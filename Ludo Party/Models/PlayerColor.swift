import Foundation
import SpriteKit

/// Represents the four player colors in Ludo
enum PlayerColor: Int, CaseIterable, Codable {
    case red = 0
    case green = 1
    case yellow = 2
    case blue = 3

    /// The display name of the color
    var name: String {
        switch self {
        case .red: return "Red"
        case .green: return "Green"
        case .yellow: return "Yellow"
        case .blue: return "Blue"
        }
    }

    /// The SKColor for rendering
    var color: SKColor {
        switch self {
        case .red: return SKColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1.0)
        case .green: return SKColor(red: 0.15, green: 0.65, blue: 0.15, alpha: 1.0)
        case .yellow: return SKColor(red: 0.95, green: 0.85, blue: 0.15, alpha: 1.0)
        case .blue: return SKColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 1.0)
        }
    }

    /// Lighter version of the color for home areas
    var lightColor: SKColor {
        switch self {
        case .red: return SKColor(red: 1.0, green: 0.7, blue: 0.7, alpha: 1.0)
        case .green: return SKColor(red: 0.7, green: 1.0, blue: 0.7, alpha: 1.0)
        case .yellow: return SKColor(red: 1.0, green: 1.0, blue: 0.7, alpha: 1.0)
        case .blue: return SKColor(red: 0.7, green: 0.7, blue: 1.0, alpha: 1.0)
        }
    }

    /// The starting position index on the main track (0-51)
    var startPosition: Int {
        switch self {
        case .red: return 0
        case .green: return 13
        case .yellow: return 26
        case .blue: return 39
        }
    }

    /// The position before entering home path (two positions before start position)
    /// Token enters home path from this position, never stepping on the position just before start
    var homeEntryPosition: Int {
        switch self {
        case .red: return 50     // Red enters home path from position 50 (2 before start at 0)
        case .green: return 11   // Green enters home path from position 11 (2 before start at 13)
        case .yellow: return 24  // Yellow enters home path from position 24 (2 before start at 26)
        case .blue: return 37    // Blue enters home path from position 37 (2 before start at 39)
        }
    }

    /// Safe square positions for this color (star positions)
    static let safeSquares: Set<Int> = [0, 8, 13, 21, 26, 34, 39, 47]

    /// The next player in turn order
    var next: PlayerColor {
        let allCases = PlayerColor.allCases
        let nextIndex = (self.rawValue + 1) % allCases.count
        return allCases[nextIndex]
    }
}
