//
//  PresenceRealtimeBridge.swift
//  Push
//
//  Issue #84 — session-scoped Realtime bridge for `current_presence`.
//  Patches LiveDataStore; debounces revisions; reconciles after subscribe.
//

import Foundation
import Supabase

// MARK: - Protocols

@MainActor
protocol PresenceRealtimeBridging: AnyObject {
    func start() async
    func stop()
    var isRunning: Bool { get }
}

/// Yields app-owned wire events. Production uses Supabase postgres_changes.
@MainActor
protocol PresenceRealtimeEventSourcing: AnyObject {
    func events() -> AsyncStream<PresenceRealtimeWireEvent>
    func connect() async throws
    func disconnect()
}

enum PresenceRealtimeConstants {
    static let channelName = "current-presence"
    static let tableName = "current_presence"
    static let schemaName = "public"
}

// MARK: - Bridge

@MainActor
final class PresenceRealtimeBridge: PresenceRealtimeBridging {
    private let store: LiveDataStore
    private let currentUserID: Person.ID
    private let source: PresenceRealtimeEventSourcing
    private let debounceInterval: TimeInterval
    private let now: () -> Date

    private var generation: UInt = 0
    private var running = false
    private var listenTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var pendingOps: [PresenceRealtimeOp] = []
    private var reconcileTask: Task<Void, Never>?

    var isRunning: Bool { running }

    init(
        store: LiveDataStore,
        currentUserID: Person.ID,
        source: PresenceRealtimeEventSourcing,
        debounce: TimeInterval = LocationPipelineConstants.realtimePatchDebounce,
        now: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.currentUserID = currentUserID
        self.source = source
        self.debounceInterval = debounce
        self.now = now
    }

    /// Live convenience: Supabase postgres_changes source.
    convenience init(
        client: SupabaseClient,
        store: LiveDataStore,
        currentUserID: Person.ID,
        debounce: TimeInterval = LocationPipelineConstants.realtimePatchDebounce,
        now: @escaping () -> Date = { Date() }
    ) {
        self.init(
            store: store,
            currentUserID: currentUserID,
            source: SupabasePresenceRealtimeSource(client: client),
            debounce: debounce,
            now: now
        )
    }

    func start() async {
        guard !running else { return }
        stopInternal(disconnect: false)
        generation += 1
        let gen = generation
        running = true

        do {
            try await source.connect()
        } catch {
            PushLog.network.error(
                "presence_realtime_connect_failed \(PushLog.safeDescription(for: error), privacy: .public)"
            )
            running = false
            return
        }
        guard gen == generation, running else { return }

        await runReconcile(generation: gen)
        guard gen == generation, running else { return }

        listenTask = Task { [weak self] in
            guard let self else { return }
            let stream = self.source.events()
            for await event in stream {
                guard !Task.isCancelled else { break }
                await self.handle(event: event, generation: gen)
            }
        }
    }

    func stop() {
        stopInternal(disconnect: true)
    }

    // MARK: - Private lifecycle

    private func stopInternal(disconnect: Bool) {
        running = false
        generation += 1
        listenTask?.cancel()
        listenTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        reconcileTask?.cancel()
        reconcileTask = nil
        pendingOps.removeAll()
        if disconnect {
            source.disconnect()
        }
    }

    private func handle(event: PresenceRealtimeWireEvent, generation gen: UInt) async {
        guard gen == generation, running else { return }
        guard let op = PresenceRealtimeApplying.operation(
            from: event,
            currentUserID: currentUserID,
            now: now()
        ) else { return }

        switch op {
        case .reconcileHint:
            await runReconcile(generation: gen)
        case .upsert, .remove:
            pendingOps.append(op)
            scheduleDebounce(generation: gen)
        }
    }

