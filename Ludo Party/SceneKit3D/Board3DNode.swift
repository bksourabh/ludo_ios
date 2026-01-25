import SceneKit
import SpriteKit

/// 3D Ludo board using SceneKit
class Board3DNode: SCNNode {

    // MARK: - Properties

    let boardSize: CGFloat
    let cellSize: CGFloat
    let gridSize: Int = 15

    // Position mappings
    private(set) var trackPositions: [Int: SCNVector3] = [:]
    private(set) var homePathPositions: [PlayerColor: [SCNVector3]] = [:]
    private(set) var yardPositions: [PlayerColor: [SCNVector3]] = [:]
    private(set) var homePositions: [PlayerColor: SCNVector3] = [:]

    // Visual nodes
    private var boardBase: SCNNode!
    private var cellNodes: [SCNNode] = []

    // MARK: - Initialization

    /// Default initializer with standard board size
    override init() {
        self.boardSize = 7.0  // Default size in scene units
        self.cellSize = 7.0 / CGFloat(gridSize)
        super.init()

        setupBoard()
        calculatePositions()
    }

    init(size: CGFloat) {
        self.boardSize = size
        self.cellSize = size / CGFloat(gridSize)
        super.init()

        setupBoard()
        calculatePositions()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Board Setup

    private func setupBoard() {
        // Create base board
        let baseGeometry = SCNBox(width: boardSize, height: 0.1, length: boardSize, chamferRadius: 0.02)
        let baseMaterial = SCNMaterial()
        baseMaterial.diffuse.contents = UIColor(white: 0.95, alpha: 1.0)
        baseMaterial.roughness.contents = 0.3
        baseGeometry.materials = [baseMaterial]

        boardBase = SCNNode(geometry: baseGeometry)
        boardBase.position = SCNVector3(0, -0.05, 0)
        addChildNode(boardBase)

        // Create board frame
        createBoardFrame()

        // Create the four home areas (corners)
        createHomeAreas()

        // Create the track cells
        createTrackCells()

        // Create the home paths
        createHomePaths()

        // Create center home triangles
        createCenterHome()

        // Add safe square markers
        createSafeSquareMarkers()
    }

    private func createBoardFrame() {
        let frameThickness: CGFloat = 0.05
        let frameHeight: CGFloat = 0.15

        let frameMaterial = SCNMaterial()
        frameMaterial.diffuse.contents = UIColor(red: 0.4, green: 0.25, blue: 0.1, alpha: 1.0)
        frameMaterial.roughness.contents = 0.7

        // Four sides of the frame
        let positions = [
            SCNVector3(0, frameHeight/2, boardSize/2 + frameThickness/2),
            SCNVector3(0, frameHeight/2, -boardSize/2 - frameThickness/2),
            SCNVector3(boardSize/2 + frameThickness/2, frameHeight/2, 0),
            SCNVector3(-boardSize/2 - frameThickness/2, frameHeight/2, 0)
        ]

        let sizes = [
            SCNVector3(boardSize + frameThickness * 2, frameHeight, frameThickness),
            SCNVector3(boardSize + frameThickness * 2, frameHeight, frameThickness),
            SCNVector3(frameThickness, frameHeight, boardSize),
            SCNVector3(frameThickness, frameHeight, boardSize)
        ]

        for i in 0..<4 {
            let frameGeometry = SCNBox(width: CGFloat(sizes[i].x), height: CGFloat(sizes[i].y), length: CGFloat(sizes[i].z), chamferRadius: 0.01)
            frameGeometry.materials = [frameMaterial]
            let frameNode = SCNNode(geometry: frameGeometry)
            frameNode.position = positions[i]
            addChildNode(frameNode)
        }
    }

    private func createHomeAreas() {
        let homeAreaSize = cellSize * 6
        let homeAreaOffset = boardSize / 2 - homeAreaSize / 2

        let colors: [(PlayerColor, SCNVector3)] = [
            (.red, SCNVector3(-homeAreaOffset, 0.01, -homeAreaOffset)),
            (.green, SCNVector3(homeAreaOffset, 0.01, -homeAreaOffset)),
            (.yellow, SCNVector3(homeAreaOffset, 0.01, homeAreaOffset)),
            (.blue, SCNVector3(-homeAreaOffset, 0.01, homeAreaOffset))
        ]

        for (playerColor, position) in colors {
            createHomeArea(color: playerColor, at: position, size: homeAreaSize)
        }
    }

    private func createHomeArea(color: PlayerColor, at position: SCNVector3, size: CGFloat) {
        // Home area base
        let baseGeometry = SCNBox(width: size, height: 0.02, length: size, chamferRadius: 0.01)
        let baseMaterial = SCNMaterial()
        baseMaterial.diffuse.contents = color.uiColor.withAlphaComponent(0.3)
        baseMaterial.roughness.contents = 0.5
        baseGeometry.materials = [baseMaterial]

        let baseNode = SCNNode(geometry: baseGeometry)
        baseNode.position = position
        addChildNode(baseNode)

        // Home area border
        let borderGeometry = SCNBox(width: size, height: 0.05, length: size, chamferRadius: 0.01)
        let borderMaterial = SCNMaterial()
        borderMaterial.diffuse.contents = color.uiColor
        borderMaterial.roughness.contents = 0.3
        borderMaterial.transparency = 0.0
        borderGeometry.materials = [borderMaterial]

        // Create border frame (hollow)
        let borderThickness: CGFloat = cellSize * 0.15
        let innerSize = size - borderThickness * 2

        // Create four border sides
        let borderPositions = [
            SCNVector3(0, 0.025, size/2 - borderThickness/2),
            SCNVector3(0, 0.025, -size/2 + borderThickness/2),
            SCNVector3(size/2 - borderThickness/2, 0.025, 0),
            SCNVector3(-size/2 + borderThickness/2, 0.025, 0)
        ]

        let borderSizes = [
            (size, borderThickness),
            (size, borderThickness),
            (borderThickness, size - borderThickness * 2),
            (borderThickness, size - borderThickness * 2)
        ]

        for i in 0..<4 {
            let sideGeometry = SCNBox(width: borderSizes[i].0, height: 0.03, length: borderSizes[i].1, chamferRadius: 0.005)
            sideGeometry.materials = [borderMaterial]
            let sideNode = SCNNode(geometry: sideGeometry)
            sideNode.position = SCNVector3(
                position.x + borderPositions[i].x,
                position.y + borderPositions[i].y,
                position.z + borderPositions[i].z
            )
            addChildNode(sideNode)
        }

        // Create yard positions (4 circles for tokens)
        let yardOffset = size * 0.25
        let yardCircleRadius = cellSize * 0.6

        var yardPos: [SCNVector3] = []

        let offsets: [(CGFloat, CGFloat)] = [
            (-yardOffset, -yardOffset),
            (yardOffset, -yardOffset),
            (-yardOffset, yardOffset),
            (yardOffset, yardOffset)
        ]

        for (xOff, zOff) in offsets {
            let circleGeometry = SCNCylinder(radius: yardCircleRadius, height: 0.02)
            let circleMaterial = SCNMaterial()
            circleMaterial.diffuse.contents = UIColor.white
            circleMaterial.roughness.contents = 0.3
            circleGeometry.materials = [circleMaterial]

            let circleNode = SCNNode(geometry: circleGeometry)
            circleNode.position = SCNVector3(
                position.x + Float(xOff),
                0.02,
                position.z + Float(zOff)
            )
            addChildNode(circleNode)

            // Add colored ring
            let ringGeometry = SCNTorus(ringRadius: yardCircleRadius, pipeRadius: 0.02)
            let ringMaterial = SCNMaterial()
            ringMaterial.diffuse.contents = color.uiColor
            ringGeometry.materials = [ringMaterial]

            let ringNode = SCNNode(geometry: ringGeometry)
            ringNode.position = circleNode.position
            ringNode.position.y = 0.03
            addChildNode(ringNode)

            yardPos.append(circleNode.position)
        }

        yardPositions[color] = yardPos
    }

    private func createTrackCells() {
        let cellHeight: CGFloat = 0.015

        // Define track layout - 52 cells around the board
        // The track goes around the board in a specific pattern
        for i in 0..<52 {
            let position = getTrackCellPosition(index: i)
            let color = getTrackCellColor(index: i)

            let cellGeometry = SCNBox(width: cellSize * 0.9, height: cellHeight, length: cellSize * 0.9, chamferRadius: 0.005)
            let cellMaterial = SCNMaterial()
            cellMaterial.diffuse.contents = color
            cellMaterial.roughness.contents = 0.4
            cellGeometry.materials = [cellMaterial]

            let cellNode = SCNNode(geometry: cellGeometry)
            cellNode.position = position
            cellNode.name = "track_\(i)"
            addChildNode(cellNode)
            cellNodes.append(cellNode)

            trackPositions[i] = position
        }
    }

    private func getTrackCellPosition(index: Int) -> SCNVector3 {
        let halfBoard = Float(boardSize / 2)
        let cell = Float(cellSize)
        let trackOffset = cell * 6.5  // Distance from center to track

        // Calculate position based on index
        // Track layout: 13 cells per side, starting from red's start position

        let segment = index / 13
        let posInSegment = index % 13

        var x: Float = 0
        var z: Float = 0

        switch segment {
        case 0: // Red side (bottom) - going right
            if posInSegment < 6 {
                x = -trackOffset + cell * Float(posInSegment)
                z = trackOffset
            } else if posInSegment == 6 {
                x = -cell * 0.5
                z = halfBoard - cell * 0.5
            } else {
                x = cell * 0.5
                z = halfBoard - cell * Float(posInSegment - 6)
            }

        case 1: // Green side (right) - going up
            if posInSegment < 6 {
                x = trackOffset
                z = trackOffset - cell * Float(posInSegment)
            } else if posInSegment == 6 {
                x = halfBoard - cell * 0.5
                z = cell * 0.5
            } else {
                x = halfBoard - cell * Float(posInSegment - 6)
                z = -cell * 0.5
            }

        case 2: // Yellow side (top) - going left
            if posInSegment < 6 {
                x = trackOffset - cell * Float(posInSegment)
                z = -trackOffset
            } else if posInSegment == 6 {
                x = cell * 0.5
                z = -halfBoard + cell * 0.5
            } else {
                x = -cell * 0.5
                z = -halfBoard + cell * Float(posInSegment - 6)
            }

        case 3: // Blue side (left) - going down
            if posInSegment < 6 {
                x = -trackOffset
                z = -trackOffset + cell * Float(posInSegment)
            } else if posInSegment == 6 {
                x = -halfBoard + cell * 0.5
                z = -cell * 0.5
            } else {
                x = -halfBoard + cell * Float(posInSegment - 6)
                z = cell * 0.5
            }

        default:
            break
        }

        let trackCellHeight: CGFloat = 0.015
        return SCNVector3(x, Float(trackCellHeight / 2 + 0.01), z)
    }

    private func getTrackCellColor(index: Int) -> UIColor {
        // Start positions are colored
        let startPositions = [0, 13, 26, 39]
        let colors: [UIColor] = [
            PlayerColor.red.uiColor,
            PlayerColor.green.uiColor,
            PlayerColor.yellow.uiColor,
            PlayerColor.blue.uiColor
        ]

        if let startIndex = startPositions.firstIndex(of: index) {
            return colors[startIndex]
        }

        // Safe squares (stars)
        let safeSquares = [8, 21, 34, 47]
        if safeSquares.contains(index) {
            return UIColor(white: 0.9, alpha: 1.0)
        }

        return UIColor.white
    }

    private func createHomePaths() {
        let cellHeight: CGFloat = 0.015

        let colors: [PlayerColor] = [.red, .green, .yellow, .blue]

        for color in colors {
            var pathPositions: [SCNVector3] = []

            for i in 0..<6 {
                let position = getHomePathPosition(color: color, index: i)

                let cellGeometry = SCNBox(width: cellSize * 0.85, height: cellHeight, length: cellSize * 0.85, chamferRadius: 0.005)
                let cellMaterial = SCNMaterial()
                cellMaterial.diffuse.contents = color.uiColor.withAlphaComponent(0.7)
                cellMaterial.roughness.contents = 0.4
                cellGeometry.materials = [cellMaterial]

                let cellNode = SCNNode(geometry: cellGeometry)
                cellNode.position = position
                cellNode.name = "homepath_\(color.rawValue)_\(i)"
                addChildNode(cellNode)

                pathPositions.append(position)
            }

            homePathPositions[color] = pathPositions
        }
    }

    private func getHomePathPosition(color: PlayerColor, index: Int) -> SCNVector3 {
        let cell = Float(cellSize)
        let offset = cell * (Float(index) + 1)

        switch color {
        case .red:
            return SCNVector3(-cell * 0.5, 0.02, cell * 6 - offset)
        case .green:
            return SCNVector3(cell * 6 - offset, 0.02, -cell * 0.5)
        case .yellow:
            return SCNVector3(cell * 0.5, 0.02, -cell * 6 + offset)
        case .blue:
            return SCNVector3(-cell * 6 + offset, 0.02, cell * 0.5)
        }
    }

    private func createCenterHome() {
        // Center triangles for each color
        let triangleSize = Float(cellSize * 2.5)

        let colors: [PlayerColor] = [.red, .green, .yellow, .blue]
        let rotations: [Float] = [0, .pi / 2, .pi, .pi * 3 / 2]

        for (i, color) in colors.enumerated() {
            // Create triangle using custom geometry
            let trianglePath = UIBezierPath()
            trianglePath.move(to: CGPoint(x: 0, y: CGFloat(triangleSize)))
            trianglePath.addLine(to: CGPoint(x: CGFloat(-triangleSize * 0.6), y: 0))
            trianglePath.addLine(to: CGPoint(x: CGFloat(triangleSize * 0.6), y: 0))
            trianglePath.close()

            let triangleShape = SCNShape(path: trianglePath, extrusionDepth: 0.02)
            let triangleMaterial = SCNMaterial()
            triangleMaterial.diffuse.contents = color.uiColor
            triangleMaterial.roughness.contents = 0.3
            triangleShape.materials = [triangleMaterial]

            let triangleNode = SCNNode(geometry: triangleShape)
            triangleNode.eulerAngles.x = -.pi / 2
            triangleNode.eulerAngles.z = rotations[i]
            triangleNode.position = SCNVector3(0, 0.02, 0)
            addChildNode(triangleNode)

            // Store home position at center
            homePositions[color] = SCNVector3(0, 0.1, 0)
        }

        // Center circle
        let centerGeometry = SCNCylinder(radius: CGFloat(cellSize * 0.8), height: 0.03)
        let centerMaterial = SCNMaterial()
        centerMaterial.diffuse.contents = UIColor(white: 0.95, alpha: 1.0)
        centerGeometry.materials = [centerMaterial]

        let centerNode = SCNNode(geometry: centerGeometry)
        centerNode.position = SCNVector3(0, 0.025, 0)
        addChildNode(centerNode)
    }

    private func createSafeSquareMarkers() {
        // Add star markers on safe squares
        let safeSquares = [8, 21, 34, 47]

        for index in safeSquares {
            guard let position = trackPositions[index] else { continue }

            // Create a star shape marker
            let starGeometry = SCNCylinder(radius: CGFloat(cellSize * 0.2), height: 0.01)
            let starMaterial = SCNMaterial()
            starMaterial.diffuse.contents = UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
            starMaterial.emission.contents = UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 0.3)
            starGeometry.materials = [starMaterial]

            let starNode = SCNNode(geometry: starGeometry)
            starNode.position = SCNVector3(position.x, position.y + 0.02, position.z)
            addChildNode(starNode)
        }
    }

