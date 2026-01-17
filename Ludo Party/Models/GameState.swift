import Foundation

/// Represents the overall state of the game
enum GamePhase {
    case waitingToStart
    case rolling              // Waiting for dice roll
    case selectingToken       // Player needs to select which token to move
    case animatingMove        // Token movement animation in progress
    case gameOver
}

/// Represents a game event for logging/history
enum GameEvent {
    case diceRolled(player: PlayerColor, value: Int)
    case tokenMoved(player: PlayerColor, tokenIndex: Int, from: TokenState, to: TokenState)
    case tokenCaptured(capturer: PlayerColor, captured: PlayerColor, position: Int)
    case playerFinished(player: PlayerColor, place: Int)
    case bonusRoll(player: PlayerColor, reason: BonusRollReason)
    case turnSkipped(player: PlayerColor, reason: String)
}

enum BonusRollReason {
    case rolledSix
    case capturedToken
    case reachedHome
}

/// Main game state container
class GameState {
    var players: [Player]
    var currentPlayerIndex: Int
    var phase: GamePhase
    var currentDiceValue: Int?
    var consecutiveSixes: Int
    var events: [GameEvent]
    var finishOrder: [PlayerColor]

    init(playerColors: [PlayerColor]) {
        self.players = playerColors.map { Player(color: $0) }
        self.currentPlayerIndex = 0
        self.phase = .waitingToStart
        self.currentDiceValue = nil
        self.consecutiveSixes = 0
        self.events = []
        self.finishOrder = []
    }

    /// The current player
    var currentPlayer: Player {
        return players[currentPlayerIndex]
    }

    /// Move to the next player
    func nextTurn() {
        consecutiveSixes = 0
        currentDiceValue = nil

        // Find next player who hasn't finished
        var nextIndex = (currentPlayerIndex + 1) % players.count
        var attempts = 0
        while players[nextIndex].hasWon && attempts < players.count {
            nextIndex = (nextIndex + 1) % players.count
            attempts += 1
        }

        currentPlayerIndex = nextIndex
        phase = .rolling
    }

    /// Check if game is over (only one player left or all but one finished)
    var isGameOver: Bool {
        let playersNotFinished = players.filter { !$0.hasWon }
        return playersNotFinished.count <= 1
    }

    /// Get player by color
    func player(for color: PlayerColor) -> Player? {
        return players.first { $0.color == color }
    }

    /// Record a player finishing
    func recordFinish(player: Player) {
        if player.hasWon && player.finishOrder == nil {
            let place = finishOrder.count + 1
            player.finishOrder = place
            finishOrder.append(player.color)
            events.append(.playerFinished(player: player.color, place: place))
        }
    }

    /// Add an event to history
    func addEvent(_ event: GameEvent) {
        events.append(event)
    }
}
