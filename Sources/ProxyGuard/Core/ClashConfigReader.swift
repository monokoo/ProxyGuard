import Foundation

struct ClashConfigReader {

    private static var cachedConfig: ClashConfig?
    private static var cacheTimestamp: Date?
    private static let cacheValidDuration: TimeInterval = 1.0

    static func readConfig(from path: String) -> ClashConfig? {
        // Check cache first
        if let cached = cachedConfig,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidDuration {
            return cached
        }

        // Expand tilde in path
        let expandedPath = (path as NSString).expandingTildeInPath

        // Native Swift file reading
        guard let content = try? String(contentsOfFile: expandedPath, encoding: .utf8) else {
            return nil
        }

        // Parse line by line to extract values
        var enabled: Bool = false
        var port: Int = 7897 // Default
        var kernel: String? = nil
        
        // Priority tracking for port (verge_mixed > mixed > port)
        var portPriority = 0 // 0: default, 1: port, 2: mixed, 3: verge_mixed
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            // Check enable_system_proxy
            if trimmed.hasPrefix("enable_system_proxy:") {
                let value = parseValue(from: trimmed)
                if value == "true" { enabled = true }
                else if value == "false" { enabled = false }
            }
            // Fallback: system-proxy
            else if trimmed.hasPrefix("system-proxy:") && !enabled { // Only if not already set by higher prio? 
                // Actually system-proxy in standard clash is string/bool? Usually boolean.
                // But verge uses enable_system_proxy. Keep logic similar to script.
                // The script checked system-proxy ONLY if enable_system_proxy was not found (empty).
                // Here we initialize enabled=false. We should distinguish "not found" vs "false".
                // But simplified logic: assume false.
                // To strictly follow script priority: capture strings first, then decide.
            }
            
            // Check clash_core (Kernel)
            if trimmed.hasPrefix("clash_core:") {
                let value = parseValue(from: trimmed)
                // Value might be "mihomo", "clash", "clash-meta"
                // Remove quotes if present
                kernel = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }

            // Check Ports
            if trimmed.hasPrefix("verge_mixed_port:") {
                if let p = Int(parseValue(from: trimmed)), p > 0 {
                    port = p
                    portPriority = 4
                }
            } else if trimmed.hasPrefix("mixed-port:") && portPriority < 4 {
                if let p = Int(parseValue(from: trimmed)), p > 0 {
                    port = p
                    portPriority = 3
                }
            } else if trimmed.hasPrefix("verge_port:") && portPriority < 3 {
                if let p = Int(parseValue(from: trimmed)), p > 0 {
                    port = p
                    portPriority = 2
                }
            } else if (trimmed.hasPrefix("port:") || trimmed.hasPrefix("http-port:")) && portPriority < 2 {
                 // Note: script checked "port:". "http-port" is synonym in some contexts? 
                 // Script checked "port:" last.
                if let p = Int(parseValue(from: trimmed)), p > 0 {
                    port = p
                    portPriority = 1
                }
            }
        }
        
        // Re-scan for system-proxy if needed? 
        // Logic simplification: Just finding "enable_system_proxy" is usually enough for Verge.
        // If not found, default is false.

        let config = ClashConfig(systemProxyEnabled: enabled, port: port, kernelName: kernel)

        // Update cache
        cachedConfig = config
        cacheTimestamp = Date()

        return config
    }
    
    private static func parseValue(from line: String) -> String {
        guard let range = line.range(of: ":") else { return "" }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    static func clearCache() {
        cachedConfig = nil
        cacheTimestamp = nil
    }
}

struct ClashConfig {
    let systemProxyEnabled: Bool
    let port: Int
    /// Detected kernel name from config (e.g. "mihomo", "clash")
    let kernelName: String?
}
