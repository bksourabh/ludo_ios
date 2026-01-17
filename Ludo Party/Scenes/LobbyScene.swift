import SpriteKit
import GameKit
import Combine

// MARK: - Lobby Scene Delegate

protocol LobbySceneDelegate: AnyObject {
    func lobbySceneDidStartGame(_ scene: LobbyScene, roomState: OnlineRoomState)
    func lobbySceneDidCancel(_ scene: LobbyScene)
    func lobbySceneRequestsMatchmaker(_ scene: LobbyScene)
}

// MARK: - Lobby Scene

/// Scene for online game lobby - player management before game starts
class LobbyScene: SKScene {

    // MARK: - Properties

    weak var lobbyDelegate: LobbySceneDelegate?

    private var roomState: OnlineRoomState!
    private var matchManager: MatchManager!
    private var cancellables = Set<AnyCancellable>()

    // UI Elements
    private var titleLabel: SKLabelNode!
    private var statusLabel: SKLabelNode!
    private var playerSlots: [PlayerSlotNode] = []
    private var startButton: SKShapeNode!
    private var startButtonLabel: SKLabelNode!
    private var readyButton: SKShapeNode!
    private var readyButtonLabel: SKLabelNode!
    private var inviteButton: SKShapeNode!
    private var addAIButton: SKShapeNode!
    private var backButton: SKShapeNode!
    private var waitingLabel: SKLabelNode!

    // Layout constants
    private let slotHeight: CGFloat = 70
    private let slotSpacing: CGFloat = 12
    private let buttonHeight: CGFloat = 50

    // MARK: - Initialization

