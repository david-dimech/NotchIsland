import XCTest
@testable import NotchIslandCore

@MainActor
final class AlertManagerTests: XCTestCase {

    private var manager: AlertManager!

    override func setUp() async throws {
        manager = AlertManager()
    }

    override func tearDown() async throws {
        manager.clearAll()
        manager = nil
    }

    // MARK: – AlertInfo model

    func testAlertTextTruncatedTo25Chars() {
        let long = "This is a very long alert message that exceeds 25 characters"
        let info = AlertInfo(icon: "bell", text: long, source: "Test")
        XCTAssertEqual(info.text.count, 25)
        XCTAssertEqual(info.text, String(long.prefix(25)))
    }

    func testAlertTextExactly25CharsNotTruncated() {
        let exactly25 = "1234567890123456789012345"
        XCTAssertEqual(exactly25.count, 25)
        let info = AlertInfo(icon: "bell", text: exactly25, source: "Test")
        XCTAssertEqual(info.text, exactly25)
    }

    func testAlertShortTextUnchanged() {
        let info = AlertInfo(icon: "bell", text: "Hello", source: "Test")
        XCTAssertEqual(info.text, "Hello")
    }

    func testAlertEqualityByID() {
        let info = AlertInfo(icon: "bell", text: "Test", source: "App")
        // Same instance equals itself
        XCTAssertEqual(info, info)
    }

    func testAlertInequalityDifferentInstances() {
        // Two independently created alerts have different UUIDs
        let a = AlertInfo(icon: "bell", text: "Test", source: "App")
        let b = AlertInfo(icon: "bell", text: "Test", source: "App")
        XCTAssertNotEqual(a, b)
    }

    func testAlertPreservesIcon() {
        let info = AlertInfo(icon: "envelope.fill", text: "Mail", source: "Gmail")
        XCTAssertEqual(info.icon, "envelope.fill")
    }

    func testAlertPreservesSource() {
        let info = AlertInfo(icon: "bell", text: "Alert", source: "Todoist")
        XCTAssertEqual(info.source, "Todoist")
    }

    func testAlertActionURLStored() {
        let url = URL(string: "https://meet.google.com/abc")!
        let info = AlertInfo(icon: "calendar", text: "Meeting", source: "Calendar", actionURL: url)
        XCTAssertEqual(info.actionURL, url)
    }

    func testAlertActionLabelStored() {
        let info = AlertInfo(icon: "bell", text: "Test", source: "App", actionLabel: "Join")
        XCTAssertEqual(info.actionLabel, "Join")
    }

    // MARK: – AlertManager queue

    func testStartsEmpty() {
        XCTAssertNil(manager.current)
    }

    func testPostShowsCurrentAlert() {
        manager.post(icon: "bell", text: "Hello", source: "Test")
        XCTAssertNotNil(manager.current)
        XCTAssertEqual(manager.current?.text, "Hello")
    }

    func testPostMultipleShowsFirstImmediately() {
        manager.post(icon: "bell", text: "First",  source: "Test")
        manager.post(icon: "bell", text: "Second", source: "Test")
        // Current should still be the first alert (second is queued)
        XCTAssertEqual(manager.current?.text, "First")
    }

    func testDismissShowsNextAlert() {
        manager.post(icon: "bell", text: "First",  source: "Test")
        manager.post(icon: "bell", text: "Second", source: "Test")
        manager.dismiss()
        XCTAssertEqual(manager.current?.text, "Second")
    }

    func testDismissLastAlertClearsQueue() {
        manager.post(icon: "bell", text: "Only", source: "Test")
        manager.dismiss()
        XCTAssertNil(manager.current)
    }

    func testClearAllEmptiesQueue() {
        manager.post(icon: "bell", text: "A", source: "Test")
        manager.post(icon: "bell", text: "B", source: "Test")
        manager.post(icon: "bell", text: "C", source: "Test")
        manager.clearAll()
        XCTAssertNil(manager.current)
    }

    func testClearAllThenPostWorks() {
        manager.post(icon: "bell", text: "Old", source: "Test")
        manager.clearAll()
        manager.post(icon: "bell", text: "New", source: "Test")
        XCTAssertEqual(manager.current?.text, "New")
    }

    func testQueueOrderPreserved() {
        let texts = ["Alpha", "Beta", "Gamma"]
        for t in texts { manager.post(icon: "bell", text: t, source: "Test") }
        XCTAssertEqual(manager.current?.text, "Alpha")
        manager.dismiss()
        XCTAssertEqual(manager.current?.text, "Beta")
        manager.dismiss()
        XCTAssertEqual(manager.current?.text, "Gamma")
        manager.dismiss()
        XCTAssertNil(manager.current)
    }

    func testDismissOnEmptyManagerIsNoop() {
        XCTAssertNil(manager.current)
        manager.dismiss()
        XCTAssertNil(manager.current)
    }

    func testTextTruncationAppliedInQueue() {
        let long = String(repeating: "x", count: 50)
        manager.post(icon: "bell", text: long, source: "Test")
        XCTAssertEqual(manager.current?.text.count, 25)
    }
}
