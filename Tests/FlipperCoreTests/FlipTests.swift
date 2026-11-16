import XCTest
@testable import FlipperCore

final class FlipTests: XCTestCase {
    func testDevice() {
        XCTAssertEqual(ScrollDevice(isContinuous: false), .mouse)
        XCTAssertEqual(ScrollDevice(isContinuous: true), .trackpad)
    }

    func testDefaultsFlipTheMouseBothWaysAndLeaveTheTrackpad() {
        let s = FlipSettings()
        XCTAssertEqual(s.axes(for: .mouse), Axes(vertical: true, horizontal: true))
        XCTAssertEqual(s.axes(for: .trackpad), .none)
    }

    func testEachDeviceAndAxisIsSeparate() {
        var s = FlipSettings()
        s.mouse = false
        s.trackpad = true
        s.horizontal = false
        XCTAssertEqual(s.axes(for: .mouse), .none)
        XCTAssertEqual(s.axes(for: .trackpad), Axes(vertical: true, horizontal: false))
    }

    func testFlipsNothingWithNoDeviceOrNoAxis() {
        var s = FlipSettings()
        s.mouse = false
        XCTAssertEqual(s.axes(for: .mouse), .none)
        XCTAssertEqual(s.axes(for: .trackpad), .none)
        s = FlipSettings()
        s.vertical = false
        s.horizontal = false
        XCTAssertEqual(s.axes(for: .mouse), .none)
    }

    func testSavedSettingsComeBack() throws {
        let suite = "FlipperTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(FlipSettings(defaults: defaults), FlipSettings())
        var s = FlipSettings()
        s.mouse = false
        s.trackpad = true
        s.vertical = false
        s.save(to: defaults)
        XCTAssertEqual(FlipSettings(defaults: defaults), s)
    }

    func testFlipNegatesEveryFormOfTheChosenAxes() {
        let d = ScrollDeltas(lines: (3, -1), points: (30, -10), fixed: (2.5, -0.75))
        XCTAssertEqual(d.flipped(Axes(vertical: true, horizontal: false)),
                       ScrollDeltas(lines: (-3, -1), points: (-30, -10), fixed: (-2.5, -0.75)))
        XCTAssertEqual(d.flipped(Axes(vertical: false, horizontal: true)),
                       ScrollDeltas(lines: (3, 1), points: (30, 10), fixed: (2.5, 0.75)))
        XCTAssertEqual(d.flipped(.none), d)
    }
}
