//
//  OnboardingAuthScreens.swift
//  Push
//
//  Mobile sign-in path: phone number entry and code verification.
//  Both drive the shared numeric keypad through the view model.
//

#if DEBUG
import SwiftUI

// MARK: - Phone

struct OnboardingPhoneScreen: View {
    @ObservedObject var model: OnboardingLabViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeader(
                title: "What's your number?",
                subtitle: "We'll text you a code to make sure it's really you."
            )
            entryRow.padding(.top, 26)
            OnboardingCTAButton(title: "Send code") { model.go(to: .verify) }
                .padding(.top, 22)
            Spacer(minLength: 24)
            OnboardingKeypad(onDigit: { model.pressDigit($0) }, onDelete: { model.deleteDigit() })
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding)
        .padding(.top, 120)
        .padding(.bottom, 26)
    }

    private var entryRow: some View {
        HStack(spacing: 10) {
            Text("🇺🇸 +1")
                .font(OnboardingLabFont.rounded(18, .bold))
                .foregroundStyle(OnboardingLabColor.espresso)
                .padding(.horizontal, 16)
                .frame(height: 60)
                .background(OnboardingLabColor.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack {
                if model.phone.isEmpty {
                    Text("(555) 000-0000")
                        .font(OnboardingLabFont.rounded(20, .semibold))
                        .foregroundStyle(OnboardingLabColor.textTertiary)
                } else {
                    Text(model.formattedPhone)
                        .font(OnboardingLabFont.rounded(22, .bold))
                        .foregroundStyle(OnboardingLabColor.espresso)
                        .kerning(0.5)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(OnboardingLabColor.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - Verify

struct OnboardingVerifyScreen: View {
    @ObservedObject var model: OnboardingLabViewModel

    private let cellCount = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            codeCells.padding(.top, 30)
            resend.padding(.top, 22)
            Spacer(minLength: 24)
            OnboardingKeypad(onDigit: { model.pressDigit($0) }, onDelete: { model.deleteDigit() })
        }
        .padding(.horizontal, OnboardingLabMetric.screenHorizontalPadding)
        .padding(.top, 120)
        .padding(.bottom, 26)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter the code")
                .font(OnboardingLabFont.rounded(30, .heavy))
                .foregroundStyle(OnboardingLabColor.espresso)
            (Text("Sent to ")
                + Text(model.verifyNumber).foregroundColor(OnboardingLabColor.walnut).bold())
                .font(OnboardingLabFont.text(16, .medium))
                .foregroundStyle(OnboardingLabColor.textSecondary)
        }
    }

    private var codeCells: some View {
        HStack(spacing: 12) {
            ForEach(0..<cellCount, id: \.self) { index in
                cell(at: index)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cell(at index: Int) -> some View {
        let characters = Array(model.code)
        let value = index < characters.count ? String(characters[index]) : ""
        let isCursor = index == characters.count
        return Text(value)
            .font(OnboardingLabFont.rounded(34, .heavy))
            .foregroundStyle(OnboardingLabColor.espresso)
            .frame(width: 62, height: 74)
            .background(OnboardingLabColor.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(borderColor(isCursor: isCursor, filled: !value.isEmpty), lineWidth: 2)
            )
    }

    private func borderColor(isCursor: Bool, filled: Bool) -> Color {
        if isCursor { return OnboardingLabColor.walnut }
        return filled ? OnboardingLabColor.walnut.opacity(0.3) : OnboardingLabColor.walnut.opacity(0.14)
    }

    private var resend: some View {
        (Text("Didn't get it? ")
            + Text("Resend code").foregroundColor(OnboardingLabColor.walnut).bold())
            .font(OnboardingLabFont.text(14, .regular))
            .foregroundStyle(OnboardingLabColor.textSecondary)
            .frame(maxWidth: .infinity)
    }
}
#endif
