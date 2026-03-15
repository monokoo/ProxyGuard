import Foundation
import Observation

struct ProxyConfig: Codable, Equatable {
    var httpEnabled: Bool
    var httpPort: Int
    var httpsEnabled: Bool
    var httpsPort: Int
    var socksEnabled: Bool
    var socksPort: Int
    var autoRestoreEnabled: Bool
    var restoreDelaySeconds: Double
    var language: AppLanguage
    var proxymanPort: Int
    var clashConfigPath: String
    var clashEnableField: String
    var retryEnabled: Bool
    var maxRetryCount: Int
    var loggingEnabled: Bool
    var terminalProxyEnabled: Bool
    var terminalProxyLiveReload: Bool

    static let `default` = ProxyConfig(
        httpEnabled: true,
        httpPort: 7897,
        httpsEnabled: true,
        httpsPort: 7897,
        socksEnabled: true,
        socksPort: 7897,
        autoRestoreEnabled: true,
        restoreDelaySeconds: 2.0,
        language: .auto,
        proxymanPort: 9090,
        clashConfigPath: "~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/verge.yaml",
        clashEnableField: "enable_system_proxy",
        retryEnabled: true,
        maxRetryCount: 3,
        loggingEnabled: true,
        terminalProxyEnabled: true,
        terminalProxyLiveReload: false
    )

    // Explicit memberwise init (required since init(from:) suppresses auto-synthesis)
    init(
        httpEnabled: Bool, httpPort: Int,
        httpsEnabled: Bool, httpsPort: Int,
        socksEnabled: Bool, socksPort: Int,
        autoRestoreEnabled: Bool, restoreDelaySeconds: Double,
        language: AppLanguage, proxymanPort: Int,
        clashConfigPath: String, clashEnableField: String,
        retryEnabled: Bool, maxRetryCount: Int,
        loggingEnabled: Bool,
        terminalProxyEnabled: Bool, terminalProxyLiveReload: Bool
    ) {
        self.httpEnabled = httpEnabled
        self.httpPort = httpPort
        self.httpsEnabled = httpsEnabled
        self.httpsPort = httpsPort
        self.socksEnabled = socksEnabled
        self.socksPort = socksPort
        self.autoRestoreEnabled = autoRestoreEnabled
        self.restoreDelaySeconds = restoreDelaySeconds
        self.language = language
        self.proxymanPort = proxymanPort
        self.clashConfigPath = clashConfigPath
        self.clashEnableField = clashEnableField
        self.retryEnabled = retryEnabled
        self.maxRetryCount = maxRetryCount
        self.loggingEnabled = loggingEnabled
        self.terminalProxyEnabled = terminalProxyEnabled
        self.terminalProxyLiveReload = terminalProxyLiveReload
    }

    // Custom decoder for backward compatibility with saved configs
    // that don't have the new terminal proxy fields.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        httpEnabled = try container.decode(Bool.self, forKey: .httpEnabled)
        httpPort = try container.decode(Int.self, forKey: .httpPort)
        httpsEnabled = try container.decode(Bool.self, forKey: .httpsEnabled)
        httpsPort = try container.decode(Int.self, forKey: .httpsPort)
        socksEnabled = try container.decode(Bool.self, forKey: .socksEnabled)
        socksPort = try container.decode(Int.self, forKey: .socksPort)
        autoRestoreEnabled = try container.decode(Bool.self, forKey: .autoRestoreEnabled)
        restoreDelaySeconds = try container.decode(Double.self, forKey: .restoreDelaySeconds)
        language = try container.decode(AppLanguage.self, forKey: .language)
        proxymanPort = try container.decode(Int.self, forKey: .proxymanPort)
        clashConfigPath = try container.decode(String.self, forKey: .clashConfigPath)
        clashEnableField = try container.decode(String.self, forKey: .clashEnableField)
        retryEnabled = try container.decode(Bool.self, forKey: .retryEnabled)
        maxRetryCount = try container.decode(Int.self, forKey: .maxRetryCount)
        loggingEnabled = try container.decode(Bool.self, forKey: .loggingEnabled)
        terminalProxyEnabled = try container.decodeIfPresent(Bool.self, forKey: .terminalProxyEnabled) ?? true
        terminalProxyLiveReload = try container.decodeIfPresent(Bool.self, forKey: .terminalProxyLiveReload) ?? false
    }
}

@Observable
final class ConfigStore {

    static let shared = ConfigStore()

    private static let storageKey = "proxyConfig"

    var config: ProxyConfig {
        didSet {
            save()
        }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(ProxyConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = .default
        }
    }

    var language: AppLanguage {
        get { config.language }
        set { config.language = newValue }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
