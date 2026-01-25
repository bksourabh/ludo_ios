import SceneKit

/// 3D dice for the Ludo game using SceneKit
class Dice3DNode: SCNNode {

    private var diceBody: SCNNode!
    private var dotNodes: [[SCNNode]] = [] // Dots for each face
    private(set) var currentValue: Int = 1
    private(set) var isRolling: Bool = false

    var isEnabled: Bool = true {
        didSet {
            opacity = isEnabled ? 1.0 : 0.5
        }
    }

    // Dice dimensions
    private let diceSize: CGFloat = 0.3
    private let cornerRadius: CGFloat = 0.04
    private let dotRadius: CGFloat = 0.025

    // Face orientations for each dice value (euler angles to show that face up)
    private let faceOrientations: [Int: SCNVector3] = [
        1: SCNVector3(0, 0, 0),                          // 1 on top
        2: SCNVector3(-Float.pi/2, 0, 0),                // 2 on top
        3: SCNVector3(0, 0, Float.pi/2),                 // 3 on top
        4: SCNVector3(0, 0, -Float.pi/2),                // 4 on top
        5: SCNVector3(Float.pi/2, 0, 0),                 // 5 on top
        6: SCNVector3(Float.pi, 0, 0)                    // 6 on top
    ]

    override init() {
        super.init()
        self.name = "dice"
        setupDice()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupDice() {
        // Create rounded cube for dice body
        diceBody = createDiceBody()
        addChildNode(diceBody)

        // Add dots to all faces
        addDotsToAllFaces()

        // Add shadow
        addShadow()
    }

    private func createDiceBody() -> SCNNode {
        // Use a box with chamfer for rounded corners
        let box = SCNBox(width: diceSize, height: diceSize, length: diceSize, chamferRadius: cornerRadius)

        // Create materials for the dice
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.specular.contents = UIColor.white
        material.shininess = 0.8
        material.fresnelExponent = 1.0

        box.materials = [material]

        let node = SCNNode(geometry: box)
        return node
    }

    private func addDotsToAllFaces() {
        // Face 1 (top - Y+) - 1 dot in center
        addDots(to: .yPositive, pattern: [[0.5, 0.5]])

        // Face 6 (bottom - Y-) - 6 dots
        addDots(to: .yNegative, pattern: [
            [0.25, 0.25], [0.25, 0.5], [0.25, 0.75],
            [0.75, 0.25], [0.75, 0.5], [0.75, 0.75]
        ])

        // Face 2 (front - Z+) - 2 dots diagonal
        addDots(to: .zPositive, pattern: [[0.25, 0.75], [0.75, 0.25]])

        // Face 5 (back - Z-) - 5 dots
        addDots(to: .zNegative, pattern: [
            [0.25, 0.25], [0.25, 0.75],
            [0.5, 0.5],
            [0.75, 0.25], [0.75, 0.75]
        ])

        // Face 3 (right - X+) - 3 dots diagonal
        addDots(to: .xPositive, pattern: [[0.25, 0.75], [0.5, 0.5], [0.75, 0.25]])

        // Face 4 (left - X-) - 4 dots in corners
        addDots(to: .xNegative, pattern: [
            [0.25, 0.25], [0.25, 0.75],
            [0.75, 0.25], [0.75, 0.75]
        ])
    }

    private enum DiceFace {
        case xPositive, xNegative, yPositive, yNegative, zPositive, zNegative
    }

    private func addDots(to face: DiceFace, pattern: [[CGFloat]]) {
        var faceDotsNodes: [SCNNode] = []
        let halfSize = diceSize / 2
        let offset: CGFloat = 0.001 // Slight offset to prevent z-fighting

        for pos in pattern {
            let dot = SCNCylinder(radius: dotRadius, height: 0.01)
            let dotMaterial = SCNMaterial()
            dotMaterial.diffuse.contents = UIColor(white: 0.15, alpha: 1.0)
            dot.materials = [dotMaterial]

            let dotNode = SCNNode(geometry: dot)

            // Convert normalized position (0-1) to local coordinates
            let localX = (pos[0] - 0.5) * diceSize * 0.7
            let localY = (pos[1] - 0.5) * diceSize * 0.7

            switch face {
            case .yPositive:
                dotNode.position = SCNVector3(localX, halfSize + offset, localY)
                dotNode.eulerAngles.x = 0
            case .yNegative:
                dotNode.position = SCNVector3(localX, -halfSize - offset, -localY)
                dotNode.eulerAngles.x = .pi
            case .zPositive:
                dotNode.position = SCNVector3(localX, localY, halfSize + offset)
                dotNode.eulerAngles.x = .pi / 2
            case .zNegative:
                dotNode.position = SCNVector3(-localX, localY, -halfSize - offset)
                dotNode.eulerAngles.x = -.pi / 2
            case .xPositive:
                dotNode.position = SCNVector3(halfSize + offset, localY, -localX)
                dotNode.eulerAngles.z = -.pi / 2
            case .xNegative:
                dotNode.position = SCNVector3(-halfSize - offset, localY, localX)
                dotNode.eulerAngles.z = .pi / 2
            }

            diceBody.addChildNode(dotNode)
            faceDotsNodes.append(dotNode)
        }

        dotNodes.append(faceDotsNodes)
    }

    private func addShadow() {
        let shadowPlane = SCNPlane(width: diceSize * 1.5, height: diceSize * 1.5)
        let shadowMaterial = SCNMaterial()
        shadowMaterial.diffuse.contents = UIColor.black.withAlphaComponent(0.3)
        shadowMaterial.isDoubleSided = true
        shadowPlane.materials = [shadowMaterial]

        let shadowNode = SCNNode(geometry: shadowPlane)
        shadowNode.eulerAngles.x = -Float.pi / 2
        shadowNode.position.y = Float(-diceSize / 2 - 0.01)
        shadowNode.opacity = 0.5
        shadowNode.name = "shadow"
        addChildNode(shadowNode)
    }

    // MARK: - Dice Rolling

    /// Roll the dice with 3D animation
    func roll(finalValue: Int, duration: TimeInterval = 1.2, completion: (() -> Void)? = nil) {
        guard !isRolling else { return }
        isRolling = true
        isEnabled = false

        // Phase 1: Jump up
        let jumpHeight: Float = 0.8
        let startPosition = position

        // Create physics-like rolling animation
        let totalSpins = Int.random(in: 3...5)
        let randomAxis = SCNVector3(
            Float.random(in: 0.5...1.0),
            Float.random(in: 0.5...1.0),
            Float.random(in: 0.5...1.0)
        ).normalized()

        // Jump up animation
        let jumpUp = SCNAction.moveBy(x: 0, y: CGFloat(jumpHeight), z: 0, duration: duration * 0.2)
        jumpUp.timingMode = .easeOut

        // Tumble rotation during flight
        let spinAngle = CGFloat(totalSpins) * .pi * 2
        let tumbleRotation = SCNAction.rotate(by: spinAngle, around: randomAxis, duration: duration * 0.6)

        // Fall down animation
        let fallDown = SCNAction.move(to: startPosition, duration: duration * 0.2)
        fallDown.timingMode = .easeIn

        // Final orientation to show the correct value
        guard let finalOrientation = faceOrientations[finalValue] else {
            completion?()
            return
        }

        let snapToValue = SCNAction.rotateTo(
            x: CGFloat(finalOrientation.x),
            y: CGFloat(finalOrientation.y),
            z: CGFloat(finalOrientation.z),
            duration: duration * 0.1
        )

        // Bounce animation
        let bounceUp = SCNAction.moveBy(x: 0, y: 0.1, z: 0, duration: duration * 0.05)
        bounceUp.timingMode = .easeOut
        let bounceDown = SCNAction.moveBy(x: 0, y: -0.1, z: 0, duration: duration * 0.05)
        bounceDown.timingMode = .easeIn

        // Small bounce
        let smallBounceUp = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: duration * 0.03)
        let smallBounceDown = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: duration * 0.03)

