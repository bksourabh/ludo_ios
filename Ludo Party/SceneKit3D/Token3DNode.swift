import SceneKit

/// 3D token/pawn for the Ludo game using SceneKit
class Token3DNode: SCNNode {

    let tokenColor: PlayerColor
    let tokenIndex: Int
    private var bodyNode: SCNNode!
    private var highlightNode: SCNNode?

    // Animation states
    private(set) var isAnimating: Bool = false
    private(set) var isSelected: Bool = false

    // Token dimensions
    private let baseRadius: CGFloat = 0.15
    private let tokenHeight: CGFloat = 0.4

    init(color: PlayerColor, index: Int) {
        self.tokenColor = color
        self.tokenIndex = index
        super.init()

        self.name = "token_\(color.name)_\(index)"
        setupToken()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupToken() {
        // Create token body - pawn shape
        bodyNode = createPawnShape()
        addChildNode(bodyNode)

        // Add subtle shadow plane
        let shadowPlane = SCNPlane(width: baseRadius * 2.5, height: baseRadius * 2.5)
        let shadowMaterial = SCNMaterial()
        shadowMaterial.diffuse.contents = UIColor.black.withAlphaComponent(0.3)
        shadowMaterial.isDoubleSided = true
        shadowPlane.materials = [shadowMaterial]

        let shadowNode = SCNNode(geometry: shadowPlane)
        shadowNode.eulerAngles.x = -.pi / 2
        shadowNode.position.y = 0.001
        shadowNode.opacity = 0.5
        addChildNode(shadowNode)
    }

    private func createPawnShape() -> SCNNode {
        let pawnNode = SCNNode()

        let color = tokenColor.color
        let darkColor = darkenColor(color, by: 0.3)
        let lightColor = lightenColor(color, by: 0.2)

        // Base - wide cylinder
        let base = SCNCylinder(radius: baseRadius, height: 0.05)
        let baseMaterial = SCNMaterial()
        baseMaterial.diffuse.contents = darkColor
        baseMaterial.specular.contents = UIColor.white
        baseMaterial.shininess = 0.7
        base.materials = [baseMaterial]

        let baseNode = SCNNode(geometry: base)
        baseNode.position.y = 0.025
        pawnNode.addChildNode(baseNode)

        // Lower body - tapered cylinder (using cone approximation)
        let lowerBody = SCNCone(topRadius: baseRadius * 0.6, bottomRadius: baseRadius * 0.9, height: 0.12)
        let bodyMaterial = SCNMaterial()
        bodyMaterial.diffuse.contents = color
        bodyMaterial.specular.contents = UIColor.white
        bodyMaterial.shininess = 0.8
        lowerBody.materials = [bodyMaterial]

        let lowerNode = SCNNode(geometry: lowerBody)
        lowerNode.position.y = 0.11
        pawnNode.addChildNode(lowerNode)

        // Middle body - cylinder
        let middleBody = SCNCylinder(radius: baseRadius * 0.55, height: 0.1)
        middleBody.materials = [bodyMaterial]

        let middleNode = SCNNode(geometry: middleBody)
        middleNode.position.y = 0.22
        pawnNode.addChildNode(middleNode)

        // Neck - tapered section
        let neck = SCNCone(topRadius: baseRadius * 0.35, bottomRadius: baseRadius * 0.5, height: 0.06)
        neck.materials = [bodyMaterial]

        let neckNode = SCNNode(geometry: neck)
        neckNode.position.y = 0.3
        pawnNode.addChildNode(neckNode)

        // Head - sphere
        let head = SCNSphere(radius: baseRadius * 0.45)
        let headMaterial = SCNMaterial()
        headMaterial.diffuse.contents = lightColor
        headMaterial.specular.contents = UIColor.white
        headMaterial.shininess = 0.9
        headMaterial.fresnelExponent = 1.5
        head.materials = [headMaterial]

        let headNode = SCNNode(geometry: head)
        headNode.position.y = 0.38
        pawnNode.addChildNode(headNode)

        // Add highlight ring around middle
        let ring = SCNTorus(ringRadius: baseRadius * 0.58, pipeRadius: 0.01)
        let ringMaterial = SCNMaterial()
        ringMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.6)
        ringMaterial.emission.contents = lightColor.withAlphaComponent(0.3)
        ring.materials = [ringMaterial]

        let ringNode = SCNNode(geometry: ring)
        ringNode.position.y = 0.17
        pawnNode.addChildNode(ringNode)

        return pawnNode
    }

