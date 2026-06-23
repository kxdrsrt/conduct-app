import Foundation
import Cocoa

/// Supported music applications
enum MusicApp: String, CaseIterable {
    // Auto detection
    case auto = "auto"

    // Official players (sorted first)
    case appleMusic = "com.apple.Music"
    case spotify = "com.spotify.client"

    // Third-party players
    case doppler = "co.brushedtype.doppler-macos"
    case vox = "com.coppertino.Vox"
    case swinsian = "com.swinsian.Swinsian"
    case cider = "sh.cider.classic"
    case daftCloud = "com.daftcloud.DaftCloud"

    // Browser-based
    case youtube = "youtube"

    var displayName: String {
        switch self {
        case .auto: return L("app.auto")
        case .appleMusic: return L("app.appleMusic")
        case .spotify: return L("app.spotify")
        case .doppler: return L("app.doppler")
        case .vox: return L("app.vox")
        case .swinsian: return L("app.swinsian")
        case .cider: return L("app.cider")
        case .daftCloud: return L("app.daftCloud")
        case .youtube: return L("app.youtube")
        }
    }

    var isOfficialPlayer: Bool {
        switch self {
        case .appleMusic, .spotify: return true
        default: return false
        }
    }

    var isBrowserBased: Bool {
        switch self {
        case .youtube: return true
        default: return false
        }
    }

    /// Whether this app is installed on the system
    var isInstalled: Bool {
        switch self {
        case .auto: return true
        case .youtube: return true // Browser-based, always available
        default:
            // Check if any app with this bundle ID exists
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue) != nil
        }
    }

    /// Icon filename in the app bundle Resources
    private var iconFileName: String {
        switch self {
        case .auto: return "auto"
        case .appleMusic: return "apple-music"
        case .spotify: return "spotify"
        case .doppler: return "doppler"
        case .vox: return "vox"
        case .swinsian: return "swinsian"
        case .cider: return "cider"
        case .daftCloud: return "daftcloud"
        case .youtube: return "youtube"
        }
    }

    /// The app's official logo icon from the bundle
    var icon: NSImage? {
        if let path = Bundle.main.path(forResource: iconFileName, ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            return image
        }
        // Fallback to system icon
        if self == .auto {
            return NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: "Auto")
        }
        return NSImage(systemSymbolName: "music.note", accessibilityDescription: displayName)
    }

    /// All cases excluding .auto, used for auto-detection scanning
    static var selectablePlayers: [MusicApp] {
        allCases.filter { $0 != .auto }
    }

    /// Default Auto-mode priority order, sorted by popularity:
    /// Spotify, Apple Music, YouTube, DaftCloud, Doppler, Cider, Vox, Swinsian.
    static var defaultPriority: [MusicApp] {
        let preferred: [MusicApp] = [.spotify, .appleMusic, .youtube, .daftCloud, .doppler, .cider, .vox, .swinsian]
        return preferred + selectablePlayers.filter { !preferred.contains($0) }
    }
}

