//
//  DashboardDonutChart.swift
//  Truedata
//

import SwiftUI

struct DashboardChartSegment: Identifiable {
    let id = UUID()
    let value: Double
    let color: Color
}

struct DashboardDonutChart: View {
    let segments: [DashboardChartSegment]
    let centerTitle: String
    let centerSubtitle: String?
    var size: CGFloat = 110
    var lineWidth: CGFloat = 14

    private var total: Double {
        max(segments.reduce(0) { $0 + $1.value }, 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(DashboardTheme.surfaceVariant, lineWidth: lineWidth)

                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    let start = segments.prefix(index).reduce(0.0) { $0 + $1.value } / total
                    Circle()
                        .trim(from: start, to: start + segment.value / total)
                        .stroke(segment.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 2) {
                    Text(centerTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    if let centerSubtitle {
                        Text(centerSubtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(width: size, height: size)
        }
    }
}
