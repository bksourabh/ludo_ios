import SpriteKit
import AuthenticationServices
import GameKit

/// Protocol for menu scene delegate
protocol MenuSceneDelegate: AnyObject {
    func menuSceneDidStartGame(with config: GameConfig)
    func menuSceneRequestsAppleSignIn()
    func menuSceneRequestsGameCenterAuth()
}

/// Main menu scene for game setup
class MenuScene: SKScene {

    weak var menuDelegate: MenuSceneDelegate?

    // UI Elements
    private var titleLabel: SKLabelNode!
    private var playerButtons: [PlayerColor: SKShapeNode] = [:]
    private var playerLabels: [PlayerColor: SKLabelNode] = [:]
    private var startButton: SKShapeNode!
    private var signInButton: SKShapeNode?
    private var playerNameLabel: SKLabelNode!

    // Game configuration
    private var gameConfig = GameConfig()

    // Layout constants
    private let buttonHeight: CGFloat = 50
    private let buttonSpacing: CGFloat = 20

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)
        setupUI()
        updateAuthUI()
    }

    private func setupUI() {
        // Title
        titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = "LUDO"
        titleLabel.fontSize = 48
        titleLabel.fontColor = .white
        titleLabel.position = CGPoint(x: 0, y: size.height * 0.35)
        addChild(titleLabel)

        // Subtitle
        let subtitleLabel = SKLabelNode(fontNamed: "Helvetica")
        subtitleLabel.text = "Select Players"
        subtitleLabel.fontSize = 20
        subtitleLabel.fontColor = SKColor(white: 0.7, alpha: 1.0)
        subtitleLabel.position = CGPoint(x: 0, y: size.height * 0.28)
        addChild(subtitleLabel)

        // Player name label
        playerNameLabel = SKLabelNode(fontNamed: "Helvetica")
        playerNameLabel.fontSize = 16
        playerNameLabel.fontColor = SKColor(white: 0.6, alpha: 1.0)
        playerNameLabel.position = CGPoint(x: 0, y: size.height * 0.40)
        addChild(playerNameLabel)

        // Player selection buttons
        setupPlayerButtons()

        // Start game button
        setupStartButton()

        // Sign in button
        setupSignInButton()
    }

    private func setupPlayerButtons() {
        let colors: [PlayerColor] = [.red, .green, .yellow, .blue]
        let startY = size.height * 0.12
        let buttonWidth = size.width * 0.7

        for (index, color) in colors.enumerated() {
            let yPos = startY - CGFloat(index) * (buttonHeight + buttonSpacing)

            // Button background
            let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 10)
            button.position = CGPoint(x: 0, y: yPos)
            button.fillColor = color.color.withAlphaComponent(0.3)
            button.strokeColor = color.color
            button.lineWidth = 2
            button.name = "playerButton_\(color.rawValue)"
            addChild(button)
            playerButtons[color] = button

            // Color name label (left side)
            let colorLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
            colorLabel.text = color.name
            colorLabel.fontSize = 18
            colorLabel.fontColor = color.color
            colorLabel.horizontalAlignmentMode = .left
            colorLabel.verticalAlignmentMode = .center
            colorLabel.position = CGPoint(x: -buttonWidth/2 + 20, y: yPos)
            addChild(colorLabel)

            // Player type label (right side)
            let typeLabel = SKLabelNode(fontNamed: "Helvetica")
            typeLabel.fontSize = 16
            typeLabel.fontColor = .white
            typeLabel.horizontalAlignmentMode = .right
            typeLabel.verticalAlignmentMode = .center
            typeLabel.position = CGPoint(x: buttonWidth/2 - 20, y: yPos)
            addChild(typeLabel)
            playerLabels[color] = typeLabel

            updatePlayerButton(color)
        }
    }

    private func setupStartButton() {
        let buttonWidth = size.width * 0.6
        let buttonHeight: CGFloat = 55

        startButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        startButton.position = CGPoint(x: 0, y: -size.height * 0.28)
        startButton.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        startButton.strokeColor = SKColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1.0)
        startButton.lineWidth = 2
        startButton.name = "startButton"
        addChild(startButton)

        let startLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        startLabel.text = "START GAME"
        startLabel.fontSize = 22
        startLabel.fontColor = .white
        startLabel.verticalAlignmentMode = .center
        startLabel.position = CGPoint(x: 0, y: -size.height * 0.28)
        addChild(startLabel)
    }

    private func setupSignInButton() {
        let buttonWidth = size.width * 0.5
        let buttonHeight: CGFloat = 44

        let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 8)
        button.position = CGPoint(x: 0, y: -size.height * 0.38)
        button.fillColor = .black
        button.strokeColor = .white
        button.lineWidth = 1
        button.name = "signInButton"
        addChild(button)
        signInButton = button

        let appleIcon = SKLabelNode(fontNamed: "Helvetica")
        appleIcon.text = " Sign in with Apple"
        appleIcon.fontSize = 16
        appleIcon.fontColor = .white
        appleIcon.verticalAlignmentMode = .center
        appleIcon.position = CGPoint(x: 0, y: -size.height * 0.38)
        appleIcon.name = "signInLabel"
        addChild(appleIcon)
    }

    private func updatePlayerButton(_ color: PlayerColor) {
        guard let label = playerLabels[color],
              let button = playerButtons[color] else { return }

        let isHuman = gameConfig.isHuman(color)
        label.text = isHuman ? "👤 Human" : "🤖 Computer"

        // Update button appearance
        button.fillColor = isHuman ?
            color.color.withAlphaComponent(0.5) :
            color.color.withAlphaComponent(0.2)
    }

    private func updateAuthUI() {
        let manager = GameManager.shared

        if manager.isSignedInWithApple || manager.isGameCenterAuthenticated {
            playerNameLabel.text = "Welcome, \(manager.playerName)!"
            signInButton?.isHidden = true
            childNode(withName: "signInLabel")?.isHidden = true
        } else {
            playerNameLabel.text = ""
            signInButton?.isHidden = false
            childNode(withName: "signInLabel")?.isHidden = false
        }
    }

    private func togglePlayerType(_ color: PlayerColor) {
        switch color {
        case .red:
            gameConfig.redPlayer = gameConfig.redPlayer == .human ? .computer : .human
        case .green:
            gameConfig.greenPlayer = gameConfig.greenPlayer == .human ? .computer : .human
        case .yellow:
            gameConfig.yellowPlayer = gameConfig.yellowPlayer == .human ? .computer : .human
        case .blue:
            gameConfig.bluePlayer = gameConfig.bluePlayer == .human ? .computer : .human
        }
        updatePlayerButton(color)

        // Animate button
        if let button = playerButtons[color] {
            let scale = SKAction.sequence([
                SKAction.scale(to: 1.05, duration: 0.1),
                SKAction.scale(to: 1.0, duration: 0.1)
            ])
            button.run(scale)
        }
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check player buttons
        for color in PlayerColor.allCases {
            if let button = playerButtons[color], button.contains(location) {
                togglePlayerType(color)
                return
            }
        }

        // Check start button
        if startButton.contains(location) {
            animateButtonPress(startButton) { [weak self] in
                guard let self = self else { return }
                self.menuDelegate?.menuSceneDidStartGame(with: self.gameConfig)
            }
            return
        }

        // Check sign in button
        if let signInBtn = signInButton, signInBtn.contains(location) {
            animateButtonPress(signInBtn) { [weak self] in
                self?.menuDelegate?.menuSceneRequestsAppleSignIn()
            }
            return
        }
    }

    private func animateButtonPress(_ button: SKShapeNode, completion: @escaping () -> Void) {
        let pressDown = SKAction.scale(to: 0.95, duration: 0.1)
        let pressUp = SKAction.scale(to: 1.0, duration: 0.1)
        let sequence = SKAction.sequence([pressDown, pressUp])

        button.run(sequence) {
            completion()
        }
    }

    /// Refresh UI after authentication changes
    func refreshAuthState() {
        updateAuthUI()
    }
}
