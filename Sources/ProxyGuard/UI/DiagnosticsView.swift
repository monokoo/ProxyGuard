import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var monitor: ProxyMonitor
    @ObservedObject var configStore: ConfigStore
    
    @State private var report: String = L10n.loadingReport
    @State private var timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            
            // 系统代理状态
            proxyStatusCard
            
            // 进程状态报告
            processReportCard
        }
        .onAppear {
            refreshReport()
        }
        .onReceive(timer) { _ in
            refreshReport()
        }
    }
    
    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "stethoscope")
                .font(.system(size: 12))
                .foregroundColor(.neonBlue)
            Text(L10n.diagnosticsTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Button {
                refreshReport()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
            .buttonStyle(.plain)
            .help(L10n.refreshReport)
        }
        .padding(.bottom, 4)
    }
    
    private var proxyStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.currentProxyStatus)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            HStack(spacing: 20) {
                statusRow(label: "HTTP", enabled: monitor.currentState.httpEnabled, port: monitor.currentState.httpPort)
                statusRow(label: "HTTPS", enabled: monitor.currentState.httpsEnabled, port: monitor.currentState.httpsPort)
                statusRow(label: "SOCKS", enabled: monitor.currentState.socksEnabled, port: monitor.currentState.socksPort)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    private var processReportCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.processReport)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            ScrollView {
                Text(report)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 200)
            .background(Color.black.opacity(0.3))
            .cornerRadius(6)
        }
        .padding(14)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    private func refreshReport() {
        // Run in background to avoid blocking main thread if file IO needed
        DispatchQueue.global(qos: .userInitiated).async {
            let config = ClashConfigReader.readConfig(from: configStore.config.clashConfigPath)
            let hint = config?.kernelName
            let text = ProcessChecker.getDiagnosticsReport(kernelHint: hint)
            
            DispatchQueue.main.async {
                self.report = text
            }
        }
    }

    private func statusRow(label: String, enabled: Bool, port: Int?) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(enabled ? Color.neonGreen : Color.red)
                .frame(width: 8, height: 8)
                .shadow(color: (enabled ? Color.neonGreen : Color.red).opacity(0.5), radius: 2)
            
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            
            if enabled, let p = port {
                Text(":\(p.formatted(.number.grouping(.never)))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            } else if !enabled {
                Text(L10n.statusOff)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
    }
}
