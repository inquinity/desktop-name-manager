import Foundation

/// Resolves the `--display` value (FR-023).
///
/// Accepted: nothing (the main display), `main`, a display's name as macOS shows it
/// (case-insensitive), or a partial name that matches exactly one connected display.
/// Numbers and position keywords are not interpreted. They only match if they appear in a name.
public enum DisplayResolver {
    public static func resolve(_ value: String?, in displays: [Display]) throws -> Display {
        guard !displays.isEmpty else { throw DnmError.failure("No displays are connected.") }

        guard let raw = value?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else {
            return try mainDisplay(in: displays)
        }
        if raw.caseInsensitiveCompare("main") == .orderedSame { return try mainDisplay(in: displays) }
        if raw.allSatisfy(\.isNumber) {
            throw DnmError.invalidInput("Numbered displays are not supported because macOS can reorder them. Use a display's name; \(listing(displays)).")
        }

        let needle = raw.lowercased()
        let exact = displays.filter { $0.name.lowercased() == needle }
        if exact.count == 1 { return exact[0] }
        if exact.count > 1 { throw ambiguous(raw, exact) }

        let partial = displays.filter { $0.name.lowercased().contains(needle) }
        switch partial.count {
        case 1: return partial[0]
        case 0: throw DnmError.invalidInput("No display matches \"\(raw)\"; \(listing(displays)).")
        default: throw ambiguous(raw, partial)
        }
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
