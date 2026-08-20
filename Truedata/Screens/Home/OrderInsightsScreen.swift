//
//  OrderInsightsScreen.swift
//  Truedata
//

import SwiftUI

struct OrderInsightsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OrderInsightsViewModel
    @State private var showFilterSheet = false

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
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadOrders(isRefresh: true) }
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
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.initialize() }
        .sheet(isPresented: $showFilterSheet) {
            OrderInsightsFilterSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    (viewModel.isCreatedOrderHistory ? Color(hex: "673AB7") : DashboardTheme.primaryBlue)
                        .opacity(0.1)
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
                        NavigationLink {
                            OrderDetailScreen(orderId: order.orderNo)
                        } label: {
                            OrderInsightsOrderCard(order: order)
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
                .padding(.bottom, 16)
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
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text("No orders found")
                .font(.system(size: 16, weight: .semibold))
            Text("Try changing filters or date range.")
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Spacer()
        }
    }
}

// MARK: - App Bar

private struct OrderInsightsAppBar: View {
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

// MARK: - Order Card

private struct OrderInsightsOrderCard: View {
    let order: OrderInsightsOrder

    private var statusStyle: OrderInsightsStatusStyle {
        OrderInsightsStatusStyle.from(status: order.status)
    }

    private var borderColor: Color {
        if order.showRedBox { return DashboardTheme.dangerRed }
        return DashboardTheme.successGreen.opacity(0.55)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(order.displayOrderNo)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)

                        Text(order.orderDate)
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralMedium)

                        if order.orderNotDelivered {
                            Text("Rescheduled")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(DashboardTheme.warningYellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DashboardTheme.warningYellow.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(order.totalAmount.priceLabel)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)

                        Text(statusStyle.displayName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(statusStyle.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusStyle.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }

                VStack(spacing: 4) {
                    detailRow(icon: "info.circle", label: "Seller", value: order.sellerName)
                    detailRow(icon: "phone", label: "Mobile", value: order.sellerPhone)
                    detailRow(icon: "mappin.and.ellipse", label: "Beat", value: order.beatName)
                    detailRow(icon: "arrow.triangle.2.circlepath", label: "Delivered At", value: order.deliveryDateTime)
                    HStack(spacing: 12) {
                        detailRow(icon: "person", label: "Staff", value: order.staffName)
                        detailRow(icon: "person", label: "Rider", value: order.displayRiderName)
                    }
                }

                HStack {
                    Spacer()
                    Text("View Details")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .overlay {
                            Capsule()
                                .stroke(DashboardTheme.primaryBlue.opacity(0.5), lineWidth: 1)
                        }
                }
                .padding(.top, 4)
            }
            .padding(12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: order.showRedBox ? 2 : 1.5)
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(width: 14)
            Text("\(label):")
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(value.isEmptyString ? "-" : value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
