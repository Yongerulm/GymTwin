import Foundation

#if canImport(CoreNFC)
import CoreNFC

/// Reads a single NDEF tag and extracts a machine code from the first record.
///
/// - All CoreNFC delegate callbacks arrive on an internal NFC queue.  The class
///   bridges them to `@MainActor` via `MainActor.run` before touching any
///   stored state, satisfying Swift 6 concurrency requirements.
/// - The `scan()` function suspends until a tag is read, an error occurs, or
///   the user cancels.
@MainActor
final class NFCService: NSObject {

    // MARK: - Public API

    /// `true` when the device hardware supports NFC NDEF reading.
    static var isAvailable: Bool {
        NFCNDEFReaderSession.readingAvailable
    }

    /// Starts an NFC scan and returns the first recognised machine code.
    ///
    /// Returns `nil` when NFC is unavailable, the user cancels, or no machine
    /// code can be parsed from the tag.
    func scan() async -> String? {
        guard NFCNDEFReaderSession.readingAvailable else { return nil }

        return await withCheckedContinuation { continuation in
            // Store the continuation before starting the session so that the
            // delegate can always resume it — even if invalidation fires first.
            self.continuation = continuation

            let session = NFCNDEFReaderSession(
                delegate: self,
                queue: nil,          // NFC framework chooses its internal queue
                invalidateAfterFirstRead: true
            )
            session.alertMessage = "Hold your iPhone near the machine tag."
            self.session = session
            session.begin()
        }
    }

    // MARK: - Private State

    private var session: NFCNDEFReaderSession?
    private var continuation: CheckedContinuation<String?, Never>?

    /// Resumes the continuation exactly once with `value`, then clears both
    /// stored references.  Safe to call from any thread.
    private func resume(with value: String?) {
        let c = continuation
        continuation = nil
        session = nil
        c?.resume(returning: value)
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCService: NFCNDEFReaderSessionDelegate {

    nonisolated func readerSession(_ session: NFCNDEFReaderSession,
                                   didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Parse the first record of the first message.
        let record = messages.first?.records.first
        var code: String?

        if let record {
            code = MachineRecognitionService.machineCode(
                fromNDEFPayload: record.payload,
                typeNameFormat: record.typeNameFormat.rawValue
            )
        }

        // Bridge to @MainActor. The session auto-invalidates after the first
        // read (`invalidateAfterFirstRead: true`), so we must not capture the
        // non-Sendable `session` into this actor-hopping closure.
        Task { @MainActor [weak self] in
            self?.resume(with: code)
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession,
                                   didInvalidateWithError error: Error) {
        // User cancelled (NFCReaderError.readerSessionInvalidationErrorUserCanceled)
        // or a hardware/timeout error — either way, resume with nil.
        Task { @MainActor [weak self] in
            self?.resume(with: nil)
        }
    }
}

#else

// MARK: - Stub for targets that don't link CoreNFC (e.g. simulator without entitlement)

/// No-op stub used when CoreNFC is not available.
@MainActor
final class NFCService: NSObject {
    static var isAvailable: Bool { false }

    func scan() async -> String? { nil }
}

#endif
