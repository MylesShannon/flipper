import Foundation

public enum ScrollDevice: Equatable {
    case mouse, trackpad

    /// Trackpads scroll smoothly in pixels and mouse wheels in whole lines, which is how the two are told apart.
    /// A Magic Mouse also scrolls in pixels, so it counts as a trackpad.
    public init(isContinuous: Bool) {
        self = isContinuous ? .trackpad : .mouse
    }
}

public struct Axes: Equatable {
    public var vertical: Bool
    public var horizontal: Bool

    public init(vertical: Bool, horizontal: Bool) {
        self.vertical = vertical
        self.horizontal = horizontal
    }

    public static let none = Axes(vertical: false, horizontal: false)
}

public struct FlipSettings: Equatable {
    public var mouse = true
    public var trackpad = false
    public var vertical = true
    public var horizontal = true

    public init() {}

    public init(defaults: UserDefaults) {
        mouse = defaults.object(forKey: Key.mouse) as? Bool ?? mouse
        trackpad = defaults.object(forKey: Key.trackpad) as? Bool ?? trackpad
        vertical = defaults.object(forKey: Key.vertical) as? Bool ?? vertical
        horizontal = defaults.object(forKey: Key.horizontal) as? Bool ?? horizontal
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(mouse, forKey: Key.mouse)
        defaults.set(trackpad, forKey: Key.trackpad)
        defaults.set(vertical, forKey: Key.vertical)
        defaults.set(horizontal, forKey: Key.horizontal)
    }

    public func axes(for device: ScrollDevice) -> Axes {
        let on = device == .mouse ? mouse : trackpad
        return on ? Axes(vertical: vertical, horizontal: horizontal) : .none
    }

    public var flipsAnything: Bool {
        (mouse || trackpad) && (vertical || horizontal)
    }

    enum Key {
        static let mouse = "flipMouse"
        static let trackpad = "flipTrackpad"
        static let vertical = "flipVertical"
        static let horizontal = "flipHorizontal"
    }
}

/// A scroll event carries each axis three ways (lines, pixels and fixed-point lines), and apps read different ones,
/// so all three are flipped together. Axis 1 is up and down, axis 2 left and right.
public struct ScrollDeltas: Equatable {
    public var lines: (vertical: Int64, horizontal: Int64)
    public var points: (vertical: Int64, horizontal: Int64)
    public var fixed: (vertical: Double, horizontal: Double)

    public init(lines: (Int64, Int64), points: (Int64, Int64), fixed: (Double, Double)) {
        self.lines = lines
        self.points = points
        self.fixed = fixed
    }

    public func flipped(_ axes: Axes) -> ScrollDeltas {
        var d = self
        if axes.vertical {
            d.lines.vertical.negate()
            d.points.vertical.negate()
            d.fixed.vertical.negate()
        }
        if axes.horizontal {
            d.lines.horizontal.negate()
            d.points.horizontal.negate()
            d.fixed.horizontal.negate()
        }
        return d
    }

    public static func == (a: ScrollDeltas, b: ScrollDeltas) -> Bool {
        a.lines == b.lines && a.points == b.points && a.fixed == b.fixed
    }
}
