import SpriteKit
import GameplayKit
import GameKit

// MARK: - Online Game Scene Delegate

protocol OnlineGameSceneDelegate: AnyObject {
    func onlineGameSceneDidRequestMainMenu(_ scene: OnlineGameScene)
    func onlineGameSceneDidRequestRematch(_ scene: OnlineGameScene)
}

// MARK: - Online Game Scene

/// Multiplayer-aware game scene for online play
class OnlineGameScene: SKScene {

    // MARK: - Properties

    private var gameEngine: GameEngine!
    private var multiplayerController: MultiplayerGameController!
    private var matchManager: MatchManager!
    private var roomState: OnlineRoomState!

    private var boardNode: BoardNode!
    private var diceNode: DiceNode!
    private var tokenNodes: [String: TokenNode] = [:]

    // UI Elements
    private var currentPlayerLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!
    private var menuButton: SKShapeNode!
    private var waitingOverlay: SKNode?
    private var disconnectOverlay: SKNode?

    // Delegate
    weak var onlineGameDelegate: OnlineGameSceneDelegate?

    // Constants
    private var boardSize: CGFloat = 0
    private var tokenSize: CGFloat = 0
    private var diceSize: CGFloat = 0

    // AI timing
    private let aiRollDelay: TimeInterval = 0.8
    private let aiMoveDelay: TimeInterval = 0.5

    // State
    private var isAnimating: Bool = false
    private let playerColors: [PlayerColor] = [.red, .green, .yellow, .blue]

    // MARK: - Configuration

