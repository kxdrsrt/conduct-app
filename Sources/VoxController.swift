import Foundation
import Cocoa

/// Controls VOX via AppleScript
class VoxController: MusicControllerProtocol {
    let appName = "VOX"
    let bundleIdentifier = "com.coppertino.Vox"

    var isRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first != nil
    }

    func playPause() {
        executeScript("tell application \"VOX\" to playpause")
    }

    func nextTrack() {
        executeScript("tell application \"VOX\" to next")
    }

    func previousTrack() {
        executeScript("tell application \"VOX\" to previous")
    }

    func volumeUp() {
        executeScript("""
            tell application "VOX"
                set playerVolume to (playerVolume + \(kVolumeStep))
            end tell
        """)
    }

    func volumeDown() {
        executeScript("""
            tell application "VOX"
                set playerVolume to (playerVolume - \(kVolumeStep))
            end tell
        """)
    }

    func mute() {
        executeScript("""
            tell application "VOX"
                if playerVolume > 0 then
                    set playerVolume to 0
                else
                    set playerVolume to 50
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
                print("Conduct VOX error: \(error)")
            }
        }
    }
}
