import Foundation
import GameKit
import Combine

// MARK: - Room State

/// Represents the state of an online room
enum RoomState: Int {
    case creating = 0
    case waitingForPlayers = 1
    case allPlayersReady = 2
    case starting = 3
    case inGame = 4
    case ended = 5
}

// MARK: - Online Player

/// Represents a player in an online game
struct OnlinePlayer: Identifiable, Equatable {
    let id: String // GKPlayer.gamePlayerID
    let displayName: String
    var assignedColor: PlayerColor?
    var isReady: Bool
    var isHost: Bool
    var isLocal: Bool
    var isAI: Bool
    var isConnected: Bool

    init(from gkPlayer: GKPlayer, isLocal: Bool = false, isHost: Bool = false) {
        self.id = gkPlayer.gamePlayerID
        self.displayName = gkPlayer.displayName
        self.assignedColor = nil
        self.isReady = false
        self.isHost = isHost
        self.isLocal = isLocal
        self.isAI = false
        self.isConnected = true
    }

    init(id: String, displayName: String, color: PlayerColor?, isAI: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.assignedColor = color
        self.isReady = isAI
        self.isHost = false
        self.isLocal = false
        self.isAI = isAI
        self.isConnected = true
    }

    static func == (lhs: OnlinePlayer, rhs: OnlinePlayer) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Online Room State

/// Manages the state of an online game room/lobby
class OnlineRoomState: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var state: RoomState = .creating
    @Published private(set) var players: [OnlinePlayer] = []
    @Published private(set) var errorMessage: String?

    // MARK: - Properties

    private(set) var isHost: Bool
    private(set) var localPlayerID: String
    private let maxPlayers: Int = 4

    /// Check if game can start (host only, at least 2 players, all ready)
    var canStartGame: Bool {
        guard isHost else { return false }
        guard players.count >= 2 else { return false }
        return players.allSatisfy { $0.isReady || $0.isAI }
    }

    /// Check if room is full
    var isRoomFull: Bool {
        return players.count >= maxPlayers
    }

    /// Get player count (excluding AI)
    var humanPlayerCount: Int {
        return players.filter { !$0.isAI }.count
    }

    /// Get unassigned colors
    var availableColors: [PlayerColor] {
        let assignedColors = Set(players.compactMap { $0.assignedColor })
        return PlayerColor.allCases.filter { !assignedColors.contains($0) }
    }

    // MARK: - Initialization

    init(isHost: Bool, localPlayerID: String) {
        self.isHost = isHost
        self.localPlayerID = localPlayerID
    }

    // MARK: - Player Management

    /// Add a player to the room
    func addPlayer(_ player: OnlinePlayer) {
        guard !players.contains(where: { $0.id == player.id }) else { return }
        guard players.count < maxPlayers else { return }

        var newPlayer = player
        // Auto-assign color if available
        if newPlayer.assignedColor == nil, let color = availableColors.first {
            newPlayer.assignedColor = color
        }

        players.append(newPlayer)

        // Update state if needed
        updateRoomState()
    }

    /// Add the local player
    func addLocalPlayer(displayName: String) {
        let localPlayer = OnlinePlayer(
            id: localPlayerID,
            displayName: displayName,
            color: availableColors.first,
            isAI: false
        )
        var mutablePlayer = localPlayer
        mutablePlayer.isLocal = true
        mutablePlayer.isHost = isHost
        mutablePlayer.isReady = isHost // Host is always ready

        players.append(mutablePlayer)
        updateRoomState()
    }

    /// Remove a player from the room
    func removePlayer(withID playerID: String) {
        players.removeAll { $0.id == playerID }
        updateRoomState()
    }

    /// Update a player's ready status
    func setPlayerReady(_ playerID: String, isReady: Bool) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].isReady = isReady
        updateRoomState()
    }

    /// Update a player's assigned color
    func setPlayerColor(_ playerID: String, color: PlayerColor) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }

        // Unassign color from any other player
        for i in players.indices {
            if players[i].assignedColor == color && players[i].id != playerID {
                players[i].assignedColor = nil
            }
        }

        players[index].assignedColor = color
    }

    /// Mark a player as disconnected
    func markPlayerDisconnected(_ playerID: String) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].isConnected = false
    }

    /// Mark a player as reconnected
    func markPlayerReconnected(_ playerID: String) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }
        players[index].isConnected = true
    }

    /// Replace a disconnected player with AI
    func replaceWithAI(_ playerID: String) {
        guard let index = players.firstIndex(where: { $0.id == playerID }) else { return }

        let player = players[index]
        players[index] = OnlinePlayer(
            id: "AI_\(player.assignedColor?.rawValue ?? 0)",
            displayName: "AI (\(player.assignedColor?.name ?? "Unknown"))",
            color: player.assignedColor,
            isAI: true
        )
    }

    // MARK: - Color Assignment

    /// Auto-assign colors to all players (host only)
    func assignColors() {
        guard isHost else { return }

        let colors = PlayerColor.allCases
        for (index, _) in players.enumerated() {
            if index < colors.count {
                players[index].assignedColor = colors[index]
            }
        }
    }

    /// Fill remaining slots with AI players (host only)
    func fillWithAI() {
        guard isHost else { return }

        while players.count < maxPlayers {
            guard let color = availableColors.first else { break }

            let aiPlayer = OnlinePlayer(
                id: "AI_\(color.rawValue)",
                displayName: "AI (\(color.name))",
                color: color,
                isAI: true
            )
            players.append(aiPlayer)
        }

        updateRoomState()
    }

    // MARK: - State Management

    /// Update room state based on current players
    private func updateRoomState() {
        switch state {
        case .creating:
            if !players.isEmpty {
                state = .waitingForPlayers
            }
        case .waitingForPlayers:
            if canStartGame {
                state = .allPlayersReady
            }
        case .allPlayersReady:
            if !canStartGame {
                state = .waitingForPlayers
            }
        case .starting, .inGame, .ended:
            // These states are managed externally
            break
        }
    }

    /// Set room state to starting
    func startGame() {
        guard canStartGame else { return }
        state = .starting
    }

    /// Set room state to in game
    func setInGame() {
        state = .inGame
    }

    /// Set room state to ended
    func endGame() {
        state = .ended
    }

    /// Set error message
    func setError(_ message: String) {
        errorMessage = message
    }

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Serialization

    /// Get color assignments for network transmission
    func getColorAssignments() -> [String: Int] {
        var assignments: [String: Int] = [:]
        for player in players {
            if let color = player.assignedColor {
                assignments[player.id] = color.rawValue
            }
        }
        return assignments
    }

    /// Get player order for turn taking
    func getPlayerOrder() -> [String] {
        return players
            .sorted { ($0.assignedColor?.rawValue ?? 0) < ($1.assignedColor?.rawValue ?? 0) }
            .map { $0.id }
    }

    /// Get player by color
    func player(for color: PlayerColor) -> OnlinePlayer? {
        return players.first { $0.assignedColor == color }
    }

    /// Get player by ID
    func player(withID playerID: String) -> OnlinePlayer? {
        return players.first { $0.id == playerID }
    }

    /// Check if a color is assigned to the local player
    func isLocalPlayerColor(_ color: PlayerColor) -> Bool {
        return players.first { $0.assignedColor == color }?.isLocal == true
    }

    /// Get the local player's assigned color
    var localPlayerColor: PlayerColor? {
        return players.first { $0.isLocal }?.assignedColor
    }
}
