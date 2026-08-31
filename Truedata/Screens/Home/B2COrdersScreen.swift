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
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "9CA3AF"))

                TextField("Search...", text: $viewModel.searchText)
                    .font(.system(size: 14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !viewModel.searchText.isEmptyString {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(hex: "9CA3AF"))
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "9CA3AF"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            }

            Button {
                showFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 42)
                        .background(Color(hex: "2563EB"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(Color(hex: "EF4444"))
                            .frame(width: 8, height: 8)
                            .padding(6)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
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
        VStack(spacing: 14) {
            Spacer()

            SadMagnifyingGlassView()
                .padding(.bottom, 8)

            Text("No customer orders here")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))

            Text("Nothing matches the filters you have selected.")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "6B7280"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Last Used Filter Popup (Empty State Quick-Bar)

    private var lastUsedFilterPopup: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "EFF6FF"))
                        .frame(width: 38, height: 38)

                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: "2563EB"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apply Last Used Filter?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "111827"))

                    Text("Use your previous filter settings")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "6B7280"))
                }

                Spacer()

                Button {
                    withAnimation { showLastUsedFilterPrompt = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "6B7280"))
                        .frame(width: 26, height: 26)
                        .background(Color(hex: "F3F4F6"))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(viewModel.lastUsedStatus.rawValue)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "1E293B"))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(hex: "F1F5F9"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 12) {
                Button {
                    withAnimation { showLastUsedFilterPrompt = false }
                    viewModel.resetToDefaultFilters()
                } label: {
                    Text("Use Default")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "374151"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation { showLastUsedFilterPrompt = false }
                    viewModel.applyLastUsedFilter()
                } label: {
                    Text("Apply Filter")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color(hex: "2563EB"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
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

    var body: some View {
        VStack(spacing: 0) {
            header
            lastUsedFilterBanner
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

            Divider()

            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 6) {
                    ForEach(B2CFilterTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(selectedTab == tab ? .white : Color(hex: "4B5563"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(selectedTab == tab ? Color(hex: "2563EB") : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .frame(width: 124)
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .background(Color(hex: "F8FAFC"))

                Divider()

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

            Divider()
            bottomBar
        }
        .background(Color.white)
    }

    private var header: some View {
        HStack {
            Text("Order Filters")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "4B5563"))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "F3F4F6"))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var lastUsedFilterBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: "2563EB"))

            VStack(alignment: .leading, spacing: 2) {
                Text("Last Used Filter")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "1E40AF"))

                Text(viewModel.lastUsedFilterSubtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "6B7280"))
            }

            Spacer()

            Button {
                viewModel.applyLastUsedFilter()
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("Apply")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: "2563EB"))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: "EFF6FF"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "DBEAFE"), lineWidth: 1)
        )
    }

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DATE RANGE")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "1E40AF"))

            ForEach(B2CDateRangeFilter.allCases) { item in
                Button {
                    tempDateRange = item
                } label: {
                    HStack(spacing: 12) {
                        customRadioButton(isSelected: tempDateRange == item)
                        Text(item.rawValue)
                            .font(.system(size: 14, weight: tempDateRange == item ? .medium : .regular))
                            .foregroundStyle(Color(hex: "1F2937"))
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var orderStatusSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ORDER STATUS")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "1E40AF"))

            ForEach(B2COrderStatusFilter.allCases) { item in
                Button {
                    tempStatus = item
                } label: {
                    HStack(spacing: 12) {
                        customRadioButton(isSelected: tempStatus == item)
                        Text(item.rawValue)
                            .font(.system(size: 14, weight: tempStatus == item ? .medium : .regular))
                            .foregroundStyle(Color(hex: "1F2937"))
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PAYMENT MODE")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "1E40AF"))

            ForEach(B2CPaymentModeFilter.allCases) { item in
                Button {
                    tempPayment = item
                } label: {
                    HStack(spacing: 12) {
                        customRadioButton(isSelected: tempPayment == item)
                        Text(item.rawValue)
                            .font(.system(size: 14, weight: tempPayment == item ? .medium : .regular))
                            .foregroundStyle(Color(hex: "1F2937"))
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }

            Text("Prepaid orders whose payment is pending or failed are excluded by the server.")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "6B7280"))
                .lineSpacing(3)
                .padding(.top, 8)
        }
    }

    private func customRadioButton(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color(hex: "2563EB") : Color(hex: "9CA3AF"), lineWidth: isSelected ? 2 : 1.5)
                .frame(width: 18, height: 18)

            if isSelected {
                Circle()
                    .fill(Color(hex: "2563EB"))
                    .frame(width: 9, height: 9)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                tempDateRange = .thisMonth
                tempStatus = .all
                tempPayment = .all
                viewModel.resetToDefaultFilters()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("Use Default")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color(hex: "2563EB"))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(hex: "2563EB"), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            Button {
                viewModel.applyFilters(
                    dateRange: tempDateRange,
                    status: tempStatus,
                    paymentMode: tempPayment
                )
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("Apply Filters")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(hex: "2563EB"))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(Color.white)
    }
}

// MARK: - Sad Magnifying Glass Illustration

struct SadMagnifyingGlassView: View {
    var body: some View {
        ZStack {
            // Sparkles & bubbles around
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

            // Magnifying Glass
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: "CBD5E1"), lineWidth: 8)
                        .background(Circle().fill(Color(hex: "F8FAFC")))
                        .frame(width: 72, height: 72)

                    // Face
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

                    // Tear Drop
                    Image(systemName: "drop.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "BAE6FD"))
                        .offset(x: 24, y: -10)
                }

                // Handle
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
