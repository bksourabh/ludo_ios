import SceneKit
import SpriteKit

/// 3D Ludo game scene using SceneKit with camera rotation for active player view
class GameScene3D: SCNScene {

    // MARK: - Properties

    private var gameEngine: GameEngine!
    private var board3D: Board3DNode!
    private var dice3D: Dice3DNode!
    private var token3DNodes: [String: Token3DNode] = [:]

    // Camera system
    private var cameraNode: SCNNode!
    private var cameraOrbit: SCNNode!
    private var currentCameraAngle: Float = 0

    // Camera angles for each player color (radians)
    private let playerCameraAngles: [PlayerColor: Float] = [
        .red: 0,                    // Red at bottom, camera facing down
        .green: Float.pi / 2,       // Green on right, camera rotated 90°
        .yellow: Float.pi,          // Yellow at top, camera rotated 180°
        .blue: Float.pi * 1.5       // Blue on left, camera rotated 270°
    ]

    // UI overlay (using SpriteKit for 2D UI)
    private var overlayScene: SKScene!
    private var currentPlayerLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!
    private var menuButton: SKShapeNode!

    // Game configuration
    var gameConfig: GameConfig = GameConfig()
    weak var game3DDelegate: Game3DSceneDelegate?
    private let playerColors: [PlayerColor] = [.red, .green, .yellow, .blue]

    // Board dimensions
    private let boardScale: Float = 1.0

    // AI timing
    private let aiRollDelay: TimeInterval = 0.8
    private let aiMoveDelay: TimeInterval = 0.5

    // Track view size for positioning
    var viewSize: CGSize = .zero

    // MARK: - Initialization

    override init() {
        super.init()
        setupScene()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewSize: CGSize, config: GameConfig) {
        self.viewSize = viewSize
        self.gameConfig = config

        setupGameEngine()
        setupTokens()
        setupOverlayUI()

        gameEngine.startGame()
    }

    // MARK: - Scene Setup

    private func setupScene() {
        // Background color
        background.contents = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)

        // Setup lighting
        setupLighting()

        // Setup camera
        setupCamera()

        // Setup board
        setupBoard()

