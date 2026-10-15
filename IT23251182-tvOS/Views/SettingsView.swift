//
//  SettingsView.swift
//  IT23251182-tvOS
//
//  Preferences, instructions, about and the local-data description.
//
//  Every control here changes something observable: Reduce Motion suppresses
//  animation app-wide, Sound Effects gates the answer tones, and Question Time
//  changes the countdown on the next question asked. Nothing on this screen is
//  decorative.
//

import SwiftUI

struct SettingsView: View {

    let viewModel: HomeViewModel
    /// Pushes the How to Play screen, so the rules are reachable from here too.
    let onShowHowToPlay: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        @Bindable var settings = settings

        return ZStack {
            BrandBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {

                    ScreenHeader(
                        title: "Settings",
                        subtitle: "Preferences are saved on this Apple TV."
                    )

                    gameplaySection(settings: $settings)
                    accessibilitySection(settings: $settings)
                    helpSection
                    aboutSection
                    privacySection
                    questionBankSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BrandLayout.screenPaddingH)
                .padding(.vertical, BrandLayout.screenPaddingV)
            }
        }
    }

    // MARK: Gameplay

    private func gameplaySection(settings: Bindable<AppSettings>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Gameplay")

            BrandToggleRow(
                title: "Adaptive Challenge",
                subtitle: "Pick each question from your recent accuracy — harder on a good run, easier after a tough one. A fixed set of rules, not machine learning.",
                isOn: settings.adaptiveDifficulty,
                accessibilityHintText: "Adjusts question difficulty to each player's recent answers"
            )

            BrandToggleRow(
                title: "Sound Effects",
                subtitle: "Play a short tone when an answer is right, wrong or runs out of time.",
                isOn: settings.soundEffects,
                accessibilityHintText: "Turns answer feedback sounds on or off"
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Question Time")
                    .font(BrandFont.label)
                    .foregroundStyle(Brand.textPrimary)
                Text("Currently \(settings.wrappedValue.questionDuration.exampleRange) depending on difficulty.")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textSecondary)

                HStack(spacing: 16) {
                    ForEach(QuestionDuration.allCases) { duration in
                        durationButton(duration, settings: settings)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
            .brandCardSurface()
        }
    }

    private func durationButton(_ duration: QuestionDuration,
                                settings: Bindable<AppSettings>) -> some View {
        let isSelected = settings.wrappedValue.questionDuration == duration

        return Button {
            settings.wrappedValue.questionDuration = duration
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(duration.displayName)
                    .font(BrandFont.label)
                    .foregroundStyle(isSelected ? Brand.accent : Brand.textPrimary)
                Text(duration.detail)
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textSecondary)
                    .lineLimit(2, reservesSpace: true)
                Text(duration.exampleRange)
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textTertiary)
            }
            .frame(width: 360, alignment: .leading)
        }
        .buttonStyle(BrandCardStyle(isPrimary: isSelected))
        .accessibilityLabel("\(duration.displayName) question time, \(duration.exampleRange)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    // MARK: Accessibility

    private func accessibilitySection(settings: Bindable<AppSettings>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Accessibility")

            BrandToggleRow(
                title: "Reduce Motion",
                subtitle: systemReduceMotion
                    ? "Turned on system-wide in tvOS Accessibility settings. Animations are already reduced."
                    : "Switch off entrance and focus animations across the app.",
                isOn: settings.reduceMotion,
                accessibilityHintText: "Turns off entrance and focus animations throughout the app"
            )
        }
    }

    // MARK: Help

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Instructions")

            Button(action: onShowHowToPlay) {
                HStack(spacing: 20) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Brand.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How to Play")
                            .font(BrandFont.label)
                            .foregroundStyle(Brand.textPrimary)
                        Text("Rules, turn order, scoring and timings.")
                            .font(BrandFont.caption)
                            .foregroundStyle(Brand.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Brand.textTertiary)
                }
            }
            .buttonStyle(BrandRowStyle())
            .accessibilityHint("Opens the rules")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "About Brain Battle")

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Brand.accent)
                            .frame(width: 76, height: 76)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(Brand.onAccent)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Brain Battle")
                            .font(BrandFont.heading)
                            .foregroundStyle(Brand.textPrimary)
                        Text("Think Fast. Play Together.")
                            .font(BrandFont.caption)
                            .foregroundStyle(Brand.accent)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Version \(AppInfo.versionString)")
                            .font(BrandFont.caption)
                            .foregroundStyle(Brand.textSecondary)
                        Text("tvOS \(AppInfo.minimumOSVersion) or later")
                            .font(BrandFont.caption)
                            .foregroundStyle(Brand.textTertiary)
                    }
                }

                Text("A pass-the-remote trivia game for two to four players sharing one Apple TV. Built as a native tvOS prototype for SE4041 Mobile Application Design and Development.")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
            .brandCardSurface()
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Privacy

    /// Deliberately specific. It names what is stored, where it lives and what
    /// does not happen — no accounts, no network, no analytics. Describing local
    /// storage as anything cloud-like would be untrue.
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Your data")

            VStack(alignment: .leading, spacing: 14) {
                privacyLine("internaldrive.fill",
                            "Everything stays on this Apple TV. Brain Battle has no accounts, makes no network requests, and collects no analytics.")
                privacyLine("list.bullet.rectangle",
                            "Stored locally: completed match results (player names, scores and the answers given), the last roster of player names and avatars, and the preferences on this screen.")
                privacyLine("xmark.circle",
                            "Not stored: anything identifying you personally beyond the names you type in. Player names are whatever you choose and can be anything.")
                privacyLine("trash",
                            "Deleting saved matches is done from the Leaderboard with Clear History. Removing the app deletes all of it.")
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 28)
            .brandCardSurface()
        }
    }

    private func privacyLine(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Brand.accent)
                .frame(width: 36)
                .accessibilityHidden(true)
            Text(text)
                .font(BrandFont.caption)
                .foregroundStyle(Brand.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Question bank

    private var questionBankSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(text: "Question Bank")

            HStack(spacing: BrandLayout.gutter) {
                StatPill(value: "\(viewModel.totalQuestionCount)", label: "Questions")
                StatPill(value: "\(viewModel.availableCategories.count)", label: "Categories")
                StatPill(value: "v\(viewModel.bankVersion)", label: "Bank Version")
                StatPill(value: "\(viewModel.rejectedCount)", label: "Rejected")
                Spacer()
            }
        }
    }
}

/// Reads the app's own bundle metadata, so the About section cannot drift out
/// of step with the project settings.
enum AppInfo {
    static var versionString: String {
        let bundle = Bundle.main
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    static var minimumOSVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "MinimumOSVersion") as? String ?? "26.1"
    }
}
