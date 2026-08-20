//
//  SalesmanActivityDetailScreen.swift
//  Truedata
//

import SwiftUI

struct SalesmanActivityDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SalesmanActivityDetailViewModel

    init(staffId: String, staffName: String) {
        _viewModel = StateObject(
            wrappedValue: SalesmanActivityDetailViewModel(staffId: staffId, staffName: staffName)
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                detailAppBar
                dateFilterSection
                tabBar
                beatFilterRow
                content
            }

            if viewModel.isLoading && viewModel.allShops.isEmpty {
                ProgressView().tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadActivities() }
    }

    private var detailAppBar: some View {
        HStack(spacing: 8) {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text(viewModel.screenTitle)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button { viewModel.loadActivities(isRefresh: true) } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }

            Button(action: { dismiss() }) {
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

    private var dateFilterSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isDateFilterExpanded.toggle()
                }
            } label: {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                            .foregroundStyle(DashboardTheme.primaryBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.selectedDatePreset.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                            Text(dateRangeLabel)
                                .font(.system(size: 12))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(viewModel.isDateFilterExpanded ? 180 : 0))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if viewModel.isDateFilterExpanded {
                VStack(spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(OrderInsightsDatePreset.allCases.filter { $0 != .custom }, id: \.self) { preset in
                                Button {
                                    viewModel.applyDatePreset(preset)
                                } label: {
                                    Text(preset.rawValue)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(
                                            viewModel.selectedDatePreset == preset ? .white : DashboardTheme.primaryBlue
                                        )
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            viewModel.selectedDatePreset == preset
                                                ? DashboardTheme.primaryBlue
                                                : Color.white
                                        )
                                        .clipShape(Capsule())
                                        .overlay {
                                            Capsule()
                                                .stroke(DashboardTheme.primaryBlue.opacity(0.35), lineWidth: 1)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        DashboardDatePickerField(
                            dateString: viewModel.startDate,
                            onDateSelected: { viewModel.updateStartDate($0) }
                        )
                        DashboardDatePickerField(
                            dateString: viewModel.endDate,
                            onDateSelected: { viewModel.updateEndDate($0) }
                        )
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "F3F4F6"))
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(SalesmanActivityTab.allCases) { tab in
                    Button {
                        viewModel.selectedTab = tab
                    } label: {
                        VStack(spacing: 8) {
                            Text(viewModel.tabTitle(for: tab))
                                .font(.system(size: 14, weight: viewModel.selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(
                                    viewModel.selectedTab == tab
                                        ? DashboardTheme.primaryBlue
                                        : DashboardTheme.neutralMedium
                                )
                                .lineLimit(1)
                            Rectangle()
                                .fill(viewModel.selectedTab == tab ? DashboardTheme.primaryBlue : Color.clear)
                                .frame(height: 3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.white)
    }

    @ViewBuilder
    private var beatFilterRow: some View {
        if !viewModel.availableBeats.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    beatChip(title: "All Beats", isSelected: viewModel.selectedBeat == nil) {
                        viewModel.selectedBeat = nil
                    }
                    ForEach(viewModel.availableBeats, id: \.self) { beat in
                        beatChip(title: beat, isSelected: viewModel.selectedBeat == beat) {
                            viewModel.selectedBeat = beat
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(hex: "F3F4F6"))
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage, viewModel.allShops.isEmpty {
            errorView(error)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    switch viewModel.selectedTab {
                    case .summary:
                        performanceCard
                        assignedShopsCard
                    case .visits:
                        visitsContent
                    case .orders:
                        ordersContent
                    case .noOrders:
                        noOrdersContent
                    case .field:
                        fieldOrdersContent
                    case .phone:
                        phoneOrdersContent
                    }
                }
                .padding(16)
            }
        }
    }

    private var performanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(DashboardTheme.primaryBlue)
                Text("Performance Analytics")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }

            HStack {
                metricItem(
                    value: viewModel.activities.shopsVisited.count,
                    label: "Shop Visits",
                    color: DashboardTheme.primaryBlue
                )
                metricItem(
                    value: viewModel.activities.shopsGivenOrders.count,
                    label: "Orders Secured",
                    color: DashboardTheme.successGreen
                )
            }

            HStack {
                metricItem(
                    value: viewModel.activities.ordersPhysical.count,
                    label: "Field Orders",
                    color: DashboardTheme.secondaryPurple
                )
                metricItem(
                    value: viewModel.activities.ordersTelephonic.count,
                    label: "Phone Orders",
                    color: DashboardTheme.dangerRed
                )
                metricItem(
                    value: viewModel.conversionPercent,
                    label: "Conversion %",
                    color: DashboardTheme.successGreen
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }

    private var assignedShopsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "storefront.fill")
                    .foregroundStyle(DashboardTheme.primaryBlue)
                Text("\(viewModel.assignedShopsTitle) (\(viewModel.filteredAssignedShops.count)/\(viewModel.allShops.count))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search by shop name...", text: $viewModel.shopSearch)
                    .font(.system(size: 14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(hex: "F3F4F6"))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 16) {
                shopFilterRadio(
                    title: "All (\(viewModel.allShops.count))",
                    filter: .all,
                    color: DashboardTheme.primaryBlue
                )
                shopFilterRadio(
                    title: "Placed (\(viewModel.allShops.filter(\.isOrderPlaced).count))",
                    filter: .placed,
                    color: DashboardTheme.successGreen
                )
                shopFilterRadio(
                    title: "Not Placed (\(viewModel.allShops.filter { !$0.isOrderPlaced }.count))",
                    filter: .notPlaced,
                    color: DashboardTheme.dangerRed
                )
            }

            if viewModel.groupedAssignedShops.isEmpty {
                Text("No assigned shops found.")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(viewModel.groupedAssignedShops, id: \.beat) { group in
                    VStack(spacing: 8) {
                        beatHeader(title: group.beat, count: group.shops.count)
                        ForEach(group.shops) { shop in
                            NavigationLink {
                                SellerProfileScreen(
                                    sellerId: Int(shop.sellerId) ?? 0,
                                    usesNavigationStack: false
                                )
                            } label: {
                                assignedShopRow(shop: shop)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var visitsContent: some View {
        let groups = viewModel.groupedShopsVisited()
        if groups.isEmpty {
            emptyTabMessage("No visits found.")
        } else {
            ForEach(groups, id: \.beat) { group in
                VStack(spacing: 8) {
                    beatHeader(title: group.beat, count: group.shops.count)
                    ForEach(group.shops) { shop in
                        SalesmanVisitShopCard(shop: shop, isProspect: false)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var ordersContent: some View {
        let groups = viewModel.groupedOrders()
        if groups.isEmpty {
            emptyTabMessage("No orders secured.")
        } else {
            ForEach(groups, id: \.beat) { group in
                VStack(spacing: 8) {
                    beatHeader(title: group.beat, count: group.orders.count)
                    ForEach(group.orders) { order in
                        NavigationLink {
                            OrderDetailScreen(orderId: order.orderId)
                        } label: {
                            orderRow(order: order)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var noOrdersContent: some View {
        let groups = viewModel.groupedShopsNotGivenOrders()
        if groups.isEmpty {
            emptyTabMessage("No prospects found.")
        } else {
            ForEach(groups, id: \.beat) { group in
                VStack(spacing: 8) {
                    beatHeader(title: group.beat, count: group.shops.count)
                    ForEach(group.shops) { shop in
                        SalesmanVisitShopCard(shop: shop, isProspect: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var fieldOrdersContent: some View {
        let orders = viewModel.activities.ordersPhysical.filter {
            viewModel.selectedBeat == nil || $0.resolvedBeatName == viewModel.selectedBeat
        }
        if orders.isEmpty {
            emptyTabMessage("No field orders found.")
        } else {
            ForEach(orders) { order in
                NavigationLink {
                    OrderDetailScreen(orderId: order.orderId)
                } label: {
                    physicalOrderRow(order: order)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var phoneOrdersContent: some View {
        let orders = viewModel.activities.ordersTelephonic.filter {
            viewModel.selectedBeat == nil || $0.resolvedBeatName == viewModel.selectedBeat
        }
        if orders.isEmpty {
            emptyTabMessage("No phone orders found.")
        } else {
            ForEach(orders) { order in
                NavigationLink {
                    OrderDetailScreen(orderId: order.orderId)
                } label: {
                    telephonicOrderRow(order: order)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func metricItem(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func beatChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? DashboardTheme.primaryBlue.opacity(0.12) : Color.white)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func beatHeader(title: String, count: Int) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
            Spacer()
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DashboardTheme.primaryBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DashboardTheme.primaryBlue.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DashboardTheme.surfaceVariant.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func assignedShopRow(shop: SalesmanAllShop) -> some View {
        let placed = shop.isOrderPlaced
        let color = placed ? DashboardTheme.successGreen : DashboardTheme.dangerRed
        return HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(shop.displayShopName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)
                Text(shop.name)
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .lineLimit(1)
            }
            Spacer()
            Text(placed ? "Order Placed" : "Order Not Placed")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 1)
        }
    }

    private func orderRow(order: SalesmanOrderInfo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Order #\(order.orderId)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text(order.date)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            Spacer()
            Text(order.totalPrice.priceLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DashboardTheme.successGreen)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }

    private func physicalOrderRow(order: SalesmanPhysicalOrder) -> some View {
        orderDetailRow(
            orderId: order.orderId,
            title: order.shopName.isEmptyString ? order.sellerName : order.shopName,
            subtitle: order.orderDate,
            amount: order.totalPrice
        )
    }

    private func telephonicOrderRow(order: SalesmanTelephonicOrder) -> some View {
        orderDetailRow(
            orderId: order.orderId,
            title: order.shopName.isEmptyString ? order.sellerName : order.shopName,
            subtitle: order.orderDate,
            amount: order.totalPrice
        )
    }

    private func orderDetailRow(orderId: String, title: String, subtitle: String, amount: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)
                Text("Order #\(orderId) • \(subtitle)")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .lineLimit(1)
            }
            Spacer()
            Text(amount.priceLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DashboardTheme.successGreen)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }

    private func shopFilterRadio(title: String, filter: SalesmanShopOrderFilter, color: Color) -> some View {
        Button {
            viewModel.shopOrderFilter = filter
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.shopOrderFilter == filter ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(color)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 12, weight: viewModel.shopOrderFilter == filter ? .semibold : .regular))
                    .foregroundStyle(viewModel.shopOrderFilter == filter ? color : DashboardTheme.neutralMedium)
            }
        }
        .buttonStyle(.plain)
    }

    private func emptyTabMessage(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14))
            .foregroundStyle(DashboardTheme.neutralMedium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Text(error)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") { viewModel.loadActivities(isRefresh: true) }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(DashboardTheme.primaryBlue)
                .clipShape(Capsule())
            Spacer()
        }
    }

    private var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let start = OrderInsightsDateFormat.parse(viewModel.startDate),
              let end = OrderInsightsDateFormat.parse(viewModel.endDate) else {
            return "\(viewModel.startDate) - \(viewModel.endDate)"
        }

        if Calendar.current.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        }
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Visit Shop Card

private struct SalesmanVisitShopCard: View {
    let shop: SalesmanShopInfo
    let isProspect: Bool

    @State private var showFullImage = false
    @State private var mapErrorMessage: String?

    private var accentColor: Color {
        isProspect ? DashboardTheme.warningYellow : DashboardTheme.primaryBlue
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    if isProspect {
                        Text("NOT GIVEN ORDER")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DashboardTheme.warningYellow)
                    }

                    labeledValue(title: shop.displayShopName, label: "Shop Name")
                    labeledValue(title: shop.name, label: "Seller Name")
                    labeledValue(title: shop.displayVisitDateTime, label: "Shop Visit Date/Time")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)

            if shop.hasExtraInfo {
                Divider().padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 10) {
                    if let address = shop.shopAddress, !address.isEmptyString {
                        detailRow(icon: "mappin.and.ellipse", label: "Address", value: address)
                    }

                    if let nextVisit = shop.nextVisitDate, !nextVisit.isEmptyString {
                        detailRow(icon: "calendar", label: "Next Visit", value: nextVisit)
                    }

                    if let remark = shop.remark, !remark.isEmptyString {
                        detailRow(icon: "note.text", label: "Remark", value: remark)
                    }

                    if shop.hasMapCoordinates, let lat = shop.lat, let lng = shop.lng {
                        HStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 14))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                            Button("View on Map") {
                                SellerContactActions.openMap(
                                    latitude: lat,
                                    longitude: lng,
                                    address: shop.shopAddress ?? "",
                                    label: shop.displayShopName
                                ) { result in
                                    if case .failure(let error) = result {
                                        mapErrorMessage = error.localizedDescription
                                    }
                                }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(DashboardTheme.primaryBlue.opacity(0.5), lineWidth: 1)
                            }
                        }
                    }

                    if let imageURL = shop.image, !imageURL.isEmptyString {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Shop Image")
                                .font(.system(size: 10))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                            Button { showFullImage = true } label: {
                                RemoteImage(url: imageURL, contentMode: .fill)
                                    .frame(height: 120)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }

            Divider()

            HStack {
                Spacer()
                NavigationLink {
                    SellerProfileScreen(
                        sellerId: Int(shop.sellerId) ?? 0,
                        usesNavigationStack: false
                    )
                } label: {
                    Text("Seller Profile")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
        .sheet(isPresented: $showFullImage) {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if let imageURL = shop.image {
                        RemoteImage(url: imageURL, contentMode: .fit)
                            .padding()
                    }
                }
                .navigationTitle("Shop Image")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { showFullImage = false }
                    }
                }
            }
        }
        .alert("Unable to open map", isPresented: mapErrorBinding) {
            Button("OK") { mapErrorMessage = nil }
        } message: {
            Text(mapErrorMessage ?? "")
        }
    }

    private var mapErrorBinding: Binding<Bool> {
        Binding(get: { mapErrorMessage != nil }, set: { if !$0 { mapErrorMessage = nil } })
    }

    private func labeledValue(title: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(2)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(width: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
