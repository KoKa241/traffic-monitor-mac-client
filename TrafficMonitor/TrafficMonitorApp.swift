import SwiftUI
import Combine

@main
struct TrafficMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .onOpenURL { _ in
                    appDelegate.openSettingsWindow()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Traffic Monitor") {
                    appDelegate.showAboutPanel()
                }
            }
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?

    private var cancellables = Set<AnyCancellable>()
    private var isFinishedLaunching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Элемент статус-бара
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Traffic Monitor")
            button.imagePosition = .imageLeft
            button.action = #selector(togglePopover(_:))
            button.target = self

            // Подписываемся на данные — обновляем текст в статус-баре
            TrafficManager.shared.$trafficData
                .receive(on: DispatchQueue.main)
                .sink { [weak self] data in
                    self?.updateStatusBarTitle(data: data)
                }
                .store(in: &cancellables)

            // Обновляем заголовок при изменении настроек
            NotificationCenter.default
                .publisher(for: UserDefaults.didChangeNotification)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateStatusBarTitle(data: TrafficManager.shared.trafficData)
                }
                .store(in: &cancellables)
        }

        // 2. Popover
        popover.contentSize = NSSize(width: 270, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())

        // 3. Скрываем из Dock
        NSApp.setActivationPolicy(.accessory)

        // 4. Listen for "dismiss onboarding" notification from the Get Started button
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDismissOnboarding),
            name: .dismissOnboarding,
            object: nil
        )

        // 5. Показываем onboarding если первый запуск
        let hasOnboarded = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasOnboarded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.showOnboarding()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isFinishedLaunching = true
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard isFinishedLaunching else { return false }
        openSettingsWindow()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        openSettingsWindow()
    }

    // MARK: - Status Bar

    private func updateStatusBarTitle(data: TrafficData?) {
        let showIcon = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        statusItem?.isVisible = showIcon

        if !showIcon {
            showDockIcon()
            return
        }

        guard let data else {
            statusItem?.button?.title = " …"
            return
        }
        let fraction = data.day_limit > 0 ? data.day_gb / data.day_limit : 0
        let showPct = UserDefaults.standard.object(forKey: "showPercentInBar") as? Bool ?? true
        if showPct {
            statusItem?.button?.title = String(format: " %.2f GB (%d%%)", data.day_gb, Int(fraction * 100))
        } else {
            statusItem?.button?.title = String(format: " %.2f GB", data.day_gb)
        }
    }

    // MARK: - Dock Icon

    /// Show Dock icon when any managed window is visible; hide when all are closed.
    private func showDockIcon() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
    }

    private func hideDockIconIfNoWindows() {
        let showIcon = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true
        if !showIcon {
            showDockIcon()
            return
        }
        let hasVisible = (onboardingWindow?.isVisible == true) || (settingsWindow?.isVisible == true)
        if !hasVisible {
            // Small delay lets the closing animation finish before removing from Dock
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    // MARK: - Onboarding

    @objc func showOnboarding() {
        if onboardingWindow == nil {
            let hostingView = NSHostingView(rootView: OnboardingView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Welcome to Traffic Monitor"
            window.titlebarAppearsTransparent = true
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = true
            window.delegate = self
            onboardingWindow = window
        }

        showDockIcon()
        onboardingWindow?.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func handleDismissOnboarding() {
        // Close window first, then mark onboarding as complete after a short delay
        // so SwiftUI doesn't re-render mid-teardown
        onboardingWindow?.close()
        onboardingWindow = nil
        hideDockIconIfNoWindows()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
    }

    // MARK: - Popover

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            TrafficManager.shared.fetchData()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - Settings

    @objc func openSettingsWindow() {
        if settingsWindow == nil {
            let hostingView = NSHostingView(rootView: SettingsView())
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 380),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.setFrameAutosaveName("TrafficMonitorPreferences")
            window.title = "Preferences"
            window.contentView = hostingView
            window.isReleasedWhenClosed = false
            window.toolbarStyle = .unified
            window.delegate = self
            settingsWindow = window
        }

        showDockIcon()
        settingsWindow?.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - About

    @objc func showAboutPanel() {
        let creditsText = "Created by KoKa241\nhttps://github.com/KoKa241"
        let credits = NSMutableAttributedString(string: creditsText)
        if let range = creditsText.range(of: "https://github.com/KoKa241") {
            let nsRange = NSRange(range, in: creditsText)
            credits.addAttribute(.link, value: "https://github.com/KoKa241", range: nsRange)
        }

        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .credits: credits,
            .applicationName: "Traffic Monitor"
        ]

        showDockIcon()
        NSApp.orderFrontStandardAboutPanel(options: options)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        hideDockIconIfNoWindows()
    }
}
