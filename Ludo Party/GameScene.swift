//
//  GameScene.swift
//  ludo_ios
//
//  Created by Sourabh Mazumder on 17/1/2026.
//

import UIKit
import SpriteKit
import GameplayKit

class GameScene: SKScene {

    // MARK: - Properties

    private var gameEngine: GameEngine!
    private var boardNode: BoardNode!
    private var diceNode: DiceNode!
    private var tokenNodes: [String: TokenNode] = [:]
    private var stackedTokenNodes: [Int: StackedTokenNode] = [:] // Key is track position

    // UI Elements
    private var currentPlayerLabel: SKLabelNode!
    private var messageLabel: SKLabelNode!
    private var rollButton: SKShapeNode!
    private var rollButtonLabel: SKLabelNode!
    private var menuButton: SKShapeNode!

    // Game configuration
    var gameConfig: GameConfig = GameConfig()
    var savedGameState: GameState?  // For loading saved games
    weak var gameSceneDelegate: GameSceneDelegate?
    private let playerColors: [PlayerColor] = [.red, .green, .yellow, .blue]

    // Constants
    private var boardSize: CGFloat = 0
    private var tokenSize: CGFloat = 0
    private var diceSize: CGFloat = 0

    // AI timing
    private let aiGlowDelay: TimeInterval = 0.6
    private let aiMoveDelay: TimeInterval = 0.6
    private let noMovesHoldDelay: TimeInterval = 0.8

    // Deferred turn change tracking
    // diceAnimationInProgress captures ALL cases where turnDidChange fires during animation:
    //   - noValidMoves (no moves possible → skip turn)
    //   - turnVoided   (three 6s → skip turn)
    // The flag is set BEFORE gameEngine.rollDice() so synchronous delegate callbacks are caught.
    private var diceAnimationInProgress: Bool = false
    private var noValidMovesOccurred: Bool = false   // set for "no moves" flavour of deferral
    private var pendingTurnPlayer: Player?

    // AI turn tracking to prevent overlapping turns
    private var isAITurnInProgress: Bool = false

