//
//  RiderInsightsScreen.swift
//  Truedata
//

import SwiftUI
import MapKit

struct RiderInsightsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RiderInsightsViewModel()

    @State private var selectedOrderId: String?
    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var tempStartDate = Date()
    @State private var tempEndDate = Date()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Rider Insights",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load(isRefresh: true) }
                )

                filterPanel
                tabBar

                contentArea
            }

            if viewModel.isLoading && viewModel.payload == nil {
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load() }
        .navigationDestination(isPresented: Binding(
            get: { selectedOrderId != nil },
            set: { if !$0 { selectedOrderId = nil } }
        )) {
            if let orderId = selectedOrderId {
                OrderDetailScreen(orderId: orderId)
            }
        }
        .sheet(isPresented: $showStartDatePicker) {
            datePickerSheet(title: "Select Start Date", date: $tempStartDate) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                let startStr = formatter.string(from: tempStartDate)
                viewModel.updateCustomDates(start: startStr, end: viewModel.endDate)
            }
            .presentationDetents([.height(340)])
        }
        .sheet(isPresented: $showEndDatePicker) {
            datePickerSheet(title: "Select End Date", date: $tempEndDate) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                let endStr = formatter.string(from: tempEndDate)
                viewModel.updateCustomDates(start: viewModel.startDate, end: endStr)
            }
            .presentationDetents([.height(340)])
        }
    }

    // MARK: - Filter Panel

    private var filterPanel: some View {
        VStack(spacing: 10) {
            // Preset Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RiderDatePreset.allCases) { preset in
                        Button {
                            viewModel.selectPreset(preset)
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(viewModel.selectedPreset == preset ? .white : DashboardTheme.neutralDark)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.selectedPreset == preset
                                        ? DashboardTheme.primaryBlue
                                        : Color(hex: "F3F4F6")
                                )
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Date Pickers Row
            HStack(spacing: 12) {
                Button {
                    tempStartDate = parseDate(viewModel.startDate)
                    showStartDatePicker = true
                } label: {
                    HStack {
                        Text(viewModel.startDate.isEmptyString ? "Start Date" : viewModel.startDate)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    tempEndDate = parseDate(viewModel.endDate)
                    showEndDatePicker = true
                } label: {
                    HStack {
                        Text(viewModel.endDate.isEmptyString ? "End Date" : viewModel.endDate)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(DashboardTheme.neutralMedium)

                TextField("Search by Order ID, Rider, Seller...", text: $viewModel.searchText)
                    .font(.system(size: 14))

                if !viewModel.searchText.isEmptyString {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.primaryBlue.opacity(0.8), lineWidth: 1.2)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color.white)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(RiderViewMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.viewMode = mode
                            if mode != .reports {
                                viewModel.clearSelectedRider()
                            }
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(mode.title)
                                .font(.system(size: 14, weight: viewModel.viewMode == mode ? .bold : .medium))
                                .foregroundStyle(
                                    viewModel.viewMode == mode
                                        ? DashboardTheme.primaryBlue
                                        : DashboardTheme.neutralMedium
                                )
                                .padding(.horizontal, 4)

                            Rectangle()
                                .fill(viewModel.viewMode == mode ? DashboardTheme.primaryBlue : Color.clear)
                                .frame(height: 3)
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Divider().background(Color(hex: "E5E7EB"))
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if let error = viewModel.errorMessage, viewModel.payload == nil {
            errorView(error)
        } else {
            switch viewModel.viewMode {
            case .insights:
                insightsView
            case .reports:
                riderReportView
            case .assigned:
                ordersListView(orders: viewModel.filteredAssignedOrders, emptyMessage: "No assigned orders found.")
            case .pickedUp:
                ordersListView(orders: viewModel.filteredPickedUpOrders, emptyMessage: "No picked up orders found.")
            case .active:
                activeRidersView
            case .delivered:
                ordersListView(orders: viewModel.filteredDeliveredOrders, emptyMessage: "No delivered orders found.")
            }
        }
    }

    // MARK: - Insights View

    private var insightsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 8 KPI Stat Grid (2 rows of 4 cards)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        statCard(
                            icon: "checkmark.circle.fill",
                            value: "\(viewModel.deliveredCount)",
                            label: "Delivered",
                            color: DashboardTheme.successGreen
                        )
                        statCard(
                            icon: "list.clipboard.fill",
                            value: "\(viewModel.assignedCount)",
                            label: "Assigned",
                            color: DashboardTheme.primaryBlue
                        )
                        statCard(
                            icon: "shippingbox.fill",
                            value: "\(viewModel.pickedUpCount)",
                            label: "Picked Up",
                            color: DashboardTheme.warningYellow
                        )
                        statCard(
                            icon: "bicycle",
                            value: "\(viewModel.activeCount)",
                            label: "Active",
                            color: DashboardTheme.infoBlue
                        )
                    }

                    HStack(spacing: 8) {
                        statCard(
                            icon: "scooter",
                            value: "\(viewModel.allOrdersCount)",
                            label: "All Orders",
                            color: Color(hex: "8B5CF6")
                        )
                        statCard(
                            icon: "chart.line.uptrend.xyaxis",
                            value: "\(viewModel.deliveryRatePercentage)%",
                            label: "Delivery %",
                            color: Color(hex: "0D9488")
                        )
                        statCard(
                            icon: "person.2.fill",
                            value: "\(viewModel.totalRidersCount)",
                            label: "Riders",
                            color: Color(hex: "6366F1")
                        )
                        statCard(
                            icon: "person.crop.circle.fill",
                            value: "\(viewModel.topRidersCount)",
                            label: "Top Riders",
                            color: Color(hex: "FD7E14")
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Top Performing Riders Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Top Performing Riders")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .padding(.horizontal, 16)

                    if viewModel.topRiders.isEmpty {
                        emptyState(message: "No top riders in this period.", isCompact: true)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(viewModel.topRiders) { rider in
                                topRiderCard(rider: rider)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.bottom, 24)
        }
        .background(Color(hex: "F9FAFB"))
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(height: 20)

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func topRiderCard(rider: TopRiderItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color(hex: "D4AF37"))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(rider.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text("Top Performer")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(rider.totalDelivered)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DashboardTheme.successGreen)
                Text("Delivered")
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "FDE047").opacity(0.6), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
    }

    // MARK: - Rider Reports View

    @ViewBuilder
    private var riderReportView: some View {
        if let profile = viewModel.selectedRiderProfile {
            riderDetailReport(profile: profile)
        } else {
            riderSelectionList
        }
    }

    private var riderSelectionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Select a Rider to View Report")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                if viewModel.filteredRidersSummary.isEmpty {
                    emptyState(message: viewModel.searchText.isEmptyString ? "No riders found for this period." : "No riders match your search.")
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredRidersSummary) { rider in
                            Button {
                                viewModel.selectRider(rider.riderName)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(DashboardTheme.neutralMedium)

                                    Text(rider.riderName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DashboardTheme.neutralDark)

                                    Spacer()

                                    Text("\(rider.totalOrders) Orders")
                                        .font(.system(size: 13))
                                        .foregroundStyle(DashboardTheme.neutralMedium)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.6))
                                }
                                .padding(14)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 40)
            }
            .padding(.bottom, 24)
        }
        .background(Color(hex: "F9FAFB"))
    }

    private func riderDetailReport(profile: RiderProfileItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header Card with back arrow & Rider Name
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Button {
                            viewModel.clearSelectedRider()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)

                        Text(profile.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)

                        Spacer()
                    }
                    .padding(12)

                    Divider()

                    // 3 KPI stats
                    HStack {
                        riderSummaryStat(label: "Total Orders", value: "\(profile.totalOrders)", color: DashboardTheme.primaryBlue)
                        riderSummaryStat(label: "Delivered", value: "\(profile.deliveredCount)", color: DashboardTheme.successGreen)
                        riderSummaryStat(label: "Total Value", value: profile.formattedTotalAmount, color: Color(hex: "8B5CF6"))
                    }
                    .padding(14)

                    // Last Known Location Row (if available)
                    if let address = profile.lastKnownAddress, !address.isEmptyString {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DashboardTheme.primaryBlue)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Current Location:")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(DashboardTheme.neutralMedium)
                                    Text(address)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(DashboardTheme.neutralDark)
                                }

                                Spacer()
                            }

                            if profile.hasMapLocation {
                                HStack {
                                    Spacer()
                                    Button {
                                        openMap(lat: profile.lastKnownLatitude, lng: profile.lastKnownLongitude, label: profile.name)
                                    } label: {
                                        Text("View on Map")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(DashboardTheme.primaryBlue)
                                    }
                                }
                            }
                        }
                        .padding(14)
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Order History Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Order History (\(profile.orders.count))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .padding(.horizontal, 16)

                    if profile.orders.isEmpty {
                        emptyState(message: "No orders for this rider.", isCompact: true)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(profile.orders) { order in
                                orderCard(order: order)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.bottom, 24)
        }
        .background(Color(hex: "F9FAFB"))
    }

    private func riderSummaryStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Active Riders View

    private var activeRidersView: some View {
        Group {
            if viewModel.filteredActiveOrders.isEmpty {
                emptyState(message: viewModel.searchText.isEmptyString ? "No active orders found." : "No active orders match your search.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.filteredActiveOrders) { order in
                            activeOrderCard(order: order)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .background(Color(hex: "F9FAFB"))
            }
        }
    }

    private func activeOrderCard(order: RiderOrderDisplayItem) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("#\(order.orderId)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    Spacer()
                    Text(order.formattedPrice)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                infoRow(icon: "bicycle", label: "Rider:", value: order.riderName)
                infoRow(icon: "building.2.fill", label: "Seller:", value: order.sellerName)
                infoRow(icon: "arrow.triangle.swap", label: "Distance:", value: "\(order.distance ?? "0") km")
                infoRow(icon: "location.fill", label: "Current Location:", value: order.address ?? "no address")
            }
            .padding(14)

            Divider()

            HStack {
                if order.hasLocationCoordinates {
                    Button {
                        openMap(lat: order.latitude, lng: order.longitude, label: order.riderName)
                    } label: {
                        Text("View on Map")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                } else {
                    Text("No GPS data")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }

                Spacer()

                Button {
                    selectedOrderId = order.orderId
                } label: {
                    Text("View Details")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: "F9FAFB"))
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
    }

    // MARK: - Orders List View (Assigned, Picked Up, Delivered)

    private func ordersListView(orders: [RiderOrderDisplayItem], emptyMessage: String) -> some View {
        Group {
            if orders.isEmpty {
                emptyState(message: viewModel.searchText.isEmptyString ? emptyMessage : "No orders match your search.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(orders) { order in
                            orderCard(order: order)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                }
                .background(Color(hex: "F9FAFB"))
            }
        }
    }

    private func orderCard(order: RiderOrderDisplayItem) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("#\(order.orderId)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(order.orderStatusLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(order.statusBadgeColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(order.statusBadgeColor.opacity(0.12))
                            .clipShape(Capsule())

                        Text(order.formattedPrice)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                }

                infoRow(icon: "bicycle", label: "Rider:", value: order.riderName)
                infoRow(icon: "building.2.fill", label: "Seller:", value: order.sellerName)
                infoRow(icon: "person.fill", label: "Sales Person:", value: order.staffName)
            }
            .padding(14)

            Divider()

            HStack {
                Spacer()
                Button {
                    selectedOrderId = order.orderId
                } label: {
                    Text("View Details")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 1)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(1)

            Spacer()
        }
    }

    // MARK: - Helper Views

    private func emptyState(message: String, isCompact: Bool = false) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: isCompact ? 16 : 40)
            Image(systemName: "info.circle")
                .font(.system(size: isCompact ? 24 : 36))
                .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.6))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer(minLength: isCompact ? 16 : 40)
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
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
                viewModel.load(isRefresh: true)
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

    private func datePickerSheet(title: String, date: Binding<Date>, onSave: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Spacer()
                Button("Done") {
                    onSave()
                    showStartDatePicker = false
                    showEndDatePicker = false
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .padding(16)

            Divider()

            DatePicker("", selection: date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding(16)
        }
    }

    private func parseDate(_ str: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: str) ?? Date()
    }

    private func openMap(lat: String?, lng: String?, label: String) {
        guard let latStr = lat, let lngStr = lng,
              let latitude = Double(latStr), let longitude = Double(lngStr) else { return }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = "Rider: \(label)"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}
