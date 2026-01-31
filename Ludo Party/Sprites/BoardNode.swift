import SpriteKit

/// SpriteKit node that renders the Ludo board
class BoardNode: SKNode {
    let boardSize: CGFloat
    let ludoBoard: LudoBoard
    let cellSize: CGFloat
    var gameConfig: GameConfig?

    private let backgroundColor = SKColor(white: 0.95, alpha: 1.0)
    private let lineColor = SKColor(white: 0.3, alpha: 1.0)

    private var yardHighlightNode: SKShapeNode?
    private var currentHighlightedColor: PlayerColor?

    init(size: CGFloat, gameConfig: GameConfig? = nil) {
        self.boardSize = size
        self.cellSize = size / 15.0
        self.ludoBoard = LudoBoard(boardSize: size)
        self.gameConfig = gameConfig
        super.init()

        // Set board origin for position calculations (bottom-left of board)
        ludoBoard.setOrigin(CGPoint(x: -size/2, y: -size/2))

        drawBoard()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Coordinate Helpers

    /// Convert grid (col, row) to screen position (center of cell)
    private func gridToScreen(col: Int, row: Int) -> CGPoint {
        let x = -boardSize/2 + (CGFloat(col) + 0.5) * cellSize
        let y = -boardSize/2 + (CGFloat(row) + 0.5) * cellSize
        return CGPoint(x: x, y: y)
    }

    /// Get cell rectangle in screen coordinates
    private func cellRect(col: Int, row: Int) -> CGRect {
        let x = -boardSize/2 + CGFloat(col) * cellSize
        let y = -boardSize/2 + CGFloat(row) * cellSize
        return CGRect(x: x, y: y, width: cellSize, height: cellSize)
    }

    // MARK: - Drawing

    private func drawBoard() {
        // Draw background
        let background = SKShapeNode(rectOf: CGSize(width: boardSize, height: boardSize))
        background.fillColor = backgroundColor
        background.strokeColor = lineColor
        background.lineWidth = 2
        background.zPosition = -10
        addChild(background)

        // Draw colored yards (4 corners)
        drawYards()

        // Draw the track cells
        drawTrack()

        // Draw home paths (colored paths to center)
        drawHomePaths()

        // Draw center home area
        drawCenterHome()

        // Draw start position markers
        drawStartPositions()

        // Draw safe square stars
        drawSafeSquares()

        // Draw yard token circles
        drawYardCircles()

        // Draw player type indicators (human/AI)
        drawPlayerTypeIndicators()
    }

    private func drawYards() {
        // Red yard: bottom-left (cols 0-5, rows 0-5)
        drawYard(startCol: 0, startRow: 0, color: .red)
        // Green yard: top-left (cols 0-5, rows 9-14)
        drawYard(startCol: 0, startRow: 9, color: .green)
        // Yellow yard: top-right (cols 9-14, rows 9-14)
        drawYard(startCol: 9, startRow: 9, color: .yellow)
        // Blue yard: bottom-right (cols 9-14, rows 0-5)
        drawYard(startCol: 9, startRow: 0, color: .blue)
    }

    private func drawYard(startCol: Int, startRow: Int, color: PlayerColor) {
        // Yard covers the entire 6x6 cell block
        let yardSize = cellSize * 6

        // Outer colored rectangle (covers entire block)
        let x = -boardSize/2 + CGFloat(startCol) * cellSize
        let y = -boardSize/2 + CGFloat(startRow) * cellSize
        let outerRect = SKShapeNode(rect: CGRect(x: x, y: y, width: yardSize, height: yardSize), cornerRadius: 4)
        outerRect.fillColor = color.color
        outerRect.strokeColor = lineColor
        outerRect.lineWidth = 2
        outerRect.zPosition = -5
        addChild(outerRect)

        // Inner white area (margin determines colored border width)
        let margin = cellSize * 0.8
        let innerRect = SKShapeNode(rect: CGRect(
            x: x + margin,
            y: y + margin,
            width: yardSize - margin * 2,
            height: yardSize - margin * 2
        ), cornerRadius: 4)
        innerRect.fillColor = .white
        innerRect.strokeColor = lineColor
        innerRect.lineWidth = 1
        innerRect.zPosition = -4
        addChild(innerRect)
    }

    private func drawTrack() {
        // Draw the cross-shaped track
        // Vertical arm: columns 6-8, rows 0-5 and 9-14
        // Horizontal arm: rows 6-8, columns 0-5 and 9-14

        // Draw all track cells (the cross shape excluding yards and center)
        for row in 0..<15 {
            for col in 0..<15 {
                // Check if this is a track cell
                let isVerticalArm = (col >= 6 && col <= 8) && (row <= 5 || row >= 9)
                let isHorizontalArm = (row >= 6 && row <= 8) && (col <= 5 || col >= 9)

                if isVerticalArm || isHorizontalArm {
                    let rect = cellRect(col: col, row: row)
                    let cell = SKShapeNode(rect: rect)
                    cell.fillColor = .white
                    cell.strokeColor = lineColor
                    cell.lineWidth = 0.5
                    cell.zPosition = -3
                    addChild(cell)
                }
            }
        }
    }

    private func drawHomePaths() {
        // Red home path: column 7, rows 1-6 (going up towards center)
        for row in 1...6 {
            drawHomePathCell(col: 7, row: row, color: .red)
        }

        // Green home path: row 7, columns 1-6 (going right towards center)
        for col in 1...6 {
            drawHomePathCell(col: col, row: 7, color: .green)
        }

        // Yellow home path: column 7, rows 8-13 (going down towards center)
        for row in 8...13 {
            drawHomePathCell(col: 7, row: row, color: .yellow)
        }

        // Blue home path: row 7, columns 8-13 (going left towards center)
        for col in 8...13 {
            drawHomePathCell(col: col, row: 7, color: .blue)
        }
    }

    private func drawHomePathCell(col: Int, row: Int, color: PlayerColor) {
        let rect = cellRect(col: col, row: row)
        let cell = SKShapeNode(rect: rect)
        cell.fillColor = color.lightColor
        cell.strokeColor = color.color
        cell.lineWidth = 1
        cell.zPosition = -2
        addChild(cell)
    }

    private func drawCenterHome() {
        let centerSize = cellSize * 3
        let center = CGPoint(x: 0, y: 0) // Board is centered

        // White background
        let centerBg = SKShapeNode(rectOf: CGSize(width: centerSize, height: centerSize))
        centerBg.position = center
        centerBg.fillColor = .white
        centerBg.strokeColor = lineColor
        centerBg.lineWidth = 2
        centerBg.zPosition = -1
        addChild(centerBg)

        // Draw colored triangles (cover entire center square)
        let triangleSize = centerSize

        // Red triangle (bottom, pointing up)
        drawTriangle(at: center, size: triangleSize, color: .red, rotation: 0)
        // Blue triangle (left, pointing right)
        drawTriangle(at: center, size: triangleSize, color: .blue, rotation: .pi / 2)
        // Yellow triangle (top, pointing down)
        drawTriangle(at: center, size: triangleSize, color: .yellow, rotation: .pi)
        // Green triangle (right, pointing left)
        drawTriangle(at: center, size: triangleSize, color: .green, rotation: -.pi / 2)
    }

    private func drawTriangle(at center: CGPoint, size: CGFloat, color: PlayerColor, rotation: CGFloat) {
        let path = CGMutablePath()
        // Triangle pointing up from bottom
        path.move(to: CGPoint(x: -size/2, y: -size/2))
        path.addLine(to: CGPoint(x: size/2, y: -size/2))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()

        let triangle = SKShapeNode(path: path)
        triangle.fillColor = color.color
        triangle.strokeColor = lineColor
        triangle.lineWidth = 1
        triangle.position = center
        triangle.zRotation = rotation
        triangle.zPosition = 0
        addChild(triangle)
    }

    private func drawStartPositions() {
        let startPositions: [(col: Int, row: Int, color: PlayerColor)] = [
            (6, 1, .red),
            (1, 8, .green),
            (8, 13, .yellow),
            (13, 6, .blue)
        ]

        for (col, row, color) in startPositions {
            let rect = cellRect(col: col, row: row)
            let pos = gridToScreen(col: col, row: row)

            // Colored background for the entire cell
            let bg = SKShapeNode(rect: rect)
            bg.fillColor = color.color
            bg.strokeColor = lineColor
            bg.lineWidth = 0.5
            bg.zPosition = -2
            addChild(bg)

            // Glowing halo circle
            let halo = SKShapeNode(circleOfRadius: cellSize * 0.35)
            halo.position = pos
            halo.fillColor = .clear
            halo.strokeColor = .white
            halo.lineWidth = 2
            halo.glowWidth = 6
            halo.zPosition = 2
            addChild(halo)
        }
    }

    private func drawSafeSquares() {
        // Safe squares are at specific positions on the track
        // Standard Ludo has safe squares at: 0, 8, 13, 21, 26, 34, 39, 47
        // Stars only at the "5 before start" safe positions
        // (starting positions are also safe but marked with colored circles instead)
        let safePositions: [(col: Int, row: Int)] = [
            (8, 2),   // Position 47 — 5 before Red start
            (2, 6),   // Position 8  — 5 before Green start
            (6, 12),  // Position 21 — 5 before Yellow start
            (12, 8)   // Position 34 — 5 before Blue start
        ]

        for (col, row) in safePositions {
            let pos = gridToScreen(col: col, row: row)
            let star = createStar(size: cellSize * 0.3)
            star.position = pos
            star.fillColor = SKColor(white: 0.9, alpha: 1.0)
            star.strokeColor = SKColor(white: 0.4, alpha: 1.0)
            star.lineWidth = 1
            star.zPosition = 2
            addChild(star)
        }
    }

    private func createStar(size: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        let points = 5
        let innerRadius = size * 0.4
        let outerRadius = size

        for i in 0..<points * 2 {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let point = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return SKShapeNode(path: path)
    }

    private func drawYardCircles() {
        // Draw circles in each yard where tokens start
        // Use LudoBoard's calculated positions to ensure perfect alignment
        let circleRadius = cellSize * 0.32

        for color in PlayerColor.allCases {
            let positions = ludoBoard.yardCirclePositions(for: color)

            for pos in positions {
                let circle = SKShapeNode(circleOfRadius: circleRadius)
                circle.position = pos
                circle.fillColor = color.lightColor
                circle.strokeColor = color.color
                circle.lineWidth = 2
                circle.zPosition = 3
                addChild(circle)
            }
        }
    }

    /// Get the LudoBoard for position calculations
    func getBoard() -> LudoBoard {
        return ludoBoard
    }

    // MARK: - Player Type Indicators

    private func drawPlayerTypeIndicators() {
        guard let config = gameConfig else { return }

        for color in PlayerColor.allCases {
            let isHuman = config.isHuman(color)
            drawPlayerTypeIndicator(for: color, isHuman: isHuman)
        }
    }

    private func drawPlayerTypeIndicator(for color: PlayerColor, isHuman: Bool) {
        let yardSize = cellSize * 6

        // Get yard position based on color
        let (startCol, startRow): (Int, Int)
        switch color {
        case .red:
            startCol = 0; startRow = 0
        case .green:
            startCol = 0; startRow = 9
        case .yellow:
            startCol = 9; startRow = 9
        case .blue:
            startCol = 9; startRow = 0
        }

        let yardX = -boardSize/2 + CGFloat(startCol) * cellSize
        let yardY = -boardSize/2 + CGFloat(startRow) * cellSize

        // Badge size and position (top-left corner of yard)
        let badgeSize = cellSize * 0.85
        let badgeMargin = cellSize * 0.2
        let badgeX = yardX + badgeMargin + badgeSize/2
        let badgeY = yardY + yardSize - badgeMargin - badgeSize/2

        // Create badge background with frosted glass effect
        let badgeBg = SKShapeNode(circleOfRadius: badgeSize/2)
        badgeBg.position = CGPoint(x: badgeX, y: badgeY)
        badgeBg.fillColor = SKColor(white: 1.0, alpha: 0.95)
        badgeBg.strokeColor = color.color
        badgeBg.lineWidth = 2.5
        badgeBg.zPosition = 6
        addChild(badgeBg)

        // Add subtle shadow
        let shadow = SKShapeNode(circleOfRadius: badgeSize/2 + 1)
        shadow.position = CGPoint(x: badgeX + 1, y: badgeY - 1)
        shadow.fillColor = SKColor(white: 0, alpha: 0.15)
        shadow.strokeColor = .clear
        shadow.zPosition = 5.5
        addChild(shadow)

        // Create the icon
        let iconSize = badgeSize * 0.55
        let icon: SKNode
        if isHuman {
            icon = createHumanIcon(size: iconSize, color: color)
        } else {
            icon = createComputerIcon(size: iconSize, color: color)
        }
        icon.position = CGPoint(x: badgeX, y: badgeY)
        icon.zPosition = 7
        addChild(icon)

        // Add subtle label below icon
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.text = isHuman ? "YOU" : "CPU"
        label.fontSize = badgeSize * 0.22
        label.fontColor = color.color.withAlphaComponent(0.9)
        label.position = CGPoint(x: badgeX, y: badgeY - badgeSize * 0.28)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 7
        addChild(label)
    }

    private func createHumanIcon(size: CGFloat, color: PlayerColor) -> SKNode {
        let container = SKNode()

        // Head (circle)
        let headRadius = size * 0.28
        let head = SKShapeNode(circleOfRadius: headRadius)
        head.position = CGPoint(x: 0, y: size * 0.18)
        head.fillColor = color.color
        head.strokeColor = color.color.withAlphaComponent(0.8)
        head.lineWidth = 1
        container.addChild(head)

        // Body (shoulders arc)
        let bodyPath = CGMutablePath()
        let bodyWidth = size * 0.7
        let bodyHeight = size * 0.35

        // Create rounded shoulders shape
        bodyPath.move(to: CGPoint(x: -bodyWidth/2, y: -size * 0.15))
        bodyPath.addQuadCurve(
            to: CGPoint(x: bodyWidth/2, y: -size * 0.15),
            control: CGPoint(x: 0, y: -size * 0.05)
        )
        bodyPath.addLine(to: CGPoint(x: bodyWidth/2 * 0.7, y: -size * 0.15 - bodyHeight))
        bodyPath.addQuadCurve(
            to: CGPoint(x: -bodyWidth/2 * 0.7, y: -size * 0.15 - bodyHeight),
            control: CGPoint(x: 0, y: -size * 0.15 - bodyHeight * 0.8)
        )
        bodyPath.closeSubpath()

        let body = SKShapeNode(path: bodyPath)
        body.fillColor = color.color
        body.strokeColor = color.color.withAlphaComponent(0.8)
        body.lineWidth = 1
        container.addChild(body)

        return container
    }

    private func createComputerIcon(size: CGFloat, color: PlayerColor) -> SKNode {
        let container = SKNode()

        // Robot head (rounded rectangle)
        let headWidth = size * 0.65
        let headHeight = size * 0.5
        let headRect = CGRect(x: -headWidth/2, y: -headHeight/2 + size * 0.08, width: headWidth, height: headHeight)
        let head = SKShapeNode(rect: headRect, cornerRadius: size * 0.08)
        head.fillColor = color.color
        head.strokeColor = color.color.withAlphaComponent(0.8)
        head.lineWidth = 1
        container.addChild(head)

        // Eyes (two small circles)
        let eyeRadius = size * 0.08
        let eyeSpacing = size * 0.18
        let eyeY = size * 0.15

        let leftEye = SKShapeNode(circleOfRadius: eyeRadius)
        leftEye.position = CGPoint(x: -eyeSpacing, y: eyeY)
        leftEye.fillColor = .white
        leftEye.strokeColor = .clear
        container.addChild(leftEye)

        let rightEye = SKShapeNode(circleOfRadius: eyeRadius)
        rightEye.position = CGPoint(x: eyeSpacing, y: eyeY)
        rightEye.fillColor = .white
        rightEye.strokeColor = .clear
        container.addChild(rightEye)

        // Mouth (small rectangle grid pattern)
        let mouthWidth = size * 0.3
        let mouthHeight = size * 0.1
        let mouthY = -size * 0.02
        let mouth = SKShapeNode(rect: CGRect(x: -mouthWidth/2, y: mouthY - mouthHeight/2, width: mouthWidth, height: mouthHeight), cornerRadius: 2)
        mouth.fillColor = .white
        mouth.strokeColor = .clear
        container.addChild(mouth)

        // Antenna
        let antennaHeight = size * 0.15
        let antennaY = headHeight/2 + size * 0.08
        let antennaLine = SKShapeNode(rect: CGRect(x: -1, y: antennaY, width: 2, height: antennaHeight))
        antennaLine.fillColor = color.color
        antennaLine.strokeColor = .clear
        container.addChild(antennaLine)

        let antennaBall = SKShapeNode(circleOfRadius: size * 0.06)
        antennaBall.position = CGPoint(x: 0, y: antennaY + antennaHeight)
        antennaBall.fillColor = color.color.withAlphaComponent(0.7)
        antennaBall.strokeColor = color.color
        antennaBall.lineWidth = 1
        container.addChild(antennaBall)

        // Body (smaller rectangle below head)
        let bodyWidth = size * 0.5
        let bodyHeight = size * 0.25
        let bodyY = -headHeight/2 - size * 0.02
        let bodyRect = CGRect(x: -bodyWidth/2, y: bodyY - bodyHeight, width: bodyWidth, height: bodyHeight)
        let body = SKShapeNode(rect: bodyRect, cornerRadius: size * 0.04)
        body.fillColor = color.color
        body.strokeColor = color.color.withAlphaComponent(0.8)
        body.lineWidth = 1
        container.addChild(body)

        return container
    }

    // MARK: - Yard Highlighting

    /// Highlight a player's yard with a glowing effect
    func highlightYard(for color: PlayerColor) {
        // Remove existing highlight if any
        unhighlightYard()

        currentHighlightedColor = color
        let yardSize = cellSize * 6

        // Get yard position based on color
        let (startCol, startRow): (Int, Int)
        switch color {
        case .red:
            startCol = 0; startRow = 0
        case .green:
            startCol = 0; startRow = 9
        case .yellow:
            startCol = 9; startRow = 9
        case .blue:
            startCol = 9; startRow = 0
        }

        let x = -boardSize/2 + CGFloat(startCol) * cellSize
        let y = -boardSize/2 + CGFloat(startRow) * cellSize

        // Create glow highlight around the yard
        yardHighlightNode = SKShapeNode(rect: CGRect(x: x, y: y, width: yardSize, height: yardSize), cornerRadius: 4)
        yardHighlightNode?.fillColor = .clear
        yardHighlightNode?.strokeColor = color.color
        yardHighlightNode?.lineWidth = 4
        yardHighlightNode?.glowWidth = 8
        yardHighlightNode?.zPosition = 5
        addChild(yardHighlightNode!)

        // Add pulsing animation
        let fadeOut = SKAction.fadeAlpha(to: 0.4, duration: 0.6)
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.6)
        let pulse = SKAction.sequence([fadeOut, fadeIn])
        yardHighlightNode?.run(SKAction.repeatForever(pulse))
    }

    /// Remove yard highlight
    func unhighlightYard() {
        yardHighlightNode?.removeFromParent()
        yardHighlightNode = nil
        currentHighlightedColor = nil
    }
}
