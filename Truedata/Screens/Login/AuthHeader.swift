//
//  AuthHeader.swift
//  Truedata
//

import SwiftUI

private struct StarInfo {
    var initialX: Double
    var initialY: Double
    var alpha: Double
    var speed: Double
}

struct AuthHeader: View {
    var title: String = "Let's Get\nYou Started"
    var subtitle: String = "Sign up to your account and manage sales on the go"

    @State private var animatedAlpha: CGFloat = 0.0

    private let headerHeight: CGFloat = 280
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    // Deterministic 50 stars matching Android Random(0) distribution
    private let stars: [StarInfo] = {
        var result: [StarInfo] = []
        var seed: UInt64 = 123456789
        func nextRandom() -> Double {
            seed = (1103515245 * seed + 12345) & 0x7FFFFFFF
            return Double(seed) / Double(0x7FFFFFFF)
        }

        for _ in 0..<50 {
            let x = nextRandom()
            let y = nextRandom()
            let rawAlpha = nextRandom()
            let alpha = max(0.1, min(0.7, rawAlpha))
            let speed = nextRandom() * 0.0002 + 0.0001
            result.append(StarInfo(initialX: x, initialY: y, alpha: alpha, speed: speed))
        }
        return result
    }()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(hex: "0F2C42")

            starfield
                .opacity(animatedAlpha)

            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
                    .lineSpacing(8)
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(width: screenWidth, height: headerHeight)
        .clipped()
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedAlpha = 1.0
            }
        }
    }

    private var starfield: some View {
        let width = screenWidth
        let height = headerHeight

        return TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, _ in
                // 1. Space background
                context.fill(Path(CGRect(x: 0, y: 0, width: width, height: height)), with: .color(Color(hex: "0F2C42")))

                // 2. 8x8 Grid lines
                let gridColor = Color(hex: "1A4668")
                let lines = 8
                let stepX = width / CGFloat(lines)
                let stepY = height / CGFloat(lines)

                for i in 1..<lines {
                    var vertical = Path()
                    vertical.move(to: CGPoint(x: CGFloat(i) * stepX, y: 0))
                    vertical.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: height))
                    context.stroke(vertical, with: .color(gridColor), lineWidth: 1)

                    var horizontal = Path()
                    horizontal.move(to: CGPoint(x: 0, y: CGFloat(i) * stepY))
                    horizontal.addLine(to: CGPoint(x: width, y: CGFloat(i) * stepY))
                    context.stroke(horizontal, with: .color(gridColor), lineWidth: 1)
                }

                // 3. Diagonal Halo Glow Effect (Top-right quadrant)
                let haloCenter = CGPoint(x: width * 0.75, y: height * 0.25)
                let haloRadius = width * 0.6
                let haloRect = CGRect(
                    x: haloCenter.x - haloRadius,
                    y: haloCenter.y - haloRadius,
                    width: haloRadius * 2,
                    height: haloRadius * 2
                )
                context.fill(
                    Path(ellipseIn: haloRect),
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.2), .clear]),
                        center: haloCenter,
                        startRadius: 0,
                        endRadius: haloRadius
                    )
                )

                // 4. Floating Stars animation
                let elapsedFrames = time * 60.0
                for star in stars {
                    var curY = (star.initialY + star.speed * elapsedFrames).truncatingRemainder(dividingBy: 1.0)
                    var curX = (star.initialX + (star.speed / 2.0) * elapsedFrames).truncatingRemainder(dividingBy: 1.0)

                    if curY < 0 { curY += 1.0 }
                    if curX < 0 { curX += 1.0 }

                    let starRect = CGRect(
                        x: curX * width - 1.0,
                        y: curY * height - 1.0,
                        width: 2.2,
                        height: 2.2
                    )
                    context.fill(
                        Path(ellipseIn: starRect),
                        with: .color(Color.white.opacity(star.alpha))
                    )
                }
            }
            .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
    }
}

#Preview {
    AuthHeader()
}
