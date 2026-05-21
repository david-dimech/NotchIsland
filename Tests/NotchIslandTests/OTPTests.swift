import XCTest
@testable import NotchIslandCore

final class OTPTests: XCTestCase {

    // Helper — builds a GmailMessage using only subject/snippet for OTP testing.
    private func msg(subject: String = "", snippet: String = "") -> GmailMessage {
        GmailMessage(id: "x", threadId: "t", from: "Sender <s@x.com>",
                     fromName: "Sender", subject: subject,
                     date: Date(), snippet: snippet, isUnread: true)
    }

    // MARK: – Happy path: codes that SHOULD be detected

    func testDetectsVerificationCodeInSubject() {
        XCTAssertEqual(msg(subject: "Your verification code is 12345").otpCode, "12345")
    }

    func testDetectsLoginCode() {
        XCTAssertEqual(msg(subject: "Your login code: 987654").otpCode, "987654")
    }

    func testDetects2FACode() {
        XCTAssertEqual(msg(snippet: "Use 2FA code 445566 to verify your identity").otpCode, "445566")
    }

    func testDetectsOTPKeyword() {
        XCTAssertEqual(msg(subject: "OTP: 123456").otpCode, "123456")
    }

    func testDetectsPINKeyword() {
        XCTAssertEqual(msg(snippet: "Your PIN is 99887").otpCode, "99887")
    }

    func testDetectsPasscodeKeyword() {
        XCTAssertEqual(msg(snippet: "Enter passcode 77665").otpCode, "77665")
    }

    func testDetectsSecurityCode() {
        XCTAssertEqual(msg(subject: "Security code: 556677").otpCode, "556677")
    }

    func testDetectsConfirmationCode() {
        XCTAssertEqual(msg(snippet: "Your confirmation code is 112233").otpCode, "112233")
    }

    func testDetectsAccessCode() {
        XCTAssertEqual(msg(subject: "access code 654321").otpCode, "654321")
    }

    func testDetectsOneTimeCode() {
        XCTAssertEqual(msg(snippet: "one-time code 246810").otpCode, "246810")
    }

    func testDetectsTemporaryCode() {
        XCTAssertEqual(msg(snippet: "Use temporary password 135790").otpCode, "135790")
    }

    func testDetectsAuthenticateKeyword() {
        XCTAssertEqual(msg(subject: "authenticate with 543210").otpCode, "543210")
    }

    func testDetects8DigitCode() {
        XCTAssertEqual(msg(subject: "Your code is 12345678").otpCode, "12345678")
    }

    func testDetects5DigitCode() {
        XCTAssertEqual(msg(subject: "Verify: 54321").otpCode, "54321")
    }

    func testCodeInSnippetAloneIsDetected() {
        XCTAssertEqual(msg(snippet: "Your verification code is 77722").otpCode, "77722")
    }

    // MARK: – False-positive prevention: codes that MUST NOT be detected

    func testIgnoresWithoutKeyword() {
        // Random 6-digit number with no OTP keyword context
        XCTAssertNil(msg(subject: "Order confirmed", snippet: "Reference 654321").otpCode)
    }

    func testIgnoresPhoneNumberUS() {
        // US phone number format adjacent to digits
        XCTAssertNil(msg(subject: "Call us at +1-555-123456").otpCode)
    }

    func testIgnoresPhoneNumberParentheses() {
        XCTAssertNil(msg(subject: "code: (800) 123456").otpCode)
    }

    func testIgnores4DigitCode() {
        // 4 digits is too short — PIN-pad code, not an OTP
        XCTAssertNil(msg(subject: "Your PIN is 1234").otpCode)
    }

    func testIgnores9DigitNumber() {
        // 9 digits is too long — likely a reference or account number
        XCTAssertNil(msg(subject: "verification code 123456789").otpCode)
    }

    func testIgnoresAdjacentDigits() {
        // 6-digit run inside a longer number string
        XCTAssertNil(msg(subject: "code", snippet: "Number: 1234567890").otpCode)
    }

    func testIgnoresDecimalNumber() {
        // Decimal-adjacent digits should be excluded
        XCTAssertNil(msg(subject: "code price 1.23456").otpCode)
    }

    func testIgnoresDashedNumber() {
        // Dashes adjacent to digits are phone-number indicators
        XCTAssertNil(msg(subject: "code ref: 123-456").otpCode)
    }

    func testCaseSensitivityKeywordDetection() {
        // Keywords are lowercased before matching — uppercase OTP email should still work
        XCTAssertEqual(msg(subject: "YOUR VERIFICATION CODE IS 55443").otpCode, "55443")
    }

    // MARK: – Returns first match only

    func testReturnsFirstCodeWhenMultiplePresent() {
        let result = msg(subject: "Code 11111", snippet: "Also code 22222").otpCode
        XCTAssertEqual(result, "11111")
    }
}
