import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var viewModel: IslandViewModel
    private var info: NowPlayingInfo { viewModel.nowPlaying }

    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            Group {
                if let image = info.artwork {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        Image(systemName: "music.note")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Track info + progress bar
            VStack(alignment: .leading, spacing: 4) {
                Text(info.title.isEmpty ? "Nothing Playing" : info.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if !info.artist.isEmpty {
                    Text(info.artist)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                if info.duration > 0 {
                    ProgressView(value: min(info.elapsed / info.duration, 1.0))
                        .progressViewStyle(LinearProgressViewStyle(tint: .white.opacity(0.6)))
                        .frame(height: 2)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Playback controls
            HStack(spacing: 10) {
                controlButton(icon: "gobackward.10", size: 12) { viewModel.skipBackward() }
                controlButton(icon: "backward.fill",  size: 13) { viewModel.previousTrack() }
                controlButton(icon: info.isPlaying ? "pause.fill" : "play.fill", size: 20) { viewModel.togglePlayPause() }
                controlButton(icon: "forward.fill",   size: 13) { viewModel.nextTrack() }
                controlButton(icon: "goforward.10",   size: 12) { viewModel.skipForward() }
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill + centre in page slot
    }

    private func controlButton(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white)
                .frame(width: size + 12, height: size + 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
