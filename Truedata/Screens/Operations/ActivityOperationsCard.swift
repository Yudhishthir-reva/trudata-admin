//
//  ActivityOperationsCard.swift
//  Truedata
//

import SwiftUI

struct TodayAchievementsSummary {
    let sellerCount: Int
    let collectionAmount: Double
    let approvedAmount: Double
    let cashCount: Int
    let upiCount: Int
    let chequeCount: Int
    let cashAmount: Double
    let upiAmount: Double
    let chequeAmount: Double

    var totalTransactions: Int { cashCount + upiCount + chequeCount }

    static let empty = TodayAchievementsSummary(
        sellerCount: 0,
        collectionAmount: 0,
        approvedAmount: 0,
        cashCount: 0,
        upiCount: 0,
        chequeCount: 0,
        cashAmount: 0,
        upiAmount: 0,
        chequeAmount: 0
    )

    static func from(payload: JSONValue?) -> TodayAchievementsSummary {
        guard let payload else { return .empty }
        return from(dictionary: payload.objectValue)
    }

    static func from(dictionary payload: [String: JSONValue]) -> TodayAchievementsSummary {
        let paymentCounts = payload["paymentModeWise"]
        let paymentAmounts = payload["paymentModeWiseAmount"]
        let payloadValue = JSONValue.object(payload)

        return TodayAchievementsSummary(
            sellerCount: payloadValue.int(for: "todaySellerCount", "today_seller_count"),
            collectionAmount: payloadValue.double(for: "todayCollectionAmount", "today_collection_amount"),
            approvedAmount: payloadValue.double(for: "todayApprovedCollectionAmount", "today_approved_collection_amount"),
            cashCount: paymentCounts?.int(for: "cash") ?? 0,
            upiCount: paymentCounts?.int(for: "upi") ?? 0,
            chequeCount: paymentCounts?.int(for: "cheque") ?? 0,
            cashAmount: paymentAmounts?.double(for: "cash") ?? 0,
            upiAmount: paymentAmounts?.double(for: "upi") ?? 0,
            chequeAmount: paymentAmounts?.double(for: "cheque") ?? 0
        )
    }
}

struct ActivityOperationsCard: View {
    let title: String
    let data: TodayAchievementsSummary
    var onViewDetails: (() -> Void)?

    var body: some View {
        DashboardCardChrome(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                DashboardBulletTitle(title: title.isEmptyString ? "Today Achievements" : title)

                mainStatsRow

                Divider().overlay(DashboardTheme.surfaceVariant)

                collectionSummarySection

                Divider().overlay(DashboardTheme.surfaceVariant)

                paymentMethodsSection

                if let onViewDetails {
                    HStack {
                        Spacer()
                        Button(action: onViewDetails) {
                            HStack(spacing: 4) {
                                Text("View Details")
                                    .font(.system(size: 12, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var mainStatsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            achievementDonut(
                value: data.sellerCount,
                label: "Sellers Ordered",
                segments: data.sellerCount > 0
                    ? [DashboardChartSegment(value: Double(data.sellerCount), color: DashboardTheme.successGreen)]
                    : []
            )

            achievementDonut(
                value: data.totalTransactions,
                label: "Total Collection",
                segments: transactionSegments
            )
        }
    }

    private var transactionSegments: [DashboardChartSegment] {
        var segments: [DashboardChartSegment] = []
        if data.cashCount > 0 {
            segments.append(DashboardChartSegment(value: Double(data.cashCount), color: DashboardTheme.successGreen))
        }
        if data.upiCount > 0 {
            segments.append(DashboardChartSegment(value: Double(data.upiCount), color: DashboardTheme.infoBlue))
        }
        if data.chequeCount > 0 {
            segments.append(DashboardChartSegment(value: Double(data.chequeCount), color: DashboardTheme.pickupOrange))
        }
        return segments
    }

    private func achievementDonut(value: Int, label: String, segments: [DashboardChartSegment]) -> some View {
        VStack(spacing: 8) {
            DashboardDonutChart(
                segments: segments,
                centerTitle: "\(value)",
                centerSubtitle: nil,
                size: 96,
                lineWidth: 12
            )
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var collectionSummarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            DashboardSectionHeader(title: "Today's Collection Summary")

            VStack(spacing: 4) {
                Text("Total Collection")
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Text(displayCollectionAmount.currencyLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(DashboardTheme.surfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var displayCollectionAmount: Double {
        if data.approvedAmount > 0 { return data.approvedAmount }
        if data.collectionAmount > 0 { return data.collectionAmount }
        return data.cashAmount + data.upiAmount + data.chequeAmount
    }

    private var paymentMethodsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DashboardSectionHeader(title: "Payment Methods Breakdown")

            VStack(spacing: 6) {
                paymentModeRow(
                    icon: "banknote.fill",
                    label: "Cash",
                    count: data.cashCount,
                    amount: data.cashAmount,
                    color: DashboardTheme.successGreen
                )
                paymentModeRow(
                    icon: "doc.text.fill",
                    label: "UPI",
                    count: data.upiCount,
                    amount: data.upiAmount,
                    color: DashboardTheme.infoBlue
                )
                paymentModeRow(
                    icon: "creditcard.fill",
                    label: "Cheque",
                    count: data.chequeCount,
                    amount: data.chequeAmount,
                    color: DashboardTheme.pickupOrange
                )
            }
        }
    }

    private func paymentModeRow(
        icon: String,
        label: String,
        count: Int,
        amount: Double,
        color: Color
    ) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text("\(count) transactions")
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }

            Spacer(minLength: 0)

            Text(amount.currencyLabel)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DashboardTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ActivityOperationsContent: View {
    let tile: OperationsTile?
    var onViewDetails: () -> Void

    var body: some View {
        ActivityOperationsCard(
            title: tile?.title ?? "Today Achievements",
            data: TodayAchievementsSummary.from(payload: tile?.payload),
            onViewDetails: onViewDetails
        )
    }
}
