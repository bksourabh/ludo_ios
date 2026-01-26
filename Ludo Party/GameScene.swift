//
//  GameScene.swift
//  ludo_ios
//
//  Created by Sourabh Mazumder on 17/1/2026.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {

    // MARK: - Properties

    private var gameEngine: GameEngine!
    private var boardNode: BoardNode!
    private var diceNode: DiceNode!
    private var tokenNodes: [String: TokenNode] = [:]

    // UI Elements
    private var currentPlayerLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!
    private var rollButton: SKShapeNode!
    private var rollButtonLabel: SKLabelNode!
    private var menuButton: SKShapeNode!

    // Game configuration
    var gameConfig: GameConfig = GameConfig()
    weak var gameSceneDelegate: GameSceneDelegate?
    private let playerColors: [PlayerColor] = [.red, .green, .yellow, .blue]

    // Constants
    private var boardSize: CGFloat = 0
    private var tokenSize: CGFloat = 0
    private var diceSize: CGFloat = 0

    // AI timing
    private let aiGlowDelay: TimeInterval = 0.5
    private let aiMoveDelay: TimeInterval = 0.5
    private let noMovesHoldDelay: TimeInterval = 1.0

    // Deferred turn change tracking (for no valid moves case)
    private var noValidMovesOccurred: Bool = false
    private var pendingTurnPlayer: Player?

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)

        calculateSizes()
        setupBoard()
        setupDice()
        setupGameEngine() // Must be before setupTokens to create players
        setupTokens()
        setupUI()

        gameEngine.startGame()
    }

    private func calculateSizes() {
        // Calculate board size based on screen
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

    private func setupTokens() {
        // Create tokens using the GameEngine's players to ensure synchronization
        for player in gameEngine.gameState.players {
            for token in player.tokens {
                let tokenNode = TokenNode(token: token, size: tokenSize)

                // Position in yard
                let yardPositions = boardNode.getBoard().yardPositions(for: token.color)
                let position = yardPositions[token.index]

                // Adjust position relative to board node
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

        // Menu button (top-left corner)
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

        updateCurrentPlayerDisplay()
        showMessage("Tap dice to roll!")
    }

    private func setupGameEngine() {
        gameEngine = GameEngine(playerColors: playerColors, boardSize: boardSize)
        gameEngine.board.setOrigin(CGPoint(x: -boardSize/2, y: -boardSize/2))
        gameEngine.delegate = self
    }

    // MARK: - UI Updates

    private func updateCurrentPlayerDisplay() {
        let player = gameEngine.currentPlayer
        currentPlayerLabel.text = "\(player.color.name)'s Turn"
        currentPlayerLabel.fontColor = player.color.color

        diceNode.setPlayerColor(player.color)
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

    private func updateTokenPositions() {
        for player in gameEngine.gameState.players {
            for token in player.tokens {
                guard let tokenNode = tokenNodes[token.identifier] else { continue }
                let position = gameEngine.screenPosition(for: token)

                // Adjust for board offset
                tokenNode.position = CGPoint(
                    x: position.x,
                    y: position.y + size.height * 0.05
                )
            }
        }
    }

    private func highlightMovableTokens() {
        // Clear all highlights
        for (_, tokenNode) in tokenNodes {
            tokenNode.isHighlighted = false
        }

        // Highlight movable tokens
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

    private func updateTurnHighlights() {
        let currentColor = gameEngine.currentPlayer.color

        // Highlight the current player's yard
        boardNode.highlightYard(for: currentColor)

        // Highlight all tokens belonging to the current player
        for (_, tokenNode) in tokenNodes {
            tokenNode.isTurnActive = (tokenNode.token.color == currentColor)
        }
    }

    private func clearTurnHighlights() {
        boardNode.unhighlightYard()
        for (_, tokenNode) in tokenNodes {
            tokenNode.isTurnActive = false
        }
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
        // Check menu button first (always active)
        if menuButton.contains(location) {
            showPauseMenu()
            return
        }

        switch gameEngine.phase {
        case .rolling:
            handleRollingPhase(at: location)
        case .selectingToken:
            handleTokenSelection(at: location)
        case .animatingMove:
            // Ignore touches during animation
            break
        case .gameOver:
            // Check if tapped on game over overlay to restart
            if childNode(withName: "gameOverOverlay") != nil {
                restartGame()
            }
        case .waitingToStart:
            break
        }
    }

    private func showPauseMenu() {
        // Create pause overlay
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        overlay.fillColor = SKColor(white: 0, alpha: 0.7)
        overlay.strokeColor = .clear
        overlay.position = .zero
        overlay.zPosition = 200
        overlay.name = "pauseOverlay"
        addChild(overlay)

        // Pause menu container
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

        // Title
        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "PAUSED"
        titleLabel.fontSize = 28
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: 50)
        titleLabel.zPosition = 202
        addChild(titleLabel)

        // Resume button
        let resumeButton = createPauseButton(text: "Resume", yPos: 0, name: "resumeButton")
        addChild(resumeButton)

        // Main Menu button
        let mainMenuButton = createPauseButton(text: "Main Menu", yPos: -60, name: "mainMenuButton")
        addChild(mainMenuButton)
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

        if let mainMenuButton = childNode(withName: "mainMenuButton") as? SKShapeNode,
           mainMenuButton.contains(location) {
            dismissPauseMenu()
            gameSceneDelegate?.gameSceneDidRequestMainMenu()
            return
        }

        // Tap outside menu to dismiss
        if let pauseMenu = childNode(withName: "pauseMenu") as? SKShapeNode,
           !pauseMenu.contains(location) {
            dismissPauseMenu()
        }
    }

    private func dismissPauseMenu() {
        childNode(withName: "pauseOverlay")?.removeFromParent()
        childNode(withName: "pauseMenu")?.removeFromParent()
        childNode(withName: "resumeButton")?.removeFromParent()
        childNode(withName: "mainMenuButton")?.removeFromParent()
        enumerateChildNodes(withName: "//PAUSED") { node, _ in node.removeFromParent() }

        // Remove title label
        children.filter { ($0 as? SKLabelNode)?.text == "PAUSED" }.forEach { $0.removeFromParent() }
    }

    private func handleRollingPhase(at location: CGPoint) {
        // Check if dice was tapped
        let diceLocation = convert(location, to: diceNode.parent!)
        if diceNode.isPointInside(diceLocation) && diceNode.isEnabled {
            rollDice()
        }
    }

    private func handleTokenSelection(at location: CGPoint) {
        // Check if a valid token was tapped
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
        diceNode.hideGlow()

        let value = gameEngine.rollDice()

        diceNode.animateRoll(finalValue: value) { [weak self] in
            self?.afterDiceRoll(value: value)
        }
    }

    private func afterDiceRoll(value: Int) {
        // Handle deferred "no valid moves" — hold dice result for 1 second
        if let pendingPlayer = pendingTurnPlayer {
            pendingTurnPlayer = nil
            noValidMovesOccurred = false
            currentPlayerLabel.text = "No possible move"

            DispatchQueue.main.asyncAfter(deadline: .now() + noMovesHoldDelay) { [weak self] in
                self?.executeTurnChange(to: pendingPlayer)
            }
            return
        }

        if gameEngine.phase == .selectingToken {
            let movable = gameEngine.movableTokens()

            // Check if current player is AI
            if isAIPlayer(gameEngine.currentPlayer) {
                // AI selects best move
                DispatchQueue.main.asyncAfter(deadline: .now() + aiMoveDelay) { [weak self] in
                    self?.performAIMove()
                }
            } else {
                // Human player
                // Auto-play when all movable tokens are in the same state
                // (e.g. all in yard, or all at the same track position)
                let allSameState = movable.allSatisfy { $0.state == movable[0].state }

                if movable.count == 1 || allSameState {
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

    private func executeTurnChange(to player: Player) {
        updateCurrentPlayerDisplay()
        updateTurnHighlights()

        if isAIPlayer(player) {
            showMessage("\(player.color.name) is thinking...")
            checkAndPerformAITurn()
        } else {
            showMessage("Tap dice to roll!")
            diceNode.showGlow(color: player.color)
        }
    }

    private func checkAndPerformAITurn() {
        guard gameEngine.phase == .rolling else { return }
        guard isAIPlayer(gameEngine.currentPlayer) else { return }

        // Show glow for 0.5s then auto-roll
        diceNode.showGlow(color: gameEngine.currentPlayer.color)

        DispatchQueue.main.asyncAfter(deadline: .now() + aiGlowDelay) { [weak self] in
            guard let self = self else { return }
            guard self.gameEngine.phase == .rolling else { return }
            guard self.isAIPlayer(self.gameEngine.currentPlayer) else { return }

            self.rollDice()
        }
    }

    private func moveToken(_ token: Token) {
        guard let tokenNode = tokenNodes[token.identifier] else { return }

        clearHighlights()

        let previousState = token.state
        let result = gameEngine.moveToken(token)

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
            if isAIPlayer(gameEngine.currentPlayer) {
                checkAndPerformAITurn()
            } else {
                diceNode.showGlow(color: gameEngine.currentPlayer.color)
            }
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

    private func showGameOver() {
        guard let winner = gameEngine.gameState.finishOrder.first else { return }

        // Create game over overlay
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
        tapLabel.text = "Tap to play again"
        tapLabel.fontSize = 20
        tapLabel.fontColor = .white
        tapLabel.position = CGPoint(x: 0, y: -30)
        overlay.addChild(tapLabel)

        // Animate in
        overlay.alpha = 0
        overlay.setScale(0.5)
        addChild(overlay)

        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.3)
        overlay.run(SKAction.group([fadeIn, scaleUp]))
    }

    private func restartGame() {
        // Animate out game over overlay
        if let overlay = childNode(withName: "gameOverOverlay") {
            let fadeOut = SKAction.fadeOut(withDuration: 0.3)
            let scaleDown = SKAction.scale(to: 0.5, duration: 0.3)
            let remove = SKAction.removeFromParent()
            overlay.run(SKAction.sequence([SKAction.group([fadeOut, scaleDown]), remove]))
        }

        // Remove existing token nodes
        for (_, tokenNode) in tokenNodes {
            tokenNode.removeFromParent()
        }
        tokenNodes.removeAll()

        // Reset game state
        gameEngine = GameEngine(playerColors: playerColors, boardSize: boardSize)
        gameEngine.board.setOrigin(CGPoint(x: -boardSize/2, y: -boardSize/2))
        gameEngine.delegate = self

        // Recreate token nodes
        setupTokens()

        // Reset UI
        clearHighlights()
        clearTurnHighlights()
        diceNode.showValue(1)
        diceNode.hideGlow()
        diceNode.resetAppearance()

        gameEngine.startGame()
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}

// MARK: - GameEngineDelegate

extension GameScene: GameEngineDelegate {
    func gameDidStart() {
        showMessage("Game started! Roll the dice.", duration: 2)
        updateTurnHighlights()

        if isAIPlayer(gameEngine.currentPlayer) {
            checkAndPerformAITurn()
        } else {
            diceNode.showGlow(color: gameEngine.currentPlayer.color)
        }
    }

    func turnDidChange(to player: Player) {
        // If no valid moves occurred, defer the turn change until after the dice
        // animation finishes and the result is held on screen
        if noValidMovesOccurred {
            pendingTurnPlayer = player
            return
        }

        executeTurnChange(to: player)
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
        clearTurnHighlights()
        // Game over UI handled in afterTokenMove
    }

    func noValidMoves(for player: Player) {
        // Defer the message and turn change — shown after dice animation completes
        noValidMovesOccurred = true
    }

    func turnVoided(player: Player, reason: String) {
        showMessage("Three 6s! Turn voided.", duration: 2)
    }
}
