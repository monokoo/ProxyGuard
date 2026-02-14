import SwiftUI
import AppKit

struct MenuBarView: View {

    @ObservedObject var monitor: ProxyMonitor
    @ObservedObject var configStore: ConfigStore

    // Neon glow animation state
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // 1. Global Background
            Color.brandGradient
                .ignoresSafeArea()
            
            // 2. Content
            VStack(spacing: DesignSystem.spacingM) {
                headerSection
                
                // Scrollable Content Area
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: DesignSystem.spacingM) {
                        statsGrid
                        controlSection
                        systemProxySection
                        connectionSection
                        eventLogSection
                    }
                    .padding(.horizontal, DesignSystem.spacingM)
                    .padding(.bottom, 4) // Reduced bottom padding
                }
                
                footerSection
                    .padding(.top, -DesignSystem.spacingS) // Pull footer up slightly
            }
        }
        .frame(width: 320, height: 500) // Fixed size for consistent "Pro" feel
        .onAppear {
            isAnimating = true
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            // Icon with Glow
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .blur(radius: isAnimating ? 8 : 4)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                
                Image(systemName: "shield.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("ProxyGuard")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(statusText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            // Global Action Button
            // Global Action Button
            // Global Action Button
            CustomTooltipButton(
                tooltip: monitor.isPaused ? L10n.resumeGuard : L10n.pauseGuard,
                action: { monitor.isPaused.toggle() }
            ) {
                Image(systemName: monitor.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.8))
            }
        }

        .padding(.top, DesignSystem.spacingL)
        .padding(.horizontal, DesignSystem.spacingL)
    }

    // MARK: - Stats Grid (Port Info)
    private var statsGrid: some View {
        HStack(spacing: DesignSystem.spacingS) {
            // HTTP
            PortStatItem(
                label: "HTTP",
                value: "\(monitor.currentState.httpPort ?? 7890)",
                icon: "globe",
                isActive: monitor.currentState.httpEnabled
            )
            
            // HTTPS
            let httpsActive = monitor.currentState.httpsEnabled || (monitor.currentState.httpEnabled && monitor.currentState.httpsPort == nil)
            let httpsValue: String = {
                if let port = monitor.currentState.httpsPort { return "\(port)" }
                return "\(monitor.currentState.httpPort ?? 7890)" 
            }()
            
            PortStatItem(
                label: "HTTPS",
                value: httpsValue,
                icon: "lock.shield",
                isActive: httpsActive
            )
            
            // SOCKS5
            PortStatItem(
                label: "SOCKS5",
                value: "\(monitor.currentState.socksPort ?? 7891)",
                icon: "point.3.connected.trianglepath.dotted",
                isActive: monitor.currentState.socksEnabled
            )
        }
        // Block ALL animation transactions from parent (breathing glow etc.)
        .transaction { $0.animation = nil }
    }
    
struct PortStatItem: View, Equatable {
    let label: String
    let value: String
    let icon: String
    let isActive: Bool
    
