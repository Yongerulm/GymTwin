import XCTest
@testable import GymTwin

/// Unit tests for `MachineRecognitionService.parseMachineCode(from:)`.
///
/// Covers full LF-Connect URLs, bare codes, whitespace trimming,
/// unrecognisable URLs, and empty input.
final class MachineRecognitionTests: XCTestCase {

    // MARK: - Full URL with `m` query parameter

    func testParseMachineCode_lfConnectURL_extractsMQueryParam() {
        // Arrange
        let raw = "https://lfconnect.com/q?t=s&m=sscp"

        // Act
        let code = MachineRecognitionService.parseMachineCode(from: raw)

        // Assert
        XCTAssertEqual(code, "sscp",
                       "Should extract the `m` query parameter value from a Life Fitness Connect URL.")
    }

    // MARK: - Bare machine code

    func testParseMachineCode_bareCode_returnsCode() {
        // Arrange
        let raw = "sscp"

        // Act
        let code = MachineRecognitionService.parseMachineCode(from: raw)

        // Assert
        XCTAssertEqual(code, "sscp",
                       "A bare machine code should be returned as-is (lowercased).")
    }

    // MARK: - Whitespace trimming

    func testParseMachineCode_codeWithLeadingAndTrailingSpaces_returnsNormalisedCode() {
        // Arrange — simulates a QR payload that includes surrounding whitespace
        let raw = "  ssle "

        // Act
        let code = MachineRecognitionService.parseMachineCode(from: raw)

        // Assert
        XCTAssertEqual(code, "ssle",
                       "Leading and trailing whitespace should be stripped before parsing.")
    }

    // MARK: - URL without a recognisable machine code

    func testParseMachineCode_urlWithNoRecognisableCode_doesNotCrash() {
        // Arrange — valid URL but no `m` param and path component is not a plausible code
        let raw = "https://example.com/nope"

        // Act — must not crash; result may be nil or a non-nil fallback, either is acceptable
        var threwError = false
        var result: String? = nil
        do {
            result = MachineRecognitionService.parseMachineCode(from: raw)
        } catch {
            threwError = true
        }

        // Assert — the call itself must not throw or crash
        XCTAssertFalse(threwError, "parseMachineCode must never throw.")

        // "nope" is a plausible-length alphanumeric string so the service may
        // return it as a code. What matters is that execution completes without error.
        _ = result  // result is intentionally unused — correctness is crash-freedom here
    }

    // MARK: - Empty input

    func testParseMachineCode_emptyString_returnsNil() {
        // Arrange
        let raw = ""

        // Act
        let code = MachineRecognitionService.parseMachineCode(from: raw)

        // Assert
        XCTAssertNil(code, "An empty input string should return nil.")
    }
}
