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

// MARK: - Search (no filter button)

struct AppSearchBar<Trailing: View>: View {
    let placeholder: String
    @Binding var text: String
    var fill: Color = .white
    var strokeColor: Color? = nil
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 8
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .buttonStyle(.plain)
            }

            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if let strokeColor {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
    }
}

extension AppSearchBar where Trailing == EmptyView {
    init(
        placeholder: String,
        text: Binding<String>,
        fill: Color = .white,
        strokeColor: Color? = nil,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 8
    ) {
        self.init(
            placeholder: placeholder,
            text: text,
            fill: fill,
            strokeColor: strokeColor,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            trailing: { EmptyView() }
        )
    }
}

// MARK: - Empty / loading / error content shells

enum AppEmptyIllustration {
    case none
    case system(String)
    case sadMagnifyingGlass
}

struct AppEmptyState: View {
    var illustration: AppEmptyIllustration = .sadMagnifyingGlass
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            switch illustration {
            case .none:
                EmptyView()
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: 44))
                    .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.55))
                    .padding(.bottom, 4)
            case .sadMagnifyingGlass:
                SadMagnifyingGlassView()
                    .padding(.bottom, 8)
            }

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))
                .multilineTextAlignment(.center)

            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let actionTitle, let action {
                PrimaryActionButton(title: actionTitle, action: action)
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AppContentState<Content: View, Empty: View>: View {
    let isLoading: Bool
    var loadingMessage: String? = nil
    let errorMessage: String?
    /// No source data yet — show full-screen loading / error.
    var hasNoLoadedData: Bool
    /// Filtered / display list is empty.
    var isEmpty: Bool
    var retryTitle: String = "Retry"
    var onRetry: (() -> Void)? = nil
    @ViewBuilder var empty: () -> Empty
    @ViewBuilder var content: () -> Content

    var body: some View {
        if isLoading && hasNoLoadedData {
            Group {
                if let loadingMessage, !loadingMessage.isEmpty {
                    ProgressView(loadingMessage)
                } else {
                    ProgressView()
                }
            }
            .tint(DashboardTheme.primaryBlue)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage, hasNoLoadedData {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                if let onRetry {
                    PrimaryActionButton(title: retryTitle, action: onRetry)
                        .padding(.horizontal, 40)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isEmpty {
            empty()
        } else {
            content()
        }
    }
}

extension AppContentState where Empty == EmptyView {
    init(
        isLoading: Bool,
        loadingMessage: String? = nil,
        errorMessage: String?,
        hasNoLoadedData: Bool,
        retryTitle: String = "Retry",
        onRetry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            isLoading: isLoading,
            loadingMessage: loadingMessage,
            errorMessage: errorMessage,
            hasNoLoadedData: hasNoLoadedData,
            isEmpty: false,
            retryTitle: retryTitle,
            onRetry: onRetry,
            empty: { EmptyView() },
            content: content
        )
    }
}

struct SadMagnifyingGlassView: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1.5)
                .frame(width: 14, height: 14)
                .offset(x: -60, y: -35)

            Circle()
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1.5)
                .frame(width: 8, height: 8)
                .offset(x: 45, y: -40)

            Circle()
                .fill(Color(hex: "E5E7EB"))
                .frame(width: 8, height: 8)
                .offset(x: -65, y: 15)

            Circle()
                .fill(Color(hex: "E5E7EB"))
                .frame(width: 6, height: 6)
                .offset(x: 65, y: 25)

            Text("+")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(Color(hex: "D1D5DB"))
                .offset(x: 55, y: -10)

            Text("+")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Color(hex: "D1D5DB"))
                .offset(x: -15, y: -40)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "CBD5E1"), lineWidth: 8)
                        .background(Circle().fill(Color(hex: "F8FAFC")))
                        .frame(width: 72, height: 72)

                    VStack(spacing: 4) {
                        HStack(spacing: 12) {
                            Capsule()
                                .fill(Color(hex: "475569"))
                                .frame(width: 4, height: 8)
                            Capsule()
                                .fill(Color(hex: "475569"))
                                .frame(width: 4, height: 8)
                        }

                        Capsule()
                            .fill(Color(hex: "475569"))
                            .frame(width: 10, height: 2.5)
                    }

                    Image(systemName: "drop.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "BAE6FD"))
                        .offset(x: 24, y: -10)
                }

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(hex: "64748B"))
                    .frame(width: 12, height: 28)
                    .rotationEffect(.degrees(-45))
                    .offset(x: 24, y: -10)
            }
        }
        .frame(width: 160, height: 120)
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

