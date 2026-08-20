//
//  SlideToConfirmView.swift
//  Truedata
//

import SwiftUI

struct SlideToConfirmView: View {
    let text: String
    var isEnabled: Bool = true
    let onConfirmed: () -> Void

    @State private var dragOffset: CGFloat = 0

    private let handleSize: CGFloat = 52
    private let trackHeight: CGFloat = 58

    var body: some View {
        GeometryReader { proxy in
            let maxOffset = max(proxy.size.width - handleSize - 8, 0)
            let progress = maxOffset > 0 ? min(max(dragOffset / maxOffset, 0), 1) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.darkMidnightBlue)

                Text(text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .opacity(Double(1 - progress))

                Capsule()
                    .fill(DashboardTheme.primaryBlue.opacity(0.35))
                    .frame(width: handleSize + dragOffset + 8)

                Circle()
                    .fill(DashboardTheme.primaryBlue)
                    .frame(width: handleSize, height: handleSize)
                    .overlay {
                        Image(systemName: "chevron.right.2")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4 + dragOffset)
                    .gesture(
                        DragGesture(minimumDistance: 4)
                            .onChanged { value in
                                guard isEnabled else { return }
                                dragOffset = min(max(value.translation.width, 0), maxOffset)
                            }
                            .onEnded { _ in
                                guard isEnabled else { return }
                                if dragOffset >= maxOffset * 0.85 {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        dragOffset = maxOffset
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        onConfirmed()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            dragOffset = 0
                                        }
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
            }
            .frame(height: trackHeight)
        }
        .frame(height: trackHeight)
        .opacity(isEnabled ? 1 : 0.55)
        .allowsHitTesting(isEnabled)
    }
}
