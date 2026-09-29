import SwiftUI
import ServiceManagement

// MARK: - ContentView (Popover)

struct ContentView: View {
    @StateObject private var manager = TrafficManager.shared
    @AppStorage("refreshInterval") private var interval: Double = 60.0
    @AppStorage("showDailyBar") private var showDailyBar: Bool = true
    @AppStorage("showPingSection") private var showPingSection: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // ── Заголовок ──────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .foregroundStyle(.blue)
                    .font(.callout)
                Text("Traffic Monitor")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // ── Основной контент ───────────────────────────────────────
            Group {
                if let data = manager.trafficData {
                    VStack(spacing: 14) {
                        if showDailyBar {
                            TrafficBar(
                                title: "Today",
                                value: data.day_gb,
                                total: data.day_limit
                            )
                        }
                        TrafficBar(
                            title: "This Month",
                            value: data.month_gb,
                            total: data.month_limit
                        )

                        // ── Ping секция ────────────────────────────────────
                        if showPingSection, let ping = data.ping {
                            Divider()
                            PingSection(ping: ping)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                } else if let error = manager.errorMessage {
                    VStack(spacing: 6) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.title2)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)

                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }

            Divider()

            // ── Нижняя панель ──────────────────────────────────────────
            HStack {
                Text(manager.lastUpdated)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    manager.fetchData()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh Now")

                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("Preferences")

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 270)
        .onAppear { manager.fetchData() }
        .onChange(of: interval) { _ in
            manager.setupTimer()
        }
    }

    private func openSettings() {
        NSApp.sendAction(#selector(AppDelegate.openSettingsWindow), to: nil, from: nil)
    }
}

// MARK: - PingSection

struct PingSection: View {
    let ping: PingData

    @AppStorage("pingShow_avgLatency")    private var showAvgLatency:    Bool = true
    @AppStorage("pingShow_worstLatency") private var showWorstLatency:  Bool = true
    @AppStorage("pingShow_latestLatency") private var showLatestLatency: Bool = true
    @AppStorage("pingShow_avgLoss")      private var showAvgLoss:       Bool = true
    @AppStorage("pingShow_worstLoss")    private var showWorstLoss:     Bool = true
    @AppStorage("pingShow_latestLoss")   private var showLatestLoss:    Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.blue)
                    .font(.caption)
                Text("Ping – \(ping.target)")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(ping.total_checks) checks")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 3) {
                if showAvgLatency {
                    PingRow(label: "Avg latency",
                            value: String(format: "%.1f ms", ping.avg_latency_ms),
                            isWarning: ping.avg_latency_ms > 100)
                }
                if showWorstLatency {
                    PingRow(label: "Worst latency",
                            value: String(format: "%.1f ms", ping.worst_latency_ms),
                            isWarning: ping.worst_latency_ms > 150)
                }
                if showLatestLatency {
                    PingRow(label: "Latest latency",
                            value: String(format: "%.1f ms", ping.latest_latency_ms),
                            isWarning: ping.latest_latency_ms > 100)
                }
                if showAvgLoss {
                    PingRow(label: "Avg loss",
                            value: String(format: "%.1f%%", ping.avg_packet_loss),
                            isWarning: ping.avg_packet_loss > 1)
                }
                if showWorstLoss {
                    PingRow(label: "Worst loss",
                            value: String(format: "%.1f%%", ping.max_packet_loss),
                            isWarning: ping.max_packet_loss > 5)
                }
                if showLatestLoss {
                    PingRow(label: "Latest loss",
                            value: String(format: "%.1f%%", ping.latest_packet_loss),
                            isWarning: ping.latest_packet_loss > 1)
                }
            }
        }
    }
}

// MARK: - PingRow

struct PingRow: View {
    let label: String
    let value: String
    var isWarning: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isWarning ? .orange : .primary)
        }
    }
}

// MARK: - TrafficBar