        // Shadow animation during jump
        if let shadowNode = childNode(withName: "shadow", recursively: false) {
            let shadowShrink = SCNAction.scale(to: 0.5, duration: duration * 0.3)
            let shadowWait = SCNAction.wait(duration: duration * 0.4)
            let shadowGrow = SCNAction.scale(to: 1.0, duration: duration * 0.3)
            shadowNode.runAction(SCNAction.sequence([shadowShrink, shadowWait, shadowGrow]))

            let shadowFade = SCNAction.fadeOpacity(to: 0.2, duration: duration * 0.3)
            let shadowFadeBack = SCNAction.fadeOpacity(to: 0.5, duration: duration * 0.3)
            shadowNode.runAction(SCNAction.sequence([shadowFade, shadowWait, shadowFadeBack]))
        }

        // Main animation sequence
        let animation = SCNAction.sequence([
            jumpUp,
            SCNAction.group([
                tumbleRotation,
                SCNAction.sequence([
                    SCNAction.wait(duration: duration * 0.4),
                    fallDown
                ])
            ]),
            snapToValue,
            bounceUp,
            bounceDown,
            smallBounceUp,
            smallBounceDown
        ])

        runAction(animation) { [weak self] in
            self?.currentValue = finalValue
            self?.isRolling = false
            self?.isEnabled = true
            completion?()
        }
    }

    /// Show specific value without animation
    func showValue(_ value: Int) {
        guard let orientation = faceOrientations[value] else { return }
        currentValue = value
        diceBody.eulerAngles = orientation
    }

    // MARK: - Visual Effects

    /// Highlight dice when it's the player's turn to roll
    func showRollPrompt() {
        // Gentle floating animation
        let floatUp = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 0.5)
        floatUp.timingMode = .easeInEaseOut
        let floatDown = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 0.5)
        floatDown.timingMode = .easeInEaseOut

        let float = SCNAction.sequence([floatUp, floatDown])
        runAction(SCNAction.repeatForever(float), forKey: "rollPrompt")

        // Add glow effect
        if let material = diceBody.geometry?.firstMaterial {
            material.emission.contents = UIColor.yellow.withAlphaComponent(0.3)
        }
    }

    /// Stop roll prompt animation
    func hideRollPrompt() {
        removeAction(forKey: "rollPrompt")

        // Reset position
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.2
        position.y = position.y.rounded() // Snap to nearest whole position
        SCNTransaction.commit()

        // Remove glow
        if let material = diceBody.geometry?.firstMaterial {
            material.emission.contents = UIColor.clear
        }
    }

    /// Set dice border color to match current player
    func setPlayerColor(_ color: PlayerColor) {
        if let material = diceBody.geometry?.firstMaterial {
            material.emission.contents = color.color.withAlphaComponent(0.2)
        }
    }

    /// Reset to default appearance
    func resetAppearance() {
        if let material = diceBody.geometry?.firstMaterial {
            material.emission.contents = UIColor.clear
        }
    }

    /// Shake animation for invalid action
    func shake() {
        let shakeLeft = SCNAction.moveBy(x: -0.03, y: 0, z: 0, duration: 0.05)
        let shakeRight = SCNAction.moveBy(x: 0.06, y: 0, z: 0, duration: 0.1)
        let shakeBack = SCNAction.moveBy(x: -0.03, y: 0, z: 0, duration: 0.05)

        let shake = SCNAction.sequence([shakeLeft, shakeRight, shakeBack])
        runAction(SCNAction.repeat(shake, count: 2))
    }
}

// MARK: - SCNVector3 Extension

extension SCNVector3 {
    func normalized() -> SCNVector3 {
        let length = sqrt(x * x + y * y + z * z)
        guard length > 0 else { return self }
        return SCNVector3(x / length, y / length, z / length)
    }
}
