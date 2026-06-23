import SwiftUI

// MARK: - Settings Window Root View

@available(macOS 13.0, *)
struct SettingsView: View {
    @State private var selectedTab = 0
    /// The tab the sliding highlight points at. It follows `selectedTab` one runloop
    /// tick LATER (see onTapGesture) so the highlight slides over an already-resized,
    /// stable window - never while the window is mid-resize, which made it stretch.
    @State private var indicatorIndex = 0
    /// Measured nav-row height, captured once. Used as the highlight's FIXED height
    /// so the sliding highlight can never stretch vertically during a tab switch.
    @State private var navRowHeight: CGFloat = 49

    /// Reports the active tab's natural total height so the host window can size
    /// to fit it (anchored at the top, keeping the nav bar perfectly static).
    var onHeightChange: ((CGFloat) -> Void)?

    private let tabs: [(String, String)] = [
        ("settings.general",  "gear"),
        ("settings.musicApp", "music.note"),
        ("settings.controls", "command"),
        ("settings.about",    "info.circle"),
    ]

    /// Fixed width of one tab cell. The window width is constant (520) and the nav
    /// HStack is inset 12pt on each side, so each of the four cells is a known
    /// constant. Computing this without a GeometryReader is deliberate: a
    /// GeometryReader background re-measures its height transiently during the
    /// (instant) window resize, and the highlight's spring would then animate that
    /// height too - making the blue highlight stretch/drop into the content. A
    /// constant width + a height that simply fills the nav row keeps the highlight
    /// rock-steady; only its X offset ever animates.
    private var tabWidth: CGFloat { (520 - 24) / CGFloat(tabs.count) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    tabButton(title: L(tabs[index].0), icon: tabs[index].1, index: index)
                }
            }
            .background(alignment: .leading) {
                // A single highlight that slides between tabs. Fixed width AND fixed
                // height (measured once below) with only the X offset bound to
                // selectedTab - so the spring animates ONLY horizontal movement and
                // the highlight can never stretch, drop, or lag during a resize.
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: tabWidth, height: navRowHeight)
                    .offset(x: tabWidth * CGFloat(indicatorIndex))
                    .animation(.spring(response: 0.32, dampingFraction: 0.82), value: indicatorIndex)
            }
            .background(
                // Capture the nav row's height once; it never changes after layout,
                // so feeding it back as a constant can't trigger any animation.
                GeometryReader { geo in
                    Color.clear
                        .onAppear { navRowHeight = geo.size.height }
                }
            )
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            // Only the area BELOW the nav bar changes height. The nav bar is the
            // first item in this top-anchored stack, so it never moves; the window
            // animates (in the controller) to fit the active tab's content,
            // growing/shrinking downward only.
            tabContent
                .frame(maxWidth: .infinity, alignment: .top)
                // Content swap stays INSTANT; only the window frame + nav highlight
                // animate, so the new tab's content is never animated into place.
                .transaction { $0.animation = nil }
        }
        .frame(width: 520)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onPreferenceChange(ContentHeightKey.self) { onHeightChange?($0) }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: GeneralTab()
        case 1: PlayerTab()
        case 2: ControlsTab()
        default: AboutTab()
        }
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        let isSelected = selectedTab == index
        return VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(title)
                .font(.system(size: 10))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .foregroundColor(isSelected ? .accentColor : .secondary)
        .contentShape(Rectangle())
        .onTapGesture {
            // Swap content + resize the window FIRST (instant, this tick), then let
            // the highlight slide on the NEXT tick over the already-stable window.
            // Doing both at once made the highlight stretch during the resize.
            selectedTab = index
            DispatchQueue.main.async { indicatorIndex = index }
        }
    }
}

// MARK: - Shared Components

@available(macOS 13.0, *)
private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: $isOn)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 20)
        }
    }
}

