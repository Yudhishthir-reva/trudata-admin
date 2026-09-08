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
    var spacing: CGFloat
    var lineSpacing: CGFloat
    var alignment: HorizontalAlignment

    init(
        spacing: CGFloat = 8,
        lineSpacing: CGFloat? = nil,
        alignment: HorizontalAlignment = .leading
    ) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing ?? spacing
        self.alignment = alignment
    }

    struct Row {
        var subviews: [(subview: LayoutSubview, size: CGSize, x: CGFloat)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    struct LayoutResult {
        var rows: [Row] = []
        var totalSize: CGSize = .zero
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).totalSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in result.rows {
            let rowOffset: CGFloat
            switch alignment {
            case .leading:
                rowOffset = 0
            case .center:
                rowOffset = max(0, (bounds.width - row.width) / 2)
            case .trailing:
                rowOffset = max(0, bounds.width - row.width)
            default:
                rowOffset = 0
            }

            for item in row.subviews {
                let x = bounds.minX + item.x + rowOffset
                let itemY = y + (row.height - item.size.height) / 2
                item.subview.place(at: CGPoint(x: x, y: itemY), proposal: ProposedViewSize(item.size))
            }

            y += row.height + lineSpacing
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var currentRow = Row()
        var currentX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, !currentRow.subviews.isEmpty {
                currentRow.width = max(0, currentX - spacing)
                rows.append(currentRow)
                currentRow = Row()
                currentX = 0
            }

            currentRow.subviews.append((subview: subview, size: size, x: currentX))
            currentRow.height = max(currentRow.height, size.height)
            currentX += size.width + spacing
        }

        if !currentRow.subviews.isEmpty {
            currentRow.width = max(0, currentX - spacing)
            rows.append(currentRow)
        }

        let maxRowWidth = rows.map(\.width).max() ?? 0
        let totalHeight: CGFloat
        if rows.isEmpty {
            totalHeight = 0
        } else {
            let rowHeightsSum = rows.map(\.height).reduce(0, +)
            let spacingSum = CGFloat(max(0, rows.count - 1)) * lineSpacing
            totalHeight = rowHeightsSum + spacingSum
        }

        let computedWidth = (proposal.width != nil && proposal.width != .infinity)
            ? proposal.width!
            : maxRowWidth

        return LayoutResult(
            rows: rows,
            totalSize: CGSize(width: computedWidth, height: totalHeight)
        )
    }
}

