//
//  AuthHeader.swift
//  Truedata
//

import SwiftUI

struct AuthHeader: View {
    var title: String = "Let's Get\nYou Started"
    var subtitle: String = "Sign up to your account and manage sales on the go"

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            starfield
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
        .frame(maxWidth: .infinity)
        .aspectRatio(1.5, contentMode: .fit)
        .clipped()
    }

    private var starfield: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(AppTheme.authHeader))

                let grid = AppTheme.authGrid
                let lines = 8
                let stepX = size.width / CGFloat(lines)
                let stepY = size.height / CGFloat(lines)
                for i in 1..<lines {
                    var vertical = Path()
                    vertical.move(to: CGPoint(x: CGFloat(i) * stepX, y: 0))
                    vertical.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: size.height))
                    context.stroke(vertical, with: .color(grid), lineWidth: 1)

                    var horizontal = Path()
                    horizontal.move(to: CGPoint(x: 0, y: CGFloat(i) * stepY))
                    horizontal.addLine(to: CGPoint(x: size.width, y: CGFloat(i) * stepY))
                    context.stroke(horizontal, with: .color(grid), lineWidth: 1)
                }

                let haloRect = CGRect(
                    x: size.width * 0.75 - size.width * 0.6,
                    y: size.height * 0.25 - size.width * 0.6,
                    width: size.width * 1.2,
                    height: size.width * 1.2
                )
                context.fill(
                    Path(ellipseIn: haloRect),
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(0.2), .clear]),
                        center: CGPoint(x: size.width * 0.75, y: size.height * 0.25),
                        startRadius: 0,
                        endRadius: size.width * 0.6
                    )
                )

                for index in 0..<50 {
                    let seed = Double(index)
                    let speed = 0.0001 + (seed.truncatingRemainder(dividingBy: 7) * 0.00003)
                    var x = (seed * 0.37).truncatingRemainder(dividingBy: 1) + time * speed / 2
                    var y = (seed * 0.61).truncatingRemainder(dividingBy: 1) + time * speed
                    x = x.truncatingRemainder(dividingBy: 1)
                    y = y.truncatingRemainder(dividingBy: 1)
                    if x < 0 { x += 1 }
                    if y < 0 { y += 1 }
                    let alpha = 0.15 + (seed.truncatingRemainder(dividingBy: 5) * 0.1)
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x * size.width,
                            y: y * size.height,
                            width: 2,
                            height: 2
                        )),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
    }
}

#Preview {
    AuthHeader()
}
