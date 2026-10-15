//
//  SoundEffectPlayer.swift
//  IT23251182-tvOS
//
//  Short feedback tones for answering.
//
//  The tones are synthesised in code rather than bundled as audio files. Three
//  short blips would otherwise mean three binary assets to ship, license and
//  keep in the repository; generating them is a few lines of arithmetic, adds
//  nothing to the app size, and keeps the project free of third-party content.
//
//  Playback is best-effort by design: if audio is unavailable for any reason,
//  the game carries on silently. Sound is feedback, never a requirement.
//

import Foundation
import AVFoundation

enum SoundEffect {
    case correct
    case incorrect
    case timeout

    /// Rising pair for correct, falling for wrong, low double for a timeout.
    var tones: [(frequency: Double, duration: Double)] {
        switch self {
        case .correct:   return [(660, 0.09), (990, 0.14)]
        case .incorrect: return [(400, 0.16)]
        case .timeout:   return [(300, 0.12), (220, 0.18)]
        }
    }
}

/// Abstracted so the engine can be tested with a spy and never touches audio
/// hardware during unit tests.
protocol SoundPlaying: AnyObject {
    func play(_ effect: SoundEffect)
}

final class SoundEffectPlayer: SoundPlaying {

    /// Consulted at play time, so toggling sound in Settings takes effect
    /// immediately rather than at the start of the next match.
    private let isEnabled: () -> Bool

    /// Held so a tone is not deallocated mid-playback.
    private var players: [AVAudioPlayer] = []

    init(isEnabled: @escaping () -> Bool) {
        self.isEnabled = isEnabled
        configureAudioSession()
    }

    /// `.ambient` means Brain Battle never stops whatever the household is
    /// already playing, and is not treated as the primary audio on the device.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [])
        try? session.setActive(true)
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled() else { return }

        let data = Self.waveform(for: effect)
        guard let player = try? AVAudioPlayer(data: data) else { return }

        player.volume = 0.6
        player.prepareToPlay()
        player.play()

        // Keep a reference while it plays, and drop finished ones so the array
        // cannot grow for the length of a match.
        players.removeAll { !$0.isPlaying }
        players.append(player)
    }

    // MARK: Tone synthesis

    private static let sampleRate: Double = 44_100

    /// Builds a complete 16-bit mono WAV in memory for the effect's tones.
    static func waveform(for effect: SoundEffect) -> Data {
        var samples: [Int16] = []

        for tone in effect.tones {
            let frameCount = Int(tone.duration * sampleRate)
            guard frameCount > 0 else { continue }

            for frame in 0..<frameCount {
                let time = Double(frame) / sampleRate
                // Short fade in and out; a square-edged tone clicks audibly.
                let fadeFrames = max(1.0, sampleRate * 0.008)
                let envelope = min(1.0, min(Double(frame), Double(frameCount - frame)) / fadeFrames)
                let value = sin(2 * .pi * tone.frequency * time) * envelope * 0.35
                samples.append(Int16(value * Double(Int16.max)))
            }
        }

        return wavData(from: samples)
    }

    /// Wraps PCM samples in a minimal RIFF/WAVE container.
    private static func wavData(from samples: [Int16]) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataBytes = UInt32(samples.count * MemoryLayout<Int16>.size)

        var data = Data()

        // WAV is little-endian. Writing the bytes explicitly, rather than
        // copying raw memory, keeps this correct on any architecture and avoids
        // taking a pointer to a generic value.
        func append16(_ value: UInt16) {
            data.append(UInt8(value & 0xFF))
            data.append(UInt8((value >> 8) & 0xFF))
        }
        func append32(_ value: UInt32) {
            data.append(UInt8(value & 0xFF))
            data.append(UInt8((value >> 8) & 0xFF))
            data.append(UInt8((value >> 16) & 0xFF))
            data.append(UInt8((value >> 24) & 0xFF))
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append32(36 + dataBytes)
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        append32(16)                        // PCM chunk size
        append16(1)                         // PCM format
        append16(channels)
        append32(UInt32(sampleRate))
        append32(byteRate)
        append16(blockAlign)
        append16(bitsPerSample)

        data.append(contentsOf: Array("data".utf8))
        append32(dataBytes)
        for sample in samples { append16(UInt16(bitPattern: sample)) }

        return data
    }
}
