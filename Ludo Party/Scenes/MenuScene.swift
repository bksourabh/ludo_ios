import SpriteKit
import AuthenticationServices
import GameKit

/// Protocol for menu scene delegate
protocol MenuSceneDelegate: AnyObject {
    func menuSceneDidStartGame(with config: GameConfig)
    func menuSceneRequestsAppleSignIn()
    func menuSceneRequestsGameCenterAuth()
    func menuSceneRequestsGuestLogin()
    func menuSceneRequestsCreateOnlineGame()
    func menuSceneRequestsJoinOnlineGame()
}

/// Main menu scene for game setup
class MenuScene: SKScene {

    weak var menuDelegate: MenuSceneDelegate?

    // Scene state
    private var isLoggedIn: Bool {
        return GameManager.shared.isLoggedIn
    }

    // UI Containers
    private var loginContainer: SKNode!
    private var modeSelectionContainer: SKNode!
    private var gameSetupContainer: SKNode!

    // Current screen state
    private enum MenuState {
        case login
        case modeSelection
        case offlineSetup
    }
    private var menuState: MenuState = .login

    // Login UI Elements
    private var logoSprite: SKSpriteNode!
    private var signInButton: SKShapeNode!
    private var signInLabel: SKLabelNode!
    private var guestButton: SKShapeNode!
    private var guestLabel: SKLabelNode!

    // Mode Selection UI Elements
    private var playOfflineButton: SKShapeNode!
    private var createOnlineButton: SKShapeNode!
    private var joinOnlineButton: SKShapeNode!
    private var modeBackButton: SKShapeNode!

    // Game Setup UI Elements
    private var playerButtons: [PlayerColor: SKShapeNode] = [:]
    private var playerLabels: [PlayerColor: SKLabelNode] = [:]
    private var colorLabels: [PlayerColor: SKLabelNode] = [:]
    private var startButton: SKShapeNode!
    private var startButtonLabel: SKLabelNode!
    private var welcomeLabel: SKLabelNode!
    private var subtitleLabel: SKLabelNode!

    // Game configuration
    private var gameConfig = GameConfig()

