//
//  FeedMediaPageStrip.swift
//  Push
//
//  Horizontal page strip for Feed media carousels. Programmatic advances and
//  drags animate as page swipes. Last → first loops via a cloned first page so
//  wrap-around also swipes forward. First-page chrome rides with slide 0.
//

import SwiftUI

/// Multi-page media scroller with animated selection handoffs.
struct FeedMediaPageStrip<FirstPageChrome: View>: View {
    let items: [FeedMediaItem]
    @Binding var selectedIndex: Int
    let size: CGSize
    /// Overlay on the first media page (and its loop clone) — avatars / play / Add yours.
    @ViewBuilder var firstPageChrome: () -> FirstPageChrome

    @State private var scrollIndex: Int = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isSettlingWrap = false
    @GestureState private var isDragging = false

    private var pageWidth: CGFloat { max(size.width, 1) }
    private var logicalCount: Int { items.count }
    private var allowsLoop: Bool { logicalCount > 1 }
    /// Extra trailing clone of page 0 enables forward wrap animation.
    private var stripCount: Int { allowsLoop ? logicalCount + 1 : logicalCount }

    private var logicalIndex: Int {
        FeedMediaCarouselSelection.clampedIndex(selectedIndex, itemCount: logicalCount)
    }

    private var contentOffsetX: CGFloat {
        -CGFloat(scrollIndex) * pageWidth + dragTranslation
    }

    private var pageAnimation: Animation {
        .easeInOut(duration: FeedMediaLayout.autoAdvanceAnimationDuration)
    }

