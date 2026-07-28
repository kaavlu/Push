//
//  FeedMediaPageStrip.swift
//  Push
//
//  Horizontal page strip for Feed media carousels. Programmatic index changes
//  (auto-advance) animate with a page swipe; drag gestures still page manually.
//

import SwiftUI

/// Multi-page media scroller with animated selection handoffs.
struct FeedMediaPageStrip: View {
    let items: [FeedMediaItem]
    @Binding var selectedIndex: Int
    let size: CGSize

    @State private var dragTranslation: CGFloat = 0
    @GestureState private var isDragging = false

    private var pageWidth: CGFloat { max(size.width, 1) }
    private var pageCount: Int { items.count }

    private var clampedIndex: Int {
        FeedMediaCarouselSelection.clampedIndex(selectedIndex, itemCount: pageCount)
    }

    /// Base offset for the selected page, plus in-flight drag.
    private var contentOffsetX: CGFloat {
        -CGFloat(clampedIndex) * pageWidth + dragTranslation
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                FeedMediaPageView(item: item, size: size)
                    .frame(width: pageWidth, height: size.height)
            }
        }
        .offset(x: contentOffsetX)
        .frame(width: pageWidth, height: size.height, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .gesture(pageDragGesture)
        .onChange(of: selectedIndex) { _ in
            // External advance (autoplay) leaves drag at rest.
            if !isDragging, dragTranslation != 0 {
                dragTranslation = 0
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                selectPage(clampedIndex + 1, animated: true)
            case .decrement:
                selectPage(clampedIndex - 1, animated: true)
            @unknown default:
                break
            }
        }
    }

    private var pageDragGesture: some Gesture {
        DragGesture(minimumDistance: FeedMediaPageStripMetrics.dragMinimumDistance)
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                // Prefer horizontal intent so vertical Feed scroll still works.
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) >= abs(vertical) * FeedMediaPageStripMetrics.horizontalDominance
                else {
                    dragTranslation = 0
                    return
                }
                dragTranslation = rubberBandedTranslation(horizontal)
            }
            .onEnded { value in
                finishDrag(
                    translation: value.translation.width,
                    predicted: value.predictedEndTranslation.width
                )
            }
    }

    private func rubberBandedTranslation(_ raw: CGFloat) -> CGFloat {
        let atStart = clampedIndex == 0 && raw > 0
        let atEnd = clampedIndex >= pageCount - 1 && raw < 0
        guard atStart || atEnd else { return raw }
        return raw * FeedMediaPageStripMetrics.edgeRubberBand
    }

    private func finishDrag(translation: CGFloat, predicted: CGFloat) {
        let threshold = pageWidth * FeedMediaPageStripMetrics.pageCommitFraction
        let decisive = abs(predicted) > abs(translation) ? predicted : translation
        var target = clampedIndex
        if decisive < -threshold {
            target = min(clampedIndex + 1, pageCount - 1)
        } else if decisive > threshold {
            target = max(clampedIndex - 1, 0)
        }
        withAnimation(pageAnimation) {
            selectedIndex = target
            dragTranslation = 0
        }
    }

    private func selectPage(_ index: Int, animated: Bool) {
        let next = FeedMediaCarouselSelection.clampedIndex(index, itemCount: pageCount)
        if animated {
            withAnimation(pageAnimation) {
                selectedIndex = next
                dragTranslation = 0
            }
        } else {
            selectedIndex = next
            dragTranslation = 0
        }
    }

    private var pageAnimation: Animation {
        .easeInOut(duration: FeedMediaLayout.autoAdvanceAnimationDuration)
    }
}

enum FeedMediaPageStripMetrics {
    static let dragMinimumDistance: CGFloat = 16
    /// Horizontal drag must dominate vertical by this factor to take over.
    static let horizontalDominance: CGFloat = 1.15
    static let pageCommitFraction: CGFloat = 0.22
    static let edgeRubberBand: CGFloat = 0.28
}
