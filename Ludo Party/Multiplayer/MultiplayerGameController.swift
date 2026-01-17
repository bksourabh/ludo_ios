import Foundation
import GameKit

// MARK: - Multiplayer Game Controller Delegate

protocol MultiplayerGameControllerDelegate: AnyObject {
    func multiplayerController(_ controller: MultiplayerGameController, didRollDice value: Int, for color: PlayerColor)
    func multiplayerController(_ controller: MultiplayerGameController, didMoveToken token: Token, from: TokenState, to: TokenState, result: MoveResult)
    func multiplayerController(_ controller: MultiplayerGameController, didChangeTurn to: PlayerColor)
    func multiplayerController(_ controller: MultiplayerGameController, playerDidDisconnect color: PlayerColor)
    func multiplayerController(_ controller: MultiplayerGameController, playerReplacedWithAI color: PlayerColor)
    func multiplayerController(_ controller: MultiplayerGameController, didReceiveStateSync state: FullStateSyncPayload)
    func multiplayerControllerGameDidEnd(_ controller: MultiplayerGameController)
    func multiplayerController(_ controller: MultiplayerGameController, didEncounterError error: Error)
}

// MARK: - Multiplayer Game Controller

/// Bridges network events with local GameEngine for online multiplayer
class MultiplayerGameController: MatchManagerDelegate {

    // MARK: - Properties

    weak var delegate: MultiplayerGameControllerDelegate?

    private let gameEngine: GameEngine
    private let matchManager: MatchManager
    private let roomState: OnlineRoomState

    private var sequenceNumber: UInt32 = 0
    private var turnNumber: Int = 0
    private var pendingMessages: [NetworkMessage] = []

    /// Map of player IDs to colors
    private var playerColorMap: [String: PlayerColor] = [:]

    /// Map of colors to player IDs
    private var colorPlayerMap: [PlayerColor: String] = [:]

    /// Disconnection tracking
    private var disconnectedPlayers: Set<PlayerColor> = []
    private var disconnectionTimers: [PlayerColor: Timer] = [:]
    private let reconnectionTimeout: TimeInterval = 30.0

    /// Check if it's the local player's turn
    var isLocalPlayerTurn: Bool {
        return roomState.isLocalPlayerColor(gameEngine.currentPlayer.color)
    }

    /// Get the current player color
    var currentPlayerColor: PlayerColor {
        return gameEngine.currentPlayer.color
    }

    /// Check if the local player is the host
    var isHost: Bool {
        return roomState.isHost
    }

    // MARK: - Initialization

    init(gameEngine: GameEngine, matchManager: MatchManager, roomState: OnlineRoomState) {
        self.gameEngine = gameEngine
        self.matchManager = matchManager
        self.roomState = roomState

        // Build player ID to color maps
        for player in roomState.players {
            if let color = player.assignedColor {
                playerColorMap[player.id] = color
                colorPlayerMap[color] = player.id
            }
        }

        matchManager.delegate = self
    }

    // MARK: - Local Player Actions

    /// Roll dice for the local player
    func localPlayerRollDice() -> Int {
        guard isLocalPlayerTurn else { return 0 }
        guard gameEngine.phase == .rolling else { return 0 }

        let value = gameEngine.rollDice()
        turnNumber += 1

        // Broadcast dice roll to all players
        broadcastDiceRoll(value: value)

        return value
    }

    /// Move a token for the local player
    func localPlayerMoveToken(_ token: Token) -> MoveResult {
        guard isLocalPlayerTurn else { return .invalidMove }
        guard gameEngine.phase == .selectingToken else { return .invalidMove }

        let fromState = token.state
        let result = gameEngine.moveToken(token)
        let toState = token.state

        // Broadcast token move to all players
        broadcastTokenMove(token: token, from: fromState, to: toState, result: result)

        return result
    }

    // MARK: - Network Broadcasting

