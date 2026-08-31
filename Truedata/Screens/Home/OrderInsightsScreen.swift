//
//  OrderInsightsScreen.swift
//  Truedata
//

import SwiftUI

struct OrderInsightsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OrderInsightsViewModel
    @State private var showFilterSheet = false
    @State private var navigatedOrderNo: String? = nil
    @State private var selectedSellerProfileId: Int? = nil
    @State private var showLastUsedFilterPrompt = true

    init(
        startDate: String? = nil,
        endDate: String? = nil,
        datePreset: OrderInsightsDatePreset? = nil,
        orderStatus: String? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: OrderInsightsViewModel(
                startDate: startDate,
                endDate: endDate,
                datePreset: datePreset,
                orderStatus: orderStatus
            )
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                OrderInsightsAppBar(
                    title: viewModel.screenTitle,
                    isInSelectionMode: viewModel.isInSelectionMode,
                    selectionCount: viewModel.selectedOrderIds.count,
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadOrders(isRefresh: true) },
                    onCancelSelection: { viewModel.exitSelectionMode() }
                )

                searchAndFilterBar
                switchHistoryButton
                viewModeTabs
                recordsHeader
                mainContent
            }

            if viewModel.isLoading && viewModel.orders.isEmpty && viewModel.viewMode == .list {
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }

            if showLastUsedFilterPrompt && viewModel.orders.isEmpty && !viewModel.isLoading {
                VStack {
                    Spacer()
                    lastUsedFilterPopup
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut, value: showLastUsedFilterPrompt)
            }

            if viewModel.isInSelectionMode && !viewModel.selectedOrderIds.isEmpty {
                VStack {
                    Spacer()
                    Button {
                        viewModel.generateBulkInvoice()
                    } label: {
                        HStack(spacing: 8) {
                            if viewModel.isExporting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "doc.text.fill")
                            }
                            Text("Generate Bulk Invoice (\(viewModel.selectedOrderIds.count))")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(DashboardTheme.primaryBlue)
                        .clipShape(Capsule())
                        .shadow(color: DashboardTheme.primaryBlue.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                    .disabled(viewModel.isExporting)
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.initialize() }
        .sheet(isPresented: $showFilterSheet) {
            OrderInsightsFilterSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.exportShareURL != nil },
            set: { isPresented in
                if !isPresented { viewModel.exportShareURL = nil }
            }
        )) {
            if let url = viewModel.exportShareURL {
                ActivityShareSheet(items: [url])
            }
        }
        .alert(isPresented: Binding(
            get: { viewModel.exportAlertMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.exportAlertMessage = nil }
            }
        )) {
            Alert(
                title: Text("Export Bulk Invoice"),
                message: Text(viewModel.exportAlertMessage ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationDestination(isPresented: Binding(
            get: { navigatedOrderNo != nil },
            set: { isPresented in
                if !isPresented { navigatedOrderNo = nil }
            }
        )) {
            if let orderNo = navigatedOrderNo {
                OrderDetailScreen(orderId: orderNo)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedSellerProfileId != nil },
            set: { isPresented in
                if !isPresented { selectedSellerProfileId = nil }
            }
        )) {
            if let sellerId = selectedSellerProfileId {
                SellerProfileScreen(sellerId: sellerId)
            }
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

                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
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
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(DashboardTheme.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if viewModel.isFilterActive {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: -4, y: 4)
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

    private var switchHistoryButton: some View {
        HStack {
            Spacer()
            Button(action: { viewModel.toggleCreatedOrderHistory() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                    Text(viewModel.switchHistoryTitle)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(viewModel.isCreatedOrderHistory ? Color(hex: "673AB7") : DashboardTheme.primaryBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    (viewModel.isCreatedOrderHistory ? Color(hex: "673AB7") : DashboardTheme.primaryBlue)
                        .opacity(0.12)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color(hex: "F3F4F6"))
    }

    private var viewModeTabs: some View {
        HStack(spacing: 0) {
            ForEach(OrderInsightsViewMode.allCases, id: \.self) { mode in
                Button {
                    viewModel.viewMode = mode
                } label: {
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

    private var recordsHeader: some View {
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

    @ViewBuilder
    private var mainContent: some View {
        switch viewModel.viewMode {
        case .list:
            orderListContent
        case .report:
            reportContent
        }
    }

    @ViewBuilder
    private var orderListContent: some View {
        if let error = viewModel.errorMessage, viewModel.orders.isEmpty {
            errorView(error)
        } else if viewModel.orders.isEmpty && !viewModel.isLoading {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.orders) { order in
                        OrderInsightsOrderCard(
                            order: order,
                            isInSelectionMode: viewModel.isInSelectionMode,
                            isSelected: viewModel.isOrderSelected(orderId: order.id),
                            onViewDetails: { orderNo in
                                navigatedOrderNo = orderNo
                            },
                            onSellerProfile: { sellerId in
                                selectedSellerProfileId = sellerId
                            }
                        )
                        .onTapGesture {
                            if viewModel.isInSelectionMode {
                                viewModel.toggleOrderSelection(orderId: order.id)
                            } else {
                                navigatedOrderNo = order.orderNo
                            }
                        }
                        .onLongPressGesture {
                            if !viewModel.isInSelectionMode {
                                viewModel.toggleSelectionMode()
                                viewModel.toggleOrderSelection(orderId: order.id)
                            }
                        }
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
                .padding(.bottom, viewModel.isInSelectionMode && !viewModel.selectedOrderIds.isEmpty ? 90 : 16)
            }
        }
    }

    private var reportContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                OrderInsightsReportOverviewCard(viewModel: viewModel)

                HStack(spacing: 12) {
                    if !viewModel.topSellerName.isEmptyString {
                        OrderInsightsStatCard(
                            title: "Top Seller",
                            value: viewModel.topSellerName,
                            subValue: viewModel.topSellerAmount.currencyLabel,
                            color: DashboardTheme.primaryBlue
                        )
                    }
                    if !viewModel.topStaffName.isEmptyString {
                        OrderInsightsStatCard(
                            title: "Top Staff",
                            value: viewModel.topStaffName,
                            subValue: viewModel.topStaffAmount.currencyLabel,
                            color: DashboardTheme.secondaryPurple
                        )
                    }
                }
            }
            .padding(16)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Text(error)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.errorRed)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            DashboardCompactButton(title: "Retry") {
                viewModel.loadOrders(isRefresh: true)
            }
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()

            SadMagnifyingGlassView()
                .padding(.bottom, 8)

            Text("No orders found")
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

    private var lastUsedFilterPopup: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "EFF6FF"))
                        .frame(width: 38, height: 38)

                    Image(systemName: "slider.horizontal.3")
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

            Text(viewModel.lastUsedFilterLabel)
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
                        .foregroundStyle(.white)
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
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: -4)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - App Bar

private struct OrderInsightsAppBar: View {
    let title: String
    var isInSelectionMode: Bool = false
    var selectionCount: Int = 0
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: () -> Void
    var onCancelSelection: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            if isInSelectionMode {
                Button(action: { onCancelSelection?() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }

                Text("\(selectionCount) order\(selectionCount != 1 ? "s" : "") selected")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            } else {
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
            }

            Spacer(minLength: 0)

            if !isInSelectionMode {
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
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
    }
}

// MARK: - Order Card

private struct OrderInsightsOrderCard: View {
    let order: OrderInsightsOrder
    var isInSelectionMode: Bool = false
    var isSelected: Bool = false
    var onViewDetails: (String) -> Void
    var onSellerProfile: (Int) -> Void

    private var statusStyle: OrderInsightsStatusStyle {
        OrderInsightsStatusStyle.from(status: order.status)
    }

    private var borderColor: Color {
        if isInSelectionMode && isSelected { return DashboardTheme.primaryBlue }
        return Color(hex: "EF4444")
    }

    var body: some View {
        HStack(spacing: 0) {
            if isInSelectionMode {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                    .padding(.leading, 12)
            }

            VStack(alignment: .leading, spacing: 10) {
                // Header Row: Order Number & Price
                HStack(alignment: .firstTextBaseline) {
                    Text(order.displayOrderNo)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "111827"))

                    Spacer(minLength: 8)

                    Text(order.totalAmount.priceLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                // Date Row
                if !order.displayOrderDate.isEmptyString {
                    Text(order.displayOrderDate)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "6B7280"))
                }

                // Badges Row
                HStack(spacing: 8) {
                    // Status Badge
                    Text(statusStyle.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusStyle.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusStyle.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    // Source Badge
                    HStack(spacing: 4) {
                        Image(systemName: order.orderSourceIcon)
                            .font(.system(size: 10))
                        Text(order.orderSourceDisplay)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "059669"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "E6F8F3"))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    // Special Note Badge
                    if order.containsSpecialNote {
                        Text("Contains Special Note")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(hex: "DC2626"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "FEF2F2"))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color(hex: "DC2626"), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    // Rescheduled Badge
                    if order.orderNotDelivered {
                        Text("Rescheduled")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DashboardTheme.warningYellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DashboardTheme.warningYellow.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    Spacer(minLength: 0)
                }

                // 2-Column Info Grid
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        gridItem(icon: "info.circle", label: "Seller", value: order.sellerName)
                        gridItem(icon: "mappin.and.ellipse", label: "Beat", value: order.beatName.isEmptyString ? "-" : order.beatName)
                        gridItem(icon: "person", label: "Rider", value: order.displayRiderName)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        gridItem(icon: "phone", label: "Mobile", value: order.sellerPhone.isEmptyString ? "-" : order.sellerPhone)
                        gridItem(icon: "person.crop.circle", label: "Staff", value: order.staffName.isEmptyString ? "-" : order.staffName)
                        gridItem(icon: "arrow.triangle.2.circlepath", label: "Delivered", value: order.deliveryDateTime.isEmptyString ? "Not Delivered Yet" : order.deliveryDateTime)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 2)

                // Action Buttons
                if !isInSelectionMode {
                    HStack(spacing: 8) {
                        Spacer()

                        if order.sellerId > 0 {
                            Button {
                                onSellerProfile(order.sellerId)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "storefront.fill")
                                        .font(.system(size: 11))
                                    Text("Seller Profile")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(Color(hex: "1F2937"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .overlay {
                                    Capsule()
                                        .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                                }
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            onViewDetails(order.orderNo)
                        } label: {
                            Text("View Details")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DashboardTheme.primaryBlue)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.white)
                                .overlay {
                                    Capsule()
                                        .stroke(DashboardTheme.primaryBlue.opacity(0.6), lineWidth: 1)
                                }
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1.5)
        }
    }

    private func gridItem(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "6B7280"))
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "6B7280"))
            }
            Text(value.isEmptyString ? "-" : value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "1F2937"))
                .lineLimit(2)
        }
    }
}

// MARK: - Report Cards

private struct OrderInsightsReportOverviewCard: View {
    @ObservedObject var viewModel: OrderInsightsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DashboardTheme.primaryBlue, DashboardTheme.secondaryPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 8, height: 8)
                Text("Order Overview")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }

            VStack(spacing: 14) {
                HStack {
                    metricColumn(title: "Total Orders", value: "\(viewModel.totalOrders)")
                    Spacer()
                    metricColumn(title: "Total Amount", value: viewModel.totalAmount.currencyLabel, valueColor: DashboardTheme.primaryBlue)
                }

                HStack {
                    metricColumn(title: "Avg. Order Value", value: viewModel.averageOrderValue.currencyLabel)
                    Spacer()
                }

                if !viewModel.summary.filter({ $0.status.lowercased() != "all" }).isEmpty {
                    Divider()
                    ForEach(viewModel.summary.filter { $0.status.lowercased() != "all" }) { item in
                        HStack {
                            Text(item.statusLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(DashboardTheme.neutralDark)
                            Spacer()
                            Text("\(item.count) · \(item.totalAmount.currencyLabel)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DashboardTheme.primaryBlue)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
            }
        }
    }

    private func metricColumn(title: String, value: String, valueColor: Color = DashboardTheme.neutralDark) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(valueColor)
        }
    }
}

private struct OrderInsightsStatCard: View {
    let title: String
    let value: String
    let subValue: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(2)
            Text(subValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        }
    }
}

#Preview {
    NavigationStack {
        OrderInsightsScreen()
    }
}
