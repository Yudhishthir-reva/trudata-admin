//
//  AllSourceOrdersScreen.swift
//  Truedata
//

import SwiftUI

struct AllSourceOrdersScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AllSourceOrdersViewModel
    @State private var navigateOrderNo: String?
    @State private var navigateB2COrderId: Int?

    init(initialSource: AllSourceOrderSource = .all) {
        _viewModel = StateObject(wrappedValue: AllSourceOrdersViewModel(initialSource: initialSource))
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "All Source Orders",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.refresh() }
                )

                searchAndFilterRow
                sourceTabs

                if viewModel.isRefreshing {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }

                content
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.ensureLoaded() }
        .sheet(isPresented: $viewModel.showFilterSheet) {
            AllSourceOrdersFilterSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Status breakdown sheet — disabled for now.
        // .sheet(isPresented: $viewModel.showSummaryBreakdown) {
        //     AllSourceOrdersSummaryBreakdownSheet(
        //         filter: viewModel.filter,
        //         summary: viewModel.summary
        //     )
        //     .presentationDetents([.medium, .large])
        //     .presentationDragIndicator(.visible)
        // }
        .background {
            NavigationLink(
                isActive: Binding(
                    get: { navigateOrderNo != nil },
                    set: { if !$0 { navigateOrderNo = nil } }
                )
            ) {
                if let orderNo = navigateOrderNo {
                    OrderDetailScreen(orderId: orderNo)
                }
            } label: { EmptyView() }
            .hidden()

            NavigationLink(
                isActive: Binding(
                    get: { navigateB2COrderId != nil },
                    set: { if !$0 { navigateB2COrderId = nil } }
                )
            ) {
                if let orderId = navigateB2COrderId {
                    B2COrderDetailScreen(orderId: orderId)
                }
            } label: { EmptyView() }
            .hidden()
        }
    }

    private var searchAndFilterRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Order no, seller, staff or mobile", text: Binding(
                    get: { viewModel.searchQuery },
                    set: { viewModel.onSearchQueryChange($0) }
                ))
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            }

            Button {
                viewModel.showFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                        }

                    if viewModel.filter.activeCount > 0 {
                        Text("\(viewModel.filter.activeCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(DashboardTheme.dangerRed)
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var sourceTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AllSourceOrderSource.allCases) { source in
                    let selected = viewModel.filter.source == source
                    Button {
                        viewModel.selectSource(source)
                    } label: {
                        Text(source.tabLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selected ? .white : DashboardTheme.neutralDark)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selected ? source.chipColor : Color.white)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color(hex: "E5E7EB"), lineWidth: selected ? 0 : 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.orders.isEmpty {
            ProgressView("Loading orders...")
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.orders.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                Button("Retry") { viewModel.refresh() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    AllSourceOrdersSummaryCard(
                        filter: viewModel.filter,
                        summary: viewModel.summary,
                        // onOpenBreakdown: { viewModel.showSummaryBreakdown = true },
                        onOpenDates: { viewModel.showFilterSheet = true }
                    )
                    .padding(.horizontal, 16)

                    listHeader
                        .padding(.horizontal, 16)

                    if viewModel.visibleOrders.isEmpty {
                        emptyState
                            .padding(.top, 40)
                    } else {
                        ForEach(viewModel.visibleOrders) { order in
                            Button {
                                openOrder(order)
                            } label: {
                                AllSourceOrderRow(order: order)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentItem: order)
                            }
                        }

                        if viewModel.isLoadingMore {
                            ProgressView()
                                .tint(DashboardTheme.primaryBlue)
                                .padding(.vertical, 12)
                        } else if !viewModel.canLoadMore {
                            Text("You've reached the end")
                                .font(.system(size: 12))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.bottom, 24)
            }
        }
    }

    private var listHeader: some View {
        HStack {
            Text("\(viewModel.totalRecords) orders")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
            Spacer()
            if !viewModel.searchQuery.isEmptyString && !AllSourceOrdersViewModel.serverSearchReady {
                Text("\(viewModel.visibleOrders.count) match")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            } else {
                Text("\(viewModel.orders.count) loaded")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text(viewModel.searchQuery.isEmptyString ? "No orders here" : "No match in loaded orders")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
            if viewModel.filter.activeCount > 0 || !viewModel.searchQuery.isEmptyString {
                Button("Reset filters") {
                    viewModel.onSearchQueryChange("")
                    viewModel.resetFilters()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryBlue)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func openOrder(_ order: AllSourceOrderItem) {
        if order.isB2C {
            navigateB2COrderId = order.orderId
        } else {
            navigateOrderNo = order.orderNo.isEmptyString ? String(order.orderId) : order.orderNo
        }
    }
}

// MARK: - Summary card

private struct AllSourceOrdersSummaryCard: View {
    let filter: AllSourceOrdersFilter
    let summary: [AllSourceOrderStatusSummary]
    // var onOpenBreakdown: () -> Void
    var onOpenDates: () -> Void

    private var metrics: AllSourceOrdersSummaryMetrics {
        AllSourceOrdersSummaryMetrics(summary: summary)
    }

    var body: some View {
        // Button(action: onOpenBreakdown) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(filter.source == .all ? "ORDERS · ALL SOURCES" : "PERIOD TOTAL · ALL SOURCES")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(0.6)
                                .foregroundStyle(.white.opacity(0.75))
                            // Image(systemName: "arrow.up.left.and.arrow.down.right")
                            //     .font(.system(size: 10, weight: .bold))
                            //     .foregroundStyle(.white.opacity(0.7))
                        }
                        HStack(alignment: .bottom, spacing: 8) {
                            Text("\(metrics.totalCount)")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(.white)
                            Text(metrics.grossValue.currencyLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.bottom, 5)
                        }
                    }
                    Spacer()
                    Button(action: onOpenDates) {
                        Text(filter.dateChipLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                AllSourceOrdersStatusBar(summary: summary)

                HStack(spacing: 8) {
                    heroMetric(title: "Delivered", value: metrics.deliveredValue.currencyLabel, color: Color(hex: "86EFAC"))
                    heroMetric(title: "Open", value: metrics.openValue.currencyLabel, color: Color(hex: "FDE68A"))
                    heroMetric(title: "Cancel / Return", value: "\(metrics.cancelledCount)", color: Color(hex: "FCA5A5"))
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "0F172A"), Color(hex: "1E3A5F")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        // }
        // .buttonStyle(.plain)
    }

    private func heroMetric(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct AllSourceOrdersStatusBar: View {
    let summary: [AllSourceOrderStatusSummary]

    private var total: Int {
        max(summary.reduce(0) { $0 + $1.countValue }, 1)
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(summary.filter { $0.countValue > 0 }) { item in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(AllSourceOrderStatusStyle.color(for: item.statusCode))
                        .frame(width: max(geo.size.width * CGFloat(item.countValue) / CGFloat(total), 4))
                }
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }
}

// MARK: - Row

private struct AllSourceOrderRow: View {
    let order: AllSourceOrderItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.orderNo.isEmptyString ? "#\(order.orderId)" : order.orderNo)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(order.orderDate)
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                Spacer()
                Text(order.totalPrice.priceLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            HStack(spacing: 8) {
                sourceChip
                statusChip
                if !order.paymentStatus.isEmptyString {
                    Text(order.paymentStatus)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "F3F4F6"))
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if !order.sellerName.isEmptyString {
                    labeled("Seller", order.sellerName)
                }
                if !order.staffName.isEmptyString {
                    labeled("Staff", order.staffName)
                }
                if SellerContactVisibility.canViewSellerMobile, !order.sellerMobile.isEmptyString {
                    labeled("Mobile", order.sellerMobile)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }

    private var sourceChip: some View {
        Text(order.displaySourceLabel)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(order.source.chipColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(order.source.chipColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusChip: some View {
        Text(order.statusLabel.isEmptyString ? "Status \(order.status)" : order.statusLabel)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AllSourceOrderStatusStyle.color(for: order.status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AllSourceOrderStatusStyle.color(for: order.status).opacity(0.12))
            .clipShape(Capsule())
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(title):")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Summary breakdown sheet

private struct AllSourceOrdersSummaryBreakdownSheet: View {
    let filter: AllSourceOrdersFilter
    let summary: [AllSourceOrderStatusSummary]
    @Environment(\.dismiss) private var dismiss

    private var metrics: AllSourceOrdersSummaryMetrics {
        AllSourceOrdersSummaryMetrics(summary: summary)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if filter.source != .all {
                        Text("These totals cover every source for the date range — not only \(filter.source.filterLabel).")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "92400E"))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "FEF3C7"))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(metrics.totalCount) orders")
                                .font(.system(size: 20, weight: .bold))
                            Text(metrics.grossValue.currencyLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DashboardTheme.primaryBlue)
                        }
                        Spacer()
                        Text(filter.dateChipLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }

                    AllSourceOrdersStatusBar(summary: summary)

                    ForEach(summary) { item in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(AllSourceOrderStatusStyle.color(for: item.statusCode))
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.statusLabel.isEmptyString ? "Status \(item.status)" : item.statusLabel)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(DashboardTheme.neutralDark)
                                Text("\(item.countValue) orders")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DashboardTheme.neutralMedium)
                            }
                            Spacer()
                            Text(item.amountValue.currencyLabel)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(16)
            }
            .background(Color(hex: "F9FAFB"))
            .navigationTitle("Status breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
