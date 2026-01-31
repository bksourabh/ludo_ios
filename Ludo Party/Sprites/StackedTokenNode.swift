import SpriteKit

/// SpriteKit node representing multiple tokens from different colors stacked at the same position
/// Displays as a circle divided into colored sections (pie chart style)
class StackedTokenNode: SKNode {
    private(set) var colors: [PlayerColor] = []
    let size: CGFloat

    private var sectionsContainer: SKNode!
    private var glowNode: SKShapeNode?
    private var currentGlowColor: PlayerColor?

    /// The tokens represented by this stacked node
    private(set) var tokens: [Token] = []

    init(size: CGFloat) {
        self.size = size
        super.init()

        sectionsContainer = SKNode()
        sectionsContainer.zPosition = 10
        addChild(sectionsContainer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Update the stacked token with the given tokens
    func update(with tokens: [Token], currentTurnColor: PlayerColor) {
        self.tokens = tokens
        self.colors = tokens.map { $0.color }

        redrawSections()
        updateGlow(for: currentTurnColor)
    }

    /// Redraw all the colored sections
    private func redrawSections() {
        sectionsContainer.removeAllChildren()

        guard colors.count >= 2 else { return }

        let radius = size * 0.4
        let uniqueColors = Array(Set(colors)).sorted { $0.rawValue < $1.rawValue }
        let sectionCount = uniqueColors.count
        let anglePerSection = CGFloat.pi * 2 / CGFloat(sectionCount)

        // Draw each section
        for (index, color) in uniqueColors.enumerated() {
            let startAngle = CGFloat(index) * anglePerSection - CGFloat.pi / 2
            let endAngle = startAngle + anglePerSection

            let section = createSection(
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                color: color
            )
            sectionsContainer.addChild(section)
        }

        // Add border circle
        let border = SKShapeNode(circleOfRadius: radius)
        border.fillColor = .clear
        border.strokeColor = SKColor(white: 0.2, alpha: 1.0)
        border.lineWidth = 2
        border.zPosition = 11
        sectionsContainer.addChild(border)

        // Add center highlight for 3D effect
        let highlightRadius = radius * 0.3
        let highlight = SKShapeNode(circleOfRadius: highlightRadius)
        highlight.fillColor = SKColor(white: 1.0, alpha: 0.3)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -radius * 0.15, y: radius * 0.15)
        highlight.zPosition = 12
        sectionsContainer.addChild(highlight)
    }

    /// Create a pie section shape
    private func createSection(radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, color: PlayerColor) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addArc(center: .zero, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()

        let section = SKShapeNode(path: path)
        section.fillColor = color.color
        section.strokeColor = SKColor(white: 0.2, alpha: 1.0)
        section.lineWidth = 1
        section.zPosition = 10

        return section
    }

    /// Update the glow to show whose turn it is
    func updateGlow(for turnColor: PlayerColor) {
        // Only show glow if this turn's color is in the stack
        let hasCurrentTurnColor = colors.contains(turnColor)

        if hasCurrentTurnColor {
            if glowNode == nil || currentGlowColor != turnColor {
                // Remove old glow
                glowNode?.removeFromParent()

                // Create new glow
                let radius = size * 0.55
                glowNode = SKShapeNode(circleOfRadius: radius)
                glowNode?.fillColor = .clear
                glowNode?.strokeColor = turnColor.color
                glowNode?.lineWidth = 3
                glowNode?.zPosition = 8
                glowNode?.glowWidth = 8
                addChild(glowNode!)

                // Pulse animation
                let fadeOut = SKAction.fadeAlpha(to: 0.4, duration: 0.6)
                let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.6)
                let pulse = SKAction.sequence([fadeOut, fadeIn])
                glowNode?.run(SKAction.repeatForever(pulse))

                currentGlowColor = turnColor
            }
        } else {
            glowNode?.removeFromParent()
            glowNode = nil
            currentGlowColor = nil
        }
    }

    /// Hide the glow
    func hideGlow() {
        glowNode?.removeFromParent()
        glowNode = nil
        currentGlowColor = nil
    }

    /// Check if a point is within this stacked token
    func isPointInside(_ point: CGPoint) -> Bool {
        guard let parentNode = parent else { return false }
        let localPoint = convert(point, from: parentNode)
        let radius = size * 0.4
        return localPoint.x * localPoint.x + localPoint.y * localPoint.y <= radius * radius
    }

    /// Get the token of a specific color from this stack
    func token(for color: PlayerColor) -> Token? {
        return tokens.first { $0.color == color }
    }

    /// Check if this stack contains a token of the given color
    func containsColor(_ color: PlayerColor) -> Bool {
        return colors.contains(color)
    }
}