    // MARK: - Position Calculations

    private func calculatePositions() {
        // Positions are calculated during cell creation
        // This method can be used for additional calculations if needed
    }

    // MARK: - Public Methods

    func getPosition(for tokenState: TokenState, color: PlayerColor, tokenIndex: Int) -> SCNVector3 {
        switch tokenState {
        case .inYard:
            return yardPositions[color]?[tokenIndex] ?? SCNVector3Zero

        case .onTrack(let position):
            return trackPositions[position] ?? SCNVector3Zero

        case .onHomePath(let position):
            return homePathPositions[color]?[position] ?? SCNVector3Zero

        case .home:
            return homePositions[color] ?? SCNVector3Zero
        }
    }

    func isSafeSquare(_ position: Int) -> Bool {
        return PlayerColor.safeSquares.contains(position)
    }

    // MARK: - Convenience Position Methods

    /// Get yard position for a specific token
    func yardPosition(for color: PlayerColor, index: Int) -> SCNVector3 {
        guard let positions = yardPositions[color], index < positions.count else {
            return SCNVector3Zero
        }
        var pos = positions[index]
        pos.y = 0.15 // Raise token above the board
        return pos
    }

    /// Get track position at given index
    func trackPosition(at index: Int) -> SCNVector3 {
        guard let pos = trackPositions[index] else {
            return SCNVector3Zero
        }
        return SCNVector3(pos.x, 0.15, pos.z)
    }

    /// Get home path position for a color at given index
    func homePathPosition(for color: PlayerColor, at index: Int) -> SCNVector3 {
        guard let positions = homePathPositions[color], index < positions.count else {
            return SCNVector3Zero
        }
        let pos = positions[index]
        return SCNVector3(pos.x, 0.15, pos.z)
    }

    /// Get final home position for a token
    func homePosition(for color: PlayerColor, index: Int) -> SCNVector3 {
        // Stack tokens in the center when they reach home
        let basePos = homePositions[color] ?? SCNVector3Zero
        let stackOffset = Float(index) * 0.08
        return SCNVector3(basePos.x, 0.2 + stackOffset, basePos.z)
    }
}

// MARK: - PlayerColor Extension for UIColor

extension PlayerColor {
    var uiColor: UIColor {
        switch self {
        case .red: return UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1.0)
        case .green: return UIColor(red: 0.15, green: 0.65, blue: 0.15, alpha: 1.0)
        case .yellow: return UIColor(red: 0.95, green: 0.85, blue: 0.15, alpha: 1.0)
        case .blue: return UIColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 1.0)
        }
    }
}
