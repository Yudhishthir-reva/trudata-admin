//
//  AchievementHistoryScreen.swift
//  Truedata
//

import SwiftUI

struct AchievementHistoryScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AchievementHistoryViewModel

    init(startDate: String, endDate: String) {
        _viewModel = StateObject(
            wrappedValue: AchievementHistoryViewModel(startDate: startDate, endDate: endDate)
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Achievement Insights",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load(isRefresh: true) }
                )

                filterPanel
                tabBar
                content
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load() }
    }

    private var filterPanel: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AchievementHistoryDatePreset.selectablePresets) { preset in
                        Button {
                            viewModel.applyDatePreset(preset)
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(
                                    viewModel.selectedDatePreset == preset ? .white : DashboardTheme.neutralDark
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.selectedDatePreset == preset
                                        ? DashboardTheme.primaryBlue
                                        : Color.white
                                )
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(DashboardTheme.neutralMedium.opacity(0.2), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            HStack(spacing: 8) {
                DashboardDatePickerField(
                    dateString: viewModel.startDate,
                    onDateSelected: { viewModel.updateStartDate($0) }
                )
                DashboardDatePickerField(
                    dateString: viewModel.endDate,
                    onDateSelected: { viewModel.updateEndDate($0) }
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()
        }
        .background(Color.white)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AchievementHistoryViewMode.allCases, id: \.self) { mode in
                Button(action: { viewModel.viewMode = mode }) {
                    Text(mode.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.viewMode == mode ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if viewModel.viewMode == mode {
                                Rectangle()
                                    .fill(DashboardTheme.primaryBlue)
                                    .frame(height: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.data.isEmpty {
            Spacer()
            ProgressView().tint(DashboardTheme.primaryBlue)
            Spacer()
        } else if let error = viewModel.errorMessage, viewModel.data.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.load()
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.data.isEmpty {
            Text("No data found.")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                switch viewModel.viewMode {
                case .report:
                    reportContent
                case .list:
                    listContent
                }
            }
        }
    }

    private var reportContent: some View {
        VStack(spacing: 16) {
            if !viewModel.data.sortedSellerOrders.isEmpty {
                AchievementLeaderboardCard(
                    title: "Top Sellers by Orders",
                    systemImage: "trophy.fill",
                    items: viewModel.data.sortedSellerOrders.map {
                        AchievementLeaderboardItem(
                            id: $0.id,
                            label: $0.sellerName,
                            value: Double($0.orderCount),
                            formattedValue: "\($0.orderCount)"
                        )
                    },
                    progressColor: DashboardTheme.primaryBlue
                )
            }

            if !viewModel.data.sortedSellerCollections.isEmpty {
                AchievementLeaderboardCard(
                    title: "Top Sellers by Collection",
                    systemImage: "doc.text.fill",
                    items: viewModel.data.sortedSellerCollections.map {
                        AchievementLeaderboardItem(
                            id: $0.id,
                            label: $0.sellerName,
                            value: $0.totalAmount,
                            formattedValue: $0.totalAmount.compactCurrencyLabel
                        )
                    },
                    progressColor: DashboardTheme.successGreen
                )
            }

            if !viewModel.data.paymentModeSummaries.isEmpty {
                AchievementPaymentModeDonutCard(
                    title: "Collections by Payment Mode",
                    systemImage: "person.3.fill",
                    summaries: viewModel.data.paymentModeSummaries
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private var listContent: some View {
        VStack(spacing: 16) {
            if !viewModel.data.sortedSellerOrders.isEmpty {
                AchievementPaginatedListCard(
                    title: "Top Sellers by Orders",
                    systemImage: "trophy.fill",
                    pageSize: 4,
                    items: viewModel.data.sortedSellerOrders
                ) { row in
                    AchievementListRow(title: row.sellerName, value: "\(row.orderCount) Orders")
                }
            }

            if !viewModel.data.sortedSellerCollections.isEmpty {
                AchievementPaginatedListCard(
                    title: "Top Collections",
                    systemImage: "doc.text.fill",
                    pageSize: 4,
                    items: viewModel.data.sortedSellerCollections
                ) { row in
                    AchievementListRow(title: row.sellerName, value: row.totalAmount.currencyLabel)
                }
            }

            if !viewModel.data.sellerPaymentGroups.isEmpty {
                AchievementPaginatedListCard(
                    title: "Payment Breakdown by Seller",
                    systemImage: "person.3.fill",
                    pageSize: 2,
                    items: viewModel.data.sellerPaymentGroups
                ) { group in
                    AchievementPaymentBreakdownGroup(
                        sellerName: group.sellerName,
                        stats: group.stats,
                        paymentModeMap: viewModel.data.paymentModeMap
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

private struct AchievementLeaderboardItem: Identifiable {
    let id: String
    let label: String
    let value: Double
    let formattedValue: String
}

private struct AchievementLeaderboardCard: View {
    let title: String
    let systemImage: String
    let items: [AchievementLeaderboardItem]
    let progressColor: Color

    @State private var currentPage = 0
    private let pageSize = 5

    private var totalPages: Int {
        max(Int(ceil(Double(items.count) / Double(pageSize))), 1)
    }

    private var currentItems: [AchievementLeaderboardItem] {
        let start = currentPage * pageSize
        guard start < items.count else { return [] }
        return Array(items[start..<min(start + pageSize, items.count)])
    }

    private var maxValue: Double {
        max(items.map(\.value).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            VStack(spacing: 10) {
                ForEach(currentItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.label)
                                .font(.system(size: 13))
                                .foregroundStyle(DashboardTheme.neutralDark)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(item.formattedValue)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(progressColor)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(DashboardTheme.surfaceVariant)
                                Capsule()
                                    .fill(progressColor)
                                    .frame(width: proxy.size.width * CGFloat(item.value / maxValue))
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if totalPages > 1 {
                Divider()
                AchievementPaginationBar(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    onPrevious: { currentPage -= 1 },
                    onNext: { currentPage += 1 }
                )
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }
}

private struct AchievementPaymentModeDonutCard: View {
    let title: String
    let systemImage: String
    let summaries: [AchievementPaymentModeSummary]

    private var chartColors: [Color] {
        [
            DashboardTheme.primaryBlue,
            DashboardTheme.successGreen,
            DashboardTheme.secondaryPurple,
            DashboardTheme.accentTeal,
            DashboardTheme.infoBlue,
            DashboardTheme.pickupOrange,
            DashboardTheme.warningYellow
        ]
    }

    private var totalAmount: Double {
        summaries.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            HStack(alignment: .center, spacing: 12) {
                DashboardDonutChart(
                    segments: summaries.enumerated().map { index, item in
                        DashboardChartSegment(
                            value: item.amount,
                            color: chartColors[index % chartColors.count]
                        )
                    },
                    centerTitle: totalAmount.indianCompactCurrencyLabel,
                    centerSubtitle: "Total Collection",
                    size: 120,
                    lineWidth: 14
                )
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(summaries.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(chartColors[index % chartColors.count])
                                .frame(width: 8, height: 8)
                            Text(item.label)
                                .font(.system(size: 12))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(item.amount.compactCurrencyLabel)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }
}

private struct AchievementPaginatedListCard<Item: Identifiable, Content: View>: View {
    let title: String
    let systemImage: String
    let pageSize: Int
    let items: [Item]
    @ViewBuilder let rowContent: (Item) -> Content

    @State private var currentPage = 0

    private var totalPages: Int {
        max(Int(ceil(Double(items.count) / Double(pageSize))), 1)
    }

    private var currentItems: [Item] {
        let start = currentPage * pageSize
        guard start < items.count else { return [] }
        return Array(items[start..<min(start + pageSize, items.count)])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            VStack(spacing: 0) {
                ForEach(Array(currentItems.enumerated()), id: \.element.id) { index, item in
                    rowContent(item)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    if index < currentItems.count - 1 {
                        Divider().padding(.leading, 12)
                    }
                }
            }

            if totalPages > 1 {
                Divider()
                AchievementPaginationBar(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    onPrevious: { currentPage -= 1 },
                    onNext: { currentPage += 1 }
                )
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }
}

private struct AchievementListRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(2)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryBlue)
        }
    }
}

private struct AchievementPaymentBreakdownGroup: View {
    let sellerName: String
    let stats: [AchievementPaymentModeStat]
    let paymentModeMap: [Int: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "storefront")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Text(sellerName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(2)
            }

            VStack(spacing: 6) {
                ForEach(stats) { stat in
                    HStack {
                        Text(stat.modeLabel(from: paymentModeMap))
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(stat.transactionCount) Trx")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .frame(width: 56, alignment: .trailing)
                        Text(stat.totalAmount.currencyLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DashboardTheme.successGreen)
                            .frame(width: 88, alignment: .trailing)
                    }
                }
            }
            .padding(.leading, 4)
        }
    }
}

private struct AchievementPaginationBar: View {
    let currentPage: Int
    let totalPages: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
            }
            .disabled(currentPage <= 0)

            Text("Page \(currentPage + 1) of \(totalPages)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .disabled(currentPage >= totalPages - 1)
        }
        .foregroundStyle(DashboardTheme.primaryBlue)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
