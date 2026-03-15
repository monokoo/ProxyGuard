import SwiftUI
import AppKit
import ServiceManagement

// MARK: - 设置页主视图
struct SettingsView: View {

    @Bindable var configStore: ConfigStore
    var monitor: ProxyMonitor

    @State private var showResetAlert = false
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var selectedTab: SettingsTab = .proxy
    @State private var configFileExists = false
    @State private var localDelay: Double = 2.0
    @State private var shellStatuses: [TerminalProxyManager.ShellStatus] = TerminalProxyManager.shellIntegrationStatus()
    // 缓存 AppIcon 避免切换 Tab 时重复加载闪烁
    private let appIcon: NSImage? = NSImage(contentsOfFile: Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns")

    enum SettingsTab: String, CaseIterable {
        case proxy, behavior, terminal, advanced, diagnostics, history, about

        var icon: String {
            switch self {
            case .proxy: return "network"
            case .behavior: return "gearshape"
            case .terminal: return "terminal"
            case .advanced: return "slider.horizontal.3"
            case .diagnostics: return "stethoscope"
            case .history: return "clock.arrow.circlepath"
            case .about: return "info.circle"
            }
        }

        var title: String {
            switch self {
            case .proxy: return L10n.tabProxy
            case .behavior: return L10n.tabBehavior
            case .terminal: return L10n.tabTerminal
            case .advanced: return L10n.tabAdvanced
            case .diagnostics: return L10n.tabDiagnostics
            case .history: return L10n.tabHistory
            case .about: return L10n.tabAbout
            }
        }
    }

    var body: some View {
        ZStack {
            Color.brandGradient.ignoresSafeArea()

            HStack(spacing: 0) {
                // 侧边栏
                sidebar
                // 分隔线
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)
                // 内容区
                contentArea
            }
        }
        .frame(width: DesignSystem.settingsWidth, height: DesignSystem.settingsHeight)
        .onAppear {
            let expanded = (configStore.config.clashConfigPath as NSString).expandingTildeInPath
            configFileExists = FileManager.default.fileExists(atPath: expanded)
            localDelay = configStore.config.restoreDelaySeconds
        }
        .onChange(of: configStore.config.clashConfigPath) { newPath in
            let expanded = (newPath as NSString).expandingTildeInPath
            configFileExists = FileManager.default.fileExists(atPath: expanded)
        }
    }

    // MARK: - 侧边栏
    private var sidebar: some View {
        VStack(spacing: 4) {
            // Logo 区域
            VStack(spacing: 6) {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.neonGreen)
                }
                Text("ProxyGuard")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Tab 按钮
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                sidebarButton(tab: tab)
            }

            Spacer()