    private func scheduleDebounce(generation gen: UInt) {
        debounceTask?.cancel()
        let interval = debounceInterval
        debounceTask = Task { [weak self] in
            let nanos = UInt64(max(interval, 0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            self?.flushPending(generation: gen)
        }
    }

    private func flushPending(generation gen: UInt) {
        guard gen == generation, running else {
            pendingOps.removeAll()
            return
        }
        let batch = pendingOps
        pendingOps.removeAll()
        var material = false
        for op in batch {
            switch op {
            case .upsert(let row):
                if store.applyRemotePresenceRow(row) { material = true }
            case .remove(let userID):
                if store.removeRemotePresence(userID: userID) { material = true }
            case .reconcileHint:
                break
            }
        }
        if material {
            store.publishPresenceRevision()
        }
    }

    private func runReconcile(generation gen: UInt) async {
        guard gen == generation, running else { return }
        if let reconcileTask {
            await reconcileTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let changed = try await self.store.reconcilePresence()
                guard gen == self.generation, self.running else { return }
                if changed {
                    self.store.publishPresenceRevision()
                }
            } catch {
                PushLog.network.error(
                    "presence_realtime_reconcile_failed \(PushLog.safeDescription(for: error), privacy: .public)"
                )
            }
        }
        reconcileTask = task
        await task.value
        // Clear only if we still own the coalesced task (stop may have replaced it).
        if reconcileTask != nil {
            reconcileTask = nil
        }
    }
}

// MARK: - Fake source (tests)

@MainActor
final class FakePresenceRealtimeSource: PresenceRealtimeEventSourcing {
    private(set) var connectCount = 0
    private(set) var disconnectCount = 0
    private var continuation: AsyncStream<PresenceRealtimeWireEvent>.Continuation?
    private var stream: AsyncStream<PresenceRealtimeWireEvent>?

    func events() -> AsyncStream<PresenceRealtimeWireEvent> {
        if let stream { return stream }
        let pair = AsyncStream<PresenceRealtimeWireEvent>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
        return pair.stream
    }

    func connect() async throws {
        connectCount += 1
        _ = events()
    }

    func disconnect() {
        disconnectCount += 1
        continuation?.finish()
        continuation = nil
        stream = nil
    }

    func yield(_ event: PresenceRealtimeWireEvent) {
        _ = events()
        continuation?.yield(event)
    }
}

// MARK: - Supabase source

@MainActor
final class SupabasePresenceRealtimeSource: PresenceRealtimeEventSourcing {
    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var eventStream: AsyncStream<PresenceRealtimeWireEvent>?
    private var continuation: AsyncStream<PresenceRealtimeWireEvent>.Continuation?
    private var pumpTask: Task<Void, Never>?

    init(client: SupabaseClient) {
        self.client = client
    }

    func events() -> AsyncStream<PresenceRealtimeWireEvent> {
        if let eventStream { return eventStream }
        let pair = AsyncStream<PresenceRealtimeWireEvent>.makeStream()
        eventStream = pair.stream
        continuation = pair.continuation
        return pair.stream
    }

    func connect() async throws {
        disconnect()
        _ = events()
        let channel = client.channel(PresenceRealtimeConstants.channelName)
        self.channel = channel
        let changes = channel.postgresChange(
            AnyAction.self,
            schema: PresenceRealtimeConstants.schemaName,
            table: PresenceRealtimeConstants.tableName
        )
        try await channel.subscribeWithError()
        pumpTask = Task { [weak self] in
            for await action in changes {
                guard !Task.isCancelled else { break }
                let wire = PresenceRealtimeWireMapping.wireEvent(from: action)
                self?.continuation?.yield(wire)
            }
        }
    }

    func disconnect() {
        pumpTask?.cancel()
        pumpTask = nil
        continuation?.finish()
        continuation = nil
        eventStream = nil
        if let channel {
            let client = self.client
            self.channel = nil
            Task { await client.removeChannel(channel) }
        }
    }
}

// MARK: - AnyAction → wire event

enum PresenceRealtimeWireMapping {
    private static let decoder = JSONDecoder()

    static func wireEvent(from action: AnyAction) -> PresenceRealtimeWireEvent {
        switch action {
        case .insert(let insert):
            return .insert(decodeRow(from: insert))
        case .update(let update):
            return .update(
                new: decodeRow(from: update),
                oldUserID: decodeUserID(from: update.oldRecord)
            )
        case .delete(let delete):
            return .delete(oldUserID: decodeUserID(from: delete.oldRecord))
        }
    }

    private static func decodeRow(from action: some HasRecord) -> CurrentPresenceRow? {
        try? action.decodeRecord(as: CurrentPresenceRow.self, decoder: decoder)
    }

    private static func decodeUserID(from record: [String: AnyJSON]) -> String? {
        if case .string(let id) = record["user_id"] { return id }
        return nil
    }
}
