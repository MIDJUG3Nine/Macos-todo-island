import Foundation

/// Decides when the island opens and closes, from pointer position and time only.
///
/// Rules:
/// - Closed: the pointer must stay on the notch for `hoverDelay` seconds to open it.
/// - Open and not pinned (just peeking): it closes `collapseDelay` seconds after the
///   pointer leaves the panel, unless the pointer comes back first.
/// - Open and pinned (the user clicked into it, e.g. to type): pointer position is
///   ignored; it closes only on `collapse()` (click outside, Esc, menu).
///
/// The app feeds in pointer moves via `update` and, when `nextDeadline` is set, calls
/// `update` again at that time.
public struct HoverState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case collapsed
        case expanded
    }

    public var hoverDelay: TimeInterval
    public var collapseDelay: TimeInterval

    public private(set) var phase: Phase = .collapsed
    public private(set) var isPinned = false
    private var enteredAt: TimeInterval?
    private var leftAt: TimeInterval?

    public init(hoverDelay: TimeInterval, collapseDelay: TimeInterval) {
        self.hoverDelay = max(0, hoverDelay)
        self.collapseDelay = max(0, collapseDelay)
    }

    public var isExpanded: Bool { phase == .expanded }

    /// Feed the latest pointer state. Returns true when `phase` changed.
    @discardableResult
    public mutating func update(inTrigger: Bool, inPanel: Bool, now: TimeInterval) -> Bool {
        switch phase {
        case .collapsed:
            guard inTrigger else {
                enteredAt = nil
                return false
            }
            let start = enteredAt ?? now
            enteredAt = start
            if Self.reached(now - start, hoverDelay) {
                expand()
                return true
            }
            return false

        case .expanded:
            if isPinned || inPanel {
                leftAt = nil
                return false
            }
            let start = leftAt ?? now
            leftAt = start
            if Self.reached(now - start, collapseDelay) {
                collapse()
                return true
            }
            return false
        }
    }

    /// When the app should call `update` again even if the pointer does not move.
    public var nextDeadline: TimeInterval? {
        switch phase {
        case .collapsed:
            return enteredAt.map { $0 + hoverDelay }
        case .expanded:
            guard !isPinned else { return nil }
            return leftAt.map { $0 + collapseDelay }
        }
    }

    /// Open right away (menu bar icon, keyboard shortcut).
    public mutating func expand(pinned: Bool = false) {
        phase = .expanded
        enteredAt = nil
        leftAt = nil
        if pinned { isPinned = true }
    }

    /// Keep the island open regardless of the pointer.
    public mutating func pin() {
        guard phase == .expanded else { return }
        isPinned = true
        leftAt = nil
    }

    public mutating func unpin() {
        isPinned = false
    }

    /// Timers fire at the deadline itself, where float rounding can leave `elapsed` a hair
    /// short of `delay` (10.2 - 10 < 0.2). Allow a microsecond so the deadline tick counts.
    private static func reached(_ elapsed: TimeInterval, _ delay: TimeInterval) -> Bool {
        elapsed + 1e-6 >= delay
    }

    public mutating func collapse() {
        phase = .collapsed
        isPinned = false
        enteredAt = nil
        leftAt = nil
    }
}