    func configure(matchManager: MatchManager, roomState: OnlineRoomState) {
        self.matchManager = matchManager
        self.roomState = roomState
    }

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)

        calculateSizes()
        setupBoard()
        setupDice()
        setupGameEngine()
        setupMultiplayerController()
        setupTokens()
        setupUI()

        gameEngine.startGame()
        updateTurnUI()
    }

    private func calculateSizes() {
        let screenMin = min(size.width, size.height)
        boardSize = screenMin * 0.85
        tokenSize = boardSize / 15 * 0.9
        diceSize = screenMin * 0.12
    }

    // MARK: - Setup Methods

    private func setupBoard() {
        boardNode = BoardNode(size: boardSize)
        boardNode.position = CGPoint(x: 0, y: size.height * 0.05)
        boardNode.zPosition = 0
        addChild(boardNode)
    }

    private func setupDice() {
        diceNode = DiceNode(size: diceSize)
        diceNode.position = CGPoint(x: 0, y: -size.height * 0.35)
        diceNode.zPosition = 100
        addChild(diceNode)
    }

    private func setupGameEngine() {
        gameEngine = GameEngine(playerColors: playerColors, boardSize: boardSize)
        gameEngine.board.setOrigin(CGPoint(x: -boardSize/2, y: -boardSize/2))
        gameEngine.delegate = self
    }

    private func setupMultiplayerController() {
        multiplayerController = MultiplayerGameController(
            gameEngine: gameEngine,
            matchManager: matchManager,
            roomState: roomState
        )
        multiplayerController.delegate = self
    }

    private func setupTokens() {
        for player in gameEngine.gameState.players {
            for token in player.tokens {
                let tokenNode = TokenNode(token: token, size: tokenSize)

                let yardPositions = boardNode.getBoard().yardPositions(for: token.color)
                let position = yardPositions[token.index]

                tokenNode.position = CGPoint(
                    x: position.x,
                    y: position.y + size.height * 0.05
                )
                tokenNode.zPosition = 50

                tokenNodes[token.identifier] = tokenNode
                addChild(tokenNode)
            }
        }
    }

    private func setupUI() {
        // Current player label
        currentPlayerLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        currentPlayerLabel.fontSize = 24
        currentPlayerLabel.position = CGPoint(x: 0, y: size.height * 0.42)
        currentPlayerLabel.zPosition = 100
        addChild(currentPlayerLabel)

        // Message label
        messageLabel = SKLabelNode(fontNamed: "Helvetica")
        messageLabel.fontSize = 18
        messageLabel.fontColor = .white
        messageLabel.position = CGPoint(x: 0, y: -size.height * 0.28)
        messageLabel.zPosition = 100
        addChild(messageLabel)

        // Menu button
        let buttonSize: CGFloat = 40
        menuButton = SKShapeNode(rectOf: CGSize(width: buttonSize, height: buttonSize), cornerRadius: 8)
        menuButton.position = CGPoint(x: -size.width/2 + 35, y: size.height/2 - 35)
        menuButton.fillColor = SKColor(white: 0.2, alpha: 0.8)
        menuButton.strokeColor = SKColor(white: 0.5, alpha: 1.0)
        menuButton.lineWidth = 1
        menuButton.zPosition = 150
        menuButton.name = "menuButton"
        addChild(menuButton)

        // Menu icon (three lines)
        let lineSpacing: CGFloat = 8
        let lineWidth: CGFloat = 18
        let lineHeight: CGFloat = 2
        for i in -1...1 {
            let line = SKShapeNode(rectOf: CGSize(width: lineWidth, height: lineHeight))
            line.position = CGPoint(x: menuButton.position.x, y: menuButton.position.y + CGFloat(i) * lineSpacing)
            line.fillColor = .white
            line.strokeColor = .clear
            line.zPosition = 151
            addChild(line)
        }
    }

    // MARK: - UI Updates

    private func updateTurnUI() {
        let player = gameEngine.currentPlayer
        currentPlayerLabel.text = "\(player.color.name)'s Turn"
        currentPlayerLabel.fontColor = player.color.color

        diceNode.setPlayerColor(player.color)

        if multiplayerController.isLocalPlayerTurn {
            hideWaitingOverlay()
            if gameEngine.phase == .rolling {
                showMessage("Tap dice to roll!")
                diceNode.showRollPrompt()
            }
        } else {
            showWaitingOverlay(for: player.color)
            checkAndPerformAITurn()
        }
    }

    private func showMessage(_ message: String, duration: TimeInterval = 0) {
        messageLabel.text = message

        if duration > 0 {
            messageLabel.removeAllActions()
            let wait = SKAction.wait(forDuration: duration)
            let clear = SKAction.run { [weak self] in
                self?.messageLabel.text = ""
            }
            messageLabel.run(SKAction.sequence([wait, clear]))
        }
    }

    private func highlightMovableTokens() {
        clearHighlights()

        let movable = gameEngine.movableTokens()
        for token in movable {
            tokenNodes[token.identifier]?.isHighlighted = true
        }
    }

    private func clearHighlights() {
        for (_, tokenNode) in tokenNodes {
            tokenNode.isHighlighted = false
        }
    }

    // MARK: - Waiting Overlay

    private func showWaitingOverlay(for playerColor: PlayerColor) {
        guard waitingOverlay == nil else { return }

        let overlay = SKNode()
        overlay.name = "waitingOverlay"
        overlay.zPosition = 300

        // Semi-transparent background for bottom area
        let bg = SKShapeNode(rectOf: CGSize(width: size.width, height: 100))
        bg.fillColor = SKColor(white: 0, alpha: 0.5)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: 0, y: -size.height * 0.35)
        overlay.addChild(bg)

        // Waiting text
        let waitingLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        waitingLabel.text = "Waiting for \(playerColor.name)..."
        waitingLabel.fontSize = 18
        waitingLabel.fontColor = playerColor.color
        waitingLabel.position = CGPoint(x: 0, y: -size.height * 0.35)
        overlay.addChild(waitingLabel)

        // Pulsing animation
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])
        waitingLabel.run(SKAction.repeatForever(pulse))

        addChild(overlay)
        waitingOverlay = overlay
    }

    private func hideWaitingOverlay() {
        waitingOverlay?.removeFromParent()
        waitingOverlay = nil
    }

    // MARK: - Disconnect Overlay

    private func showDisconnectOverlay(for playerColor: PlayerColor) {
        guard disconnectOverlay == nil else { return }

        let overlay = SKShapeNode(rectOf: CGSize(width: size.width * 0.8, height: 120), cornerRadius: 15)
        overlay.fillColor = SKColor(white: 0, alpha: 0.9)
        overlay.strokeColor = SKColor(red: 0.8, green: 0.4, blue: 0.4, alpha: 1.0)
        overlay.lineWidth = 2
        overlay.position = CGPoint(x: 0, y: 0)
        overlay.zPosition = 400
        overlay.name = "disconnectOverlay"

        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "\(playerColor.name) Disconnected"
        titleLabel.fontSize = 20
        titleLabel.fontColor = playerColor.color
        titleLabel.position = CGPoint(x: 0, y: 25)
        overlay.addChild(titleLabel)

        let subtitleLabel = SKLabelNode(fontNamed: "Helvetica")
        subtitleLabel.text = "Waiting for reconnection..."
        subtitleLabel.fontSize = 14
        subtitleLabel.fontColor = SKColor(white: 0.6, alpha: 1.0)
        subtitleLabel.position = CGPoint(x: 0, y: -5)
        overlay.addChild(subtitleLabel)

        let timerLabel = SKLabelNode(fontNamed: "Helvetica")
        timerLabel.text = "Will be replaced with AI in 30s"
        timerLabel.fontSize = 12
        timerLabel.fontColor = SKColor(white: 0.4, alpha: 1.0)
        timerLabel.position = CGPoint(x: 0, y: -30)
        overlay.addChild(timerLabel)

        addChild(overlay)
        disconnectOverlay = overlay
    }

    private func hideDisconnectOverlay() {
        disconnectOverlay?.removeFromParent()
        disconnectOverlay = nil
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check if pause menu is showing
        if childNode(withName: "pauseOverlay") != nil {
            handlePauseMenuTouch(at: location)
            return
        }

        handleTouch(at: location)
    }

    private func handleTouch(at location: CGPoint) {
        // Menu button (always active)
        if menuButton.contains(location) {
            showPauseMenu()
            return
        }

        // Only allow input during local player's turn
        guard multiplayerController.isLocalPlayerTurn else { return }
        guard !isAnimating else { return }

        switch gameEngine.phase {
        case .rolling:
            handleRollingPhase(at: location)
        case .selectingToken:
            handleTokenSelection(at: location)
        case .animatingMove, .waitingToStart, .gameOver:
            break
        }
    }

    private func handleRollingPhase(at location: CGPoint) {
        let diceLocation = convert(location, to: diceNode.parent!)
        if diceNode.isPointInside(diceLocation) && diceNode.isEnabled {
            rollDice()
        }
    }

    private func handleTokenSelection(at location: CGPoint) {
        let movable = gameEngine.movableTokens()

        for token in movable {
            guard let tokenNode = tokenNodes[token.identifier] else { continue }

            if tokenNode.isPointInside(location) {
                moveToken(token)
                return
            }
        }

        // If only one token can move, allow tapping dice to auto-move it
        if movable.count == 1 {
            let diceLocation = convert(location, to: diceNode.parent!)
            if diceNode.isPointInside(diceLocation) {
                moveToken(movable[0])
            }
        }
    }

    // MARK: - Game Actions

    private func rollDice() {
        guard multiplayerController.isLocalPlayerTurn else { return }

        diceNode.hideRollPrompt()
        let value = multiplayerController.localPlayerRollDice()

        diceNode.animateRoll(finalValue: value) { [weak self] in
            self?.afterDiceRoll(value: value)
        }
    }

    private func afterDiceRoll(value: Int) {
        if gameEngine.phase == .selectingToken {
            let movable = gameEngine.movableTokens()

            if movable.count == 1 {
                showMessage("Moving...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.moveToken(movable[0])
                }
            } else if movable.count > 1 {
                highlightMovableTokens()
                showMessage("Select a token to move")
            }
        }
    }

    private func moveToken(_ token: Token) {
        guard multiplayerController.isLocalPlayerTurn else { return }
        guard let tokenNode = tokenNodes[token.identifier] else { return }

        clearHighlights()
        isAnimating = true

        let previousState = token.state
        let result = multiplayerController.localPlayerMoveToken(token)

        // Get new position
        let newPosition = gameEngine.screenPosition(for: token)
        let adjustedPosition = CGPoint(
            x: newPosition.x,
            y: newPosition.y + size.height * 0.05
        )

        // Animate the move
        tokenNode.animateMove(to: adjustedPosition) { [weak self] in
            self?.afterTokenMove(token: token, result: result, previousState: previousState)
        }
    }

    private func afterTokenMove(token: Token, result: MoveResult, previousState: TokenState) {
        isAnimating = false

        switch result {
        case .reachedHome:
            tokenNodes[token.identifier]?.animateReachHome()
        case .capturedOpponent(let captured):
            animateCapturedToken(captured)
        default:
            break
        }

        // Check game phase after move
        if gameEngine.phase == .rolling {
            updateTurnUI()
        } else if gameEngine.phase == .gameOver {
            showGameOver()
        }
    }

    private func animateCapturedToken(_ token: Token) {
        guard let tokenNode = tokenNodes[token.identifier] else { return }

        let yardPositions = gameEngine.board.yardPositions(for: token.color)
        let yardPosition = yardPositions[token.index]
        let adjustedPosition = CGPoint(
            x: yardPosition.x,
            y: yardPosition.y + size.height * 0.05
        )

        tokenNode.animateCapture(to: adjustedPosition)
    }

    // MARK: - AI Turn

    private func checkAndPerformAITurn() {
        guard multiplayerController.isHost else { return }
        guard !multiplayerController.isLocalPlayerTurn else { return }

        let currentColor = gameEngine.currentPlayer.color
        guard let onlinePlayer = roomState.player(for: currentColor), onlinePlayer.isAI else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + aiRollDelay) { [weak self] in
            guard let self = self else { return }
            guard self.gameEngine.phase == .rolling else { return }
            guard self.gameEngine.currentPlayer.color == currentColor else { return }

            self.performAITurn(for: currentColor)
        }
    }

    private func performAITurn(for color: PlayerColor) {
        // Roll dice
        let value = gameEngine.rollDice()

        diceNode.animateRoll(finalValue: value) { [weak self] in
            guard let self = self else { return }

            if self.gameEngine.phase == .selectingToken {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.aiMoveDelay) {
                    self.performAIMove(for: color)
                }
            } else {
                self.updateTurnUI()
            }
        }

        // Broadcast dice roll
        multiplayerController.performAITurn(for: color)
    }

    private func performAIMove(for color: PlayerColor) {
        guard let bestToken = gameEngine.suggestBestMove() else { return }
        guard let tokenNode = tokenNodes[bestToken.identifier] else { return }

        let previousState = bestToken.state
        let result = gameEngine.moveToken(bestToken)

        let newPosition = gameEngine.screenPosition(for: bestToken)
        let adjustedPosition = CGPoint(
            x: newPosition.x,
            y: newPosition.y + size.height * 0.05
        )

        tokenNode.animateMove(to: adjustedPosition) { [weak self] in
            self?.afterTokenMove(token: bestToken, result: result, previousState: previousState)
        }
    }

    // MARK: - Pause Menu

    private func showPauseMenu() {
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.fillColor = SKColor(white: 0, alpha: 0.7)
        overlay.strokeColor = .clear
        overlay.position = .zero
        overlay.zPosition = 200
        overlay.name = "pauseOverlay"
        addChild(overlay)

        let menuWidth = size.width * 0.7
        let menuHeight: CGFloat = 200
        let menuBg = SKShapeNode(rectOf: CGSize(width: menuWidth, height: menuHeight), cornerRadius: 15)
        menuBg.fillColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
        menuBg.strokeColor = .white
        menuBg.lineWidth = 2
        menuBg.position = .zero
        menuBg.zPosition = 201
        menuBg.name = "pauseMenu"
        addChild(menuBg)

        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "PAUSED"
        titleLabel.fontSize = 28
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 50)
        titleLabel.zPosition = 202
        addChild(titleLabel)

        let resumeButton = createPauseButton(text: "Resume", yPos: 0, name: "resumeButton")
        addChild(resumeButton)

        let leaveButton = createPauseButton(text: "Leave Game", yPos: -60, name: "leaveButton")
        addChild(leaveButton)
    }

    private func createPauseButton(text: String, yPos: CGFloat, name: String) -> SKShapeNode {
        let buttonWidth = size.width * 0.5
        let buttonHeight: CGFloat = 44

        let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 10)
        button.position = CGPoint(x: 0, y: yPos)
        button.fillColor = SKColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0)
        button.strokeColor = SKColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1.0)
        button.lineWidth = 2
        button.zPosition = 202
        button.name = name

        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.text = text
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = .zero
        button.addChild(label)

        return button
    }

    private func handlePauseMenuTouch(at location: CGPoint) {
        if let resumeButton = childNode(withName: "resumeButton") as? SKShapeNode,
           resumeButton.contains(location) {
            dismissPauseMenu()
            return
        }

        if let leaveButton = childNode(withName: "leaveButton") as? SKShapeNode,
           leaveButton.contains(location) {
            dismissPauseMenu()
            multiplayerController.cleanup()
            onlineGameDelegate?.onlineGameSceneDidRequestMainMenu(self)
            return
        }

        if let pauseMenu = childNode(withName: "pauseMenu") as? SKShapeNode,
           !pauseMenu.contains(location) {
            dismissPauseMenu()
        }
    }

    private func dismissPauseMenu() {
        childNode(withName: "pauseOverlay")?.removeFromParent()
        childNode(withName: "pauseMenu")?.removeFromParent()
        childNode(withName: "resumeButton")?.removeFromParent()
        childNode(withName: "leaveButton")?.removeFromParent()
        children.filter { ($0 as? SKLabelNode)?.text == "PAUSED" }.forEach { $0.removeFromParent() }
    }

    // MARK: - Game Over

    private func showGameOver() {
        guard let winner = gameEngine.gameState.finishOrder.first else { return }

        let overlay = SKShapeNode(rectOf: CGSize(width: size.width * 0.8, height: size.height * 0.3), cornerRadius: 20)
        overlay.fillColor = SKColor(white: 0, alpha: 0.85)
        overlay.strokeColor = winner.color
        overlay.lineWidth = 4
        overlay.position = CGPoint(x: 0, y: 0)
        overlay.zPosition = 200
        overlay.name = "gameOverOverlay"

        let winnerLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        winnerLabel.text = "\(winner.name) Wins!"
        winnerLabel.fontSize = 36
        winnerLabel.fontColor = winner.color
        winnerLabel.position = CGPoint(x: 0, y: 30)
        overlay.addChild(winnerLabel)

        let tapLabel = SKLabelNode(fontNamed: "Helvetica")
        tapLabel.text = "Tap to return to menu"
        tapLabel.fontSize = 20
        tapLabel.fontColor = .white
        tapLabel.position = CGPoint(x: 0, y: -30)
        overlay.addChild(tapLabel)

        overlay.alpha = 0
        overlay.setScale(0.5)
        addChild(overlay)

        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        overlay.run(SKAction.group([fadeIn, scaleUp]))
    }

    // MARK: - Token Position Update

    private func updateTokenPosition(_ token: Token, animated: Bool = true) {
        guard let tokenNode = tokenNodes[token.identifier] else { return }

        let newPosition = gameEngine.screenPosition(for: token)
        let adjustedPosition = CGPoint(
            x: newPosition.x,
            y: newPosition.y + size.height * 0.05
        )

        if animated {
            tokenNode.animateMove(to: adjustedPosition, completion: nil)
        } else {
            tokenNode.position = adjustedPosition
        }
    }

    private func updateAllTokenPositions() {
        for player in gameEngine.gameState.players {
            for token in player.tokens {
                updateTokenPosition(token, animated: false)
            }
        }
    }
}

