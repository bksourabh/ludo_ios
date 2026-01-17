import Foundation

/// Represents a player in the game
class Player: Identifiable, Equatable {
    let id: UUID
    let color: PlayerColor
    let isHuman: Bool
    var tokens: [Token]
    var finishOrder: Int? // 1st, 2nd, 3rd, or 4th place

    init(color: PlayerColor, isHuman: Bool = true) {
        self.id = UUID()
        self.color = color
        self.isHuman = isHuman
        self.tokens = (0..<4).map { Token(color: color, index: $0) }
        self.finishOrder = nil
    }

    /// Number of tokens that have reached home
    var tokensHome: Int {
        return tokens.filter { $0.state == .home }.count
    }

    /// Number of tokens still in the yard
    var tokensInYard: Int {
        return tokens.filter { $0.state == .inYard }.count
    }

    /// Number of tokens currently on the board (track or home path)
    var tokensInPlay: Int {
        return tokens.filter { $0.state.isInPlay }.count
    }

    /// Check if player has won (all tokens home)
    var hasWon: Bool {
        return tokensHome == 4
    }

    /// Get all tokens that can move with the given dice value
    func movableTokens(diceValue: Int) -> [Token] {
        return tokens.filter { $0.canMove(diceValue: diceValue) }
    }

    /// Check if player has any valid moves
    func hasValidMove(diceValue: Int) -> Bool {
        return !movableTokens(diceValue: diceValue).isEmpty
    }

    /// Get token at a specific track position
    func token(atTrackPosition position: Int) -> Token? {
        return tokens.first { token in
            if case .onTrack(let pos) = token.state {
                return pos == position
            }
            return false
        }
    }

    /// Get all tokens at a specific track position
    func tokens(atTrackPosition position: Int) -> [Token] {
        return tokens.filter { token in
            if case .onTrack(let pos) = token.state {
                return pos == position
            }
            return false
        }
    }

    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.id == rhs.id
    }
}
