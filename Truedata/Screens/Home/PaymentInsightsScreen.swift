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
                TextField("Search transactions...", text: Binding(
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
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(DashboardTheme.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
        switch viewModel.viewMode {
        case .bills:
            recordsHeaderRow(
                title: "\(viewModel.recordsCount) records found",
                trailing: nil
            )
        case .settlements:
            recordsHeaderRow(
                title: "Bill Settlements",
                trailing: "\(viewModel.settlementRecordsCount) records"
            )
        case .report:
            EmptyView()
        }
    }

    private func recordsHeaderRow(title: String, trailing: String?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "F3F4F6"))
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
                        PaymentTransactionRow(transaction: transaction)
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

    private let paymentModes = ["Cash", "Cheque", "UPI"]

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
                        metricBlock(
                            title: "Total Amount",
                            value: summary.totalTransactionAmount.currencyLabel,
                            valueColor: DashboardTheme.primaryBlue
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                Text("Breakdown by Payment Mode")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)

                ForEach(paymentModes, id: \.self) { mode in
                    let amount = paymentModeAmount(for: mode)
                    HStack {
                        Circle()
                            .fill(paymentModeColor(mode))
                            .frame(width: 8, height: 8)
                        Text(mode)
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Spacer()
                        Text(amount.currencyLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
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
        let segments = paymentModes.compactMap { mode -> DashboardChartSegment? in
            let amount = paymentModeAmount(for: mode)
            guard amount > 0 else { return nil }
            return DashboardChartSegment(value: amount, color: paymentModeColor(mode))
        }

        return DashboardDonutChart(
            segments: segments.isEmpty
                ? [DashboardChartSegment(value: 1, color: DashboardTheme.neutralMedium.opacity(0.3))]
                : segments,
            centerTitle: summary.totalTransactionAmount.indianCompactCurrencyLabel,
            centerSubtitle: "Total",
            size: 100,
            lineWidth: 12
        )
    }

    private func paymentModeAmount(for mode: String) -> Double {
        summary.amountByStatus.first { $0.key.caseInsensitiveCompare(mode) == .orderedSame }?.value ?? 0
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

    private var orderStatus: BillOrderStatus { BillOrderStatus(key: transaction.orderStatus) }
    private var paymentStatusLabel: String {
        PaymentInsightsPaymentStatus.title(for: transaction.status)
    }
    private var paymentStatusColor: Color {
        PaymentInsightsPaymentStatus.color(for: transaction.status)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(transaction.displayOrderLabel)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Text(transaction.date)
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(transaction.amount.currencyLabel)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                        Text("\(transaction.deductAmount.currencyLabel) Remaining")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                    }
                }

                detailLine(icon: "storefront", label: "Seller", value: transaction.sellerName)
                detailLine(icon: "phone", label: "Seller Mob.", value: transaction.sellerPhone)
                detailLine(icon: "person", label: "Staff", value: transaction.staffName)

                if orderStatus != .unknown {
                    Text("Order Status: \(orderStatus.label)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DashboardTheme.warningYellow)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DashboardTheme.warningYellow.opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 16) {
                    if !transaction.resolvedOrderId.isEmptyString {
                        NavigationLink {
                            OrderDetailScreen(orderId: transaction.resolvedOrderId)
                                .toolbar(.hidden, for: .navigationBar)
                                .navigationBarBackButtonHidden(true)
                        } label: {
                            actionLabel("View Order")
                        }
                        .buttonStyle(.plain)
                    }

                    if let sellerId = transaction.sellerIdInt {
                        NavigationLink {
                            BillSettlementScreen(sellerId: sellerId)
                                .toolbar(.hidden, for: .navigationBar)
                                .navigationBarBackButtonHidden(true)
                        } label: {
                            actionLabel("Add Payment")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)

            HStack {
                Text("Payment Status: \(paymentStatusLabel)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(paymentStatusColor)
                Spacer()
                Image(systemName: "barcode")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(paymentStatusColor.opacity(0.12))
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardTheme.neutralMedium.opacity(0.12), lineWidth: 1)
        }
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DashboardTheme.primaryBlue)
    }

    private func detailLine(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
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
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

private struct PaymentSettlementRow: View {
    let item: BillSettlementItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayBillId)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    Text(item.date)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                Spacer()
                Text(item.deductAmount.currencyLabel)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }

            HStack(spacing: 8) {
                paymentModeTag
                if !item.discount.isEmptyString, item.discount != "0", item.discount != "0.0" {
                    discountTag
                }
            }

            HStack(alignment: .top, spacing: 16) {
                settlementColumn(title: "SELLER", value: item.sellerName)
                settlementColumn(title: "STAFF", value: item.staffName)
            }

            if !item.orderId.isEmptyString {
                NavigationLink {
                    OrderDetailScreen(orderId: item.orderId)
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden(true)
                } label: {
                    HStack(spacing: 4) {
                        Text("View Details")
                            .font(.system(size: 13, weight: .semibold))
                        Text(">")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(DashboardTheme.primaryBlue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardTheme.neutralMedium.opacity(0.12), lineWidth: 1)
        }
    }

    private var displayBillId: String {
        let value = item.billId.isEmptyString ? item.orderId : item.billId
        guard !value.isEmptyString else { return "Settlement" }
        return value.hasPrefix("#") ? value : "#\(value)"
    }

    private var paymentModeTag: some View {
        let mode = PaymentInsightsPaymentMode.title(for: item.paymentMode)
        let color = paymentModeColor(for: mode)
        return HStack(spacing: 4) {
            Image(systemName: "banknote")
                .font(.system(size: 10, weight: .bold))
            Text(mode.uppercased())
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func paymentModeColor(for mode: String) -> Color {
        switch mode.lowercased() {
        case "cash": return DashboardTheme.successGreen
        case "cheque": return DashboardTheme.warningYellow
        case "upi": return DashboardTheme.primaryBlue
        default: return DashboardTheme.neutralMedium
        }
    }

    private var discountTag: some View {
        HStack(spacing: 4) {
            Image(systemName: "tag")
                .font(.system(size: 10, weight: .bold))
            Text("Discount ₹\(item.discount)")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(DashboardTheme.dangerRed)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DashboardTheme.dangerRed.opacity(0.1))
        .clipShape(Capsule())
    }

    private func settlementColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(value.isEmptyString ? "-" : value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
