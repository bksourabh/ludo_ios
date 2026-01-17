import Foundation

/// Protocol for receiving game events
protocol GameEngineDelegate: AnyObject {
    func gameDidStart()
    func turnDidChange(to player: Player)
    func diceDidRoll(value: Int)
    func tokenDidMove(token: Token, from: TokenState, to: TokenState)
    func tokenDidGetCaptured(token: Token, by: Token)
    func playerDidGetBonusRoll(player: Player, reason: BonusRollReason)
    func playerDidFinish(player: Player, place: Int)
    func gameDidEnd(winner: Player)
    func noValidMoves(for player: Player)
    func turnVoided(player: Player, reason: String)
}

/// Result of a move attempt
enum MoveResult {
    case success
    case capturedOpponent(Token)
    case reachedHome
    case invalidMove
    case noTokenSelected
}

/// Main game engine handling all game logic
class GameEngine {
    weak var delegate: GameEngineDelegate?

    private(set) var gameState: GameState
    private(set) var board: LudoBoard
    private(set) var dice: Dice

    var currentPlayer: Player {
        return gameState.currentPlayer
    }

    var currentDiceValue: Int? {
        return gameState.currentDiceValue
    }

    var phase: GamePhase {
        return gameState.phase
    }

    init(playerColors: [PlayerColor], boardSize: CGFloat) {
        self.gameState = GameState(playerColors: playerColors)
        self.board = LudoBoard(boardSize: boardSize)
        self.dice = Dice()
    }

    // MARK: - Game Flow

    /// Start the game
    func startGame() {
        gameState.phase = .rolling
        delegate?.gameDidStart()
        delegate?.turnDidChange(to: currentPlayer)
    }

    /// Roll the dice for the current player
    func rollDice() -> Int {
        guard gameState.phase == .rolling else { return 0 }

        let value = dice.roll()
        gameState.currentDiceValue = value
        gameState.addEvent(.diceRolled(player: currentPlayer.color, value: value))
        delegate?.diceDidRoll(value: value)

        // Check for three consecutive sixes
        if value == 6 {
            gameState.consecutiveSixes += 1
            if gameState.consecutiveSixes >= 3 {
                // Void the turn
                let reason = "Rolled three consecutive 6s"
                gameState.addEvent(.turnSkipped(player: currentPlayer.color, reason: reason))
                delegate?.turnVoided(player: currentPlayer, reason: reason)
                endTurn(grantBonusRoll: false)
                return value
            }
        } else {
            gameState.consecutiveSixes = 0
        }

        // Check if player has any valid moves
        if currentPlayer.hasValidMove(diceValue: value) {
            gameState.phase = .selectingToken
        } else {
            delegate?.noValidMoves(for: currentPlayer)
            endTurn(grantBonusRoll: false)
        }

        return value
    }

    /// Move a token
    func moveToken(_ token: Token) -> MoveResult {
        guard gameState.phase == .selectingToken else { return .invalidMove }
        guard let diceValue = gameState.currentDiceValue else { return .invalidMove }
        guard token.color == currentPlayer.color else { return .invalidMove }
        guard token.canMove(diceValue: diceValue) else { return .invalidMove }

        let previousState = token.state
        gameState.phase = .animatingMove

        // Move the token
        let capturePosition = token.move(by: diceValue)
        let newState = token.state

        gameState.addEvent(.tokenMoved(
            player: currentPlayer.color,
            tokenIndex: token.index,
            from: previousState,
            to: newState
        ))
        delegate?.tokenDidMove(token: token, from: previousState, to: newState)

        // Check for capture
        var capturedToken: Token?
        if let position = capturePosition {
            capturedToken = checkAndPerformCapture(at: position, by: token)
        }

        // Check if token reached home
        let reachedHome = (newState == .home && previousState != .home)

        // Check if player has won
        if currentPlayer.hasWon {
            gameState.recordFinish(player: currentPlayer)
            delegate?.playerDidFinish(player: currentPlayer, place: currentPlayer.finishOrder ?? 1)

            if gameState.isGameOver {
                gameState.phase = .gameOver
                delegate?.gameDidEnd(winner: currentPlayer)
                return reachedHome ? .reachedHome : (capturedToken != nil ? .capturedOpponent(capturedToken!) : .success)
            }
        }

        // Determine if bonus roll is granted
        var bonusRoll = false
        var bonusReason: BonusRollReason?

        if diceValue == 6 {
            bonusRoll = true
            bonusReason = .rolledSix
        } else if capturedToken != nil {
            bonusRoll = true
            bonusReason = .capturedToken
        } else if reachedHome {
            bonusRoll = true
            bonusReason = .reachedHome
        }

        if let reason = bonusReason {
            gameState.addEvent(.bonusRoll(player: currentPlayer.color, reason: reason))
            delegate?.playerDidGetBonusRoll(player: currentPlayer, reason: reason)
        }

        endTurn(grantBonusRoll: bonusRoll)

        if let captured = capturedToken {
            return .capturedOpponent(captured)
        } else if reachedHome {
            return .reachedHome
        }
        return .success
    }

