import Foundation
import OSLog
import SwiftData

/// The only writer to the SwiftData store.
@MainActor
public final class ClipStore {
    public let context: ModelContext
    public let images: ImageFileStore
    private let logger = Logger(subsystem: "com.aholoiad.clipbar", category: "ClipStore")

    /// Called after any mutation (used to refresh widgets).
    public var onChange: (@MainActor () -> Void)?

    public init(context: ModelContext, images: ImageFileStore) {
        self.context = context
        self.images = images
    }

    // MARK: Queries

    public func item(withHash hash: String) -> ClipItem? {
        var descriptor = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.contentHash == hash })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    public func allItems() -> [ClipItem] {
        let descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: Mutations

    /// Inserts a new item or bumps an existing identical one to the top. Returns the item.
    @discardableResult
    public func ingest(_ payload: ClipPayload, now: Date = .now) -> ClipItem? {
        if let existing = item(withHash: payload.contentHash) {
            existing.createdAt = now
            if let bundle = payload.sourceAppBundleID {
                existing.sourceAppBundleID = bundle
                existing.sourceAppName = payload.sourceAppName
            }
            save()
            return existing
        }
        let item = ClipItem(kind: payload.kind, text: payload.text, contentHash: payload.contentHash,
                            createdAt: now, lastUsedAt: now,
                            sourceAppBundleID: payload.sourceAppBundleID, sourceAppName: payload.sourceAppName)
        if let data = payload.imageData {
            do {
                let stored = try images.store(data, id: item.id)
                item.imageFileName = stored.fileName
                item.thumbnailData = stored.thumbnail
                item.imageWidth = stored.width
                item.imageHeight = stored.height
            } catch {
                logger.error("Image store failed: \(error.localizedDescription)")
                return nil
            }
        }
        context.insert(item)
        save()
        return item
    }

    public func markUsed(_ item: ClipItem, now: Date = .now) {
        item.useCount += 1
        item.lastUsedAt = now
        save()
    }

    public func togglePin(_ item: ClipItem) {
        item.isPinned.toggle()
        save()
    }

    public func toggleSaved(_ item: ClipItem) {
        item.isSaved.toggle()
        save()
    }

    /// Replaces the text of a text-like clip, re-classifying it. If another clip already has the new
    /// content, that clip is removed so there are no duplicates.
    public func updateText(_ item: ClipItem, to text: String) {
        guard item.kind != .image else { return }
        let payload = ClipPayload(text: text)
        if let other = self.item(withHash: payload.contentHash), other.id != item.id {
            item.isPinned = item.isPinned || other.isPinned
            item.useCount += other.useCount
            context.delete(other)
        }
        item.text = text
        item.kind = payload.kind
        item.contentHash = payload.contentHash
        save()
    }

    /// Deletes unpinned clips captured before `date`. Returns how many were removed.
    @discardableResult
    public func removeUnpinned(olderThan date: Date) -> Int {
        let old = allItems().filter { !$0.isPinned && !$0.isSaved && $0.createdAt < date }
        for item in old {
            if let file = item.imageFileName { images.delete(fileName: file) }
            context.delete(item)
        }
        if !old.isEmpty { save() }
        return old.count
    }

    /// Deletes unpinned secrets (API keys, tokens) captured before `date`.
    @discardableResult
    public func removeSecrets(olderThan date: Date) -> Int {
        let old = allItems().filter { !$0.isPinned && $0.isSecret && $0.createdAt < date }
        for item in old { context.delete(item) }
        if !old.isEmpty { save() }
        return old.count
    }

    /// Number of clips captured since the given date.
    public func count(since date: Date) -> Int {
        let d = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.createdAt >= date })
        return (try? context.fetchCount(d)) ?? 0
    }

    public func delete(_ item: ClipItem) {
        if let file = item.imageFileName { images.delete(fileName: file) }
        context.delete(item)
        save()
    }

    /// Removes everything except pinned and saved items.
    public func clearHistory() {
        for item in allItems() where !item.isPinned && !item.isSaved {
            if let file = item.imageFileName { images.delete(fileName: file) }
            context.delete(item)
        }
        save()
    }

    /// Keeps at most `limit` unpinned, unsaved items (newest win). `limit <= 0` means unlimited.
    public func enforceLimit(_ limit: Int) {
        guard limit > 0 else { return }
        let evictable = allItems().filter { !$0.isPinned && !$0.isSaved }
        guard evictable.count > limit else { return }
        for item in evictable[limit...] {
            if let file = item.imageFileName { images.delete(fileName: file) }
            context.delete(item)
        }
        save()
    }

    private func save() {
        do { try context.save() } catch { logger.error("Save failed: \(error.localizedDescription)") }
        onChange?()
    }
}
