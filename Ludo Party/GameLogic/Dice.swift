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

    /// Roll the dice with good luck - weighted distribution favoring higher numbers
    /// Distribution: 1: 10%, 2: 12%, 3: 15%, 4: 18%, 5: 20%, 6: 25%
    func rollWithGoodLuck() -> Int {
        let rand = Int.random(in: 1...100)
        let value: Int

        switch rand {
        case 1...10:  value = 1   // 10%
        case 11...22: value = 2   // 12%
        case 23...37: value = 3   // 15%
        case 38...55: value = 4   // 18%
        case 56...75: value = 5   // 20%
        default:      value = 6   // 25%
        }

        currentValue = value
        return value
    }

    /// Roll with weighted distribution to favor or handicap a player
    /// - Parameter favorHuman: true biases toward higher values, false biases toward lower values
    func rollBiased(favorHuman: Bool = true) -> Int {
        let rand = Int.random(in: 1...100)
        let value: Int

        if favorHuman {
            // Human-friendly distribution:
            // 1: 8%, 2: 10%, 3: 12%, 4: 18%, 5: 22%, 6: 30%
            switch rand {
            case 1...8:   value = 1
            case 9...18:  value = 2
            case 19...30: value = 3
            case 31...48: value = 4
            case 49...70: value = 5
            default:      value = 6
            }
        } else {
            // Computer-handicapped distribution:
            // 1: 22%, 2: 22%, 3: 20%, 4: 16%, 5: 12%, 6: 8%
            switch rand {
            case 1...22:  value = 1
            case 23...44: value = 2
            case 45...64: value = 3
            case 65...80: value = 4
            case 81...92: value = 5
            default:      value = 6
            }
        }

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
