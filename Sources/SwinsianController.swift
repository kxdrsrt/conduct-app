import Foundation
import Cocoa

/// Controls Swinsian via AppleScript
class SwinsianController: MusicControllerProtocol {
    let appName = "Swinsian"
    let bundleIdentifier = "com.swinsian.Swinsian"

    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first != nil
    }

    func playPause() {
        executeScript("tell application \"Swinsian\" to playpause")
    }

    func nextTrack() {
        executeScript("tell application \"Swinsian\" to next track")
    }

    func previousTrack() {
        executeScript("tell application \"Swinsian\" to previous track")
    }

    func volumeUp() {
        executeScript("""
            tell application "Swinsian"
                set sound volume to ((sound volume) + \(kVolumeStep))
            end tell
        """)
    }

    func volumeDown() {
        executeScript("""
            tell application "Swinsian"
                set sound volume to ((sound volume) - \(kVolumeStep))
            end tell
        """)
    }

    func mute() {
        executeScript("""
            tell application "Swinsian"
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
                print("Conduct Swinsian error: \(error)")
            }
        }
    }
}