    private func broadcastDiceRoll(value: Int) {
        sequenceNumber += 1

        let payload = DiceRollPayload(
            playerColor: currentPlayerColor.rawValue,
            diceValue: value,
            turnNumber: turnNumber
        )

        do {
            try matchManager.sendMessage(type: .diceRoll, payload: payload)
        } catch {
            delegate?.multiplayerController(self, didEncounterError: error)
        }
    }

    private func broadcastTokenMove(token: Token, from: TokenState, to: TokenState, result: MoveResult) {
        sequenceNumber += 1

        var capturedColor: Int? = nil
        var capturedIndex: Int? = nil

        if case .capturedOpponent(let capturedToken) = result {
            capturedColor = capturedToken.color.rawValue
            capturedIndex = capturedToken.index
        }

        let payload = TokenMovePayload(
            playerColor: token.color.rawValue,
            tokenIndex: token.index,
            fromState: EncodedTokenState(from: from),
            toState: EncodedTokenState(from: to),
            capturedTokenColor: capturedColor,
            capturedTokenIndex: capturedIndex,
            turnNumber: turnNumber
        )

        do {
            try matchManager.sendMessage(type: .tokenMove, payload: payload)
        } catch {
            delegate?.multiplayerController(self, didEncounterError: error)
        }
    }

    /// Broadcast full state sync (host only)
    func broadcastFullStateSync() {
        guard isHost else { return }

        sequenceNumber += 1

        let payload = createFullStateSyncPayload()

        do {
            try matchManager.sendMessage(type: .fullStateSync, payload: payload)
        } catch {
            delegate?.multiplayerController(self, didEncounterError: error)
        }
    }

    private func createFullStateSyncPayload() -> FullStateSyncPayload {
        var encodedPlayers: [EncodedPlayer] = []

        for player in gameEngine.gameState.players {
            let encodedTokens = player.tokens.map { token in
                EncodedToken(
                    color: token.color.rawValue,
                    index: token.index,
                    state: EncodedTokenState(from: token.state)
                )
            }

            let onlinePlayer = roomState.player(for: player.color)

            encodedPlayers.append(EncodedPlayer(
                color: player.color.rawValue,
                tokens: encodedTokens,
                finishOrder: player.finishOrder,
                isAI: onlinePlayer?.isAI ?? false,
                onlinePlayerID: colorPlayerMap[player.color]
            ))
        }

        return FullStateSyncPayload(
            players: encodedPlayers,
            currentPlayerColor: gameEngine.currentPlayer.color.rawValue,
            phase: gameEngine.phase.rawValue,
            currentDiceValue: gameEngine.currentDiceValue,
            consecutiveSixes: gameEngine.gameState.consecutiveSixes,
            finishOrder: gameEngine.gameState.finishOrder.map { $0.rawValue },
            sequenceNumber: sequenceNumber
        )
    }

    // MARK: - Remote Action Handling

    /// Handle received network message
    func handleReceivedMessage(_ message: NetworkMessage, from player: GKPlayer) {
        switch message.type {
        case .diceRoll:
            handleDiceRollMessage(message)
        case .tokenMove:
            handleTokenMoveMessage(message)
        case .fullStateSync:
            handleFullStateSyncMessage(message)
        case .requestSync:
            if isHost {
                broadcastFullStateSync()
            }
        case .playerDisconnected:
            handlePlayerDisconnectedMessage(message)
        case .playerReplacedWithAI:
            handlePlayerReplacedWithAIMessage(message)
        case .playerReconnected:
            handlePlayerReconnectedMessage(message)
        default:
            break
        }
    }

    private func handleDiceRollMessage(_ message: NetworkMessage) {
        guard let payload = try? message.decodePayload(DiceRollPayload.self) else { return }
        guard let color = PlayerColor(rawValue: payload.playerColor) else { return }

        // Don't process our own messages
        guard !roomState.isLocalPlayerColor(color) else { return }

        // Apply dice roll to local engine
        applyRemoteDiceRoll(value: payload.diceValue, forColor: color)

        delegate?.multiplayerController(self, didRollDice: payload.diceValue, for: color)
    }