    // Strict equality check to prevent needless redraws
    static func == (lhs: PortStatItem, rhs: PortStatItem) -> Bool {
        return lhs.label == rhs.label &&
               lhs.value == rhs.value &&
               lhs.icon == rhs.icon &&
               lhs.isActive == rhs.isActive
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(isActive ? .white.opacity(0.6) : .white.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isActive ? .white.opacity(0.5) : .white.opacity(0.2))
                
                // Use ZStack with invisible placeholder to lock width strictly
                // DOUBLE LAYER RENDERING
                ZStack(alignment: .leading) {
                    // 1. Invisible placeholder (widest possible value)
                    Text("88888")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .opacity(0)
                        .accessibilityHidden(true)
                    
                    // 2. The Value
                    Text(value)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .opacity(isActive ? 1 : 0)
                    
                    // 3. The Placeholder "--"
                    Text("--")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .opacity(isActive ? 0 : 1)
                }
                .frame(height: 16) // Fixed height
            }
            Spacer()
        }
        .padding(10)
        .frame(height: 40) // 统一卡片高度
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(isActive ? 0.15 : 0.06), lineWidth: 0.5)
        )
        // Fixed frame
        .frame(maxWidth: .infinity)
        // Disable implicit animations
        .animation(nil, value: isActive)
        .animation(nil, value: value)
        // GPU-accelerated off-screen rendering to isolate from material compositing
        .drawingGroup()
    }
}

    // MARK: - Control Section
    private var controlSection: some View {
        VStack(spacing: 0) {
            ToggleRow(
                icon: "arrow.clockwise.circle",
                title: L10n.autoRestore,
                isOn: $configStore.config.autoRestoreEnabled
            )
        }
        .padding(DesignSystem.spacingS)
        .frame(height: 40) // 统一卡片高度
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusM))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.radiusM)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - System Proxy Status
    private var systemProxySource: String {
        guard monitor.currentState.isActive else { return L10n.current == .zh ? "关闭" : "Off" }
        if let port = monitor.currentState.httpPort,
           port == configStore.config.proxymanPort {
            return "Proxyman"
        }
        return "Clash Verge"
    }

    private var systemProxyIcon: String {
        guard monitor.currentState.isActive else { return "xmark.circle" }
        if let port = monitor.currentState.httpPort,
           port == configStore.config.proxymanPort {
            return "eye.fill"
        }
        return "arrow.triangle.2.circlepath"
    }

    private var systemProxyColor: Color {
        guard monitor.currentState.isActive else { return .gray }
        return .neonGreen
    }

    private var systemProxySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.current == .zh ? "系统代理" : "System Proxy")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 4)

            HStack(spacing: 10) {
                Image(systemName: systemProxyIcon)
                    .font(.system(size: 12))
                    .foregroundColor(systemProxyColor)

                Text(systemProxySource)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(monitor.currentState.isActive ? .white : .white.opacity(0.4))

                Spacer()

                Circle()
                    .fill(systemProxyColor)
                    .frame(width: 7, height: 7)
                    .shadow(color: monitor.currentState.isActive ? systemProxyColor : .clear, radius: 4)
            }
            .padding(.horizontal, 14)
            .frame(height: 40) // 统一卡片高度
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.radiusS))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.radiusS)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Connection Status
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.processStatus)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .padding(.leading, 4)
            
            HStack(spacing: 0) {
                connectionPill(
                    name: "Clash Verge",
                    icon: "arrow.triangle.2.circlepath",
                    isRunning: monitor.isClashVergeRunning,
                    color: .neonGreen
                )
                Spacer()
                connectionPill(
                    name: "Proxyman",
                    icon: "eye.fill",
                    isRunning: monitor.isProxymanRunning,
                    color: .neonGreen
                )
            }
        }
    }
    
    private func connectionPill(name: String, icon: String, isRunning: Bool, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(isRunning ? color : Color.gray)
            
            Circle()
                .fill(isRunning ? color : Color.gray)
                .frame(width: 6, height: 6)
                .shadow(color: isRunning ? color : .clear, radius: 4)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isRunning ? .white : .white.opacity(0.4))
                
                Text(isRunning ? L10n.runningStatus : L10n.notRunning)
                    .font(.system(size: 8))
                    .foregroundColor(isRunning ? color.opacity(0.8) : .white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40) // 统一卡片高度
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.5))
    }

    // MARK: - Event Log
    private var eventLogSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.recentEvents)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            .padding(.leading, 4)
            
            if monitor.eventHistory.isEmpty {
                Text(L10n.noEventsYet)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.08).opacity(0.5))
                    .cornerRadius(8)
            } else {
                ForEach(monitor.eventHistory.prefix(3)) { event in
                    HStack(spacing: 8) {
                        // Icon based on event type
                        Image(systemName: eventIcon(event.type))
                            .font(.system(size: 10))
                            .foregroundColor(eventColor(event.type))
                            .frame(width: 16)
                            
                        Text(eventText(event.type))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                            
                        Spacer()
                        
                        Text(formatEventDate(event.timestamp))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Footer
    private var footerSection: some View {
        HStack {
            CustomTooltipButton(
                tooltip: L10n.openSettings,
                edge: .top,
                action: { SettingsWindowManager.shared.open(configStore: configStore, monitor: monitor) }
            ) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Button(L10n.resetProxy) {
                monitor.restoreToClash()
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)

            Spacer()
            
            CustomTooltipButton(
                tooltip: L10n.quitApp,
                edge: .top,
                action: { NSApplication.shared.terminate(nil) }
            ) {
                Image(systemName: "power")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, DesignSystem.spacingL)
        .padding(.bottom, DesignSystem.spacingL)
        .padding(.top, DesignSystem.spacingS)
        .background(
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.4)], startPoint: .top, endPoint: .bottom)
        )
    }
    
    // MARK: - Helpers & Computed Props
    
    private var statusColor: Color {
        if monitor.isPaused { return .orange }
        if !configStore.config.autoRestoreEnabled { return .neonRed }
        return .neonGreen // 自动恢复开启 = 守护中，始终绿色
    }
    
    private var statusText: String {
        if monitor.isPaused { return L10n.monitoringPaused }
        if !configStore.config.autoRestoreEnabled { return L10n.guardDisabled }
        return L10n.systemSecure // 自动恢复开启 = 始终显示守护中
    }
    
    private func eventColor(_ type: ProxyEventType) -> Color {
        switch type {
        case .restored, .restoredToProxyman: return .neonGreen
        case .closedByClashDead, .restoreFailed: return .neonRed
        case .skippedClashClosed, .clearedButNoClash: return .neonAmber
        default: return .white.opacity(0.5)
        }
    }

    private func eventIcon(_ type: ProxyEventType) -> String {
        switch type {
        case .restored, .restoredToProxyman: return "checkmark.circle.fill"
        case .closedByClashDead, .restoreFailed: return "xmark.circle.fill"
        case .skippedClashClosed, .clearedButNoClash: return "minus.circle.fill"
        case .retrying: return "arrow.clockwise.circle.fill"
        default: return "info.circle.fill"
        }
    }

    private func eventText(_ type: ProxyEventType) -> String {
        switch type {
        case .restored: return L10n.proxyRestored
        case .restoredToProxyman: return L10n.restoredToProxyman
        case .closedByClashDead: return L10n.closedByClashDead
        case .skippedClashClosed: return L10n.skippedClashClosed
        case .skippedNoNeed: return L10n.skippedNoNeed
        case .clearedButNoClash: return L10n.clearedNoClash
        case .retrying(let n): return "\(L10n.retrying) (\(n))"
        case .restoreFailed(let msg): return msg
        }
    }
    
    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// Custom Button Style to remove system background and add press effect
// Absolutely no background button style
// Custom Button with Manual Tooltip
struct CustomTooltipButton<Label: View>: View {
    let tooltip: String
    var edge: Edge = .bottom // .top or .bottom
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(NoBackgroundButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .overlay(
            Group {
                if isHovering {
                    Text(tooltip)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial) // Translucent background
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                        .offset(y: edge == .top ? -24 : 24) // Dynamic offset
                        .fixedSize()
                        .allowsHitTesting(false)
                        .zIndex(100)
                }
            }
        )
    }
}

// Absolutely no background button style
struct NoBackgroundButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Circle()) // Important: specific shape for hit testing
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Helper Component
struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isOn ? .neonBlue : .white.opacity(0.4))
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .neonBlue))
                .scaleEffect(0.8)
        }
        .padding(8)
    }
}
