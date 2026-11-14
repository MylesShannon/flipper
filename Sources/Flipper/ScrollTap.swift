import ApplicationServices
import FlipperCore

/// Rewrites scroll events on their way to apps. macOS only lets an app with Accessibility change other apps' events.
final class ScrollTap {
    var settings: FlipSettings
    private var tap: CFMachPort?

    init(settings: FlipSettings) {
        self.settings = settings
    }

    var isRunning: Bool { tap != nil }

    func start() -> Bool {
        if tap != nil { return true }
        guard AXIsProcessTrusted() else { return false }
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
            callback: { _, type, event, info in
                Unmanaged<ScrollTap>.fromOpaque(info!).takeUnretainedValue().handle(type, event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        return true
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .scrollWheel:
            let device = ScrollDevice(isContinuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0)
            let axes = settings.axes(for: device)
            if axes != .none { write(read(event).flipped(axes), to: event) }
        default:
            break
        }
    }

    private func read(_ e: CGEvent) -> ScrollDeltas {
        ScrollDeltas(
            lines: (e.getIntegerValueField(.scrollWheelEventDeltaAxis1), e.getIntegerValueField(.scrollWheelEventDeltaAxis2)),
            points: (e.getIntegerValueField(.scrollWheelEventPointDeltaAxis1), e.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)),
            fixed: (e.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1), e.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)))
    }

    // The line delta goes first, because setting it can recompute the other two.
    private func write(_ d: ScrollDeltas, to e: CGEvent) {
        e.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: d.lines.vertical)
        e.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: d.lines.horizontal)
        e.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: d.points.vertical)
        e.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: d.points.horizontal)
        e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: d.fixed.vertical)
        e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: d.fixed.horizontal)
    }
}
