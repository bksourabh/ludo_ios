import Foundation

/// Represents the state of a token on the board
enum TokenState: Equatable {
    case inYard                    // Token is in the starting yard
    case onTrack(position: Int)    // Token is on the main track (0-51)
    case onHomePath(position: Int) // Token is on the home path (0-5, where 5 is home)
    case home                      // Token has reached home

    var isInPlay: Bool {
        switch self {
        case .onTrack, .onHomePath:
            return true
        case .inYard, .home:
            return false
        }
    }

    var isFinished: Bool {
        return self == .home
    }
}

/// Represents a single token/piece in the game
class Token: Identifiable, Equatable {
    let id: UUID
    let color: PlayerColor
    let index: Int // 0-3 for each player
    var state: TokenState

    init(color: PlayerColor, index: Int) {
        self.id = UUID()
        self.color = color
        self.index = index
        self.state = .inYard
    }

    /// Unique identifier for this token
    var identifier: String {
        return "\(color.name)-\(index)"
    }

    /// Check if this token can move with the given dice value
    func canMove(diceValue: Int) -> Bool {
        switch state {
        case .inYard:
            // Can only leave yard with a 6
            return diceValue == 6

        case .onTrack(let position):
            // Calculate distance to home entry
            let stepsToHomeEntry = distanceToHomeEntry(from: position)
            if diceValue <= stepsToHomeEntry {
                return true
            }
            // Check if can enter home path
            let remainingSteps = diceValue - stepsToHomeEntry - 1
            return remainingSteps <= 5 // Home path has 6 positions (0-5)

        case .onHomePath(let position):
            // Need exact roll to reach home (position 5)
            let stepsNeeded = 5 - position
            return diceValue <= stepsNeeded

        case .home:
            return false
        }
    }

    /// Calculate distance to home entry point on the track
    private func distanceToHomeEntry(from position: Int) -> Int {
        let homeEntry = color.homeEntryPosition
        if position <= homeEntry {
            return homeEntry - position
        } else {
            return (52 - position) + homeEntry
        }
    }

    /// Move the token by the given dice value
    /// Returns the capture position if a capture might occur, nil otherwise
    func move(by diceValue: Int) -> Int? {
        switch state {
        case .inYard:
            if diceValue == 6 {
                state = .onTrack(position: color.startPosition)
                return color.startPosition
            }
            return nil

        case .onTrack(let position):
            let stepsToHomeEntry = distanceToHomeEntry(from: position)

            if diceValue <= stepsToHomeEntry {
                let newPosition = (position + diceValue) % 52
                state = .onTrack(position: newPosition)
                return newPosition
            } else {
                // Enter home path
                let homePathPosition = diceValue - stepsToHomeEntry - 1
                if homePathPosition >= 5 {
                    state = .home
                } else {
                    state = .onHomePath(position: homePathPosition)
                }
                return nil // No capture possible on home path
            }

        case .onHomePath(let position):
            let newPosition = position + diceValue
            if newPosition >= 5 {
                state = .home
            } else {
                state = .onHomePath(position: newPosition)
            }
            return nil

        case .home:
            return nil
        }
    }

    /// Reset token to yard (when captured)
    func resetToYard() {
        state = .inYard
    }

    static func == (lhs: Token, rhs: Token) -> Bool {
        return lhs.id == rhs.id
    }
}