struct TrafficBar: View {
    let title: String
    let value: Double
    let total: Double

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(value / total, 1.0)
    }

    /// Цвет зависит от использования: зелёный → жёлтый → красный
    private var barColor: Color {
        switch fraction {
        case ..<0.6: return .green
        case ..<0.8: return .yellow
        default:     return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: "%.2f / %.1f GB  (%.0f%%)",
                            value, total, fraction * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize()
            }

            GeometryReader { geo in
                // Трек (серый фон)
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)
                    .frame(height: 8)

                // Заполнение
                if fraction > 0 {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.gradient)
                        .frame(width: max(8, geo.size.width * fraction), height: 8)
                        .animation(.easeInOut(duration: 0.4), value: fraction)
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

// MARK: - SettingsView (Tabbed)

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case server = "Server"
        case system = "System"
        case about = "About"
        var id: Self { self }

        var icon: String {
            switch self {
            case .general: return "slider.horizontal.3"
            case .server:  return "server.rack"
            case .system:  return "gearshape.2"
            case .about:   return "info.circle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsTabButton(tab: tab, selectedTab: $selectedTab)
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)

            Divider()
                .padding(.top, 8)

            // Tab content
            Group {
                switch selectedTab {
                case .general: GeneralSettingsTab()
                case .server:  ServerSettingsTab()
                case .system:  SystemSettingsTab()
                case .about:   AboutSettingsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400, height: 380)
    }
}

// MARK: - About Tab

struct AboutSettingsTab: View {
    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2.0"
        return "Version \(version)"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "network")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 4) {
                Text("Traffic Monitor")
                    .font(.title2.bold())
                
                Text(versionString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("Created by")
                        .foregroundStyle(.secondary)
                    Link("KoKa241", destination: URL(string: "https://github.com/KoKa241")!)
                        .font(.body.weight(.semibold))
                }
                .font(.callout)

                Link(destination: URL(string: "https://github.com/KoKa241/traffic-monitor-mac-client")!) {
                    Label("View Repository on GitHub", systemImage: "arrow.up.right.square")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}

// MARK: - Tab Button

struct SettingsTabButton: View {
    let tab: SettingsView.SettingsTab
    @Binding var selectedTab: SettingsView.SettingsTab

    var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)
                Text(tab.rawValue)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Color.blue.opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue.opacity(0.25) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Server Tab

struct ServerSettingsTab: View {
    @ObservedObject private var manager = TrafficManager.shared
    @State private var urlDraft: String = ""
    @State private var showApplied = false
    @State private var isScanningMDNS = false
    @State private var discoveredDevices: [MDNSDevice] = []
    @FocusState private var isTextFieldFocused: Bool

    private var isValid: Bool {
        guard let url = URL(string: urlDraft) else { return false }
        return url.scheme != nil && url.host != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // URL field
                VStack(alignment: .leading, spacing: 6) {
                    Label("Server URL", systemImage: "link")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        TextField("http://host:port/traffic", text: $urlDraft)
                            .textFieldStyle(.roundedBorder)
                            .focused($isTextFieldFocused)
                            .onAppear {
                                urlDraft = manager.serverURL
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isTextFieldFocused = true
                                }
                            }

                        if !urlDraft.isEmpty {
                            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(isValid ? .green : .red)
                                .font(.callout)
                        }
                    }

                    Text("Full URL of your Raspberry Pi traffic endpoint, e.g. http://raspberrypi.local:5000/traffic")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Apply / status row
                HStack {
                    Button {
                        manager.serverURL = urlDraft
                        manager.fetchData()
                        showApplied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showApplied = false }
                    } label: {
                        Label(
                            showApplied ? "Applied!" : "Apply & Refresh",
                            systemImage: showApplied ? "checkmark" : "arrow.clockwise"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!isValid)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(manager.errorMessage == nil && manager.trafficData != nil ? Color.green : Color.red)
                            .frame(width: 7, height: 7)
                        Text(manager.errorMessage == nil && manager.trafficData != nil
                             ? "Connected"
                             : (manager.errorMessage ?? "Not connected"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // mDNS discovery
                Label("Auto-discover on Network (mDNS)", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                MDNSSection(
                    isScanningMDNS: $isScanningMDNS,
                    discoveredDevices: $discoveredDevices,
                    urlDraft: $urlDraft
                )
            }
            .padding(20)
        }
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @AppStorage("refreshInterval")  private var interval:         Double = 60.0
    @AppStorage("showMenuBarIcon")  private var showMenuBarIcon:  Bool   = true
    @AppStorage("showDailyBar")     private var showDailyBar:     Bool   = true
    @AppStorage("showPercentInBar") private var showPercentInBar: Bool   = true
    @AppStorage("showPingSection")  private var showPingSection:  Bool   = true

    @AppStorage("pingShow_avgLatency")    private var pingAvgLatency:    Bool = true
    @AppStorage("pingShow_worstLatency")  private var pingWorstLatency:  Bool = true
    @AppStorage("pingShow_latestLatency") private var pingLatestLatency: Bool = true
    @AppStorage("pingShow_avgLoss")       private var pingAvgLoss:       Bool = true
    @AppStorage("pingShow_worstLoss")     private var pingWorstLoss:     Bool = true
    @AppStorage("pingShow_latestLoss")    private var pingLatestLoss:    Bool = true

    private var intervalLabel: String {
        let mins = interval / 60
        if mins < 1 {
            return "\(Int(interval))s"
        } else if mins.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(mins)) min"
        } else {
            return String(format: "%.1f min", mins)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Refresh Interval ─────────────────────────────────────
                SettingsSection(title: "Refresh Interval", icon: "clock") {
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Slider(value: $interval, in: 30...900, step: 30)
                            Text(intervalLabel)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.primary)
                                .frame(width: 48, alignment: .trailing)
                        }
                        HStack {
                            Text("30s")
                            Spacer()
                            Text("15 min")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                // ── Display Options ──────────────────────────────────────
                SettingsSection(title: "Display", icon: "eye") {
                    VStack(spacing: 0) {
                        SettingsRow(label: "Show menu bar icon") {
                            Toggle("", isOn: $showMenuBarIcon)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                        Divider().padding(.leading, 14)
                        SettingsRow(label: "Show daily traffic bar") {
                            Toggle("", isOn: $showDailyBar)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                        Divider().padding(.leading, 14)
                        SettingsRow(label: "Show percentage in menu bar") {
                            Toggle("", isOn: $showPercentInBar)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                        Divider().padding(.leading, 14)
                        SettingsRow(label: "Show ping section") {
                            Toggle("", isOn: $showPingSection)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                        }
                    }
                }

                // ── Ping Metrics ──────────────────────────────────────
                if showPingSection {
                    SettingsSection(title: "Ping Metrics", icon: "antenna.radiowaves.left.and.right") {
                        VStack(spacing: 0) {
                            SettingsRow(label: "Avg latency") {
                                Toggle("", isOn: $pingAvgLatency)
                                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                            }
                            Divider().padding(.leading, 14)
                            SettingsRow(label: "Worst latency") {
                                Toggle("", isOn: $pingWorstLatency)
                                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                            }
                            Divider().padding(.leading, 14)
                            SettingsRow(label: "Latest latency") {
                                Toggle("", isOn: $pingLatestLatency)
                                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                            }
                            Divider().padding(.leading, 14)
                            SettingsRow(label: "Avg packet loss") {
                                Toggle("", isOn: $pingAvgLoss)
                                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                            }
                            Divider().padding(.leading, 14)
                            SettingsRow(label: "Worst packet loss") {
                                Toggle("", isOn: $pingWorstLoss)
                                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                            }
                            Divider().padding(.leading, 14)
                            SettingsRow(label: "Latest packet loss") {
                                Toggle("", isOn: $pingLatestLoss)
                                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                            }
                        }
                    }
                    .transition(.opacity)
                }

            }
            .padding(16)
        }
    }
}

// MARK: - System Tab

struct SystemSettingsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Startup ───────────────────────────────────────────────
                SettingsSection(title: "Startup", icon: "power") {
                    SettingsRow(label: "Launch at Login") {
                        LaunchAtLoginToggle(compact: true)
                    }
                }

                #if DEBUG
                // ── Developer ─────────────────────────────────────────────
                SettingsSection(title: "Developer", icon: "hammer") {
                    SettingsRow(label: "Setup Wizard") {
                        Button("Re-run") {
                            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                            NSApp.sendAction(#selector(AppDelegate.showOnboarding), to: nil, from: nil)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                #endif

            }
            .padding(16)
        }
    }
}

// MARK: - Launch at Login Toggle (SMAppService, macOS 13+)

struct LaunchAtLoginToggle: View {
    /// When `compact = true` only the Toggle switch is rendered (no label);
    /// the label is provided externally by `SettingsRow`.
    var compact: Bool = false

    @State private var isEnabled = false
    @State private var errorMsg: String?
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if compact {
                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .onChange(of: isEnabled) { newValue in
                        guard hasAppeared else { return }
                        setLaunchAtLogin(newValue)
                    }
                    .onAppear {
                        refreshStatus()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            hasAppeared = true
                        }
                    }
            } else {
                Toggle("Launch at Login", isOn: $isEnabled)
                    .onChange(of: isEnabled) { newValue in
                        guard hasAppeared else { return }
                        setLaunchAtLogin(newValue)
                    }
                    .onAppear {
                        refreshStatus()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            hasAppeared = true
                        }
                    }
            }

            if let msg = errorMsg {
                Text(msg)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func refreshStatus() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                errorMsg = nil
            } catch {
                errorMsg = "Error: \(error.localizedDescription)"
                // revert toggle without triggering onChange again
                hasAppeared = false
                isEnabled = !enable
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    hasAppeared = true
                }
            }
        }
    }
}

// MARK: - Settings Card Section

/// A titled, rounded-card section for the settings window.
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section header
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            // Card
            VStack(spacing: 0) {
                content
            }
            .background(.background.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
    }
}

// MARK: - Settings Row

/// A single horizontal row inside a SettingsSection card.
struct SettingsRow<Trailing: View>: View {
    let label: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
