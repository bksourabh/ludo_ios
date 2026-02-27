import SpriteKit

/// SpriteKit node representing the dice
class DiceNode: SKNode {
    let size: CGFloat

    private var backgroundNode: SKShapeNode!
    private var dotsContainer: SKNode!
    private var currentValue: Int = 1
    private var glowNode: SKShapeNode?
    private var currentDotColor: SKColor = SKColor(white: 0.2, alpha: 1.0)
    private var currentPlayerColor: PlayerColor?

    var isEnabled: Bool = true {
        didSet {
            alpha = isEnabled ? 1.0 : 0.5
        }
    }

    init(size: CGFloat) {
        self.size = size
        super.init()

        self.name = "dice"
        setupVisuals()
        showValue(1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVisuals() {
        // Shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.15)
        shadow.fillColor = SKColor(white: 0, alpha: 0.3)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 3, y: -3)
        shadow.zPosition = 0
        addChild(shadow)

        // Main dice body
        backgroundNode = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.15)
        backgroundNode.fillColor = .white
        backgroundNode.strokeColor = SKColor(white: 0.3, alpha: 1.0)
        backgroundNode.lineWidth = 2
        backgroundNode.zPosition = 1
        addChild(backgroundNode)

        // Container for dots
        dotsContainer = SKNode()
        dotsContainer.zPosition = 2
        addChild(dotsContainer)
    }

    /// Show a specific dice value
    func showValue(_ value: Int) {
        currentValue = value
        updateDots()
    }

    private func updateDots() {
        dotsContainer.removeAllChildren()

        let dotPositions = DiceFace.dotPositions(for: currentValue)
        let dotRadius = size * 0.08
        let padding = size * 0.15

        for pos in dotPositions {
            let dot = SKShapeNode(circleOfRadius: dotRadius)
            dot.fillColor = currentDotColor
            dot.strokeColor = .clear

            // Convert normalized position to actual position
            let x = (pos.x - 0.5) * (size - padding * 2)
            let y = (pos.y - 0.5) * (size - padding * 2)
            dot.position = CGPoint(x: x, y: y)

            dotsContainer.addChild(dot)
        }
    }

    /// Animate rolling the dice
    /// - Note: Does NOT re-enable the dice after animation. Caller is responsible for
    ///   setting isEnabled = true when appropriate (e.g., for human player turns only).
    func animateRoll(finalValue: Int, duration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        isEnabled = false

        // Play dice rolling sound
        let soundAction = SKAction.playSoundFileNamed("dice.mp3", waitForCompletion: false)
        run(soundAction)

        let numberOfFrames = 6
        let frameDuration = duration / Double(numberOfFrames)

        // Create sequence of random values
        var actions: [SKAction] = []

        for i in 0..<numberOfFrames {
            let isLast = i == numberOfFrames - 1
            let value = isLast ? finalValue : Int.random(in: 1...6)

            let showAction = SKAction.run { [weak self] in
                self?.showValue(value)
            }

            // Add rotation for visual effect
            let rotate = SKAction.rotate(byAngle: .pi / 4, duration: frameDuration * 0.5)
            let rotateBack = SKAction.rotate(byAngle: -.pi / 4, duration: frameDuration * 0.5)

            let wait = SKAction.wait(forDuration: frameDuration)
            let frame = SKAction.group([showAction, SKAction.sequence([rotate, rotateBack]), wait])

            actions.append(frame)
        }

        // Add bounce effect at the end
        let bounceUp = SKAction.moveBy(x: 0, y: 10, duration: 0.1)
        let bounceDown = SKAction.moveBy(x: 0, y: -10, duration: 0.15)
        bounceDown.timingMode = .easeIn
        let bounce = SKAction.sequence([bounceUp, bounceDown])

        actions.append(bounce)

        let sequence = SKAction.sequence(actions)

        // Caller controls isEnabled — we do NOT re-enable here
        run(sequence) {
            completion?()
        }
    }

    /// Shake animation for invalid action
    func shake() {
        let moveLeft = SKAction.moveBy(x: -5, y: 0, duration: 0.05)
        let moveRight = SKAction.moveBy(x: 10, y: 0, duration: 0.1)
        let moveBack = SKAction.moveBy(x: -5, y: 0, duration: 0.05)

        let shake = SKAction.sequence([moveLeft, moveRight, moveBack])
        run(SKAction.repeat(shake, count: 2))
    }

    /// Show glowing effect with the current player's color
    func showGlow(color: PlayerColor) {
        hideGlow()

        let glowSize = size + 12
        glowNode = SKShapeNode(rectOf: CGSize(width: glowSize, height: glowSize), cornerRadius: size * 0.2)
        glowNode?.fillColor = .clear
        glowNode?.strokeColor = color.color
        glowNode?.lineWidth = 4
        glowNode?.glowWidth = 10
        glowNode?.zPosition = -0.5
        addChild(glowNode!)

        // Pulse animation on the glow
        let fadeOut = SKAction.fadeAlpha(to: 0.4, duration: 0.5)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        let pulse = SKAction.sequence([fadeOut, fadeIn])
        glowNode?.run(SKAction.repeatForever(pulse))
    }

    /// Remove the glowing effect
    func hideGlow() {
        glowNode?.removeFromParent()
        glowNode = nil
    }

    /// Check if point is within dice area
    func isPointInside(_ point: CGPoint) -> Bool {
        guard let parentNode = parent else { return false }
        let localPoint = convert(point, from: parentNode)
        let halfSize = size / 2
        return abs(localPoint.x) <= halfSize && abs(localPoint.y) <= halfSize
    }

    /// Set dice color to match current player
    func setPlayerColor(_ color: PlayerColor) {
        backgroundNode.strokeColor = color.color
        backgroundNode.lineWidth = 3
    }

    /// Set full dice appearance for player's turn
    /// Changes dice fill color to player's color and dot color based on player
    func setFullPlayerColor(_ color: PlayerColor) {
        currentPlayerColor = color

        // Set dice fill color to player's color
        backgroundNode.fillColor = color.color
        backgroundNode.strokeColor = color.color.withAlphaComponent(0.8)
        backgroundNode.lineWidth = 3

        // Set dot color: white for red, green, blue; black for yellow
        switch color {
        case .yellow:
            currentDotColor = .black
        case .red, .green, .blue:
            currentDotColor = .white
        }

        // Update dots with new color
        updateDots()
    }

    /// Reset to default appearance
    func resetAppearance() {
        backgroundNode.fillColor = .white
        backgroundNode.strokeColor = SKColor(white: 0.3, alpha: 1.0)
        backgroundNode.lineWidth = 2
        currentDotColor = SKColor(white: 0.2, alpha: 1.0)
        currentPlayerColor = nil
        updateDots()
    }
}
