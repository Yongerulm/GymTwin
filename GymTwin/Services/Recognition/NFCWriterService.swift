import Foundation
#if canImport(CoreNFC)
// CoreNFC's tag/payload types aren't Sendable and its completion handlers are
// @Sendable; @preconcurrency keeps these (safe, NFC-queue-serialised) captures
// as the intended behaviour without Swift 6 concurrency noise.
@preconcurrency import CoreNFC

/// Writes a URL NDEF record (`gymtwin://machine/<code>`) to a machine's NFC tag,
/// so that later just tapping the tag launches the app via the small system
/// banner — no full scan sheet. Writing itself uses the system NFC UI once.
@MainActor
final class NFCWriterService: NSObject {

    static var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    // Serialised: set on the main actor before the session begins, then read on
    // the NFC delegate queue. Safe for this one-shot write flow.
    nonisolated(unsafe) private var session: NFCNDEFReaderSession?
    nonisolated(unsafe) private var continuation: CheckedContinuation<Bool, Never>?
    nonisolated(unsafe) private var payloadURL: URL?

    /// Writes `urlString` to the next tag held to the phone. Returns true on a
    /// successful write, false on cancel / read-only / error.
    func write(urlString: String) async -> Bool {
        guard NFCNDEFReaderSession.readingAvailable, let url = URL(string: urlString) else { return false }
        return await withCheckedContinuation { cont in
            continuation = cont
            payloadURL = url
            let newSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            newSession.alertMessage = "Hold your iPhone near the machine tag to write it."
            session = newSession
            newSession.begin()
        }
    }

    nonisolated private func finish(_ ok: Bool, message: String?) {
        if let message { session?.alertMessage = message }
        session?.invalidate()
        session = nil
        payloadURL = nil
        let c = continuation
        continuation = nil
        c?.resume(returning: ok)
    }
}

extension NFCWriterService: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if continuation != nil { finish(false, message: nil) }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {}

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first,
              let url = payloadURL,
              let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
            finish(false, message: "Could not prepare the tag.")
            return
        }
        // CoreNFC's tag/payload aren't Sendable but its completion handlers are
        // @Sendable; box them so the (NFC-queue-serialised) captures are safe.
        let box = NFCWriteBox(tag: tag, payload: payload)
        session.connect(to: tag) { [self] error in
            if error != nil { finish(false, message: "Connection failed — try again."); return }
            box.tag.queryNDEFStatus { [self] status, _, _ in
                guard status == .readWrite else {
                    finish(false, message: status == .readOnly ? "This tag is read-only." : "This tag can't be written.")
                    return
                }
                box.tag.writeNDEF(NFCNDEFMessage(records: [box.payload])) { [self] writeError in
                    finish(writeError == nil, message: writeError == nil ? "Saved to tag ✓" : "Write failed — try again.")
                }
            }
        }
    }
}

/// Carries non-Sendable CoreNFC values across the @Sendable completion handlers.
/// Safe because all access is serialised on the NFC reader queue.
private struct NFCWriteBox: @unchecked Sendable {
    let tag: any NFCNDEFTag
    let payload: NFCNDEFPayload
}
#else
/// Stub for platforms without CoreNFC (e.g. the Simulator builds where it links
/// but the hardware is absent).
@MainActor
final class NFCWriterService {
    static var isAvailable: Bool { false }
    func write(urlString: String) async -> Bool { false }
}
#endif
