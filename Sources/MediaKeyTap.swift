import Cocoa
import CoreGraphics

/// Media key event types
enum MediaKeyEvent {
    case playPause
    case next
    case previous
    case volumeUp
    case volumeDown
    case mute
}

/// Delegate protocol for media key events
protocol MediaKeyTapDelegate: AnyObject {
    func mediaKeyTap(_ tap: MediaKeyTap, receivedEvent event: MediaKeyEvent)
}

/// Intercepts system media key events using a CGEvent tap
class MediaKeyTap {

    weak var delegate: MediaKeyTapDelegate?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var interceptVolumeKeys = false
    private var isRunning = false
    private let lock = NSLock()

    // Media key codes (from IOKit/hidsystem)
    private static let NX_KEYTYPE_PLAY: UInt32 = 16
    private static let NX_KEYTYPE_NEXT: UInt32 = 17
    private static let NX_KEYTYPE_PREVIOUS: UInt32 = 18
    private static let NX_KEYTYPE_FAST: UInt32 = 19
    private static let NX_KEYTYPE_REWIND: UInt32 = 20
    private static let NX_KEYTYPE_SOUND_UP: UInt32 = 0
    private static let NX_KEYTYPE_SOUND_DOWN: UInt32 = 1
    private static let NX_KEYTYPE_MUTE: UInt32 = 7

    init(delegate: MediaKeyTapDelegate) {
        self.delegate = delegate
    }

    deinit {
        stop()
    }

    func setInterceptVolumeKeys(_ intercept: Bool) {
        lock.lock()
        interceptVolumeKeys = intercept
        lock.unlock()
    }

    func start() {
        lock.lock()
        guard !isRunning else {
            lock.unlock()
            return
        }
        lock.unlock()

        // Create event tap for system-defined events (media keys are NX_SYSDEFINED = 14)
        let nsSystemDefined: CGEventMask = (1 << 14)

        // Retain self for the C callback to prevent dangling pointer
        let userInfo = Unmanaged.passRetained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: nsSystemDefined,
            callback: MediaKeyTap.eventTapCallback,
            userInfo: userInfo
        ) else {
            // Balance the retain since we won't use the reference
            Unmanaged<MediaKeyTap>.fromOpaque(userInfo).release()
            print("Conduct: Failed to create event tap. Is Accessibility permission granted?")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let source = runLoopSource else {
            Unmanaged<MediaKeyTap>.fromOpaque(userInfo).release()
            print("Conduct: Failed to create run loop source")
            eventTap = nil
            return
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        lock.lock()
        isRunning = true
        lock.unlock()
    }

    func stop() {
        lock.lock()
        guard isRunning else {
            lock.unlock()
            return
        }
        isRunning = false
        lock.unlock()

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            // Balance the passRetained from start()
            var context = CFMachPortContext()
            CFMachPortGetContext(tap, &context)
            if let ptr = context.info {
                Unmanaged<MediaKeyTap>.fromOpaque(ptr).release()
            }
        }

        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Event Tap Callback

    private static let eventTapCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
        guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
        let tap = Unmanaged<MediaKeyTap>.fromOpaque(userInfo).takeUnretainedValue()

        // Handle tap disabled (system can disable it if it takes too long)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = tap.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Only handle system-defined events (type 14 = NX_SYSDEFINED)
        guard type.rawValue == 14 else {
            return Unmanaged.passUnretained(event)
        }

        // Parse the NSEvent from CGEvent
        let nsEvent = NSEvent(cgEvent: event)
        guard let nsEvent = nsEvent, nsEvent.subtype.rawValue == 8 else {
            // subtype 8 = media key events
            return Unmanaged.passUnretained(event)
        }

        // Extract key data from event
        let data1 = nsEvent.data1
        let keyCode = UInt32((data1 & 0xFFFF0000) >> 16)
        let keyFlags = UInt32(data1 & 0x0000FFFF)
        let keyState = (keyFlags & 0xFF00) >> 8 // 0x0A = key down, 0x0B = key up
        let keyRepeat = (keyFlags & 0x1) // 1 = repeat

        // Only handle key down events (not repeats for play/pause/next/prev)
        let isKeyDown = keyState == 0x0A
        let isKeyUp = keyState == 0x0B

        // Determine the media key event
        var mediaEvent: MediaKeyEvent?
        var isVolumeKey = false
        var isMediaKey = false

        switch keyCode {
        case NX_KEYTYPE_PLAY:
            isMediaKey = true
            if isKeyDown && keyRepeat == 0 {
                mediaEvent = .playPause
            }
        case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
            isMediaKey = true
            if isKeyDown && keyRepeat == 0 {
                mediaEvent = .next
            }
        case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
            isMediaKey = true
            if isKeyDown && keyRepeat == 0 {
                mediaEvent = .previous
            }
        case NX_KEYTYPE_SOUND_UP:
            if isKeyDown {
                mediaEvent = .volumeUp
                isVolumeKey = true
            }
        case NX_KEYTYPE_SOUND_DOWN:
            if isKeyDown {
                mediaEvent = .volumeDown
                isVolumeKey = true
            }
        case NX_KEYTYPE_MUTE:
            if isKeyDown && keyRepeat == 0 {
                mediaEvent = .mute
                isVolumeKey = true
            }
        default:
            break
        }

        // If it's a volume key and we're not intercepting those, pass through
        tap.lock.lock()
        let shouldInterceptVolume = tap.interceptVolumeKeys
        tap.lock.unlock()
        if isVolumeKey && !shouldInterceptVolume {
            return Unmanaged.passUnretained(event)
        }

        // If we have a media event, handle it and consume the event
        if let mediaEvent = mediaEvent {
            DispatchQueue.main.async {
                tap.delegate?.mediaKeyTap(tap, receivedEvent: mediaEvent)
            }
            return nil
        }

        // Consume ALL key-down and key-up events for media keys
        // (including repeats) to prevent other apps from seeing them
        if isMediaKey {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }
}
