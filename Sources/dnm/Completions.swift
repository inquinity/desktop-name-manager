import ArgumentParser
import DesktopNameCore
import Foundation

/// The candidates Tab offers, computed when the shell asks (spec 007). Read-only: no permission, no network, no
/// switching, and the store is never created. Anything that goes wrong offers nothing, so a completion never prints
/// an error into someone's command line.
enum Completions {
    /// Display names, `main` and (for `--display`) aliases, as `DisplayResolver.completionCandidates` decides.
    static func displays(includeAliases: Bool) -> [String] {
        let system = SystemWallpaperSystem()
        let labeler = DesktopLabeler(system: system, store: Store(directory: Store.defaultDirectory()))
        guard let displays = try? system.displays(), let aliases = try? labeler.aliases() else { return [] }
        return DisplayResolver.completionCandidates(in: displays, aliases: aliases, includeAliases: includeAliases)
    }

    /// Every stored alias, for `dnm alias --remove`: removing an absent or overridden alias is allowed.
    static func aliasNames() -> [String] {
        let labeler = DesktopLabeler(system: SystemWallpaperSystem(), store: Store(directory: Store.defaultDirectory()))
        return ((try? labeler.aliases()) ?? []).map { TerminalText.sanitized($0.name) }.sorted { $0.lowercased() < $1.lowercased() }
    }

    /// The fixed values of an option, from the same enums the parser validates against.
    static func values<Value: CaseIterable & RawRepresentable>(of _: Value.Type) -> CompletionKind where Value.RawValue == String {
        .list(Value.allCases.map(\.rawValue))
    }
}