@available(macOS 13.0, *)
private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .kerning(0.3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - General Tab

@available(macOS 13.0, *)
struct GeneralTab: View {
    @AppStorage("launchAtLogin")      private var launchAtLogin      = false
    @AppStorage("showSplashOnLaunch") private var showSplashOnLaunch = true
    @AppStorage("hideMenuBarIcon")    private var hideMenuBarIcon    = false
    @AppStorage("notifyOnSwitch")     private var notifyOnSwitch     = true

    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            SectionLabel(L("settings.sectionStartup"))
            VStack(alignment: .leading, spacing: 10) {
                SettingsToggleRow(
                    title: L("settings.launchAtLogin"),
                    isOn: $launchAtLogin,
                    description: L("settings.launchAtLoginDesc")
                )
                SettingsToggleRow(
                    title: L("settings.showSplash"),
                    isOn: $showSplashOnLaunch,
                    description: L("settings.showSplashDesc")
                )
            }

            Divider()

            SectionLabel(L("settings.sectionAppearance"))
            SettingsToggleRow(
                title: L("settings.hideMenuBarIcon"),
                isOn: $hideMenuBarIcon,
                description: L("settings.hideMenuBarIconDesc")
            )

            Divider()

            SectionLabel(L("settings.sectionNotifications"))
            SettingsToggleRow(
                title: L("settings.notifyOnSwitch"),
                isOn: $notifyOnSwitch,
                description: L("settings.notifyOnSwitchDesc")
            )

            Spacer().frame(height: 16)
            Divider()

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                    showResetConfirm = true
                }
                .alert("Reset all settings to defaults?", isPresented: $showResetConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) {
                        Preferences.shared.resetToDefaults()
                        NotificationCenter.default.post(name: .settingsChanged, object: nil)
                    }
                } message: {
                    Text("This will reset all preferences to their default values.")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear {
            // Reconcile the toggle with the real system state - the user may have
            // disabled the login item in System Settings since the app last ran.
            LaunchAtLoginManager.synchronize()
            launchAtLogin = LaunchAtLoginManager.isEnabled()
        }
        .onChange(of: hideMenuBarIcon) { _ in
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        .onChange(of: launchAtLogin) { newValue in
            let actual = LaunchAtLoginManager.setEnabled(newValue)
            // Reflect the real resulting state (registration may require approval
            // or fail), so the switch never lies about what actually happened.
            if actual != newValue {
                DispatchQueue.main.async {
                    launchAtLogin = actual
                }
            }
        }
    }
}

// MARK: - Player Tab

@available(macOS 13.0, *)
struct PlayerTab: View {
    @AppStorage("selectedMusicApp") private var selectedApp: String = MusicApp.auto.rawValue

    @State private var priorityOrder: [MusicApp]
    @State private var draggedApp: MusicApp?
    @State private var ignoredApps: Set<String>

    private let columns     = [GridItem(.flexible()), GridItem(.flexible())]

    private var isAutoMode: Bool { selectedApp == MusicApp.auto.rawValue }

    // Load the persisted state up front so the very first layout is already at
    // its full height. Populating these in .onAppear instead caused the tab to
    // render empty (short) and then jump taller a frame later.
    init() {
        _priorityOrder = State(initialValue: PlayerTab.resolvedPriority())
        _ignoredApps   = State(initialValue: Set(Preferences.shared.ignoredApps))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("settings.playerDescription"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)

                playerRow(for: .auto)
                    .padding(.bottom, 5)

                Divider().padding(.bottom, 5)

                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(MusicApp.allCases.filter { $0 != .auto }, id: \.rawValue) { app in
                        playerRow(for: app)
                    }
                }

                // Auto Priority - reorder by drag, toggle to include/exclude
                Divider().padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text(L("settings.priority"))
                        .font(.system(size: 12, weight: .semibold))

