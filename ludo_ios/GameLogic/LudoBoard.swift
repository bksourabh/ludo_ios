import Foundation
import SpriteKit

/// Handles the Ludo board layout and position calculations
/// The board is a 15x15 grid with the classic Ludo layout
class LudoBoard {
    let boardSize: CGFloat
    let cellSize: CGFloat
    let gridSize: Int = 15

    // Board origin (bottom-left corner in screen coordinates)
    var origin: CGPoint = .zero

    init(boardSize: CGFloat) {
        self.boardSize = boardSize
        self.cellSize = boardSize / CGFloat(gridSize)
    }

    /// Set the origin point for the board (bottom-left corner)
    func setOrigin(_ point: CGPoint) {
        self.origin = point
    }

    // MARK: - Grid Conversion

    /// Convert grid coordinates to screen position (center of cell)
    func gridToScreen(col: Int, row: Int) -> CGPoint {
        let x = origin.x + (CGFloat(col) + 0.5) * cellSize
        let y = origin.y + (CGFloat(row) + 0.5) * cellSize
        return CGPoint(x: x, y: y)
    }

    // MARK: - Track Position Mapping

    /// The main track consists of 52 positions (0-51)
    /// Track goes clockwise. Red starts at 0, Green at 13, Yellow at 26, Blue at 39
    ///
    /// Board layout (15x15 grid):
    /// - Columns 0-5, Rows 0-5: Red yard (bottom-left)
    /// - Columns 0-5, Rows 9-14: Green yard (top-left)
    /// - Columns 9-14, Rows 9-14: Yellow yard (top-right)
    /// - Columns 9-14, Rows 0-5: Blue yard (bottom-right)
    /// - Columns 6-8, Rows 0-14: Vertical track arm
    /// - Rows 6-8, Columns 0-14: Horizontal track arm
    /// - Columns 6-8, Rows 6-8: Center home area

    private let trackPositions: [(col: Int, row: Int)] = [
        // Red section: Start at (6,1), go UP column 6, rows 1-5
        (6, 1), (6, 2), (6, 3), (6, 4), (6, 5),           // 0-4

        // Turn LEFT at row 6, go from column 5 to 0
        (5, 6), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6),   // 5-10

        // Turn UP at column 0, go from row 7 to 8
        (0, 7), (0, 8),                                    // 11-12

        // Green section: Start at (1,8), go RIGHT row 8, columns 1-5
        (1, 8), (2, 8), (3, 8), (4, 8), (5, 8),           // 13-17

        // Turn UP at column 6, go from row 9 to 14
        (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14), // 18-23

        // Turn RIGHT at row 14, go from column 7 to 8
        (7, 14), (8, 14),                                  // 24-25

        // Yellow section: Start at (8,13), go DOWN column 8, rows 13-9
        (8, 13), (8, 12), (8, 11), (8, 10), (8, 9),       // 26-30

        // Turn RIGHT at row 8, go from column 9 to 14
        (9, 8), (10, 8), (11, 8), (12, 8), (13, 8), (14, 8), // 31-36

        // Turn DOWN at column 14, go from row 7 to 6
        (14, 7), (14, 6),                                  // 37-38

        // Blue section: Start at (13,6), go LEFT row 6, columns 13-9
        (13, 6), (12, 6), (11, 6), (10, 6), (9, 6),       // 39-43

        // Turn DOWN at column 8, go from row 5 to 0
        (8, 5), (8, 4), (8, 3), (8, 2), (8, 1), (8, 0),   // 44-49

