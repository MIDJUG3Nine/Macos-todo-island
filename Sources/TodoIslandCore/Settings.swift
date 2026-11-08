import Foundation

/// The panels the island can show. To add a panel: add a case here, give it a title and
/// an SF Symbol, then add its view in `PanelContentView` (app target).
public enum PanelID: String, CaseIterable, Codable, Identifiable, Sendable {
    case todo
    case notes

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .todo: return "checklist"
        case .notes: return "note.text"
        }
    }

    public func title(_ language: AppLanguage) -> String {
        switch self {
        case .todo: return language.pick(en: "Todo", zh: "待办")
        case .notes: return language.pick(en: "Notes", zh: "便签")
        }
    }
}

/// How big the open island is.
public enum PanelSize: String, CaseIterable, Codable, Identifiable, Sendable {
    case compact
    case regular
    case large

    public var id: String { rawValue }

    public var dimensions: (width: Double, height: Double) {
        switch self {
        case .compact: return (360, 260)
        case .regular: return (440, 320)
        case .large: return (540, 420)
        }
    }

    public func title(_ language: AppLanguage) -> String {
        switch self {
        case .compact: return language.pick(en: "Compact", zh: "小")
        case .regular: return language.pick(en: "Regular", zh: "中")
        case .large: return language.pick(en: "Large", zh: "大")
        }
    }
}

/// User preferences. Every field decodes with a default, so adding a field in a later
/// version never wipes the user's existing settings.
public struct IslandSettings: Codable, Equatable, Sendable {
    /// The panel shown when the island opens.
    public var defaultPanel: PanelID
    /// Panels shown as tabs, in `PanelID.allCases` order. Never empty after `normalized()`.
    public var enabledPanels: [PanelID]
    /// Seconds the pointer must rest on the notch before the island opens.
    public var hoverDelay: Double
    /// Seconds after the pointer leaves before the island closes.
    public var collapseDelay: Double
    public var panelSize: PanelSize
    /// On a Mac without a notch (or an external display), show a small pill at the top
    /// centre of the menu bar instead.
    public var showOnScreensWithoutNotch: Bool
    /// Remember the last panel instead of always opening `defaultPanel`.
    public var rememberLastPanel: Bool

    public static let hoverDelayRange: ClosedRange<Double> = 0...1.5
    public static let collapseDelayRange: ClosedRange<Double> = 0...2

    public init(
        defaultPanel: PanelID = .todo,
        enabledPanels: [PanelID] = PanelID.allCases,
        hoverDelay: Double = 0.15,
        collapseDelay: Double = 0.4,
        panelSize: PanelSize = .regular,
        showOnScreensWithoutNotch: Bool = true,
        rememberLastPanel: Bool = false
    ) {
        self.defaultPanel = defaultPanel
        self.enabledPanels = enabledPanels
        self.hoverDelay = hoverDelay
        self.collapseDelay = collapseDelay
        self.panelSize = panelSize
        self.showOnScreensWithoutNotch = showOnScreensWithoutNotch
        self.rememberLastPanel = rememberLastPanel
    }

    public init(from decoder: Decoder) throws {
        let defaults = IslandSettings()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultPanel = (try? c.decodeIfPresent(PanelID.self, forKey: .defaultPanel)) ?? defaults.defaultPanel
        // Unknown panel names (from a newer version) are dropped instead of failing the whole decode.
        if let raw = try? c.decodeIfPresent([String].self, forKey: .enabledPanels) {
            enabledPanels = raw.compactMap(PanelID.init(rawValue:))
        } else {
            enabledPanels = defaults.enabledPanels
        }
        hoverDelay = (try? c.decodeIfPresent(Double.self, forKey: .hoverDelay)) ?? defaults.hoverDelay
        collapseDelay = (try? c.decodeIfPresent(Double.self, forKey: .collapseDelay)) ?? defaults.collapseDelay
        panelSize = (try? c.decodeIfPresent(PanelSize.self, forKey: .panelSize)) ?? defaults.panelSize
        showOnScreensWithoutNotch = (try? c.decodeIfPresent(Bool.self, forKey: .showOnScreensWithoutNotch))
            ?? defaults.showOnScreensWithoutNotch
        rememberLastPanel = (try? c.decodeIfPresent(Bool.self, forKey: .rememberLastPanel))
            ?? defaults.rememberLastPanel
        self = normalized()
    }

    /// Fixes values that would leave the app in a bad state: no panels, a default panel
    /// that is switched off, or delays out of range.
    public func normalized() -> IslandSettings {
        var copy = self
        let enabled = Set(enabledPanels)
        copy.enabledPanels = PanelID.allCases.filter { enabled.contains($0) }
        if copy.enabledPanels.isEmpty {
            copy.enabledPanels = [.todo]
        }
        if !copy.enabledPanels.contains(copy.defaultPanel) {
            copy.defaultPanel = copy.enabledPanels[0]
        }
        copy.hoverDelay = Self.clamp(hoverDelay, to: Self.hoverDelayRange)
        copy.collapseDelay = Self.clamp(collapseDelay, to: Self.collapseDelayRange)
        return copy
    }

    /// Turns a panel on or off, keeping at least one panel on.
    public mutating func setPanel(_ panel: PanelID, enabled: Bool) {
        if enabled {
            enabledPanels.append(panel)
        } else {
            enabledPanels.removeAll { $0 == panel }
        }
        self = normalized()
    }

    /// The panel to show when the island opens, given the last one the user looked at.
    public func panelToOpen(last: PanelID?) -> PanelID {
        if rememberLastPanel, let last, enabledPanels.contains(last) {
            return last
        }
        return defaultPanel
    }

    private static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return range.lowerBound }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

/// Reads and writes `IslandSettings` as one JSON blob in `UserDefaults`.
public struct SettingsStore {
    public static let key = "islandSettings"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> IslandSettings {
        guard let data = defaults.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(IslandSettings.self, from: data) else {
            return IslandSettings()
        }
        return settings
    }

    public func save(_ settings: IslandSettings) {
        guard let data = try? JSONEncoder().encode(settings.normalized()) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
