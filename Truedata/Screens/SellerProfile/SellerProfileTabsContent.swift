//
//  SellerProfileTabsContent.swift
//  Truedata
//

import SwiftUI

struct SellerProfileActionsTab: View {
    let sellerId: Int
    let screenTitle: String

    var body: some View {
        VStack(spacing: 14) {
            SellerProfileOperationCard(
                title: "Add Payment",
                description: "Add amount paid in cheque here to settle...",
                buttonTitle: "Go to Add Payment",
                destination: {
                    AddPaymentScreen(sellerId: sellerId, appBarTitle: screenTitle)
                }
            )
            SellerProfileOperationCard(
                title: "Bill Settlement",
                description: "Settle your bills here...",
                buttonTitle: "Go to Bill Settlement",
                destination: {
                    BillSettlementScreen(sellerId: sellerId)
                }
            )
            SellerProfileOperationCard(
                title: "Cheque Settlement",
                description: "Settle pending bills using approved cheques...",
                buttonTitle: "Go to Cheque Settlement",
                destination: {
                    ChequeSettlementScreen(sellerId: sellerId)
                }
            )
            SellerProfileOperationCard(
                title: "Payment approvals via Retailer App",
                description: "Review payments this retailer submitted from their app...",
                buttonTitle: "Go to Retailer App Payments",
                destination: {
                    RetailerAppPaymentScreen()
                }
            )
        }
    }
}

struct SellerProfileOrdersTab: View {
    @ObservedObject var viewModel: SellerProfileViewModel

    var body: some View {
        VStack(spacing: 12) {
            SellerProfileSearchField(
                text: $viewModel.orderIdSearch,
                placeholder: "Search by Order ID..."
            )

            SellerProfileFilterChipRow(
                presets: SellerProfileDatePreset.ordersTabPresets + [.custom],
                selectedPreset: viewModel.ordersDatePreset,
                onSelect: { viewModel.selectOrdersDatePreset($0) }
            )

            if viewModel.ordersShowCustomDates || viewModel.ordersDatePreset == .custom {
                HStack(spacing: 10) {
                    SellerProfileDateField(
                        label: "Start",
                        dateString: viewModel.ordersStartDate,
                        onDateSelected: { viewModel.updateOrdersStartDate($0) }
                    )
                    SellerProfileDateField(
                        label: "End",
                        dateString: viewModel.ordersEndDate,
                        onDateSelected: { viewModel.updateOrdersEndDate($0) }
                    )
                }
            }

            if !viewModel.orderStatusMap.isEmpty {
                SellerProfileWrappedFilterChips(
                    items: viewModel.orderStatusMap.map { ($0.id, $0.label) },
                    selectedID: viewModel.selectedOrderStatus,
                    onSelect: { viewModel.selectOrderStatus($0) }
                )
            }

            ordersContent
        }
    }

    @ViewBuilder
    private var ordersContent: some View {
        if viewModel.ordersLoading && viewModel.orders.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let error = viewModel.ordersError, viewModel.orders.isEmpty {
            SellerProfileInlineError(message: error) {
                viewModel.loadOrders(isInitial: true)
            }
        } else if viewModel.orders.isEmpty {
            SellerProfileEmptyState(message: "No orders found for the selected filters.")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.orders) { order in
                    SellerProfileOrderCard(order: order)
                        .onAppear {
                            viewModel.loadMoreOrdersIfNeeded(currentOrder: order)
                        }
                }

                if viewModel.ordersLoadingMore {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                        .padding(.vertical, 12)
                }
            }
        }
    }
}

struct SellerProfilePaymentsTab: View {
    @ObservedObject var viewModel: SellerProfileViewModel
    @State private var expandedTransactionIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 12) {
            SellerProfileSearchField(
                text: $viewModel.transactionIdSearch,
                placeholder: "Search by Transaction ID..."
            )

            SellerProfileFilterChipRow(
                presets: SellerProfileDatePreset.paymentsTabPresets + [.custom],
                selectedPreset: viewModel.paymentsDatePreset,
                onSelect: { viewModel.selectPaymentsDatePreset($0) }
            )

            if viewModel.paymentsShowCustomDates || viewModel.paymentsDatePreset == .custom {
                HStack(spacing: 10) {
                    SellerProfileDateField(
                        label: "Start",
                        dateString: viewModel.paymentsStartDate,
                        onDateSelected: { viewModel.updatePaymentsStartDate($0) }
                    )
                    SellerProfileDateField(
                        label: "End",
                        dateString: viewModel.paymentsEndDate,
                        onDateSelected: { viewModel.updatePaymentsEndDate($0) }
                    )
                }
            }

            SellerProfileWrappedFilterChips(
                items: SellerProfileTransactionStatusFilter.allCases.map { ($0.apiKey, $0.title) },
                selectedID: viewModel.selectedTransactionStatus,
                onSelect: { key in
                    if let filter = SellerProfileTransactionStatusFilter.allCases.first(where: { $0.apiKey == key }) {
                        viewModel.selectTransactionStatus(filter)
                    }
                }
            )

            paymentsContent
        }
    }

    @ViewBuilder
    private var paymentsContent: some View {
        if viewModel.paymentsLoading && viewModel.transactions.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let error = viewModel.paymentsError, viewModel.transactions.isEmpty {
            SellerProfileInlineError(message: error) {
                viewModel.loadPayments(isInitial: true)
            }
        } else if viewModel.transactions.isEmpty {
            SellerProfileEmptyState(message: "No transactions found for the selected filters.")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.transactions) { transaction in
                    SellerProfileTransactionCard(
                        transaction: transaction,
                        isExpanded: expandedTransactionIDs.contains(transaction.id),
                        onToggleHistory: {
                            if expandedTransactionIDs.contains(transaction.id) {
                                expandedTransactionIDs.remove(transaction.id)
                            } else {
                                expandedTransactionIDs.insert(transaction.id)
                            }
                        }
                    )
                    .onAppear {
                        viewModel.loadMorePaymentsIfNeeded(currentTransaction: transaction)
                    }
                }

                if viewModel.paymentsLoadingMore {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                        .padding(.vertical, 12)
                }
            }
        }
    }
}

