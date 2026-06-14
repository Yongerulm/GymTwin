import Foundation
#if canImport(CoreNFC)
import CoreNFC
#endif

/// Parses raw strings (QR payloads, NFC URI/text records, bare codes) into
/// normalised machine codes that can be looked up in the MachineRepository.
enum MachineRecognitionService {

    // MARK: - QR / Raw String Parsing

    /// Extracts a machine code from a raw string.
    ///
    /// Handles:
    /// - Full URLs with a `m` query parameter  (e.g. `https://lfconnect.com/q?t=s&m=sscp`)
    /// - Any URL whose last non-empty path component looks like a code
    /// - Bare machine codes (e.g. `sscp`)
    ///
    /// Returns `nil` for empty or unrecognisable input.
    static func parseMachineCode(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Attempt URL parsing first.
        if let url = URL(string: trimmed), url.scheme != nil {
            return machineCode(fromURL: url)
        }

        // Treat as a bare code – reject obvious garbage.
        return isPlausibleCode(trimmed) ? trimmed.lowercased() : nil
    }

    // MARK: - NFC NDEF Parsing

    /// Extracts a machine code from a raw NDEF record payload.
    ///
    /// - Parameters:
    ///   - payload: The raw payload bytes of an NDEF record.
    ///   - typeNameFormat: The TNF value from the NDEF record header.
    /// - Returns: A machine code string, or `nil` if the payload cannot be
    ///   interpreted as one.
    static func machineCode(fromNDEFPayload payload: Data,
                            typeNameFormat: UInt8) -> String? {
        // TNF 0x01 = Well-Known; type "U" = URI record, type "T" = Text record.
        // TNF 0x02 = MIME media type.
        // For all cases we attempt to decode the payload as UTF-8 text / URI.

        guard !payload.isEmpty else { return nil }

        // --- URI record (TNF 0x01, type "U") ---
        // First byte is a URI identifier code; 0x00 means no prefix.
        let uriPrefixes: [UInt8: String] = [
            0x01: "http://www.",
            0x02: "https://www.",
            0x03: "http://",
            0x04: "https://",
            0x05: "tel:",
            0x06: "mailto:",
        ]

        if let prefix = uriPrefixes[payload[0]] {
            let rest = payload.dropFirst()
            if let uriString = String(bytes: rest, encoding: .utf8) {
                return parseMachineCode(from: prefix + uriString)
            }
        }

        // --- Text record (TNF 0x01, type "T") ---
        // First byte encodes language code length; skip language bytes.
        let langLen = Int(payload[0] & 0x3F)
        let textStart = 1 + langLen
        if textStart < payload.count {
            let textData = payload[textStart...]
            if let text = String(bytes: textData, encoding: .utf8) {
                return parseMachineCode(from: text)
            }
        }

        // --- Fallback: treat entire payload as UTF-8 ---
        if let raw = String(bytes: payload, encoding: .utf8) {
            return parseMachineCode(from: raw)
        }

        return nil
    }

    // MARK: - Private Helpers

    private static func machineCode(fromURL url: URL) -> String? {
        // Prefer the `m` query parameter (LF Connect style).
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let mParam = components.queryItems?.first(where: { $0.name == "m" })?.value,
           isPlausibleCode(mParam) {
            return mParam.lowercased()
        }

        // Fall back to the last non-empty path component.
        let pathComponents = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        if let last = pathComponents.last, isPlausibleCode(last) {
            return last.lowercased()
        }

        return nil
    }

    /// A code is plausible when it is 2–20 alphanumeric/hyphen characters.
    private static func isPlausibleCode(_ candidate: String) -> Bool {
        let range = 2...20
        guard range.contains(candidate.count) else { return false }
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        return candidate.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
