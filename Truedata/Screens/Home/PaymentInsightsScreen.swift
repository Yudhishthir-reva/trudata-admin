//
//  PaymentInsightsScreen.swift
//  Truedata
//

import SwiftUI

struct PaymentInsightsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PaymentInsightsViewModel
    @State private var showFilterSheet = false

    init(
        startDate: String? = nil,
        endDate: String? = nil,
        initialTab: PaymentInsightsViewMode = .report,
        datePreset: OrderInsightsDatePreset? = nil,
        paymentStatus: String? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: PaymentInsightsViewModel(
                startDate: startDate,
                endDate: endDate,
                initialViewMode: initialTab,
                datePreset: datePreset,
                paymentStatus: paymentStatus
            )
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                PaymentInsightsAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.refreshAll() }
                )

                searchAndFilterBar
                viewModeTabs
                recordsHeader
                mainContent
            }

            if isInitialLoading {
                ProgressView().tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.initialize() }
        .sheet(isPresented: $showFilterSheet) {
            PaymentInsightsFilterSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var isInitialLoading: Bool {
        switch viewModel.viewMode {
        case .report:
            return viewModel.isLoading && viewModel.summary == nil
        case .settlements:
            return viewModel.isLoadingSettlements && viewModel.settlements.isEmpty
        case .bills:
            return viewModel.isLoading && viewModel.transactions.isEmpty
        }
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search...", text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.updateSearch($0) }
                ))
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if !viewModel.searchText.isEmptyString {
                    Button { viewModel.updateSearch("") } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.neutralMedium.opacity(0.35), lineWidth: 1)
            }

            Button { showFilterSheet = true } label: {
                ZStack(alignment: .topTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Filter")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color.clear)
                    .overlay {
                        Capsule()
                            .stroke(DashboardTheme.primaryBlue.opacity(0.55), lineWidth: 1)
                    }

                    if viewModel.isFilterActive {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(Color(hex: "F3F4F6"))
    }

    private var viewModeTabs: some View {
        HStack(spacing: 0) {
            ForEach(PaymentInsightsViewMode.allCases, id: \.self) { mode in
                Button { viewModel.viewMode = mode } label: {
                    VStack(spacing: 8) {
                        Text(mode.rawValue)
                            .font(.system(size: 15, weight: viewModel.viewMode == mode ? .bold : .medium))
                            .foregroundStyle(
                                viewModel.viewMode == mode
                                ? DashboardTheme.primaryBlue
                                : DashboardTheme.neutralMedium
                            )
                        Rectangle()
                            .fill(viewModel.viewMode == mode ? DashboardTheme.primaryBlue : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .background(Color(hex: "F3F4F6"))
    }

    @ViewBuilder
    private var recordsHeader: some View {
        if viewModel.viewMode == .bills {
            HStack {
                Text("\(viewModel.recordsCount) records found")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "F3F4F6"))
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.viewMode {
        case .report:
            reportContent
        case .settlements:
            settlementsContent
        case .bills:
            billsContent
        }
    }

    @ViewBuilder
    private var reportContent: some View {
        if let error = viewModel.errorMessage, viewModel.summary == nil, !viewModel.isLoading {
            emptyState(message: error, retry: { viewModel.loadTransactions(isRefresh: true) })
        } else if viewModel.summary == nil && !viewModel.isLoading {
            emptyState(message: "No summary data available.")
        } else if let summary = viewModel.summary {
            ScrollView {
                PaymentInsightsReportCard(summary: summary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var settlementsContent: some View {
        if let error = viewModel.settlementErrorMessage, viewModel.settlements.isEmpty, !viewModel.isLoadingSettlements {
            emptyState(message: error, retry: { viewModel.loadSettlements(isRefresh: true) })
        } else if viewModel.settlements.isEmpty && !viewModel.isLoadingSettlements {
            emptyState(message: "No settlements found.")
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.settlements) { item in
                        PaymentSettlementRow(item: item)
                            .onAppear { viewModel.loadMoreSettlementsIfNeeded(current: item) }
                    }
                    if viewModel.isLoadingMoreSettlements {
                        ProgressView().tint(DashboardTheme.primaryBlue).padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    @ViewBuilder
    private var billsContent: some View {
        if let error = viewModel.errorMessage, viewModel.transactions.isEmpty, !viewModel.isLoading {
            emptyState(message: error, retry: { viewModel.loadTransactions(isRefresh: true) })
        } else if viewModel.transactions.isEmpty && !viewModel.isLoading {
            emptyState(message: "No bills/orders found.")
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.transactions) { transaction in
                        NavigationLink {
                            OrderDetailScreen(orderId: transaction.orderNo)
                        } label: {
                            PaymentTransactionRow(transaction: transaction)
                        }
                        .buttonStyle(.plain)
                        .onAppear { viewModel.loadMoreTransactionsIfNeeded(current: transaction) }
                    }
                    if viewModel.isLoadingMore {
                        ProgressView().tint(DashboardTheme.primaryBlue).padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private func emptyState(message: String, retry: (() -> Void)? = nil) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Retry", action: retry)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(DashboardTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PaymentInsightsAppBar: View {
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("Payment Insights")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }

            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
    }
}

private struct PaymentInsightsReportCard: View {
    let summary: PaymentInsightsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Financial Overview")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    paymentModeDonut
                    VStack(alignment: .leading, spacing: 10) {
                        metricBlock(title: "Bills with Settlements", value: "\(summary.totalTransactions)")
                        metricBlock(title: "Total Amount", value: summary.totalTransactionAmount.currencyLabel, valueColor: DashboardTheme.primaryBlue)
                        metricBlock(title: "Avg. Transaction", value: summary.averageTransactionValue.currencyLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !summary.amountByStatus.isEmpty {
                    Divider()
                    Text("Breakdown by Payment Mode")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)

                    ForEach(summary.amountByStatus.sorted(by: { $0.key < $1.key }), id: \.key) { key, amount in
                        HStack {
                            Circle()
                                .fill(paymentModeColor(key))
                                .frame(width: 8, height: 8)
                            Text(key.capitalized)
                                .font(.system(size: 13))
                                .foregroundStyle(DashboardTheme.neutralDark)
                            Spacer()
                            Text(amount.currencyLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DashboardTheme.primaryBlue)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
            }
        }
    }

    private var paymentModeDonut: some View {
        let segments = summary.amountByStatus.map { key, value in
            DashboardChartSegment(value: value, color: paymentModeColor(key))
        }.filter { $0.value > 0 }

        return DashboardDonutChart(
            segments: segments.isEmpty
                ? [DashboardChartSegment(value: 1, color: DashboardTheme.neutralMedium.opacity(0.3))]
                : segments,
            centerTitle: summary.totalTransactionAmount.compactCurrencyLabel,
            centerSubtitle: nil,
            size: 96,
            lineWidth: 12
        )
    }

    private func metricBlock(title: String, value: String, valueColor: Color = DashboardTheme.neutralDark) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(valueColor)
        }
    }

    private func paymentModeColor(_ mode: String) -> Color {
        switch mode.lowercased() {
        case "cash": return DashboardTheme.successGreen
        case "cheque": return DashboardTheme.warningYellow
        case "upi": return DashboardTheme.primaryBlue
        default: return DashboardTheme.neutralMedium
        }
    }
}

private struct PaymentTransactionRow: View {
    let transaction: PaymentTransactionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.orderNo.isEmptyString ? "Order" : transaction.orderNo)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    Text(transaction.date)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(transaction.amount.currencyLabel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    Text("\(transaction.deductAmount.currencyLabel) Remaining")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
            }

            Divider()

            detailLine(icon: "storefront", label: "Seller", value: transaction.sellerName)
            detailLine(icon: "person", label: "Staff", value: transaction.staffName)
            HStack(spacing: 8) {
                statusChip(
                    PaymentInsightsPaymentStatus.title(for: transaction.status),
                    color: PaymentInsightsPaymentStatus.color(for: transaction.status)
                )
                statusChip(
                    PaymentInsightsPaymentMode.title(for: transaction.paymentMode),
                    color: DashboardTheme.infoBlue
                )
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.neutralMedium.opacity(0.15), lineWidth: 1)
        }
    }

    private func detailLine(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(width: 16)
            Text("\(label):")
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(value.isEmptyString ? "-" : value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
            Spacer(minLength: 0)
        }
    }

    private func statusChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct PaymentSettlementRow: View {
    let item: BillSettlementItem

    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: item.imageUrl, contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.orderId.isEmptyString ? item.billId : "Order \(item.orderId)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text(item.sellerName)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Text(item.date)
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text(item.deductAmount.currencyLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                Text(PaymentInsightsPaymentMode.title(for: item.paymentMode))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.neutralMedium.opacity(0.15), lineWidth: 1)
        }
    }
}
