import Foundation
import SystemConfiguration
import AppKit
import Observation

@Observable
final class ProxyMonitor {

    private(set) var currentState: ProxyState = .empty
    private(set) var eventHistory: [ProxyEvent] = []
    private(set) var isClashVergeRunning: Bool = false
    private(set) var isProxymanRunning: Bool = false
    var isPaused: Bool = false {
        didSet {
            if isPaused {
                // Remove observers
                removeProcessObservers()
                print("[ProxyGuard] Paused: monitoring frozen")
            } else {
                // Resume: Refresh state + Add observers
                let freshState = readCurrentProxyState()
                previousState = freshState
                currentState = freshState
                refreshProcessStatus()
                setupProcessObservers()
                print("[ProxyGuard] Resumed: observers added, state refreshed")
            }
        }
    }

    private var store: SCDynamicStore?
    private var runLoopSource: CFRunLoopSource?
    private var previousState: ProxyState = .empty
    private var isRestoring = false
    // Flag to suppress restore operations after we closed proxy due to Clash death
    // This prevents race conditions where the proxy close event triggers a restore
    // because ProcessChecker might still report Clash as running for a split second
    private var suppressRestoreUntilClashRestart = false
    
    // Debounce work item for proxy change callbacks
    private var debounceWorkItem: DispatchWorkItem?
    
    // Observers token
    private var observers: [NSObjectProtocol] = []

    private let restorer = ProxyRestorer()
    private let configStore: ConfigStore

    init(configStore: ConfigStore) {
        self.configStore = configStore
    }

    func startMonitoring() {
        var context = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let store = SCDynamicStoreCreate(
            kCFAllocatorDefault,
            "com.proxyguard.monitor" as CFString,
            proxyChangeCallback,
            &context
        ) else {
            print("[ProxyGuard] Failed to create SCDynamicStore")
            return
        }
        self.store = store

        let keys = ["State:/Network/Global/Proxies" as CFString] as CFArray
        guard SCDynamicStoreSetNotificationKeys(store, keys, nil) else {
            print("[ProxyGuard] Failed to set notification keys")
            return
        }

        guard let source = SCDynamicStoreCreateRunLoopSource(
            kCFAllocatorDefault, store, 0
        ) else {
            print("[ProxyGuard] Failed to create RunLoop source")
            return
        }
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)

        previousState = readCurrentProxyState()
        currentState = previousState
        refreshProcessStatus()
        
        // Setup event-driven observers instead of polling
        setupProcessObservers()

