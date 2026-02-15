import SwiftUI

@main
struct ProxyGuardApp: App {

    @State private var configStore = ConfigStore.shared
    @State private var monitor: ProxyMonitor = {
        let m = ProxyMonitor(configStore: ConfigStore.shared)
        m.startMonitoring()
        return m
    }()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(monitor: monitor, configStore: configStore)
                .onAppear {
                    LogManager.shared.log("=== ProxyGuard Started ===")
                    LogManager.shared.log("App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: menuBarIcon.name)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(menuBarIcon.primary, menuBarIcon.secondary)
                Text("PG")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: (name: String, primary: Color, secondary: Color) {
        if monitor.isPaused {
            return ("shield.slash.fill", .orange, .gray)
        } else if monitor.currentState.isActive {
            return ("shield.checkmark.fill", .green, .green)
        } else {
            return ("shield.trianglebadge.exclamationmark.fill", .red, .yellow)
        }
    }
}

final class SettingsWindowManager {

    static let shared = SettingsWindowManager()

    private var window: NSWindow?

    private init() {}

    func open(configStore: ConfigStore, monitor: ProxyMonitor) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(configStore: configStore, monitor: monitor)
        let hostingView = NSHostingView(rootView: settingsView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: DesignSystem.settingsWidth, height: DesignSystem.settingsHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = L10n.settingsWindowTitle
        newWindow.contentView = hostingView
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.appearance = NSAppearance(named: .darkAqua)
        newWindow.backgroundColor = .clear
        newWindow.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.window = newWindow
    }
}