    // MARK: - Selection & Highlighting

    func setSelected(_ selected: Bool, animated: Bool = true) {
        isSelected = selected

        if selected {
            showSelectionHighlight(animated: animated)
        } else {
            hideSelectionHighlight(animated: animated)
        }
    }

    private func showSelectionHighlight(animated: Bool) {
        // Remove existing highlight
        highlightNode?.removeFromParentNode()

        // Create pulsing ring highlight
        let highlightRing = SCNTorus(ringRadius: baseRadius * 1.3, pipeRadius: 0.02)
        let highlightMaterial = SCNMaterial()
        highlightMaterial.diffuse.contents = UIColor.white
        highlightMaterial.emission.contents = tokenColor.color
        highlightMaterial.emission.intensity = 1.0
        highlightRing.materials = [highlightMaterial]

        highlightNode = SCNNode(geometry: highlightRing)
        highlightNode?.position.y = 0.01
        addChildNode(highlightNode!)

        // Pulsing animation
        if animated {
            let pulseUp = SCNAction.scale(to: 1.2, duration: 0.4)
            pulseUp.timingMode = .easeInEaseOut
            let pulseDown = SCNAction.scale(to: 1.0, duration: 0.4)
            pulseDown.timingMode = .easeInEaseOut
            let pulse = SCNAction.sequence([pulseUp, pulseDown])
            highlightNode?.runAction(SCNAction.repeatForever(pulse))

            // Also pulse the token itself
            let tokenPulseUp = SCNAction.scale(to: 1.1, duration: 0.4)
            tokenPulseUp.timingMode = .easeInEaseOut
            let tokenPulseDown = SCNAction.scale(to: 1.0, duration: 0.4)
            tokenPulseDown.timingMode = .easeInEaseOut
            let tokenPulse = SCNAction.sequence([tokenPulseUp, tokenPulseDown])
            bodyNode.runAction(SCNAction.repeatForever(tokenPulse), forKey: "selectionPulse")
        }
    }

    private func hideSelectionHighlight(animated: Bool) {
        bodyNode.removeAction(forKey: "selectionPulse")

        if animated {
            highlightNode?.runAction(SCNAction.sequence([
                SCNAction.fadeOut(duration: 0.2),
                SCNAction.removeFromParentNode()
            ]))
            bodyNode.runAction(SCNAction.scale(to: 1.0, duration: 0.2))
        } else {
            highlightNode?.removeFromParentNode()
            bodyNode.scale = SCNVector3(1, 1, 1)
        }
        highlightNode = nil
    }

    // MARK: - Movement Animations

