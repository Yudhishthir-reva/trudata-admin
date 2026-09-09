//
//  HomeAppBar.swift
//  Truedata
//

import SwiftUI

struct HomeAppBar: View {
    let title: String
    let role: String
    let profileUrl: String
    var onProfileTap: () -> Void = {}
    var onRefresh: () -> Void
    var onLogout: () -> Void

    @State private var didAppear = false
    @State private var particles: [HomeHeaderParticle] = HomeHeaderParticle.makeSeed(count: 28)

    var body: some View {
        HStack(spacing: 14) {
            profileAvatar
                .scaleEffect(didAppear ? 1 : 0.01)
                .animation(.spring(response: 0.55, dampingFraction: 0.65), value: didAppear)

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome Back!")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title.isEmptyString ? "TruDataa" : title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !role.isEmptyString {
                        Text("(\(role))")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(0.1), value: didAppear)

            Spacer(minLength: 8)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 36, height: 36)
            }
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : -10)
            .animation(.easeOut(duration: 0.35).delay(0.2), value: didAppear)

            Button(action: onLogout) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 36, height: 36)
            }
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : -10)
            .animation(.easeOut(duration: 0.35).delay(0.4), value: didAppear)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            headerBackground
        }
        .onAppear {
            didAppear = true
        }
    }

    /// Android HomeAppBar: green panel + glow + floating white motes.
    private var headerBackground: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 32,
                        bottomTrailingRadius: 32,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: AppTheme.heroTop, location: 0),
                                .init(color: AppTheme.heroMid, location: 0.55),
                                .init(color: AppTheme.heroBottom, location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                    // Soft top-right glow
                    RadialGradient(
                        colors: [
                            AppTheme.heroGlow.opacity(0.28),
                            AppTheme.heroGlow.opacity(0.06),
                            .clear
                        ],
                        center: UnitPoint(x: 0.86, y: 0.12),
                        startRadius: 0,
                        endRadius: max(size.width, 1) * 0.72
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 32,
                            bottomTrailingRadius: 32,
                            topTrailingRadius: 0,
                            style: .continuous
                        )
                    )

                    Canvas { context, canvasSize in
                        for particle in particles {
                            let travelled = (particle.startY - time * particle.speed)
                                .truncatingRemainder(dividingBy: 1.2)
                            let wrapped = travelled < 0 ? travelled + 1.2 : travelled
                            let y = (wrapped - 0.1) * canvasSize.height
                            let wobble = sin(time * 0.5 + particle.phase) * 0.015
                            let x = (particle.x + wobble) * canvasSize.width
                            let radius = particle.radius
                            let rect = CGRect(
                                x: x - radius,
                                y: y - radius,
                                width: radius * 2,
                                height: radius * 2
                            )
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(.white.opacity(particle.alpha))
                            )
                        }
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 32,
                            bottomTrailingRadius: 32,
                            topTrailingRadius: 0,
                            style: .continuous
                        )
                    )
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var profileAvatar: some View {
        Button(action: onProfileTap) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.45), lineWidth: 2)
                    .frame(width: 52, height: 52)

                if !profileUrl.isEmptyString {
                    RemoteImage(url: profileUrl)
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 46, height: 46)
                        .overlay {
                            Text(initial)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var initial: String {
        let source = title.isEmptyString ? "T" : title
        return String(source.prefix(1)).uppercased()
    }
}

// MARK: - Particles (Android HomeAppBar floating dots)

private struct HomeHeaderParticle: Identifiable {
    let id: UUID
    let x: CGFloat
    let startY: Double
    let radius: CGFloat
    let alpha: Double
    let speed: Double
    let phase: Double

    static func makeSeed(count: Int) -> [HomeHeaderParticle] {
        (0..<count).map { _ in
            HomeHeaderParticle(
                id: UUID(),
                x: CGFloat.random(in: 0...1),
                startY: Double.random(in: 0...1),
                radius: CGFloat.random(in: 0.8...2.4),
                alpha: Double.random(in: 0.06...0.26),
                speed: Double.random(in: 0.02...0.07),
                phase: Double.random(in: 0...(2 * .pi))
            )
        }
    }
}
