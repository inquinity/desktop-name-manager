import ArgumentParser
import DesktopNameCore

struct AliasCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "alias",
        abstract: "Give a display a short name for --display, list the aliases, or remove one.",
        discussion: """
        dnm alias <name> [<display>]   point <name> at a display (default: main)
        dnm alias --remove <name>      delete an alias
        dnm alias [--json]             list the aliases

        An alias is 1 to 30 letters, digits, hyphens or underscores. A connected display's own name wins over \
        an alias of the same name. Aliases are matched in full, ignoring case.
        """)

    // A new alias name is typed freehand, so only --remove offers names (the stored aliases).
    @Argument(help: ArgumentHelp("The alias to set, or with --remove the one to delete.", valueName: "name"),
              completion: .custom { arguments, _, _ in Self.isRemoving(arguments) ? Completions.aliasNames() : [] })
    var name: String?

    // The target is a display, never an alias, as in the resolver's display-only mode.
    @Argument(help: ArgumentHelp("The display to point the alias at: main, a display's name, or part of a name that matches one display. Default: main.", valueName: "display"),
              completion: .custom { arguments, _, _ in Self.isRemoving(arguments) ? [] : Completions.displays(includeAliases: false) })
    var display: String?

    @Flag(name: .customLong("remove"), help: "Delete the alias <name>.")
    var remove = false

    @Flag(name: .long, help: "Print the list as one JSON document instead of text.")
    var json = false

    func run() throws {
        try Self.guarded {
            let context = Context()
            try context.labeler.cleanUp()
            if remove {
                guard let name, display == nil, !json else {
                    throw DnmError.invalidInput("--remove takes one alias name and nothing else.")
                }
                Output.out("Removed alias \(try context.labeler.removeAlias(named: name)).")
            } else if let name {
                guard !json else { throw DnmError.invalidInput("--json is only for listing the aliases.") }
                Output.out(Self.confirmation(try context.labeler.setAlias(name, display: display)))
            } else {
                try list(context)
            }
        }
    }

    private static func isRemoving(_ arguments: [String]) -> Bool {
        arguments.contains("--remove")
    }

    static func confirmation(_ result: SetAliasResult) -> String {
        let target = result.displayName + (result.isMain ? " (main)" : "")
        if case .moved(let from) = result.change { return "Moved alias \(result.name) from \(from) to \(target)." }
        return "Aliased \(result.name) to \(target)."
    }

    private func list(_ context: Context) throws {
        let entries = try context.labeler.listAliases()
        if json {
            Output.out(try Reports.json(Reports.aliases(entries)))
        } else if entries.isEmpty {
            Output.out("No aliases. Set one with: dnm alias <name> [<display>]")
        } else {
            let nameWidth = entries.map(\.name.count).max() ?? 0
            let displayWidth = entries.map(\.display.count).max() ?? 0
            for entry in entries {
                let status = entry.overriddenBy.map { "(overridden by connected display \($0))" }
                    ?? (entry.isMain ? "(main)" : (entry.connected ? "" : "(not connected)"))
                let line = entry.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0) + "  "
                    + (status.isEmpty ? entry.display : entry.display.padding(toLength: displayWidth, withPad: " ", startingAt: 0) + "  " + status)
                Output.out(line)
            }
        }
        for entry in entries {
            if let by = entry.overriddenBy {
                Output.err("dnm: warning: alias \(entry.name) is not used while a display named \(by) is connected.")
            }
        }
    }
}
