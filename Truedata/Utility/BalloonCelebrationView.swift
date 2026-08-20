//
//  BalloonCelebrationView.swift
//  Truedata
//

import SwiftUI

enum BalloonCelebrationStyle {
    case card
    case fullScreen

    var balloonCount: Int {
        switch self {
        case .card: return 20
        case .fullScreen: return 40
        }
    }

    var speedRange: ClosedRange<CGFloat> {
        switch self {
        case .card: return 100...300
        case .fullScreen: return 200...500
        }
    }

    var sizeRange: ClosedRange<CGFloat> {
        switch self {
        case .card: return 15...45
        case .fullScreen: return 40...90
        }
    }

    var amplitudeRange: ClosedRange<CGFloat> {
        switch self {
        case .card: return 10...30
        case .fullScreen: return 20...60
        }
    }

    var speedMultiplier: CGFloat {
        switch self {
        case .card: return 1.5
        case .fullScreen: return 2.5
        }
    }

    var stagger: CGFloat {
        switch self {
        case .card: return 20
        case .fullScreen: return 50
        }
    }
}

private struct BalloonParticleModel: Identifiable {
    let id: Int
    let x: CGFloat
    let speed: CGFloat
    let size: CGFloat
    let color: Color
    let initialPhase: CGFloat
    let amplitude: CGFloat
}

struct BalloonCelebrationView: View {
    let style: BalloonCelebrationStyle
    var duration: TimeInterval = 3.5
    var onFinished: () -> Void

    @State private var startDate = Date()

    private let balloons: [BalloonParticleModel]

    init(style: BalloonCelebrationStyle, duration: TimeInterval = 3.5, onFinished: @escaping () -> Void) {
        self.style = style
        self.duration = duration
        self.onFinished = onFinished

        let palette: [Color] = [
            DashboardTheme.primaryBlue,
            DashboardTheme.successGreen,
            DashboardTheme.warningYellow,
            DashboardTheme.dangerRed,
            DashboardTheme.infoBlue,
            Color(hex: "9C27B0"),
            Color(hex: "FF4081")
        ]

        balloons = (0..<style.balloonCount).map { id in
            BalloonParticleModel(
                id: id,
                x: CGFloat.random(in: 0...1),
                speed: CGFloat.random(in: style.speedRange),
                size: CGFloat.random(in: style.sizeRange),
                color: palette.randomElement() ?? DashboardTheme.primaryBlue,
                initialPhase: CGFloat.random(in: 0...(2 * .pi)),
                amplitude: CGFloat.random(in: style.amplitudeRange)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = min(timeline.date.timeIntervalSince(startDate), duration)
                let timeSecs = CGFloat(elapsed)

                for balloon in balloons {
                    let startDelayHeight = CGFloat(balloon.id) * style.stagger
                    let currentY = size.height + startDelayHeight - (balloon.speed * timeSecs * style.speedMultiplier)
                    let swayOffset = sin(timeSecs * 3 + balloon.initialPhase) * balloon.amplitude
                    let currentX = (balloon.x * size.width) + swayOffset

                    guard currentY > -150, currentY < size.height + 300 else { continue }

                    var stringPath = Path()
                    stringPath.move(to: CGPoint(x: currentX, y: currentY + balloon.size * 0.8))
                    stringPath.addLine(to: CGPoint(x: currentX, y: currentY + balloon.size * 2.5))
                    context.stroke(
                        stringPath,
                        with: .color(Color.gray.opacity(0.6)),
                        lineWidth: style == .card ? 1.5 : 2
                    )

                    let bodyRect = CGRect(
                        x: currentX - balloon.size / 2,
                        y: currentY - balloon.size * 0.65,
                        width: balloon.size,
                        height: balloon.size * 1.3
                    )
                    context.fill(Path(ellipseIn: bodyRect), with: .color(balloon.color))

                    let shineRect = CGRect(
                        x: currentX - balloon.size * 0.3,
                        y: currentY - balloon.size * 0.5,
                        width: balloon.size * 0.2,
                        height: balloon.size * 0.3
                    )
                    context.fill(Path(ellipseIn: shineRect), with: .color(Color.white.opacity(0.3)))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            startDate = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                onFinished()
            }
        }
    }
}
