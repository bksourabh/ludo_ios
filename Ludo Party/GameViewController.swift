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

    // Online multiplayer
    private var matchManager: MatchManager?
    private var roomState: OnlineRoomState?

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

    private func showGameScene(with config: GameConfig, savedGameState: GameState? = nil) {
        currentGameConfig = config

        let gameScene = GameScene(size: skView.bounds.size)
        gameScene.scaleMode = .aspectFill
        gameScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        gameScene.gameConfig = config
        gameScene.savedGameState = savedGameState
        gameScene.gameSceneDelegate = self

        skView.presentScene(gameScene, transition: SKTransition.fade(withDuration: 0.5))

        // Start Game Mode if available
        startGameMode()
    }

    private func showLobbyScene(isHost: Bool) {
        guard let matchManager = matchManager else { return }

        let localPlayerID = matchManager.localPlayerID
        roomState = OnlineRoomState(isHost: isHost, localPlayerID: localPlayerID)

        // Add local player
        roomState?.addLocalPlayer(displayName: matchManager.localPlayerDisplayName)

        let lobbyScene = LobbyScene(size: skView.bounds.size)
        lobbyScene.scaleMode = .aspectFill
        lobbyScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        lobbyScene.configure(roomState: roomState!, matchManager: matchManager)
        lobbyScene.lobbyDelegate = self

        skView.presentScene(lobbyScene, transition: SKTransition.fade(withDuration: 0.5))
    }

    private func showOnlineGameScene(with roomState: OnlineRoomState) {
        guard let matchManager = matchManager else { return }

        let onlineGameScene = OnlineGameScene(size: skView.bounds.size)
        onlineGameScene.scaleMode = .aspectFill
        onlineGameScene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        onlineGameScene.configure(matchManager: matchManager, roomState: roomState)
        onlineGameScene.onlineGameDelegate = self

        skView.presentScene(onlineGameScene, transition: SKTransition.fade(withDuration: 0.5))

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

    func menuSceneDidRequestContinueGame() {
        guard let savedData = GameSaveManager.shared.loadGame() else {
            // No saved game found, show menu
            showMenuScene()
            return
        }
        showGameScene(with: savedData.gameConfig, savedGameState: savedData.gameState)
    }

    func menuSceneRequestsAppleSignIn() {
        performAppleSignIn()
    }

    func menuSceneRequestsGameCenterAuth() {
        authenticateGameCenter()
    }

    func menuSceneRequestsGuestLogin() {
        GameManager.shared.loginAsGuest()

        // Refresh menu
        if let menuScene = skView.scene as? MenuScene {
            menuScene.refreshAuthState()
        }
    }

    func menuSceneRequestsCreateOnlineGame() {
        matchManager = MatchManager()
        matchManager?.delegate = self

        // Show matchmaker UI for creating a game
        matchManager?.showMatchmakerUI(from: self)
    }

    func menuSceneRequestsJoinOnlineGame() {
        matchManager = MatchManager()
        matchManager?.delegate = self

        // Show matchmaker UI for joining a game
        matchManager?.showMatchmakerUI(from: self)
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

        // Show error alert to user
        let alert = UIAlertController(
            title: "Sign In Failed",
            message: "Could not sign in with Apple. You can try again or continue as a guest.\n\nError: \(error.localizedDescription)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension GameViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}

// MARK: - MatchManagerDelegate

extension GameViewController: MatchManagerDelegate {
    func matchManager(_ manager: MatchManager, didReceiveMessage message: NetworkMessage, from player: GKPlayer) {
        // Handle messages at lobby level
        guard let roomState = roomState else { return }

        switch message.type {
        case .playerJoined:
            if let payload = try? message.decodePayload(PlayerJoinedPayload.self) {
                let onlinePlayer = OnlinePlayer(
                    id: payload.playerID,
                    displayName: payload.displayName,
                    color: nil,
                    isAI: false
                )
                roomState.addPlayer(onlinePlayer)
            }

        case .playerReady:
            if let payload = try? message.decodePayload(PlayerReadyPayload.self) {
                roomState.setPlayerReady(payload.playerID, isReady: payload.isReady)
            }

        case .gameStart:
            if let payload = try? message.decodePayload(GameStartPayload.self) {
                // Apply color assignments
                for (playerID, colorRaw) in payload.colorAssignments {
                    if let color = PlayerColor(rawValue: colorRaw) {
                        roomState.setPlayerColor(playerID, color: color)
                    }
                }
                roomState.setInGame()
                showOnlineGameScene(with: roomState)
            }

        default:
            break
        }
    }

    func matchManager(_ manager: MatchManager, playerDidConnect player: GKPlayer) {
        guard let roomState = roomState else { return }

        let onlinePlayer = OnlinePlayer(from: player, isLocal: false, isHost: false)
        roomState.addPlayer(onlinePlayer)

        // Broadcast that we joined (if we're not the host)
        if !roomState.isHost {
            do {
                let payload = PlayerJoinedPayload(
                    playerID: manager.localPlayerID,
                    displayName: manager.localPlayerDisplayName
                )
                try manager.sendMessage(type: .playerJoined, payload: payload)
            } catch {
                print("Failed to send player joined message: \(error)")
            }
        }
    }

    func matchManager(_ manager: MatchManager, playerDidDisconnect player: GKPlayer) {
        roomState?.markPlayerDisconnected(player.gamePlayerID)
    }

    func matchManagerDidFindMatch(_ manager: MatchManager) {
        let isHost = manager.determineHost()
        showLobbyScene(isHost: isHost)
    }

    func matchManager(_ manager: MatchManager, didFailWithError error: Error) {
        let alert = UIAlertController(
            title: "Connection Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        showMenuScene()
    }

    func matchManagerDidCancel(_ manager: MatchManager) {
        matchManager = nil
        // Stay on menu scene
    }
}

// MARK: - LobbySceneDelegate

extension GameViewController: LobbySceneDelegate {
    func lobbySceneDidStartGame(_ scene: LobbyScene, roomState: OnlineRoomState) {
        self.roomState = roomState
        showOnlineGameScene(with: roomState)
    }

    func lobbySceneDidCancel(_ scene: LobbyScene) {
        matchManager?.disconnect()
        matchManager = nil
        roomState = nil
        showMenuScene()
    }

    func lobbySceneRequestsMatchmaker(_ scene: LobbyScene) {
        matchManager?.showMatchmakerUI(from: self)
    }
}

// MARK: - OnlineGameSceneDelegate

extension GameViewController: OnlineGameSceneDelegate {
    func onlineGameSceneDidRequestMainMenu(_ scene: OnlineGameScene) {
        matchManager?.disconnect()
        matchManager = nil
        roomState = nil
        stopGameMode()
        showMenuScene()
    }

    func onlineGameSceneDidRequestRematch(_ scene: OnlineGameScene) {
        // For rematch, we'd need to create a new room with the same players
        // For simplicity, just return to menu
        onlineGameSceneDidRequestMainMenu(scene)
    }
}