        // Turn LEFT at row 0, go from column 7 to 6
        (7, 0), (6, 0)                                     // 50-51
    ]

    /// Get the screen position for a main track position (0-51)
    func screenPosition(forTrackPosition position: Int) -> CGPoint {
        guard position >= 0 && position < 52 else {
            return .zero
        }
        let gridPos = trackPositions[position]
        return gridToScreen(col: gridPos.col, row: gridPos.row)
    }

    // MARK: - Home Path Positions

    /// Home paths are the colored paths leading to the center
    /// Each player has 6 positions (0-5, where 5 is closest to center/home)
    func screenPosition(forHomePath position: Int, color: PlayerColor) -> CGPoint {
        let gridPos = homePathGridPosition(position: position, color: color)
        return gridToScreen(col: gridPos.col, row: gridPos.row)
    }

    private func homePathGridPosition(position: Int, color: PlayerColor) -> (col: Int, row: Int) {
        // Home path positions 0-5, where 5 is the innermost (closest to center)
        switch color {
        case .red:
            // Red home path: column 7, rows 1-6 (going up towards center)
            return (7, 1 + position)
        case .green:
            // Green home path: row 7, columns 1-6 (going right towards center)
            return (1 + position, 7)
        case .yellow:
            // Yellow home path: column 7, rows 13-8 (going down towards center)
            return (7, 13 - position)
        case .blue:
            // Blue home path: row 7, columns 13-8 (going left towards center)
            return (13 - position, 7)
        }
    }

    // MARK: - Yard Positions

    /// Get screen positions for the 4 tokens in a yard
    func yardPositions(for color: PlayerColor) -> [CGPoint] {
        // Get the 4 token positions as grid coordinates
        let positions = yardTokenGridPositions(for: color)
        return positions.map { gridToScreen(col: $0.col, row: $0.row) }
    }

    /// Get the 4 grid positions for tokens in a yard
    private func yardTokenGridPositions(for color: PlayerColor) -> [(col: Int, row: Int)] {
        // Tokens are placed in a 2x2 pattern within the inner white area
        // The inner white area has ~0.8 cell margin, so tokens at positions +/-1 from center
        switch color {
        case .red:
            // Red yard: cols 0-5, rows 0-5, inner area roughly cols 1-4, rows 1-4
            return [(2, 2), (4, 2), (2, 4), (4, 4)]
        case .green:
            // Green yard: cols 0-5, rows 9-14, inner area roughly cols 1-4, rows 10-13
            return [(2, 10), (4, 10), (2, 12), (4, 12)]
        case .yellow:
            // Yellow yard: cols 9-14, rows 9-14, inner area roughly cols 10-13, rows 10-13
            return [(10, 10), (12, 10), (10, 12), (12, 12)]
        case .blue:
            // Blue yard: cols 9-14, rows 0-5, inner area roughly cols 10-13, rows 1-4
            return [(10, 2), (12, 2), (10, 4), (12, 4)]
        }
    }

    /// Get the yard area rectangle for a color
    func yardRect(for color: PlayerColor) -> CGRect {
        let startCol: Int
        let startRow: Int

        switch color {
        case .red:
            startCol = 0
            startRow = 0
        case .green:
            startCol = 0
            startRow = 9
        case .yellow:
            startCol = 9
            startRow = 9
        case .blue:
            startCol = 9
            startRow = 0
        }

        let x = origin.x + CGFloat(startCol) * cellSize
        let y = origin.y + CGFloat(startRow) * cellSize
        let size = cellSize * 6

        return CGRect(x: x, y: y, width: size, height: size)
    }

    // MARK: - Home Center

    /// Get the center position (home/finish area)
    func homeCenterPosition() -> CGPoint {
        return gridToScreen(col: 7, row: 7)
    }

    /// Get the home triangle position for tokens that have finished
    func homeTrianglePosition(for color: PlayerColor) -> CGPoint {
        // Position tokens slightly towards their color's triangle
        switch color {
        case .red:
            return gridToScreen(col: 7, row: 6)
        case .green:
            return gridToScreen(col: 6, row: 7)
        case .yellow:
            return gridToScreen(col: 7, row: 8)
        case .blue:
            return gridToScreen(col: 8, row: 7)
        }
    }

    // MARK: - Safe Squares

    /// Check if a track position is a safe square (star positions)
    func isSafeSquare(_ position: Int) -> Bool {
        return PlayerColor.safeSquares.contains(position)
    }

    /// Check if a position is a starting square
    func isStartSquare(_ position: Int) -> Bool {
        return PlayerColor.allCases.contains { $0.startPosition == position }
    }

    // MARK: - Cell Helpers

    /// Get the rectangle for a grid cell
    func cellRect(col: Int, row: Int) -> CGRect {
        let x = origin.x + CGFloat(col) * cellSize
        let y = origin.y + CGFloat(row) * cellSize
        return CGRect(x: x, y: y, width: cellSize, height: cellSize)
    }
}
