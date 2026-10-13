//
//  PlayerSlotCard.swift
//  IT23251182-tvOS
//
//  One editable player slot.
//
//  Each slot carries its seat colour on the avatar, the seat number and the
//  left edge, so four cards side by side are distinguishable at a glance from
//  across a room rather than only by the name typed into them.
//
//  Focus order within a card is avatar → name field → remove, which matches the
//  order someone fills them in.
//

import SwiftUI

struct PlayerSlotCard: View {

    let player: Player
    let seat: Int
    let isDuplicate: Bool
    let canRemove: Bool

    let onNameChange: (String) -> Void
    let onCycleAvatar: () -> Void
    let onRemove: () -> Void

    /// Local mirror of the text field. tvOS commits the full-screen keyboard's
    /// result back through this binding; the view model is updated on change.
    @State private var name: String = ""

    private var seatColor: Color { Brand.playerColor(at: seat - 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            header

            avatarButton

            nameField

            if canRemove {
                removeButton
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BrandLayout.cardRadius, style: .continuous)
                .fill(Brand.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandLayout.cardRadius, style: .continuous)
                .strokeBorder(isDuplicate ? Brand.incorrect : Brand.hairline,
                              lineWidth: isDuplicate ? 4 : 2)
        )
        // A coloured left edge identifies the seat even when nothing is focused.
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(seatColor)
                .frame(width: 8)
                .padding(.vertical, 24)
        }
        .onAppear { name = player.name }
        // Keeps the field in step when the view model changes the name itself,
        // for example after a remembered roster loads.
        .onChange(of: player.name) { _, newValue in
            if newValue != name { name = newValue }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Text("PLAYER \(seat)")
                .font(BrandFont.caption)
                .tracking(3)
                .foregroundStyle(seatColor)
            Spacer()
            if isDuplicate {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Brand.incorrect)
                    .accessibilityHidden(true)
            }
        }
    }

    private var avatarButton: some View {
        Button(action: onCycleAvatar) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(seatColor.opacity(0.18))
                        .frame(width: 78, height: 78)
                    Image(systemName: player.avatar.symbolName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(seatColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.avatar.displayName)
                        .font(BrandFont.caption)
                        .foregroundStyle(Brand.textPrimary)
                    Text("Change")
                        .font(BrandFont.caption)
                        .foregroundStyle(Brand.textTertiary)
                }
                Spacer()
            }
        }
        .buttonStyle(BrandRowStyle())
        .accessibilityLabel("Player \(seat) avatar")
        .accessibilityValue(player.avatar.displayName)
        .accessibilityHint("Changes to the next available avatar")
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            // On tvOS a focused TextField opens the system's full-screen
            // keyboard, which is the platform's own text-entry mechanism —
            // there is no on-screen keyboard to build ourselves.
            TextField("Enter name", text: $name)
                .font(BrandFont.label)
                .foregroundStyle(Brand.textPrimary)
                .onChange(of: name) { _, newValue in
                    onNameChange(newValue)
                }
                .accessibilityLabel("Player \(seat) name")

            if isDuplicate {
                Text("Duplicate name")
                    .font(BrandFont.caption)
                    .foregroundStyle(Brand.incorrect)
            }
        }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Label("Remove", systemImage: "minus.circle.fill")
        }
        .buttonStyle(BrandButtonStyle(kind: .secondary))
        .accessibilityLabel("Remove player \(seat)")
    }
}
