//
//  StaffActivitiesCommonViews.swift
//  Truedata
//

import SwiftUI

enum StaffActivityRankStyle {
    static func color(for rank: Int) -> Color {
        switch rank {
        case 1: return DashboardTheme.rankGold
        case 2: return DashboardTheme.rankSilver
        case 3: return DashboardTheme.rankBronze
        default: return DashboardTheme.rankDefault
        }
    }

    static func textColor(for rank: Int) -> Color {
        rank <= 3 ? .white : .black
    }

    static func rowBackground(for rank: Int) -> Color {
        if rank <= 3 {
            return color(for: rank).opacity(0.04)
        }
        return DashboardTheme.infoBlue.opacity(0.1)
    }
}

struct StaffActivityTableHeader: View {
    var showAmountDetails: Bool
    var staffColumnTitle: String = "STAFF"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("#")
                    .frame(width: 36, alignment: .leading)
                Text(staffColumnTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("ORDERS")
                    .frame(width: 72, alignment: .trailing)
                if showAmountDetails {
                    Text("SALES / COLLEC.")
                        .frame(width: 96, alignment: .trailing)
                }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(DashboardTheme.neutralMedium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .overlay(Color(hex: "D1D5DB").opacity(0.5))
        }
        .background(Color(hex: "FAFAFA"))
    }
}

struct StaffActivityTableRow: View {
    let row: StaffActivityDisplayRow
    let rank: Int
    var showAmountDetails: Bool
    var animateTopRank: Bool = true

    @State private var pulseScale = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                rankBadge
                    .frame(width: 36, alignment: .leading)

                Text(row.name)
                    .font(.system(size: 13, weight: rank <= 3 ? .bold : .medium))
                    .foregroundStyle(rank <= 3 ? DashboardTheme.neutralDark : Color(hex: "374151"))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 2) {
                    Text("\(row.orders)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    Text("orders")
                        .font(.system(size: 10))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .padding(.bottom, 1)
                }
                .frame(width: 72, alignment: .trailing)

                if showAmountDetails {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.sales.currencyLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(rank <= 3 ? StaffActivityRankStyle.color(for: rank) : DashboardTheme.neutralDark)
                            .lineLimit(1)
                        Text(row.collection.currencyLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .lineLimit(1)
                    }
                    .frame(width: 96, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .overlay(Color(hex: "D1D5DB").opacity(0.2))
        }
        .background(StaffActivityRankStyle.rowBackground(for: rank))
    }

    private var rankBadge: some View {
        let rankColor = StaffActivityRankStyle.color(for: rank)
        let scale = (animateTopRank && rank == 1) ? (pulseScale ? 1.15 : 1.0) : 1.0

        return Text("\(rank)")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(StaffActivityRankStyle.textColor(for: rank))
            .frame(width: 24, height: 24)
            .background(rankColor)
            .clipShape(Circle())
            .scaleEffect(scale)
            .onAppear {
                guard animateTopRank, rank == 1 else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulseScale = true
                }
            }
    }
}

struct StaffActivitiesPillButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(DashboardTheme.neutralMedium)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .overlay {
                Capsule()
                    .stroke(Color(hex: "D1D5DB").opacity(0.8), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
