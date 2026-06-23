import Foundation
import Cocoa
import UserNotifications

/// Auto-detection controller that finds the currently active/playing music app
/// Priority: currently playing > most recently launched > first running
/// Once resolved, stays "sticky" - only switches when the current target stops running.
class AutoController: MusicControllerProtocol {
    let appName = "Auto"
    let bundleIdentifier = "auto"

    private var resolvedController: (any MusicControllerProtocol)?
    private var resolvedApp: MusicApp?
    private var lastResolvedTime: Date = .distantPast
    private var lastCommandTime: Date = .distantPast
    private let cacheInterval: TimeInterval = 1.5 // Re-resolve every 1.5 seconds
    private let stickyInterval: TimeInterval = 300 // Stay sticky for 5 minutes after last command
    private let lock = NSLock() // Thread safety for resolution cache
    private var isRefreshing = false // Prevents duplicate background refreshes

    init() {
        // Trigger initial resolution eagerly so first key press isn't dropped
        appleScriptQueue.async { [weak self] in
            guard let self = self else { return }
            let detectedApp = self.detectActiveApp()

            self.lock.lock()
            self.resolvedApp = detectedApp
            if let app = detectedApp {
                self.resolvedController = MusicControllerFactory.controller(for: app)
            }
            self.lastResolvedTime = Date()
            self.lock.unlock()
        }
    }

    /// The bundle identifier of the currently resolved target app (nil if unresolved)
    var resolvedBundleIdentifier: String? {
        lock.lock()
        let id = resolvedController?.bundleIdentifier
        lock.unlock()
        return id
    }

    var isRunning: Bool {
        return resolve() != nil
    }

    func playPause() {
        resolve()?.playPause()
        markCommandSent()
    }

    func nextTrack() {
        resolve()?.nextTrack()
        markCommandSent()
    }

    func previousTrack() {
        resolve()?.previousTrack()
        markCommandSent()
    }

    func volumeUp() {
        resolve()?.volumeUp()
        markCommandSent()
    }

    func volumeDown() {
        resolve()?.volumeDown()
        markCommandSent()
    }

    func mute() {
        resolve()?.mute()
        markCommandSent()
    }

    private func markCommandSent() {
        lock.lock()
        lastCommandTime = Date()
        lock.unlock()
    }

    // MARK: - Resolution

    /// Resolves the best music controller to use right now.
    /// If we recently sent a command, stays sticky with the current controller
    /// as long as it's still running.
    /// Returns the cached controller immediately and triggers a background refresh
    /// when the cache is stale, to avoid blocking the main thread with AppleScript IPC.
    @discardableResult
    private func resolve() -> (any MusicControllerProtocol)? {
        lock.lock()
        let now = Date()

        // If we have a sticky controller and recently sent a command, keep it
        // as long as the target is still running
        if let cached = resolvedController,
           now.timeIntervalSince(lastCommandTime) < stickyInterval {
            lastResolvedTime = now
            lock.unlock()
            // Verify it's still running OUTSIDE the lock (isRunning may do I/O)
            if cached.isRunning {
                return cached
            }
            // Target stopped running - re-acquire lock and fall through to re-resolve
            lock.lock()
        }

        // Normal cache: avoid re-resolving too frequently
        if let cached = resolvedController, now.timeIntervalSince(lastResolvedTime) < cacheInterval {
            let controller = cached
            lock.unlock()
            return controller
        }

        // Cache is stale - return current value immediately, refresh in background
        let stale = resolvedController
        lastResolvedTime = now // Prevent re-triggering while refresh is in flight

        if !isRefreshing {
            isRefreshing = true
            lock.unlock()

            appleScriptQueue.async { [weak self] in
                guard let self = self else { return }
                let detectedApp = self.detectActiveApp()

                self.lock.lock()
                self.isRefreshing = false
                if detectedApp != self.resolvedApp {
                    let previousApp = self.resolvedApp
                    self.resolvedApp = detectedApp
                    if let app = detectedApp {
                        self.resolvedController = MusicControllerFactory.controller(for: app)
                        if previousApp != nil && Preferences.shared.notifyOnSwitch {
                            DispatchQueue.main.async {
                                let content = UNMutableNotificationContent()
                                content.title = "Conduct"
                                content.body = "Auto switched to \(app.displayName)"
                                let request = UNNotificationRequest(identifier: "conduct-auto-switch", content: content, trigger: nil)
                                UNUserNotificationCenter.current().add(request)
                            }
                        }
                    } else {
                        self.resolvedController = nil
                    }
                }
                self.lastResolvedTime = Date()
                self.lock.unlock()
            }
        } else {
            lock.unlock()
        }

        return stale
    }