    /// Move token to a new position with hop animation
    func moveToPosition(_ position: SCNVector3, duration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        isAnimating = true

        let startPos = self.position
        let endPos = position
        let midPos = SCNVector3(
            (startPos.x + endPos.x) / 2,
            max(startPos.y, endPos.y) + 0.3, // Hop height
            (startPos.z + endPos.z) / 2
        )

        // Create bezier-like path using keyframe animation
        let moveAnimation = CAKeyframeAnimation(keyPath: "position")
        moveAnimation.values = [
            NSValue(scnVector3: startPos),
            NSValue(scnVector3: midPos),
            NSValue(scnVector3: endPos)
        ]
        moveAnimation.keyTimes = [0, 0.5, 1]
        moveAnimation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn)
        ]
        moveAnimation.duration = duration
        moveAnimation.fillMode = .forwards
        moveAnimation.isRemovedOnCompletion = false

        // Slight rotation during hop
        let rotateAnimation = CAKeyframeAnimation(keyPath: "eulerAngles.z")
        rotateAnimation.values = [0, Float.pi * 0.1, 0]
        rotateAnimation.keyTimes = [0, 0.5, 1]
        rotateAnimation.duration = duration

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.position = endPos
            self?.removeAllAnimations()
            self?.isAnimating = false
            completion?()
        }

        addAnimation(moveAnimation, forKey: "move")
        addAnimation(rotateAnimation, forKey: "rotate")

        CATransaction.commit()
    }

    /// Animate token entering the board from yard
    func animateEnterBoard(to position: SCNVector3, completion: (() -> Void)? = nil) {
        isAnimating = true

        // Start from below and pop up
        let startY = self.position.y
        self.position.y = startY - 0.5
        self.opacity = 0

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.4
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        SCNTransaction.completionBlock = { [weak self] in
            self?.moveToPosition(position, duration: 0.3) {
                self?.bounceOnLand()
                completion?()
            }
        }

        self.position.y = startY
        self.opacity = 1

        SCNTransaction.commit()
    }

    /// Animate token reaching home
    func animateReachHome(completion: (() -> Void)? = nil) {
        isAnimating = true

        // Celebration spin and scale up, then back to normal
        let spinAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 4, z: 0, duration: 0.8)
        let scaleUp = SCNAction.scale(to: 1.5, duration: 0.4)
        let scaleDown = SCNAction.scale(to: 1.0, duration: 0.4)
        let scaleSequence = SCNAction.sequence([scaleUp, scaleDown])

        let group = SCNAction.group([spinAction, scaleSequence])

        runAction(group) { [weak self] in
            self?.isAnimating = false
            completion?()
        }
    }

    /// Animate token being captured (sent back to yard)
    func animateCaptured(yardPosition: SCNVector3, completion: (() -> Void)? = nil) {
        isAnimating = true

        // Flash red, shrink, move to yard, pop back
        let flashRed = SCNAction.customAction(duration: 0.2) { [weak self] node, time in
            let progress = CGFloat(time) / 0.2
            if progress < 0.5 {
                self?.setEmissionColor(UIColor.red.withAlphaComponent(progress * 2))
            } else {
                self?.setEmissionColor(UIColor.red.withAlphaComponent(2 - progress * 2))
            }
        }

        let shrink = SCNAction.scale(to: 0.3, duration: 0.2)
        let moveToYard = SCNAction.move(to: yardPosition, duration: 0.3)
        let popBack = SCNAction.scale(to: 1.0, duration: 0.2)
        popBack.timingMode = .easeOut

        let sequence = SCNAction.sequence([flashRed, shrink, moveToYard, popBack])

        runAction(sequence) { [weak self] in
            self?.setEmissionColor(.clear)
            self?.isAnimating = false
            completion?()
        }
    }

    /// Small bounce on landing
    private func bounceOnLand() {
        let bounceUp = SCNAction.moveBy(x: 0, y: 0.1, z: 0, duration: 0.1)
        bounceUp.timingMode = .easeOut
        let bounceDown = SCNAction.moveBy(x: 0, y: -0.1, z: 0, duration: 0.1)
        bounceDown.timingMode = .easeIn

        let smallBounceUp = SCNAction.moveBy(x: 0, y: 0.05, z: 0, duration: 0.08)
        let smallBounceDown = SCNAction.moveBy(x: 0, y: -0.05, z: 0, duration: 0.08)

        let bounce = SCNAction.sequence([bounceUp, bounceDown, smallBounceUp, smallBounceDown])
        runAction(bounce)
    }

    // MARK: - Helper Methods

    private func setEmissionColor(_ color: UIColor) {
        bodyNode.enumerateChildNodes { node, _ in
            if let geometry = node.geometry {
                for material in geometry.materials {
                    material.emission.contents = color
                }
            }
        }
    }

    private func darkenColor(_ color: UIColor, by amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return UIColor(hue: hue, saturation: saturation, brightness: max(brightness - amount, 0), alpha: alpha)
    }

    private func lightenColor(_ color: UIColor, by amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return UIColor(hue: hue, saturation: min(saturation - amount * 0.5, 1), brightness: min(brightness + amount, 1), alpha: alpha)
    }
}

// MARK: - SCNVector3 Extension for NSValue

extension NSValue {
    convenience init(scnVector3: SCNVector3) {
        var vector = scnVector3
        self.init(bytes: &vector, objCType: "{SCNVector3=fff}")
    }
}
