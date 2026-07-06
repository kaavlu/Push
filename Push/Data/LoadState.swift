//
//  LoadState.swift
//  Push
//

import Foundation

/// Lightweight loading/error state for view-model content. The local data
/// layer never fails, but the seam supports it so a real backend won't
/// retrofit loading UX onto every screen.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(Error)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
