import SwiftUI

/// First-launch onboarding window with a multi-step tutorial
@available(macOS 13.0, *)
struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("selectedMusicApp") private var selectedApp: String = MusicApp.auto.rawValue
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Content
            Group {
                switch currentPage {
                case 0: welcomePage
                case 1: featuresPage
                case 2: menuBarPage
                case 3: playerPage
                default: accessibilityPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation
            HStack {
                if currentPage > 0 {
                    Button(L("onboarding.back")) {
                        withAnimation(.easeInOut(duration: 0.2)) { currentPage -= 1 }
                    }
                }

                Spacer()

                // Page indicators
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }

                Spacer()

                if currentPage < 4 {
                    Button(L("onboarding.next")) {
                        withAnimation(.easeInOut(duration: 0.2)) { currentPage += 1 }
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button(L("onboarding.getStarted")) {
                        onComplete()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(width: 480, height: 340)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 16) {
            Spacer()

            if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
               let icon = NSImage(contentsOfFile: iconPath) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 80, height: 80)
            }

            Text(L("onboarding.welcomeTitle"))
                .font(.title.bold())

            Text(L("onboarding.welcomeBody"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            Spacer()
        }
        .padding()
    }

    private var featuresPage: some View {
        VStack(spacing: 14) {
            Text(L("onboarding.featuresTitle"))
                .font(.title2.bold())
                .padding(.top, 6)

            LazyVGrid(
                columns: [GridItem(.flexible(), alignment: .leading),
                          GridItem(.flexible(), alignment: .leading)],
                spacing: 14
            ) {
                featureItem("play.circle.fill",      "onboarding.featMediaKeys", .blue)
                featureItem("wand.and.stars",        "onboarding.featAuto",      .purple)
                featureItem("music.note.list",       "onboarding.featPlayers",   .pink)
                featureItem("globe",                 "onboarding.featBrowser",   .teal)
                featureItem("speaker.wave.2.fill",   "onboarding.featVolume",    .orange)
                featureItem("hand.tap.fill",         "onboarding.featDoubleTap", .green)
                featureItem("command",               "onboarding.featShortcut",  .indigo)
                featureItem("arrow.down.circle.fill","onboarding.featUpdates",   .gray)
            }
            .padding(.horizontal, 26)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 18)
    }

    private func featureItem(_ icon: String, _ titleKey: String, _ color: Color) -> some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
            Text(L(titleKey))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    private var menuBarPage: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "menubar.arrow.up.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text(L("onboarding.menuBarTitle"))
                .font(.title2.bold())

            Text(L("onboarding.menuBarBody"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            Spacer()
        }
        .padding()
    }

    private var playerPage: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text(L("onboarding.playerTitle"))
                .font(.title2.bold())

            Picker("", selection: $selectedApp) {
                Text(MusicApp.auto.displayName).tag(MusicApp.auto.rawValue)
                Divider()
                ForEach(MusicApp.allCases.filter(\.isOfficialPlayer), id: \.rawValue) { app in
                    Text(app.displayName).tag(app.rawValue)
                }
                Divider()
                ForEach(MusicApp.allCases.filter { !$0.isOfficialPlayer && !$0.isBrowserBased && $0 != .auto }, id: \.rawValue) { app in
                    Text(app.displayName).tag(app.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
            .onChange(of: selectedApp) { _ in
                NotificationCenter.default.post(name: .settingsChanged, object: nil)
            }

            Text(L("onboarding.playerBody"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            Spacer()
        }
        .padding()
    }

    private var accessibilityPage: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text(L("onboarding.accessibilityTitle"))
                .font(.title2.bold())

            Text(L("onboarding.accessibilityBody"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            Spacer()
        }
        .padding()
    }
}

/// Manages the onboarding window
@available(macOS 13.0, *)
class OnboardingWindowController: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?
    private var onCompleteCallback: (() -> Void)?

    /// Uses a file-based marker inside Application Support so that
    /// deleting and reinstalling the app resets the onboarding state.
    private var markerFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("Conduct", isDirectory: true)
        return folder.appendingPathComponent(".onboarding_complete")
    }

    var hasCompletedOnboarding: Bool {
        FileManager.default.fileExists(atPath: markerFileURL.path)
    }

    private func markOnboardingComplete() {
        let folder = markerFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: markerFileURL.path, contents: nil)
    }

    func showIfNeeded(completion: (() -> Void)? = nil) {
        guard !hasCompletedOnboarding else {
            completion?()
            return
        }
        show(completion: completion)
    }

    func show(completion: (() -> Void)? = nil) {
        onCompleteCallback = completion

        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let onboardingView = OnboardingView {
            self.markOnboardingComplete()
            self.window?.close()
            self.window = nil
            self.onCompleteCallback?()
            self.onCompleteCallback = nil
        }

        let hostingController = NSHostingController(rootView: onboardingView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Conduct"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 480, height: 340))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        // User closed via the red X - still need to start the event tap
        window = nil
        NSApp.setActivationPolicy(.accessory)
        let cb = onCompleteCallback
        onCompleteCallback = nil
        cb?()
    }
}
