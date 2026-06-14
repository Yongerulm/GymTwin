import Foundation

/// Connection details for an OpenSearch cluster. Loaded from environment /
/// Info.plist / Admin panel — never hardcoded. When `baseURL` is nil the
/// repository is considered unconfigured and the app stays on the local store.
struct OpenSearchConfig: Sendable {
    let baseURL: URL
    let index: String
    /// Optional HTTP Basic auth header value, e.g. "Basic <base64>".
    let authorization: String?

    static let indexName = "machines"

    /// Reads config from the environment (CI / advanced users). Returns nil
    /// when not configured, which keeps the app fully offline by default.
    static func fromEnvironment() -> OpenSearchConfig? {
        let env = ProcessInfo.processInfo.environment
        guard let urlString = env["OPENSEARCH_URL"], let url = URL(string: urlString) else { return nil }
        return OpenSearchConfig(baseURL: url, index: indexName, authorization: env["OPENSEARCH_AUTH"])
    }

    /// The index mapping for the `machines` index — ready to PUT on setup.
    static let indexMapping: String = """
    {
      "mappings": {
        "properties": {
          "machineCode":      { "type": "keyword" },
          "name":             { "type": "text" },
          "manufacturer":     { "type": "keyword" },
          "category":         { "type": "keyword" },
          "movementPattern":  { "type": "keyword" },
          "primaryMuscles":   { "type": "keyword" },
          "secondaryMuscles": { "type": "keyword" },
          "difficulty":       { "type": "keyword" },
          "equipmentType":    { "type": "keyword" }
        }
      }
    }
    """
}

/// OpenSearch-backed implementation of `MachineRepository`. Wired and ready:
/// supply an `OpenSearchConfig` and it performs real REST calls; with no
/// config every call throws `RepositoryError.notConfigured`, so the app
/// transparently falls back to `LocalMachineRepository`.
struct OpenSearchMachineRepository: MachineRepository {
    let config: OpenSearchConfig?
    private let session: URLSession

    init(config: OpenSearchConfig? = OpenSearchConfig.fromEnvironment(), session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    private func request(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let config else { throw RepositoryError.notConfigured }
        var req = URLRequest(url: config.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let auth = config.authorization { req.setValue(auth, forHTTPHeaderField: "Authorization") }
        req.httpBody = body
        return req
    }

    func allMachines() async throws -> [MachineDefinition] {
        guard let config else { throw RepositoryError.notConfigured }
        let body = #"{"size":1000,"query":{"match_all":{}}}"#.data(using: .utf8)
        let req = try request(path: "\(config.index)/_search", method: "POST", body: body)
        let (data, _) = try await session.data(for: req)
        return try Self.decodeHits(data)
    }

    func machine(forCode code: String) async throws -> MachineDefinition? {
        guard let config else { throw RepositoryError.notConfigured }
        let req = try request(path: "\(config.index)/_doc/\(code)")
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return nil }
        let doc = try JSONDecoder().decode(OSDocument.self, from: data)
        return doc._source
    }

    func search(_ query: String) async throws -> [MachineDefinition] {
        guard let config else { throw RepositoryError.notConfigured }
        let payload = ["query": ["multi_match": ["query": query, "fields": ["name^2", "category", "primaryMuscles"]]]]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try request(path: "\(config.index)/_search", method: "POST", body: body)
        let (data, _) = try await session.data(for: req)
        return try Self.decodeHits(data)
    }

    func upsert(_ machine: MachineDefinition) async throws {
        guard let config else { throw RepositoryError.notConfigured }
        let body = try JSONEncoder().encode(machine)
        let req = try request(path: "\(config.index)/_doc/\(machine.machineCode)", method: "PUT", body: body)
        _ = try await session.data(for: req)
    }

    // MARK: - Decoding helpers

    private struct OSDocument: Decodable { let _source: MachineDefinition }
    private struct OSHits: Decodable { let hits: Inner; struct Inner: Decodable { let hits: [OSDocument] } }

    private static func decodeHits(_ data: Data) throws -> [MachineDefinition] {
        guard let result = try? JSONDecoder().decode(OSHits.self, from: data) else {
            throw RepositoryError.decodingFailed
        }
        return result.hits.hits.map(\._source)
    }
}
