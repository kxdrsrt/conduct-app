import Foundation

/// Serial queue for all AppleScript execution - NSAppleScript is not thread-safe
let appleScriptQueue = DispatchQueue(label: "com.conduct.applescript")

/// Protocol that all music app controllers must implement
protocol MusicControllerProtocol {
    var appName: String { get }
    var bundleIdentifier: String { get }
    var isRunning: Bool { get }

    func playPause()
    func nextTrack()
    func previousTrack()
    func volumeUp()
    func volumeDown()
    func mute()
}

/// Default volume step (reads from preferences)
var kVolumeStep: Int { Preferences.shared.volumeStep }

/// Factory for creating the appropriate music controller
class MusicControllerFactory {
    static func controller(for app: MusicApp) -> any MusicControllerProtocol {
        switch app {
        case .auto:
            return AutoController()
        case .appleMusic:
            return AppleMusicController()
        case .spotify:
            return SpotifyController()
        case .doppler:
            return DopplerController()
        case .vox:
            return VoxController()
        case .swinsian:
            return SwinsianController()
        case .cider:
            return CiderController()
        case .daftCloud:
            return DaftCloudController()
        case .youtube:
            return YouTubeController()
        }
    }
}
