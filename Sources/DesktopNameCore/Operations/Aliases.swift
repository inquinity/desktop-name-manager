import Foundation

public enum AliasChange: Equatable, Sendable {
    case created
    /// The alias already pointed at this display.
    case unchanged
    /// The alias pointed at another display, shown by `from`.
    case moved(from: String)
}

public struct SetAliasResult: Equatable, Sendable {
    /// The name as stored (the capitalization just typed).
    public var name: String
    public var displayName: String
    public var isMain: Bool
    public var change: AliasChange
}

/// One alias as `dnm alias` lists it (contracts/cli.md).
public struct AliasEntry: Codable, Equatable, Sendable {
    public var name: String
    /// The connected display's name, else the name recorded with the alias, else its identity.
    public var display: String
    public var connected: Bool
    public var isMain: Bool
    public var overridden: Bool
    public var overriddenBy: String?
}

extension DesktopLabeler {
    /// The stored aliases. Reads only; never creates the store.
    public func aliases() throws -> [DisplayAlias] {
        try store.readManifest().aliases
    }

    /// Points alias `rawName` at the display chosen by `displayValue` (resolved by `DisplayResolver` in its
    /// display-only mode). Setting an alias again moves it; nothing about a wallpaper changes.
    @discardableResult
    public func setAlias(_ rawName: String, display displayValue: String?) throws -> SetAliasResult {
        let name = try DisplayAlias.validated(rawName)
        let displays = try system.displays()
        if let clash = displays.first(where: { $0.name.lowercased() == name.lowercased() }) {
            throw DnmError.invalidInput("\(clash.name) is already the name of a connected display and cannot be used as an alias.")
        }
        let display = try DisplayResolver.resolve(displayValue, in: displays)
        guard !display.uuid.hasPrefix("no-uuid-") else {
            throw DnmError.invalidInput("\(display.name) has no stable identity that macOS keeps across reconnects, so it cannot have an alias.")
        }
        if let twin = displays.first(where: { $0.uuid == display.uuid && $0 != display }) {
            throw DnmError.invalidInput("\(display.name) and \(twin.name) report the same identity to macOS, so an alias could point at either. Nothing was changed.")
        }

        let change = try store.transaction { manifest -> AliasChange in
            let entry = DisplayAlias(name: name, displayUUID: display.uuid, displayName: display.name)
            guard let index = manifest.aliases.firstIndex(where: { $0.matches(name) }) else {
                manifest.aliases.append(entry)
                return .created
            }
            let old = manifest.aliases[index]
            manifest.aliases[index] = entry
            return old.displayUUID == display.uuid ? .unchanged : .moved(from: DisplayResolver.targetName(of: old, in: displays))
        }
        return SetAliasResult(name: name, displayName: display.name, isMain: display.isMain, change: change)
    }

    /// Deletes an alias and returns its stored name.
    @discardableResult
    public func removeAlias(named rawName: String) throws -> String {
        let missing = DnmError.invalidInput("No alias named \(rawName) exists.")
        guard store.hasManifest else { throw missing }
        return try store.transaction { manifest -> String in
            guard let index = manifest.aliases.firstIndex(where: { $0.matches(rawName) }) else { throw missing }
            return manifest.aliases.remove(at: index).name
        }
    }

    /// Every alias with its display and status, sorted by name.
    public func listAliases() throws -> [AliasEntry] {
        let stored = try aliases()
        let displays = try system.displays()
        return stored.sorted { $0.name.lowercased() < $1.name.lowercased() }.map { alias in
            let target = displays.first { $0.uuid == alias.displayUUID }
            let overrider = DisplayResolver.overrider(of: alias, in: displays)
            return AliasEntry(name: TerminalText.sanitized(alias.name), display: DisplayResolver.targetName(of: alias, in: displays), connected: target != nil,
                              isMain: target?.isMain ?? false, overridden: overrider != nil, overriddenBy: overrider?.name)
        }
    }
}
