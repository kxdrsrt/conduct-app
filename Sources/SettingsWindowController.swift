import AppKit
import SwiftUI

/// Hosts the SwiftUI SettingsView in an NSWindow (macOS 13+).
@available(macOS 13.0, *)
class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var lastContentHeight: CGFloat = 0
    private var hasSizedOnce = false

    var isWindowVisible: Bool {
        window?.isVisible ?? false
    }

    func showWindow() {
        if let window = window {
            #if DEBUG
            print("[SettingsWC] showWindow: reusing existing window")
            #endif
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        #if DEBUG
        print("[SettingsWC] showWindow: creating new window")
        #endif

        var settingsView = SettingsView()
        settingsView.onHeightChange = { [weak self] height in
            self?.resizeToContentHeight(height)
        }
        let hc = NSHostingController(rootView: settingsView)

        // The window snaps to each tab's natural content height (see
        // resizeToContentHeight) so there are never empty gaps. It only ever
        // grows/shrinks downward - the top edge (and thus the nav bar) stays
        // perfectly fixed - and the snap is instant, so content is never shown
        // clipped mid-animation (which is what used to read as a "jump").
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hc
        window.title = "Conduct"
        window.isReleasedWhenClosed = false
        window.delegate = self

        window.setContentSize(NSSize(width: 520, height: 600))
        window.center()
        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        #if DEBUG
        print("[SettingsWC] showWindow: window created and shown, size=\(window.frame)")
        #endif
    }

    /// Resize the window to fit the active tab's content, anchoring the TOP edge so
    /// the nav bar stays perfectly static. The resize is INSTANT (not animated).
    ///
    /// This is deliberate and is the only way the nav bar stays truly rock solid:
    /// the nav bar lives inside the same hosting view as the content, so ANY
    /// animated window resize disturbs it - with allowsImplicitAnimation off the
    /// content drifts above the top edge, with it on the nav bar (and its sliding
    /// selection highlight) lags behind, and the blocking setFrame(display:animate:)
    /// freezes SwiftUI's concurrent highlight animation so it snaps. An instant
    /// snap finishes in the same display cycle, leaving the nav bar untouched while
    /// the decoupled highlight springs smoothly on its own (see SettingsView).
    private func resizeToContentHeight(_ contentHeight: CGFloat) {
        guard let window = window, contentHeight > 1 else { return }

        // Clamp to the visible screen so a very tall tab can never run off-screen.
        let maxHeight = (window.screen ?? NSScreen.main)?.visibleFrame.height ?? 1200
        let targetContentHeight = (min(contentHeight, maxHeight - 40)).rounded()

        // Ignore no-op updates so a tab switch triggers at most one resize.
        guard abs(targetContentHeight - lastContentHeight) > 0.5 else { return }
        lastContentHeight = targetContentHeight

        let newContentRect = NSRect(x: 0, y: 0, width: 520, height: targetContentHeight)
        var newFrame = window.frameRect(forContentRect: newContentRect)
        let oldFrame = window.frame
        newFrame.origin.x = oldFrame.origin.x
        newFrame.origin.y = oldFrame.maxY - newFrame.height   // keep the top edge fixed

        guard abs(newFrame.height - oldFrame.height) > 0.5 else { return }
        hasSizedOnce = true
        window.setFrame(newFrame, display: true)
    }

    func windowWillClose(_ notification: Notification) {
        #if DEBUG
        print("[SettingsWC] windowWillClose")
        #endif
        window = nil
        lastContentHeight = 0
        hasSizedOnce = false
        if SplashWindowController.shared.isWindowVisible { return }
        DispatchQueue.main.async {
            // When the last window closes, return to accessory (no Dock icon)
            // regardless of hideMenuBarIcon. If the menu bar icon is hidden, the
            // app runs silently; the user re-opens it via Spotlight or Finder.
            NSApp.setActivationPolicy(.accessory)
            // Re-show the status item - switching activation policy can hide it on
            // macOS 14+. Re-assert after the policy change settles (next tick).
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .settingsChanged, object: nil)
            }
            #if DEBUG
            print("[SettingsWC] windowWillClose: setActivationPolicy .accessory")
            #endif
        }
    }
}
