import Foundation
import Cocoa

/// Controls YouTube playback in browsers via keyboard shortcuts sent through System Events.
/// Finds the browser window with YouTube, activates it briefly, sends the keyboard shortcut,
/// then restores focus to the previous app.
class YouTubeController: MusicControllerProtocol {
    let appName = "YouTube"
    let bundleIdentifier = "youtube"

    /// Supported browsers in priority order
    private static let browsers: [(id: String, name: String, process: String)] = [
        ("company.thebrowser.dia", "Dia", "Dia"),
        ("company.thebrowser.Browser", "Arc", "Arc"),
        ("com.google.Chrome", "Google Chrome", "Google Chrome"),
        ("com.brave.Browser", "Brave Browser", "Brave Browser"),
        ("com.microsoft.edgemac", "Microsoft Edge", "Microsoft Edge"),
        ("com.vivaldi.Vivaldi", "Vivaldi", "Vivaldi"),
        ("com.operasoftware.Opera", "Opera", "Opera"),
        ("app.zen-browser.zen", "Zen Browser", "Zen Browser"),
        ("org.waterfox.waterfox", "Waterfox", "Waterfox"),
        ("org.chromium.Chromium", "Chromium", "Chromium"),
        ("com.kagi.kagimacOS", "Orion", "Orion"),
        ("com.apple.Safari", "Safari", "Safari"),
        ("org.mozilla.firefox", "Firefox", "Firefox"),
    ]

    var isRunning: Bool {
        // Quick check: any supported browser running?
        guard findRunningBrowser() != nil else { return false }

        // On main thread, skip expensive AppleScript tab verification to avoid UI hangs.
        // Commands will fail gracefully if no YouTube tab exists.
        // On background thread (AutoController detection), verify tab to avoid false positives.
        if Thread.isMainThread { return true }

        return verifyYouTubeTabExists()
    }

    /// Quick check: returns the first running supported browser, or nil
    private func findRunningBrowser() -> (id: String, name: String, process: String)? {
        for browser in Self.browsers {
            if NSRunningApplication.runningApplications(withBundleIdentifier: browser.id).first != nil {
                return browser
            }
        }
        return nil
    }

    /// Expensive check: verifies a YouTube tab actually exists via AppleScript.
    /// Must NOT be called on the main thread.
    private func verifyYouTubeTabExists() -> Bool {
        guard let browser = findRunningBrowser() else { return false }

        let checkScript: String
        if browser.name == "Safari" {
            checkScript = """
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then return true
                    end repeat
                end repeat
            end tell
            return false
            """
        } else if browser.name == "Firefox" || browser.name == "Zen Browser" || browser.name == "Waterfox" {
            checkScript = """
            tell application "System Events"
                tell process "\(browser.process)"
                    repeat with w in windows
                        if name of w contains "YouTube" then return true
                    end repeat
                end tell
            end tell
            return false
            """
        } else {
            checkScript = """
            tell application "\(browser.name)"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then return true
                    end repeat
                end repeat
            end tell
            return false
            """
        }

        let script = NSAppleScript(source: checkScript)
        var error: NSDictionary?
        if let result = script?.executeAndReturnError(&error) {
            return result.booleanValue
        }
        return false
    }

    func playPause() {
        sendYouTubeCommand(jsAction: "document.querySelector('video').paused ? document.querySelector('video').play() : document.querySelector('video').pause()", keystroke: "k", keyCode: nil)
    }

    func nextTrack() {
        // Shift+N = next video in YouTube
        sendYouTubeCommand(jsAction: nil, keystroke: "N", keyCode: nil)
    }

    func previousTrack() {
        // Shift+P = previous video in YouTube
        sendYouTubeCommand(jsAction: nil, keystroke: "P", keyCode: nil)
    }

    func volumeUp() {
        // Up arrow = volume up in YouTube
        sendYouTubeCommand(jsAction: "document.querySelector('video').volume = Math.min(1, document.querySelector('video').volume + 0.05)", keystroke: nil, keyCode: 126)
    }

    func volumeDown() {
        // Down arrow = volume down in YouTube
        sendYouTubeCommand(jsAction: "document.querySelector('video').volume = Math.max(0, document.querySelector('video').volume - 0.05)", keystroke: nil, keyCode: 125)
    }

    func mute() {
        sendYouTubeCommand(jsAction: "document.querySelector('video').muted = !document.querySelector('video').muted", keystroke: "m", keyCode: nil)
    }

    // MARK: - Private