    /// End the current turn
    private func endTurn(grantBonusRoll: Bool) {
        if grantBonusRoll && !currentPlayer.hasWon && !gameState.isGameOver {
            // Same player gets another turn
            gameState.phase = .rolling
            gameState.currentDiceValue = nil
        } else {
            // Move to next player
            gameState.nextTurn()
            delegate?.turnDidChange(to: currentPlayer)
        }
    }

    // MARK: - Capture Logic

    /// Check for and perform capture at a position
    private func checkAndPerformCapture(at position: Int, by attackingToken: Token) -> Token? {
        // Can't capture on safe squares
        if board.isSafeSquare(position) {
            return nil
        }

        // Check all other players for tokens at this position
        for player in gameState.players {
            // Can't capture own tokens
            if player.color == attackingToken.color {
                continue
            }

            let tokensAtPosition = player.tokens(atTrackPosition: position)

            // If multiple tokens of same color are stacked, they're safe
            if tokensAtPosition.count >= 2 {
                continue
            }

            // Capture single token
            if let targetToken = tokensAtPosition.first {
                targetToken.resetToYard()
                gameState.addEvent(.tokenCaptured(
                    capturer: attackingToken.color,
                    captured: targetToken.color,
                    position: position
                ))
                delegate?.tokenDidGetCaptured(token: targetToken, by: attackingToken)
                return targetToken
            }
        }

        return nil
    }

    // MARK: - Query Methods

    /// Get movable tokens for current player
    func movableTokens() -> [Token] {
        guard let diceValue = gameState.currentDiceValue else { return [] }
        return currentPlayer.movableTokens(diceValue: diceValue)
    }

    /// Check if a token can be moved
    func canMoveToken(_ token: Token) -> Bool {
        guard let diceValue = gameState.currentDiceValue else { return false }
        guard token.color == currentPlayer.color else { return false }
        return token.canMove(diceValue: diceValue)
    }

    /// Get all tokens at a track position (for stacking display)
    func tokensAtPosition(_ position: Int) -> [Token] {
        var tokens: [Token] = []
        for player in gameState.players {
            tokens.append(contentsOf: player.tokens(atTrackPosition: position))
        }
        return tokens
    }

    /// Get the screen position for a token
    func screenPosition(for token: Token) -> CGPoint {
        switch token.state {
        case .inYard:
            let yardPositions = board.yardPositions(for: token.color)
            return yardPositions[token.index]

        case .onTrack(let position):
            return board.screenPosition(forTrackPosition: position)

        case .onHomePath(let position):
            return board.screenPosition(forHomePath: position, color: token.color)

        case .home:
            return board.homeTrianglePosition(for: token.color)
        }
    }

    // MARK: - AI Support

    /// Get the best move for AI (simple strategy)
    func suggestBestMove() -> Token? {
        let movable = movableTokens()
        guard !movable.isEmpty, let diceValue = gameState.currentDiceValue else { return nil }

        // Priority 1: Capture an opponent
        for token in movable {
            if let capturePos = simulateMovePosition(token: token, diceValue: diceValue) {
                if canCaptureAt(position: capturePos, byColor: token.color) {
                    return token
                }
            }
        }

        // Priority 2: Move token close to home
        let sortedByProgress = movable.sorted { t1, t2 in
            progressScore(for: t1) > progressScore(for: t2)
        }

        // Priority 3: Get token out of yard with a 6
        if diceValue == 6 {
            if let inYard = movable.first(where: { $0.state == .inYard }) {
                return inYard
            }
        }

        // Priority 4: Move to safe square if possible
        for token in sortedByProgress {
            if let newPos = simulateMovePosition(token: token, diceValue: diceValue) {
                if board.isSafeSquare(newPos) {
                    return token
                }
            }
        }

        // Default: Move the most advanced token
        return sortedByProgress.first
    }

    private func simulateMovePosition(token: Token, diceValue: Int) -> Int? {
        switch token.state {
        case .inYard:
            return diceValue == 6 ? token.color.startPosition : nil
        case .onTrack(let position):
            return (position + diceValue) % 52
        default:
            return nil
        }
    }

    private func canCaptureAt(position: Int, byColor: PlayerColor) -> Bool {
        if board.isSafeSquare(position) { return false }

        for player in gameState.players {
            if player.color == byColor { continue }
            let tokensAtPos = player.tokens(atTrackPosition: position)
            if tokensAtPos.count == 1 {
                return true
            }
        }
        return false
    }

    private func progressScore(for token: Token) -> Int {
        switch token.state {
        case .inYard: return 0
        case .onTrack(let position):
            // Calculate how far along the track
            let start = token.color.startPosition
            if position >= start {
                return position - start
            } else {
                return (52 - start) + position
            }
        case .onHomePath(let position): return 52 + position
        case .home: return 100
        }
    }
}
