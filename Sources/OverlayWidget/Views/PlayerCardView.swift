//
//  PlayerCardView.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import SwiftUI

struct PlayerCardView: View {
    private enum Constants {
        static let artworkSize: CGFloat = 52
        static let artworkCornerRadius: CGFloat = 8
        static let transportIconSize: CGFloat = 22
        static let sideIconSize: CGFloat = 15
        static let progressHeight: CGFloat = 4
    }

    @ObservedObject private var viewInput: PlayerViewInput
    @EnvironmentObject private var languageStore: LanguageStore
    private let viewModel: PlayerViewModel
    @State private var isExpanded = false

    init(viewModel: PlayerViewModel) {
        self.viewModel = viewModel
        viewInput = viewModel.viewInput
    }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedArtwork
            }

            VStack(spacing: WidgetStyle.stackSpacing) {
                header
                progressTrack
                if let appsToLaunch = viewInput.appsToLaunch {
                    appPicker(appsToLaunch)
                } else {
                    transportRow
                }
            }
            .padding(WidgetStyle.cardPadding)
        }
        .frame(width: WidgetStyle.cardWidth)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: WidgetStyle.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: WidgetStyle.cornerRadius)
                .strokeBorder(Color.white.opacity(0.08))
        )
    }
}

// MARK: - Subviews

private extension PlayerCardView {
    /// Как на заблокированном экране iPhone: тап по обложке — большая обложка сверху той
    /// же карточки (общий фон/скругление/бордер, без разрыва), тап ещё раз — обратно.
    var expandedArtwork: some View {
        Group {
            if let artwork = viewInput.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Color.white.opacity(0.1))
            }
        }
        .frame(width: WidgetStyle.cardWidth, height: WidgetStyle.cardWidth)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { isExpanded = false }
    }

    var header: some View {
        HStack(spacing: 10) {
            if !isExpanded {
                artworkView
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewInput.title.isEmpty ? languageStore.current.strings.nothingPlaying : viewInput.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(viewInput.artist)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.didTapTrackInfo() }

            Spacer(minLength: 0)

            if viewInput.isLikeAvailable {
                likeButton
            }
        }
    }

    var artworkView: some View {
        Group {
            if let artwork = viewInput.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: Constants.artworkCornerRadius)
                    .fill(Color.white.opacity(0.1))
            }
        }
        .frame(width: Constants.artworkSize, height: Constants.artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: Constants.artworkCornerRadius))
        .contentShape(Rectangle())
        .onTapGesture { isExpanded = true }
    }

    var likeButton: some View {
        Button(action: viewModel.didTapLike) {
            Image(systemName: viewInput.isLiked ? "heart.fill" : "heart")
                .foregroundStyle(viewInput.isLiked ? .gray : .secondary)
        }
        .buttonStyle(.plain)
        .font(.system(size: Constants.sideIconSize))
    }

    var progressTrack: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule().fill(Color.white.opacity(0.9))
                    .frame(width: proxy.size.width * progressFraction)
            }
        }
        .frame(height: Constants.progressHeight)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    seek(atDragLocationX: value.location.x, trackWidth: WidgetStyle.cardWidth - WidgetStyle.cardPadding * 2)
                }
        )
    }

    func appPicker(_ apps: [MusicApp]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(languageStore.current.strings.noActivePlayerOpen)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            ForEach(apps) { app in
                Button(app.displayName) { viewModel.didSelectAppToLaunch(app) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var transportRow: some View {
        HStack(spacing: 28) {
            Button(action: viewModel.didTapPrevious) {
                Image(systemName: "backward.fill")
            }
            Button(action: viewModel.didTapPlayPause) {
                Image(systemName: viewInput.isPlaying ? "pause.fill" : "play.fill")
                    // play.fill/pause.fill — разные по форме глифы, чуть отличающиеся по
                    // фактической высоте. Без фиксированного фрейма это на пиксель меняло
                    // высоту всей карточки при каждом переключении и дёргало auto-resize окна.
                    .frame(width: Constants.transportIconSize, height: Constants.transportIconSize)
            }
            Button(action: viewModel.didTapNext) {
                Image(systemName: "forward.fill")
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: Constants.transportIconSize))
    }

    var progressFraction: Double {
        guard viewInput.durationSeconds > 0 else {
            return 0
        }
        return min(max(viewInput.elapsedSeconds / viewInput.durationSeconds, 0), 1)
    }

    func seek(atDragLocationX x: CGFloat, trackWidth: CGFloat) {
        guard viewInput.durationSeconds > 0, trackWidth > 0 else {
            return
        }
        let fraction = min(max(x / trackWidth, 0), 1)
        viewModel.didSeek(toSeconds: fraction * viewInput.durationSeconds)
    }
}
