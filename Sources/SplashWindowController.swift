import AppKit
import SwiftUI

/// Splash window shown on launch - displays permission status, quick actions.
/// Apple Liquid Glass design language.
@available(macOS 13.0, *)
class SplashWindowController: NSObject, NSWindowDelegate {
    static let shared = SplashWindowController()

    private var window: NSWindow?
    private var permissionCheckTimer: Timer?
    private var isTransitioning = false

    var isWindowVisible: Bool {
        window?.isVisible ?? false
    }

    func show() {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let splashView = SplashView(
            onOpenSettings: { [weak self] in
                self?.dismissAndTransition {
                    SettingsWindowController.shared.showWindow()
                }
            },
            onShowTutorial: { [weak self] in
                self?.dismissAndTransition {
                    OnboardingWindowController.shared.show()
                }
            },
            onDismiss: { [weak self] in
                self?.close()
            }
        )

        let hostingController = NSHostingController(rootView: splashView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Conduct"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 400, height: 380))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.isMovableByWindowBackground = true

        // Clear background to let vibrancy extend to window edges
        window.backgroundColor = .clear

        window.layoutIfNeeded()
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    /// Close splash and open another window without losing foreground
    private func dismissAndTransition(_ openNext: @escaping () -> Void) {
        #if DEBUG
        print("[Splash] dismissAndTransition - closing splash, opening next window")
        #endif
        isTransitioning = true
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        window?.close()
        openNext()
        NSApp.activate(ignoringOtherApps: true)
        isTransitioning = false
    }

    func close() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        #if DEBUG
        print("[Splash] windowWillClose - isTransitioning=\(isTransitioning)")
        #endif
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
        window = nil
        // Don't change activation policy if transitioning to another window
        guard !isTransitioning else { return }
        // Don't switch policy if Settings is still open - it manages its own teardown.
        if SettingsWindowController.shared.isWindowVisible { return }
        NSApp.setActivationPolicy(.accessory)
        // Re-show the status item - switching activation policy can hide it on macOS 14+.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        #if DEBUG
        print("[Splash] windowWillClose: setActivationPolicy .accessory")
        #endif
    }
}

// MARK: - Splash View (Liquid Glass)

@available(macOS 13.0, *)
struct SplashView: View {
    var onOpenSettings: () -> Void
    var onShowTutorial: () -> Void
    var onDismiss: () -> Void

    @AppStorage("showSplashOnLaunch") private var showOnLaunch: Bool = true
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Vibrancy background
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                // App icon
                if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
                   let icon = NSImage(contentsOfFile: iconPath) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }

                Spacer().frame(height: 14)

                // App name + version
                Text("Conduct")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text(versionString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                Spacer().frame(height: 24)

                // Permission card
                permissionCard()
                    .padding(.horizontal, 28)

                Spacer().frame(height: 20)

                // Status badge
                statusBadge()

                Spacer()

                // Action buttons
                HStack(spacing: 10) {
                    splashButton("Tutorial", icon: "book", action: onShowTutorial)
                    splashButton("Settings", icon: "gear", action: onOpenSettings)
                    splashButton("Close", icon: "xmark", isPrimary: true, action: onDismiss)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 16)

                // Show on launch toggle
                Toggle("Show this window on launch", isOn: $showOnLaunch)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .toggleStyle(.checkbox)

                Spacer().frame(height: 20)
            }
        }
        .frame(width: 400, height: 380)
        .onReceive(timer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    // MARK: - Permission Card

    private func permissionCard() -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accessibilityGranted ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: accessibilityGranted ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(accessibilityGranted ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility")
                    .font(.system(size: 13, weight: .semibold))

                Text("Required to intercept media keys")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if accessibilityGranted {
                Text("Granted")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
            } else {
                Button("Grant…") { openAccessibilitySettings() }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Status Badge

    private func statusBadge() -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(accessibilityGranted ? Color.green : Color.orange)
                .frame(width: 7, height: 7)

            Text(accessibilityGranted ? "Conduct is running" : "Grant permission to start")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Button

    private func splashButton(_ title: String, icon: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isPrimary ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isPrimary ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isPrimary ? Color.accentColor : .primary)
    }

    // MARK: - Helpers

    private func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "Version \(version)"
    }
}

// MARK: - NSVisualEffectView wrapper

@available(macOS 13.0, *)
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
