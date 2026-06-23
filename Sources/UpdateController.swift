import Cocoa
import Sparkle

/// Manages Sparkle auto-update functionality
class UpdateController: NSObject {

    static let shared = UpdateController()

    private let updaterController: SPUStandardUpdaterController

    private override init() {
        // startingUpdater: true means it will automatically check on schedule
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    @objc func checkForUpdates(_ sender: Any?) {
        updaterController.checkForUpdates(sender)
    }

    /// Whether the updater can check for updates right now
    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    /// Whether Sparkle checks for updates automatically on its schedule.
    /// Backed by Sparkle's own persisted setting (defaults to the value of
    /// `SUEnableAutomaticChecks` in Info.plist - currently on).
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
}
