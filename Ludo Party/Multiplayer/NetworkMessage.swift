import Foundation
import GameKit

// MARK: - Network Message Types

/// Types of messages that can be sent between players
enum NetworkMessageType: UInt8, Codable {
    // Lobby messages
    case playerJoined = 0
    case playerLeft = 1
    case playerReady = 2
    case gameStart = 3
    case roomClosed = 4

    // Game action messages
    case diceRoll = 10
    case tokenMove = 11
    case turnEnd = 12

    // Synchronization messages
    case fullStateSync = 20
    case requestSync = 21

    // Disconnection messages
    case playerDisconnected = 30
    case playerReplacedWithAI = 31
    case playerReconnected = 32
}

// MARK: - Network Message

/// Base network message structure
struct NetworkMessage: Codable {
    let type: NetworkMessageType
    let senderID: String
    let timestamp: TimeInterval
    let sequenceNumber: UInt32
    let payload: Data?

    init(type: NetworkMessageType, senderID: String, sequenceNumber: UInt32, payload: Data? = nil) {
        self.type = type
        self.senderID = senderID
        self.timestamp = Date().timeIntervalSince1970
        self.sequenceNumber = sequenceNumber
        self.payload = payload
    }

    /// Encode message to Data for network transmission
    func encode() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    /// Decode message from network Data
    static func decode(from data: Data) throws -> NetworkMessage {
        return try JSONDecoder().decode(NetworkMessage.self, from: data)
    }
}

// MARK: - Payload Structures

/// Payload for player joined message
struct PlayerJoinedPayload: Codable {
    let playerID: String
    let displayName: String
}

/// Payload for player ready message
struct PlayerReadyPayload: Codable {
    let playerID: String
    let isReady: Bool
}

/// Payload for game start message
struct GameStartPayload: Codable {
    let colorAssignments: [String: Int] // playerID -> PlayerColor.rawValue
    let playerOrder: [String] // Order of playerIDs for turn taking
    let hostID: String
    let initialSequenceNumber: UInt32
}

/// Payload for dice roll message
struct DiceRollPayload: Codable {
    let playerColor: Int // PlayerColor.rawValue
    let diceValue: Int
    let turnNumber: Int
}

/// Encoded representation of TokenState for network transmission
struct EncodedTokenState: Codable, Equatable {
    enum StateType: Int, Codable {
        case inYard = 0
        case onTrack = 1
        case onHomePath = 2
        case home = 3
    }

    let stateType: StateType
    let position: Int? // Only used for onTrack and onHomePath

    init(from tokenState: TokenState) {
        switch tokenState {
        case .inYard:
            self.stateType = .inYard
            self.position = nil
        case .onTrack(let pos):
            self.stateType = .onTrack
            self.position = pos
        case .onHomePath(let pos):
            self.stateType = .onHomePath
            self.position = pos
        case .home:
            self.stateType = .home
            self.position = nil
        }
    }

    func toTokenState() -> TokenState {
        switch stateType {
        case .inYard:
            return .inYard
        case .onTrack:
            return .onTrack(position: position ?? 0)
        case .onHomePath:
            return .onHomePath(position: position ?? 0)
        case .home:
            return .home
        }
    }
}

/// Payload for token move message
struct TokenMovePayload: Codable {
    let playerColor: Int // PlayerColor.rawValue
    let tokenIndex: Int
    let fromState: EncodedTokenState
    let toState: EncodedTokenState
    let capturedTokenColor: Int? // PlayerColor.rawValue of captured token, if any
    let capturedTokenIndex: Int?
    let turnNumber: Int
}

/// Payload for turn end message
struct TurnEndPayload: Codable {
    let playerColor: Int // PlayerColor.rawValue of player whose turn ended
    let nextPlayerColor: Int // PlayerColor.rawValue of next player
    let grantedBonusRoll: Bool
    let reason: String? // Reason for bonus roll if applicable
}

/// Encoded token data for full state sync
struct EncodedToken: Codable {
    let color: Int // PlayerColor.rawValue
    let index: Int
    let state: EncodedTokenState
}

/// Encoded player data for full state sync
struct EncodedPlayer: Codable {
    let color: Int // PlayerColor.rawValue
    let tokens: [EncodedToken]
    let finishOrder: Int?
    let isAI: Bool
    let onlinePlayerID: String? // nil if AI
}

/// Payload for full state synchronization
struct FullStateSyncPayload: Codable {
    let players: [EncodedPlayer]
    let currentPlayerColor: Int // PlayerColor.rawValue
    let phase: Int // GamePhase as raw value
    let currentDiceValue: Int?
    let consecutiveSixes: Int
    let finishOrder: [Int] // Array of PlayerColor.rawValue
    let sequenceNumber: UInt32
}

/// Payload for player disconnection
struct PlayerDisconnectedPayload: Codable {
    let playerID: String
    let playerColor: Int // PlayerColor.rawValue
    let disconnectedAt: TimeInterval
}

/// Payload for player replaced with AI
struct PlayerReplacedWithAIPayload: Codable {
    let playerID: String
    let playerColor: Int // PlayerColor.rawValue
    let replacedAt: TimeInterval
}

/// Payload for player reconnection
struct PlayerReconnectedPayload: Codable {
    let playerID: String
    let playerColor: Int // PlayerColor.rawValue
}

// MARK: - Payload Encoding/Decoding Helpers

extension NetworkMessage {
    /// Create a message with an encodable payload
    static func create<T: Encodable>(
        type: NetworkMessageType,
        senderID: String,
        sequenceNumber: UInt32,
        payload: T
    ) throws -> NetworkMessage {
        let payloadData = try JSONEncoder().encode(payload)
        return NetworkMessage(type: type, senderID: senderID, sequenceNumber: sequenceNumber, payload: payloadData)
    }

    /// Decode the payload to a specific type
    func decodePayload<T: Decodable>(_ type: T.Type) throws -> T {
        guard let payloadData = payload else {
            throw NetworkMessageError.missingPayload
        }
        return try JSONDecoder().decode(type, from: payloadData)
    }
}

enum NetworkMessageError: Error {
    case missingPayload
    case invalidPayload
    case encodingFailed
    case decodingFailed
}

// MARK: - GamePhase Extension for Encoding

extension GamePhase {
    var rawValue: Int {
        switch self {
        case .waitingToStart: return 0
        case .rolling: return 1
        case .selectingToken: return 2
        case .animatingMove: return 3
        case .gameOver: return 4
        }
    }

    init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .waitingToStart
        case 1: self = .rolling
        case 2: self = .selectingToken
        case 3: self = .animatingMove
        case 4: self = .gameOver
        default: return nil
        }
    }
}