                    Text(L("settings.priorityDesc"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 2) {
                        ForEach(Array(priorityOrder.enumerated()), id: \.element.rawValue) { index, app in
                            priorityRow(app: app, index: index)
                        }
                    }
                    .padding(.top, 2)
                    .animation(.spring(response: 0.32, dampingFraction: 0.72), value: priorityOrder)
                }
                .opacity(isAutoMode ? 1.0 : 0.4)
                .allowsHitTesting(isAutoMode)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
    }

    private func priorityRow(app: MusicApp, index: Int) -> some View {
        let isIncluded = !ignoredApps.contains(app.rawValue)
        return HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Text("\(index + 1).")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)

            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .cornerRadius(7)
                    .opacity(isIncluded ? 1.0 : 0.35)
            }

            Text(app.displayName)
                .font(.system(size: 13))
                .foregroundColor(isIncluded ? .primary : .secondary)
                .lineLimit(1)

            Spacer()

            Toggle("", isOn: Binding(
                get: { !ignoredApps.contains(app.rawValue) },
                set: { included in
                    if included { ignoredApps.remove(app.rawValue) }
                    else        { ignoredApps.insert(app.rawValue) }
                    Preferences.shared.ignoredApps = Array(ignoredApps)
                    NotificationCenter.default.post(name: .settingsChanged, object: nil)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.secondary.opacity(0.06))
        )
        .scaleEffect(draggedApp == app ? 1.03 : 1.0)
        .shadow(color: .black.opacity(draggedApp == app ? 0.18 : 0),
                radius: 5, x: 0, y: 2)
        .opacity(draggedApp == app ? 0.85 : 1.0)
        .zIndex(draggedApp == app ? 1 : 0)
        .onDrag {
            draggedApp = app
            return NSItemProvider(object: app.rawValue as NSString)
        }
        .onDrop(of: [.text], delegate: PriorityDropDelegate(
            targetIndex: index,
            priorityOrder: $priorityOrder,
            draggedApp: $draggedApp
        ))
    }

    private func playerRow(for app: MusicApp) -> some View {
        let installed  = app.isInstalled
        let isSelected = app.rawValue == selectedApp
        return HStack(spacing: 10) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
                    .opacity(installed ? 1.0 : 0.35)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(app.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(installed ? .primary : .secondary)
                    .lineLimit(1)

                if !installed && app != .auto {
                    Text("Not Installed")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            Spacer(minLength: 2)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(isSelected
                    ? Color.accentColor.opacity(0.08)
                    : (installed ? Color.clear : Color.secondary.opacity(0.03)))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard installed else { return }
            selectedApp = app.rawValue
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
        .opacity(installed ? 1.0 : 0.7)
    }

    private static func resolvedPriority() -> [MusicApp] {
        let saved   = Preferences.shared.autoPriority
        let allApps = MusicApp.defaultPriority
        guard !saved.isEmpty else { return allApps }
        var ordered: [MusicApp] = []
        for raw in saved {
            if let app = MusicApp(rawValue: raw) { ordered.append(app) }
        }
        for app in allApps where !ordered.contains(app) { ordered.append(app) }
        return ordered
    }
}

// MARK: - Priority Drag & Drop

@available(macOS 13.0, *)
struct PriorityDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var priorityOrder: [MusicApp]
    @Binding var draggedApp: MusicApp?

    /// Reorder live as the dragged row passes over another row, so the list
    /// shuffles dynamically under the cursor instead of waiting for the drop.
    func dropEntered(info: DropInfo) {
        guard let dragged = draggedApp,
              let fromIndex = priorityOrder.firstIndex(of: dragged),
              fromIndex != targetIndex,
              targetIndex < priorityOrder.count else { return }
        priorityOrder.move(fromOffsets: IndexSet(integer: fromIndex),
                           toOffset: targetIndex > fromIndex ? targetIndex + 1 : targetIndex)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        draggedApp = nil
        Preferences.shared.autoPriority = priorityOrder.map { $0.rawValue }
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
        return true
    }

    func validateDrop(info: DropInfo) -> Bool { draggedApp != nil }
}

// MARK: - Controls Tab

@available(macOS 13.0, *)
struct ControlsTab: View {
    @AppStorage("controlVolumeKeys")     private var controlVolumeKeys    = false
    @AppStorage("volumeStep")            private var volumeStep: Int      = 5
    @AppStorage("doubleTapAction")       private var doubleTapAction      = "none"
    @AppStorage("globalHotkeyEnabled")   private var globalHotkeyEnabled  = false
    @AppStorage("globalHotkeyKeyCode")   private var globalHotkeyKeyCode: Int  = 46
    @AppStorage("globalHotkeyModifiers") private var globalHotkeyModifiers: Int = 6144
    @AppStorage("pauseOthersOnPlay")     private var pauseOthersOnPlay    = true
    @AppStorage("playOnWake")            private var playOnWake           = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

