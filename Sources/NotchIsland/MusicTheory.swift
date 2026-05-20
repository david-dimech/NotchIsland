import Foundation

// MARK: – Root Note

enum RootNote: String, CaseIterable, Identifiable, Equatable {
    case C, Cs = "C#", D, Ds = "D#", E, F, Fs = "F#", G, Gs = "G#", A, As = "A#", B

    var id: String { rawValue }
    var displayName: String { rawValue }

    /// Index into the chromatic scale (C = 0 … B = 11).
    var semitone: Int { RootNote.allCases.firstIndex(of: self) ?? 0 }
}

// MARK: – Scale Type

enum ScaleType: String, CaseIterable, Identifiable, Equatable {
    case major       = "Major"
    case minor       = "Minor"
    case dorian      = "Dorian"
    case mixolydian  = "Mixolydian"
    case barryHarris = "BH Dim 6th"

    var id: String { rawValue }

    /// Semitone offsets from the root that define one octave of the scale.
    var intervals: [Int] {
        switch self {
        case .major:       return [0, 2, 4, 5, 7, 9, 11]
        case .minor:       return [0, 2, 3, 5, 7, 8, 10]
        case .dorian:      return [0, 2, 3, 5, 7, 9, 10]
        case .mixolydian:  return [0, 2, 4, 5, 7, 9, 10]
        // Barry Harris major-6th diminished: R 2 3 4 5 b6 6 7 (8 notes)
        case .barryHarris: return [0, 2, 4, 5, 7, 8, 9, 11]
        }
    }
}

// MARK: – Engine (stateless, pure functions)

enum MusicTheory {
    static let chromaticNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]

    /// Set of active pitch-class integers (0–11) for the given root + scale.
    static func activeSemitones(root: RootNote, scale: ScaleType) -> Set<Int> {
        Set(scale.intervals.map { ($0 + root.semitone) % 12 })
    }

    static func name(ofSemitone s: Int) -> String {
        chromaticNames[((s % 12) + 12) % 12]
    }
}
