import SwiftUI

// MARK: – MusicView

struct MusicView: View {
    @StateObject private var bpmMgr = BPMManager()
    @State private var root:      RootNote  = .C
    @State private var scale:     ScaleType = .major
    @State private var tapFlash:  Bool      = false

    private var active: Set<Int> { MusicTheory.activeSemitones(root: root, scale: scale) }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top row: BPM tapper (left) + scale pickers (right) ────────
            HStack(alignment: .center, spacing: 0) {
                bpmTapper
                    .frame(width: 108)
                    .padding(.leading, 16)

                // Divider
                Color.white.opacity(0.1)
                    .frame(width: 1, height: 40)
                    .padding(.horizontal, 10)

                scalePickers
                    .padding(.trailing, 16)
            }
            .frame(height: 52)
            .padding(.top, 6)

            // ── Piano keyboard ─────────────────────────────────────────────
            PianoKeyboardView(active: active, root: root.semitone)
                .frame(height: 50)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – BPM Tapper

    private var bpmTapper: some View {
        Button {
            bpmMgr.tap()
            withAnimation(.spring(duration: 0.07, bounce: 0)) { tapFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(duration: 0.25)) { tapFlash = false }
            }
        } label: {
            VStack(spacing: 1) {
                Text(bpmMgr.bpm.map { "\($0)" } ?? "—")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(bpmMgr.bpm != nil ? .white : .white.opacity(0.18))
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.spring(duration: 0.25), value: bpmMgr.bpm)
                    .monospacedDigit()

                Text(bpmMgr.bpm != nil ? "BPM" : "TAP")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.35))
                    .kerning(0.8)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tapFlash ? Color.white.opacity(0.14) : Color.white.opacity(0.055))
            )
            .scaleEffect(tapFlash ? 0.93 : 1.0)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Reset BPM", role: .destructive) { bpmMgr.reset() }
        }
    }

    // MARK: – Scale Pickers

    private var scalePickers: some View {
        VStack(alignment: .leading, spacing: 5) {
            pickerRow(
                icon: "music.note",
                label: root.displayName
            ) {
                ForEach(RootNote.allCases) { n in
                    Button(n.displayName) {
                        withAnimation(.spring(duration: 0.22, bounce: 0.15)) { root = n }
                    }
                }
            }

            pickerRow(
                icon: "slider.horizontal.3",
                label: scale.rawValue
            ) {
                ForEach(ScaleType.allCases) { s in
                    Button(s.rawValue) {
                        withAnimation(.spring(duration: 0.22, bounce: 0.15)) { scale = s }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func pickerRow<Content: View>(
        icon: String,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
                .frame(width: 12)

            Menu(content: content) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.09))
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}

// MARK: – Piano Keyboard

struct PianoKeyboardView: View {
    let active: Set<Int>
    let root:   Int

    // White keys: (pitch-class, white-key index 0–6, label)
    private static let whiteSems:  [Int]    = [0, 2, 4, 5, 7, 9, 11]
    private static let whiteNames: [String] = ["C","D","E","F","G","A","B"]

    // Black keys: (pitch-class, center expressed as a multiple of white-key width)
    // Centers fall exactly between adjacent white keys.
    private static let blackSems:    [Int]    = [1,   3,   6,   8,   10  ]
    private static let blackCenters: [Double] = [1.0, 2.0, 4.0, 5.0, 6.0]

    var body: some View {
        GeometryReader { geo in
            let ww = geo.size.width / 7   // white key width
            let wh = geo.size.height
            let bw = ww * 0.60            // black key width
            let bh = wh * 0.61            // black key height

            ZStack(alignment: .topLeading) {
                // — White keys —
                ForEach(0..<7, id: \.self) { i in
                    let sem  = Self.whiteSems[i]
                    let name = Self.whiteNames[i]
                    let ia   = active.contains(sem)
                    let ir   = sem == root

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(whiteFill(ia, ir))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.13), lineWidth: 0.5)
                            )
                        if ia || ir {
                            Text(name)
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(ir ? Color(red: 0.45, green: 0.22, blue: 0) : .black.opacity(0.55))
                                .padding(.bottom, 3)
                        }
                    }
                    .frame(width: ww - 1.5, height: wh)
                    .offset(x: CGFloat(i) * ww + 0.75)
                    .animation(.spring(duration: 0.22, bounce: 0.15), value: ia)
                    .animation(.spring(duration: 0.22, bounce: 0.15), value: ir)
                }

                // — Black keys (rendered on top) —
                ForEach(0..<5, id: \.self) { i in
                    let sem    = Self.blackSems[i]
                    let center = Self.blackCenters[i]
                    let ia     = active.contains(sem)
                    let ir     = sem == root

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(blackFill(ia, ir))
                        if ia || ir {
                            Text(MusicTheory.name(ofSemitone: sem))
                                .font(.system(size: 5.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.bottom, 2)
                        }
                    }
                    .frame(width: bw, height: bh)
                    .offset(x: center * ww - bw / 2)
                    .animation(.spring(duration: 0.22, bounce: 0.15), value: ia)
                    .animation(.spring(duration: 0.22, bounce: 0.15), value: ir)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    // MARK: – Key colours

    private func whiteFill(_ isActive: Bool, _ isRoot: Bool) -> Color {
        isRoot   ? Color(red: 1.0, green: 0.52, blue: 0.08) :
        isActive ? Color(red: 0.38, green: 0.68, blue: 1.00) :
                   Color(red: 0.87, green: 0.87, blue: 0.89)
    }

    private func blackFill(_ isActive: Bool, _ isRoot: Bool) -> Color {
        isRoot   ? Color(red: 1.0, green: 0.45, blue: 0.05) :
        isActive ? Color(red: 0.20, green: 0.50, blue: 0.95) :
                   Color(red: 0.10, green: 0.10, blue: 0.11)
    }
}
