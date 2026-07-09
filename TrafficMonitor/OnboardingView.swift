import SwiftUI
import Network

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject private var manager = TrafficManager.shared

    @State private var currentStep = 0
    @State private var urlDraft: String = ""
    @State private var discoveryMode: DiscoveryMode = .manual
    @State private var isScanningMDNS = false

    // mDNS placeholder — in the future these will be populated by real Bonjour scan
    @State private var discoveredDevices: [MDNSDevice] = []

    enum DiscoveryMode {
        case manual, mdns
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.blue.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Step indicator
                StepIndicator(total: 3, current: currentStep)
                    .padding(.top, 28)
                    .padding(.bottom, 20)

                // Step content
                Group {
                    switch currentStep {
                    case 0: WelcomeStep()
                    case 1: ServerStep(
                        urlDraft: $urlDraft,
                        discoveryMode: $discoveryMode,
                        isScanningMDNS: $isScanningMDNS,
                        discoveredDevices: $discoveredDevices
                    )
                    case 2: ConfirmStep(urlDraft: urlDraft)
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                    .padding(.top, 16)

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.spring(response: 0.35)) {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    Spacer()

                    if currentStep < 2 {
                        Button("Next") {
                            if currentStep == 1 {
                                // Save URL before moving on
                                manager.serverURL = urlDraft.isEmpty
                                    ? manager.serverURL
                                    : urlDraft
                            }
                            withAnimation(.spring(response: 0.35)) {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(currentStep == 1 && !isURLValid)
                    } else {
                        Button("Get Started") {
                            manager.serverURL = urlDraft.isEmpty ? manager.serverURL : urlDraft
                            manager.fetchData()
                            // Post notification to close window — AppDelegate handles it.
                            // Set hasCompletedOnboarding after a short delay to avoid
                            // SwiftUI re-render conflicts during window teardown.
                            NotificationCenter.default.post(name: .dismissOnboarding, object: nil)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .frame(width: 460, height: 400)
        .onAppear {
            urlDraft = manager.serverURL
        }
    }

    private var isURLValid: Bool {
        if discoveryMode == .mdns && !discoveredDevices.isEmpty { return true }
        return URL(string: urlDraft) != nil && !urlDraft.isEmpty
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.blue : Color.secondary.opacity(0.25))
                    .frame(width: i == current ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
    }
}

// MARK: - Step 0: Welcome

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .padding(.bottom, 4)

            Text("Welcome to\nTraffic Monitor")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("Monitor your internet traffic right from the menu bar.\nLet's connect to your Raspberry Pi server.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Step 1: Server Setup

struct ServerStep: View {
    @Binding var urlDraft: String
    @Binding var discoveryMode: OnboardingView.DiscoveryMode
    @Binding var isScanningMDNS: Bool
    @Binding var discoveredDevices: [MDNSDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect to Your Server")
                    .font(.title2.bold())
                Text("How would you like to find your Raspberry Pi?")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            // Mode picker
            Picker("", selection: $discoveryMode) {
                Label("Enter address manually", systemImage: "pencil")
                    .tag(OnboardingView.DiscoveryMode.manual)
                Label("Auto-discover on network (mDNS)", systemImage: "antenna.radiowaves.left.and.right")
                    .tag(OnboardingView.DiscoveryMode.mdns)
            }
            .pickerStyle(.radioGroup)
            .padding(.horizontal, 24)

            Divider()
                .padding(.horizontal, 24)

            // Mode content
            if discoveryMode == .manual {
                ManualEntrySection(urlDraft: $urlDraft)
            } else {
                MDNSSection(
                    isScanningMDNS: $isScanningMDNS,
                    discoveredDevices: $discoveredDevices,
                    urlDraft: $urlDraft
                )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Manual Entry Section

struct ManualEntrySection: View {
    @Binding var urlDraft: String
    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        guard let url = URL(string: urlDraft) else { return false }
        return url.scheme != nil && url.host != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server URL")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                TextField("http://192.168.0.1:5000/traffic", text: $urlDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isFocused = true
                        }
                    }
                if !urlDraft.isEmpty {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isValid ? .green : .red)
                        .font(.callout)
                }
            }
            .padding(.horizontal, 24)

            Text("Enter the full URL of your traffic monitor endpoint, e.g. http://raspberrypi.local:5000/traffic")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
        }
    }
}

// MARK: - mDNS Browser

final class MDNSBrowser: ObservableObject {
    @Published var devices: [MDNSDevice] = []
    @Published var isScanning = false

    private var browser: NWBrowser?
    private var resolvers: [String: NWConnection] = [:]

    func startScan() {
        devices = []
        isScanning = true

        let params = NWParameters()
        params.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: nil)
        let b = NWBrowser(for: descriptor, using: params)

        b.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                DispatchQueue.main.async { self?.isScanning = false }
            default: break
            }
        }

        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            for result in results {
                if case let .service(name, type, domain, _) = result.endpoint {
                    // Filter by TXT record app=traffic-monitor
                    if case let .bonjour(txtRecord) = result.metadata {
                        guard case .string(let appValue) = txtRecord.getEntry(for: "app"),
                              appValue == "traffic-monitor" else { continue }
                    }
                    self.resolve(name: name, type: type, domain: domain)
                }
            }
        }

        browser = b
        b.start(queue: .main)

        // Auto-stop scanning indicator after 5 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.isScanning = false
        }
    }

    func stopScan() {
        browser?.cancel()
        browser = nil
        resolvers.values.forEach { $0.cancel() }
        resolvers = [:]
        isScanning = false
    }

    private func resolve(name: String, type: String, domain: String) {
        let endpoint = NWEndpoint.service(name: name, type: type, domain: domain, interface: nil)
        let connection = NWConnection(to: endpoint, using: .tcp)
        resolvers[name] = connection

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .ready = state,
               case let .hostPort(host, port) = connection.currentPath?.remoteEndpoint ?? .hostPort(host: "unknown", port: 0) {
                // Strip zone ID suffix (e.g. "192.168.0.106%en1" → "192.168.0.106")
                let rawHost: String
                switch host {
                case .name(let h, _): rawHost = h
                case .ipv4(let a):    rawHost = "\(a)"
                case .ipv6(let a):    rawHost = "\(a)"
                @unknown default:     rawHost = "unknown"
                }
                let hostStr = rawHost.components(separatedBy: "%").first ?? rawHost
                let device = MDNSDevice(id: name, name: name, host: hostStr, port: Int(port.rawValue))
                DispatchQueue.main.async {
                    if !self.devices.contains(where: { $0.id == name }) {
                        self.devices.append(device)
                    }
                }
                connection.cancel()
                self.resolvers.removeValue(forKey: name)
            }
        }
        connection.start(queue: .main)
    }
}

