import Foundation
import SwiftData
import CryptoKit

/// Backs AdminPanelView. Manages the machine catalog, passcode gate,
/// and optional OpenSearch sync. All mutable state is @MainActor.
@Observable
@MainActor
final class AdminViewModel {

    // MARK: - Passcode state

    /// True once the correct passcode has been entered this session.
    private(set) var isUnlocked: Bool = false
    /// True when no passcode has ever been set (first-use flow).
    private(set) var isFirstUse: Bool = false
    /// Non-nil when unlock/set failed.
    private(set) var passcodeError: String?

    // MARK: - Machine library state

    private(set) var definitions: [MachineDefinition] = []
    private(set) var isLoadingDefs: Bool = false

    // MARK: - Sync state

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success(Int)
        case notConfigured
        case failed(String)
    }
    private(set) var syncStatus: SyncStatus = .idle

    // MARK: - Private

    private let repo: LocalMachineRepository
    /// AppStorage key for the hashed passcode.
    private static let hashKey = "admin.passcode.hash"
    /// Stored hash is a hex-encoded SHA-256 of the 4-digit string. Backed by
    /// UserDefaults directly — `@AppStorage` is a View-only property wrapper
    /// and cannot live inside an `@Observable` class.
    private var storedHash: String {
        get { UserDefaults.standard.string(forKey: Self.hashKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.hashKey) }
    }

    // MARK: - Init

    init(repository: LocalMachineRepository = LocalMachineRepository()) {
        self.repo = repository
        isFirstUse = storedHash.isEmpty
    }

    // MARK: - Binding

    /// Called once by the view with the active ModelContext (unused directly,
    /// kept for consistency with the project's bind(_ context:) pattern).
    func bind(_ context: ModelContext) {
        // No SwiftData models owned here; context kept for future extension.
        Task { await loadDefinitions() }
    }

    /// Reload definitions from the local repository.
    func refresh() {
        Task { await loadDefinitions() }
    }

    // MARK: - Passcode

    /// Attempt to unlock. On first use, sets the passcode. On subsequent use,
    /// verifies it. Returns true when the action succeeds.
    @discardableResult
    func submitPasscode(_ code: String) -> Bool {
        guard code.count == 4, code.allSatisfy(\.isNumber) else {
            passcodeError = "Enter a 4-digit code."
            return false
        }
        let hash = sha256(code)
        if isFirstUse {
            storedHash = hash
            isFirstUse = false
            isUnlocked = true
            passcodeError = nil
            return true
        } else {
            if hash == storedHash {
                isUnlocked = true
                passcodeError = nil
                return true
            } else {
                passcodeError = "Incorrect code. Try again."
                return false
            }
        }
    }

    func lock() { isUnlocked = false }

    func clearPasscodeError() { passcodeError = nil }

    // MARK: - Machine library

    private func loadDefinitions() async {
        isLoadingDefs = true
        defer { isLoadingDefs = false }
        definitions = (try? await repo.allMachines()) ?? []
    }

    /// Persist a new or updated MachineDefinition to the local repository.
    func upsert(_ definition: MachineDefinition) async {
        try? await repo.upsert(definition)
        await loadDefinitions()
    }

    // MARK: - OpenSearch sync

    /// Pushes the entire local catalog to OpenSearch if configured.
    func syncToOpenSearch() async {
        syncStatus = .syncing
        let remoteRepo = OpenSearchMachineRepository()
        guard remoteRepo.config != nil else {
            syncStatus = .notConfigured
            return
        }
        do {
            let defs = (try? await repo.allMachines()) ?? []
            for def in defs {
                try await remoteRepo.upsert(def)
            }
            syncStatus = .success(defs.count)
        } catch RepositoryError.notConfigured {
            syncStatus = .notConfigured
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
