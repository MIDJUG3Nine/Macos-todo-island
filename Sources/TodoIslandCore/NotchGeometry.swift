import CoreGraphics
import Foundation

/// What we need to know about a display, in AppKit screen coordinates
/// (origin at the bottom-left of the main display, y grows upwards).
public struct ScreenMetrics: Equatable, Sendable {
    public var frame: CGRect
    /// `NSScreen.safeAreaInsets.top`. Greater than zero only on displays with a camera housing.
    public var safeAreaTop: CGFloat
    /// Widths of `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` (the menu bar
    /// space left and right of the notch). Nil on displays without a notch.
    public var auxiliaryLeftWidth: CGFloat?
    public var auxiliaryRightWidth: CGFloat?
    /// `NSStatusBar.system.thickness`, used for the pill on displays without a notch.
    public var menuBarHeight: CGFloat

    public init(
        frame: CGRect,
        safeAreaTop: CGFloat = 0,
        auxiliaryLeftWidth: CGFloat? = nil,
        auxiliaryRightWidth: CGFloat? = nil,
        menuBarHeight: CGFloat = 24
    ) {
        self.frame = frame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryLeftWidth = auxiliaryLeftWidth
        self.auxiliaryRightWidth = auxiliaryRightWidth
        self.menuBarHeight = menuBarHeight
    }

    public var hasNotch: Bool {
        safeAreaTop > 0 && auxiliaryLeftWidth != nil && auxiliaryRightWidth != nil
    }
}

/// Where the island sits on one display. All rects are in screen coordinates.
public struct NotchLayout: Equatable, Sendable {
    /// Size of the pill drawn on displays without a notch.
    public static let virtualNotchWidth: CGFloat = 180
    /// Extra hover room on each side of the notch, so it is easy to hit.
    public static let hoverPadding: CGFloat = 10

    public let screenFrame: CGRect
    /// The camera housing, or the virtual pill on displays without one.
    public let notchRect: CGRect
    public let isHardwareNotch: Bool

    public init(screen: ScreenMetrics) {
        screenFrame = screen.frame
        if screen.hasNotch,
           let left = screen.auxiliaryLeftWidth,
           let right = screen.auxiliaryRightWidth,
           screen.frame.width - left - right > 0 {
            let width = screen.frame.width - left - right
            let height = screen.safeAreaTop
            notchRect = CGRect(
                x: screen.frame.minX + left,
                y: screen.frame.maxY - height,
                width: width,
                height: height
            )
            isHardwareNotch = true
        } else {
            let width = Self.virtualNotchWidth
            let height = max(screen.menuBarHeight, 1)
            notchRect = CGRect(
                x: screen.frame.midX - width / 2,
                y: screen.frame.maxY - height,
                width: width,
                height: height
            )
            isHardwareNotch = false
        }
    }

    /// Window frame while closed: the notch plus a little room on each side.
    public var collapsedFrame: CGRect {
        notchRect.insetBy(dx: -Self.hoverPadding, dy: 0)
    }

    /// Area that opens the island. Reaches a few points above the screen edge because the
    /// pointer's y can sit exactly on `maxY` when it is pushed against the top.
    public var hoverZone: CGRect {
        let frame = collapsedFrame
        return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height + 4)
    }

    /// Window frame while open: hangs from the top edge, centred on the notch, never wider
    /// than the screen and never narrower than the notch.
    public func expandedFrame(width: CGFloat, height: CGFloat) -> CGRect {
        let w = min(max(width, notchRect.width + 2 * Self.hoverPadding), screenFrame.width)
        let h = min(max(height, notchRect.height), screenFrame.height)
        var x = notchRect.midX - w / 2
        x = min(max(x, screenFrame.minX), screenFrame.maxX - w)
        return CGRect(x: x, y: screenFrame.maxY - h, width: w, height: h)
    }

    /// Area that keeps the open island open (the panel plus a small margin, and above the edge).
    public func expandedHoverZone(width: CGFloat, height: CGFloat, margin: CGFloat = 8) -> CGRect {
        let frame = expandedFrame(width: width, height: height)
        return CGRect(
            x: frame.minX - margin,
            y: frame.minY - margin,
            width: frame.width + 2 * margin,
            height: frame.height + margin + 4
        )
    }
}
