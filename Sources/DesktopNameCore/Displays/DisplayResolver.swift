import Foundation

/// The one place a display is chosen from what the user typed (FR-023, spec 006 FR-011 and FR-019).
/// No command matches display names or aliases itself.
///
/// In order:
/// 1. nothing, or `main`: the main display;
/// 2. only digits: rejected, because macOS can reorder displays;
/// 3. an exact display name (case-insensitive). A connected display's name overrides an alias of the same
///    name, so every monitor stays reachable;
/// 4. an exact alias (case-insensitive; aliases are never matched partially), only when `aliases` is given;
/// 5. a partial display name that matches exactly one connected display.
///
/// `aliases: nil` is the display-only mode, used to choose the target of `dnm alias`.
public enum DisplayResolver {
    struct Resolution: Equatable, Sendable {
        var display: Display
        /// A warning for standard error when an alias of the same name was overridden.
        var notice: String?
    }

    static func resolve(_ value: String?, in displays: [Display], aliases: [DisplayAlias]? = nil) throws -> Display {
        try resolution(value, in: displays, aliases: aliases).display
    }

    static func resolution(_ value: String?, in displays: [Display], aliases: [DisplayAlias]? = nil) throws -> Resolution {
        guard !displays.isEmpty else { throw DnmError.failure("No displays are connected.") }

        guard let raw = value?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return Resolution(display: try mainDisplay(in: displays), notice: nil)
        }
        if isMain(raw) { return Resolution(display: try mainDisplay(in: displays), notice: nil) }
        if raw.allSatisfy(\.isNumber) {
            throw DnmError.invalidInput("Numbered displays are not supported because macOS can reorder them. Use a display's name; \(listing(displays)).")
        }

        let needle = raw.lowercased()
        let exact = exactMatches(raw, in: displays)
        if exact.count > 1 { throw ambiguous(raw, exact) }
        if let display = exact.first {
            let overridden = aliasNamed(raw, in: aliases).flatMap { $0.displayUUID != display.uuid ? $0 : nil }
            let notice = overridden.map {
                "\(display.name) is a connected display, which overrides alias \($0.name) (\(targetName(of: $0, in: displays)))."
            }
            return Resolution(display: display, notice: notice)
        }

        if let alias = aliasNamed(raw, in: aliases) {
            guard let display = displays.first(where: { $0.uuid == alias.displayUUID }) else {
                throw DnmError.invalidInput("The display aliased as \(alias.name) is not connected.")
            }
            return Resolution(display: display, notice: nil)
        }

        let partial = displays.filter { $0.name.lowercased().contains(needle) }
        switch partial.count {
        case 1: return Resolution(display: partial[0], notice: nil)
        case 0: throw DnmError.invalidInput("No display matches \"\(raw)\"; \(listing(displays)).")
        default: throw ambiguous(raw, partial)
        }
    }

    /// True when `value` is, exactly and ignoring case, `main`, a connected display's name, or the name of any stored
    /// alias (connected or not, overridden or not). Partial names and numbers are not references. It shares its
    /// matchers with `resolution`, so the two cannot drift (spec 008 FR-008).
    static func isReference(_ value: String, in displays: [Display], aliases: [DisplayAlias]) -> Bool {
        let raw = value.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return false }
        return isMain(raw) || !exactMatches(raw, in: displays).isEmpty || aliasNamed(raw, in: aliases) != nil
    }

    private static func isMain(_ raw: String) -> Bool { raw.caseInsensitiveCompare("main") == .orderedSame }

    private static func exactMatches(_ raw: String, in displays: [Display]) -> [Display] {
        let needle = raw.lowercased()
        return displays.filter { $0.name.lowercased() == needle }
    }

    private static func aliasNamed(_ raw: String, in aliases: [DisplayAlias]?) -> DisplayAlias? {
        aliases?.first { $0.matches(raw) }
    }

    /// The connected display whose name hides this alias, if any (a different display than the alias's own).
    public static func overrider(of alias: DisplayAlias, in displays: [Display]) -> Display? {
        exactMatches(alias.name, in: displays).first { $0.uuid != alias.displayUUID }
    }

    /// The aliases a person can use for `display` now, sorted: those that no other connected display's name overrides.
    public static func activeAliases(of display: Display, in aliases: [DisplayAlias], displays: [Display]) -> [String] {
        aliases.filter { $0.displayUUID == display.uuid && overrider(of: $0, in: displays) == nil }
            .map { TerminalText.sanitized($0.name) }
            .sorted { $0.lowercased() < $1.lowercased() }
    }

    /// What Tab offers for a display (spec 007): `main`, the connected displays' names, and, when `includeAliases`,
    /// the aliases that `resolve` would accept (not overridden, for a connected display). Each one resolves to a
    /// display; a name shared by two displays is still offered once. Aliases of absent displays are left out,
    /// because choosing one would only fail.
    public static func completionCandidates(in displays: [Display], aliases: [DisplayAlias], includeAliases: Bool) -> [String] {
        var candidates = ["main"] + displays.map(\.name)
        if includeAliases {
            candidates += aliases.filter { alias in displays.contains { $0.uuid == alias.displayUUID } && overrider(of: alias, in: displays) == nil }
                .map(\.name)
                .sorted { $0.lowercased() < $1.lowercased() }
        }
        var seen = Set<String>()
        return candidates.map(TerminalText.sanitized).filter { seen.insert($0.lowercased()).inserted }
    }

    /// How to show an alias's display: its connected name, else the name recorded with the alias, else its identity.
    public static func targetName(of alias: DisplayAlias, in displays: [Display]) -> String {
        // Stored text is untrusted on the way back out, like a display's name from macOS.
        TerminalText.sanitized(displays.first { $0.uuid == alias.displayUUID }?.name ?? alias.displayName ?? alias.displayUUID)
    }

    private static func mainDisplay(in displays: [Display]) throws -> Display {
        displays.first(where: \.isMain) ?? displays[0]
    }

    private static func ambiguous(_ raw: String, _ matches: [Display]) -> DnmError {
        .invalidInput("\"\(raw)\" matches more than one display: \(matches.map { "\"\($0.name)\"" }.joined(separator: ", ")). Use more of the name.")
    }

    private static func listing(_ displays: [Display]) -> String {
        "connected displays: " + displays.map { "\"\($0.name)\"" }.joined(separator: ", ") + " (or \"main\")"
    }
}