    private var wrapSettleNanoseconds: UInt64 {
        UInt64(FeedMediaLayout.autoAdvanceAnimationDuration * 1_000_000_000)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<stripCount, id: \.self) { page in
                pageView(at: page)
                    .frame(width: pageWidth, height: size.height)
            }
        }
        .offset(x: contentOffsetX)
        .frame(width: pageWidth, height: size.height, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .gesture(pageDragGesture)
        .onAppear {
            scrollIndex = logicalIndex
        }
        .onChange(of: selectedIndex) { newValue in
            handleLogicalSelectionChange(to: newValue)
        }
        .onChange(of: logicalCount) { _ in
            scrollIndex = FeedMediaCarouselSelection.clampedIndex(
                selectedIndex,
                itemCount: logicalCount
            )
            dragTranslation = 0
            isSettlingWrap = false
        }
        .accessibilityElement(children: .contain)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                moveLogical(by: 1)
            case .decrement:
                moveLogical(by: -1)
            @unknown default:
                break
            }
        }
    }

    @ViewBuilder
    private func pageView(at page: Int) -> some View {
        let itemIndex = itemIndex(forStripPage: page)
        let item = items[itemIndex]
        ZStack {
            FeedMediaPageView(item: item, size: size)
            // Chrome lives on slide 0 + wrap clone so it swipes with the first photo.
            if itemIndex == 0 {
                firstPageChrome()
            }
        }
        .frame(width: pageWidth, height: size.height)
        .clipped()
    }

    private func itemIndex(forStripPage page: Int) -> Int {
        if allowsLoop, page >= logicalCount {
            return 0
        }
        return FeedMediaCarouselSelection.clampedIndex(page, itemCount: logicalCount)
    }

    // MARK: - Selection sync (autoplay / external)

    private func handleLogicalSelectionChange(to newValue: Int) {
        guard !isSettlingWrap else { return }
        let newLogical = FeedMediaCarouselSelection.clampedIndex(
            newValue,
            itemCount: logicalCount
        )
        let from = scrollIndex

        // Forward wrap: last logical page → first (via trailing clone).
        if allowsLoop, from == logicalCount - 1, newLogical == 0 {
            animateForwardWrap()
            return
        }

        // Already showing clone while settling — ignore.
        if from == logicalCount, newLogical == 0 {
            return
        }

        withAnimation(pageAnimation) {
            scrollIndex = newLogical
            dragTranslation = 0
        }
    }

    private func animateForwardWrap() {
        isSettlingWrap = true
        withAnimation(pageAnimation) {
            // Clone of first page sits at strip index `logicalCount`.
            scrollIndex = logicalCount
            dragTranslation = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: wrapSettleNanoseconds)
            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) {
                scrollIndex = 0
                dragTranslation = 0
                isSettlingWrap = false
            }
        }
    }

    // MARK: - Drag

    private var pageDragGesture: some Gesture {
        DragGesture(minimumDistance: FeedMediaPageStripMetrics.dragMinimumDistance)
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                guard !isSettlingWrap else { return }
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
                guard !isSettlingWrap else {
                    dragTranslation = 0
                    return
                }
                finishDrag(
                    translation: value.translation.width,
                    predicted: value.predictedEndTranslation.width
                )
            }
    }

    private func rubberBandedTranslation(_ raw: CGFloat) -> CGFloat {
        // Allow free drag into the wrap clone from the last page.
        if allowsLoop, scrollIndex == logicalCount - 1, raw < 0 {
            return raw
        }
        let atStart = scrollIndex == 0 && raw > 0
        let atEnd = !allowsLoop && scrollIndex >= logicalCount - 1 && raw < 0
        guard atStart || atEnd else { return raw }
        return raw * FeedMediaPageStripMetrics.edgeRubberBand
    }

    private func finishDrag(translation: CGFloat, predicted: CGFloat) {
        let threshold = pageWidth * FeedMediaPageStripMetrics.pageCommitFraction
        let decisive = abs(predicted) > abs(translation) ? predicted : translation

        if decisive < -threshold {
            // Next page (or wrap via clone of first).
            if allowsLoop, scrollIndex >= logicalCount - 1 {
                // Setting logical index 0 drives forward-wrap animation in onChange.
                selectedIndex = 0
                return
            }
            let next = min(scrollIndex + 1, logicalCount - 1)
            commitLogicalSelection(next)
            return
        }

        if decisive > threshold {
            let previous = max(scrollIndex - 1, 0)
            // If user pulled back from clone before settle, treat as last page.
            if scrollIndex == logicalCount {
                commitLogicalSelection(logicalCount - 1)
                return
            }
            commitLogicalSelection(previous)
            return
        }

        // Cancel — spring back to current page.
        withAnimation(pageAnimation) {
            dragTranslation = 0
            if scrollIndex == logicalCount {
                scrollIndex = logicalCount - 1
            }
        }
    }

    private func commitLogicalSelection(_ index: Int) {
        let next = FeedMediaCarouselSelection.clampedIndex(index, itemCount: logicalCount)
        // Prefer binding update so onChange owns a single animation path.
        if selectedIndex != next {
            selectedIndex = next
            return
        }
        withAnimation(pageAnimation) {
            scrollIndex = next
            dragTranslation = 0
        }
    }

    private func moveLogical(by delta: Int) {
        guard logicalCount > 0 else { return }
        if allowsLoop {
            let raw = logicalIndex + delta
            if raw >= logicalCount {
                selectedIndex = 0
                return
            }
            if raw < 0 {
                selectedIndex = logicalCount - 1
                withAnimation(pageAnimation) {
                    scrollIndex = logicalCount - 1
                    dragTranslation = 0
                }
                return
            }
            selectedIndex = raw
            return
        }
        selectedIndex = FeedMediaCarouselSelection.clampedIndex(
            logicalIndex + delta,
            itemCount: logicalCount
        )
    }
}

enum FeedMediaPageStripMetrics {
    static let dragMinimumDistance: CGFloat = 16
    /// Horizontal drag must dominate vertical by this factor to take over.
    static let horizontalDominance: CGFloat = 1.15
    static let pageCommitFraction: CGFloat = 0.22
    static let edgeRubberBand: CGFloat = 0.28
}
