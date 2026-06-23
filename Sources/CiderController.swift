import Foundation
import Cocoa

/// Controls Cider (open-source Apple Music client) via AppleScript
class CiderController: MusicControllerProtocol {
    let appName = "Cider"
    let bundleIdentifier = "sh.cider.classic"

    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first != nil
    }

    func playPause() {
        executeScript("tell application \"Cider\" to playpause")
    }

    func nextTrack() {
        executeScript("tell application \"Cider\" to next track")
    }

    func previousTrack() {
        executeScript("tell application \"Cider\" to previous track")
    }

    func volumeUp() {
        executeScript("""
            tell application "Cider"
                set sound volume to ((sound volume) + \(kVolumeStep))
            end tell
        """)
    }

    func volumeDown() {
        executeScript("""
            tell application "Cider"
                set sound volume to ((sound volume) - \(kVolumeStep))
            end tell
        """)
    }

    func mute() {
        executeScript("""
            tell application "Cider"
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
                print("Conduct Cider error: \(error)")
            }
        }
    }
}
