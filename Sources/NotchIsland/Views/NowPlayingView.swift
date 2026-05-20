import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var viewModel: IslandViewModel
    private var info: NowPlayingInfo { viewModel.nowPlaying }

    var body: some View {
        HStack(spacing: 12) {
            artwork
            VStack(alignment: .leading, spacing: 5) {
                trackMeta
                ScrubBar(
                    elapsed:  info.elapsed,
                    duration: info.duration,
                    onScrub:  { viewModel.nowPlayingManager.seekTo($0) }
                )
                timeRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            controls
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: – Sub-views

    private var artwork: some View {
        Button { viewModel.nowPlayingManager.openSourceApp() } label: {
            Group {
                if let img = info.artwork {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.easeInOut(duration: 0.3), value: info.artwork != nil)
            .overlay(alignment: .bottomTrailing) {
                // Small app-launch hint
                if info.sourceBundleID != nil || info.isPlaying {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var trackMeta: some View {
        Button { viewModel.nowPlayingManager.openSourceApp() } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(info.title.isEmpty ? "Nothing Playing" : info.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !info.artist.isEmpty {
                    Text(info.artist)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var timeRow: some View {
        HStack {
            Text(format(info.elapsed))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            Spacer()
            if info.duration > 0 {
                Text("-\(format(max(0, info.duration - info.elapsed)))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            controlBtn("backward.fill",  size: 13) { viewModel.previousTrack() }
            controlBtn(info.isPlaying ? "pause.fill" : "play.fill", size: 18) { viewModel.togglePlayPause() }
            controlBtn("forward.fill",   size: 13) { viewModel.nextTrack() }
        }
    }

    private func controlBtn(_ icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: size + 10, height: size + 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(max(0, t))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: – Scrub bar

private struct ScrubBar: View {
    let elapsed:  TimeInterval
    let duration: TimeInterval
    let onScrub:  (TimeInterval) -> Void   // called with absolute position in seconds

    @State private var isDragging    = false
    @State private var dragFraction: CGFloat = 0

    private var progress: CGFloat {
        duration > 0 ? CGFloat(min(elapsed / duration, 1.0)) : 0
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fill = isDragging ? dragFraction : progress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: isDragging ? 4 : 2)

                Capsule()
                    .fill(Color.white.opacity(isDragging ? 1.0 : 0.55))
                    .frame(width: max(0, fill * w), height: isDragging ? 4 : 2)

                if isDragging {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .offset(x: max(0, fill * w - 5))
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        isDragging   = true
                        dragFraction = max(0, min(1, v.location.x / w))
                    }
                    .onEnded { v in
                        let frac = max(0, min(1, v.location.x / w))
                        onScrub(frac * duration)
                        isDragging = false
                    }
            )
        }
        .frame(height: 14)   // generous hit area
        .animation(.easeInOut(duration: 0.12), value: isDragging)
    }
}
