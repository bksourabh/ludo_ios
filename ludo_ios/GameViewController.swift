//
//  GameViewController.swift
//  ludo_ios
//
//  Created by Sourabh Mazumder on 17/1/2026.
//

import UIKit
import SpriteKit
import GameplayKit
import AuthenticationServices
import GameKit

class GameViewController: UIViewController {

    private var skView: SKView!
    private var currentGameConfig: GameConfig?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let view = self.view as? SKView else {
            return
        }
        skView = view

        // Configure the view
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false

        // Authenticate Game Center
        authenticateGameCenter()

        // Show menu scene
        showMenuScene()
    }

    // MARK: - Scene Management

    private func showMenuScene() {
        let menuScene = MenuScene(size: skView.bounds.size)
        menuScene.scaleMode = .aspectFill
        menuScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        menuScene.menuDelegate = self

        skView.presentScene(menuScene, transition: SKTransition.fade(withDuration: 0.5))
    }

    private func showGameScene(with config: GameConfig) {
        currentGameConfig = config

        let gameScene = GameScene(size: skView.bounds.size)
        gameScene.scaleMode = .aspectFill
        gameScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        gameScene.gameConfig = config
        gameScene.gameSceneDelegate = self

        skView.presentScene(gameScene, transition: SKTransition.fade(withDuration: 0.5))

        // Start Game Mode if available
        startGameMode()
    }

    // MARK: - Game Center

    private func authenticateGameCenter() {
        GameManager.shared.authenticateGameCenter(presentingViewController: self) { [weak self] success in
            if success {
                print("Game Center authenticated")
                // Refresh menu if it's showing
                if let menuScene = self?.skView.scene as? MenuScene {
                    menuScene.refreshAuthState()
                }
            }
        }
    }

    // MARK: - Sign in with Apple

    private func performAppleSignIn() {
        let request = GameManager.shared.createAppleSignInRequest()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: - Game Mode

    private func startGameMode() {
        if #available(iOS 18.0, *) {
            // iOS 18+ has automatic Game Mode when game is active
            // The system detects game activity automatically
        }
        // For older iOS versions, Game Mode is managed by the system based on
        // device thermal state and CPU usage
    }

    private func stopGameMode() {
        // Game Mode ends automatically when leaving the game
    }

    // MARK: - Interface Orientation

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - MenuSceneDelegate

extension GameViewController: MenuSceneDelegate {
    func menuSceneDidStartGame(with config: GameConfig) {
        showGameScene(with: config)
    }

    func menuSceneRequestsAppleSignIn() {
        performAppleSignIn()
    }

    func menuSceneRequestsGameCenterAuth() {
        authenticateGameCenter()
    }
}

// MARK: - GameSceneDelegate

protocol GameSceneDelegate: AnyObject {
    func gameSceneDidRequestMainMenu()
}

extension GameViewController: GameSceneDelegate {
    func gameSceneDidRequestMainMenu() {
        stopGameMode()
        showMenuScene()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension GameViewController: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        GameManager.shared.handleAppleSignIn(authorization: authorization)

        // Refresh menu
        if let menuScene = skView.scene as? MenuScene {
            menuScene.refreshAuthState()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        GameManager.shared.handleAppleSignInError(error)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension GameViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}
