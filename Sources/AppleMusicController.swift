import Foundation
import Cocoa

/// Controls Apple Music (formerly iTunes) via AppleScript
class AppleMusicController: MusicControllerProtocol {
    let appName = "Apple Music"
    let bundleIdentifier = "com.apple.Music"

    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first != nil
    }

    func playPause() {
        executeScript("""
            tell application "Music"
                if player state is playing then
                    pause
                else if player state is paused then
                    play
                else
                    set shuffle enabled to true
                    play playlist "Library"
                end if
            end tell
        """)
    }

    func nextTrack() {
        executeScript("tell application \"Music\" to next track")
    }

    func previousTrack() {
        executeScript("tell application \"Music\" to previous track")
    }

    func volumeUp() {
        executeScript("""
            tell application "Music"
                set sound volume to (sound volume + \(kVolumeStep))
            end tell
        """)
    }

    func volumeDown() {
        executeScript("""
            tell application "Music"
                set sound volume to (sound volume - \(kVolumeStep))
            end tell
        """)
    }

    func mute() {
        executeScript("""
            tell application "Music"
                set mute to (not mute)
            end tell
        """)
    }

    private func executeScript(_ source: String) {
        appleScriptQueue.async {
            let script = NSAppleScript(source: source)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            if let error = error {
                print("Conduct AppleMusic error: \(error)")
            }
        }
    }
}