// MARK: - mDNS Section

struct MDNSSection: View {
    @Binding var isScanningMDNS: Bool
    @Binding var discoveredDevices: [MDNSDevice]
    @Binding var urlDraft: String

    @StateObject private var mdnsBrowser = MDNSBrowser()
    @State private var selectedDevice: MDNSDevice?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Discovered Devices")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    mdnsBrowser.startScan()
                } label: {
                    Label(mdnsBrowser.isScanning ? "Scanning…" : "Scan", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(mdnsBrowser.isScanning)
            }
            .padding(.horizontal, 24)

            if mdnsBrowser.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching for traffic monitors on your network…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 24)
            } else if mdnsBrowser.devices.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                    Text("No devices found.\nMake sure your server is running and on the same network.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(mdnsBrowser.devices) { device in
                            MDNSDeviceRow(device: device, isSelected: selectedDevice?.id == device.id)
                                .onTapGesture {
                                    selectedDevice = device
                                    urlDraft = device.url
                                    // sync upward
                                    discoveredDevices = mdnsBrowser.devices
                                }
                        }
                    }
                }
                .frame(maxHeight: 120)
                .padding(.horizontal, 24)
            }

            Label("Tap Scan to find Traffic Monitor servers on your local network.", systemImage: "info.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
        }
        .onAppear {
            mdnsBrowser.startScan()
        }
        .onDisappear {
            mdnsBrowser.stopScan()
        }
        .onChange(of: mdnsBrowser.devices) { newDevices in
            discoveredDevices = newDevices
            isScanningMDNS = mdnsBrowser.isScanning
        }
        .onChange(of: mdnsBrowser.isScanning) { scanning in
            isScanningMDNS = scanning
        }
    }
}

// MARK: - mDNS Device Row

struct MDNSDeviceRow: View {
    let device: MDNSDevice
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .foregroundStyle(.blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.callout.bold())
                Text(device.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
                    .font(.caption.bold())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue.opacity(0.4) : .clear, lineWidth: 1)
        )
    }
}

// MARK: - Step 2: Confirmation

struct ConfirmStep: View {
    let urlDraft: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.green)

            Text("All Set!")
                .font(.title.bold())

            VStack(spacing: 6) {
                Text("Your server address has been saved.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if !urlDraft.isEmpty {
                    Text(urlDraft)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Text("Traffic Monitor will appear in your menu bar.\nYou can change these settings anytime via the ⚙ gear icon.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - MDNSDevice Model

struct MDNSDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let host: String
    let port: Int
    var url: String { "http://\(host):\(port)/traffic" }
}

// MARK: - Notifications

extension Notification.Name {
    static let dismissOnboarding = Notification.Name("dismissOnboarding")
}
