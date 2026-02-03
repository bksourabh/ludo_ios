import Foundation

/// Data structure for saving game state
struct GameSaveData: Codable {
    let savedAt: Date
    let playerColors: [PlayerColor]
    let currentPlayerIndex: Int
    let consecutiveSixes: Int
    let finishOrder: [PlayerColor]

    // Token states for each player (4 tokens per player)
    let tokenStates: [PlayerColor: [TokenState]]

    // Player finish orders
    let playerFinishOrders: [PlayerColor: Int?]

    // Game configuration
    let redPlayerType: PlayerType
    let greenPlayerType: PlayerType
    let yellowPlayerType: PlayerType
    let bluePlayerType: PlayerType
    let goodLuckForAll: Bool
}

/// Manages saving and loading game state for offline play
class GameSaveManager {
    static let shared = GameSaveManager()

    private let saveKey = "savedOfflineGame"
    private let userDefaults = UserDefaults.standard

    private init() {}

    // MARK: - Public Methods

    /// Check if there's a saved game available
    var hasSavedGame: Bool {
        return userDefaults.data(forKey: saveKey) != nil
    }

    /// Get saved game info for display (without fully loading)
    var savedGameInfo: (date: Date, players: [PlayerColor])? {
        guard let data = userDefaults.data(forKey: saveKey) else { return nil }

        do {
            let saveData = try JSONDecoder().decode(GameSaveData.self, from: data)
            return (saveData.savedAt, saveData.playerColors)
        } catch {
            print("[GameSaveManager] Failed to decode save info: \(error)")
            return nil
        }
    }

    /// Save the current game state
    func saveGame(gameState: GameState, gameConfig: GameConfig) {
        // Collect token states for each player
        var tokenStates: [PlayerColor: [TokenState]] = [:]
        var playerFinishOrders: [PlayerColor: Int?] = [:]

        for player in gameState.players {
            tokenStates[player.color] = player.tokens.map { $0.state }
            playerFinishOrders[player.color] = player.finishOrder
        }

        let saveData = GameSaveData(
            savedAt: Date(),
            playerColors: gameState.players.map { $0.color },
            currentPlayerIndex: gameState.currentPlayerIndex,
            consecutiveSixes: gameState.consecutiveSixes,
            finishOrder: gameState.finishOrder,
            tokenStates: tokenStates,
            playerFinishOrders: playerFinishOrders,
            redPlayerType: gameConfig.redPlayer,
            greenPlayerType: gameConfig.greenPlayer,
            yellowPlayerType: gameConfig.yellowPlayer,
            bluePlayerType: gameConfig.bluePlayer,
            goodLuckForAll: gameConfig.goodLuckForAll
        )

        do {
            let data = try JSONEncoder().encode(saveData)
            userDefaults.set(data, forKey: saveKey)
            print("[GameSaveManager] Game saved successfully")
        } catch {
            print("[GameSaveManager] Failed to save game: \(error)")
        }
    }

    /// Load the saved game state
    func loadGame() -> (gameState: GameState, gameConfig: GameConfig)? {
        guard let data = userDefaults.data(forKey: saveKey) else {
            print("[GameSaveManager] No saved game found")
            return nil
        }

        do {
            let saveData = try JSONDecoder().decode(GameSaveData.self, from: data)

            // Recreate game config
            var gameConfig = GameConfig()
            gameConfig.redPlayer = saveData.redPlayerType
            gameConfig.greenPlayer = saveData.greenPlayerType
            gameConfig.yellowPlayer = saveData.yellowPlayerType
            gameConfig.bluePlayer = saveData.bluePlayerType
            gameConfig.goodLuckForAll = saveData.goodLuckForAll
            gameConfig.gameMode = .offline

            // Recreate game state
            let gameState = GameState(playerColors: saveData.playerColors)
            gameState.currentPlayerIndex = saveData.currentPlayerIndex
            gameState.consecutiveSixes = saveData.consecutiveSixes
            gameState.finishOrder = saveData.finishOrder
            gameState.phase = .rolling  // Always resume at rolling phase

            // Restore token states
            for player in gameState.players {
                if let states = saveData.tokenStates[player.color] {
                    for (index, state) in states.enumerated() where index < player.tokens.count {
                        player.tokens[index].state = state
                    }
                }
                if let finishOrder = saveData.playerFinishOrders[player.color] {
                    player.finishOrder = finishOrder
                }
            }

            print("[GameSaveManager] Game loaded successfully")
            return (gameState, gameConfig)

        } catch {
            print("[GameSaveManager] Failed to load game: \(error)")
            return nil
        }
    }

    /// Delete the saved game
    func deleteSavedGame() {
        userDefaults.removeObject(forKey: saveKey)
        print("[GameSaveManager] Saved game deleted")
    }
}
