//
//  AppSettings.swift
//  IT23251182-tvOS
//
//  User preferences that persist between launches.
//
//  Deliberately small for now: it holds only settings that have a real,
//  observable effect in the current build. A preference that nothing reads is
//  a fake control, so options are added here as the features that consume them
//  are built, not before.
//

import Foundation
import Observation

@Observable
final class AppSettings {

    private enum Key {
        static let reduceMotion = "settings.reduceMotion"
    }

    private let defaults: UserDefaults

    /// When on, decorative entrance and focus animations are suppressed
    /// throughout the app. Written straight back to `UserDefaults` so the
    /// choice survives relaunch.
    var reduceMotion: Bool {
        didSet { defaults.set(reduceMotion, forKey: Key.reduceMotion) }
    }

    /// `UserDefaults` is injected so a unit test can pass a throwaway suite
    /// instead of polluting the real one.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.reduceMotion = defaults.bool(forKey: Key.reduceMotion)
    }
}
