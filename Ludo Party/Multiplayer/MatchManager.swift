import Foundation
import GameKit

// MARK: - Match Manager Delegate

/// Protocol for receiving match events
protocol MatchManagerDelegate: AnyObject {
    func matchManager(_ manager: MatchManager, didReceiveMessage message: NetworkMessage, from player: GKPlayer)
    func matchManager(_ manager: MatchManager, playerDidConnect player: GKPlayer)
    func matchManager(_ manager: MatchManager, playerDidDisconnect player: GKPlayer)
    func matchManagerDidFindMatch(_ manager: MatchManager)
    func matchManager(_ manager: MatchManager, didFailWithError error: Error)
    func matchManagerDidCancel(_ manager: MatchManager)
}

// MARK: - Match Manager

/// Manages GameKit matchmaking and GKMatch lifecycle
class MatchManager: NSObject {

    // MARK: - Properties

    weak var delegate: MatchManagerDelegate?

    private(set) var match: GKMatch?
    private(set) var isHost: Bool = false
    private(set) var connectedPlayers: [GKPlayer] = []

    private var sequenceNumber: UInt32 = 0
    private let sequenceLock = NSLock()

    /// The local player's ID
    var localPlayerID: String {
        return GKLocalPlayer.local.gamePlayerID
    }

    /// The local player's display name
    var localPlayerDisplayName: String {
        return GKLocalPlayer.local.displayName
    }

    /// Check if Game Center is authenticated
    var isAuthenticated: Bool {
        return GKLocalPlayer.local.isAuthenticated
    }

    /// Get all players including local player
    var allPlayers: [GKPlayer] {
        var players = connectedPlayers
        if !players.contains(where: { $0.gamePlayerID == localPlayerID }) {
            players.insert(GKLocalPlayer.local, at: 0)
        }
        return players
    }

    /// Get the number of expected players (including local)
    var expectedPlayerCount: Int {
        return (match?.expectedPlayerCount ?? 0) + connectedPlayers.count + 1
    }

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - Room Management

    /// Create a room as host
    func createRoom(minPlayers: Int = 2, maxPlayers: Int = 4, completion: @escaping (Result<GKMatch, Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(MatchManagerError.notAuthenticated))
            return
        }

        let request = GKMatchRequest()
        request.minPlayers = minPlayers
        request.maxPlayers = maxPlayers
        request.inviteMessage = "Join my Ludo Party game!"

