import Foundation

public struct GmailMessage: Identifiable, Equatable {
    public let id: String
    public let threadId: String
    public let from: String        // raw "Name <email>"
    public let fromName: String    // display name extracted
    public let subject: String
    public let date: Date
    public let snippet: String
    public let isUnread: Bool

    public init(id: String, threadId: String, from: String, fromName: String,
                subject: String, date: Date, snippet: String, isUnread: Bool) {
        self.id       = id
        self.threadId = threadId
        self.from     = from
        self.fromName = fromName
        self.subject  = subject
        self.date     = date
        self.snippet  = snippet
        self.isUnread = isUnread
    }

    public static func == (lhs: GmailMessage, rhs: GmailMessage) -> Bool { lhs.id == rhs.id }

    // Extracted OTP/verification code, if any.
    // Only fires when OTP-related keywords are present to avoid false positives on
    // phone numbers, order numbers, and other incidental digit sequences.
    public var otpCode: String? {
        let lowered = (subject + " " + snippet).lowercased()

        // Must contain at least one OTP-context keyword
        let keywords = ["code", "otp", "verification", "verify", "pin", "2fa",
                        "passcode", "one-time", "one time", "temporary", "access code",
                        "security code", "confirmation code", "authenticate", "login code"]
        guard keywords.contains(where: { lowered.contains($0) }) else { return nil }

        let original = subject + " " + snippet
        // 5–8 digit standalone numbers; exclude those adjacent to phone-number punctuation
        // Second lookbehind catches area-code pattern: "(800) 123456" → skip "123456"
        let pattern = #"(?<![0-9\-\+\(\)\.])\b(?<!\) )(\d{5,8})\b(?![0-9\-\+\(\)\.])"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: original,
                                           range: NSRange(original.startIndex..., in: original)),
              let range = Range(match.range(at: 1), in: original) else { return nil }
        return String(original[range])
    }
}
