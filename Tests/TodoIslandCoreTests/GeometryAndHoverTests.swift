import XCTest
@testable import TodoIslandCore

final class NotchLayoutTests: XCTestCase {
    /// Roughly a 14-inch MacBook Pro at default scaling.
    private let notched = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        safeAreaTop: 32,
        auxiliaryLeftWidth: 662,
        auxiliaryRightWidth: 662,
        menuBarHeight: 24
    )

    func testHardwareNotchRect() {
        let layout = NotchLayout(screen: notched)
        XCTAssertTrue(layout.isHardwareNotch)
        XCTAssertEqual(layout.notchRect, CGRect(x: 662, y: 950, width: 188, height: 32))
        XCTAssertEqual(layout.collapsedFrame, CGRect(x: 652, y: 950, width: 208, height: 32))
    }

    func testHoverZoneReachesPastTopEdge() {
        let layout = NotchLayout(screen: notched)
        XCTAssertTrue(layout.hoverZone.contains(CGPoint(x: 756, y: 982)))
        XCTAssertTrue(layout.hoverZone.contains(CGPoint(x: 655, y: 960)))
        XCTAssertFalse(layout.hoverZone.contains(CGPoint(x: 756, y: 940)))
        XCTAssertFalse(layout.hoverZone.contains(CGPoint(x: 600, y: 970)))
    }

    func testVirtualNotchOnPlainDisplay() {
        let external = ScreenMetrics(frame: CGRect(x: 1512, y: -200, width: 2560, height: 1440), menuBarHeight: 25)
        let layout = NotchLayout(screen: external)
        XCTAssertFalse(layout.isHardwareNotch)
        XCTAssertEqual(layout.notchRect.width, NotchLayout.virtualNotchWidth)
        XCTAssertEqual(layout.notchRect.height, 25)
        XCTAssertEqual(layout.notchRect.midX, external.frame.midX)
        XCTAssertEqual(layout.notchRect.maxY, external.frame.maxY)
    }

    func testSafeAreaWithoutAuxiliaryAreasIsNotANotch() {
        var screen = notched
        screen.auxiliaryLeftWidth = nil
        XCTAssertFalse(NotchLayout(screen: screen).isHardwareNotch)
    }

    func testExpandedFrameHangsFromTopCentred() {
        let layout = NotchLayout(screen: notched)
        let frame = layout.expandedFrame(width: 440, height: 320)
        XCTAssertEqual(frame.width, 440)
        XCTAssertEqual(frame.height, 320)
        XCTAssertEqual(frame.maxY, 982)
        XCTAssertEqual(frame.midX, layout.notchRect.midX)
    }

    func testExpandedFrameIsClampedToScreen() {
        let small = ScreenMetrics(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let layout = NotchLayout(screen: small)
        let frame = layout.expandedFrame(width: 1000, height: 1000)
        XCTAssertEqual(frame, CGRect(x: 0, y: 0, width: 300, height: 200))
    }

    func testExpandedHoverZoneHasMargin() {
        let layout = NotchLayout(screen: notched)
        let zone = layout.expandedHoverZone(width: 440, height: 320)
        XCTAssertTrue(zone.contains(CGPoint(x: layout.notchRect.midX, y: 982 - 320 - 4)))
        XCTAssertFalse(zone.contains(CGPoint(x: layout.notchRect.midX, y: 982 - 320 - 20)))
    }
}

final class HoverStateTests: XCTestCase {
    func testOpensOnlyAfterHoverDelay() {
        var state = HoverState(hoverDelay: 0.2, collapseDelay: 0.4)
        XCTAssertFalse(state.update(inTrigger: true, inPanel: false, now: 10))
        XCTAssertEqual(state.nextDeadline ?? 0, 10.2, accuracy: 1e-9)
        XCTAssertFalse(state.update(inTrigger: true, inPanel: false, now: 10.1))
        XCTAssertTrue(state.update(inTrigger: true, inPanel: true, now: 10.2))
        XCTAssertTrue(state.isExpanded)
    }

    func testLeavingBeforeDelayCancels() {
        var state = HoverState(hoverDelay: 0.2, collapseDelay: 0.4)
        state.update(inTrigger: true, inPanel: false, now: 0)
        state.update(inTrigger: false, inPanel: false, now: 0.1)
        XCTAssertNil(state.nextDeadline)
        XCTAssertFalse(state.update(inTrigger: true, inPanel: false, now: 0.25), "timer restarts on re-entry")
        XCTAssertFalse(state.isExpanded)
    }

    func testZeroDelayOpensImmediately() {
        var state = HoverState(hoverDelay: 0, collapseDelay: 0)
        XCTAssertTrue(state.update(inTrigger: true, inPanel: false, now: 5))
        XCTAssertTrue(state.update(inTrigger: false, inPanel: false, now: 5.01))
        XCTAssertFalse(state.isExpanded)
    }

    func testClosesAfterLeavingUnlessPointerReturns() {
        var state = HoverState(hoverDelay: 0, collapseDelay: 0.4)
        state.update(inTrigger: true, inPanel: true, now: 0)
        XCTAssertFalse(state.update(inTrigger: false, inPanel: false, now: 1))
        XCTAssertEqual(state.nextDeadline ?? 0, 1.4, accuracy: 1e-9)
        XCTAssertFalse(state.update(inTrigger: false, inPanel: true, now: 1.2))
        XCTAssertNil(state.nextDeadline)
        XCTAssertFalse(state.update(inTrigger: false, inPanel: false, now: 2))
        XCTAssertTrue(state.update(inTrigger: false, inPanel: false, now: 2.4))
        XCTAssertFalse(state.isExpanded)
    }

    func testPinnedIgnoresPointerUntilCollapse() {
        var state = HoverState(hoverDelay: 0, collapseDelay: 0.1)
        state.update(inTrigger: true, inPanel: true, now: 0)
        state.pin()
        XCTAssertFalse(state.update(inTrigger: false, inPanel: false, now: 5))
        XCTAssertNil(state.nextDeadline)
        XCTAssertTrue(state.isExpanded)
        state.collapse()
        XCTAssertFalse(state.isExpanded)
        XCTAssertFalse(state.isPinned)
    }

    func testPinDoesNothingWhileCollapsed() {
        var state = HoverState(hoverDelay: 0.3, collapseDelay: 0.1)
        state.pin()
        XCTAssertFalse(state.isPinned)
        state.expand(pinned: true)
        XCTAssertTrue(state.isExpanded)
        XCTAssertTrue(state.isPinned)
    }
}