        GKMatchmaker.shared().findMatch(for: request) { [weak self] match, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let match = match else {
                    completion(.failure(MatchManagerError.matchCreationFailed))
                    return
                }

                self?.setupMatch(match, asHost: true)
                completion(.success(match))
            }
        }
    }

    /// Show the matchmaker UI for creating or joining games
    func showMatchmakerUI(from viewController: UIViewController, minPlayers: Int = 2, maxPlayers: Int = 4) {
        guard isAuthenticated else {
            delegate?.matchManager(self, didFailWithError: MatchManagerError.notAuthenticated)
            return
        }

        let request = GKMatchRequest()
        request.minPlayers = minPlayers
        request.maxPlayers = maxPlayers
        request.inviteMessage = "Join my Ludo Party game!"

        guard let matchmakerVC = GKMatchmakerViewController(matchRequest: request) else {
            delegate?.matchManager(self, didFailWithError: MatchManagerError.matchmakerUIFailed)
            return
        }

        matchmakerVC.matchmakerDelegate = self
        viewController.present(matchmakerVC, animated: true)
    }

    /// Setup match after connection
    private func setupMatch(_ match: GKMatch, asHost: Bool) {
        self.match = match
        self.isHost = asHost
        match.delegate = self

        // Add already connected players
        connectedPlayers = match.players

        delegate?.matchManagerDidFindMatch(self)
    }

    // MARK: - Data Transmission

    /// Get the next sequence number
    private func nextSequenceNumber() -> UInt32 {
        sequenceLock.lock()
        defer { sequenceLock.unlock() }
        sequenceNumber += 1
        return sequenceNumber
    }

    /// Send data to all connected players
    func sendDataToAll(_ data: Data, mode: GKMatch.SendDataMode) throws {
        guard let match = match else {
            throw MatchManagerError.noActiveMatch
        }

        try match.sendData(toAllPlayers: data, with: mode)
    }

    /// Send a network message to all players
    func sendMessageToAll(_ message: NetworkMessage, mode: GKMatch.SendDataMode = .reliable) throws {
        let data = try message.encode()
        try sendDataToAll(data, mode: mode)
    }

    /// Create and send a message with payload
    func sendMessage<T: Encodable>(
        type: NetworkMessageType,
        payload: T,
        mode: GKMatch.SendDataMode = .reliable
    ) throws {
        let message = try NetworkMessage.create(
            type: type,
            senderID: localPlayerID,
            sequenceNumber: nextSequenceNumber(),
            payload: payload
        )
        try sendMessageToAll(message, mode: mode)
    }

    /// Send a simple message without payload
    func sendMessage(type: NetworkMessageType, mode: GKMatch.SendDataMode = .reliable) throws {
        let message = NetworkMessage(
            type: type,
            senderID: localPlayerID,
            sequenceNumber: nextSequenceNumber()
        )
        try sendMessageToAll(message, mode: mode)
    }

    /// Send data to specific players
    func sendData(_ data: Data, to players: [GKPlayer], mode: GKMatch.SendDataMode) throws {
        guard let match = match else {
            throw MatchManagerError.noActiveMatch
        }

        try match.send(data, to: players, dataMode: mode)
    }

    // MARK: - Disconnection

    /// Disconnect from the current match
    func disconnect() {
        match?.disconnect()
        match?.delegate = nil
        match = nil
        connectedPlayers.removeAll()
        isHost = false
        sequenceNumber = 0
    }

    // MARK: - Player Identification

    /// Get player by ID
    func player(withID playerID: String) -> GKPlayer? {
        if GKLocalPlayer.local.gamePlayerID == playerID {
            return GKLocalPlayer.local
        }
        return connectedPlayers.first { $0.gamePlayerID == playerID }
    }

    /// Determine if local player should be host based on player IDs
    func determineHost() -> Bool {
        let allPlayerIDs = allPlayers.map { $0.gamePlayerID }.sorted()
        return allPlayerIDs.first == localPlayerID
    }
}

// MARK: - GKMatchDelegate

extension MatchManager: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        do {
            let message = try NetworkMessage.decode(from: data)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.matchManager(self, didReceiveMessage: message, from: player)
            }
        } catch {
            print("Failed to decode network message: \(error)")
        }
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch state {
            case .connected:
                if !self.connectedPlayers.contains(where: { $0.gamePlayerID == player.gamePlayerID }) {
                    self.connectedPlayers.append(player)
                }
                self.delegate?.matchManager(self, playerDidConnect: player)

            case .disconnected:
                self.connectedPlayers.removeAll { $0.gamePlayerID == player.gamePlayerID }
                self.delegate?.matchManager(self, playerDidDisconnect: player)

            @unknown default:
                break
            }
        }
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.matchManager(self, didFailWithError: error ?? MatchManagerError.unknownError)
        }
    }
}

// MARK: - GKMatchmakerViewControllerDelegate

extension MatchManager: GKMatchmakerViewControllerDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        viewController.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.matchManagerDidCancel(self)
        }
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        viewController.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.matchManager(self, didFailWithError: error)
        }
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        viewController.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            // Determine host status based on player IDs
            self.setupMatch(match, asHost: self.determineHost())
        }
    }
}

// MARK: - Match Manager Errors

enum MatchManagerError: LocalizedError {
    case notAuthenticated
    case noActiveMatch
    case matchCreationFailed
    case matchmakerUIFailed
    case sendFailed
    case unknownError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Game Center"
        case .noActiveMatch:
            return "No active match"
        case .matchCreationFailed:
            return "Failed to create match"
        case .matchmakerUIFailed:
            return "Failed to show matchmaker UI"
        case .sendFailed:
            return "Failed to send data"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