    private func handleTokenMoveMessage(_ message: NetworkMessage) {
        guard let payload = try? message.decodePayload(TokenMovePayload.self) else { return }
        guard let color = PlayerColor(rawValue: payload.playerColor) else { return }

        // Don't process our own messages
        guard !roomState.isLocalPlayerColor(color) else { return }

        // Apply token move to local engine
        applyRemoteTokenMove(payload: payload)
    }

    private func handleFullStateSyncMessage(_ message: NetworkMessage) {
        guard let payload = try? message.decodePayload(FullStateSyncPayload.self) else { return }

        // Apply full state sync
        applyFullStateSync(payload)

        delegate?.multiplayerController(self, didReceiveStateSync: payload)
    }

    private func handlePlayerDisconnectedMessage(_ message: NetworkMessage) {
        guard let payload = try? message.decodePayload(PlayerDisconnectedPayload.self) else { return }
        guard let color = PlayerColor(rawValue: payload.playerColor) else { return }

        disconnectedPlayers.insert(color)
        roomState.markPlayerDisconnected(payload.playerID)
        delegate?.multiplayerController(self, playerDidDisconnect: color)
    }

    private func handlePlayerReplacedWithAIMessage(_ message: NetworkMessage) {
        guard let payload = try? message.decodePayload(PlayerReplacedWithAIPayload.self) else { return }
        guard let color = PlayerColor(rawValue: payload.playerColor) else { return }

        roomState.replaceWithAI(payload.playerID)
        disconnectedPlayers.remove(color)
        delegate?.multiplayerController(self, playerReplacedWithAI: color)
    }

    private func handlePlayerReconnectedMessage(_ message: NetworkMessage) {
        guard let payload = try? message.decodePayload(PlayerReconnectedPayload.self) else { return }
        guard let color = PlayerColor(rawValue: payload.playerColor) else { return }

        disconnectedPlayers.remove(color)
        roomState.markPlayerReconnected(payload.playerID)
        cancelReconnectionTimer(for: color)

        // Send state sync to reconnected player
        if isHost {
            broadcastFullStateSync()
        }
    }

    // MARK: - Apply Remote Actions

    private func applyRemoteDiceRoll(value: Int, forColor color: PlayerColor) {
        // Set the dice value directly on game state
        gameEngine.gameState.currentDiceValue = value

        // Check for valid moves
        if gameEngine.currentPlayer.hasValidMove(diceValue: value) {
            gameEngine.gameState.phase = .selectingToken
        } else {
            gameEngine.gameState.phase = .rolling
            gameEngine.gameState.nextTurn()
        }
    }

    private func applyRemoteTokenMove(payload: TokenMovePayload) {
        guard let color = PlayerColor(rawValue: payload.playerColor) else { return }
        guard let player = gameEngine.gameState.player(for: color) else { return }
        guard payload.tokenIndex >= 0 && payload.tokenIndex < player.tokens.count else { return }

        let token = player.tokens[payload.tokenIndex]
        let fromState = token.state
        let toState = payload.toState.toTokenState()

        // Update token state directly
        token.state = toState

        // Handle capture if any
        if let capturedColorRaw = payload.capturedTokenColor,
           let capturedIndex = payload.capturedTokenIndex,
           let capturedColor = PlayerColor(rawValue: capturedColorRaw),
           let capturedPlayer = gameEngine.gameState.player(for: capturedColor) {
            if capturedIndex >= 0 && capturedIndex < capturedPlayer.tokens.count {
                capturedPlayer.tokens[capturedIndex].resetToYard()
            }
        }

        // Determine result
        var result: MoveResult = .success
        if toState == .home && fromState != .home {
            result = .reachedHome
        } else if let capturedColorRaw = payload.capturedTokenColor,
                  let capturedIndex = payload.capturedTokenIndex,
                  let capturedColor = PlayerColor(rawValue: capturedColorRaw),
                  let capturedPlayer = gameEngine.gameState.player(for: capturedColor) {
            if capturedIndex >= 0 && capturedIndex < capturedPlayer.tokens.count {
                result = .capturedOpponent(capturedPlayer.tokens[capturedIndex])
            }
        }

        delegate?.multiplayerController(self, didMoveToken: token, from: fromState, to: toState, result: result)

        // Update game state
        updateGameStateAfterMove(player: player, result: result)
    }

