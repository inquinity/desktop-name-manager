import Foundation

/// The decision: how to back the label and which text color to use.
struct Treatment: Equatable {
    var look: Look
    var lightText: Bool
    var textColor: TextColor
    /// Which of look and text color were chosen by the tool.
    var automatic: Set<LabelOption>
}

/// The decision rules, ported from the prototype: contrast first (can plain text be read here?),
/// then texture (will it fight the letterforms?), then fall back to a backing.
enum StylePicker {
    /// Mean relative luminance below which a dark glow behind light text is invisible.
    static let darkBackdrop = 0.05
    /// Mean relative luminance above which a light glow behind dark text is invisible.
    static let brightBackdrop = 0.6

    static func choose(_ stats: RegionStats, options: LabelOptions) -> Treatment {
        var automatic: Set<LabelOption> = []
        let lightText: Bool
        let textColor: TextColor
        switch options.textColor {
        case .light?: lightText = true; textColor = .light
        case .dark?: lightText = false; textColor = .dark
        case .custom(let red, let green, let blue)?:
            lightText = 0.2126 * red + 0.7152 * green + 0.0722 * blue > 0.5
            textColor = .custom(red: red, green: green, blue: blue)
        case nil:
            automatic.insert(.textColor)
            if abs(stats.badWhite - stats.badBlack) > 0.05 {
                lightText = stats.badWhite < stats.badBlack
            } else {
                // Both read about equally: compare average contrast, leaning to white, which suits photos.
                let whiteRatio = 1.05 / (stats.meanLuminance + 0.05), blackRatio = (stats.meanLuminance + 0.05) / 0.05
                lightText = whiteRatio * 1.3 >= blackRatio
            }
            textColor = lightText ? .light : .dark
        }

        if let look = options.look {
            return Treatment(look: look, lightText: lightText, textColor: textColor, automatic: automatic)
        }
        automatic.insert(.look)
        let weak = lightText ? stats.badWhite : stats.badBlack
        if weak < 0.05 && stats.busyness < 0.035 {
            return Treatment(look: .plain, lightText: lightText, textColor: textColor, automatic: automatic)
        }
        if weak < 0.20 && stats.busyness < 0.07 {
            // A halo is a glow in the opposite shade of the text. Where the backdrop already is that shade
            // (near black under light text, near white under dark text) the glow cannot show, so the label
            // would read as plain text called "halo". Say what it looks like.
            let glowCannotShow = lightText ? stats.meanLuminance < Self.darkBackdrop : stats.meanLuminance > Self.brightBackdrop
            if glowCannotShow && weak < 0.05 {
                return Treatment(look: .plain, lightText: lightText, textColor: textColor, automatic: automatic)
            }
            return Treatment(look: .halo, lightText: lightText, textColor: textColor, automatic: automatic)
        }
        return Treatment(look: .frosted, lightText: lightText, textColor: textColor, automatic: automatic)
    }
}
