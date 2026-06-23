import Foundation
import ServiceManagement
import AppKit

/// Manages the "Launch at Login" functionality across macOS versions
class LaunchAtLoginManager {

    private static let launchAgentLabel = "com.conductapp.Conduct"

    /// Updates the login item and returns the resulting *actual* enabled state.
    /// The returned value reflects the real system state, which may differ from the
    /// requested value (e.g. when the change still requires user approval).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            return setEnabledModern(enabled)
        } else {
            return setEnabledLegacy(enabled)
        }
    }

    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
    }

    /// Reconciles the stored `launchAtLogin` preference with the real system state.
    /// Call this on launch and whenever the Settings UI appears so the toggle always
    /// reflects the truth (the user can disable the login item in System Settings).
    static func synchronize() {
        let actual = isEnabled()
        if UserDefaults.standard.bool(forKey: "launchAtLogin") != actual {
            UserDefaults.standard.set(actual, forKey: "launchAtLogin")
        }
    }

    @available(macOS 13.0, *)
    private static func setEnabledModern(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if enabled {
                // Already registered? Nothing to do.
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status != .notRegistered {
                    try service.unregister()
                }
            }
        } catch {
            print("Conduct: Failed to update login item: \(error.localizedDescription) (status=\(service.status.rawValue))")
        }

        let status = service.status
        #if DEBUG
        print("[LaunchAtLogin] requested=\(enabled) resultingStatus=\(status.rawValue)")
        #endif

        // When enabling requires the user's approval, guide them to the right pane.
        if enabled && status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }

        return status == .enabled
    }

    private static func setEnabledLegacy(_ enabled: Bool) -> Bool {
        // For macOS 11-12, install/remove a LaunchAgent plist
        UserDefaults.standard.set(enabled, forKey: "launchAtLogin")

        let launchAgentsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let plistPath = launchAgentsDir.appendingPathComponent("\(launchAgentLabel).plist")

        if enabled {
            guard let appPath = Bundle.main.bundlePath as String? else { return false }
            let plistContent: [String: Any] = [
                "Label": launchAgentLabel,
                "ProgramArguments": ["\(appPath)/Contents/MacOS/Conduct"],
                "RunAtLoad": true,
                "LimitLoadToSessionType": "Aqua"
            ]
            try? FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
            let success = (plistContent as NSDictionary).write(to: plistPath, atomically: true)
            if !success {
                // Revert the preference so the UI reflects the actual state
                UserDefaults.standard.set(false, forKey: "launchAtLogin")
                print("Conduct: Failed to write LaunchAgent plist at \(plistPath.path)")
                return false
            }
            return true
        } else {
            try? FileManager.default.removeItem(at: plistPath)
            return false
        }
    }
}
