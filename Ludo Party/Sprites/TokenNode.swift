import SpriteKit

/// SpriteKit node representing a game token/piece
class TokenNode: SKNode {
    let token: Token
    let size: CGFloat

    private var bodyNode: SKShapeNode!
    private var highlightNode: SKShapeNode?

    var isHighlighted: Bool = false {
        didSet {
            updateHighlight()
        }
    }

    init(token: Token, size: CGFloat) {
        self.token = token
        self.size = size
        super.init()

        self.name = token.identifier
        setupVisuals()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupVisuals() {
        let radius = size * 0.4

        // Main body - circular token
        bodyNode = SKShapeNode(circleOfRadius: radius)
        bodyNode.fillColor = token.color.color
        bodyNode.strokeColor = SKColor(white: 0.2, alpha: 1.0)
        bodyNode.lineWidth = 2
        bodyNode.zPosition = 10
        addChild(bodyNode)

        // Inner circle for 3D effect
        let innerRadius = radius * 0.6
        let innerCircle = SKShapeNode(circleOfRadius: innerRadius)
        innerCircle.fillColor = token.color.lightColor
        innerCircle.strokeColor = .clear
        innerCircle.position = CGPoint(x: -radius * 0.15, y: radius * 0.15)
        innerCircle.zPosition = 11
        addChild(innerCircle)

        // Token number/index
        let label = SKLabelNode(text: "\(token.index + 1)")
        label.fontName = "Helvetica-Bold"
        label.fontSize = size * 0.3
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 12
        addChild(label)
    }

    private func updateHighlight() {
        if isHighlighted {
            if highlightNode == nil {
                let radius = size * 0.5
                highlightNode = SKShapeNode(circleOfRadius: radius)
                highlightNode?.fillColor = .clear
                highlightNode?.strokeColor = SKColor.white
                highlightNode?.lineWidth = 3
                highlightNode?.zPosition = 9
                highlightNode?.glowWidth = 5
                addChild(highlightNode!)

                // Pulse animation
                let scaleUp = SKAction.scale(to: 1.15, duration: 0.3)
                let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
                let pulse = SKAction.sequence([scaleUp, scaleDown])
                highlightNode?.run(SKAction.repeatForever(pulse))
            }
        } else {
            highlightNode?.removeFromParent()
            highlightNode = nil
        }
    }

    /// Animate moving to a new position
    func animateMove(to position: CGPoint, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        let moveAction = SKAction.move(to: position, duration: duration)
        moveAction.timingMode = .easeInEaseOut

        // Add a slight hop effect
        let hopUp = SKAction.moveBy(x: 0, y: 10, duration: duration * 0.3)
        let hopDown = SKAction.moveBy(x: 0, y: -10, duration: duration * 0.3)
        hopUp.timingMode = .easeOut
        hopDown.timingMode = .easeIn

        let hop = SKAction.sequence([hopUp, hopDown])
        let moveWithHop = SKAction.group([moveAction, hop])

        run(moveWithHop) {
            completion?()
        }
    }

    /// Animate capture (disappear and reappear in yard)
    func animateCapture(to yardPosition: CGPoint, completion: (() -> Void)? = nil) {
        // Shrink and fade
        let shrink = SKAction.scale(to: 0.1, duration: 0.2)
        let fade = SKAction.fadeOut(withDuration: 0.2)
        let disappear = SKAction.group([shrink, fade])

        // Move to yard
        let move = SKAction.move(to: yardPosition, duration: 0.01)

        // Grow and appear
        let grow = SKAction.scale(to: 1.0, duration: 0.3)
        let appear = SKAction.fadeIn(withDuration: 0.3)
        let reappear = SKAction.group([grow, appear])

        let sequence = SKAction.sequence([disappear, move, reappear])
        run(sequence) {
            completion?()
        }
    }

    /// Animate reaching home
    func animateReachHome(completion: (() -> Void)? = nil) {
        // Celebration effect
        let scaleUp = SKAction.scale(to: 1.3, duration: 0.2)
        let scaleDown = SKAction.scale(to: 0.8, duration: 0.3)
        let normalize = SKAction.scale(to: 1.0, duration: 0.1)

        let colorize = SKAction.colorize(with: .yellow, colorBlendFactor: 0.5, duration: 0.3)
        let uncolorize = SKAction.colorize(withColorBlendFactor: 0, duration: 0.2)

        let scaleSeq = SKAction.sequence([scaleUp, scaleDown, normalize])
        let colorSeq = SKAction.sequence([colorize, uncolorize])

        let celebrate = SKAction.group([scaleSeq, colorSeq])
        run(celebrate) {
            completion?()
        }
    }

    /// Check if a point is within this token
    func isPointInside(_ point: CGPoint) -> Bool {
        guard let parentNode = parent else { return false }
        let localPoint = convert(point, from: parentNode)
        let radius = size * 0.4
        return localPoint.x * localPoint.x + localPoint.y * localPoint.y <= radius * radius
    }
}