        print("[ProxyGuard] Monitoring started. Initial state: \(previousState)")
    }

    func refreshProcessStatus() {
        let wasClashRunning = isClashVergeRunning
        
        // Read config to get kernel hint
        // Uses cache so it's fast
        let config = ClashConfigReader.readConfig(from: configStore.config.clashConfigPath)
        let hint = config?.kernelName
        
        let clashRunning = ProcessChecker.isClashVergeRunning(kernelHint: hint)
        if isClashVergeRunning != clashRunning {
            isClashVergeRunning = clashRunning
        }
        
        let proxymanRunning = ProcessChecker.isProxymanRunning()
        if isProxymanRunning != proxymanRunning {
            isProxymanRunning = proxymanRunning
        }

        // If Clash restarted, we can stop suppressing restores
        if !wasClashRunning && isClashVergeRunning {
            if suppressRestoreUntilClashRestart {
                print("[ProxyGuard] Clash restarted, lifting suppression")
                suppressRestoreUntilClashRestart = false
            }
        }
    }

    func stopMonitoring() {
        removeProcessObservers()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        runLoopSource = nil
        store = nil
        print("[ProxyGuard] Monitoring stopped")
    }
    
    // MARK: - Event Driven Monitoring
    
    private func setupProcessObservers() {
        let center = NSWorkspace.shared.notificationCenter
        // Watch for App Launch/Terminate events
        let relevantNotifications: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]
        
        for name in relevantNotifications {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                self?.handleApplicationNotification(note)
            }
            observers.append(observer)
        }
    }
    
    private func removeProcessObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }
    
    private func handleApplicationNotification(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = app.bundleIdentifier else {
            return
        }
        
        // Simple filter: only refresh if Clash or Proxyman is involved
        // This reduces overhead from unrelated app launches
        let interestingIDs = [
            "clash", "verge", "proxyman"
        ]
        
        if interestingIDs.contains(where: { bundleID.lowercased().contains($0) }) {
            print("[ProxyGuard] Relevant app event detected: \(bundleID) - Refreshing status")
            // Add a small delay for 'didLaunch' to ensure service processes might have started?
            // Since ProcessChecker uses sysctl (instant), we trigger immediately.
            // But for 'launch', the service might lag behind the UI.
            refreshProcessStatus()
            
            // Optional: Double check after 1s for "Launch" events where service might start late
             if notification.name == NSWorkspace.didLaunchApplicationNotification {
                 scheduleTolerantly(1.0, tolerance: 0.5) { [weak self] in
                     self?.refreshProcessStatus()
                 }
            }
        }
    }

    func readCurrentProxyState() -> ProxyState {
        guard let store = store,
              let dict = SCDynamicStoreCopyProxies(store) as? [String: Any]
        else {
            return .empty
        }

        return ProxyState(
            httpEnabled: (dict[kSCPropNetProxiesHTTPEnable as String] as? Int) == 1,
            httpHost: dict[kSCPropNetProxiesHTTPProxy as String] as? String,
            httpPort: dict[kSCPropNetProxiesHTTPPort as String] as? Int,
            httpsEnabled: (dict[kSCPropNetProxiesHTTPSEnable as String] as? Int) == 1,
            httpsHost: dict[kSCPropNetProxiesHTTPSProxy as String] as? String,
            httpsPort: dict[kSCPropNetProxiesHTTPSPort as String] as? Int,
            socksEnabled: (dict[kSCPropNetProxiesSOCKSEnable as String] as? Int) == 1,
            socksHost: dict[kSCPropNetProxiesSOCKSProxy as String] as? String,
            socksPort: dict[kSCPropNetProxiesSOCKSPort as String] as? Int
        )
    }

    fileprivate func handleProxyChange() {
        // Debounce: coalesce rapid proxy change callbacks into one
        debounceWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.processProxyChange()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    private func processProxyChange() {
        // 暂停模式：完全休眠，不更新状态，不做任何处理
        guard !isPaused else {
            print("[ProxyGuard] Paused, ignoring proxy change entirely")
            return
        }
        
        let newState = readCurrentProxyState()
        
        // Anti-flicker: Only update if state actually changed
        if newState == currentState {
            previousState = newState
        } else {
            previousState = newState
            currentState = newState
        }

        // 自动恢复关闭：继续更新状态展示，但不进行干预
        guard configStore.config.autoRestoreEnabled else {
            print("[ProxyGuard] Auto restore disabled, state updated but skipping intervention")
            return
        }

        guard !isRestoring else {
            print("[ProxyGuard] Already restoring, ignoring")
            return
        }

        // Read Clash config
        guard let clashConfig = ClashConfigReader.readConfig(
            from: configStore.config.clashConfigPath
        ) else {
            print("[ProxyGuard] Failed to read Clash config")
            return
        }

        let proxymanRunning = ProcessChecker.isProxymanRunning()
        // Pass kernel hint to check specifically for the user's configured kernel
        let clashRunning = ProcessChecker.isClashVergeRunning(kernelHint: clashConfig.kernelName)
        let clashEnabled = clashConfig.systemProxyEnabled
        let currentPort = newState.httpPort ?? newState.httpsPort ?? newState.socksPort ?? 0
        // Use port from config file for accurate detection
        let clashPort = clashConfig.port
        let proxymanPort = configStore.config.proxymanPort

        let delay = configStore.config.restoreDelaySeconds
        
        LogManager.shared.log("Handle Proxy Change:")
        LogManager.shared.log("  Clash Config: enabled=\(clashEnabled), port=\(clashPort)")
        LogManager.shared.log("  System State: currentPort=\(currentPort), active=\(newState.isActive)")
        LogManager.shared.log("  Process State: ClashVerge=\(clashRunning), Proxyman=\(proxymanRunning)")

        LogManager.shared.log("  Decision Matrix:")

        // Scenario decision matrix
        if proxymanRunning {
            LogManager.shared.log("  Scenario Check: Proxyman Running")
            if currentPort == clashPort && clashEnabled {
                LogManager.shared.log("    Condition: Port is Clash's (\(clashPort)), Clash Enabled")
                // Scenario 1: Proxyman exists, port is Clash's, Clash enabled
                    if !clashRunning {
                        // Scenario 1b: Clash process not running → close proxy
                        LogManager.shared.log("  -> Scenario 1b: Clash enabled but not running, closing proxy")
                        isRestoring = true
                        suppressRestoreUntilClashRestart = true
                        scheduleDelayed(delay) { [weak self] in
                            self?.closeProxy()
                        }
                        return
                    }
                // Scenario 1a: Clash running → no intervention
                LogManager.shared.log("  -> Scenario 1a: Clash running, no intervention needed")
                recordEvent(.skippedNoNeed)
                return
            } else if currentPort == clashPort && !clashEnabled {
                LogManager.shared.log("    Condition: Port is Clash's (\(clashPort)), Clash Disabled")
                // Scenario 2: Proxyman exists, port is Clash's, Clash disabled
                // Restore to Proxyman proxy
                LogManager.shared.log("  -> Scenario 2: Clash disabled, restoring to Proxyman")
                isRestoring = true
                scheduleDelayed(delay) { [weak self] in
                    self?.restoreToProxyman()
                }
                return
            }
            // Scenario 1c: Proxyman running but proxy cleared, Clash enabled
            // (e.g. Proxyman window closed, proxy settings cleared, but process still alive)
            if !newState.isActive && clashEnabled && clashRunning {
                LogManager.shared.log("    Condition: Proxy cleared, Clash Enabled, Clash Running")
                LogManager.shared.log("  -> Scenario 1c: Proxyman bg + proxy cleared + Clash enabled → restoring Clash")
                isRestoring = true
                scheduleDelayed(delay) { [weak self] in
                    self?.restoreToClash()
                    self?.refreshProcessStatus()
                }
                return
            }
            // Other states with Proxyman running → no intervention
            LogManager.shared.log("  -> Proxyman running with different state, no intervention")
            recordEvent(.skippedNoNeed)
            return
        }

        // Proxyman is closed
        LogManager.shared.log("  Scenario Check: Proxyman Closed")
        if currentPort == clashPort && clashEnabled {
            LogManager.shared.log("    Condition: Port is Clash's (\(clashPort)), Clash Enabled")
            // Scenario 3: Proxyman closed, port is Clash's, Clash enabled
            if !clashRunning {
                // Scenario 3b: Clash process not running → close proxy
                LogManager.shared.log("  -> Scenario 3b: Clash enabled but not running, closing proxy")
                isRestoring = true
                suppressRestoreUntilClashRestart = true
                scheduleDelayed(delay) { [weak self] in
                    self?.closeProxy()
                }
                return
            }
            // Scenario 3a: Clash running → no intervention
            LogManager.shared.log("  -> Scenario 3a: Clash running, no intervention needed")
            recordEvent(.skippedNoNeed)
            return
        }

        if !newState.isActive && clashEnabled {
            LogManager.shared.log("    Condition: Proxy cleared, Clash Enabled")
            // Scenario 4: Proxy cleared, Clash enabled
            if clashRunning {
                // Scenario 4a: Clash running → restore Clash proxy
                LogManager.shared.log("  -> Scenario 4a: Proxy cleared + Clash enabled + Running → scheduling restore check")
                isRestoring = true
                scheduleDelayed(delay) { [weak self] in
                    let freshConfig = ClashConfigReader.readConfig(from: self?.configStore.config.clashConfigPath ?? "")
                    let hint = freshConfig?.kernelName
                    
                    if !ProcessChecker.isClashVergeRunning(kernelHint: hint) {
                        LogManager.shared.log("  -> Scenario 4a: Abort restore, Clash process exited during delay")
                        self?.isRestoring = false
                        return
                    }
                    self?.restoreToClash()
                }
                return
            } else {
                // Scenario 4b: Clash not running → do nothing (already cleared)
                LogManager.shared.log("  -> Scenario 4b: Proxy cleared + Clash enabled but not running → no action")
                recordEvent(.skippedNoNeed)
                return
            }
        }

        if !newState.isActive && !clashEnabled {
            LogManager.shared.log("    Condition: Proxy cleared, Clash Disabled")
            // Scenario 5: Proxyman closed, proxy disabled, Clash disabled
            LogManager.shared.log("  -> Scenario 5: Both disabled, no intervention")
            recordEvent(.skippedNoNeed)
            return
        }

        if currentPort == proxymanPort && clashEnabled {
            LogManager.shared.log("    Condition: Port is Proxyman's (\(proxymanPort)), Clash Enabled")
            // Scenario 6: Proxyman closed, port is Proxyman's, Clash enabled
            if clashRunning {
                // Scenario 6a: Restore to Clash proxy
                print("[ProxyGuard] Scenario 6a: Restoring to Clash proxy")
                isRestoring = true
                scheduleDelayed(delay) { [weak self] in
                    self?.restoreToClash()
                }
                return
            }
            // Scenario 6b: Clash not running → close proxy
            print("[ProxyGuard] Scenario 6b: Clash not running, closing proxy")
            isRestoring = true
            scheduleDelayed(delay) { [weak self] in
                self?.closeProxy()
            }
            return
        }

        if currentPort == proxymanPort && !clashEnabled {
            // Scenario 7: Proxyman closed, port is Proxyman's, Clash disabled
            print("[ProxyGuard] Scenario 7: Clash disabled, closing proxy")
            isRestoring = true
            scheduleDelayed(delay) { [weak self] in
                self?.closeProxy()
            }
            return
        }

        // Default: no intervention
        print("[ProxyGuard] No matching scenario, no intervention")
        recordEvent(.skippedNoNeed)
    }

    func restoreToClash(retryAttempt: Int = 0) {
        defer {
            if retryAttempt == 0 {
                isRestoring = false
            }
        }

        guard configStore.config.autoRestoreEnabled else {
            LogManager.shared.log("[Restore] Auto restore disabled in settings")
            return
        }

        // Double-check: re-read Clash config to handle race condition
        // (User may have manually disabled system proxy between event and restore)
        if let freshConfig = ClashConfigReader.readConfig(from: configStore.config.clashConfigPath),
           !freshConfig.systemProxyEnabled {
            LogManager.shared.log("[Restore] Clash system proxy was disabled before restore, skipping")
            recordEvent(.skippedNoNeed)
            return
        }

        // Check if we are suppressed
        if suppressRestoreUntilClashRestart {
            LogManager.shared.log("[Restore] Suppressed until Clash restarts")
            // We don't record 'skipped' here to avoid spamming log, knowing it's intentional
            return
        }

        let result = restorer.restore(with: configStore.config)
        switch result {
        case .success:
            print("[ProxyGuard] Clash proxy restored successfully")
            let restored = readCurrentProxyState()
            previousState = restored
            currentState = restored
            recordEvent(.restored)
        case .failure(let error):
            let maxRetries = configStore.config.maxRetryCount
            if configStore.config.retryEnabled && retryAttempt < maxRetries {
                let retryDelays: [Double] = [2.0, 5.0, 10.0]
                let delay = retryAttempt < retryDelays.count ? retryDelays[retryAttempt] : 10.0
                let next = retryAttempt + 1
                print("[ProxyGuard] Restore failed, retrying (\(next)/\(maxRetries)) in \(delay)s...")
                recordEvent(.retrying(next))
                scheduleTolerantly(delay, tolerance: 1.0) { [weak self] in
                    self?.restoreToClash(retryAttempt: next)
                }
            } else {
                print("[ProxyGuard] Proxy restore failed: \(error)")
                recordEvent(.restoreFailed(error.localizedDescription))
            }
        }
    }

    func restoreToProxyman() {
        // 延迟重置 isRestoring，防止代理变化事件竞态
        func delayedResetRestoring() {
            scheduleTolerantly(3.0, tolerance: 1.0) { [weak self] in
                self?.isRestoring = false
            }
        }

        let config = ProxyConfig(
            httpEnabled: true,
            httpPort: configStore.config.proxymanPort,
            httpsEnabled: true,
            httpsPort: configStore.config.proxymanPort,
            socksEnabled: false,
            socksPort: 0,
            autoRestoreEnabled: true,
            restoreDelaySeconds: configStore.config.restoreDelaySeconds,
            language: configStore.config.language,
            proxymanPort: configStore.config.proxymanPort,
            clashConfigPath: configStore.config.clashConfigPath,
            clashEnableField: configStore.config.clashEnableField,
            retryEnabled: configStore.config.retryEnabled,
            maxRetryCount: configStore.config.maxRetryCount,
            loggingEnabled: configStore.config.loggingEnabled
        )

        let result = restorer.restore(with: config)
        switch result {
        case .success:
            print("[ProxyGuard] Proxyman proxy restored successfully")
            let restored = readCurrentProxyState()
            previousState = restored
            currentState = restored
            recordEvent(.restoredToProxyman)
            delayedResetRestoring()
        case .failure(let error):
            print("[ProxyGuard] Proxyman restore failed: \(error)")
            recordEvent(.restoreFailed(error.localizedDescription))
            delayedResetRestoring()
        }
    }

    func closeProxy() {
        // 延迟重置 isRestoring，防止代理变化事件竞态
        // closeProxy 修改系统代理 → 触发 SCDynamicStore 回调 → handleProxyChange
        // 如果立即重置 isRestoring，后续事件可能因进程检测延迟而错误恢复代理
        func delayedResetRestoring() {
            scheduleTolerantly(3.0, tolerance: 1.0) { [weak self] in
                self?.isRestoring = false
            }
        }

        let result = restorer.disableAllProxy()
        switch result {
        case .success:
            print("[ProxyGuard] Proxy closed successfully")
            let closed = readCurrentProxyState()
            previousState = closed
            currentState = closed
            recordEvent(.closedByClashDead)
            delayedResetRestoring()
        case .failure(let error):
            print("[ProxyGuard] Proxy close failed: \(error)")
            recordEvent(.restoreFailed(error.localizedDescription))
            delayedResetRestoring()
        }
    }

    // 最近一条事件（兼容）
    var lastEvent: ProxyEvent? {
        eventHistory.first
    }

    // 清除事件历史
    func clearEventHistory() {
        DispatchQueue.main.async {
            self.eventHistory.removeAll()
        }
    }

    private static let maxEventHistory = 50

    private func recordEvent(_ type: ProxyEventType) {
        DispatchQueue.main.async {
            // Anti-spam: Ignore repeated "skippedNoNeed" events
            // This prevents rapid UI redrawing when system proxy callbacks fire frequently without actual changes
            if type == .skippedNoNeed, let last = self.eventHistory.first, last.type == .skippedNoNeed {
                return
            }
            
            self.eventHistory.insert(
                ProxyEvent(timestamp: Date(), type: type),
                at: 0
            )
            if self.eventHistory.count > Self.maxEventHistory {
                self.eventHistory.removeLast()
            }
        }
    }

    // MARK: - Timer Helpers

    /// Schedule a delayed action with moderate tolerance for system wake coalescing
    private func scheduleDelayed(_ delay: TimeInterval, action: @escaping () -> Void) {
        let timer = Timer(timeInterval: delay, repeats: false) { _ in action() }
        timer.tolerance = delay * 0.3 // 30% tolerance
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Schedule with explicit tolerance for non-critical timers (reduces idle wakeups)
    private func scheduleTolerantly(_ delay: TimeInterval, tolerance: TimeInterval, action: @escaping () -> Void) {
        let timer = Timer(timeInterval: delay, repeats: false) { _ in action() }
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
    }
}

private func proxyChangeCallback(
    store: SCDynamicStore,
    changedKeys: CFArray,
    info: UnsafeMutableRawPointer?
) {
    guard let info else { return }
    let monitor = Unmanaged<ProxyMonitor>.fromOpaque(info).takeUnretainedValue()
    monitor.handleProxyChange()
}