// MARK: - GameEngineDelegate

extension OnlineGameScene: GameEngineDelegate {
    func gameDidStart() {
        showMessage("Game started!", duration: 2)
    }

    func turnDidChange(to player: Player) {
        updateTurnUI()
    }

    func diceDidRoll(value: Int) {
        // Handled by animation callback
    }

    func tokenDidMove(token: Token, from: TokenState, to: TokenState) {
        // Animation handled separately
    }

    func tokenDidGetCaptured(token: Token, by: Token) {
        showMessage("\(by.color.name) captured \(token.color.name)!", duration: 2)
    }

    func playerDidGetBonusRoll(player: Player, reason: BonusRollReason) {
        var message = ""
        switch reason {
        case .rolledSix:
            message = "Rolled 6! Roll again!"
        case .capturedToken:
            message = "Capture! Bonus roll!"
        case .reachedHome:
            message = "Home! Bonus roll!"
        }
        showMessage(message, duration: 1.5)
    }

    func playerDidFinish(player: Player, place: Int) {
        let ordinal: String
        switch place {
        case 1: ordinal = "1st"
        case 2: ordinal = "2nd"
        case 3: ordinal = "3rd"
        default: ordinal = "\(place)th"
        }
        showMessage("\(player.color.name) finished \(ordinal)!", duration: 2)
    }

