import Foundation

/// Represents whether a player is human or AI controlled
enum PlayerType: Int, Codable {
    case human = 0
    case computer = 1

    var displayName: String {
        switch self {
        case .human: return "Human"
        case .computer: return "Computer"
        }
    }
}

/// Configuration for a game session
struct GameConfig {
    var redPlayer: PlayerType = .human
    var greenPlayer: PlayerType = .computer
    var yellowPlayer: PlayerType = .computer
    var bluePlayer: PlayerType = .computer

    /// Get player type for a color
    func playerType(for color: PlayerColor) -> PlayerType {
        switch color {
        case .red: return redPlayer
        case .green: return greenPlayer
        case .yellow: return yellowPlayer
        case .blue: return bluePlayer
        }
    }

    /// Check if a color is human controlled
    func isHuman(_ color: PlayerColor) -> Bool {
        return playerType(for: color) == .human
    }

    /// Get all player colors that are human
    var humanPlayers: [PlayerColor] {
        return PlayerColor.allCases.filter { isHuman($0) }
    }

    /// Get all player colors that are AI
    var aiPlayers: [PlayerColor] {
        return PlayerColor.allCases.filter { !isHuman($0) }
    }

    /// Default configuration (1 human, 3 AI)
    static let defaultConfig = GameConfig()

    /// All human players
    static let allHuman = GameConfig(
        redPlayer: .human,
        greenPlayer: .human,
        yellowPlayer: .human,
        bluePlayer: .human
    )

    /// All AI players (demo mode)
    static let allAI = GameConfig(
        redPlayer: .computer,
        greenPlayer: .computer,
        yellowPlayer: .computer,
        bluePlayer: .computer
    )
}