    func configure(roomState: OnlineRoomState, matchManager: MatchManager) {
        self.roomState = roomState
        self.matchManager = matchManager
    }

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)

        setupUI()
        setupObservers()
        updateUI()
    }

    override func willMove(from view: SKView) {
        cancellables.removeAll()
    }

    // MARK: - Setup

    private func setupUI() {
        setupHeader()
        setupPlayerSlots()
        setupButtons()
        setupWaitingIndicator()
    }

    private func setupHeader() {
        // Title
        titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = roomState.isHost ? "Your Game Room" : "Game Lobby"
        titleLabel.fontSize = 28
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: size.height * 0.40)
        addChild(titleLabel)

        // Status label
        statusLabel = SKLabelNode(fontNamed: "Helvetica")
        statusLabel.text = "Waiting for players..."
        statusLabel.fontSize = 16
        statusLabel.fontColor = SKColor(white: 0.6, alpha: 1.0)
        statusLabel.position = CGPoint(x: 0, y: size.height * 0.35)
        addChild(statusLabel)

        // Back button
        let backButtonSize: CGFloat = 40
        backButton = SKShapeNode(rectOf: CGSize(width: backButtonSize, height: backButtonSize), cornerRadius: 8)
        backButton.position = CGPoint(x: -size.width/2 + 35, y: size.height/2 - 35)
        backButton.fillColor = SKColor(white: 0.2, alpha: 0.8)
        backButton.strokeColor = SKColor(white: 0.5, alpha: 1.0)
        backButton.lineWidth = 1
        backButton.name = "backButton"
        addChild(backButton)

        // Back arrow
        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 5, y: 0))
        arrowPath.addLine(to: CGPoint(x: -5, y: 8))
        arrowPath.addLine(to: CGPoint(x: -5, y: -8))
        arrowPath.closeSubpath()
        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = .white
        arrow.strokeColor = .clear
        arrow.position = backButton.position
        addChild(arrow)
    }

    private func setupPlayerSlots() {
        let startY = size.height * 0.20
        let slotWidth = size.width * 0.85

        for i in 0..<4 {
            let yPos = startY - CGFloat(i) * (slotHeight + slotSpacing)
            let color = PlayerColor.allCases[i]

            let slot = PlayerSlotNode(
                size: CGSize(width: slotWidth, height: slotHeight),
                color: color,
                index: i
            )
            slot.position = CGPoint(x: 0, y: yPos)
            addChild(slot)
            playerSlots.append(slot)
        }
    }

    private func setupButtons() {
        let buttonWidth = size.width * 0.4
        let bottomY = -size.height * 0.38

        if roomState.isHost {
            // Start button (host only)
            startButton = createButton(
                text: "START GAME",
                width: buttonWidth,
                color: SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0),
                name: "startButton"
            )
            startButton.position = CGPoint(x: buttonWidth/2 + 10, y: bottomY)
            addChild(startButton)

            startButtonLabel = startButton.children.first as? SKLabelNode

            // Add AI button
            addAIButton = createButton(
                text: "Add AI",
                width: buttonWidth * 0.8,
                color: SKColor(red: 0.3, green: 0.3, blue: 0.5, alpha: 1.0),
                name: "addAIButton"
            )
            addAIButton.position = CGPoint(x: -buttonWidth/2 - 10, y: bottomY)
            addChild(addAIButton)

            // Invite button
            inviteButton = createButton(
                text: "Invite",
                width: buttonWidth * 0.8,
                color: SKColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0),
                name: "inviteButton"
            )
            inviteButton.position = CGPoint(x: -buttonWidth/2 - 10, y: bottomY + buttonHeight + 15)
            addChild(inviteButton)
        } else {
            // Ready button (client only)
            readyButton = createButton(
                text: "READY",
                width: buttonWidth,
                color: SKColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0),
                name: "readyButton"
            )
            readyButton.position = CGPoint(x: 0, y: bottomY)
            addChild(readyButton)

            readyButtonLabel = readyButton.children.first as? SKLabelNode
        }
    }

    private func setupWaitingIndicator() {
        waitingLabel = SKLabelNode(fontNamed: "Helvetica")
        waitingLabel.text = "Waiting for host to start..."
        waitingLabel.fontSize = 14
        waitingLabel.fontColor = SKColor(white: 0.5, alpha: 1.0)
        waitingLabel.position = CGPoint(x: 0, y: -size.height * 0.45)
        waitingLabel.isHidden = roomState.isHost
        addChild(waitingLabel)
    }

    private func createButton(text: String, width: CGFloat, color: SKColor, name: String) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: buttonHeight), cornerRadius: 10)
        button.fillColor = color
        button.strokeColor = color.withAlphaComponent(0.7)
        button.lineWidth = 2
        button.name = name

        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        button.addChild(label)

        return button
    }

    // MARK: - Observers

    private func setupObservers() {
        // Observe room state changes
        roomState.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateUI()
            }
            .store(in: &cancellables)

        roomState.$players
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateUI()
            }
            .store(in: &cancellables)

        roomState.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                if let message = message {
                    self?.showError(message)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - UI Updates

    private func updateUI() {
        updateStatusLabel()
        updatePlayerSlots()
        updateButtons()
    }

    private func updateStatusLabel() {
        let playerCount = roomState.players.count
        let humanCount = roomState.humanPlayerCount

        switch roomState.state {
        case .creating:
            statusLabel.text = "Creating room..."
        case .waitingForPlayers:
            if roomState.isHost {
                statusLabel.text = "\(playerCount)/4 players (\(humanCount) human)"
            } else {
                statusLabel.text = "Waiting for other players..."
            }
        case .allPlayersReady:
            statusLabel.text = "All players ready!"
        case .starting:
            statusLabel.text = "Starting game..."
        case .inGame:
            statusLabel.text = "Game in progress"
        case .ended:
            statusLabel.text = "Game ended"
        }
    }

    private func updatePlayerSlots() {
        for (index, slot) in playerSlots.enumerated() {
            let color = PlayerColor.allCases[index]
            let player = roomState.player(for: color)

            if let player = player {
                slot.setPlayer(
                    name: player.displayName,
                    isReady: player.isReady,
                    isHost: player.isHost,
                    isLocal: player.isLocal,
                    isAI: player.isAI,
                    isConnected: player.isConnected
                )
            } else {
                slot.setEmpty()
            }
        }
    }

    private func updateButtons() {
        if roomState.isHost {
            // Update start button
            let canStart = roomState.canStartGame
            startButton.alpha = canStart ? 1.0 : 0.5
            startButton.isUserInteractionEnabled = canStart

            // Update add AI button
            let canAddAI = roomState.players.count < 4
            addAIButton.alpha = canAddAI ? 1.0 : 0.5
            addAIButton.isUserInteractionEnabled = canAddAI
        } else {
            // Update ready button
            let localPlayer = roomState.players.first { $0.isLocal }
            let isReady = localPlayer?.isReady ?? false
            readyButtonLabel?.text = isReady ? "NOT READY" : "READY"
            readyButton.fillColor = isReady ?
                SKColor(red: 0.5, green: 0.3, blue: 0.3, alpha: 1.0) :
                SKColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0)
        }

        // Update waiting label
        if !roomState.isHost {
            waitingLabel.isHidden = roomState.state != .waitingForPlayers
        }
    }

    private func showError(_ message: String) {
        // Create error overlay
        let errorLabel = SKLabelNode(fontNamed: "Helvetica")
        errorLabel.text = message
        errorLabel.fontSize = 14
        errorLabel.fontColor = SKColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
        errorLabel.position = CGPoint(x: 0, y: size.height * 0.32)
        errorLabel.name = "errorLabel"
        addChild(errorLabel)

        // Auto-dismiss after 3 seconds
        let wait = SKAction.wait(forDuration: 3.0)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let remove = SKAction.removeFromParent()
        errorLabel.run(SKAction.sequence([wait, fadeOut, remove]))

        roomState.clearError()
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Back button
        if backButton.contains(location) {
            animateButton(backButton) { [weak self] in
                guard let self = self else { return }
                self.matchManager.disconnect()
                self.lobbyDelegate?.lobbySceneDidCancel(self)
            }
            return
        }

        if roomState.isHost {
            // Start button
            if startButton.contains(location) && roomState.canStartGame {
                animateButton(startButton) { [weak self] in
                    self?.startGame()
                }
                return
            }

            // Add AI button
            if addAIButton.contains(location) && roomState.players.count < 4 {
                animateButton(addAIButton) { [weak self] in
                    self?.addAIPlayer()
                }
                return
            }

            // Invite button
            if inviteButton.contains(location) {
                animateButton(inviteButton) { [weak self] in
                    guard let self = self else { return }
                    self.lobbyDelegate?.lobbySceneRequestsMatchmaker(self)
                }
                return
            }
        } else {
            // Ready button
            if readyButton.contains(location) {
                animateButton(readyButton) { [weak self] in
                    self?.toggleReady()
                }
                return
            }
        }
    }

    private func animateButton(_ button: SKShapeNode, completion: @escaping () -> Void) {
        let pressDown = SKAction.scale(to: 0.95, duration: 0.1)
        let pressUp = SKAction.scale(to: 1.0, duration: 0.1)
        button.run(SKAction.sequence([pressDown, pressUp])) {
            completion()
        }
    }

    // MARK: - Actions

    private func startGame() {
        guard roomState.isHost && roomState.canStartGame else { return }

        roomState.startGame()

        // Broadcast game start to all players
        do {
            let payload = GameStartPayload(
                colorAssignments: roomState.getColorAssignments(),
                playerOrder: roomState.getPlayerOrder(),
                hostID: matchManager.localPlayerID,
                initialSequenceNumber: 0
            )
            try matchManager.sendMessage(type: .gameStart, payload: payload)
        } catch {
            roomState.setError("Failed to start game: \(error.localizedDescription)")
            return
        }

        lobbyDelegate?.lobbySceneDidStartGame(self, roomState: roomState)
    }

    private func addAIPlayer() {
        guard roomState.isHost else { return }
        guard let color = roomState.availableColors.first else { return }

        let aiPlayer = OnlinePlayer(
            id: "AI_\(color.rawValue)",
            displayName: "AI (\(color.name))",
            color: color,
            isAI: true
        )
        roomState.addPlayer(aiPlayer)
    }

    private func toggleReady() {
        guard let localPlayer = roomState.players.first(where: { $0.isLocal }) else { return }

        let newReadyState = !localPlayer.isReady
        roomState.setPlayerReady(localPlayer.id, isReady: newReadyState)

        // Broadcast ready state
        do {
            let payload = PlayerReadyPayload(playerID: localPlayer.id, isReady: newReadyState)
            try matchManager.sendMessage(type: .playerReady, payload: payload)
        } catch {
            roomState.setError("Failed to update ready state")
        }
    }
}