    // Haptic feedback generators
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback  = UIImpactFeedbackGenerator(style: .heavy)
    private let notifyFeedback = UINotificationFeedbackGenerator()

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 1.0)

        calculateSizes()
        setupBoard()
        setupDice()
        setupGameEngine() // Must be before setupTokens to create players
        setupTokens()
        setupUI()

        // Prepare haptic engines so first call has no latency
        impactFeedback.prepare()
        heavyFeedback.prepare()
        notifyFeedback.prepare()

        // Stop menu music when game starts
        MusicManager.shared.stopBackgroundMusic()

        // Set initial dice position and color without animation
        let startingColor = gameEngine.currentPlayer.color
        diceNode.position = dicePosition(for: startingColor)
        diceNode.setFullPlayerColor(startingColor)

        gameEngine.startGame()
    }

    private func calculateSizes() {
        // Calculate board size based on screen
        let screenMin = min(size.width, size.height)
        boardSize = screenMin * 0.95
        tokenSize = boardSize / 15 * 1.0
        diceSize = screenMin * 0.12
    }

    // MARK: - Setup Methods

    private func setupBoard() {
        boardNode = BoardNode(size: boardSize, gameConfig: gameConfig)
        boardNode.position = CGPoint(x: 0, y: 0)  // Center the board
        boardNode.zPosition = 0
        addChild(boardNode)
    }

    private func setupDice() {
        diceNode = DiceNode(size: diceSize)
        diceNode.position = CGPoint(x: 0, y: -size.height * 0.35)
        diceNode.zPosition = 100
        addChild(diceNode)
    }

    /// Calculate dice position based on current player's color
    /// Positions dice above or below the player's yard
    private func dicePosition(for color: PlayerColor) -> CGPoint {
        let boardY: CGFloat = 0  // Board is centered
        let halfBoard = boardSize / 2
        let verticalOffset = diceSize * 0.8

        switch color {
        case .red:
            // Red is bottom-left - position dice below the yard
            return CGPoint(
                x: -halfBoard + boardSize * 0.2,
                y: boardY - halfBoard - verticalOffset
            )
        case .green:
            // Green is top-left - position dice above the yard
            return CGPoint(
                x: -halfBoard + boardSize * 0.2,
                y: boardY + halfBoard + verticalOffset
            )
        case .yellow:
            // Yellow is top-right - position dice above the yard
            return CGPoint(
                x: halfBoard - boardSize * 0.2,
                y: boardY + halfBoard + verticalOffset
            )
        case .blue:
            // Blue is bottom-right - position dice below the yard
            return CGPoint(
                x: halfBoard - boardSize * 0.2,
                y: boardY - halfBoard - verticalOffset
            )
        }
    }

    /// Animate dice moving to new position
    private func moveDice(to position: CGPoint, animated: Bool = true) {
        if animated {
            let moveAction = SKAction.move(to: position, duration: 0.3)
            moveAction.timingMode = .easeInEaseOut
            diceNode.run(moveAction)
        } else {
            diceNode.position = position
        }
    }

    private func setupTokens() {
        // Create tokens using the GameEngine's players to ensure synchronization
        for player in gameEngine.gameState.players {
            for token in player.tokens {
                let tokenNode = TokenNode(token: token, size: tokenSize)

                // Position based on token's current state (supports saved games)
                let position = gameEngine.screenPosition(for: token)

                // Adjust position relative to board node
                tokenNode.position = CGPoint(
                    x: position.x,
                    y: position.y
                )
                tokenNode.zPosition = 50

                tokenNodes[token.identifier] = tokenNode
                addChild(tokenNode)
            }
        }

        // Update token stacking for any tokens that are on the same position (from saved game)
        if savedGameState != nil {
            updateTokenStacking()
        }
    }

    private func setupUI() {
        // Turn banner — pill-shaped container at the top
        let bannerWidth = size.width * 0.55
        let bannerHeight: CGFloat = 38
        let banner = SKShapeNode(rectOf: CGSize(width: bannerWidth, height: bannerHeight), cornerRadius: bannerHeight / 2)
        banner.position = CGPoint(x: 0, y: size.height * 0.43)
        banner.fillColor = SKColor(white: 0.0, alpha: 0.55)
        banner.strokeColor = SKColor(white: 1.0, alpha: 0.15)
        banner.lineWidth = 1
        banner.zPosition = 99
        addChild(banner)

        // Current player label — centered inside the banner
        currentPlayerLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        currentPlayerLabel.fontSize = 18
        currentPlayerLabel.verticalAlignmentMode = .center
        currentPlayerLabel.position = CGPoint(x: 0, y: size.height * 0.43)
        currentPlayerLabel.zPosition = 100
        addChild(currentPlayerLabel)

        // Message label — inside a subtle pill below the board
        let msgBannerWidth = size.width * 0.75
        let msgBannerHeight: CGFloat = 30
        let msgBanner = SKShapeNode(rectOf: CGSize(width: msgBannerWidth, height: msgBannerHeight), cornerRadius: msgBannerHeight / 2)
        msgBanner.position = CGPoint(x: 0, y: -size.height * 0.275)
        msgBanner.fillColor = SKColor(white: 0.0, alpha: 0.45)
        msgBanner.strokeColor = SKColor(white: 1.0, alpha: 0.10)
        msgBanner.lineWidth = 1
        msgBanner.zPosition = 99
        addChild(msgBanner)

        messageLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        messageLabel.fontSize = 15
        messageLabel.fontColor = SKColor(white: 0.92, alpha: 1.0)
        messageLabel.verticalAlignmentMode = .center
        messageLabel.position = CGPoint(x: 0, y: -size.height * 0.275)
        messageLabel.zPosition = 100
        addChild(messageLabel)

        // Menu button (top-left corner) — rounded square with glass look
        let buttonSize: CGFloat = 40
        menuButton = SKShapeNode(rectOf: CGSize(width: buttonSize, height: buttonSize), cornerRadius: 10)
        menuButton.position = CGPoint(x: -size.width/2 + 35, y: size.height/2 - 40)
        menuButton.fillColor = SKColor(white: 0.15, alpha: 0.85)
        menuButton.strokeColor = SKColor(white: 0.6, alpha: 0.4)
        menuButton.lineWidth = 1
        menuButton.zPosition = 150
        menuButton.name = "menuButton"
        addChild(menuButton)

        // Hamburger icon
        let lineSpacing: CGFloat = 7
        let lineWidth: CGFloat = 18
        let lineHeight: CGFloat = 2.5
        for i in -1...1 {
            let line = SKShapeNode(rectOf: CGSize(width: lineWidth, height: lineHeight), cornerRadius: 1)
            line.position = CGPoint(x: menuButton.position.x, y: menuButton.position.y + CGFloat(i) * lineSpacing)
            line.fillColor = SKColor(white: 0.9, alpha: 1.0)
            line.strokeColor = .clear
            line.zPosition = 151
            addChild(line)
        }

        updateCurrentPlayerDisplay()
        showMessage("Tap dice to roll!")
    }

    private func setupGameEngine() {
        if let savedState = savedGameState {
            // Use saved game state
            gameEngine = GameEngine(savedGameState: savedState, boardSize: boardSize, gameConfig: gameConfig)
        } else {
            // Create new game
            gameEngine = GameEngine(playerColors: playerColors, boardSize: boardSize, gameConfig: gameConfig)
        }
        gameEngine.board.setOrigin(CGPoint(x: -boardSize/2, y: -boardSize/2))
        gameEngine.delegate = self
    }

    // MARK: - UI Updates

    private func updateCurrentPlayerDisplay() {
        let player = gameEngine.currentPlayer
        currentPlayerLabel.fontColor = player.color.color
        animateTurnLabel("\(player.color.name)'s Turn")

        // Set full dice color (fill and dots) based on player
        diceNode.setFullPlayerColor(player.color)

        // Move dice to position near the current player's yard
        let newDicePosition = dicePosition(for: player.color)
        moveDice(to: newDicePosition)
    }

    /// Animate the turn label with a brief pop to draw attention to turn changes
    private func animateTurnLabel(_ text: String) {
        currentPlayerLabel.removeAllActions()
        currentPlayerLabel.text = text
        currentPlayerLabel.setScale(0.8)
        currentPlayerLabel.alpha = 0.5
        let scaleUp  = SKAction.scale(to: 1.05, duration: 0.12)
        let scaleNorm = SKAction.scale(to: 1.0,  duration: 0.08)
        let fadeIn   = SKAction.fadeIn(withDuration: 0.12)
        currentPlayerLabel.run(SKAction.group([SKAction.sequence([scaleUp, scaleNorm]), fadeIn]))
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
                    y: position.y
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

    // MARK: - Token Stacking

    /// Update token stacking after a move - groups tokens at same positions
    private func updateTokenStacking() {
        let currentTurnColor = gameEngine.currentPlayer.color

        // Find all tokens on the track grouped by position
        var tokensByPosition: [Int: [Token]] = [:]

        for player in gameEngine.gameState.players {
            for token in player.tokens {
                if case .onTrack(let position) = token.state {
                    if tokensByPosition[position] == nil {
                        tokensByPosition[position] = []
                    }
                    tokensByPosition[position]?.append(token)
                }
            }
        }

        // Track which positions need stacked views
        var positionsWithStacks = Set<Int>()

        for (position, tokens) in tokensByPosition {
            // Get unique colors at this position
            let uniqueColors = Set(tokens.map { $0.color })

            if uniqueColors.count >= 2 {
                positionsWithStacks.insert(position)

                // Hide individual token nodes for tokens at this position
                for token in tokens {
                    tokenNodes[token.identifier]?.isHidden = true
                }

                // Create or update stacked token node
                if let stackedNode = stackedTokenNodes[position] {
                    stackedNode.update(with: tokens, currentTurnColor: currentTurnColor)
                } else {
                    let stackedNode = StackedTokenNode(size: tokenSize)
                    stackedNode.update(with: tokens, currentTurnColor: currentTurnColor)

                    // Position the stacked node
                    let screenPos = gameEngine.board.screenPosition(forTrackPosition: position)
                    stackedNode.position = CGPoint(
                        x: screenPos.x,
                        y: screenPos.y
                    )
                    stackedNode.zPosition = 55
                    addChild(stackedNode)
                    stackedTokenNodes[position] = stackedNode
                }
            } else {
                // Only one color at this position - show individual tokens
                for token in tokens {
                    tokenNodes[token.identifier]?.isHidden = false
                }
            }
        }

        // Remove stacked nodes for positions that no longer have multiple colors
        let positionsToRemove = stackedTokenNodes.keys.filter { !positionsWithStacks.contains($0) }
        for position in positionsToRemove {
            stackedTokenNodes[position]?.removeFromParent()
            stackedTokenNodes.removeValue(forKey: position)

            // Show individual tokens at this position
            if let tokens = tokensByPosition[position] {
                for token in tokens {
                    tokenNodes[token.identifier]?.isHidden = false
                }
            }
        }

        // Make sure tokens not on track are visible
        for player in gameEngine.gameState.players {
            for token in player.tokens {
                switch token.state {
                case .inYard, .onHomePath, .home:
                    tokenNodes[token.identifier]?.isHidden = false
                case .onTrack:
                    break // Handled above
                }
            }
        }
    }

    /// Update stacked token glows when turn changes
    private func updateStackedTokenGlows() {
        let currentTurnColor = gameEngine.currentPlayer.color
        for (_, stackedNode) in stackedTokenNodes {
            stackedNode.updateGlow(for: currentTurnColor)
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
        guard childNode(withName: "pauseOverlay") == nil else { return } // already shown

        // Pause SpriteKit update loop — this also suspends SKAction timers including
        // all DispatchQueue.main.asyncAfter calls queued via SpriteKit actions.
        // Note: DispatchQueue.main.asyncAfter timers outside SpriteKit run independently;
        // we gate them with the phase/player guards in their callbacks.
        isPaused = true

        // Full-screen dim overlay (not part of the paused scene graph)
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        overlay.fillColor = SKColor(white: 0, alpha: 0.65)
        overlay.strokeColor = .clear
        overlay.position = .zero
        overlay.zPosition = 200
        overlay.name = "pauseOverlay"
        // We need this to render while paused — add it unpause-proof by setting its speed to 0
        addChild(overlay)

        // Card container
        let cardWidth = size.width * 0.72
        let cardHeight: CGFloat = 220
        let card = SKShapeNode(rectOf: CGSize(width: cardWidth, height: cardHeight), cornerRadius: 20)
        card.fillColor = SKColor(red: 0.12, green: 0.13, blue: 0.20, alpha: 0.98)
        card.strokeColor = SKColor(white: 1.0, alpha: 0.18)
        card.lineWidth = 1.5
        card.position = .zero
        card.zPosition = 201
        card.name = "pauseMenu"
        addChild(card)

        // PAUSED title
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        titleLabel.text = "PAUSED"
        titleLabel.fontSize = 26
        titleLabel.fontColor = SKColor(white: 0.95, alpha: 1.0)
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: 72)
        titleLabel.zPosition = 202
        addChild(titleLabel)

        // Thin separator
        let sep = SKShapeNode(rectOf: CGSize(width: cardWidth * 0.8, height: 1))
        sep.fillColor = SKColor(white: 1.0, alpha: 0.12)
        sep.strokeColor = .clear
        sep.position = CGPoint(x: 0, y: 44)
        sep.zPosition = 202
        sep.name = "pauseSeparator"
        addChild(sep)

        // Resume button (primary — accent colour)
        addChild(createPauseButton(text: "Resume", yPos: 8, name: "resumeButton",
                                   fill: SKColor(red: 0.20, green: 0.60, blue: 0.95, alpha: 1.0)))
        // Main Menu button (secondary)
        addChild(createPauseButton(text: "Main Menu", yPos: -54, name: "mainMenuButton",
                                   fill: SKColor(white: 0.25, alpha: 1.0)))
    }

    private func createPauseButton(text: String, yPos: CGFloat, name: String, fill: SKColor) -> SKShapeNode {
        let buttonWidth = size.width * 0.55
        let buttonHeight: CGFloat = 48

        let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        button.position = CGPoint(x: 0, y: yPos)
        button.fillColor = fill
        button.strokeColor = fill.withAlphaComponent(0.5)
        button.lineWidth = 1.5
        button.zPosition = 202
        button.name = name

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = text
        label.fontSize = 17
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = .zero
        button.addChild(label)

        return button
    }

    private func handlePauseMenuTouch(at location: CGPoint) {
        // Un-pause first so hit-testing works on restored node positions
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

        // Tap outside card to resume
        if let pauseMenu = childNode(withName: "pauseMenu") as? SKShapeNode,
           !pauseMenu.contains(location) {
            dismissPauseMenu()
        }
    }

    private func dismissPauseMenu() {
        isPaused = false  // Resume SpriteKit update loop

        ["pauseOverlay", "pauseMenu", "resumeButton", "mainMenuButton", "pauseSeparator"].forEach {
            childNode(withName: $0)?.removeFromParent()
        }
        // Remove the PAUSED title label (added directly to scene, not to card)
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
        // Block human input when the AI is deciding or it is an AI's turn
        guard !isAIPlayer(gameEngine.currentPlayer) else { return }

        // Check if a valid token was tapped
        let movable = gameEngine.movableTokens()

        // First check individual token nodes
        for token in movable {
            guard let tokenNode = tokenNodes[token.identifier] else { continue }

            // Only check visible tokens (not hidden in a stack)
            if !tokenNode.isHidden && tokenNode.isPointInside(location) {
                moveToken(token)
                return
            }
        }

        // Check stacked token nodes
        for (_, stackedNode) in stackedTokenNodes {
            if stackedNode.isPointInside(location) {
                // Find the movable token in this stack for the current player
                let currentColor = gameEngine.currentPlayer.color
                if let token = stackedNode.token(for: currentColor),
                   movable.contains(where: { $0.identifier == token.identifier }) {
                    moveToken(token)
                    return
                }
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
        // Disable dice immediately to prevent double-taps
        diceNode.isEnabled = false
        diceNode.hideGlow()

        // Set BEFORE calling rollDice() so any synchronous delegate callbacks
        // (turnVoided, noValidMoves → turnDidChange) see this flag and defer correctly.
        diceAnimationInProgress = true

        let value = gameEngine.rollDice()

        // Haptic for every dice roll
        impactFeedback.impactOccurred()

        diceNode.animateRoll(finalValue: value) { [weak self] in
            self?.diceAnimationInProgress = false
            self?.afterDiceRoll(value: value)
        }
    }

    private func afterDiceRoll(value: Int) {
        // Handle any deferred turn change — covers BOTH "no valid moves" and "turn voided" (three 6s).
        // The pendingTurnPlayer is set in turnDidChange when diceAnimationInProgress was true.
        if let pendingPlayer = pendingTurnPlayer {
            pendingTurnPlayer = nil
            isAITurnInProgress = false

            if noValidMovesOccurred {
                // Show "no moves" feedback, then hand off to next player
                noValidMovesOccurred = false
                showMessage("No possible move")
            }
            // For turn-voided case the message was already shown via turnVoided delegate.

            diceNode.isEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + noMovesHoldDelay) { [weak self] in
                self?.executeTurnChange(to: pendingPlayer)
            }
            return
        }

        if gameEngine.phase == .selectingToken {
            let movable = gameEngine.movableTokens()

            if isAIPlayer(gameEngine.currentPlayer) {
                // AI selects best move after a short thinking pause
                let currentColor = gameEngine.currentPlayer.color
                DispatchQueue.main.asyncAfter(deadline: .now() + aiMoveDelay) { [weak self] in
                    guard let self = self else { return }
                    guard self.gameEngine.currentPlayer.color == currentColor,
                          self.gameEngine.phase == .selectingToken else {
                        self.isAITurnInProgress = false
                        return
                    }
                    self.performAIMove()
                }
            } else {
                // Human player
                isAITurnInProgress = false

                // Auto-move only when there is exactly one meaningful choice:
                //   • single movable token, OR
                //   • all movable tokens share the same state (e.g. all stacked at same position)
                let singleChoice = movable.count == 1 ||
                                   movable.allSatisfy { $0.state == movable[0].state }

                if singleChoice {
                    showMessage("Moving...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                        self?.moveToken(movable[0])
                    }
                } else {
                    highlightMovableTokens()
                    showMessage("Select a token to move")
                }
            }
        } else {
            // Phase is not selectingToken (e.g. turn was voided synchronously before we checked)
            isAITurnInProgress = false
        }
    }

    private func isAIPlayer(_ player: Player) -> Bool {
        return !gameConfig.isHuman(player.color)
    }

    private func performAIMove() {
        // Verify we're still in the correct state
        guard gameEngine.phase == .selectingToken,
              isAIPlayer(gameEngine.currentPlayer) else {
            isAITurnInProgress = false
            return
        }

        guard let bestToken = gameEngine.suggestBestMove() else {
            // No valid move found (shouldn't happen if phase is selectingToken)
            // This is a safety fallback
            isAITurnInProgress = false
            return
        }
        moveToken(bestToken)
    }

    private func executeTurnChange(to player: Player) {
        updateCurrentPlayerDisplay()
        updateTurnHighlights()
        updateStackedTokenGlows()

        // Reset AI turn flag when changing turns
        isAITurnInProgress = false

        if isAIPlayer(player) {
            showMessage("\(player.color.name) is thinking...")
            checkAndPerformAITurn()
        } else {
            showMessage("Tap dice to roll!")
            diceNode.isEnabled = true
            diceNode.showGlow(color: player.color)
        }
    }

    private func checkAndPerformAITurn() {
        // Verify we're in the correct state for an AI turn
        guard gameEngine.phase == .rolling else {
            isAITurnInProgress = false
            return
        }
        guard isAIPlayer(gameEngine.currentPlayer) else {
            isAITurnInProgress = false
            return
        }

        // Prevent overlapping AI turn attempts
        if isAITurnInProgress {
            return
        }

        isAITurnInProgress = true

        // Capture the current player to verify in the callback
        let initiatingPlayer = gameEngine.currentPlayer.color

        // Disable dice during AI turn - not clickable by human
        diceNode.isEnabled = false

        // Show glow for 0.5s then auto-roll
        diceNode.showGlow(color: gameEngine.currentPlayer.color)

        DispatchQueue.main.asyncAfter(deadline: .now() + aiGlowDelay) { [weak self] in
            guard let self = self else { return }

            // Verify state hasn't changed during the delay
            guard self.gameEngine.phase == .rolling,
                  self.gameEngine.currentPlayer.color == initiatingPlayer,
                  self.isAIPlayer(self.gameEngine.currentPlayer) else {
                // State changed - reset flag and let the current state handler take over
                self.isAITurnInProgress = false
                return
            }

            // Proceed with the roll
            self.rollDice()
        }
    }

    private func moveToken(_ token: Token) {
        guard let tokenNode = tokenNodes[token.identifier] else { return }

        clearHighlights()
        impactFeedback.impactOccurred(intensity: 0.7)

        let previousState = token.state
        let result = gameEngine.moveToken(token)

        // Get new position
        let newPosition = gameEngine.screenPosition(for: token)
        let adjustedPosition = CGPoint(
            x: newPosition.x,
            y: newPosition.y
        )

        // Animate the move
        tokenNode.animateMove(to: adjustedPosition) { [weak self] in
            self?.afterTokenMove(token: token, result: result, previousState: previousState)
        }
    }

    private func afterTokenMove(token: Token, result: MoveResult, previousState: TokenState) {
        // Handle capture case specially - wait for capture animation before enabling dice
        if case .capturedOpponent(let captured) = result {
            // Get the capture position from the moving token's current state
            let capturePosition: Int
            if case .onTrack(let pos) = token.state {
                capturePosition = pos
            } else {
                // Fallback: use start position if we can't determine capture position
                capturePosition = captured.color.startPosition
            }

            // Update token stacking before animation
            updateTokenStacking()

            // Animate the captured token and wait for completion before enabling dice
            animateCapturedToken(captured, fromPosition: capturePosition) { [weak self] in
                guard let self = self else { return }
                self.enableNextTurnAfterMove(token: token)
            }
            return
        }

        // Handle other result types
        switch result {
        case .reachedHome:
            tokenNodes[token.identifier]?.animateReachHome()
            MusicManager.shared.playInHomeSound()
            notifyFeedback.notificationOccurred(.success)  // Celebratory haptic
        case .success:
            // Check if token landed on a safe spot
            // Don't play safe sound if token just came out of yard onto its start position
            if case .onTrack(let position) = token.state {
                let justLeftYard = (previousState == .inYard)
                let isOwnStartPosition = (position == token.color.startPosition)

                if PlayerColor.safeSquares.contains(position) && !(justLeftYard && isOwnStartPosition) {
                    MusicManager.shared.playSafeSound()
                }
            }
        default:
            break
        }

        // Update token stacking after the move
        updateTokenStacking()

        // Enable next turn
        enableNextTurnAfterMove(token: token)
    }

    /// Enable the next turn after a token move completes (including any capture animation)
    private func enableNextTurnAfterMove(token: Token) {
        // Check game phase after move
        if gameEngine.phase == .rolling {
            // Only trigger next roll if this is a bonus roll for the SAME player
            // Turn changes to a different player are handled by turnDidChange delegate
            if token.color == gameEngine.currentPlayer.color {
                // This is a bonus roll situation - same player gets another turn
                if isAIPlayer(gameEngine.currentPlayer) {
                    // For AI bonus rolls, use a dedicated method that forces the turn to happen
                    performAIBonusRoll()
                } else {
                    // Human player gets another roll
                    isAITurnInProgress = false
                    diceNode.isEnabled = true
                    diceNode.showGlow(color: gameEngine.currentPlayer.color)
                }
            }
            // If token.color != currentPlayer.color, the turn already changed
            // and turnDidChange already triggered the new player's turn.
            // Do NOT reset isAITurnInProgress here - the new player's turn may have already set it.
        } else if gameEngine.phase == .gameOver {
            isAITurnInProgress = false
            showGameOver()
        }
    }

    /// Handle AI bonus roll - dedicated method to ensure bonus roll always happens
    private func performAIBonusRoll() {
        // Force reset the flag to allow this bonus roll
        isAITurnInProgress = false

        // Verify state
        guard gameEngine.phase == .rolling,
              isAIPlayer(gameEngine.currentPlayer) else {
            return
        }

        // Capture the current player for verification
        let bonusRollPlayer = gameEngine.currentPlayer.color

        // Mark as in progress
        isAITurnInProgress = true

        // Disable dice during AI turn
        diceNode.isEnabled = false

        // Show glow for the bonus roll
        diceNode.showGlow(color: gameEngine.currentPlayer.color)
        showMessage("Bonus roll!")

        // Schedule the roll after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + aiGlowDelay) { [weak self] in
            guard let self = self else { return }

            // Verify state is still valid
            guard self.gameEngine.phase == .rolling,
                  self.gameEngine.currentPlayer.color == bonusRollPlayer,
                  self.isAIPlayer(self.gameEngine.currentPlayer) else {
                self.isAITurnInProgress = false
                return
            }

            // Proceed with the roll
            self.rollDice()
        }
    }

    private func animateCapturedToken(_ token: Token, fromPosition capturePosition: Int, completion: (() -> Void)? = nil) {
        guard let tokenNode = tokenNodes[token.identifier] else {
            completion?()
            return
        }

        let yardPositions = gameEngine.board.yardPositions(for: token.color)
        let yardPosition = yardPositions[token.index]
        let adjustedYardPosition = CGPoint(
            x: yardPosition.x,
            y: yardPosition.y
        )

        // Calculate the path backwards from capture position to start position
        let startPosition = token.color.startPosition
        var pathPositions: [CGPoint] = []

        // Trace backwards from capture position to start position
        var currentPos = capturePosition
        while currentPos != startPosition {
            // Move backwards on the track (wrap around at 0)
            currentPos = (currentPos - 1 + 52) % 52

            let screenPos = gameEngine.board.screenPosition(forTrackPosition: currentPos)
            let adjustedPos = CGPoint(
                x: screenPos.x,
                y: screenPos.y
            )
            pathPositions.append(adjustedPos)

            // Safety check to avoid infinite loop
            if pathPositions.count > 52 {
                break
            }
        }

        // Animate along the path back to yard, then call completion
        tokenNode.animateCaptureAlongPath(pathPositions: pathPositions, yardPosition: adjustedYardPosition, completion: completion)
    }

    private func showGameOver() {
        let finishOrder = gameEngine.gameState.finishOrder
        guard let winner = finishOrder.first else { return }

        // Haptic for winner
        notifyFeedback.notificationOccurred(.success)

        // Full-screen dim
        let dim = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        dim.fillColor = SKColor(white: 0, alpha: 0.60)
        dim.strokeColor = .clear
        dim.position = .zero
        dim.zPosition = 198
        dim.name = "gameOverOverlay"
        addChild(dim)

        // Card
        let cardW = size.width * 0.82
        let rowH: CGFloat = 50
        let headerH: CGFloat = 90
        let footerH: CGFloat = 52
        let cardH = headerH + CGFloat(gameEngine.gameState.players.count) * rowH + footerH + 16
        let card = SKShapeNode(rectOf: CGSize(width: cardW, height: cardH), cornerRadius: 22)
        card.fillColor = SKColor(red: 0.10, green: 0.11, blue: 0.18, alpha: 0.97)
        card.strokeColor = winner.color.withAlphaComponent(0.6)
        card.lineWidth = 2.5
        card.position = .zero
        card.zPosition = 199
        card.name = "gameOverCard"
        addChild(card)

        // "🏆 <Color> Wins!" header
        let topY = cardH / 2 - headerH / 2 + 6
        let winLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        winLabel.text = "\(winner.name) Wins!"
        winLabel.fontSize = 30
        winLabel.fontColor = winner.color
        winLabel.verticalAlignmentMode = .center
        winLabel.position = CGPoint(x: 0, y: topY)
        winLabel.zPosition = 200
        addChild(winLabel)

        // Separator
        let sep = SKShapeNode(rectOf: CGSize(width: cardW * 0.85, height: 1))
        sep.fillColor = SKColor(white: 1.0, alpha: 0.13)
        sep.strokeColor = .clear
        sep.position = CGPoint(x: 0, y: topY - headerH / 2 + 4)
        sep.zPosition = 200
        addChild(sep)

        // Rankings rows
        let medals = ["🥇", "🥈", "🥉", "4th"]
        let ordinals = ["1st", "2nd", "3rd", "4th"]
        let allPlayers = gameEngine.gameState.players
        var rankY = topY - headerH / 2 - rowH / 2

        // Show finished players in order, then remaining players who didn't finish
        var rankedColors = finishOrder
        for player in allPlayers where !finishOrder.contains(player.color) {
            rankedColors.append(player.color)
        }

        for (i, color) in rankedColors.enumerated() {
            let medal = i < medals.count ? medals[i] : "—"
            let ordinal = i < ordinals.count ? ordinals[i] : "\(i + 1)th"

            // Medal / ordinal
            let medalLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
            medalLabel.text = medal
            medalLabel.fontSize = 20
            medalLabel.verticalAlignmentMode = .center
            medalLabel.horizontalAlignmentMode = .center
            medalLabel.position = CGPoint(x: -cardW * 0.35, y: rankY)
            medalLabel.zPosition = 200
            addChild(medalLabel)

            // Color swatch circle
            let swatch = SKShapeNode(circleOfRadius: 8)
            swatch.fillColor = color.color
            swatch.strokeColor = SKColor(white: 1.0, alpha: 0.3)
            swatch.lineWidth = 1.5
            swatch.position = CGPoint(x: -cardW * 0.18, y: rankY)
            swatch.zPosition = 200
            addChild(swatch)

            // Color name
            let nameLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            nameLabel.text = color.name
            nameLabel.fontSize = 17
            nameLabel.fontColor = color.color
            nameLabel.verticalAlignmentMode = .center
            nameLabel.horizontalAlignmentMode = .left
            nameLabel.position = CGPoint(x: -cardW * 0.11, y: rankY)
            nameLabel.zPosition = 200
            addChild(nameLabel)

            // Finished / In Progress indicator
            let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
            let isFinished = finishOrder.contains(color)
            statusLabel.text = isFinished ? ordinal : "In play"
            statusLabel.fontSize = 14
            statusLabel.fontColor = isFinished ? SKColor(white: 0.75, alpha: 1.0) : SKColor(red: 0.4, green: 0.9, blue: 0.5, alpha: 1.0)
            statusLabel.verticalAlignmentMode = .center
            statusLabel.horizontalAlignmentMode = .right
            statusLabel.position = CGPoint(x: cardW * 0.42, y: rankY)
            statusLabel.zPosition = 200
            addChild(statusLabel)

            rankY -= rowH
        }

        // "Tap anywhere to play again" footer
        let tapLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        tapLabel.text = "Tap anywhere to play again"
        tapLabel.fontSize = 13
        tapLabel.fontColor = SKColor(white: 0.50, alpha: 1.0)
        tapLabel.verticalAlignmentMode = .center
        tapLabel.position = CGPoint(x: 0, y: -cardH / 2 + footerH / 2)
        tapLabel.zPosition = 200
        addChild(tapLabel)

        // Animate entire card group in
        let nodesToAnimate: [SKNode] = [dim, card, winLabel, sep, tapLabel]
        for node in nodesToAnimate {
            node.alpha = 0
        }
        // Also fade the dynamically created ranking labels/nodes
        let rankNodes = children.filter { $0.zPosition == 200 && !nodesToAnimate.contains($0) }
        for node in rankNodes { node.alpha = 0 }

        let delay = SKAction.wait(forDuration: 0.15)
        let fadeIn = SKAction.fadeIn(withDuration: 0.35)
        card.setScale(0.88)
        let scaleUp = SKAction.scale(to: 1.0, duration: 0.35)
        scaleUp.timingMode = .easeOut

        let allVisible = nodesToAnimate + rankNodes
        for node in allVisible {
            node.run(SKAction.sequence([delay, fadeIn]))
        }
        card.run(SKAction.sequence([delay, SKAction.group([fadeIn, scaleUp])]))
    }

    private func restartGame() {
        // Fade out all game-over nodes (dim overlay + card + all z=200 labels)
        let gameOverNodes = children.filter { $0.name == "gameOverOverlay" || $0.name == "gameOverCard" || $0.zPosition == 200 }
        for node in gameOverNodes {
            let fadeOut = SKAction.fadeOut(withDuration: 0.25)
            let remove  = SKAction.removeFromParent()
            node.run(SKAction.sequence([fadeOut, remove]))
        }

        // Remove existing token nodes
        for (_, tokenNode) in tokenNodes {
            tokenNode.removeFromParent()
        }
        tokenNodes.removeAll()

        // Remove stacked token nodes
        for (_, stackedNode) in stackedTokenNodes {
            stackedNode.removeFromParent()
        }
        stackedTokenNodes.removeAll()

        // Reset all state flags to clean slate
        diceAnimationInProgress = false
        noValidMovesOccurred    = false
        pendingTurnPlayer       = nil
        isAITurnInProgress      = false

        // Reset game state
        gameEngine = GameEngine(playerColors: playerColors, boardSize: boardSize, gameConfig: gameConfig)
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

        // Set initial dice position and color for new game
        let startingColor = gameEngine.currentPlayer.color
        diceNode.position = dicePosition(for: startingColor)
        diceNode.setFullPlayerColor(startingColor)

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
            diceNode.isEnabled = true
            diceNode.showGlow(color: gameEngine.currentPlayer.color)
        }
    }

    func turnDidChange(to player: Player) {
        // Save game state after each turn change (for offline play only)
        if gameConfig.gameMode == .offline {
            GameSaveManager.shared.saveGame(gameState: gameEngine.gameState, gameConfig: gameConfig)
        }

        // Defer the turn change if the dice animation is still running.
        // This handles BOTH cases:
        //   1. "No valid moves"  — gameEngine called noValidMoves + turnDidChange synchronously
        //   2. "Turn voided"     — gameEngine called turnVoided   + turnDidChange synchronously
        // In both cases diceAnimationInProgress == true because we set it before rollDice().
        if diceAnimationInProgress || noValidMovesOccurred {
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

    func tokenDidGetCaptured(token: Token, by: Token, atPosition: Int) {
        showMessage("\(by.color.name) captured \(token.color.name)!", duration: 2)
        MusicManager.shared.playEatSound()
        heavyFeedback.impactOccurred()   // Strong pulse on capture
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
        showMessage("\(player.color.name) finished \(ordinal)!", duration: 2.5)

        // Haptic: winner gets notification success, others get impact
        if place == 1 {
            notifyFeedback.notificationOccurred(.success)
        } else {
            impactFeedback.impactOccurred()
        }

        // Show crown in the player's yard
        showCrown(for: player.color, place: place)
    }

    /// Display a crown with rank in the player's yard when they finish
    private func showCrown(for color: PlayerColor, place: Int) {
        // Get the center of the player's yard
        let yardCenter = gameEngine.board.yardCenter(for: color)

        // Create crown sized appropriately for the yard
        let crownSize = boardSize / 6  // Yard is roughly 1/6 of the board
        let crown = CrownNode(place: place, playerColor: color, size: crownSize)

        // Position crown in the yard center
        crown.position = yardCenter
        crown.zPosition = 100
        crown.name = "crown_\(color.name)"

        addChild(crown)

        // Animate the crown appearing
        crown.animateAppearance()
    }

    func gameDidEnd(winner: Player) {
        showMessage("")
        clearTurnHighlights()
        // Play in_home sound first, then applause
        MusicManager.shared.playGameFinishSounds()
        // Delete saved game when game is complete
        if gameConfig.gameMode == .offline {
            GameSaveManager.shared.deleteSavedGame()
        }
        // Game over UI handled in afterTokenMove
    }

    func noValidMoves(for player: Player) {
        // Defer the message and turn change — shown after dice animation completes
        noValidMovesOccurred = true
    }

    func turnVoided(player: Player, reason: String) {
        animateTurnLabel("Three 6s! Voided.")
        showMessage("Turn skipped — three sixes!", duration: 2.0)
        notifyFeedback.notificationOccurred(.warning)
    }
}
