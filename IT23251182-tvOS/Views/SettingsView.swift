//
//  SettingsView.swift
//  IT23251182-tvOS
//
//  Preferences and app information.
//
//  The Reduce Motion switch is a *working* control, not a placeholder: it writes
//  to `AppSettings`, which `ContentView` feeds into the `brandAnimationsEnabled`
//  environment value, which every button style and screen entrance reads. Toggle
//  it and the effect is visible immediately on the next screen you focus.
//
//  The information rows below it report the real loaded question bank.
//

import SwiftUI

struct SettingsView: View {

    let viewModel: HomeViewModel

    @Environment(AppSettings.self) private var settings
    /// Mirrors the system-wide accessibility switch so we can show the user why
    /// animation may already be off even with our own toggle left alone.
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        // `@Bindable` is how an @Observable object taken from the environment is
        // turned into bindings for controls such as Toggle.
        @Bindable var settings = settings

        return ZStack {
            BrandBackground()

            VStack(alignment: .leading, spacing: 44) {

                ScreenHeader(
                    title: "Settings",
                    subtitle: "Preferences are saved on this Apple TV."
                )

                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel(text: "Accessibility")

                    BrandToggleRow(
                        title: "Reduce Motion",
                        subtitle: motionSubtitle,
                        isOn: $settings.reduceMotion,
                        accessibilityHintText: "Turns off entrance and focus animations throughout the app"
                    )
                }

                VStack(alignment: .leading, spacing: 18) {
                    SectionLabel(text: "Question Bank")

                    HStack(spacing: BrandLayout.gutter) {
                        StatPill(value: "\(viewModel.totalQuestionCount)", label: "Questions")
                        StatPill(value: "\(viewModel.availableCategories.count)", label: "Categories")
                        StatPill(value: "v\(viewModel.bankVersion)", label: "Bank Version")
                        StatPill(value: "\(viewModel.rejectedCount)", label: "Rejected")
                        Spacer()
                    }
                }

                Spacer()

                Text("Gameplay preferences are added alongside the match engine in a later stage.")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.textTertiary)
            }
            .padding(.horizontal, BrandLayout.screenPaddingH)
            .padding(.vertical, BrandLayout.screenPaddingV)
        }
    }

    private var motionSubtitle: String {
        systemReduceMotion
        ? "Turned on system-wide in tvOS Accessibility settings. Animations are already reduced."
        : "Switch off entrance and focus animations across the app."
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: HomeViewModel())
    }
    .environment(AppSettings())
}