    // Layout constants
    private let buttonHeight: CGFloat = 50
    private let buttonSpacing: CGFloat = 20

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)
        setupLoginUI()
        setupModeSelectionUI()
        setupGameSetupUI()
        updateVisibility()
    }

    // MARK: - Login UI

    private func setupLoginUI() {
        loginContainer = SKNode()
        addChild(loginContainer)

        // Logo image
        if let logoTexture = SKTexture(imageNamed: "LudoLogo") as SKTexture? {
            logoSprite = SKSpriteNode(texture: logoTexture)
            let maxWidth = size.width * 0.6
            let maxHeight = size.height * 0.3
            let scale = min(maxWidth / logoSprite.size.width, maxHeight / logoSprite.size.height)
            logoSprite.setScale(scale)
            logoSprite.position = CGPoint(x: 0, y: size.height * 0.15)
            loginContainer.addChild(logoSprite)
        } else {
            // Fallback text if logo not found
            let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
            titleLabel.text = "LUDO"
            titleLabel.fontSize = 64
            titleLabel.fontColor = .white
            titleLabel.position = CGPoint(x: 0, y: size.height * 0.15)
            loginContainer.addChild(titleLabel)
        }

        // Welcome message
        let welcomeText = SKLabelNode(fontNamed: "Helvetica")
        welcomeText.text = "Sign in to play"
        welcomeText.fontSize = 20
        welcomeText.fontColor = SKColor(white: 0.7, alpha: 1.0)
        welcomeText.position = CGPoint(x: 0, y: -size.height * 0.05)
        loginContainer.addChild(welcomeText)

        // Sign in with Apple button
        let buttonWidth = size.width * 0.65
        let buttonHeight: CGFloat = 50

        signInButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 8)
        signInButton.position = CGPoint(x: 0, y: -size.height * 0.15)
        signInButton.fillColor = .black
        signInButton.strokeColor = .white
        signInButton.lineWidth = 2
        signInButton.name = "signInButton"
        loginContainer.addChild(signInButton)

        signInLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        signInLabel.text = " Sign in with Apple"
        signInLabel.fontSize = 18
        signInLabel.fontColor = .white
        signInLabel.verticalAlignmentMode = .center
        signInLabel.position = CGPoint(x: 0, y: -size.height * 0.15)
        loginContainer.addChild(signInLabel)

        // "or" separator
        let orLabel = SKLabelNode(fontNamed: "Helvetica")
        orLabel.text = "or"
        orLabel.fontSize = 16
        orLabel.fontColor = SKColor(white: 0.5, alpha: 1.0)
        orLabel.position = CGPoint(x: 0, y: -size.height * 0.22)
        loginContainer.addChild(orLabel)

        // Continue as Guest button
        guestButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 8)
        guestButton.position = CGPoint(x: 0, y: -size.height * 0.29)
        guestButton.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        guestButton.strokeColor = SKColor(white: 0.4, alpha: 1.0)
        guestButton.lineWidth = 1
        guestButton.name = "guestButton"
        loginContainer.addChild(guestButton)

        guestLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        guestLabel.text = "Continue as Guest"
        guestLabel.fontSize = 18
        guestLabel.fontColor = .white
        guestLabel.verticalAlignmentMode = .center
        guestLabel.position = CGPoint(x: 0, y: -size.height * 0.29)
        loginContainer.addChild(guestLabel)
    }

    // MARK: - Mode Selection UI

    private func setupModeSelectionUI() {
        modeSelectionContainer = SKNode()
        addChild(modeSelectionContainer)

        // Logo (smaller, at top)
        if let logoTexture = SKTexture(imageNamed: "LudoLogo") as SKTexture? {
            let smallLogo = SKSpriteNode(texture: logoTexture)
            let maxWidth = size.width * 0.4
            let maxHeight = size.height * 0.15
            let scale = min(maxWidth / smallLogo.size.width, maxHeight / smallLogo.size.height)
            smallLogo.setScale(scale)
            smallLogo.position = CGPoint(x: 0, y: size.height * 0.32)
            modeSelectionContainer.addChild(smallLogo)
        }

        // Welcome label
        let modeWelcomeLabel = SKLabelNode(fontNamed: "Helvetica")
        modeWelcomeLabel.text = "Welcome, \(GameManager.shared.playerName)!"
        modeWelcomeLabel.fontSize = 16
        modeWelcomeLabel.fontColor = SKColor(white: 0.6, alpha: 1.0)
        modeWelcomeLabel.position = CGPoint(x: 0, y: size.height * 0.22)
        modeWelcomeLabel.name = "modeWelcomeLabel"
        modeSelectionContainer.addChild(modeWelcomeLabel)

        // Title
        let modeTitle = SKLabelNode(fontNamed: "Helvetica-Bold")
        modeTitle.text = "Choose Game Mode"
        modeTitle.fontSize = 24
        modeTitle.fontColor = .white
        modeTitle.position = CGPoint(x: 0, y: size.height * 0.14)
        modeSelectionContainer.addChild(modeTitle)

        let buttonWidth = size.width * 0.75

        // Play Offline button
        playOfflineButton = createModeButton(
            text: "Play Offline",
            subtitle: "vs Computer or Local Players",
            color: SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0),
            yPos: size.height * 0.02
        )
        playOfflineButton.name = "playOfflineButton"
        modeSelectionContainer.addChild(playOfflineButton)

        // Create Online Game button
        createOnlineButton = createModeButton(
            text: "Create Online Game",
            subtitle: "Host a multiplayer match",
            color: SKColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0),
            yPos: -size.height * 0.10
        )
        createOnlineButton.name = "createOnlineButton"
        modeSelectionContainer.addChild(createOnlineButton)

        // Join Online Game button
        joinOnlineButton = createModeButton(
            text: "Join Online Game",
            subtitle: "Find a multiplayer match",
            color: SKColor(red: 0.6, green: 0.3, blue: 0.7, alpha: 1.0),
            yPos: -size.height * 0.22
        )
        joinOnlineButton.name = "joinOnlineButton"
        modeSelectionContainer.addChild(joinOnlineButton)

        // Check if Game Center is authenticated for online buttons
        updateOnlineButtonsState()
    }

    private func createModeButton(text: String, subtitle: String, color: SKColor, yPos: CGFloat) -> SKShapeNode {
        let buttonWidth = size.width * 0.75
        let buttonHeight: CGFloat = 70

        let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 12)
        button.position = CGPoint(x: 0, y: yPos)
        button.fillColor = color
        button.strokeColor = color.withAlphaComponent(0.7)
        button.lineWidth = 2

        let titleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        titleLabel.text = text
        titleLabel.fontSize = 18
        titleLabel.fontColor = .white
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: 0, y: 10)
        button.addChild(titleLabel)

        let subtitleLabel = SKLabelNode(fontNamed: "Helvetica")
        subtitleLabel.text = subtitle
        subtitleLabel.fontSize = 12
        subtitleLabel.fontColor = SKColor(white: 0.85, alpha: 1.0)
        subtitleLabel.verticalAlignmentMode = .center
        subtitleLabel.position = CGPoint(x: 0, y: -12)
        button.addChild(subtitleLabel)

        return button
    }

    private func updateOnlineButtonsState() {
        let isGameCenterAuth = GameManager.shared.isGameCenterAuthenticated

        createOnlineButton.alpha = isGameCenterAuth ? 1.0 : 0.5
        joinOnlineButton.alpha = isGameCenterAuth ? 1.0 : 0.5

        // Update subtitles if not authenticated
        if !isGameCenterAuth {
            if let subtitleLabel = createOnlineButton.children.compactMap({ $0 as? SKLabelNode }).last {
                subtitleLabel.text = "Game Center required"
                subtitleLabel.fontColor = SKColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0)
            }
            if let subtitleLabel = joinOnlineButton.children.compactMap({ $0 as? SKLabelNode }).last {
                subtitleLabel.text = "Game Center required"
                subtitleLabel.fontColor = SKColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 1.0)
            }
        }
    }

    // MARK: - Game Setup UI

    private func setupGameSetupUI() {
        gameSetupContainer = SKNode()
        addChild(gameSetupContainer)

        // Back button
        let backButtonSize: CGFloat = 40
        let backButton = SKShapeNode(rectOf: CGSize(width: backButtonSize, height: backButtonSize), cornerRadius: 8)
        backButton.position = CGPoint(x: -size.width/2 + 35, y: size.height/2 - 35)
        backButton.fillColor = SKColor(white: 0.2, alpha: 0.8)
        backButton.strokeColor = SKColor(white: 0.5, alpha: 1.0)
        backButton.lineWidth = 1
        backButton.name = "backButton"
        gameSetupContainer.addChild(backButton)

        // Back arrow
        let arrowPath = CGMutablePath()
        arrowPath.move(to: CGPoint(x: 5, y: 0))
        arrowPath.addLine(to: CGPoint(x: -5, y: 8))
        arrowPath.addLine(to: CGPoint(x: -5, y: -8))
        arrowPath.closeSubpath()
        let arrow = SKShapeNode(path: arrowPath)
        arrow.fillColor = .white
        arrow.strokeColor = .clear
        arrow.position = .zero
        backButton.addChild(arrow)

        // Logo (smaller, at top)
        if let logoTexture = SKTexture(imageNamed: "LudoLogo") as SKTexture? {
            let smallLogo = SKSpriteNode(texture: logoTexture)
            let maxWidth = size.width * 0.35
            let maxHeight = size.height * 0.12
            let scale = min(maxWidth / smallLogo.size.width, maxHeight / smallLogo.size.height)
            smallLogo.setScale(scale)
            smallLogo.position = CGPoint(x: 0, y: size.height * 0.38)
            gameSetupContainer.addChild(smallLogo)
        }

        // Welcome label
        welcomeLabel = SKLabelNode(fontNamed: "Helvetica")
        welcomeLabel.fontSize = 16
        welcomeLabel.fontColor = SKColor(white: 0.6, alpha: 1.0)
        welcomeLabel.position = CGPoint(x: 0, y: size.height * 0.30)
        gameSetupContainer.addChild(welcomeLabel)

        // Subtitle
        subtitleLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        subtitleLabel.text = "Select Players"
        subtitleLabel.fontSize = 22
        subtitleLabel.fontColor = .white
        subtitleLabel.position = CGPoint(x: 0, y: size.height * 0.22)
        gameSetupContainer.addChild(subtitleLabel)

        // Player selection buttons
        setupPlayerButtons()

        // Start game button
        setupStartButton()
    }

    private func setupPlayerButtons() {
        let colors: [PlayerColor] = [.red, .green, .yellow, .blue]
        let startY = size.height * 0.10
        let buttonWidth = size.width * 0.75

        for (index, color) in colors.enumerated() {
            let yPos = startY - CGFloat(index) * (buttonHeight + buttonSpacing)

            // Button background
            let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 10)
            button.position = CGPoint(x: 0, y: yPos)
            button.fillColor = color.color.withAlphaComponent(0.3)
            button.strokeColor = color.color
            button.lineWidth = 2
            button.name = "playerButton_\(color.rawValue)"
            gameSetupContainer.addChild(button)
            playerButtons[color] = button

            // Color name label (left side)
            let colorLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
            colorLabel.text = color.name
            colorLabel.fontSize = 18
            colorLabel.fontColor = color.color
            colorLabel.horizontalAlignmentMode = .left
            colorLabel.verticalAlignmentMode = .center
            colorLabel.position = CGPoint(x: -buttonWidth/2 + 20, y: yPos)
            gameSetupContainer.addChild(colorLabel)
            colorLabels[color] = colorLabel

            // Player type label (right side)
            let typeLabel = SKLabelNode(fontNamed: "Helvetica")
            typeLabel.fontSize = 16
            typeLabel.fontColor = .white
            typeLabel.horizontalAlignmentMode = .right
            typeLabel.verticalAlignmentMode = .center
            typeLabel.position = CGPoint(x: buttonWidth/2 - 20, y: yPos)
            gameSetupContainer.addChild(typeLabel)
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
        gameSetupContainer.addChild(startButton)

        startButtonLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        startButtonLabel.text = "START GAME"
        startButtonLabel.fontSize = 22
        startButtonLabel.fontColor = .white
        startButtonLabel.verticalAlignmentMode = .center
        startButtonLabel.position = CGPoint(x: 0, y: -size.height * 0.28)
        gameSetupContainer.addChild(startButtonLabel)
    }

    // MARK: - UI Updates

    private func updateVisibility() {
        if isLoggedIn {
            menuState = .modeSelection
        } else {
            menuState = .login
        }
        updateContainerVisibility()
    }

    private func updateContainerVisibility() {
        loginContainer.isHidden = menuState != .login
        modeSelectionContainer.isHidden = menuState != .modeSelection
        gameSetupContainer.isHidden = menuState != .offlineSetup

        if menuState == .modeSelection {
            // Update welcome label in mode selection
            if let welcomeLabel = modeSelectionContainer.childNode(withName: "modeWelcomeLabel") as? SKLabelNode {
                welcomeLabel.text = "Welcome, \(GameManager.shared.playerName)!"
            }
            updateOnlineButtonsState()
        } else if menuState == .offlineSetup {
            welcomeLabel.text = "Welcome, \(GameManager.shared.playerName)!"
        }
    }

    private func showModeSelection() {
        menuState = .modeSelection
        updateContainerVisibility()
    }

    private func showOfflineSetup() {
        menuState = .offlineSetup
        updateContainerVisibility()
    }

    private func updatePlayerButton(_ color: PlayerColor) {
        guard let label = playerLabels[color],
              let button = playerButtons[color] else { return }

        let isHuman = gameConfig.isHuman(color)
        label.text = isHuman ? "Human" : "Computer"

        // Update button appearance
        button.fillColor = isHuman ?
            color.color.withAlphaComponent(0.5) :
            color.color.withAlphaComponent(0.2)
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

        switch menuState {
        case .login:
            handleLoginTouch(at: location)
        case .modeSelection:
            handleModeSelectionTouch(at: location)
        case .offlineSetup:
            handleOfflineSetupTouch(at: location)
        }
    }

    private func handleLoginTouch(at location: CGPoint) {
        if signInButton.contains(location) {
            animateButtonPress(signInButton) { [weak self] in
                self?.menuDelegate?.menuSceneRequestsAppleSignIn()
            }
            return
        }

        if guestButton.contains(location) {
            animateButtonPress(guestButton) { [weak self] in
                self?.menuDelegate?.menuSceneRequestsGuestLogin()
            }
        }
    }

    private func handleModeSelectionTouch(at location: CGPoint) {
        // Play Offline button
        if playOfflineButton.contains(location) {
            animateButtonPress(playOfflineButton) { [weak self] in
                self?.showOfflineSetup()
            }
            return
        }

        // Create Online Game button
        if createOnlineButton.contains(location) && GameManager.shared.isGameCenterAuthenticated {
            animateButtonPress(createOnlineButton) { [weak self] in
                self?.menuDelegate?.menuSceneRequestsCreateOnlineGame()
            }
            return
        }

        // Join Online Game button
        if joinOnlineButton.contains(location) && GameManager.shared.isGameCenterAuthenticated {
            animateButtonPress(joinOnlineButton) { [weak self] in
                self?.menuDelegate?.menuSceneRequestsJoinOnlineGame()
            }
            return
        }
    }

    private func handleOfflineSetupTouch(at location: CGPoint) {
        // Check back button
        if let backButton = gameSetupContainer.childNode(withName: "backButton") as? SKShapeNode,
           backButton.contains(location) {
            animateButtonPress(backButton) { [weak self] in
                self?.showModeSelection()
            }
            return
        }

        // Player buttons
        for color in PlayerColor.allCases {
            if let button = playerButtons[color], button.contains(location) {
                togglePlayerType(color)
                return
            }
        }

        // Start button
        if startButton.contains(location) {
            animateButtonPress(startButton) { [weak self] in
                guard let self = self else { return }
                self.gameConfig.gameMode = .offline
                self.menuDelegate?.menuSceneDidStartGame(with: self.gameConfig)
            }
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
        updateVisibility()
    }
}
