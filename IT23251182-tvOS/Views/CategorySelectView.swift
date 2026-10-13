//
//  CategorySelectView.swift
//  IT23251182-tvOS
//
//  "Play Game" → choose a subject.
//
//  Layout follows the standard tvOS browse pattern: a large preview panel that
//  describes whatever the remote is currently focused on, above a row of cards.
//  The player can read about every subject by moving across the row, without
//  committing to any of them.
//
//  This view owns no question data. It renders `CategoryAvailability` summaries
//  from `CategorySelectViewModel` and reports focus and selection back to it.
//

import SwiftUI

struct CategorySelectView: View {

    /// Carries the chosen category into the next screen.
    let onCategoryChosen: (QuizSettings) -> Void

    @State private var viewModel: CategorySelectViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.brandAnimationsEnabled) private var animated

    @State private var hasAppeared = false

    /// Which card the remote is on. Mirrored into the view model so the preview
    /// panel updates as focus moves.
    @FocusState private var focusedCategory: QuizCategory?

    init(viewModel: CategorySelectViewModel,
         onCategoryChosen: @escaping (QuizSettings) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onCategoryChosen = onCategoryChosen
    }

    var body: some View {
        ZStack {
            BrandBackground()

            if viewModel.hasAnyPlayableCategory {
                content
            } else {
                noCategoriesState
            }
        }
        .onAppear { hasAppeared = true }
        // Focus is a view-layer concern; the view model only needs to know which
        // category is highlighted so it can drive the preview.
        .onChange(of: focusedCategory) { _, newValue in
            if let newValue { viewModel.highlightedCategory = newValue }
        }
    }

    // MARK: Main content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {

            header
                .padding(.bottom, 32)

            if let summary = viewModel.highlightedAvailability {
                CategoryPreviewPanel(
                    summary: summary,
                    isSelected: viewModel.isSelected(summary.category)
                )
                .padding(.bottom, 20)
                .opacity(hasAppeared ? 1 : 0)
                .animation(BrandMotion.entrance(animated, index: 1), value: hasAppeared)
            }

            categoryRow

            // One flexible spacer, so the footer sits on the bottom edge.
            // Several spacers would share the slack and leave it floating.
            Spacer(minLength: 24)

            footer
        }
        // Without an explicit fill the VStack sizes to its content and the
        // trailing Spacer has no slack to distribute, leaving the footer
        // floating in the middle of the screen.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, BrandLayout.screenPaddingH)
        .padding(.vertical, BrandLayout.screenPaddingV)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            ScreenHeader(
                title: "Choose a Category",
                subtitle: "Move across the row to compare subjects, then press Select."
            )
            Spacer()
            backButton
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 0), value: hasAppeared)
    }

    /// An explicit Back control. The Siri Remote's Menu button already pops the
    /// stack, but a visible button is discoverable and is the only route back
    /// for someone using a game controller or the simulator's keyboard.
    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Label("Back", systemImage: "chevron.left")
        }
        .buttonStyle(BrandButtonStyle(kind: .secondary))
        .accessibilityLabel("Back")
        .accessibilityHint("Returns to the main menu")
    }

    // MARK: Card row

    private var categoryRow: some View {
        HStack(spacing: BrandLayout.gutter) {
            ForEach(Array(viewModel.availability.enumerated()), id: \.element.id) { index, summary in
                categoryCard(summary, index: index)
            }
        }
        // Headroom so the focused card can scale without being clipped.
        .padding(.vertical, 20)
        .defaultFocus($focusedCategory, viewModel.firstPlayableCategory)
    }

    private func categoryCard(_ summary: CategoryAvailability, index: Int) -> some View {
        Button {
            // The view model decides whether the choice is legal and builds the
            // settings; the view only forwards the result.
            if let settings = viewModel.select(summary.category) {
                onCategoryChosen(settings)
            }
        } label: {
            CategoryCardContent(
                summary: summary,
                isSelected: viewModel.isSelected(summary.category)
            )
        }
        .buttonStyle(BrandCardStyle(isPrimary: viewModel.isSelected(summary.category)))
        .focused($focusedCategory, equals: summary.category)
        // A locked card stays visible but is skipped by the focus engine, so the
        // remote can never land on something that would do nothing when pressed.
        .disabled(!summary.isPlayable)
        .accessibilityLabel(viewModel.accessibilityLabel(for: summary))
        .accessibilityHint(summary.isPlayable ? "Starts player setup for this category" : "")
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 36)
        .animation(BrandMotion.entrance(animated, index: index + 2), value: hasAppeared)
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: BrandLayout.gutter) {
            StatPill(value: "\(viewModel.playableCount)", label: "Playable")

            if viewModel.lockedCount > 0 {
                StatPill(value: "\(viewModel.lockedCount)", label: "Locked")
            }

            StatPill(value: "\(viewModel.questionCount)", label: "Round Length")

            Spacer()

            if let selected = viewModel.selectedCategory {
                Text("Selected: \(selected.displayName)")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.accent)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(BrandMotion.entrance(animated, index: 8), value: hasAppeared)
    }

    // MARK: Empty state

    /// Shown only if the bank somehow contains no category with enough
    /// questions. Without this the screen would render an unusable row of
    /// locked cards and no way to understand why.
    private var noCategoriesState: some View {
        VStack(spacing: 36) {
            EmptyStateView(
                symbol: "tray",
                title: "No categories are ready to play",
                message: "Every category needs at least \(CategoryAvailability.minimumPlayableQuestions) questions before a match can start. Check that questions.json is included in the app target."
            )
            backButton
        }
        .padding(.horizontal, BrandLayout.screenPaddingH)
        .padding(.vertical, BrandLayout.screenPaddingV)
    }
}

#Preview {
    NavigationStack {
        CategorySelectView(
            viewModel: CategorySelectViewModel(repository: PreviewSupport.loadedRepository()),
            onCategoryChosen: { _ in }
        )
    }
}