    private func updateGameStateAfterMove(player: Player, result: MoveResult) {
        // Check for bonus roll
        var bonusRoll = false

        if let diceValue = gameEngine.currentDiceValue, diceValue == 6 {
            bonusRoll = true
        } else if case .capturedOpponent = result {
            bonusRoll = true
        } else if case .reachedHome = result {
            bonusRoll = true
        }

        // Check if player won
        if player.hasWon {
            gameEngine.gameState.recordFinish(player: player)
        }

        // Check game over
        if gameEngine.gameState.isGameOver {
            gameEngine.gameState.phase = .gameOver
            delegate?.multiplayerControllerGameDidEnd(self)
            return
        }

        // Next turn or bonus roll
        if bonusRoll && !player.hasWon {
            gameEngine.gameState.phase = .rolling
            gameEngine.gameState.currentDiceValue = nil
        } else {
            gameEngine.gameState.nextTurn()
        }

        delegate?.multiplayerController(self, didChangeTurn: gameEngine.currentPlayer.color)
    }

    private func applyFullStateSync(_ payload: FullStateSyncPayload) {
        // Update all token states
        for encodedPlayer in payload.players {
            guard let color = PlayerColor(rawValue: encodedPlayer.color) else { continue }
            guard let player = gameEngine.gameState.player(for: color) else { continue }

            player.finishOrder = encodedPlayer.finishOrder

            for encodedToken in encodedPlayer.tokens {
                if encodedToken.index >= 0 && encodedToken.index < player.tokens.count {
                    player.tokens[encodedToken.index].state = encodedToken.state.toTokenState()
                }
            }
        }

        // Update game state
        gameEngine.gameState.currentDiceValue = payload.currentDiceValue
        gameEngine.gameState.consecutiveSixes = payload.consecutiveSixes

        if let phase = GamePhase(rawValue: payload.phase) {
            gameEngine.gameState.phase = phase
        }

        // Update current player
        if let currentColor = PlayerColor(rawValue: payload.currentPlayerColor) {
            if let index = gameEngine.gameState.players.firstIndex(where: { $0.color == currentColor }) {
                gameEngine.gameState.currentPlayerIndex = index
            }
        }

        // Update finish order
        gameEngine.gameState.finishOrder = payload.finishOrder.compactMap { PlayerColor(rawValue: $0) }

        sequenceNumber = payload.sequenceNumber
    }

    // MARK: - AI Actions

    /// Perform AI turn for a player color (host only)
    func performAITurn(for color: PlayerColor) {
        guard isHost else { return }
        guard gameEngine.currentPlayer.color == color else { return }

        if gameEngine.phase == .rolling {
            let value = gameEngine.rollDice()
            turnNumber += 1
            broadcastDiceRoll(value: value)
            delegate?.multiplayerController(self, didRollDice: value, for: color)
        }

        if gameEngine.phase == .selectingToken {
            if let bestToken = gameEngine.suggestBestMove() {
                let fromState = bestToken.state
                let result = gameEngine.moveToken(bestToken)
                let toState = bestToken.state

                broadcastTokenMove(token: bestToken, from: fromState, to: toState, result: result)
                delegate?.multiplayerController(self, didMoveToken: bestToken, from: fromState, to: toState, result: result)
            }
        }
    }

