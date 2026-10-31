import SwiftUI
import AppKit
import WidgetKit

@main
struct VitalsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state: AppState?
    private var windowController: WidgetWindowController?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = CommandLine.arguments

        if let index = arguments.firstIndex(of: "--render-preview") {
            let directory = previewDirectory(from: arguments, index: index)
            renderPreview(to: directory)
            return
        }

        if arguments.contains("--dump-metrics") {
            dumpMetrics()
            return
        }

        NSApp.setActivationPolicy(.accessory)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        applyApplicationIcon()
        setupMainMenu()

        let appState = AppState()
        let controller = WidgetWindowController(state: appState)
        let statusBar = StatusBarController(state: appState, windowController: controller)
        state = appState
        windowController = controller
        statusBarController = statusBar

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            WidgetGuide.showIfNeeded()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "vitals" }) else { return }
        state?.showWidget()
        windowController?.showWidget(activate: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        state?.showWidget()
        windowController?.showWidget(activate: true)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        state?.monitor.stop()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - Menus

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "VITALS")
        appMenuItem.submenu = appMenu

        let about = NSMenuItem(title: "关于 VITALS", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())

        let show = NSMenuItem(title: "显示仪表盘", action: #selector(showWidget), keyEquivalent: "1")
        show.target = self
        appMenu.addItem(show)

        let hide = NSMenuItem(title: "隐藏仪表盘", action: #selector(hideWidget), keyEquivalent: "h")
        hide.target = self
        appMenu.addItem(hide)

        appMenu.addItem(.separator())

        let guide = NSMenuItem(title: "如何添加桌面小组件…", action: #selector(showWidgetGuide), keyEquivalent: "")
        guide.target = self
        appMenu.addItem(guide)

        appMenu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 VITALS", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        appMenu.addItem(quit)

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        AboutPanel.show()
    }

    @objc private func showWidget() {
        state?.showWidget()
        windowController?.showWidget(activate: true)
    }

    @objc private func hideWidget() {
        state?.hideWidget()
    }

    @objc private func showWidgetGuide() {
        WidgetGuide.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func applyApplicationIcon() {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: url) else { return }
        NSApp.applicationIconImage = icon
    }

    // MARK: - Developer utilities

    private func previewDirectory(from arguments: [String], index: Int) -> URL {
        let next = index + 1
        if next < arguments.count, !arguments[next].hasPrefix("--") {
            return URL(fileURLWithPath: arguments[next])
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("docs")
    }

    private func renderPreview(to directory: URL) {
        NSApp.setActivationPolicy(.prohibited)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            do {
                try PreviewRenderer.render(to: directory)
                print("Preview images written to \(directory.path)")
                exit(0)
            } catch {
                fputs("Preview rendering failed: \(error)\n", stderr)
                exit(1)
            }
        }
    }

    private func dumpMetrics() {
        NSApp.setActivationPolicy(.prohibited)
        let hardware = HardwareInfo.current()
        let sampler = SystemSampler(hardware: hardware)
        _ = sampler.sample()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            let snapshot = sampler.sample()
            print(MetricsDump.text(snapshot: snapshot, hardware: hardware))
            exit(0)
        }
    }
}

enum MetricsDump {
    static func text(snapshot: SystemSnapshot, hardware: HardwareInfo) -> String {
        var lines: [String] = []
        lines.append("VITALS hardware snapshot")
        lines.append("Model       \(hardware.modelName) (\(hardware.modelIdentifier))")
        lines.append("Chip        \(hardware.chipName)")
        lines.append("CPU cores   \(hardware.coreSummary)")
        if let gpuCores = hardware.gpuCores {
            lines.append("GPU cores   \(gpuCores)")
        }
        lines.append("Memory      \(Formatters.memorySize(hardware.memoryBytes))")
        lines.append("OS          \(hardware.macOSVersion)")
        lines.append("")
        lines.append(String(format: "CPU         %.1f%%  (user %.1f%%, system %.1f%%, idle %.1f%%)",
                            snapshot.cpu.usage * 100,
                            snapshot.cpu.user * 100,
                            snapshot.cpu.system * 100,
                            snapshot.cpu.idle * 100))
        lines.append("CPU cores   " + snapshot.cpu.cores.map { String(format: "%.0f%%", $0 * 100) }.joined(separator: " "))
        lines.append(String(format: "Load avg    %.2f  %.2f  %.2f",
                            snapshot.cpu.loadAverage1,
                            snapshot.cpu.loadAverage5,
                            snapshot.cpu.loadAverage15))
        lines.append("Memory      \(Formatters.memorySize(snapshot.memory.used)) / \(Formatters.memorySize(snapshot.memory.total))  \(Formatters.percent(snapshot.memory.usage, decimals: 1))%")
        lines.append("  app       \(Formatters.memorySize(snapshot.memory.app))")
        lines.append("  wired     \(Formatters.memorySize(snapshot.memory.wired))")
        lines.append("  compressed \(Formatters.memorySize(snapshot.memory.compressed))")
        lines.append("GPU         \(snapshot.gpu.usage.map { "\(Formatters.percent($0, decimals: 1))%" } ?? "unavailable")")
        lines.append("Disk        \(Formatters.diskSize(snapshot.disk.used)) / \(Formatters.diskSize(snapshot.disk.total))  \(Formatters.percent(snapshot.disk.usage, decimals: 1))%")
        lines.append("Network     ↓ \(Formatters.networkRate(snapshot.network.downloadBytesPerSecond))  ↑ \(Formatters.networkRate(snapshot.network.uploadBytesPerSecond))")
        lines.append("Thermal     \(snapshot.thermal.label)")
        lines.append("Uptime      \(Formatters.uptime(snapshot.uptime))")
        return lines.joined(separator: "\n")
    }
}
