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
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Track info + progress
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
                        .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        .frame(height: 2)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Playback controls
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    controlButton(icon: "backward.fill", size: 14) {
                        viewModel.previousTrack()
                    }
                    controlButton(icon: info.isPlaying ? "pause.fill" : "play.fill", size: 20) {
                        viewModel.togglePlayPause()
                    }
                    controlButton(icon: "forward.fill", size: 14) {
                        viewModel.nextTrack()
                    }
                }
            }
        }
    }

    private func controlButton(icon: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.white)
                .frame(width: size + 10, height: size + 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
