import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case auto
    case en
    case zh

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .en: return "English"
        case .zh: return "中文"
        }
    }

    var resolved: AppLanguage {
        guard self == .auto else { return self }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .zh : .en
    }
}

enum L10n {
    // MARK: - Menu Bar
    static var current: AppLanguage {
        ConfigStore.shared.language.resolved
    }

    static var proxyActive: String {
        current == .zh ? "代理已启用" : "Proxy Active"
    }

    static var proxyInactive: String {
        current == .zh ? "代理未启用" : "Proxy Inactive"
    }

    static var monitoringPaused: String {
        current == .zh ? "守护已暂停" : "Monitoring Paused"
    }

    static var guardDisabled: String {
        current == .zh ? "守护已关闭" : "Guard Disabled"
    }

    static var monitoringActive: String {
        current == .zh ? "监控运行中" : "Monitoring Active"
    }

    static var autoRestore: String {
        current == .zh ? "自动恢复" : "Auto Restore"
    }

    static var recentEvents: String {
        current == .zh ? "最近事件" : "Recent Events"
    }

    static var noEventsYet: String {
        current == .zh ? "暂无事件" : "No events yet"
    }

    static var tabHistory: String {
        current == .zh ? "历史" : "History"
    }

    static var clearHistory: String {
        current == .zh ? "清除历史" : "Clear History"
    }

    static var eventHistory: String {
        current == .zh ? "事件历史" : "Event History"
    }

    static var proxyRestored: String {
        current == .zh ? "代理已恢复" : "Proxy restored"
    }

    static var restoredToProxyman: String {
        current == .zh ? "已恢复为 Proxyman" : "Restored to Proxyman"
    }

    static var closedByClashDead: String {
        current == .zh ? "已关闭 (Clash 意外退出)" : "Closed (Clash died)"
    }

    static var skippedClashClosed: String {
        current == .zh ? "已跳过 (Clash 已关闭)" : "Skipped (Clash closed)"
    }

    static var skippedNoNeed: String {
        current == .zh ? "无需干预" : "No intervention needed"
    }

    static var clearedNoClash: String {
        current == .zh ? "已清除 (Clash 未运行)" : "Cleared (Clash not running)"
    }

    static func restoreFailed(_ msg: String) -> String {
        current == .zh ? "恢复失败: \(msg)" : "Restore failed: \(msg)"
    }

    static var settings: String {
        current == .zh ? "设置" : "Settings"
    }

    static var quit: String {
        current == .zh ? "退出 ProxyGuard" : "Quit ProxyGuard"
    }

    static var restoreNow: String {
        current == .zh ? "立即恢复" : "Restore Now"
    }

    static var closeProxy: String {
        current == .zh ? "关闭代理" : "Close Proxy"
    }

    static var running: String {
        current == .zh ? "运行中" : "Running"
    }

    static var notRunning: String {
        current == .zh ? "未运行" : "Not Running"
    }

    // MARK: - New UI Strings
    static var systemSecure: String {
        current == .zh ? "代理守护中" : "Guard Active"
    }

    static var protectionDisabled: String {
        current == .zh ? "守护已禁用" : "Protection Disabled"
    }

    static var processStatus: String {
        current == .zh ? "核心进程状态" : "Process Status"
    }
    
    static var runningStatus: String {
        current == .zh ? "运行中" : "Running"
    }

    static var resetProxy: String {
        current == .zh ? "重置系统代理" : "Reset Proxy"
    }
    
    static var openSettings: String {
        current == .zh ? "打开设置" : "Open Settings"
    }
    
    static var quitApp: String {
        current == .zh ? "退出应用" : "Quit App"
    }
    
    static var pauseGuard: String {
        current == .zh ? "暂停守护" : "Pause Guard"
    }
    
    static var resumeGuard: String {
        current == .zh ? "恢复守护" : "Resume Guard"
    }


    // MARK: - Settings Tabs
    static var tabProxy: String {
        current == .zh ? "代理" : "Proxy"
    }

    static var tabBehavior: String {
        current == .zh ? "行为" : "Behavior"
    }

    static var tabAbout: String {
        current == .zh ? "关于" : "About"
    }

    static var tabAdvanced: String {
        current == .zh ? "高级" : "Advanced"
    }

    // MARK: - Proxy Tab
    static var port: String {
        current == .zh ? "端口" : "Port"
    }

    static var enable: String {
        current == .zh ? "启用" : "Enable"
    }

    static var resetPortsToDefault: String {
        current == .zh ? "重置端口为默认值" : "Reset Ports to Default"
    }

    static var resetToDefaults: String {
        current == .zh ? "重置为默认值?" : "Reset to Defaults?"
    }

    static var resetConfirmMessage: String {
        current == .zh ? "所有代理端口将被重置为 7897。" : "All proxy ports will be reset to 7897."
    }

    static var cancel: String {
        current == .zh ? "取消" : "Cancel"
    }

    static var reset: String {
        current == .zh ? "重置" : "Reset"
    }

    // MARK: - Behavior Tab
    static var launchAtLogin: String {
        current == .zh ? "开机自启" : "Launch at Login"
    }

