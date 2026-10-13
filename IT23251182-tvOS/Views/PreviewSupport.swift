//
//  PreviewSupport.swift
//  IT23251182-tvOS
//
//  Helpers used only by SwiftUI previews.
//
//  Previews need a loaded repository, and `load()` throws. Rather than putting
//  `try?` and error handling into every `#Preview` block, that is done once here.
//

import Foundation

enum PreviewSupport {

    /// A repository backed by the real bundled bank, already loaded.
    /// Returns an empty repository if loading fails, so a preview degrades to
    /// the screen's own empty state instead of crashing the canvas.
    static func loadedRepository() -> QuestionRepository {
        let repository = QuestionRepository()
        _ = try? repository.load()
        return repository
    }
}