// MARK: - Player Slot Node

/// Visual representation of a player slot in the lobby
class PlayerSlotNode: SKNode {

    private let background: SKShapeNode
    private let colorIndicator: SKShapeNode
    private let nameLabel: SKLabelNode
    private let statusLabel: SKLabelNode
    private let hostBadge: SKLabelNode
    private let readyIndicator: SKShapeNode

    private let playerColor: PlayerColor
    private let slotSize: CGSize

    init(size: CGSize, color: PlayerColor, index: Int) {
        self.slotSize = size
        self.playerColor = color

        // Background
        background = SKShapeNode(rectOf: size, cornerRadius: 12)
        background.fillColor = SKColor(white: 0.15, alpha: 1.0)
        background.strokeColor = color.color.withAlphaComponent(0.5)
        background.lineWidth = 2

        // Color indicator
        let indicatorSize: CGFloat = 40
        colorIndicator = SKShapeNode(circleOfRadius: indicatorSize / 2)
        colorIndicator.fillColor = color.color
        colorIndicator.strokeColor = color.color.withAlphaComponent(0.7)
        colorIndicator.lineWidth = 2
        colorIndicator.position = CGPoint(x: -size.width/2 + 35, y: 0)

        // Name label
        nameLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        nameLabel.fontSize = 16
        nameLabel.fontColor = .white
        nameLabel.horizontalAlignmentMode = .left
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: -size.width/2 + 65, y: 8)

