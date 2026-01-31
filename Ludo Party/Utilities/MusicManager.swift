import AVFoundation

/// Singleton class to manage background music and sound effects across scenes
/// Respects device mute/ringer switch settings
class MusicManager {
    static let shared = MusicManager()

    private var backgroundMusicPlayer: AVAudioPlayer?
    private var soundEffectPlayers: [String: AVAudioPlayer] = [:]

    private init() {}

    /// Configure audio session to respect device mute/silent switch
    private func configureAudioSession() {
        do {
            // Use .ambient category to respect the device mute switch
            // This means audio will be silenced when the device is muted
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[MusicManager] Failed to configure audio session: \(error)")
        }
    }

    /// Start playing background music at 50% volume, looping indefinitely
    /// Music will respect device mute/ringer switch
    func startBackgroundMusic() {
        // Configure audio session before playing
        configureAudioSession()

        // Only start if not already playing
        guard backgroundMusicPlayer == nil || backgroundMusicPlayer?.isPlaying == false else {
            print("[MusicManager] Music already playing")
            return
        }

        // Try to find the music file in the bundle
        var musicURL: URL?

        // First try root of bundle
        if let url = Bundle.main.url(forResource: "bgmusic", withExtension: "mp3") {
            musicURL = url
        }
        // Try sounds subdirectory
        else if let url = Bundle.main.url(forResource: "bgmusic", withExtension: "mp3", subdirectory: "sounds") {
            musicURL = url
        }

        guard let finalURL = musicURL else {
            print("[MusicManager] Background music file 'bgmusic.mp3' not found in bundle")
            print("[MusicManager] Make sure bgmusic.mp3 is added to the Xcode project and included in 'Copy Bundle Resources'")
            return
        }

        print("[MusicManager] Found music file at: \(finalURL)")

        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: finalURL)
            backgroundMusicPlayer?.numberOfLoops = -1  // Loop indefinitely
            backgroundMusicPlayer?.volume = 1.0  // 100% volume (based on device volume)
            backgroundMusicPlayer?.prepareToPlay()

            let success = backgroundMusicPlayer?.play() ?? false
            print("[MusicManager] Music playback started: \(success)")
        } catch {
            print("[MusicManager] Failed to setup background music: \(error)")
        }
    }

    /// Stop background music completely
    func stopBackgroundMusic() {
        backgroundMusicPlayer?.stop()
        backgroundMusicPlayer = nil
        print("[MusicManager] Music stopped")
    }

    /// Check if music is currently playing
    var isPlaying: Bool {
        return backgroundMusicPlayer?.isPlaying ?? false
    }

    // MARK: - Sound Effects

    /// Play a sound effect from the sounds folder
    /// - Parameters:
    ///   - name: The name of the sound file (without extension)
    ///   - duration: Optional duration to play the sound (in seconds). If nil, plays full sound.
    func playSoundEffect(_ name: String, duration: TimeInterval? = nil) {
        // Configure audio session before playing
        configureAudioSession()

        // Try to find the sound file in the bundle
        var soundURL: URL?

        // First try sounds subdirectory
        if let url = Bundle.main.url(forResource: name, withExtension: "mp3", subdirectory: "sounds") {
            soundURL = url
        }
        // Try root of bundle
        else if let url = Bundle.main.url(forResource: name, withExtension: "mp3") {
            soundURL = url
        }

        guard let finalURL = soundURL else {
            print("[MusicManager] Sound effect '\(name).mp3' not found in bundle")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: finalURL)
            player.volume = 1.0
            player.prepareToPlay()
            player.play()

            // Store the player to keep it alive
            soundEffectPlayers[name] = player

            // If duration specified, stop after that time
            if let duration = duration {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                    self?.stopSoundEffect(name)
                }
            }

            print("[MusicManager] Playing sound effect: \(name)")
        } catch {
            print("[MusicManager] Failed to play sound effect '\(name)': \(error)")
        }
    }

    /// Stop a specific sound effect
    func stopSoundEffect(_ name: String) {
        soundEffectPlayers[name]?.stop()
        soundEffectPlayers.removeValue(forKey: name)
    }

    /// Stop all sound effects
    func stopAllSoundEffects() {
        for (_, player) in soundEffectPlayers {
            player.stop()
        }
        soundEffectPlayers.removeAll()
    }

    // MARK: - Convenience Methods for Game Sound Effects

    /// Play applause sound for game finish (5 seconds)
    func playApplause() {
        playSoundEffect("applause", duration: 5.0)
    }

    /// Play in_home sound when token reaches home
    func playInHomeSound() {
        playSoundEffect("in_home")
    }

    /// Play in_home sound followed by applause for game finish
    /// Plays in_home first, then applause after a short delay
    func playGameFinishSounds() {
        playInHomeSound()
        // Play applause after in_home sound (delay of 1.5 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.playApplause()
        }
    }

    /// Play eat sound when a token captures another
    func playEatSound() {
        playSoundEffect("eat")
    }

    /// Play safe sound when landing on a safe spot
    func playSafeSound() {
        playSoundEffect("safe")
    }
}