    /// Detection algorithm:
    /// 1. Filter out ignored apps
    /// 2. Check if any music app is currently playing (via AppleScript player state)
    /// 3. Use priority order if set
    /// 4. Fall back to the most recently activated running music app
    /// 5. Fall back to first running app
    private func detectActiveApp() -> MusicApp? {
        let ignoredApps = Set(Preferences.shared.ignoredApps)

        // Phase 1: Check which apps are running (excluding ignored)
        let runningApps = MusicApp.selectablePlayers.filter { app in
            guard !ignoredApps.contains(app.rawValue) else { return false }
            if app.isBrowserBased {
                let controller = MusicControllerFactory.controller(for: app)
                return controller.isRunning
            }
            return NSRunningApplication.runningApplications(withBundleIdentifier: app.rawValue).first != nil
        }

        if runningApps.isEmpty {
            return nil
        }

        // Phase 2: Check which app is actually playing
        if let playing = findPlayingApp(among: runningApps) {
            return playing
        }

        // Phase 3: Use priority order (custom if set, otherwise the default)
        let priority = Preferences.shared.autoPriority.isEmpty
            ? MusicApp.defaultPriority.map { $0.rawValue }
            : Preferences.shared.autoPriority
        for rawValue in priority {
            if let app = MusicApp(rawValue: rawValue), runningApps.contains(app) {
                return app
            }
        }

        // Phase 4: Return the most recently activated music app
        if let recent = findMostRecentApp(among: runningApps) {
            return recent
        }

        // Phase 5: Just use the first running one
        return runningApps[0]
    }

    /// Checks player state via AppleScript to find which app is currently playing.
    /// Only queries apps that are confirmed running (cheap NSRunningApplication check already done).
    private func findPlayingApp(among apps: [MusicApp]) -> MusicApp? {
        for app in apps {
            if app.isBrowserBased { continue }

            // Use "running" check in the script itself to avoid launching the app
            let scriptSource: String
            switch app {
            case .appleMusic:
                scriptSource = "if application \"Music\" is running then tell application \"Music\" to get player state"
            case .spotify:
                scriptSource = "if application \"Spotify\" is running then tell application \"Spotify\" to get player state"
            case .doppler:
                scriptSource = "if application \"Doppler\" is running then tell application \"Doppler\" to get player state"
            case .vox:
                scriptSource = "if application \"VOX\" is running then tell application \"VOX\" to get player state"
            default:
                let name = app.displayName
                scriptSource = "if application \"\(name)\" is running then tell application \"\(name)\" to get player state"
            }

            let script = NSAppleScript(source: scriptSource)
            var error: NSDictionary?
            if let result = script?.executeAndReturnError(&error) {
                let state = result.stringValue ?? ""
                if state.lowercased().contains("play") || state == "kPSP" {
                    return app
                }
            }
        }
        return nil
    }

    /// Returns the most recently activated running music app
    private func findMostRecentApp(among apps: [MusicApp]) -> MusicApp? {
        var bestApp: MusicApp?
        var bestDate: Date = .distantPast

        for app in apps {
            if app.isBrowserBased { continue }
            if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: app.rawValue).first,
               let launchDate = runningApp.launchDate, launchDate > bestDate {
                bestDate = launchDate
                bestApp = app
            }
        }
        return bestApp
    }
}
