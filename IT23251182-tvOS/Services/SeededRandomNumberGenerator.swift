//
//  SeededRandomNumberGenerator.swift
//  IT23251182-tvOS
//
//  A deterministic random source.
//
//  Shuffling is the one part of the repository that would otherwise be
//  untestable: with `SystemRandomNumberGenerator` a test can only assert that
//  the output is *a* permutation, never that shuffling behaves correctly for a
//  known input. Every shuffling API therefore takes a generator, and tests pass
//  a seeded one so results are reproducible.
//

import Foundation

/// SplitMix64 — small, fast and well-distributed. Not cryptographically secure,
/// which is fine: this shuffles quiz questions, it does not protect anything.
struct SeededRandomNumberGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        // A zero seed would make SplitMix64 start from a degenerate state.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
