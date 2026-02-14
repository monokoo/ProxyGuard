import Foundation
import AppKit
import Darwin

enum ProcessChecker {
    
    // MARK: - Constants
    
    private static let clashVergeBundleIDs = [
        "com.clash-verge-rev.clash-verge-rev",
        "io.github.clash-verge-rev.clash-verge-rev",
        "com.clashverge.app",
    ]

    private static let proxymanBundleIDs = [
        "com.proxyman.NSProxy",
        "com.proxyman.Proxyman",
        "com.proxyman.macos",
    ]
    
    // MARK: - Cache
    
    private struct ProcessCache {
        let timestamp: Date
        let names: Set<String>
    }
    
    // 1 second cache to prevent spamming sysctl in tight loops
    private static var cache: ProcessCache?
    private static let cacheDuration: TimeInterval = 1.0

    // MARK: - Public API

    static func isClashVergeRunning(kernelHint: String? = nil) -> Bool {
        // 1. Check for GUI App (Fastest)
        var isUIRunning = false
        for bundleID in clashVergeBundleIDs {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
                isUIRunning = true
                break
            }
        }
        
        if isUIRunning {
            LogManager.shared.log("[ProcessChecker] Clash Verge UI detected (Bundle ID match)")
        } else {
            LogManager.shared.log("[ProcessChecker] Clash Verge UI NOT detected")
        }

        guard isUIRunning else { return false }

        // 2. Check for Kernel/Service Process
        // Use native sysctl instead of pgrep for performance
        let runningProcesses = getRunningProcessNames()
        
        var serviceNames = [
            "clash-verge-service",
            "clash-verge",
            "verge-mihomo",
            "Clash Meta",
            "mihomo"
        ]
        
        // Add hint if provided
        if let hint = kernelHint, !hint.isEmpty {
            // If hint is a path, take the filename
            let name = (hint as NSString).lastPathComponent
            if !serviceNames.contains(name) {
                serviceNames.insert(name, at: 0) // Prioritize hint
            }
        }
        
        for name in serviceNames {
            if containsProcess(name: name, in: runningProcesses) {
                LogManager.shared.log("[ProcessChecker] Clash Service detected: \(name)")
                return true
            }
        }
        
        LogManager.shared.log("[ProcessChecker] Clash UI running but NO Service detected")
        return false
    }

    static func isProxymanRunning() -> Bool {
        for bundleID in proxymanBundleIDs {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
                return true
            }
        }
        return containsProcess(name: "Proxyman", in: getRunningProcessNames())
    }

    static func getDiagnosticsReport(kernelHint: String? = nil) -> String {
        var report = L10n.reportProcessStatusHeader
        
        // 1. Check UI
        var uiFound = false
        for bundleID in clashVergeBundleIDs {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
                report += L10n.reportClashUIRunning(id: bundleID)
                uiFound = true
                break
            }
        }
        if !uiFound {
            report += L10n.reportClashUIStopped
        }
        
        // 2. Check Proxyman
        var proxymanRunning = false
        for bundleID in proxymanBundleIDs {
            if !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
                proxymanRunning = true
                break
            }
        }
        report += proxymanRunning ? L10n.reportProxymanRunning : L10n.reportProxymanStopped
        
        // 3. Check Kernel
        let runningProcesses = getRunningProcessNames()
        var serviceNames = [
            "clash-verge-service",
            "clash-verge",
            "verge-mihomo",
            "Clash Meta",
            "mihomo"
        ]
        
        if let hint = kernelHint, !hint.isEmpty {
            let name = (hint as NSString).lastPathComponent
            if !serviceNames.contains(name) {
                serviceNames.insert(name, at: 0)
            }
        }
        
        var kernelFound = false
        for name in serviceNames {
            if containsProcess(name: name, in: runningProcesses) {
                report += L10n.reportKernelFound(name: name)
                kernelFound = true
            }
        }
        if !kernelFound {
            report += L10n.reportKernelNotFound
            report += L10n.reportKernelSearched(names: serviceNames.joined(separator: ", "))
        }
        
        return report
    }

    // MARK: - Private Helpers
    
    /// Checks if a process name exists in the set.
    /// Handles the 16-character limit of `p_comm` by matching prefixes if the target name is long.
    private static func containsProcess(name: String, in processes: Set<String>) -> Bool {
        if processes.contains(name) {
            return true
        }
        
        // Fallback: If name is longer than 15 chars, check for truncated match
        // macOS `p_comm` is max 16 chars including null terminator, so 15 safe chars? 
        // Often it's 16 chars. We check if any process name satisfies the prefix.
        if name.count > 15 {
            let truncated = String(name.prefix(15))
            for procName in processes {
                if procName.hasPrefix(truncated) {
                    return true
                }
            }
        }
        
        return false
    }

    /// Returns a set of unique process names currently running.
    /// Uses caching to avoid frequent sysctl calls.
    private static func getRunningProcessNames() -> Set<String> {
        if let cache = cache, Date().timeIntervalSince(cache.timestamp) < cacheDuration {
            return cache.names
        }
        
        var names = Set<String>()
        
        // Use sysctl to get process list
        // MIB: [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size: size_t = 0
        
        // 1. Get buffer size
        if sysctl(&mib, 3, nil, &size, nil, 0) == -1 {
             LogManager.shared.log("[ProcessChecker] sysctl failed to get size")
             return Set()
        }
        
        // 2. Allocate buffer
        let count = size / MemoryLayout<kinfo_proc>.stride
        var processes = [kinfo_proc](repeating: kinfo_proc(), count: count)
        
        // 3. Get process info
        if sysctl(&mib, 3, &processes, &size, nil, 0) == -1 {
            LogManager.shared.log("[ProcessChecker] sysctl failed to get process list")
            return Set()
        }
        
        // 4. Parse names
        for i in 0..<Int(size / MemoryLayout<kinfo_proc>.stride) {
            let proc = processes[i]
            let comm = proc.kp_proc.p_comm
            
            // Convert tuple to String safely
            let name = withUnsafeBytes(of: comm) { ptr -> String in
                guard let base = ptr.baseAddress else { return "" }
                let buffer = UnsafeBufferPointer(start: base.assumingMemoryBound(to: CChar.self), count: 16)
                return String(cString: buffer.baseAddress!)
            }
            
            if !name.isEmpty {
                names.insert(name)
            }
        }
        
        // Update cache
        cache = ProcessCache(timestamp: Date(), names: names)
        return names
    }
}
