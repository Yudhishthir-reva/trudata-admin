//
//  B2COrdersScreen.swift
//  Truedata
//

import SwiftUI

struct B2COrdersScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = B2COrdersViewModel()
    @Environment(\.openURL) private var openURL
    @State private var selectedOrder: B2CCustomerOrderItem?
    @State private var showLastUsedFilterPrompt: Bool = true
    @State private var showFilterSheet: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                appBar
                searchAndFilterBar
                recordsCountBar

                content
            }

            if viewModel.isLoading && viewModel.orders.isEmpty {
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }

            if showLastUsedFilterPrompt && viewModel.filteredOrders.isEmpty && !viewModel.isLoading {
                VStack {
                    Spacer()
                    lastUsedFilterPopup
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut, value: showLastUsedFilterPrompt)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $selectedOrder) { order in
            B2COrderDetailScreen(orderId: order.orderId)
        }
        .sheet(isPresented: $showFilterSheet) {
            B2COrderFiltersSheet(viewModel: viewModel)
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            if viewModel.orders.isEmpty {
                viewModel.loadOrders()
            }
        }
    }

    private var appBar: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("B2C Orders")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                viewModel.loadOrders(isRefresh: true)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }

            Button {
                dismiss()
            } label: {
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

    private var searchAndFilterBar: some View {
        SearchAndFilterBar(
            placeholder: "Search...",
            searchText: $viewModel.searchText,
            isFilterActive: viewModel.hasActiveFilters,
            onFilterTap: { showFilterSheet = true }
        ) {
            Image(systemName: "mic.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: "9CA3AF"))
        }
    }

    private var recordsCountBar: some View {
        HStack {
            Text("\(viewModel.filteredOrders.count) records found")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "1F2937"))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage, viewModel.orders.isEmpty {
            errorView(error)
        } else if viewModel.filteredOrders.isEmpty && !viewModel.isLoading {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredOrders) { order in
                        Button {
                            selectedOrder = order
                        } label: {
                            B2CCustomerOrderCard(order: order) {
                                selectedOrder = order
                            }
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentOrder: order)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(DashboardTheme.primaryBlue)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable {
                viewModel.loadOrders(isRefresh: true)
            }
        }
    }

    private var emptyView: some View {
        AppEmptyState(
            title: "No customer orders here",
            message: "Nothing matches the filters you have selected."
        )
    }

    // MARK: - Last Used Filter Popup (Empty State Quick-Bar)

    private var lastUsedFilterPopup: some View {
        FilterLastUsedPrompt(
            summaryLabel: viewModel.lastUsedFilterSubtitle,
            iconSystemName: "line.3.horizontal.decrease",
            onDismiss: {
                withAnimation { showLastUsedFilterPrompt = false }
            },
            onUseDefault: {
                withAnimation { showLastUsedFilterPrompt = false }
                viewModel.resetToDefaultFilters()
            },
            onApply: {
                withAnimation { showLastUsedFilterPrompt = false }
                viewModel.applyLastUsedFilter()
            }
        )
        .padding(.bottom, 8)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DashboardTheme.dangerRed)
            Text(error)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                viewModel.loadOrders(isRefresh: true)
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(DashboardTheme.primaryBlue)
            .clipShape(Capsule())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Order Filters Bottom Sheet

enum B2CFilterTab: String, CaseIterable {
    case dateRange = "Date Range"
    case orderStatus = "Order Status"
    case payment = "Payment"
}

struct B2COrderFiltersSheet: View {
    @ObservedObject var viewModel: B2COrdersViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: B2CFilterTab = .dateRange
    @State private var tempDateRange: B2CDateRangeFilter
    @State private var tempStatus: B2COrderStatusFilter
    @State private var tempPayment: B2CPaymentModeFilter

    init(viewModel: B2COrdersViewModel) {
        self.viewModel = viewModel
        _tempDateRange = State(initialValue: viewModel.selectedDateRange)
        _tempStatus = State(initialValue: viewModel.selectedStatus)
        _tempPayment = State(initialValue: viewModel.selectedPaymentMode)
    }

    private var categoryItems: [FilterCategoryItem] {
        B2CFilterTab.allCases.map { FilterCategoryItem(id: $0.rawValue, title: $0.rawValue) }
    }

    private var selectedCategoryID: Binding<String> {
        Binding(
            get: { selectedTab.rawValue },
            set: { if let value = B2CFilterTab(rawValue: $0) { selectedTab = value } }
        )
    }

    var body: some View {
        AppFilterSheetChrome(
            title: "Order Filters",
            categories: categoryItems,
            selectedCategoryID: selectedCategoryID,
            resetTitle: "Use Default",
            applyTitle: "Apply Filters",
            usesNavigationChrome: false,
            onReset: {
                tempDateRange = .thisMonth
                tempStatus = .all
                tempPayment = .all
                viewModel.resetToDefaultFilters()
                dismiss()
            },
            onApply: {
                viewModel.applyFilters(
                    dateRange: tempDateRange,
                    status: tempStatus,
                    paymentMode: tempPayment
                )
                dismiss()
            },
            banner: {
                FilterLastUsedBanner(label: viewModel.lastUsedFilterSubtitle) {
                    viewModel.applyLastUsedFilter()
                    dismiss()
                }
            },
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch selectedTab {
                        case .dateRange:
                            dateRangeSection
                        case .orderStatus:
                            orderStatusSection
                        case .payment:
                            paymentSection
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
            }
        )
    }

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            FilterSectionTitle(title: "Date Range")
            ForEach(B2CDateRangeFilter.allCases) { item in
                FilterRadioRow(title: item.rawValue, isSelected: tempDateRange == item) {
                    tempDateRange = item
                }
            }
        }
    }

    private var orderStatusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            FilterSectionTitle(title: "Order Status")
            ForEach(B2COrderStatusFilter.allCases) { item in
                FilterRadioRow(title: item.rawValue, isSelected: tempStatus == item) {
                    tempStatus = item
                }
            }
        }
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            FilterSectionTitle(title: "Payment Mode")
            ForEach(B2CPaymentModeFilter.allCases) { item in
                FilterRadioRow(title: item.rawValue, isSelected: tempPayment == item) {
                    tempPayment = item
                }
            }
            Text("Prepaid orders whose payment is pending or failed are excluded by the server.")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "6B7280"))
                .lineSpacing(3)
                .padding(.top, 8)
        }
    }
}