    /// Sends a command to YouTube. Tries JavaScript injection first (no focus stealing),
    /// falls back to keystroke approach (requires brief browser activation) if JS isn't available.
    private func sendYouTubeCommand(jsAction: String?, keystroke: String?, keyCode: Int?, shiftKey: Bool = false) {
        appleScriptQueue.async {
            // Find a running browser
            var targetBrowser: (id: String, name: String, process: String)?
            for browser in Self.browsers {
                if NSRunningApplication.runningApplications(withBundleIdentifier: browser.id).first != nil {
                    targetBrowser = browser
                    break
                }
            }

            guard let browser = targetBrowser else {
                print("Conduct YouTube: no supported browser running")
                return
            }

            // Try JavaScript approach first (no activation/focus change needed)
            if let js = jsAction {
                let jsScript = self.buildJavaScriptScript(browserName: browser.name, js: js)
                if let jsScript = jsScript {
                    let appleScript = NSAppleScript(source: jsScript)
                    var error: NSDictionary?
                    let result = appleScript?.executeAndReturnError(&error)
                    // If JS succeeded, we're done (no focus stealing)
                    if error == nil && result?.stringValue != "false" {
                        return
                    }
                }
            }

            // Fall back to keystroke approach (requires activation)
            guard keystroke != nil || keyCode != nil else { return }

            let keyCmd: String
            if let ks = keystroke {
                if shiftKey {
                    keyCmd = "keystroke \"\(ks)\" using shift down"
                } else {
                    keyCmd = "keystroke \"\(ks)\""
                }
            } else if let kc = keyCode {
                if shiftKey {
                    keyCmd = "key code \(kc) using shift down"
                } else {
                    keyCmd = "key code \(kc)"
                }
            } else {
                return
            }

            let script: String
            if browser.name == "Safari" {
                script = self.buildSafariScript(keyCmd: keyCmd)
            } else if browser.name == "Firefox" || browser.name == "Zen Browser" || browser.name == "Waterfox" {
                script = self.buildFirefoxScript(browserName: browser.name, processName: browser.process, keyCmd: keyCmd)
            } else {
                script = self.buildChromiumScript(browserName: browser.name, processName: browser.process, keyCmd: keyCmd)
            }

            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            let result = appleScript?.executeAndReturnError(&error)

            if let error = error {
                print("Conduct YouTube (\(browser.name)): \(error[NSAppleScript.errorMessage] ?? error)")
            } else if let r = result?.stringValue, r == "false" {
                print("Conduct YouTube: no YouTube tab found in \(browser.name)")
            }
        }
    }

    /// Builds a JavaScript-based script that controls the video element directly.
    /// Returns nil for browsers that don't support JS injection via AppleScript.
    private func buildJavaScriptScript(browserName: String, js: String) -> String? {
        // Firefox-based browsers don't support `do JavaScript` via AppleScript
        if browserName == "Firefox" || browserName == "Zen Browser" || browserName == "Waterfox" {
            return nil
        }

        if browserName == "Safari" {
            return """
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then
                            do JavaScript "\(js)" in t
                            return "true"
                        end if
                    end repeat
                end repeat
            end tell
            return "false"
            """
        }

        // Chromium-based browsers
        return """
        tell application "\(browserName)"
            repeat with w in windows
                repeat with t in tabs of w
                    if URL of t contains "youtube.com" then
                        tell t to execute javascript "\(js)"
                        return "true"
                    end if
                end repeat
            end repeat
        end tell
        return "false"
        """
    }

    /// For Chromium-based browsers (Dia, Arc, Chrome, Brave, etc.)
    /// Strategy: check window name for "YouTube", activate, send keystroke, restore focus
    private func buildChromiumScript(browserName: String, processName: String, keyCmd: String) -> String {
        return """
        set prevApp to path to frontmost application as text
        tell application "\(browserName)"
            set found to false
            repeat with w in windows
                if name of w contains "YouTube" then
                    set found to true
                    exit repeat
                end if
            end repeat
            if not found then
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then
                            set found to true
                            exit repeat
                        end if
                    end repeat
                    if found then exit repeat
                end repeat
            end if
            if not found then return "false"
            activate
        end tell
        delay 0.15
        tell application "System Events"
            tell process "\(processName)"
                key code 53
                delay 0.05
                \(keyCmd)
            end tell
        end tell
        delay 0.08
        activate application prevApp
        return "true"
        """
    }

    /// Firefox-based browsers don't expose tab URLs via AppleScript.
    /// We check window titles and send keystrokes.
    private func buildFirefoxScript(browserName: String, processName: String, keyCmd: String) -> String {
        return """
        set prevApp to path to frontmost application as text
        tell application "System Events"
            if not (exists process "\(processName)") then return "false"
            tell process "\(processName)"
                repeat with w in windows
                    if name of w contains "YouTube" then
                        tell application "\(browserName)" to activate
                        delay 0.15
                        key code 53
                        delay 0.05
                        \(keyCmd)
                        delay 0.08
                        activate application prevApp
                        return "true"
                    end if
                end repeat
            end tell
        end tell
        return "false"
        """
    }

    /// Safari supports `do JavaScript` if "Allow JavaScript from Apple Events" is enabled.
    /// Falls back to keyboard approach if that fails.
    private func buildSafariScript(keyCmd: String) -> String {
        return """
        set prevApp to path to frontmost application as text
        tell application "Safari"
            set found to false
            repeat with w in windows
                if name of w contains "YouTube" then
                    set found to true
                    exit repeat
                end if
            end repeat
            if not found then
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "youtube.com" then
                            set found to true
                            exit repeat
                        end if
                    end repeat
                    if found then exit repeat
                end repeat
            end if
            if not found then return "false"
            activate
        end tell
        delay 0.15
        tell application "System Events"
            tell process "Safari"
                key code 53
                delay 0.05
                \(keyCmd)
            end tell
        end tell
        delay 0.08
        activate application prevApp
        return "true"
        """
    }
}
