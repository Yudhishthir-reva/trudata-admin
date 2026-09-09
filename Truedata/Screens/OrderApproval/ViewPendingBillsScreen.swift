//
//  ViewPendingBillsScreen.swift
//  Truedata
//

import SwiftUI

struct ViewPendingBillsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ViewPendingBillsViewModel
    @State private var selectedBill: PendingPaymentBill?

    init(sellerId: Int, staffId: Int, sellerName: String) {
        _viewModel = StateObject(
            wrappedValue: ViewPendingBillsViewModel(
                sellerId: sellerId,
                staffId: staffId,
                sellerName: sellerName
            )
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                ViewPendingBillsAppBar(
                    title: viewModel.screenTitle,
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadBills(isRefresh: true) }
                )

                if !viewModel.statusTabs.filter({ $0.count > 0 }).isEmpty {
                    paymentStatusTabs
                }

                content
            }

            if viewModel.isLoading && viewModel.bills.isEmpty {
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadBills(isRefresh: true) }
        .sheet(item: $selectedBill) { bill in
            PendingBillDetailsSheet(
                bill: bill,
                paymentModes: viewModel.paymentModeMap,
                paymentStatuses: viewModel.paymentStatusMap,
                orderStatuses: viewModel.orderStatusMap
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var paymentStatusTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(viewModel.statusTabs.enumerated()), id: \.element.id) { index, tab in
                    Button {
                        viewModel.selectedTabIndex = index
                    } label: {
                        HStack(spacing: 6) {
                            Text(tab.label)
                                .font(.system(size: 14, weight: viewModel.selectedTabIndex == index ? .bold : .medium))
                            Text("\(tab.count)")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    (viewModel.selectedTabIndex == index
                                     ? DashboardTheme.primaryBlue
                                     : DashboardTheme.neutralMedium).opacity(0.12)
                                )
                                .clipShape(Capsule())
                        }
                        .foregroundStyle(
                            viewModel.selectedTabIndex == index
                            ? DashboardTheme.primaryBlue
                            : DashboardTheme.neutralMedium
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if viewModel.selectedTabIndex == index {
                                Rectangle()
                                    .fill(DashboardTheme.primaryBlue)
                                    .frame(height: 3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .background(Color.white)
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage, viewModel.bills.isEmpty {
            VStack(spacing: 14) {
                Spacer()
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.errorRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                DashboardCompactButton(title: "Retry") {
                    viewModel.loadBills(isRefresh: true)
                }
                Spacer()
            }
        } else if viewModel.bills.isEmpty && !viewModel.isLoading {
            VStack {
                Spacer()
                Text("No bills found.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
            }
        } else if viewModel.filteredBills.isEmpty && !viewModel.isLoading {
            VStack {
                Spacer()
                Text("No bills in this status.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredBills) { bill in
                        PendingPaymentBillCard(
                            bill: bill,
                            onViewDetails: {
                                selectedBill = bill
                            }
                        )
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentBill: bill)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(DashboardTheme.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(12)
            }
            .refreshable {
                viewModel.loadBills(isRefresh: true)
            }
        }
    }
}

// MARK: - App Bar

private struct ViewPendingBillsAppBar: View {
    let title: String
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

            Text(title)
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

// MARK: - Bill Card

private struct PendingPaymentBillCard: View {
    let bill: PendingPaymentBill
    var onViewDetails: () -> Void

    private var paymentStatus: BillPaymentStatus { BillPaymentStatus(key: bill.paymentStatus) }
    private var paymentMode: BillPaymentMode { BillPaymentMode(key: bill.paymentMode) }
    private var orderStatus: BillOrderStatus { BillOrderStatus(key: bill.orderStatus) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bill.displayOrderId)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(1)
                    Text(bill.sellerName)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    statusChip(
                        text: "Payment Status: \(paymentStatus.label)",
                        color: paymentStatus.color
                    )

                    if orderStatus != .unknown {
                        statusChip(
                            text: "Order Status: \(orderStatus.label)",
                            color: DashboardTheme.neutralMedium
                        )
                    }

                    Text(bill.remainingAmount.priceLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(bill.remainingValue > 0 ? DashboardTheme.dangerRed : DashboardTheme.successGreen)
                    Text("Remaining")
                        .font(.system(size: 10))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
            }

            HStack(spacing: 12) {
                compactInfo(icon: "calendar", label: "Date", value: bill.orderDate)
                compactInfo(icon: "wallet.pass", label: "Mode", value: paymentMode.label)
            }

            HStack(spacing: 12) {
                compactInfo(icon: "storefront", label: "Shop", value: bill.sellerName)
                compactInfo(icon: "person", label: "Sale Person", value: bill.staffName)
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: onViewDetails) {
                    Text("View Details")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(DashboardTheme.primaryBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                if !bill.orderId.isEmptyString {
                    NavigationLink {
                        OrderDetailScreen(orderId: bill.orderId)
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationBarBackButtonHidden(true)
                    } label: {
                        Text("View Order")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DashboardTheme.successGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(DashboardTheme.successGreen.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: DashboardTheme.primaryBlue.opacity(0.05), radius: 8, y: 2)
    }

    private func statusChip(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func compactInfo(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bill Details Sheet

private struct PendingBillDetailsSheet: View {
    let bill: PendingPaymentBill
    let paymentModes: [PaymentLookupItem]
    let paymentStatuses: [PaymentLookupItem]
    let orderStatuses: [PaymentLookupItem]

    @Environment(\.dismiss) private var dismiss

    private var paymentStatus: BillPaymentStatus { BillPaymentStatus(key: bill.paymentStatus) }
    private var paymentMode: BillPaymentMode { BillPaymentMode(key: bill.paymentMode) }
    private var orderStatus: BillOrderStatus { BillOrderStatus(key: bill.orderStatus) }

    private var orderIdText: String {
        let raw = bill.displayOrderId
        return raw.hasPrefix("#") ? raw : "#\(raw)"
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Divider().overlay(Color(hex: "E5E7EB"))

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    sectionBlock(title: "General Information") {
                        detailRow(label: "Order ID", value: orderIdText)
                        detailRow(label: "Order Date", value: bill.orderDate.ifEmpty(default: "N/A"))
                        detailRow(label: "Seller", value: bill.sellerName.ifEmpty(default: "N/A"))
                        detailRow(label: "Sale Person", value: bill.staffName.ifEmpty(default: "N/A"))
                        detailRow(label: "Order Status", value: orderStatus.label)
                    }

                    sectionBlock(title: "Payment Details") {
                        detailRow(label: "Payment Mode", value: paymentMode.label)
                        HStack(alignment: .center) {
                            Text("Status")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(hex: "6B7280"))
                            Spacer(minLength: 12)
                            paymentStatusBadge
                        }
                    }

                    if !bill.history.isEmpty {
                        sectionBlock(title: "Payment History") {
                            ForEach(bill.history) { item in
                                historyRow(item)
                            }
                        }
                    }

                    amountsSummary
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
        .background(Color.white)
    }

    private var sheetHeader: some View {
        HStack {
            Text("Bill Details")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "4B5563"))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "F3F4F6"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private func sectionBlock<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))
            content()
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "6B7280"))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "111827"))
                .multilineTextAlignment(.trailing)
        }
    }

    private var paymentStatusBadge: some View {
        Text(paymentStatus.label)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(paymentStatus.detailBadgeForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(paymentStatus.detailBadgeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var amountsSummary: some View {
        HStack(spacing: 0) {
            amountColumn(title: "Total Bill", value: bill.amount.priceLabel)
            Rectangle()
                .fill(Color(hex: "D1D5DB"))
                .frame(width: 1, height: 44)
            amountColumn(title: "Amount Due", value: bill.remainingAmount.priceLabel)
        }
        .padding(.vertical, 16)
        .background(Color(hex: "F3F4F6"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func amountColumn(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "6B7280"))
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))
        }
        .frame(maxWidth: .infinity)
    }

    private func historyRow(_ item: PendingPaymentBillHistory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(item.serialNumber)")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text(item.payAmount.priceLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
            Text(item.date)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
            if let mode = item.paymentMode, !mode.isEmptyString {
                Text("Mode: \(BillPaymentMode(key: mode).label)")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
            if !item.staff.isEmptyString {
                Text("Staff: \(item.staff)")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashboardTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension BillPaymentStatus {
    var detailBadgeForeground: Color {
        switch self {
        case .pending: return Color(hex: "DC2626")
        case .remaining: return Color(hex: "2563EB")
        case .complete: return Color(hex: "059669")
        case .unknown: return DashboardTheme.neutralMedium
        }
    }

    var detailBadgeBackground: Color {
        switch self {
        case .pending: return Color(hex: "FEE2E2")
        case .remaining: return Color(hex: "DBEAFE")
        case .complete: return Color(hex: "D1FAE5")
        case .unknown: return Color(hex: "F3F4F6")
        }
    }
}

private extension String {
    func ifEmpty(default defaultValue: String) -> String {
        isEmptyString ? defaultValue : self
    }
}

#Preview {
    NavigationStack {
        ViewPendingBillsScreen(sellerId: 1, staffId: 2, sellerName: "Test Shop")
    }
}
