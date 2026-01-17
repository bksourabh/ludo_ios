import Foundation

/// Represents the dice in the game
class Dice {
    private(set) var currentValue: Int = 1
    private(set) var isRolling: Bool = false

    /// Roll the dice and return a random value 1-6
    func roll() -> Int {
        let value = Int.random(in: 1...6)
        currentValue = value
        return value
    }

    /// Roll the dice with animation callback support
    /// The callback receives intermediate values during animation and final value at the end
    func rollWithAnimation(duration: Double = 0.8, onValue: @escaping (Int, Bool) -> Void) {
        guard !isRolling else { return }

        isRolling = true
        let finalValue = Int.random(in: 1...6)
        let numberOfRolls = 10
        let interval = duration / Double(numberOfRolls)

        for i in 0..<numberOfRolls {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) { [weak self] in
                if i == numberOfRolls - 1 {
                    // Final value
                    self?.currentValue = finalValue
                    self?.isRolling = false
                    onValue(finalValue, true)
                } else {
                    // Random intermediate value
                    let randomValue = Int.random(in: 1...6)
                    self?.currentValue = randomValue
                    onValue(randomValue, false)
                }
            }
        }
    }

    /// Check if the current value grants a bonus roll
    var grantsBonusRoll: Bool {
        return currentValue == 6
    }
}

/// Dice face patterns for visual representation
struct DiceFace {
    /// Returns the dot positions for a dice face value (normalized 0-1 coordinates)
    static func dotPositions(for value: Int) -> [(x: CGFloat, y: CGFloat)] {
        switch value {
        case 1:
            return [(0.5, 0.5)]
        case 2:
            return [(0.25, 0.75), (0.75, 0.25)]
        case 3:
            return [(0.25, 0.75), (0.5, 0.5), (0.75, 0.25)]
        case 4:
            return [(0.25, 0.25), (0.25, 0.75), (0.75, 0.25), (0.75, 0.75)]
        case 5:
            return [(0.25, 0.25), (0.25, 0.75), (0.5, 0.5), (0.75, 0.25), (0.75, 0.75)]
        case 6:
            return [(0.25, 0.25), (0.25, 0.5), (0.25, 0.75),
                    (0.75, 0.25), (0.75, 0.5), (0.75, 0.75)]
        default:
            return []
        }
    }
}
