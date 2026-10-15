//
//  AppSettings.swift
//  IT23251182-tvOS
//
//  User preferences, stored on this Apple TV.
//
//  Every preference here changes something observable in the app. A setting
//  that nothing reads is a fake control, so options are added as the features
//  that consume them are built, not before:
//
//  * `reduceMotion`    — suppresses entrance and focus animation everywhere.
//  * `soundEffects`    — gates the answer feedback sounds.
//  * `questionDuration`— changes the countdown on every question.
//
//  Stored in `UserDefaults`, which is the right tool for a handful of small
//  values: it is native, synchronous, needs no schema, and is automatically
//  included in a device backup. Nothing here leaves this Apple TV.
//

import Foundation
import Observation

@Observable
final class AppSettings {

    private enum Key {
        static let reduceMotion = "settings.reduceMotion"
        static let soundEffects = "settings.soundEffects"
        static let questionDuration = "settings.questionDuration"
        static let adaptiveDifficulty = "settings.adaptiveDifficulty"
    }

    private let defaults: UserDefaults

    /// When on, decorative entrance and focus animations are suppressed.
    var reduceMotion: Bool {
        didSet { defaults.set(reduceMotion, forKey: Key.reduceMotion) }
    }

    /// When on, correct/incorrect/timeout sounds play during a match.
    var soundEffects: Bool {
        didSet { defaults.set(soundEffects, forKey: Key.soundEffects) }
    }

    /// How long players get to answer each question.
    var questionDuration: QuestionDuration {
        didSet { defaults.set(questionDuration.rawValue, forKey: Key.questionDuration) }
    }

    /// When on, each question is chosen using the player's recent accuracy
    /// rather than simply taken in order. Rule-based; see `AdaptiveDifficulty`.
    var adaptiveDifficulty: Bool {
        didSet { defaults.set(adaptiveDifficulty, forKey: Key.adaptiveDifficulty) }
    }

    /// `UserDefaults` is injected so tests use a throwaway suite rather than
    /// the real preferences.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.reduceMotion = defaults.bool(forKey: Key.reduceMotion)

        // `bool(forKey:)` returns false for a missing key, which would silently
        // turn sound off on a first launch. Checking for the key distinguishes
        // "never set" from "deliberately off".
        self.soundEffects = defaults.object(forKey: Key.soundEffects) == nil
            ? true
            : defaults.bool(forKey: Key.soundEffects)

        // Same reasoning as sound: a missing key means "never set", not "off".
        self.adaptiveDifficulty = defaults.object(forKey: Key.adaptiveDifficulty) == nil
            ? true
            : defaults.bool(forKey: Key.adaptiveDifficulty)

        // An unreadable or unrecognised stored value falls back to the default
        // rather than refusing to start.
        let storedDuration = defaults.string(forKey: Key.questionDuration)
        self.questionDuration = storedDuration.flatMap(QuestionDuration.init(rawValue:)) ?? .standard
    }

    /// Returns every preference to its default. Used by the Settings screen.
    func resetToDefaults() {
        reduceMotion = false
        soundEffects = true
        questionDuration = .standard
        adaptiveDifficulty = true
    }
}
