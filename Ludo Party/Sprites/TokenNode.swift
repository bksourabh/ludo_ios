import SpriteKit

/// SpriteKit node representing a game token/piece
class TokenNode: SKNode {
    let token: Token
    let size: CGFloat

    private var bodyNode: SKShapeNode!
    private var highlightNode: SKShapeNode?
    private var turnGlowNode: SKShapeNode?

    var isHighlighted: Bool = false {
        didSet {
            updateHighlight()
        }
    }

    /// Whether this token's player is the current turn player
    var isTurnActive: Bool = false {
        didSet {
            updateTurnGlow()
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

    private func updateTurnGlow() {
        if isTurnActive {
            if turnGlowNode == nil {
                let radius = size * 0.55
                turnGlowNode = SKShapeNode(circleOfRadius: radius)
                turnGlowNode?.fillColor = .clear
                turnGlowNode?.strokeColor = token.color.color
                turnGlowNode?.lineWidth = 2
                turnGlowNode?.zPosition = 8
                turnGlowNode?.glowWidth = 6
                addChild(turnGlowNode!)

                // Subtle pulse animation
                let fadeOut = SKAction.fadeAlpha(to: 0.5, duration: 0.7)
                let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.7)
                let pulse = SKAction.sequence([fadeOut, fadeIn])
                turnGlowNode?.run(SKAction.repeatForever(pulse))
            }
        } else {
            turnGlowNode?.removeFromParent()
            turnGlowNode = nil
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

    /// Animate capture (visible movement back to yard)
    func animateCapture(to yardPosition: CGPoint, completion: (() -> Void)? = nil) {
        // Flash red to indicate capture
        let flashRed = SKAction.colorize(with: .red, colorBlendFactor: 0.8, duration: 0.1)
        let flashBack = SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
        let flash = SKAction.sequence([flashRed, flashBack, flashRed, flashBack])

        // Shrink slightly while moving
        let shrinkDown = SKAction.scale(to: 0.7, duration: 0.1)

        // Calculate arc movement back to yard
        let currentPos = self.position
        let midPoint = CGPoint(
            x: (currentPos.x + yardPosition.x) / 2,
            y: max(currentPos.y, yardPosition.y) + 80  // Arc above both points
        )

        // Move in an arc: first to midpoint (going up), then to yard (going down)
        let moveToMid = SKAction.move(to: midPoint, duration: 0.3)
        moveToMid.timingMode = .easeOut
        let moveToYard = SKAction.move(to: yardPosition, duration: 0.3)
        moveToYard.timingMode = .easeIn
        let arcMove = SKAction.sequence([moveToMid, moveToYard])

        // Grow back to normal size at the end
        let growBack = SKAction.scale(to: 1.0, duration: 0.2)

        // Bounce effect when landing
        let bounceUp = SKAction.scale(to: 1.15, duration: 0.1)
        let bounceDown = SKAction.scale(to: 1.0, duration: 0.1)
        let bounce = SKAction.sequence([bounceUp, bounceDown])

        // Combine: flash + shrink, then arc move, then grow + bounce
        let startEffects = SKAction.group([flash, shrinkDown])
        let endEffects = SKAction.sequence([growBack, bounce])

        let fullSequence = SKAction.sequence([startEffects, arcMove, endEffects])
        run(fullSequence) {
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
