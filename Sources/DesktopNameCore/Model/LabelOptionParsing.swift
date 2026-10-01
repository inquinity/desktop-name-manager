import Foundation

extension LabelOptions {
    /// Builds options from the user's text (command-line values). Anything omitted stays automatic or default.
    /// Invalid values throw `.invalidInput` naming the accepted values (FR-007).
    public static func parse(style: String?, color: String?, position: String?, size: String?) throws -> LabelOptions {
        var options = LabelOptions()
        if let style { options.look = try choice(Look.self, style, name: "style") }
        if let position { options.position = try choice(Position.self, position, name: "position") }
        if let size { options.size = try choice(Size.self, size, name: "size") }
        if let color { options.textColor = try parseColor(color) }
        return options
    }

    private static func choice<Value: RawRepresentable & CaseIterable>(_ type: Value.Type, _ text: String, name: String) throws -> Value
    where Value.RawValue == String {
        if let value = Value(rawValue: text.lowercased()) { return value }
        let allowed = Value.allCases.map(\.rawValue).joined(separator: ", ")
        throw DnmError.invalidInput("Unknown \(name) \"\(text)\". Use one of: \(allowed).")
    }

    static func parseColor(_ text: String) throws -> TextColor {
        switch text.lowercased() {
        case "light": return .light
        case "dark": return .dark
        default:
            let hex = text.hasPrefix("#") ? String(text.dropFirst()) : ""
            guard hex.count == 6, let value = UInt32(hex, radix: 16) else {
                throw DnmError.invalidInput("Unknown color \"\(text)\". Use light, dark, or #RRGGBB.")
            }
            return .custom(red: Double(value >> 16 & 0xff) / 255, green: Double(value >> 8 & 0xff) / 255, blue: Double(value & 0xff) / 255)
        }
    }
}
