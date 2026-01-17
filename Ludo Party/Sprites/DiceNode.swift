import SpriteKit

/// SpriteKit node representing the dice
class DiceNode: SKNode {
    let size: CGFloat

    private var backgroundNode: SKShapeNode!
    private var dotsContainer: SKNode!
    private var currentValue: Int = 1

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
            dot.fillColor = SKColor(white: 0.2, alpha: 1.0)
            dot.strokeColor = .clear

            // Convert normalized position to actual position
            let x = (pos.x - 0.5) * (size - padding * 2)
            let y = (pos.y - 0.5) * (size - padding * 2)
            dot.position = CGPoint(x: x, y: y)

            dotsContainer.addChild(dot)
        }
    }

    /// Animate rolling the dice
    func animateRoll(finalValue: Int, duration: TimeInterval = 0.8, completion: (() -> Void)? = nil) {
        isEnabled = false

        let numberOfFrames = 12
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

        run(sequence) { [weak self] in
            self?.isEnabled = true
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

    /// Highlight effect when it's time to roll
    func showRollPrompt() {
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.3)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
        let pulse = SKAction.sequence([scaleUp, scaleDown])

        run(SKAction.repeatForever(pulse), withKey: "rollPrompt")
    }

    /// Stop the roll prompt animation
    func hideRollPrompt() {
        removeAction(forKey: "rollPrompt")
        run(SKAction.scale(to: 1.0, duration: 0.1))
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

    /// Reset to default appearance
    func resetAppearance() {
        backgroundNode.strokeColor = SKColor(white: 0.3, alpha: 1.0)
        backgroundNode.lineWidth = 2
    }
}
