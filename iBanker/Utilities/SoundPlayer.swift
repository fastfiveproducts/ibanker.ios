//
//  SoundPlayer.swift
//
//  Created by Pete Maiser, Fast Five Products LLC, on 7/7/26.
//  Modified by Claude, Fast Five Products LLC, on 7/31/26.
//
//  Copyright © 2026 Fast Five Products LLC. All rights reserved.
//
//  This file is part of a project licensed under the GNU Affero General Public License v3.0.
//  See the LICENSE file at the root of this repository for full terms.
//
//  An exception applies: Fast Five Products LLC retains the right to use this code and
//  derivative works in proprietary software without being subject to the AGPL terms.
//  See LICENSE-EXCEPTIONS.md for details.
//
//  Swift port of v1.3.0's GameAudioPlayer (see the `v1.3.0` tag).
//  AVAudioPlayer tends to get cleaned up by ARC before it finishes playing;
//  SoundPlayer solves that by retaining each player in a private array and
//  releasing it in audioPlayerDidFinishPlaying.
//
//  Bundled sound attributions:
//  - HappySound.m4a, SadSound.m4a — recorded by Pete Maiser and Kate Maiser,
//    © 2015; authorized for inclusion in this work and derivations.
//  - CoinDrop.m4a — recorded by Pete Maiser, © 2015; authorized for use in
//    this application.
//  - CashRegister.CapsLok.freesound.m4a — "Cash Register Fake" by CapsLok,
//    freesound.org/people/CapsLok/sounds/184438/, CC0 1.0 (no attribution
//    required; recorded here as provenance). Original Foley construction by
//    the author — replaces a prior asset whose public-domain claim had a
//    broken chain of title (#46).
//

import Foundation
import AVFoundation

/// The bundled sound effects (.m4a resources in iBanker/Resources/).
enum SoundEffect: String {
    case cashRegister = "CashRegister.CapsLok.freesound"    // money added
    case coinDrop = "CoinDrop"                              // money subtracted
    case happy = "HappySound"                               // money sent / spin won
    case sad = "SadSound"                                   // balance went negative
}

/// iOS system sounds played from the system UISounds folder (no bundled file).
enum SystemSoundEffect: String {
    case spinClick = "keyboard_press_clear.caf"             // spinner spin
    case shake = "shake.caf"                                // reset players
}

/// The sound side effects `GameSession` triggers, behind a seam so tests can
/// substitute a recording double (the iOS analog of the Android port's
/// `GameSoundPlayer` interface). `SoundPlayer` is the production conformer.
protocol GameSoundPlaying: AnyObject {
    func play(_ effect: SoundEffect, volume: Float)
    func playQueued(_ effect: SoundEffect, volume: Float)
}

extension GameSoundPlaying {
    func play(_ effect: SoundEffect) { play(effect, volume: 1.0) }
    func playQueued(_ effect: SoundEffect) { playQueued(effect, volume: 1.0) }
}

/// Singleton audio service. Every play call is gated on the current
/// `soundEffects` setting (read at play time via `SettingsStore`), so a
/// disabled toggle silences the app immediately.
final class SoundPlayer: NSObject, AVAudioPlayerDelegate, DebugPrintable, GameSoundPlaying {

    static let shared = SoundPlayer()

    private override init() {
        super.init()
        // Without an explicit category, iOS defaults to .soloAmbient: the
        // Ring/Silent switch mutes the app entirely (the simulator has no
        // switch, which hides this) and playback pauses the user's music.
        // The in-app Sound Effects toggle is the authority instead: .playback
        // plays even when the phone is on silent, and .mixWithOthers lets any
        // background audio keep playing underneath.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
    }

    // Players currently playing (retained so ARC can't kill them mid-sound)
    // and players waiting to start once the active ones finish.
    private var activePlayers: [AVAudioPlayer] = []
    private var queuedPlayers: [AVAudioPlayer] = []

    // Keep the wait queue tiny — in practice it holds at most one sad sound.
    private let queuedPlayersLimit = 3

    // Sounds are off when the user disables them — and always in SwiftUI
    // previews, which would otherwise play audio on every canvas refresh.
    private var soundsSuppressed: Bool {
        #if DEBUG
        if isPreview { return true }
        #endif
        return !SettingsStore.soundEffectsEnabled
    }

    /// Play a bundled sound effect immediately.
    func play(_ effect: SoundEffect, volume: Float = 1.0) {
        guard !soundsSuppressed else { return }
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "m4a") else {
            debugprint("missing bundled sound: \(effect.rawValue).m4a")
            return
        }
        pruneStalePlayers()
        startPlayer(with: url, volume: volume)
    }

    /// Queue a bundled sound effect: plays immediately if nothing is playing,
    /// otherwise plays (FIFO) after the current sound finishes.
    func playQueued(_ effect: SoundEffect, volume: Float = 1.0) {
        guard !soundsSuppressed else { return }
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "m4a") else {
            debugprint("missing bundled sound: \(effect.rawValue).m4a")
            return
        }
        guard let player = makePlayer(url: url, volume: volume) else { return }
        pruneStalePlayers()
        if activePlayers.isEmpty {
            if player.play() {
                activePlayers.append(player)
            }
        } else {
            if queuedPlayers.count >= queuedPlayersLimit {
                queuedPlayers.removeFirst()
            }
            queuedPlayers.append(player)
        }
    }

    /// Play an iOS system sound from the system UISounds folder. On the
    /// simulator the folder lives under SIMULATOR_ROOT rather than the host
    /// Mac's filesystem root.
    func playSystemSound(_ effect: SystemSoundEffect, volume: Float = 1.0) {
        guard !soundsSuppressed else { return }
        let simulatorRoot = ProcessInfo.processInfo.environment["SIMULATOR_ROOT"] ?? ""
        let url = URL(fileURLWithPath: "\(simulatorRoot)/System/Library/Audio/UISounds/\(effect.rawValue)")
        pruneStalePlayers()
        startPlayer(with: url, volume: volume)
    }

    // MARK: - Internals

    private func startPlayer(with url: URL, volume: Float) {
        guard let player = makePlayer(url: url, volume: volume) else { return }
        if player.play() {
            activePlayers.append(player)
        }
    }

    // Drop players that are no longer playing but never fired their
    // didFinishPlaying callback (audio-session interruption, backgrounding
    // mid-sound) — otherwise they'd strand the queue forever.
    private func pruneStalePlayers() {
        activePlayers.removeAll { !$0.isPlaying }
    }

    private func makePlayer(url: URL, volume: Float) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            debugprint("could not create AVAudioPlayer for \(url.lastPathComponent)")
            return nil
        }
        player.volume = volume
        player.delegate = self
        return player
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activePlayers.removeAll { $0 === player }
        pruneStalePlayers()
        // If nothing is left playing, start the next queued sound (FIFO).
        while activePlayers.isEmpty, !queuedPlayers.isEmpty {
            let next = queuedPlayers.removeFirst()
            if next.play() {
                activePlayers.append(next)
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        activePlayers.removeAll { $0 === player }
        debugprint("audio decode error: \(error?.localizedDescription ?? "unknown")")
    }
}
