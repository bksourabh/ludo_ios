import UIKit
import Combine
import AuthenticationServices
import GameKit

/// Manages authentication and Game Center
class GameManager: NSObject, ObservableObject {
    static let shared = GameManager()

    // Authentication state
    @Published var isSignedInWithApple: Bool = false
    @Published var isGameCenterAuthenticated: Bool = false
    @Published var playerName: String = "Player"
    @Published var appleUserID: String?

    // Game Center player
    var localPlayer: GKLocalPlayer {
        return GKLocalPlayer.local
    }

    private override init() {
        super.init()
        checkExistingAppleSignIn()
    }

    // MARK: - Sign in with Apple

    /// Check if user has existing Apple Sign In credential
    private func checkExistingAppleSignIn() {
        if let userID = UserDefaults.standard.string(forKey: "appleUserID") {
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userID) { [weak self] state, error in
                DispatchQueue.main.async {
                    switch state {
                    case .authorized:
                        self?.isSignedInWithApple = true
                        self?.appleUserID = userID
                        if let name = UserDefaults.standard.string(forKey: "playerName") {
                            self?.playerName = name
                        }
                    case .revoked, .notFound:
                        self?.isSignedInWithApple = false
                        self?.appleUserID = nil
                    default:
                        break
                    }
                }
            }
        }
    }

    /// Create Sign in with Apple request
    func createAppleSignInRequest() -> ASAuthorizationAppleIDRequest {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName]
        return request
    }

    /// Handle Sign in with Apple completion
    func handleAppleSignIn(authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        appleUserID = credential.user
        UserDefaults.standard.set(credential.user, forKey: "appleUserID")

        if let fullName = credential.fullName {
            let name = [fullName.givenName, fullName.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty {
                playerName = name
                UserDefaults.standard.set(name, forKey: "playerName")
            }
        }

        isSignedInWithApple = true
    }

    /// Handle Sign in with Apple error
    func handleAppleSignInError(_ error: Error) {
        print("Sign in with Apple failed: \(error.localizedDescription)")
        isSignedInWithApple = false
    }

    // MARK: - Game Center

    /// Authenticate with Game Center
    func authenticateGameCenter(presentingViewController: UIViewController, completion: @escaping (Bool) -> Void) {
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            DispatchQueue.main.async {
                if let vc = viewController {
                    // Present Game Center login
                    presentingViewController.present(vc, animated: true)
                } else if self?.localPlayer.isAuthenticated == true {
                    self?.isGameCenterAuthenticated = true
                    self?.playerName = self?.localPlayer.displayName ?? "Player"
                    self?.enableGameCenterFeatures()
                    completion(true)
                } else {
                    self?.isGameCenterAuthenticated = false
                    if let error = error {
                        print("Game Center auth failed: \(error.localizedDescription)")
                    }
                    completion(false)
                }
            }
        }
    }

    /// Enable Game Center features after authentication
    private func enableGameCenterFeatures() {
        // Enable access point (Game Center button)
        GKAccessPoint.shared.isActive = true
        GKAccessPoint.shared.location = .topLeading
    }

    /// Report achievement
    func reportAchievement(identifier: String, percentComplete: Double) {
        guard isGameCenterAuthenticated else { return }

        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true

        GKAchievement.report([achievement]) { error in
            if let error = error {
                print("Failed to report achievement: \(error.localizedDescription)")
            }
        }
    }

    /// Report score to leaderboard
    func reportScore(_ score: Int, leaderboardID: String) {
        guard isGameCenterAuthenticated else { return }

        GKLeaderboard.submitScore(score, context: 0, player: localPlayer, leaderboardIDs: [leaderboardID]) { error in
            if let error = error {
                print("Failed to submit score: \(error.localizedDescription)")
            }
        }
    }

    /// Show Game Center dashboard
    func showGameCenterDashboard(from viewController: UIViewController) {
        guard isGameCenterAuthenticated else { return }

        let gcVC = GKGameCenterViewController(state: .dashboard)
        gcVC.gameCenterDelegate = self
        viewController.present(gcVC, animated: true)
    }

    // MARK: - Game Mode

    /// Start game mode activity (iOS 18+)
    @available(iOS 18.0, *)
    func startGameActivity() {
        // Game Activity API for iOS 18+
        // This automatically enables Game Mode when the game is active
    }
}

// MARK: - GKGameCenterControllerDelegate

extension GameManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