private struct SellerProfileOperationCard<Destination: View>: View {
    let title: String
    let description: String
    let buttonTitle: String
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "2563EB"))
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "111827"))
            }

            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "6B7280"))
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink {
                destination()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 15, weight: .semibold))
                    Text(buttonTitle)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(DashboardTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }
}

struct SellerProfileSearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.primaryBlue)
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.primaryBlue.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SellerProfileFilterChipRow: View {
    let presets: [SellerProfileDatePreset]
    let selectedPreset: SellerProfileDatePreset
    var onSelect: (SellerProfileDatePreset) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presets) { preset in
                    SellerProfileFilterChip(
                        title: preset.title,
                        isSelected: selectedPreset == preset,
                        action: { onSelect(preset) }
                    )
                }
            }
        }
    }
}

private struct SellerProfileWrappedFilterChips: View {
    let items: [(id: String, title: String)]
    let selectedID: String
    var onSelect: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.id) { item in
                SellerProfileFilterChip(
                    title: item.title,
                    isSelected: selectedID == item.id,
                    action: { onSelect(item.id) }
                )
            }
        }
    }
}

private struct SellerProfileFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : DashboardTheme.neutralDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? DashboardTheme.primaryBlue : Color.white)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(DashboardTheme.neutralMedium.opacity(0.2), lineWidth: isSelected ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct SellerProfileOrderCard: View {
    let order: SellerProfileOrderItem

    private var statusColor: Color {
        SellerProfileOrderStatusColor.color(for: order.status)
    }

    var body: some View {
        HStack(spacing: 0) {
            statusColor
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(order.orderId)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Text(SellerProfileDateFormat.displayDate(order.orderDate))
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    Spacer()
                    Text(order.amount.currencyLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                HStack {
                    Text(order.statusText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Spacer()

                    NavigationLink {
                        OrderDetailScreen(orderId: order.detailOrderId)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Details")
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }
}

private struct SellerProfileTransactionCard: View {
    let transaction: SellerProfileTransactionItem
    let isExpanded: Bool
    let onToggleHistory: () -> Void

    private var statusColor: Color {
        SellerProfileTransactionStatusStyle.color(for: transaction.transactionStatus)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Order No: \(transaction.id)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        Text(SellerProfileDateFormat.displayDateShort(transaction.date))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(transaction.totalAmount.currencyLabel)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                        Text("Total Amount")
                            .font(.system(size: 10))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }

                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: SellerProfileTransactionStatusStyle.icon(for: transaction.transactionStatus))
                            .font(.system(size: 12, weight: .semibold))
                        Text(transaction.transactionStatus.uppercased())
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    Spacer()

                    if transaction.isFullySettled {
                        Text("Fully Settled")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DashboardTheme.successGreen)
                    } else {
                        Text("Pending: \(transaction.pendingAmount.currencyLabel)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DashboardTheme.dangerRed)
                    }
                }
            }
            .padding(12)

            if !transaction.history.isEmpty {
                Button(action: onToggleHistory) {
                    HStack(spacing: 6) {
                        Text(isExpanded ? "Hide Settlement History" : "View Settlement History (\(transaction.history.count))")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(DashboardTheme.primaryBlue.opacity(0.06))
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 8) {
                        ForEach(transaction.history) { item in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(DashboardTheme.surfaceVariant)
                                    .frame(width: 42, height: 42)
                                    .overlay {
                                        Image(systemName: "indianrupeesign.circle.fill")
                                            .foregroundStyle(DashboardTheme.neutralMedium)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(SellerProfileDateFormat.displayDate(item.date, format: "dd MMM"))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(DashboardTheme.neutralDark)
                                    Text(item.paymentMode.uppercased())
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(DashboardTheme.neutralMedium)
                                }

                                Spacer()

                                Text(item.settledAmount.currencyLabel)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(DashboardTheme.neutralDark)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
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

private struct SellerProfileEmptyState: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(DashboardTheme.neutralMedium)
            .multilineTextAlignment(.center)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
    }
}

private struct SellerProfileInlineError: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
            Button("Retry", action: onRetry)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryBlue)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

