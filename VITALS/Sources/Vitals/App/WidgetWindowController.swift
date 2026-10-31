import AppKit
import SwiftUI
import Combine

final class WidgetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class WidgetWindowController: NSWindowController, NSWindowDelegate {
    private let state: AppState
    private var cancellables = Set<AnyCancellable>()
    private var hasFinishedInitialPresentation = false

    init(state: AppState) {
        self.state = state
        let size = state.isCompact ? WidgetLayout.compactSize : WidgetLayout.fullSize
        let window = WidgetWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        configure(window)
        let hostingView = NSHostingView(rootView: WidgetView(state: state, monitor: state.monitor))
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        window.delegate = self

        restorePosition(for: size)
        bindState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var desktopWindowLevel: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }

    private func configure(_ window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.title = "VITALS"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.animationBehavior = .utilityWindow
        window.level = state.isPinned ? .floating : desktopWindowLevel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.acceptsMouseMovedEvents = true
        window.contentView?.wantsLayer = true
    }

    private func bindState() {
        state.$isCompact
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] compact in
                self?.applySize(compact ? WidgetLayout.compactSize : WidgetLayout.fullSize, animated: true)
            }
            .store(in: &cancellables)

        state.$isPinned
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] pinned in
                self?.window?.level = pinned ? .floating : self?.desktopWindowLevel ?? .normal
                if pinned {
                    self?.window?.orderFrontRegardless()
                }
            }
            .store(in: &cancellables)

        state.$isVisible
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] visible in
                if visible {
                    self?.showWidget(activate: true)
                } else {
                    self?.hideWidget()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .vitalsResetWindowPosition)
            .sink { [weak self] _ in
                guard let self else { return }
                let size = self.state.isCompact ? WidgetLayout.compactSize : WidgetLayout.fullSize
                self.positionAtDefault(size: size)
            }
            .store(in: &cancellables)
    }

    func presentInitial() {
        guard !hasFinishedInitialPresentation else { return }
        hasFinishedInitialPresentation = true
        showWidget(activate: true)
    }

    func showWidget(activate: Bool) {
        guard let window else { return }
        if !window.isVisible {
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.24
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
        } else {
            window.orderFrontRegardless()
        }

        if activate {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKey()
        }
    }

    func hideWidget() {
        window?.orderOut(nil)
    }

    private func applySize(_ size: CGSize, animated: Bool) {
        guard let window else { return }
        var frame = window.frame
        let right = frame.maxX
        let top = frame.maxY
        frame.size = size
        frame.origin = NSPoint(x: right - size.width, y: top - size.height)
        frame = clampedToVisibleScreen(frame, size: size)
        window.setFrame(frame, display: true, animate: animated)
    }

    private func restorePosition(for size: CGSize) {
        guard let window else { return }
        window.setFrameAutosaveName("VitalsWidgetFrame")

        if window.setFrameUsingName("VitalsWidgetFrame") {
            var frame = window.frame
            let right = frame.maxX
            let top = frame.maxY
            frame.size = size
            frame.origin = NSPoint(x: right - size.width, y: top - size.height)
            window.setFrame(clampedToVisibleScreen(frame, size: size), display: false)
        } else {
            positionAtDefault(size: size)
        }
    }

    private func positionAtDefault(size: CGSize) {
        guard let window else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: visible.maxX - size.width - 26,
            y: visible.maxY - size.height - 26
        )
        window.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
    }

    private func clampedToVisibleScreen(_ frame: NSRect, size: CGSize) -> NSRect {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return frame }

        let intersectsAny = screens.contains { screen in
            let intersection = screen.visibleFrame.intersection(frame)
            return intersection.width > 60 && intersection.height > 60
        }
        guard !intersectsAny, let main = NSScreen.main ?? screens.first else {
            return frame
        }

        let visible = main.visibleFrame
        var clamped = frame
        clamped.origin.x = min(max(frame.origin.x, visible.minX + 12), visible.maxX - size.width - 12)
        clamped.origin.y = min(max(frame.origin.y, visible.minY + 12), visible.maxY - size.height - 12)
        return clamped
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        guard let window else { return }
        window.saveFrame(usingName: "VitalsWidgetFrame")
    }
}