        // Setup dice
        setupDice()
    }

    private func setupLighting() {
        // Ambient light for overall illumination
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor(white: 0.4, alpha: 1.0)
        ambientLight.light?.intensity = 500
        rootNode.addChildNode(ambientLight)

        // Main directional light (sun-like)
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.color = UIColor.white
        directionalLight.light?.intensity = 800
        directionalLight.light?.castsShadow = true
        directionalLight.light?.shadowMode = .deferred
        directionalLight.light?.shadowColor = UIColor.black.withAlphaComponent(0.5)
        directionalLight.light?.shadowRadius = 5
        directionalLight.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        rootNode.addChildNode(directionalLight)

        // Fill light from opposite side
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.color = UIColor(white: 0.8, alpha: 1.0)
        fillLight.light?.intensity = 300
        fillLight.eulerAngles = SCNVector3(-Float.pi / 4, -Float.pi / 3, 0)
        rootNode.addChildNode(fillLight)
    }

    private func setupCamera() {
        // Camera orbit node (for rotating around the board)
        cameraOrbit = SCNNode()
        cameraOrbit.position = SCNVector3(0, 0, 0)
        rootNode.addChildNode(cameraOrbit)

        // Camera node
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 45
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100

        // Position camera above and behind, looking at center
        cameraNode.position = SCNVector3(0, 8, 8)
        cameraNode.eulerAngles.x = -Float.pi / 4  // Look down at board

        cameraOrbit.addChildNode(cameraNode)
    }

    private func setupBoard() {
        board3D = Board3DNode()
        board3D.scale = SCNVector3(boardScale, boardScale, boardScale)
        rootNode.addChildNode(board3D)
    }

    private func setupDice() {
        dice3D = Dice3DNode()
        dice3D.position = SCNVector3(0, 0.2, 3.5) // In front of camera
        rootNode.addChildNode(dice3D)
    }

    private func setupGameEngine() {
        // Board size for position calculations (matches Board3DNode cell size)
        let boardSize: CGFloat = 7.0 * 0.5 // 7 cells * 0.5 units per cell

        gameEngine = GameEngine(playerColors: playerColors, boardSize: boardSize)
        gameEngine.delegate = self
    }

    private func setupTokens() {
        guard let board = board3D else {
            print("Error: board3D not initialized")
            return
        }

        for player in gameEngine.gameState.players {
            for token in player.tokens {
                let token3D = Token3DNode(color: token.color, index: token.index)

                // Get yard position from board
                let yardPos = board.yardPosition(for: token.color, index: token.index)
                token3D.position = yardPos

                token3DNodes[token.identifier] = token3D
                rootNode.addChildNode(token3D)
            }
        }
    }

    private func setupOverlayUI() {
        guard viewSize != .zero else { return }

        // Create SpriteKit overlay for 2D UI elements
        overlayScene = SKScene(size: viewSize)
        overlayScene.backgroundColor = .clear
        overlayScene.scaleMode = .resizeFill

        // Current player label
        currentPlayerLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        currentPlayerLabel.fontSize = 24
        currentPlayerLabel.position = CGPoint(x: viewSize.width / 2, y: viewSize.height - 60)
        currentPlayerLabel.zPosition = 100
        overlayScene.addChild(currentPlayerLabel)

        // Message label
        messageLabel = SKLabelNode(fontNamed: "Helvetica")
        messageLabel.fontSize = 18
        messageLabel.fontColor = .white
        messageLabel.position = CGPoint(x: viewSize.width / 2, y: 80)
        messageLabel.zPosition = 100
        overlayScene.addChild(messageLabel)

        // Menu button
        let buttonSize: CGFloat = 40
        menuButton = SKShapeNode(rectOf: CGSize(width: buttonSize, height: buttonSize), cornerRadius: 8)
        menuButton.position = CGPoint(x: 35, y: viewSize.height - 35)
        menuButton.fillColor = SKColor(white: 0.2, alpha: 0.8)
        menuButton.strokeColor = SKColor(white: 0.5, alpha: 1.0)
        menuButton.lineWidth = 1
        menuButton.zPosition = 150
        menuButton.name = "menuButton"
        overlayScene.addChild(menuButton)

        // Menu icon (three lines)
        let lineSpacing: CGFloat = 8
        let lineWidth: CGFloat = 18
        let lineHeight: CGFloat = 2
        for i in -1...1 {
            let line = SKShapeNode(rectOf: CGSize(width: lineWidth, height: lineHeight))
            line.position = CGPoint(x: 35, y: viewSize.height - 35 + CGFloat(i) * lineSpacing)
            line.fillColor = .white
            line.strokeColor = .clear
            line.zPosition = 151
            overlayScene.addChild(line)
        }

        updateCurrentPlayerDisplay()
        showMessage("Tap dice to roll!")
    }

    func getOverlayScene() -> SKScene? {
        return overlayScene
    }

    /// Get the camera node for setting as pointOfView
    func getCameraNode() -> SCNNode? {
        return cameraNode
    }

    // MARK: - Camera Control

    /// Rotate camera to face the current player's perspective
    func rotateCameraToPlayer(_ color: PlayerColor, animated: Bool = true) {
        guard let targetAngle = playerCameraAngles[color] else { return }

        if animated {
            // Calculate shortest rotation path
            var angleDiff = targetAngle - currentCameraAngle

            // Normalize to -π to π
            while angleDiff > Float.pi { angleDiff -= Float.pi * 2 }
            while angleDiff < -Float.pi { angleDiff += Float.pi * 2 }

            let finalAngle = currentCameraAngle + angleDiff

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.8
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            cameraOrbit.eulerAngles.y = finalAngle

            SCNTransaction.commit()

            currentCameraAngle = finalAngle
        } else {
            cameraOrbit.eulerAngles.y = targetAngle
            currentCameraAngle = targetAngle
        }
    }

    // MARK: - UI Updates

    private func updateCurrentPlayerDisplay() {
        let player = gameEngine.currentPlayer
        currentPlayerLabel?.text = "\(player.color.name)'s Turn"
        currentPlayerLabel?.fontColor = player.color.color

        dice3D?.setPlayerColor(player.color)
    }

    func showMessage(_ message: String, duration: TimeInterval = 0) {
        messageLabel?.text = message

        if duration > 0 {
            messageLabel?.removeAllActions()
            let wait = SKAction.wait(forDuration: duration)
            let clear = SKAction.run { [weak self] in
                self?.messageLabel?.text = ""
            }
            messageLabel?.run(SKAction.sequence([wait, clear]))
        }
    }

    private func highlightMovableTokens() {
        // Clear all highlights
        for (_, token3D) in token3DNodes {
            token3D.setSelected(false, animated: false)
        }

        // Highlight movable tokens
        let movable = gameEngine.movableTokens()
        for token in movable {
            token3DNodes[token.identifier]?.setSelected(true, animated: true)
        }
    }

    private func clearHighlights() {
        for (_, token3D) in token3DNodes {
            token3D.setSelected(false, animated: true)
        }
    }

    // MARK: - Touch Handling

    func handleTap(at point: CGPoint, in view: SCNView) {
        // Check overlay UI first
        if let overlayScene = overlayScene {
            let overlayPoint = CGPoint(x: point.x, y: viewSize.height - point.y)

            if let menuButton = menuButton, menuButton.contains(overlayPoint) {
                showPauseMenu()
                return
            }

            // Check pause menu buttons
            if let resumeButton = overlayScene.childNode(withName: "resumeButton") as? SKShapeNode,
               resumeButton.contains(overlayPoint) {
                dismissPauseMenu()
                return
            }

            if let mainMenuButton = overlayScene.childNode(withName: "mainMenuButton") as? SKShapeNode,
               mainMenuButton.contains(overlayPoint) {
                dismissPauseMenu()
                game3DDelegate?.game3DSceneDidRequestMainMenu()
                return
            }
        }

        // Check game phase
        switch gameEngine.phase {
        case .rolling:
            handleRollingPhase(at: point, in: view)
        case .selectingToken:
            handleTokenSelection(at: point, in: view)
        case .animatingMove:
            break
        case .gameOver:
            if overlayScene?.childNode(withName: "gameOverOverlay") != nil {
                restartGame()
            }
        case .waitingToStart:
            break
        }
    }

    private func handleRollingPhase(at point: CGPoint, in view: SCNView) {
        let hitResults = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])

        for result in hitResults {
            if result.node.name == "dice" || result.node.parent?.name == "dice" {
                if dice3D.isEnabled {
                    rollDice()
                    return
                }
            }
        }
    }

    private func handleTokenSelection(at point: CGPoint, in view: SCNView) {
        let hitResults = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
        let movable = gameEngine.movableTokens()

        for result in hitResults {
            // Check if hit a token
            var node: SCNNode? = result.node
            while node != nil {
                if let token3D = node as? Token3DNode {
                    // Find the corresponding Token
                    for token in movable {
                        if token.color == token3D.tokenColor && token.index == token3D.tokenIndex {
                            moveToken(token)
                            return
                        }
                    }
                }
                node = node?.parent
            }
        }

        // If only one token can move, allow tapping dice to auto-move it
        if movable.count == 1 {
            for result in hitResults {
                if result.node.name == "dice" || result.node.parent?.name == "dice" {
                    moveToken(movable[0])
                    return
                }
            }
        }
    }

    // MARK: - Pause Menu

    private func showPauseMenu() {
        guard let overlayScene = overlayScene else { return }

        let overlay = SKShapeNode(rectOf: viewSize)
        overlay.fillColor = SKColor(white: 0, alpha: 0.7)
        overlay.strokeColor = .clear
        overlay.position = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        overlay.zPosition = 200
        overlay.name = "pauseOverlay"
        overlayScene.addChild(overlay)

        let menuWidth = viewSize.width * 0.7
        let menuHeight: CGFloat = 200
        let menuBg = SKShapeNode(rectOf: CGSize(width: menuWidth, height: menuHeight), cornerRadius: 15)
        menuBg.fillColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
        menuBg.strokeColor = .white
        menuBg.lineWidth = 2
        menuBg.position = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        menuBg.zPosition = 201
        menuBg.name = "pauseMenu"
        overlayScene.addChild(menuBg)

        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "PAUSED"
        titleLabel.fontSize = 28
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2 + 50)
        titleLabel.zPosition = 202
        overlayScene.addChild(titleLabel)

        overlayScene.addChild(createPauseButton(text: "Resume", yPos: viewSize.height / 2, name: "resumeButton"))
        overlayScene.addChild(createPauseButton(text: "Main Menu", yPos: viewSize.height / 2 - 60, name: "mainMenuButton"))
    }

    private func createPauseButton(text: String, yPos: CGFloat, name: String) -> SKShapeNode {
        let buttonWidth = viewSize.width * 0.5
        let buttonHeight: CGFloat = 44

        let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 10)
        button.position = CGPoint(x: viewSize.width / 2, y: yPos)
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
        button.addChild(label)

        return button
    }

    private func dismissPauseMenu() {
        guard let overlayScene = overlayScene else { return }

        overlayScene.childNode(withName: "pauseOverlay")?.removeFromParent()
        overlayScene.childNode(withName: "pauseMenu")?.removeFromParent()
        overlayScene.childNode(withName: "resumeButton")?.removeFromParent()
        overlayScene.childNode(withName: "mainMenuButton")?.removeFromParent()
        overlayScene.children.filter { ($0 as? SKLabelNode)?.text == "PAUSED" }.forEach { $0.removeFromParent() }
    }

    // MARK: - Game Actions

    private func rollDice() {
        dice3D.hideRollPrompt()

        let value = gameEngine.rollDice()

        dice3D.roll(finalValue: value) { [weak self] in
            self?.afterDiceRoll(value: value)
        }
    }

    private func afterDiceRoll(value: Int) {
        if gameEngine.phase == .selectingToken {
            let movable = gameEngine.movableTokens()

            if isAIPlayer(gameEngine.currentPlayer) {
                DispatchQueue.main.asyncAfter(deadline: .now() + aiMoveDelay) { [weak self] in
                    self?.performAIMove()
                }
            } else {
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
    }

    private func isAIPlayer(_ player: Player) -> Bool {
        return !gameConfig.isHuman(player.color)
    }

    private func performAIMove() {
        guard let bestToken = gameEngine.suggestBestMove() else { return }
        moveToken(bestToken)
    }

    private func checkAndPerformAITurn() {
        guard gameEngine.phase == .rolling else { return }
        guard isAIPlayer(gameEngine.currentPlayer) else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + aiRollDelay) { [weak self] in
            guard let self = self else { return }
            guard self.gameEngine.phase == .rolling else { return }
            guard self.isAIPlayer(self.gameEngine.currentPlayer) else { return }

            self.rollDice()
        }
    }

    private func moveToken(_ token: Token) {
        guard let token3D = token3DNodes[token.identifier] else { return }

        clearHighlights()

        let previousState = token.state
        let result = gameEngine.moveToken(token)

        // Get new 3D position
        let newPosition = position3D(for: token)

        // Animate the move
        token3D.moveToPosition(newPosition, duration: 0.5) { [weak self] in
            self?.afterTokenMove(token: token, result: result, previousState: previousState)
        }
    }

    private func position3D(for token: Token) -> SCNVector3 {
        switch token.state {
        case .inYard:
            return board3D.yardPosition(for: token.color, index: token.index)
        case .onTrack(let position):
            return board3D.trackPosition(at: position)
        case .onHomePath(let position):
            return board3D.homePathPosition(for: token.color, at: position)
        case .home:
            return board3D.homePosition(for: token.color, index: token.index)
        }
    }

    private func afterTokenMove(token: Token, result: MoveResult, previousState: TokenState) {
        switch result {
        case .reachedHome:
            token3DNodes[token.identifier]?.animateReachHome()
        case .capturedOpponent(let captured):
            animateCapturedToken(captured)
        default:
            break
        }

        if gameEngine.phase == .rolling {
            if isAIPlayer(gameEngine.currentPlayer) {
                checkAndPerformAITurn()
            } else {
                dice3D.showRollPrompt()
            }
        } else if gameEngine.phase == .gameOver {
            showGameOver()
        }
    }

    private func animateCapturedToken(_ token: Token) {
        guard let token3D = token3DNodes[token.identifier] else { return }

        let yardPosition = board3D.yardPosition(for: token.color, index: token.index)
        token3D.animateCaptured(yardPosition: yardPosition)
    }

    private func showGameOver() {
        guard let winner = gameEngine.gameState.finishOrder.first,
              let overlayScene = overlayScene else { return }

        let overlay = SKShapeNode(rectOf: CGSize(width: viewSize.width * 0.8, height: viewSize.height * 0.3), cornerRadius: 20)
        overlay.fillColor = SKColor(white: 0, alpha: 0.85)
        overlay.strokeColor = winner.color
        overlay.lineWidth = 4
        overlay.position = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        overlay.zPosition = 200
        overlay.name = "gameOverOverlay"

        let winnerLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        winnerLabel.text = "\(winner.name) Wins!"
        winnerLabel.fontSize = 36
        winnerLabel.fontColor = winner.color
        winnerLabel.position = CGPoint(x: 0, y: 30)
        overlay.addChild(winnerLabel)

        let tapLabel = SKLabelNode(fontNamed: "Helvetica")
        tapLabel.text = "Tap to play again"
        tapLabel.fontSize = 20
        tapLabel.fontColor = .white
        tapLabel.position = CGPoint(x: 0, y: -30)
        overlay.addChild(tapLabel)

        overlay.alpha = 0
        overlay.setScale(0.5)
        overlayScene.addChild(overlay)

        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        overlay.run(SKAction.group([fadeIn, scaleUp]))
    }

    private func restartGame() {
        guard let overlayScene = overlayScene else { return }

        // Remove game over overlay
        if let overlay = overlayScene.childNode(withName: "gameOverOverlay") {
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let scaleDown = SKAction.scale(to: 0.5, duration: 0.3)
            let remove = SKAction.removeFromParent()
            overlay.run(SKAction.sequence([SKAction.group([fadeOut, scaleDown]), remove]))
        }

        // Remove existing token nodes
        for (_, token3D) in token3DNodes {
            token3D.removeFromParentNode()
        }
        token3DNodes.removeAll()

        // Reset game state
        let boardSize: CGFloat = 7.0 * 0.5
        gameEngine = GameEngine(playerColors: playerColors, boardSize: boardSize)
        gameEngine.delegate = self

        // Recreate tokens
        setupTokens()

        // Reset UI
        clearHighlights()
        dice3D.showValue(1)
        dice3D.resetAppearance()

        // Reset camera
        rotateCameraToPlayer(.red, animated: false)

        gameEngine.startGame()
    }
}

// MARK: - GameEngineDelegate

extension GameScene3D: GameEngineDelegate {
    func gameDidStart() {
        showMessage("Game started! Roll the dice.", duration: 2)
        dice3D.showRollPrompt()
        rotateCameraToPlayer(gameEngine.currentPlayer.color, animated: false)
    }

    func turnDidChange(to player: Player) {
        updateCurrentPlayerDisplay()
        rotateCameraToPlayer(player.color, animated: true)

        if isAIPlayer(player) {
            showMessage("\(player.color.name) is thinking...")
            checkAndPerformAITurn()
        } else {
            showMessage("Tap dice to roll!")
            dice3D.showRollPrompt()
        }
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
        if isAIPlayer(player) {
            showMessage("\(player.color.name) has no valid moves.", duration: 1.0)
        } else {
            showMessage("No valid moves. Turn skipped.", duration: 1.5)
        }
    }

    func turnVoided(player: Player, reason: String) {
        showMessage("Three 6s! Turn voided.", duration: 2)
    }
}

// MARK: - Game3DSceneDelegate

protocol Game3DSceneDelegate: AnyObject {
    func game3DSceneDidRequestMainMenu()
}
