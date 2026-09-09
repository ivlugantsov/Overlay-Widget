//
//  PetView.swift
//  OverlayWidget
//
//  Created by Iv Lugantsov on 09.09.2026.
//

import SwiftUI

struct PetView: View {
    @ObservedObject var viewModel: PetViewModel

    @State private var bobPhase: CGFloat = 0

    var body: some View {
        VStack(spacing: 6) {
            if let speechText = viewModel.speechText {
                SpeechBubble(text: speechText)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            ZStack {
                CreatureShape(mood: viewModel.mood)
                    .frame(width: PetViewModel.creatureSize, height: PetViewModel.creatureSize)
                    .scaleEffect(x: viewModel.facingRight ? 1 : -1, y: 1)
                    .offset(y: bobOffset)
                    .rotationEffect(.degrees(viewModel.isBeingWhipped ? -14 : 0))

                if viewModel.isBeingWhipped {
                    WhipStrike()
                        .transition(.opacity)
                }
            }
            .frame(height: PetViewModel.creatureSize + 6)

            HitPointsBar(hitPoints: viewModel.hitPoints, mood: viewModel.mood)
                .frame(width: 64, height: 5)
        }
        .frame(width: PetViewModel.panelSize.width, height: PetViewModel.panelSize.height, alignment: .bottom)
        .animation(.easeInOut(duration: 0.25), value: viewModel.speechText)
        .animation(.easeOut(duration: 0.15), value: viewModel.isBeingWhipped)
        .onAppear { startBobbing() }
    }

    private var bobOffset: CGFloat {
        guard viewModel.isWalking else {
            return 0
        }
        return bobPhase
    }

    private func startBobbing() {
        withAnimation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true)) {
            bobPhase = -5
        }
    }
}

// MARK: - Creature

private struct CreatureShape: View {
    let mood: PetMood

    var body: some View {
        ZStack {
            Circle()
                .fill(bodyColor)
                .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1.5))

            eyes
            mouth
        }
    }

    private var bodyColor: Color {
        switch mood {
        case .normal:
            return Color(red: 0.55, green: 0.78, blue: 0.98)
        case .tired:
            return Color(red: 0.65, green: 0.65, blue: 0.72)
        case .bloody:
            return Color(red: 0.62, green: 0.16, blue: 0.16)
        }
    }

    private var eyes: some View {
        HStack(spacing: 12) {
            eye
            eye
        }
        .offset(y: -6)
    }

    @ViewBuilder
    private var eye: some View {
        switch mood {
        case .normal:
            Circle().fill(Color.black).frame(width: 6, height: 6)
        case .tired:
            Capsule().fill(Color.black.opacity(0.7)).frame(width: 8, height: 2.5)
        case .bloody:
            Image(systemName: "xmark")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.black.opacity(0.8))
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .normal:
            Capsule()
                .fill(Color.black.opacity(0.75))
                .frame(width: 10, height: 3)
                .offset(y: 8)
        case .tired:
            Capsule()
                .fill(Color.black.opacity(0.5))
                .frame(width: 8, height: 2)
                .offset(y: 8)
        case .bloody:
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.black.opacity(0.85))
                .frame(width: 12, height: 2.5)
                .rotationEffect(.degrees(180))
                .offset(y: 9)
        }
    }
}

// MARK: - Speech bubble

private struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.black.opacity(0.85))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: 200)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            )
    }
}

// MARK: - HP bar

private struct HitPointsBar: View {
    let hitPoints: Double
    let mood: PetMood

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.15))
                Capsule()
                    .fill(barColor)
                    .frame(width: proxy.size.width * CGFloat(hitPoints / 100))
            }
        }
        .clipShape(Capsule())
    }

    private var barColor: Color {
        switch mood {
        case .normal:
            return .green
        case .tired:
            return .yellow
        case .bloody:
            return .red
        }
    }
}

// MARK: - Whip strike effect

private struct WhipStrike: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: -10, y: -30))
            path.addQuadCurve(
                to: CGPoint(x: PetViewModel.creatureSize + 10, y: PetViewModel.creatureSize * 0.4),
                control: CGPoint(x: PetViewModel.creatureSize * 0.3, y: -10)
            )
        }
        .trim(from: 0, to: progress)
        .stroke(Color.red.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                progress = 1
            }
        }
    }
}