        // Status label
        statusLabel = SKLabelNode(fontNamed: "Helvetica")
        statusLabel.fontSize = 12
        statusLabel.fontColor = SKColor(white: 0.5, alpha: 1.0)
        statusLabel.horizontalAlignmentMode = .left
        statusLabel.verticalAlignmentMode = .center
        statusLabel.position = CGPoint(x: -size.width/2 + 65, y: -10)

        // Host badge
        hostBadge = SKLabelNode(fontNamed: "Helvetica-Bold")
        hostBadge.text = "HOST"
        hostBadge.fontSize = 10
        hostBadge.fontColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
        hostBadge.horizontalAlignmentMode = .right
        hostBadge.verticalAlignmentMode = .center
        hostBadge.position = CGPoint(x: size.width/2 - 50, y: 0)
        hostBadge.isHidden = true

        // Ready indicator
        readyIndicator = SKShapeNode(circleOfRadius: 8)
        readyIndicator.fillColor = .green
        readyIndicator.strokeColor = .clear
        readyIndicator.position = CGPoint(x: size.width/2 - 25, y: 0)
        readyIndicator.isHidden = true

        super.init()

        addChild(background)
        addChild(colorIndicator)
        addChild(nameLabel)
        addChild(statusLabel)
        addChild(hostBadge)
        addChild(readyIndicator)

        setEmpty()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setPlayer(name: String, isReady: Bool, isHost: Bool, isLocal: Bool, isAI: Bool, isConnected: Bool) {
        nameLabel.text = name
        nameLabel.fontColor = isConnected ? .white : SKColor(white: 0.4, alpha: 1.0)

        if isAI {
            statusLabel.text = "AI Player"
            statusLabel.fontColor = SKColor(red: 0.6, green: 0.6, blue: 0.8, alpha: 1.0)
        } else if isLocal {
            statusLabel.text = "You"
            statusLabel.fontColor = SKColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0)
        } else if !isConnected {
            statusLabel.text = "Disconnected"
            statusLabel.fontColor = SKColor(red: 0.8, green: 0.4, blue: 0.4, alpha: 1.0)
        } else {
            statusLabel.text = "Online"
            statusLabel.fontColor = SKColor(white: 0.5, alpha: 1.0)
        }

        hostBadge.isHidden = !isHost
        readyIndicator.isHidden = !isReady
        readyIndicator.fillColor = isReady ? .green : .gray

        background.strokeColor = playerColor.color
        colorIndicator.alpha = 1.0
    }

    func setEmpty() {
        nameLabel.text = "Waiting..."
        nameLabel.fontColor = SKColor(white: 0.4, alpha: 1.0)
        statusLabel.text = "Empty slot"
        statusLabel.fontColor = SKColor(white: 0.3, alpha: 1.0)
        hostBadge.isHidden = true
        readyIndicator.isHidden = true
        background.strokeColor = playerColor.color.withAlphaComponent(0.3)
        colorIndicator.alpha = 0.3
    }
}
