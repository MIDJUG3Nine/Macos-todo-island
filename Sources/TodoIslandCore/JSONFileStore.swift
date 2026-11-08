import Foundation

/// Where Todo Island keeps its files.
public enum AppPaths {
    /// `~/Library/Application Support/TodoIsland` on macOS.
    public static func supportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("TodoIsland", isDirectory: true)
    }
}

/// Reads and writes one Codable value as a JSON file.
///
/// Writes are atomic. A file that cannot be decoded is never overwritten: it is renamed
/// to `<name>.corrupt-<timestamp>.json` first, so the user's data can still be recovered.
public struct JSONFileStore<Value: Codable>: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/TodoIsland/<fileName>` on macOS.
    public init(fileName: String, directory: URL = AppPaths.supportDirectory()) {
        self.url = directory.appendingPathComponent(fileName)
    }

    public enum LoadResult {
        /// No file yet (first launch).
        case missing
        case loaded(Value)
        /// The file was unreadable and has been moved to `backup`.
        case recovered(backup: URL)
    }

    /// Loads the value. Never throws: a broken file is moved aside and reported.
    public func load() -> LoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        do {
            let data = try Data(contentsOf: url)
            return .loaded(try Self.decoder.decode(Value.self, from: data))
        } catch {
            let backup = backupURL()
            do {
                try FileManager.default.moveItem(at: url, to: backup)
            } catch {
                // Could not move it; leave the original in place rather than lose it.
                return .recovered(backup: url)
            }
            return .recovered(backup: backup)
        }
    }

    /// Convenience: the stored value, or `fallback` when missing or unreadable.
    public func loadValue(or fallback: @autoclosure () -> Value) -> Value {
        if case .loaded(let value) = load() { return value }
        return fallback()
    }

    public func save(_ value: Value) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func backupURL() -> URL {
        let stamp = Int(Date().timeIntervalSince1970)
        let base = url.deletingPathExtension().lastPathComponent
        return url.deletingLastPathComponent()
            .appendingPathComponent("\(base).corrupt-\(stamp).json")
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
