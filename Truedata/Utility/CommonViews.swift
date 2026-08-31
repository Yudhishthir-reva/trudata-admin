//
//  CommonViews.swift
//  Truedata
//

import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppTheme.darkMidnightBlue)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(isLoading || !isEnabled)
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var currentLineWidth: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentLineWidth + size.width > maxWidth, currentLineWidth > 0 {
                maxRowWidth = max(maxRowWidth, currentLineWidth - spacing)
                totalHeight += currentLineHeight + lineSpacing
                currentLineWidth = size.width + spacing
                currentLineHeight = size.height
            } else {
                currentLineWidth += size.width + spacing
                currentLineHeight = max(currentLineHeight, size.height)
            }
        }
        maxRowWidth = max(maxRowWidth, max(0, currentLineWidth - spacing))
        totalHeight += currentLineHeight
        return CGSize(width: proposal.width ?? maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var currentLineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += currentLineHeight + lineSpacing
                currentLineHeight = size.height
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            currentLineHeight = max(currentLineHeight, size.height)
        }
    }
}