                // Volume Keys
                SectionLabel(L("settings.sectionVolumeKeys"))
                VStack(alignment: .leading, spacing: 10) {
                    SettingsToggleRow(
                        title: L("settings.redirectVolume"),
                        isOn: $controlVolumeKeys,
                        description: L("settings.redirectVolumeDesc")
                    )
                    if controlVolumeKeys {
                        HStack(spacing: 8) {
                            Text(L("settings.stepLabel"))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .leading)
                            Slider(value: Binding(
                                get: { Double(volumeStep) },
                                set: { volumeStep = Int($0) }
                            ), in: 2...20, step: 1)
                            Text("\(volumeStep)%")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                        .padding(.leading, 20)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Divider()

                // Media Keys
                SectionLabel(L("settings.sectionMediaKeys"))
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("settings.doubleTap"))
                        .font(.system(size: 12, weight: .medium))
                    Picker("", selection: $doubleTapAction) {
                        Text(L("settings.doubleTapNone")).tag("none")
                        Text(L("settings.doubleTapSkipTwo")).tag("skipTwo")
                        Text(L("settings.doubleTapRestart")).tag("restartPlaylist")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    Text(L("settings.doubleTapDesc"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // Global Shortcut
                SectionLabel(L("settings.sectionShortcut"))
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L("settings.shortcutEnabled"), isOn: $globalHotkeyEnabled)
                        .font(.system(size: 12))

                    HStack(spacing: 8) {
                        Text(L("settings.shortcutLabel"))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        HotkeyRecorderView(
                            keyCode: $globalHotkeyKeyCode,
                            modifiers: $globalHotkeyModifiers
                        )
                    }
                    .padding(.leading, 20)
                    .opacity(globalHotkeyEnabled ? 1.0 : 0.4)
                    .disabled(!globalHotkeyEnabled)

                    Text(L("settings.shortcutDesc"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // Playback
                SectionLabel(L("settings.sectionPlayback"))
                VStack(alignment: .leading, spacing: 10) {
                    SettingsToggleRow(
                        title: L("settings.pauseOthers"),
                        isOn: $pauseOthersOnPlay,
                        description: L("settings.pauseOthersDesc")
                    )
                    SettingsToggleRow(
                        title: L("settings.playOnWake"),
                        isOn: $playOnWake,
                        description: L("settings.playOnWakeDesc")
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .top)
            .animation(.easeInOut(duration: 0.15), value: controlVolumeKeys)
            .animation(.easeInOut(duration: 0.15), value: globalHotkeyEnabled)
        .onChange(of: controlVolumeKeys)    { _ in post() }
        .onChange(of: volumeStep)           { _ in post() }
        .onChange(of: doubleTapAction)      { _ in post() }
        .onChange(of: globalHotkeyEnabled)  { _ in post() }
        .onChange(of: pauseOthersOnPlay)    { _ in post() }
        .onChange(of: playOnWake)           { _ in post() }
    }

    private func post() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

// MARK: - Hotkey Recorder

@available(macOS 13.0, *)
struct HotkeyRecorderView: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @State private var isRecording  = false
    @State private var eventMonitor: Any?

    private var shortcutText: String {
        if isRecording { return L("settings.shortcutHint") }
        return Self.format(keyCode: keyCode, carbonMods: modifiers)
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(shortcutText)
                .font(.system(size: 12,
                              weight: .medium,
                              design: isRecording ? .default : .monospaced))
                .foregroundStyle(isRecording ? Color.accentColor : .primary)
                .frame(minWidth: 72, alignment: .center)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording
                                  ? Color.accentColor.opacity(0.07)
                                  : Color(nsColor: .controlBackgroundColor))
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isRecording
                                    ? Color.accentColor
                                    : Color.secondary.opacity(0.35),
                                    lineWidth: isRecording ? 1.5 : 1)
                    }
                )

            Button(isRecording ? L("settings.shortcutCancel") : L("settings.shortcutRecord")) {
                isRecording ? stopRecording() : startRecording()
            }
            .controlSize(.small)
        }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let vk      = event.keyCode
            let nsFlags = event.modifierFlags.intersection([.command, .shift, .option, .control])

            if vk == 53 { // Escape - cancel
                DispatchQueue.main.async { self.stopRecording() }
                return nil
            }

            guard !nsFlags.isEmpty else { return nil } // require a modifier

            let carbonMods = Self.toCarbonMods(nsFlags)
            DispatchQueue.main.async {
                self.keyCode   = Int(vk)
                self.modifiers = Int(carbonMods)
                self.stopRecording()
                NotificationCenter.default.post(name: .settingsChanged, object: nil)
            }
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
    }

    // MARK: Helpers

