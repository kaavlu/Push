//
//  OnboardingSetupScreens.swift
//  Push
//
//  Profile creation and privacy selection — the heart of the setup
//  progress bar.
//

#if DEBUG
import SwiftUI

// MARK: - Profile

struct OnboardingProfileScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: OnboardingLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "Make it you.",
                subtitle: "This is how friends will spot you on the map."
            )
            photoPicker.frame(maxWidth: .infinity).padding(.top, 26)
            fields.padding(.top, 30)
            Spacer(minLength: 28)
            OnboardingCTAButton(title: "Continue") { model.go(to: .privacy) }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout) + layout.value(compact: 2, standard: 3, large: 4))
        .padding(.bottom, 26)
    }

    private var photoPicker: some View {
        Button(action: model.togglePhoto) {
            ZStack(alignment: .bottomTrailing) {
                photoContent
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(OnboardingLabColor.ctaLabel)
                    .frame(width: 34, height: 34)
                    .background(OnboardingLabColor.ctaBottom, in: Circle())
            }
            .frame(width: 118, height: 118)
        }
        .buttonStyle(PushPressStyle())
    }

    @ViewBuilder
    private var photoContent: some View {
        if model.photoAdded {
            OnboardingAvatar(assetName: OnboardingLabFixtures.profileImageAssetName, size: 118, ring: OnboardingLabColor.sunbeam)
        } else {
            Image(systemName: "camera.fill")
                .font(.system(size: 30))
                .foregroundStyle(OnboardingLabColor.walnut)
                .frame(width: 118, height: 118)
                .background(OnboardingLabColor.fieldFill, in: Circle())
                .overlay(Circle().stroke(OnboardingLabColor.walnut.opacity(0.16), lineWidth: 2))
        }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            labeledField(label: "Name") {
                TextField("First name", text: $model.name)
                    .font(OnboardingLabFont.rounded(18, .semibold))
                    .foregroundStyle(OnboardingLabColor.espresso)
            }
            labeledField(label: "Handle") {
                HStack(spacing: 2) {
                    Text("@")
                        .font(OnboardingLabFont.rounded(18, .bold))
                        .foregroundStyle(OnboardingLabColor.textTertiary)
                    TextField("yourname", text: handleBinding)
                        .font(OnboardingLabFont.rounded(18, .semibold))
                        .foregroundStyle(OnboardingLabColor.espresso)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
        }
    }

    private var handleBinding: Binding<String> {
        Binding(get: { model.handle }, set: { model.setHandle($0) })
    }

    private func labeledField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(OnboardingLabFont.text(12, .bold))
                .kerning(0.5)
                .foregroundStyle(OnboardingLabColor.textTertiary)
                .padding(.leading, 6)
            content()
                .padding(.horizontal, 18)
                .frame(height: OnboardingLabMetric.fieldHeight)
                .background(OnboardingLabColor.fieldFill, in: RoundedRectangle(cornerRadius: OnboardingLabMetric.fieldCornerRadius, style: .continuous))
        }
    }
}

// MARK: - Privacy

struct OnboardingPrivacyScreen: View {
    @Environment(\.pushLayout) private var layout
    @ObservedObject var model: OnboardingLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "You're in control.",
                subtitle: "Pick what friends can see. Change it anytime."
            )
            options.padding(.top, 20)
            Spacer(minLength: 22)
            OnboardingCTAButton(title: "Continue") { model.go(to: .location) }
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding(layout))
        .padding(.top, OnboardingLabMetric.contentTopInset(layout))
        .padding(.bottom, 26)
    }

    private var options: some View {
        VStack(spacing: 11) {
            ForEach(OnboardingPrivacyOption.allCases) { option in
                OnboardingPrivacyRow(
                    option: option,
                    isSelected: model.privacy == option,
                    onTap: { model.select(option) }
                )
            }
        }
    }
}

/// A single selectable privacy option with icon tile + checkmark.
private struct OnboardingPrivacyRow: View {
    let option: OnboardingPrivacyOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                iconTile
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(OnboardingLabFont.rounded(16, .bold))
                        .foregroundStyle(OnboardingLabColor.espresso)
                    Text(option.subtitle)
                        .font(OnboardingLabFont.text(13, .regular))
                        .foregroundStyle(OnboardingLabColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isSelected { checkmark }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .background(OnboardingLabColor.fieldFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(highlight)
        }
        .buttonStyle(PushPressStyle())
        .animation(OnboardingLabMotion.standard, value: isSelected)
    }

    private var iconTile: some View {
        Image(systemName: option.symbolName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(option.iconTint)
            .frame(width: 44, height: 44)
            .background(option.iconTint.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var checkmark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(OnboardingLabColor.sage, in: Circle())
    }

    @ViewBuilder
    private var highlight: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(OnboardingLabColor.sunbeam, lineWidth: 2.5)
                .shadow(color: OnboardingLabColor.sunbeam.opacity(0.28), radius: 9, y: 8)
        }
    }
}
#endif
