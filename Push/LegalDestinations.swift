import SwiftUI

struct LegalDestination: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let url: URL
}

enum LegalDestinations {
    // RELEASE BLOCKER: replace these reachable placeholders with the final,
    // unauthenticated public documents before distributing Push publicly.
    static let termsURL = URL(string: "https://example.com/?push-legal=terms")!
    static let privacyURL = URL(string: "https://example.com/?push-legal=privacy")!

    static let all = [
        LegalDestination(
            id: "terms-of-service",
            title: "Terms of Service",
            subtitle: "The rules for using Push",
            symbolName: "doc.text.fill",
            url: termsURL
        ),
        LegalDestination(
            id: "privacy-policy",
            title: "Privacy Policy",
            subtitle: "How Push handles your information",
            symbolName: "hand.raised.fill",
            url: privacyURL
        ),
    ]
}

struct LegalConsentText: View {
    var body: some View {
        Text(attributedCopy)
            .font(OnboardingLabFont.text(12, .regular))
            .foregroundStyle(OnboardingLabColor.textTertiary)
            .tint(OnboardingLabColor.walnut)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.top, 6)
    }

    private var attributedCopy: AttributedString {
        var copy = AttributedString("By continuing you agree to Push's ")
        copy.append(link("Terms", destination: LegalDestinations.termsURL))
        copy.append(AttributedString(" & "))
        copy.append(link("Privacy", destination: LegalDestinations.privacyURL))
        copy.append(AttributedString("."))
        return copy
    }

    private func link(_ title: String, destination: URL) -> AttributedString {
        var value = AttributedString(title)
        value.link = destination
        value.inlinePresentationIntent = .stronglyEmphasized
        return value
    }
}