/// User preferences
class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedApp = "selectedMusicApp"
        static let controlVolumeKeys = "controlVolumeKeys"
        static let launchAtLogin = "launchAtLogin"
        static let pauseOthersOnPlay = "pauseOthersOnPlay"
        static let autoPriority = "autoPriority"
        static let doubleTapAction = "doubleTapAction"
        static let globalHotkeyEnabled = "globalHotkeyEnabled"
        static let globalHotkeyKeyCode = "globalHotkeyKeyCode"
        static let globalHotkeyModifiers = "globalHotkeyModifiers"
        static let notifyOnSwitch = "notifyOnSwitch"
        static let hideMenuBarIcon = "hideMenuBarIcon"
        static let ignoredApps = "ignoredApps"
        static let volumeStep = "volumeStep"
        static let playOnWake = "playOnWake"
        static let showSplashOnLaunch = "showSplashOnLaunch"
    }

    func registerDefaults() {
        defaults.register(defaults: [
            Keys.selectedApp: MusicApp.auto.rawValue,
            Keys.controlVolumeKeys: false,
            Keys.launchAtLogin: false,
            Keys.pauseOthersOnPlay: true,
            Keys.autoPriority: [String](),
            Keys.doubleTapAction: "none",
            Keys.globalHotkeyEnabled: false,
            Keys.globalHotkeyKeyCode: 46, // M key (virtual key code)
            Keys.globalHotkeyModifiers: 6144, // controlKey (4096) | optionKey (2048) = ⌃⌥
            Keys.notifyOnSwitch: true,
            Keys.hideMenuBarIcon: false,
            Keys.ignoredApps: [String](),
            Keys.volumeStep: 5,
            Keys.playOnWake: false,
            Keys.showSplashOnLaunch: true,
        ])
    }

    var selectedApp: MusicApp {
        get {
            let raw = defaults.string(forKey: Keys.selectedApp) ?? MusicApp.auto.rawValue
            return MusicApp(rawValue: raw) ?? .auto
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.selectedApp)
        }
    }

    var controlVolumeKeys: Bool {
        get { defaults.bool(forKey: Keys.controlVolumeKeys) }
        set { defaults.set(newValue, forKey: Keys.controlVolumeKeys) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            LaunchAtLoginManager.setEnabled(newValue)
        }
    }

    /// Stores the launch-at-login preference *without* re-invoking the system
    /// registration. Use this when the registration has already been performed
    /// and you only need to persist the resulting actual state.
    func setLaunchAtLoginRaw(_ value: Bool) {
        defaults.set(value, forKey: Keys.launchAtLogin)
    }

    var pauseOthersOnPlay: Bool {
        get { defaults.bool(forKey: Keys.pauseOthersOnPlay) }
        set { defaults.set(newValue, forKey: Keys.pauseOthersOnPlay) }
    }

    /// Custom priority order for Auto mode (array of MusicApp rawValues)
    var autoPriority: [String] {
        get { defaults.stringArray(forKey: Keys.autoPriority) ?? [] }
        set { defaults.set(newValue, forKey: Keys.autoPriority) }
    }

    /// "none", "skipTwo", "restartPlaylist"
    var doubleTapAction: String {
        get { defaults.string(forKey: Keys.doubleTapAction) ?? "none" }
        set { defaults.set(newValue, forKey: Keys.doubleTapAction) }
    }

    var globalHotkeyEnabled: Bool {
        get { defaults.bool(forKey: Keys.globalHotkeyEnabled) }
        set { defaults.set(newValue, forKey: Keys.globalHotkeyEnabled) }
    }

    var globalHotkeyKeyCode: Int {
        get { defaults.integer(forKey: Keys.globalHotkeyKeyCode) }
        set { defaults.set(newValue, forKey: Keys.globalHotkeyKeyCode) }
    }

    var globalHotkeyModifiers: Int {
        get { defaults.integer(forKey: Keys.globalHotkeyModifiers) }
        set { defaults.set(newValue, forKey: Keys.globalHotkeyModifiers) }
    }

    var notifyOnSwitch: Bool {
        get { defaults.bool(forKey: Keys.notifyOnSwitch) }
        set { defaults.set(newValue, forKey: Keys.notifyOnSwitch) }
    }

    var hideMenuBarIcon: Bool {
        get { defaults.bool(forKey: Keys.hideMenuBarIcon) }
        set { defaults.set(newValue, forKey: Keys.hideMenuBarIcon) }
    }

    /// Array of MusicApp rawValues to ignore in Auto mode
    var ignoredApps: [String] {
        get { defaults.stringArray(forKey: Keys.ignoredApps) ?? [] }
        set { defaults.set(newValue, forKey: Keys.ignoredApps) }
    }

    /// Volume step size (1-20, representing percentage per press)
    var volumeStep: Int {
        get { defaults.integer(forKey: Keys.volumeStep) }
        set { defaults.set(newValue, forKey: Keys.volumeStep) }
    }

    var playOnWake: Bool {
        get { defaults.bool(forKey: Keys.playOnWake) }
        set { defaults.set(newValue, forKey: Keys.playOnWake) }
    }

    var showSplashOnLaunch: Bool {
        get { defaults.bool(forKey: Keys.showSplashOnLaunch) }
        set { defaults.set(newValue, forKey: Keys.showSplashOnLaunch) }
    }

    /// Reset all preferences to their default values
    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier ?? "com.conduct.app"
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
        registerDefaults()
    }
}