    static func toCarbonMods(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var c: UInt32 = 0
        if flags.contains(.command) { c |= 256  } // cmdKey
        if flags.contains(.shift)   { c |= 512  } // shiftKey
        if flags.contains(.option)  { c |= 2048 } // optionKey
        if flags.contains(.control) { c |= 4096 } // controlKey
        return c
    }

    static func format(keyCode: Int, carbonMods: Int) -> String {
        var s = ""
        if carbonMods & 4096 != 0 { s += "⌃" }
        if carbonMods & 2048 != 0 { s += "⌥" }
        if carbonMods & 512  != 0 { s += "⇧" }
        if carbonMods & 256  != 0 { s += "⌘" }
        s += keyName(for: keyCode)
        return s
    }

    private static func keyName(for code: Int) -> String {
        let map: [Int: String] = [
             0: "A",  1: "S",  2: "D",  3: "F",  4: "H",  5: "G",
             6: "Z",  7: "X",  8: "C",  9: "V", 11: "B", 12: "Q",
            13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1",
            19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=",
            25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]",
            31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
            51: "⌫", 53: "⎋",
        ]
        return map[code] ?? "Key\(code)"
    }
}

// MARK: - About Tab  (combined About + Help)

@available(macOS 13.0, *)
struct AboutTab: View {
    @State private var autoUpdates = UpdateController.shared.automaticallyChecksForUpdates

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // App identity
            VStack(spacing: 10) {
                if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
                   let icon = NSImage(contentsOfFile: iconPath) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 64, height: 64)
                }

                Text("Conduct")
                    .font(.title2.bold())

                Text("Conduct v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(L("settings.tagline"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                HStack(spacing: 12) {
                    Link(L("settings.website"),
                         destination: URL(string: "https://kxdrsrt.github.io/conduct-app")!)
                        .font(.subheadline)
                    Link("GitHub →",
                         destination: URL(string: "https://github.com/kxdrsrt/conduct-app")!)
                        .font(.subheadline)
                }

                Button(L("settings.checkUpdates")) {
                    UpdateController.shared.checkForUpdates(nil)
                }
                .font(.subheadline)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)

            Divider()

            // Updates
            HStack {
                Toggle(L("settings.autoUpdates"), isOn: $autoUpdates)
                    .onChange(of: autoUpdates) { newValue in
                        UpdateController.shared.automaticallyChecksForUpdates = newValue
                    }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // How it works
            VStack(alignment: .leading, spacing: 6) {
                Text(L("settings.howItWorks"))
                    .font(.system(size: 12, weight: .semibold))
                Text(L("settings.howItWorksBody"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)

            Divider()

            // Support links
            VStack(spacing: 8) {
                Button(L("settings.showWelcome")) {
                    OnboardingWindowController.shared.show()
                }
                Link(L("settings.reportIssue"),
                     destination: URL(string: "https://github.com/kxdrsrt/conduct-app/issues")!)

                Divider()
                    .padding(.vertical, 4)

                Text(L("settings.supportTitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Link(L("settings.donateKofi"),
                         destination: URL(string: "https://ko-fi.com/kadirsert")!)
                        .font(.subheadline)
                    Link(L("settings.donateSponsors"),
                         destination: URL(string: "https://github.com/sponsors/kxdrsrt")!)
                        .font(.subheadline)
                    Link(L("settings.donateOC"),
                         destination: URL(string: "https://opencollective.com/kxdrsrt")!)
                        .font(.subheadline)
                }
                HStack(spacing: 12) {
                    Link(L("settings.donatePatreon"),
                         destination: URL(string: "https://www.patreon.com/cw/kxdrsrt")!)
                        .font(.subheadline)
                    Link(L("settings.donateLiberapay"),
                         destination: URL(string: "https://liberapay.com/kxdrsrt/")!)
                        .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Spacer().frame(height: 14)

            Divider()

            // Footer
            VStack(spacing: 4) {
                Text(L("settings.helpFooter"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 4) {
                    Text("Made by")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Link("@kxdrsrt",
                         destination: URL(string: "https://github.com/kxdrsrt")!)
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let settingsChanged = Notification.Name("ConductSettingsChanged")
}

// MARK: - Dynamic Sizing

/// Reports the natural total height of the active settings tab so the window can
/// size to fit it exactly (no gaps), snapping instantly to keep the nav bar static.
@available(macOS 13.0, *)
private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