    func gameDidEnd(winner: Player) {
        showMessage("")
    }

    func noValidMoves(for player: Player) {
        showMessage("No valid moves. Turn skipped.", duration: 1.5)
    }

    func turnVoided(player: Player, reason: String) {
        showMessage("Three 6s! Turn voided.", duration: 2)
    }
}

// MARK: - MultiplayerGameControllerDelegate

extension OnlineGameScene: MultiplayerGameControllerDelegate {
    func multiplayerController(_ controller: MultiplayerGameController, didRollDice value: Int, for color: PlayerColor) {
        // Remote player rolled dice - animate it
        if !roomState.isLocalPlayerColor(color) {
            diceNode.animateRoll(finalValue: value) { [weak self] in
                guard let self = self else { return }
                if self.gameEngine.phase == .selectingToken {
                    // Wait for token move
                }
            }
        }
    }

    func multiplayerController(_ controller: MultiplayerGameController, didMoveToken token: Token, from: TokenState, to: TokenState, result: MoveResult) {
        // Remote player moved token - animate it
        if !roomState.isLocalPlayerColor(token.color) {
            guard let tokenNode = tokenNodes[token.identifier] else { return }

            let newPosition = gameEngine.screenPosition(for: token)
            let adjustedPosition = CGPoint(
                x: newPosition.x,
                y: newPosition.y + size.height * 0.05
            )

            tokenNode.animateMove(to: adjustedPosition) { [weak self] in
                guard let self = self else { return }

                switch result {
                case .reachedHome:
                    tokenNode.animateReachHome()
                case .capturedOpponent(let captured):
                    self.animateCapturedToken(captured)
                default:
                    break
                }

                self.updateTurnUI()
            }
        }
    }

    func multiplayerController(_ controller: MultiplayerGameController, didChangeTurn to: PlayerColor) {
        updateTurnUI()
    }

    func multiplayerController(_ controller: MultiplayerGameController, playerDidDisconnect color: PlayerColor) {
        showDisconnectOverlay(for: color)
    }

    func multiplayerController(_ controller: MultiplayerGameController, playerReplacedWithAI color: PlayerColor) {
        hideDisconnectOverlay()
        showMessage("\(color.name) replaced with AI", duration: 2)

        // If it's AI's turn, perform AI move
        if gameEngine.currentPlayer.color == color {
            checkAndPerformAITurn()
        }
    }

    func multiplayerController(_ controller: MultiplayerGameController, didReceiveStateSync state: FullStateSyncPayload) {
        updateAllTokenPositions()
        updateTurnUI()
    }

    func multiplayerControllerGameDidEnd(_ controller: MultiplayerGameController) {
        showGameOver()
    }

    func multiplayerController(_ controller: MultiplayerGameController, didEncounterError error: Error) {
        showMessage("Network error: \(error.localizedDescription)", duration: 3)
    }
}
