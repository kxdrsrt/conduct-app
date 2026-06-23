import Foundation
import Cocoa

/// Controls Spotify via AppleScript
class SpotifyController: MusicControllerProtocol {
    let appName = "Spotify"
    let bundleIdentifier = "com.spotify.client"

    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first != nil
    }

    func playPause() {
        executeScript("tell application \"Spotify\" to playpause")
    }

    func nextTrack() {
        executeScript("tell application \"Spotify\" to next track")
    }

    func previousTrack() {
        executeScript("tell application \"Spotify\" to previous track")
    }

    func volumeUp() {
        executeScript("""
            tell application "Spotify"
                set sound volume to ((sound volume) + \(kVolumeStep))
            end tell
        """)
    }

    func volumeDown() {
        executeScript("""
            tell application "Spotify"
                set sound volume to ((sound volume) - \(kVolumeStep))
            end tell
        """)
    }

    func mute() {
        // Spotify doesn't have a native mute toggle, so set volume to 0 or restore
        executeScript("""
            tell application "Spotify"
                if sound volume > 0 then
                    set sound volume to 0
                else
                    set sound volume to 50
                end if
            end tell
        """)
    }

    private func executeScript(_ source: String) {
        appleScriptQueue.async {
            let script = NSAppleScript(source: source)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            if let error = error {
                print("Conduct Spotify error: \(error)")
            }
        }
    }
}