    static var launchAtLoginDescription: String {
        current == .zh ? "开机时自动启动 ProxyGuard" : "Automatically start ProxyGuard at login"
    }

    static var autoRestoreDescription: String {
        current == .zh ? "当代理被外部清除时自动恢复" : "Automatically restore proxy when cleared externally"
    }

    static var restoreDelay: String {
        current == .zh ? "恢复延迟" : "Restore Delay"
    }

    static var restoreDelayDescription: String {
        current == .zh ? "恢复前等待一段时间，避免与其他应用冲突。" : "Delay before restoring proxy to avoid conflicts with other apps."
    }

    static var language: String {
        current == .zh ? "语言" : "Language"
    }

    static var languageDescription: String {
        current == .zh ? "切换界面显示语言" : "Switch interface display language"
    }

    // MARK: - Advanced Settings
    static var proxymanPort: String {
        current == .zh ? "Proxyman 端口" : "Proxyman Port"
    }

    static var proxymanPortDescription: String {
        current == .zh ? "Proxyman 使用的代理端口" : "The proxy port used by Proxyman"
    }

    static var clashConfigPath: String {
        current == .zh ? "Clash 配置路径" : "Clash Config Path"
    }

    static var clashConfigPathDescription: String {
        current == .zh ? "Clash Verge Rev 配置文件路径" : "Path to Clash Verge Rev config file"
    }

    static var clashEnableField: String {
        current == .zh ? "系统代理开关字段" : "System Proxy Enable Field"
    }

    static var clashEnableFieldDescription: String {
        current == .zh ? "配置文件中表示系统代理开关的字段名" : "Field name for system proxy enable in config"
    }

    static var fileExists: String {
        current == .zh ? "文件存在" : "File exists"
    }

    static var fileNotFound: String {
        current == .zh ? "文件不存在" : "File not found"
    }

    static var retryEnabled: String {
        current == .zh ? "失败自动重试" : "Auto Retry on Failure"
    }

    static var retryEnabledDescription: String {
        current == .zh ? "恢复失败时自动重试" : "Automatically retry when restore fails"
    }

    static var maxRetryCount: String {
        current == .zh ? "最大重试次数" : "Max Retry Count"
    }

    static var retrying: String {
        current == .zh ? "重试中" : "Retrying"
    }

    static var loggingEnabled: String {
        current == .zh ? "日志记录" : "Logging"
    }

    static var loggingEnabledDescription: String {
        current == .zh ? "开启后将记录运行日志到本地文件" : "Write runtime logs to local file when enabled"
    }

    // MARK: - About Tab
    static var aboutDescription: String {
        current == .zh
            ? "监听系统代理变化，当代理被外部清除时\n自动恢复 Clash Verge 的代理设置。"
            : "Monitors system proxy changes and automatically\nrestores Clash Verge proxy when cleared."
    }

    static var settingsWindowTitle: String {
        current == .zh ? "ProxyGuard 设置" : "ProxyGuard Settings"
    }
    
    // MARK: - Diagnostics Tab
    static var tabDiagnostics: String {
        current == .zh ? "诊断" : "Diagnostics"
    }
    
    static var diagnosticsTitle: String {
        current == .zh ? "系统诊断" : "System Diagnostics"
    }
    
    static var refreshReport: String {
        current == .zh ? "刷新报告" : "Refresh Report"
    }
    
    static var currentProxyStatus: String {
        current == .zh ? "当前系统代理状态" : "Current System Proxy Status"
    }
    
    static var processReport: String {
        current == .zh ? "进程检测报告" : "Process Report"
    }
    
    static var loadingReport: String {
        current == .zh ? "正在加载诊断报告..." : "Loading diagnostics report..."
    }
    
    static var statusOff: String {
        current == .zh ? "关闭" : "Off"
    }
    
    // MARK: - Diagnostics Report
    static var reportProcessStatusHeader: String {
        current == .zh ? "进程状态:\n" : "Process Status:\n"
    }
    
    static func reportClashUIRunning(id: String) -> String {
        current == .zh 
            ? "✅ Clash Verge UI (运行中)\n   ID: \(id)\n"
            : "✅ Clash Verge UI (Running)\n   ID: \(id)\n"
    }
    
    static var reportClashUIStopped: String {
        current == .zh ? "❌ Clash Verge UI (未运行)\n" : "❌ Clash Verge UI (Stopped)\n"
    }
    
    static var reportProxymanRunning: String {
        current == .zh ? "✅ Proxyman (运行中)\n" : "✅ Proxyman (Running)\n"
    }
    
    static var reportProxymanStopped: String {
        current == .zh ? "❌ Proxyman (未运行)\n" : "❌ Proxyman (Stopped)\n"
    }
    
    static func reportKernelFound(name: String) -> String {
        current == .zh ? "✅ 内核已找到: \(name)\n" : "✅ Kernel Found: \(name)\n"
    }
    
    static var reportKernelNotFound: String {
        current == .zh ? "❌ 未检测到内核\n" : "❌ Kernel Not Detected\n"
    }
    
    static func reportKernelSearched(names: String) -> String {
        current == .zh ? "   已搜索: \(names)\n" : "   Searched: \(names)\n"
    }
}
