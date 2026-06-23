import Foundation
import Cocoa

/// Controls DaftCloud (SoundCloud client) via AppleScript
class DaftCloudController: MusicControllerProtocol {
    let appName = "DaftCloud"
    let bundleIdentifier = "com.daftcloud.DaftCloud"

    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first != nil
    }

    func playPause() {
        executeScript("tell application \"DaftCloud\" to playpause")
    }

    func nextTrack() {
        executeScript("tell application \"DaftCloud\" to next track")
    }

    func previousTrack() {
        executeScript("tell application \"DaftCloud\" to previous track")
    }

    func volumeUp() {
        executeScript("""
            tell application "DaftCloud"
                set sound volume to ((sound volume) + \(kVolumeStep))
            end tell
        """)
    }

    func volumeDown() {
        executeScript("""
            tell application "DaftCloud"
                set sound volume to ((sound volume) - \(kVolumeStep))
            end tell
        """)
    }

    func mute() {
        executeScript("""
            tell application "DaftCloud"
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
                print("Conduct DaftCloud error: \(error)")
            }
        }
    }
}
