import Foundation
import Cocoa

/// Controls Doppler via AppleScript
class DopplerController: MusicControllerProtocol {
    let appName = "Doppler"
    let bundleIdentifier = "co.brushedtype.doppler-macos"

    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first != nil
    }

    func playPause() {
        executeScript("""
            tell application "Doppler"
                if player state is playing then
                    pause
                else
                    play
                end if
            end tell
        """)
    }

    func nextTrack() {
        executeScript("tell application \"Doppler\" to next track")
    }

    func previousTrack() {
        executeScript("tell application \"Doppler\" to previous track")
    }

    func volumeUp() {
        executeScript("""
            tell application "Doppler"
                set sound volume to ((sound volume) + \(kVolumeStep))
            end tell
        """)
    }

    func volumeDown() {
        executeScript("""
            tell application "Doppler"
                set sound volume to ((sound volume) - \(kVolumeStep))
            end tell
        """)
    }

    func mute() {
        executeScript("""
            tell application "Doppler"
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
                print("Conduct Doppler error: \(error)")
            }
        }
    }
}
