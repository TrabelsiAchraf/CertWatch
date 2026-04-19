import SwiftUI

// Assigns one of four colors to a team based on its index in the sorted team list.

enum TeamColor: Int, CaseIterable {
    case blue = 0, purple, green, orange

    var color: Color {
        switch self {
        case .blue:   return Theme.teamBlue
        case .purple: return Theme.teamPurple
        case .green:  return Theme.teamGreen
        case .orange: return Theme.teamOrange
        }
    }

    static func at(_ index: Int) -> TeamColor {
        let count = TeamColor.allCases.count
        return TeamColor(rawValue: ((index % count) + count) % count) ?? .blue
    }
}

enum TeamPalette {
    static func color(forIndex index: Int) -> Color {
        TeamColor.at(index).color
    }
}

/// Two-letter initials from a team display name, e.g. "Oodrive" -> "OO", "Salt Labs SAS" -> "SL".
func teamInitials(_ name: String) -> String {
    let words = name.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
    if words.count >= 2 {
        return (String(words[0].first ?? "?") + String(words[1].first ?? "?")).uppercased()
    }
    let first = name.first.map(String.init) ?? "?"
    let second = name.dropFirst().first.map(String.init) ?? first
    return (first + second).uppercased()
}
