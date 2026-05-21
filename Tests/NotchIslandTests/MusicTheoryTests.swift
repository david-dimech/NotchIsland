import XCTest
@testable import NotchIslandCore

final class MusicTheoryTests: XCTestCase {

    // MARK: – Scale note counts

    func testMajorScaleHasSevenNotes() {
        XCTAssertEqual(ScaleType.major.intervals.count, 7)
    }

    func testMinorScaleHasSevenNotes() {
        XCTAssertEqual(ScaleType.minor.intervals.count, 7)
    }

    func testDorianScaleHasSevenNotes() {
        XCTAssertEqual(ScaleType.dorian.intervals.count, 7)
    }

    func testMixolydianScaleHasSevenNotes() {
        XCTAssertEqual(ScaleType.mixolydian.intervals.count, 7)
    }

    func testBarryHarrisScaleHasEightNotes() {
        XCTAssertEqual(ScaleType.barryHarris.intervals.count, 8)
    }

    // MARK: – Scale intervals (correctness)

    func testCMajorIntervals() {
        // W W H W W W H (whole/half steps from C)
        XCTAssertEqual(ScaleType.major.intervals, [0, 2, 4, 5, 7, 9, 11])
    }

    func testNaturalMinorIntervals() {
        // W H W W H W W
        XCTAssertEqual(ScaleType.minor.intervals, [0, 2, 3, 5, 7, 8, 10])
    }

    func testDorianIntervals() {
        // W H W W W H W
        XCTAssertEqual(ScaleType.dorian.intervals, [0, 2, 3, 5, 7, 9, 10])
    }

    func testMixolydianIntervals() {
        // W W H W W H W (dominant 7th scale)
        XCTAssertEqual(ScaleType.mixolydian.intervals, [0, 2, 4, 5, 7, 9, 10])
    }

    // MARK: – RootNote semitone indices

    func testRootNoteSemitones() {
        XCTAssertEqual(RootNote.C.semitone,  0)
        XCTAssertEqual(RootNote.Cs.semitone, 1)
        XCTAssertEqual(RootNote.D.semitone,  2)
        XCTAssertEqual(RootNote.Ds.semitone, 3)
        XCTAssertEqual(RootNote.E.semitone,  4)
        XCTAssertEqual(RootNote.F.semitone,  5)
        XCTAssertEqual(RootNote.Fs.semitone, 6)
        XCTAssertEqual(RootNote.G.semitone,  7)
        XCTAssertEqual(RootNote.Gs.semitone, 8)
        XCTAssertEqual(RootNote.A.semitone,  9)
        XCTAssertEqual(RootNote.As.semitone, 10)
        XCTAssertEqual(RootNote.B.semitone,  11)
    }

    func testAllTwelveRootNotes() {
        XCTAssertEqual(RootNote.allCases.count, 12)
    }

    // MARK: – activeSemitones

    func testCMajorActiveSemitones() {
        // C D E F G A B
        let expected: Set<Int> = [0, 2, 4, 5, 7, 9, 11]
        XCTAssertEqual(MusicTheory.activeSemitones(root: .C, scale: .major), expected)
    }

    func testAMinorActiveSemitones() {
        // A B C D E F G (relative minor of C major, same notes)
        let expected: Set<Int> = [9, 11, 0, 2, 4, 5, 7]
        XCTAssertEqual(MusicTheory.activeSemitones(root: .A, scale: .minor), expected)
    }

    func testGMajorActiveSemitones() {
        // G A B C D E F# — one sharp
        let expected: Set<Int> = [7, 9, 11, 0, 2, 4, 6]
        XCTAssertEqual(MusicTheory.activeSemitones(root: .G, scale: .major), expected)
    }

    func testDMajorActiveSemitones() {
        // D E F# G A B C# — two sharps
        let expected: Set<Int> = [2, 4, 6, 7, 9, 11, 1]
        XCTAssertEqual(MusicTheory.activeSemitones(root: .D, scale: .major), expected)
    }

    func testActiveSemitonesWrapsAt12() {
        // All values must be in 0..<12
        for root in RootNote.allCases {
            for scale in ScaleType.allCases {
                let semitones = MusicTheory.activeSemitones(root: root, scale: scale)
                for s in semitones {
                    XCTAssertGreaterThanOrEqual(s, 0, "\(root)/\(scale) has semitone < 0")
                    XCTAssertLessThan(s, 12, "\(root)/\(scale) has semitone >= 12")
                }
            }
        }
    }

    func testActiveSemitonesContainsRoot() {
        // Root note must always be in its own scale
        for root in RootNote.allCases {
            for scale in ScaleType.allCases {
                let semitones = MusicTheory.activeSemitones(root: root, scale: scale)
                XCTAssertTrue(semitones.contains(root.semitone),
                              "\(root) not in \(scale) scale — root should always be active")
            }
        }
    }

    // MARK: – Chromatic name lookup

    func testChromaticNameCount() {
        XCTAssertEqual(MusicTheory.chromaticNames.count, 12)
    }

    func testNameOfSemitoneBasic() {
        XCTAssertEqual(MusicTheory.name(ofSemitone: 0),  "C")
        XCTAssertEqual(MusicTheory.name(ofSemitone: 1),  "C#")
        XCTAssertEqual(MusicTheory.name(ofSemitone: 4),  "E")
        XCTAssertEqual(MusicTheory.name(ofSemitone: 7),  "G")
        XCTAssertEqual(MusicTheory.name(ofSemitone: 11), "B")
    }

    func testNameOfSemitoneWrapsOctave() {
        // 12 should wrap to C, 13 to C#, etc.
        XCTAssertEqual(MusicTheory.name(ofSemitone: 12), "C")
        XCTAssertEqual(MusicTheory.name(ofSemitone: 13), "C#")
        XCTAssertEqual(MusicTheory.name(ofSemitone: 24), "C")
    }

    func testNameOfSemitoneNegative() {
        // -1 should wrap to B, -12 to C
        XCTAssertEqual(MusicTheory.name(ofSemitone: -1),  "B")
        XCTAssertEqual(MusicTheory.name(ofSemitone: -12), "C")
    }
}