    // MARK: - Disconnection Handling

    /// Handle player disconnect
    func handlePlayerDisconnect(color: PlayerColor) {
        guard isHost else { return }

        disconnectedPlayers.insert(color)

        // Broadcast disconnection
        if let playerID = colorPlayerMap[color] {
            let payload = PlayerDisconnectedPayload(
                playerID: playerID,
                playerColor: color.rawValue,
                disconnectedAt: Date().timeIntervalSince1970
            )

            do {
                try matchManager.sendMessage(type: .playerDisconnected, payload: payload)
            } catch {
                print("Failed to broadcast disconnect: \(error)")
            }

            roomState.markPlayerDisconnected(playerID)
        }

        delegate?.multiplayerController(self, playerDidDisconnect: color)

        // Start reconnection timer
        startReconnectionTimer(for: color)
    }

    /// Replace disconnected player with AI
    func replaceWithAI(color: PlayerColor) {
        guard isHost else { return }
        guard disconnectedPlayers.contains(color) else { return }

        if let playerID = colorPlayerMap[color] {
            // Broadcast AI replacement
            let payload = PlayerReplacedWithAIPayload(
                playerID: playerID,
                playerColor: color.rawValue,
                replacedAt: Date().timeIntervalSince1970
            )

            do {
                try matchManager.sendMessage(type: .playerReplacedWithAI, payload: payload)
            } catch {
                print("Failed to broadcast AI replacement: \(error)")
            }

            roomState.replaceWithAI(playerID)
        }

        disconnectedPlayers.remove(color)
        cancelReconnectionTimer(for: color)

        delegate?.multiplayerController(self, playerReplacedWithAI: color)
    }

    private func startReconnectionTimer(for color: PlayerColor) {
        cancelReconnectionTimer(for: color)

        disconnectionTimers[color] = Timer.scheduledTimer(withTimeInterval: reconnectionTimeout, repeats: false) { [weak self] _ in
            self?.replaceWithAI(color: color)
        }
    }

    private func cancelReconnectionTimer(for color: PlayerColor) {
        disconnectionTimers[color]?.invalidate()
        disconnectionTimers.removeValue(forKey: color)
    }

    // MARK: - MatchManagerDelegate

    func matchManager(_ manager: MatchManager, didReceiveMessage message: NetworkMessage, from player: GKPlayer) {
        handleReceivedMessage(message, from: player)
    }

    func matchManager(_ manager: MatchManager, playerDidConnect player: GKPlayer) {
        // Check if this is a reconnecting player
        if let color = playerColorMap[player.gamePlayerID], disconnectedPlayers.contains(color) {
            let payload = PlayerReconnectedPayload(
                playerID: player.gamePlayerID,
                playerColor: color.rawValue
            )

            do {
                try matchManager.sendMessage(type: .playerReconnected, payload: payload)
            } catch {
                print("Failed to broadcast reconnection: \(error)")
            }

            disconnectedPlayers.remove(color)
            roomState.markPlayerReconnected(player.gamePlayerID)
            cancelReconnectionTimer(for: color)

            if isHost {
                broadcastFullStateSync()
            }
        }
    }

    func matchManager(_ manager: MatchManager, playerDidDisconnect player: GKPlayer) {
        if let color = playerColorMap[player.gamePlayerID] {
            handlePlayerDisconnect(color: color)
        }
    }

    func matchManagerDidFindMatch(_ manager: MatchManager) {
        // Not used during gameplay
    }

    func matchManager(_ manager: MatchManager, didFailWithError error: Error) {
        delegate?.multiplayerController(self, didEncounterError: error)
    }

    func matchManagerDidCancel(_ manager: MatchManager) {
        // Handle match cancellation
    }

    // MARK: - Cleanup

    func cleanup() {
        for timer in disconnectionTimers.values {
            timer.invalidate()
        }
        disconnectionTimers.removeAll()
        matchManager.disconnect()
    }
}
