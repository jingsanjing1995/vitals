import AppKit
import Combine
import WidgetKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let state: AppState
    private weak var windowController: WidgetWindowController?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    private let infoItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let visibilityItem = NSMenuItem(title: "", action: nil, keyEquivalent: "1")
    private let compactItem = NSMenuItem(title: "紧凑模式", action: nil, keyEquivalent: "2")
    private let levelMenu = NSMenu()
    private let floatingItem = NSMenuItem(title: "悬浮于窗口之上", action: nil, keyEquivalent: "")
    private let desktopItem = NSMenuItem(title: "固定在桌面", action: nil, keyEquivalent: "")
    private let intervalMenu = NSMenu()
    private let resetPositionItem = NSMenuItem(title: "重置窗口位置", action: nil, keyEquivalent: "")

    init(state: AppState, windowController: WidgetWindowController) {
        self.state = state
        self.windowController = windowController
        super.init()

        setupStatusItem()
        buildMenu()
        observeMonitor()

        DispatchQueue.main.async { [weak self] in
            self?.windowController?.presentInitial()
        }
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: "VITALS")
        image?.isTemplate = true
        image?.size = NSSize(width: 14, height: 14)
        button.image = image
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        statusItem.menu = menu
        updateStatusTitle()
    }

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        infoItem.isEnabled = false
        menu.addItem(infoItem)
        menu.addItem(.separator())

        visibilityItem.target = self
        visibilityItem.action = #selector(toggleVisibility)
        menu.addItem(visibilityItem)

        compactItem.target = self
        compactItem.action = #selector(toggleCompact)
        menu.addItem(compactItem)

        let levelItem = NSMenuItem(title: "窗口层级", action: nil, keyEquivalent: "")
        levelMenu.autoenablesItems = false
        floatingItem.target = self
        floatingItem.action = #selector(useFloatingLevel)
        desktopItem.target = self
        desktopItem.action = #selector(useDesktopLevel)
        levelMenu.addItem(floatingItem)
        levelMenu.addItem(desktopItem)
        levelItem.submenu = levelMenu
        menu.addItem(levelItem)

        let intervalItem = NSMenuItem(title: "刷新频率", action: nil, keyEquivalent: "")
        intervalMenu.autoenablesItems = false
        let intervals: [(String, TimeInterval)] = [
            ("0.5 秒", 0.5),
            ("1 秒", 1.0),
            ("2 秒", 2.0),
            ("5 秒", 5.0)
        ]
        for (index, entry) in intervals.enumerated() {
            let item = NSMenuItem(title: entry.0, action: #selector(setInterval(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.representedObject = entry.1
            intervalMenu.addItem(item)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        menu.addItem(.separator())

        resetPositionItem.target = self
        resetPositionItem.action = #selector(resetPosition)
        menu.addItem(resetPositionItem)

        menu.addItem(.separator())

        let guideItem = NSMenuItem(title: "如何添加桌面小组件…", action: #selector(showWidgetGuide), keyEquivalent: "")
        guideItem.target = self
        menu.addItem(guideItem)

        let reloadItem = NSMenuItem(title: "刷新桌面小组件", action: #selector(reloadWidgets), keyEquivalent: "")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "关于 VITALS", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 VITALS", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func observeMonitor() {
        state.monitor.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusTitle()
            }
            .store(in: &cancellables)
    }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        let cpu = state.monitor.snapshot.cpu.usage
        let title = " \(Formatters.percent(cpu))%"
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium),
                .foregroundColor: NSColor.labelColor,
                .baselineOffset: 0.2
            ]
        )
        let snapshot = state.monitor.snapshot
        button.toolTip = "VITALS · CPU \(Formatters.percent(cpu, decimals: 1))% · 内存 \(Formatters.percent(snapshot.memory.usage, decimals: 1))%"
    }

    func menuWillOpen(_ menu: NSMenu) {
        let snapshot = state.monitor.snapshot
        infoItem.title = "CPU \(Formatters.percent(snapshot.cpu.usage, decimals: 1))%   ·   内存 \(Formatters.percent(snapshot.memory.usage, decimals: 1))%   ·   \(Formatters.uptimeCompact(snapshot.uptime))"
        visibilityItem.title = state.isVisible ? "隐藏仪表盘" : "显示仪表盘"
        compactItem.state = state.isCompact ? .on : .off
        floatingItem.state = state.isPinned ? .on : .off
        desktopItem.state = state.isPinned ? .off : .on
        resetPositionItem.isEnabled = state.isVisible

        for item in intervalMenu.items {
            if let value = item.representedObject as? TimeInterval {
                item.state = abs(value - state.refreshInterval) < 0.001 ? .on : .off
            }
        }
    }

    @objc private func toggleVisibility() {
        state.isVisible.toggle()
    }

    @objc private func toggleCompact() {
        state.toggleCompact()
    }

    @objc private func useFloatingLevel() {
        state.isPinned = true
    }

    @objc private func useDesktopLevel() {
        state.isPinned = false
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? TimeInterval else { return }
        state.refreshInterval = value
    }

    @objc private func resetPosition() {
        state.resetWindowPosition()
    }

    @objc private func showWidgetGuide() {
        WidgetGuide.show()
    }

    @objc private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    @objc private func showAbout() {
        AboutPanel.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

enum AboutPanel {
    @MainActor
    static func show() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let credits = NSMutableAttributedString(
            string: "原生 macOS 硬件仪表\nCPU · 内存 · GPU · 存储 · 网络\n\n实时掌握这台 Mac 的状态。",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "VITALS",
            .applicationVersion: version,
            .version: "",
            .credits: credits
        ])
    }
}


enum WidgetGuide {
    private static let hasShownKey = "hasShownWidgetGuide"

    @MainActor
    static func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: hasShownKey) else { return }
        UserDefaults.standard.set(true, forKey: hasShownKey)
        show(firstRun: true)
    }

    @MainActor
    static func show(firstRun: Bool = false) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = firstRun ? "VITALS 已就绪" : "将 VITALS 添加到桌面"
        alert.informativeText = """
        实时面板默认固定在桌面，像桌面组件一样位于普通窗口下方。
        点击右上角图钉，或使用菜单栏「窗口层级」，可在桌面与悬浮之间切换。

        系统小组件：
        1. 在桌面空白处右键，选择“编辑小组件…”
        2. 搜索 VITALS
        3. 选择小、中或大尺寸，拖到桌面

        系统小组件由 macOS 调度，大约每分钟更新一次；点击小组件可打开实时面板。
        如果搜索不到 VITALS，说明当前构建没有 Apple 开发者签名，请查看 README 的签名说明。
        """
        alert.addButton(withTitle: "开始使用")
        alert.icon = NSApp.applicationIconImage
        alert.runModal()
    }
}
