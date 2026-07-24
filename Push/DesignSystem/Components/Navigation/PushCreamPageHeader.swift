//
//  PushCreamPageHeader.swift
//  Push
//
//  DS-060 — cream-page title stack + trailing circular actions.
//

import SwiftUI

enum PushCreamPageHeaderMetrics {
    static let subtitleSpacing: CGFloat = 3
}

/// Leading title (+ optional subtitle) and trailing action slot for ivory destinations.
struct PushCreamPageHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: PushCreamPageHeaderMetrics.subtitleSpacing) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(PushControlColors.activeForeground)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(PushControlColors.inactiveForeground)
                }
            }

            Spacer(minLength: 0)

            trailing()
        }
    }
}

extension PushCreamPageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = { EmptyView() }
    }
}
