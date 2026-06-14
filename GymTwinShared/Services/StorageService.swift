import Foundation
import SwiftData

/// A small repository abstraction over `ModelContext`. Centralises the
/// fetch / insert / delete / save boilerplate so view models stay focused on
/// behaviour, and gives a single seam to swap the storage mechanism later.
@MainActor
struct StorageService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Persists pending changes, swallowing nothing — callers may log.
    @discardableResult
    func save() -> Bool {
        guard context.hasChanges else { return true }
        do {
            try context.save()
            return true
        } catch {
            assertionFailure("StorageService save failed: \(error)")
            return false
        }
    }

    func insert<T: PersistentModel>(_ model: T) {
        context.insert(model)
        save()
    }

    func delete<T: PersistentModel>(_ model: T) {
        context.delete(model)
        save()
    }

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }

    func fetchAll<T: PersistentModel>(
        _ type: T.Type,
        sortBy: [SortDescriptor<T>] = []
    ) -> [T] {
        fetch(FetchDescriptor<T>(sortBy: sortBy))
    }

    func count<T: PersistentModel>(_ type: T.Type) -> Int {
        (try? context.fetchCount(FetchDescriptor<T>())) ?? 0
    }
}