            // 版本号
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 12)
        }
        .frame(width: 120)
        .background(Color.black.opacity(0.2))
    }

    private func sidebarButton(tab: SettingsTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(tab.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == tab ? Color.white.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .padding(.horizontal, 8)
    }

    // MARK: - 内容区
    private var contentArea: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                switch selectedTab {
                case .proxy: proxyContent
                case .behavior: behaviorContent
                case .terminal: terminalContent
                case .advanced: advancedContent
                case .diagnostics: diagnosticsContent
                case .history: historyContent
                case .about: aboutContent
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 代理设置 Tab
    private var proxyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(L10n.tabProxy, icon: "network")

            darkCard {
                VStack(spacing: 0) {
                    darkProxyRow(
                        label: "HTTP", icon: "globe", color: .blue,
                        enabled: $configStore.config.httpEnabled,
                        port: $configStore.config.httpPort
                    )
                    Divider().background(Color.white.opacity(0.06))
                    darkProxyRow(
                        label: "HTTPS", icon: "lock.shield", color: .green,
                        enabled: $configStore.config.httpsEnabled,
                        port: $configStore.config.httpsPort
                    )
                    Divider().background(Color.white.opacity(0.06))
                    darkProxyRow(
                        label: "SOCKS", icon: "point.3.connected.trianglepath.dotted", color: .purple,
                        enabled: $configStore.config.socksEnabled,
                        port: $configStore.config.socksPort
                    )
                }
            }

            HStack {
                Spacer()
                Button {
                    showResetAlert = true
                } label: {
                    Text(L10n.resetPortsToDefault)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .alert(L10n.resetToDefaults, isPresented: $showResetAlert) {
            Button(L10n.cancel, role: .cancel) {}
            Button(L10n.reset, role: .destructive) {
                configStore.config = .default
            }
        } message: {
            Text(L10n.resetConfirmMessage)
        }
    }

    private func darkProxyRow(label: String, icon: String, color: Color, enabled: Binding<Bool>, port: Binding<Int>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(enabled.wrappedValue ? color : .gray)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 55, alignment: .leading)

            Toggle("", isOn: enabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(.neonBlue)

            Spacer()

            Text(L10n.port)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))

            TextField("", value: port, format: IntegerFormatStyle().grouping(.never))
                .frame(width: 65)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .disabled(!enabled.wrappedValue)

            // 状态指示点
            Circle()
                .fill(enabled.wrappedValue ? Color.neonGreen : Color.gray.opacity(0.4))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 行为设置 Tab
    private var behaviorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(L10n.tabBehavior, icon: "gearshape")

            // 开机自启
            darkCard {
                darkToggleRow(
                    title: L10n.launchAtLogin,
                    description: L10n.launchAtLoginDescription,
                    isOn: $launchAtLogin
                )
                .onChange(of: launchAtLogin) { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        print("[ProxyGuard] 登录项设置失败: \(error)")
                        launchAtLogin = !newValue
                    }
                }
            }

            // 自动恢复
            darkCard {
                darkToggleRow(
                    title: L10n.autoRestore,
                    description: L10n.autoRestoreDescription,
                    isOn: $configStore.config.autoRestoreEnabled
                )
            }

            // 失败重试
            darkCard {
                VStack(spacing: 8) {
                    darkToggleRow(
                        title: L10n.retryEnabled,
                        description: L10n.retryEnabledDescription,
                        isOn: $configStore.config.retryEnabled
                    )
                    if configStore.config.retryEnabled {
                        Divider().background(Color.white.opacity(0.06))
                        HStack {
                            Text(L10n.maxRetryCount)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                            Stepper(value: $configStore.config.maxRetryCount, in: 1...5) {
                                Text("\(configStore.config.maxRetryCount)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .labelsHidden()
                            Text("\(configStore.config.maxRetryCount)")
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.neonBlue)
                                .frame(width: 20)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                    }
                }
            }

            // 恢复延迟
            darkCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L10n.restoreDelay)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(localDelay, specifier: "%.1f") s")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.neonBlue)
                    }

                    Slider(
                        value: $localDelay,
                        in: 0.5...5.0,
                        step: 0.5
                    ) {
                        EmptyView()
                    } onEditingChanged: { editing in
                        if !editing {
                            configStore.config.restoreDelaySeconds = localDelay
                        }
                    }
                    .tint(.neonBlue)

                    HStack {
                        Text("0.5s")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                        Spacer()
                        Text("5.0s")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.3))
                    }

                    Text(L10n.restoreDelayDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(14)
            }

            // 语言设置
            darkCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.language)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text(L10n.languageDescription)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Picker(selection: $configStore.config.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    } label: { EmptyView() }
                    .labelsHidden()
                    .frame(width: 120)
                }
                .padding(14)
            }

            // 日志开关
            darkCard {
                darkToggleRow(
                    title: L10n.loggingEnabled,
                    description: L10n.loggingEnabledDescription,
                    isOn: $configStore.config.loggingEnabled
                )
            }
        }
    }

    // MARK: - 终端代理 Tab
    private var terminalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(L10n.tabTerminal, icon: "terminal")

            // Terminal proxy toggle
            darkCard {
                darkToggleRow(
                    title: L10n.terminalProxy,
                    description: L10n.terminalProxyDescription,
                    isOn: $configStore.config.terminalProxyEnabled
                )
            }

            if configStore.config.terminalProxyEnabled {
                // Live reload toggle
                darkCard {
                    darkToggleRow(
                        title: L10n.terminalProxyLiveReload,
                        description: L10n.terminalProxyLiveReloadDescription,
                        isOn: $configStore.config.terminalProxyLiveReload
                    )
                }

                // Shell integration status
                darkCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.shellIntegration)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)

                        ForEach(shellStatuses, id: \.name) { status in
                            HStack {
                                Text(status.name)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                if status.installed {
                                    Label(L10n.shellIntegrationInstalled, systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.neonGreen)
                                } else {
                                    Label(L10n.shellIntegrationNotInstalled, systemImage: "xmark.circle")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                        }

                        Divider().background(Color.white.opacity(0.06))

                        HStack(spacing: 8) {
                            Button(action: {
                                TerminalProxyManager.installShellIntegration(
                                    liveReload: configStore.config.terminalProxyLiveReload
                                )
                                shellStatuses = TerminalProxyManager.shellIntegrationStatus()
                            }) {
                                Text(L10n.installShellIntegration)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.neonBlue.opacity(0.3))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                TerminalProxyManager.uninstallShellIntegration()
                                shellStatuses = TerminalProxyManager.shellIntegrationStatus()
                            }) {
                                Text(L10n.uninstallShellIntegration)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                    }
                    .padding(.vertical, 8)
                }

                // Source command preview
                darkCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("~/.proxyguard_env")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text("[ -f \"$HOME/.proxyguard_env\" ] && source \"$HOME/.proxyguard_env\"")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.neonGreen.opacity(0.8))
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
        .onAppear {
            shellStatuses = TerminalProxyManager.shellIntegrationStatus()
        }
    }

    // MARK: - 高级设置 Tab
    private var advancedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsSectionHeader(L10n.tabAdvanced, icon: "slider.horizontal.3")

            // Proxyman 端口
            darkCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.proxymanPort)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Text(L10n.port)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                        TextField("", value: $configStore.config.proxymanPort, format: IntegerFormatStyle().grouping(.never))
                            .frame(width: 65)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    Text(L10n.proxymanPortDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(14)
            }

            // Clash 配置路径
            darkCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.clashConfigPath)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        TextField("", text: $configStore.config.clashConfigPath)
                            .font(.system(size: 11, design: .monospaced))
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button {
                            selectClashConfigFile()
                        } label: {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.neonBlue)
                        }
                        .buttonStyle(.plain)
                    }

                    // 文件状态
                    HStack(spacing: 4) {
                        if configFileExists {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.neonGreen)
                                .font(.system(size: 11))
                            Text(L10n.fileExists)
                                .font(.system(size: 11))
                                .foregroundColor(.neonGreen)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.neonRed)
                                .font(.system(size: 11))
                            Text(L10n.fileNotFound)
                                .font(.system(size: 11))
                                .foregroundColor(.neonRed)
                        }
                    }
                }
                .padding(14)
            }

            // Clash 启用字段
            darkCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.clashEnableField)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        TextField("", text: $configStore.config.clashEnableField)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    Text(L10n.clashEnableFieldDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(14)
            }
        }
    }
    
    // MARK: - 诊断 Tab
    private var diagnosticsContent: some View {
        DiagnosticsView(monitor: monitor, configStore: configStore)
    }

    // MARK: - 历史记录 Tab
    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                settingsSectionHeader(L10n.tabHistory, icon: "clock.arrow.circlepath")
                Spacer()
                if !monitor.eventHistory.isEmpty {
                    Button {
                        monitor.clearEventHistory()
                    } label: {
                        Text(L10n.clearHistory)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.neonRed)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.neonRed.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if monitor.eventHistory.isEmpty {
                darkCard {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.2))
                        Text(L10n.noEventsYet)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
            darkCard {
                    VStack(spacing: 0) {
                        ForEach(Array(monitor.eventHistory.enumerated()), id: \.element.id) { index, event in
                            if index > 0 {
                                Divider().background(Color.white.opacity(0.06))
                            }
                            HStack(spacing: 10) {
                                historyEventIcon(event.type)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(historyEventText(event.type))
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(formatFullDate(event.timestamp))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                    }
                }

                Text("\(monitor.eventHistory.count) " + L10n.eventHistory)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.leading, 4)
            }
        }
    }

    // MARK: - 关于 Tab
    private var aboutContent: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)

            // App 图标
            VStack {
                if let icon = appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "shield.checkmark.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.neonGreen)
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .neonGreen.opacity(0.3), radius: 12, y: 0)

            Spacer().frame(height: 16)

            Text("ProxyGuard")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 2)

            Text(L10n.aboutDescription)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 12)

            Spacer()

            VStack(spacing: 4) {
                Text("Author: monokoo")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                Text("Created by ClaudeCode in Antigravity")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 通用组件

    private func settingsSectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.neonBlue)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.bottom, 4)
    }

    private func darkCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func darkToggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(.neonBlue)
        }
        .padding(14)
    }

    // MARK: - 文件选择器 (功能不变)
    private func selectClashConfigFile() {
        let panel = NSOpenPanel()
        panel.title = L10n.clashConfigPath
        panel.allowedContentTypes = [.yaml]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let defaultDir = (configStore.config.clashConfigPath as NSString).expandingTildeInPath
        let dirURL = URL(fileURLWithPath: defaultDir).deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: dirURL.path) {
            panel.directoryURL = dirURL
        }
        if panel.runModal() == .OK, let url = panel.url {
            let homePath = NSHomeDirectory()
            if url.path.hasPrefix(homePath) {
                configStore.config.clashConfigPath = "~" + url.path.dropFirst(homePath.count)
            } else {
                configStore.config.clashConfigPath = url.path
            }
        }
    }

    // MARK: - 事件辅助 (功能不变)

    private func historyEventIcon(_ type: ProxyEventType) -> some View {
        Group {
            switch type {
            case .restored:
                Image(systemName: "arrow.clockwise.circle.fill").foregroundColor(.neonGreen)
            case .restoredToProxyman:
                Image(systemName: "arrow.2.circlepath").foregroundColor(.neonBlue)
            case .closedByClashDead:
                Image(systemName: "xmark.circle.fill").foregroundColor(.neonRed)
            case .skippedClashClosed:
                Image(systemName: "info.circle.fill").foregroundColor(.neonAmber)
            case .skippedNoNeed:
                Image(systemName: "minus.circle.fill").foregroundColor(.white.opacity(0.3))
            case .clearedButNoClash:
                Image(systemName: "info.circle.fill").foregroundColor(.neonAmber)
            case .retrying:
                Image(systemName: "arrow.clockwise").foregroundColor(.neonAmber)
            case .restoreFailed:
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.neonRed)
            }
        }
    }

    private func historyEventText(_ type: ProxyEventType) -> String {
        switch type {
        case .restored: return L10n.proxyRestored
        case .restoredToProxyman: return L10n.restoredToProxyman
        case .closedByClashDead: return L10n.closedByClashDead
        case .skippedClashClosed: return L10n.skippedClashClosed
        case .skippedNoNeed: return L10n.skippedNoNeed
        case .clearedButNoClash: return L10n.clearedNoClash
        case .retrying(let n): return "\(L10n.retrying) (\(n)/\(configStore.config.maxRetryCount))"
        case .restoreFailed(let msg): return L10n.restoreFailed(msg)
        }
    }

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private func formatFullDate(_ date: Date) -> String {
        Self.fullDateFormatter.string(from: date)
    }
}
