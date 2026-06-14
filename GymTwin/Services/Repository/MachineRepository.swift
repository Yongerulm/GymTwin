import Foundation

enum RepositoryError: Error, LocalizedError {
    case notConfigured
    case notFound(String)
    case decodingFailed
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "The remote repository is not configured."
        case .notFound(let code): return "No machine found for code “\(code)”."
        case .decodingFailed: return "Could not decode machine data."
        case .transport(let m): return "Network error: \(m)"
        }
    }
}

/// Abstract data source for the equipment library. The app depends only on
/// this protocol, so the bundled/local store can be swapped for OpenSearch by
/// changing one binding — no call site changes (Dependency Inversion / SOLID).
protocol MachineRepository: Sendable {
    func allMachines() async throws -> [MachineDefinition]
    func machine(forCode code: String) async throws -> MachineDefinition?
    func search(_ query: String) async throws -> [MachineDefinition]
    /// Add or update a definition (used by the Admin panel).
    func upsert(_ machine: MachineDefinition) async throws
}

/// Default offline repository: seeds from the bundled `machines.json` and
/// merges any admin-added definitions persisted in Application Support. Fully
/// functional with no backend.
actor LocalMachineRepository: MachineRepository {
    private var cache: [String: MachineDefinition] = [:]
    private var loaded = false

    private let bundle: Bundle
    private let overridesURL: URL?

    /// - Parameter overridesURL: where admin-added definitions are persisted.
    ///   Pass `nil` to disable persistence entirely (used by tests for full
    ///   isolation from the shared on-disk store).
    init(bundle: Bundle = .main, overridesURL: URL? = LocalMachineRepository.makeOverridesURL()) {
        self.bundle = bundle
        self.overridesURL = overridesURL
    }

    static func makeOverridesURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return dir.appendingPathComponent("machine_overrides.json")
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        // 1) bundled seed library
        if let url = bundle.url(forResource: "machines", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let defs = try? JSONDecoder().decode([MachineDefinition].self, from: data) {
            for def in defs { cache[def.machineCode] = def }
        }
        // 2) admin-added overrides
        if let overridesURL, let data = try? Data(contentsOf: overridesURL),
           let defs = try? JSONDecoder().decode([MachineDefinition].self, from: data) {
            for def in defs { cache[def.machineCode] = def }
        }
    }

    func allMachines() async throws -> [MachineDefinition] {
        loadIfNeeded()
        return cache.values.sorted { $0.name < $1.name }
    }

    func machine(forCode code: String) async throws -> MachineDefinition? {
        loadIfNeeded()
        return cache[code.lowercased()] ?? cache[code]
    }

    func search(_ query: String) async throws -> [MachineDefinition] {
        loadIfNeeded()
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return try await allMachines() }
        return cache.values
            .filter {
                $0.name.lowercased().contains(q) ||
                $0.category.lowercased().contains(q) ||
                $0.primaryMuscles.contains { $0.lowercased().contains(q) }
            }
            .sorted { $0.name < $1.name }
    }

    func upsert(_ machine: MachineDefinition) async throws {
        loadIfNeeded()
        cache[machine.machineCode] = machine
        persistOverrides()
    }

    private func persistOverrides() {
        guard let overridesURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(Array(cache.values).sorted { $0.machineCode < $1.machineCode }) {
            try? data.write(to: overridesURL, options: .atomic)
        }
    }
}