// MARK: - Order Card

private struct B2CCustomerOrderCard: View {
    let order: B2CCustomerOrderItem
    var onSelect: () -> Void

    private var borderColor: Color {
        switch order.resolvedStatusLabel.lowercased() {
        case "pending":
            return Color(hex: "FDE047") // Yellow border
        case "cancelled", "failed":
            return Color(hex: "FCA5A5") // Red border
        case "delivered", "completed":
            return Color(hex: "86EFAC") // Green border
        default:
            return Color(hex: "93C5FD") // Blue border
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Order No & Total Amount
            HStack(alignment: .center) {
                Text(order.orderNo.isEmptyString ? "#\(order.orderId)" : order.orderNo)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "111827"))

                Spacer()

                Text(order.totalAmount.currencyLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(hex: "1D4ED8"))
            }

            // Row 2: Date and Status Badge
            HStack(spacing: 8) {
                Text(order.displayDate.isEmptyString ? order.orderDate : order.displayDate)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "6B7280"))

                Spacer()

                Text(order.resolvedStatusLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(order.resolvedStatusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(order.resolvedStatusColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Divider()

            // Row 3: Customer
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "9CA3AF"))
                    .frame(width: 14)

                HStack(spacing: 4) {
                    Text("Customer:")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "6B7280"))
                    Text(order.customerName.isEmptyString ? "-" : order.customerName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "111827"))
                }
            }

            // Row 4: Mobile
            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "9CA3AF"))
                    .frame(width: 14)

                HStack(spacing: 4) {
                    Text("Mobile:")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "6B7280"))
                    Text(order.customerMobile.isEmptyString ? "-" : order.customerMobile)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "111827"))
                }
            }

            // Row 5: Address
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "9CA3AF"))
                    .frame(width: 14)
                    .padding(.top, 1)

                HStack(alignment: .top, spacing: 4) {
                    Text("Address:")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "6B7280"))
                    Text(order.customerAddress.isEmptyString ? "-" : order.customerAddress)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "111827"))
                        .lineLimit(1)
                }
            }

            // Row 6: Items & Payment Mode
            HStack(spacing: 8) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "9CA3AF"))
                    .frame(width: 14)

                HStack(spacing: 4) {
                    Text("Items:")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "6B7280"))

                    let itemCountStr = order.itemsCount > 0 ? "\(order.itemsCount) items" : "1 item"
                    let paymentStr = order.paymentLabel.isEmptyString
                        ? (order.paymentType.isEmptyString ? "Paid Online" : order.paymentType)
                        : order.paymentLabel

                    Text("\(itemCountStr) - \(paymentStr)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "111827"))
                }
            }

            // Row 7: View Details button on bottom right
            HStack {
                Spacer()
                Button {
                    onSelect()
                } label: {
                    Text("View Details")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "2563EB"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(hex: "93C5FD"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }
}
