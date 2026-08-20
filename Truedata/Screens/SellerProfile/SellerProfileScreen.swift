//
//  SellerProfileScreen.swift
//  Truedata
//

import SwiftUI

struct SellerProfileScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SellerProfileViewModel
    @State private var showOtherDetails = false
    @State private var paymentChartMode: SellerProfilePaymentChartMode = .count
    @State private var actionMessage: String?
    @State private var showActionAlert = false
    @State private var sharePayload: SharePayload?

    private let visibleDatePresets: [SellerProfileDatePreset] = [.thisMonth, .lastMonth, .thisYear]
    private let usesNavigationStack: Bool

    init(sellerId: Int, usesNavigationStack: Bool = true) {
        self.usesNavigationStack = usesNavigationStack
        _viewModel = StateObject(wrappedValue: SellerProfileViewModel(sellerId: sellerId))
    }

    var body: some View {
        if usesNavigationStack {
            NavigationStack {
                profileContent
            }
        } else {
            profileContent
        }
    }

    private var profileContent: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellerProfileAppBar(
                    title: viewModel.screenTitle,
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadProfile(isRefresh: true) }
                )

                if viewModel.isLoading && viewModel.profile == nil {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.profile == nil {
                    errorState(error)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                profileHeader
                                tabBar
                                    .id(SellerProfileScrollAnchor.tabBar)
                                tabContent
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                        }
                        .onChange(of: viewModel.scrollToTabBarToken) { _, _ in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(SellerProfileScrollAnchor.tabBar, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadProfile() }
        .onChange(of: viewModel.selectedTab) { _, tab in
            viewModel.onTabSelected(tab)
        }
        .alert("Payment Flag", isPresented: $viewModel.showColorUpdateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.colorUpdateMessage ?? "")
        }
        .alert("Notice", isPresented: $showActionAlert) {
            Button("OK", role: .cancel) {
                actionMessage = nil
            }
        } message: {
            Text(actionMessage ?? "")
        }
        .sheet(item: $sharePayload) { payload in
            ActivityShareSheet(items: [payload.text])
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Error")
                .font(.system(size: 18, weight: .semibold))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
            Button("Retry") {
                viewModel.loadProfile()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(DashboardTheme.primaryBlue)
            .clipShape(Capsule())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 0) {
            if let profile = viewModel.profile {
                ZStack(alignment: .topTrailing) {
                    Color.clear.frame(height: 8)

                    statusBadge(profile.status)
                        .padding(.trailing, 16)
                        .padding(.top, 12)
                }

                profileAvatar(profile)
                    .padding(.top, -8)

                VStack(spacing: 6) {
                    if let description = profile.colorDescription, !description.isEmptyString {
                        Text(description)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(profile.flagColor ?? DashboardTheme.neutralMedium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((profile.flagColor ?? DashboardTheme.neutralMedium).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    Text(profile.displayShopName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    HStack(spacing: 6) {
                        Text(profile.displayOwnerName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        if let flagColor = profile.flagColor {
                            Circle()
                                .fill(flagColor)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.top, 8)

                paymentFlagRow(selectedColorId: profile.colorId)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .disabled(viewModel.isUpdatingColor)
                    .overlay {
                        if viewModel.isUpdatingColor {
                            ProgressView()
                                .tint(DashboardTheme.primaryBlue)
                        }
                    }

                actionButtonsRow(profile: profile)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider()
                    .overlay(DashboardTheme.surfaceVariant)

                expandableDetailsSection(profile: profile)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func statusBadge(_ status: String) -> some View {
        let isActive = status.lowercased().contains("active")
        return HStack(spacing: 4) {
            Circle()
                .fill(isActive ? DashboardTheme.successGreen : DashboardTheme.neutralMedium)
                .frame(width: 6, height: 6)
            Text(status.isEmptyString ? "Status N/A" : status)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(isActive ? DashboardTheme.successGreen : DashboardTheme.neutralMedium)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isActive ? DashboardTheme.successGreen : DashboardTheme.neutralMedium).opacity(0.12))
        .clipShape(Capsule())
    }

    private func profileAvatar(_ profile: SellerProfileInfo) -> some View {
        Group {
            if profile.profilePic.isEmptyString {
                Circle()
                    .fill(DashboardTheme.surfaceVariant)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
            } else {
                RemoteImage(url: profile.profilePic)
                    .clipShape(Circle())
            }
        }
        .frame(width: 84, height: 84)
        .overlay {
            Circle()
                .stroke(profile.flagColor ?? DashboardTheme.neutralMedium.opacity(0.2), lineWidth: profile.flagColor == nil ? 1 : 2)
        }
    }

    private func paymentFlagRow(selectedColorId: Int?) -> some View {
        HStack(spacing: 12) {
            Text("Payment Flag:")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralMedium)

            ForEach(viewModel.availablePaymentFlags) { colorItem in
                let color = colorItem.displayColor
                let isSelected = selectedColorId == colorItem.id

                Group {
                    if viewModel.canUpdatePaymentFlag {
                        Button {
                            viewModel.updatePaymentFlag(colorId: colorItem.id)
                        } label: {
                            paymentFlagCircle(color: color, isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                    } else {
                        paymentFlagCircle(color: color, isSelected: isSelected)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func paymentFlagCircle(color: Color, isSelected: Bool) -> some View {
        Circle()
            .fill(color)
            .frame(width: isSelected ? 22 : 18, height: isSelected ? 22 : 18)
            .overlay {
                Circle()
                    .stroke(color, lineWidth: isSelected ? 2 : 1)
                    .padding(-3)
                    .opacity(isSelected ? 1 : 0.35)
            }
    }

    private func actionButtonsRow(profile: SellerProfileInfo) -> some View {
        HStack(spacing: 0) {
            actionButton(
                icon: "phone.fill",
                label: "Call",
                isEnabled: SellerContactActions.sanitizedPhoneNumber(profile.mobile) != nil
            ) {
                SellerContactActions.call(profile.mobile) { result in
                    if case .failure(let error) = result {
                        showActionNotice(error.localizedDescription)
                    }
                }
            }

            actionButton(
                icon: "message.fill",
                label: "WhatsApp",
                isEnabled: SellerContactActions.whatsAppNumber(
                    from: profile.whatsappNo.isEmptyString ? profile.mobile : profile.whatsappNo
                ) != nil
            ) {
                let number = profile.whatsappNo.isEmptyString ? profile.mobile : profile.whatsappNo
                SellerContactActions.openWhatsApp(number) { result in
                    if case .failure(let error) = result {
                        showActionNotice(error.localizedDescription)
                    }
                }
            }

            if isValidEmail(profile.email) {
                actionButton(icon: "envelope.fill", label: "Email", isEnabled: true) {
                    SellerContactActions.sendEmail(profile.email, subject: "Inquiry for \(profile.displayShopName)") { result in
                        if case .failure(let error) = result {
                            showActionNotice(error.localizedDescription)
                        }
                    }
                }
            }

            actionButton(icon: "mappin.and.ellipse", label: "Map", isEnabled: hasLocation(profile)) {
                SellerContactActions.openMap(
                    latitude: profile.latitude,
                    longitude: profile.longitude,
                    address: profile.address,
                    label: profile.displayShopName
                ) { result in
                    if case .failure(let error) = result {
                        showActionNotice(error.localizedDescription)
                    }
                }
            }

            if profile.isShareSeller {
                actionButton(icon: "square.and.arrow.up", label: "Share", isEnabled: true) {
                    let text = SellerContactActions.shareText(for: profile)
                    guard !text.isEmptyString else {
                        showActionNotice("Nothing available to share.")
                        return
                    }
                    sharePayload = SharePayload(text: text)
                }
            }
        }
    }

    private func actionButton(
        icon: String,
        label: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(DashboardTheme.primaryBlue.opacity(isEnabled ? 0.12 : 0.06))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isEnabled ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium.opacity(0.5))
                    }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isEnabled ? DashboardTheme.neutralMedium : DashboardTheme.neutralMedium.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmptyString && trimmed.contains("@")
    }

    private func hasLocation(_ profile: SellerProfileInfo) -> Bool {
        if let lat = Double(profile.latitude),
           let lng = Double(profile.longitude),
           lat != 0, lng != 0 {
            return true
        }
        return !profile.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmptyString
    }

    private func showActionNotice(_ message: String) {
        actionMessage = message
        showActionAlert = true
    }

    private func expandableDetailsSection(profile: SellerProfileInfo) -> some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showOtherDetails.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("View Other Details")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    Image(systemName: showOtherDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            if showOtherDetails {
                VStack(spacing: 8) {
                    detailRow(icon: "phone.fill", text: profile.mobile)
                    detailRow(icon: "envelope.fill", text: profile.email.isEmptyString ? "N/A" : profile.email)
                    detailRow(icon: "mappin.and.ellipse", text: profile.address.isEmptyString ? "Address not available" : profile.address)
                    detailRow(icon: "location.fill", text: "Beat: \(profile.beat.isEmptyString ? "Not Available" : profile.beat)")
                }
                .padding(.top, 4)
            }
        }
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.primaryBlue)
                .frame(width: 18)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralDark)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Tabs

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(SellerProfileTab.allCases) { tab in
                    Button {
                        viewModel.selectedTab = tab
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.title)
                                .font(.system(size: 13, weight: viewModel.selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(viewModel.selectedTab == tab ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                                .padding(.horizontal, 12)

                            Rectangle()
                                .fill(viewModel.selectedTab == tab ? DashboardTheme.primaryBlue : Color.clear)
                                .frame(height: 2)
                        }
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .stats:
            statsContent
        case .actions:
            SellerProfileActionsTab(
                sellerId: viewModel.profileSellerId,
                screenTitle: viewModel.screenTitle
            )
        case .orders:
            SellerProfileOrdersTab(viewModel: viewModel)
        case .payments:
            SellerProfilePaymentsTab(viewModel: viewModel)
        }
    }

    // MARK: - Stats

    private var statsContent: some View {
        VStack(spacing: 12) {
            datePresetBar
            summaryCard
            todaysSalesCard
            totalValidOrdersCard
            topSellingCard
            paymentModeCard
        }
    }

    private var datePresetBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleDatePresets) { preset in
                        datePresetChip(preset)
                    }
                    datePresetChip(.custom)
                }
            }

            if viewModel.showCustomDatePickers || viewModel.selectedDatePreset == .custom {
                HStack(spacing: 10) {
                    SellerProfileDateField(
                        label: "Start",
                        dateString: viewModel.startDate,
                        onDateSelected: { viewModel.updateStartDate($0) }
                    )
                    SellerProfileDateField(
                        label: "End",
                        dateString: viewModel.endDate,
                        onDateSelected: { viewModel.updateEndDate($0) }
                    )
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func datePresetChip(_ preset: SellerProfileDatePreset) -> some View {
        Button {
            viewModel.selectDatePreset(preset)
        } label: {
            Text(preset.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(viewModel.selectedDatePreset == preset ? .white : DashboardTheme.neutralDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(viewModel.selectedDatePreset == preset ? DashboardTheme.primaryBlue : Color.white)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(DashboardTheme.neutralMedium.opacity(0.2), lineWidth: viewModel.selectedDatePreset == preset ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var summaryCard: some View {
        DashboardCardChrome(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 16) {
                DashboardBulletTitle(title: viewModel.summaryTitle)

                HStack(alignment: .top, spacing: 8) {
                    DashboardDonutChart(
                        segments: viewModel.orderChartSegments,
                        centerTitle: "\(viewModel.orderChartTotal)",
                        centerSubtitle: "Total Orders",
                        size: 100,
                        lineWidth: 12
                    )
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 8) {
                        DashboardDonutChart(
                            segments: viewModel.amountChartSegments,
                            centerTitle: viewModel.totalOrderAmount.compactCurrencyLabel,
                            centerSubtitle: "Today Order Amount\n(\(viewModel.totalOrderAmount.currencyLabel))",
                            size: 100,
                            lineWidth: 12
                        )

                        orderLegendGrid
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 10) {
                    DashboardOutlinedButton(title: "View History", systemImage: "arrow.right") {
                        viewModel.openOrdersTab()
                    }

                    if viewModel.canCreateOrder {
                        NavigationLink {
                            ChooseBrandScreen(sellerId: viewModel.profileSellerId)
                        } label: {
                            createOrderButtonLabel
                        }
                        .buttonStyle(.plain)
                    } else {
                        createOrderButtonLabel
                            .opacity(0.55)
                    }
                }
            }
        }
    }

    private var createOrderButtonLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
            Text("Create Order")
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(DashboardTheme.primaryBlue)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var orderLegendGrid: some View {
        VStack(spacing: 6) {
            ForEach(viewModel.orderLegendItems) { item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 7, height: 7)
                    Text(item.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(item.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
            }
        }
    }

    private var todaysSalesCard: some View {
        DashboardCardChrome {
            VStack(alignment: .leading, spacing: 10) {
                DashboardSectionHeader(title: "Today's Sales")

                HStack(spacing: 0) {
                    DashboardAmountTile(label: "Total", value: viewModel.totalOrderAmount)
                    dividerLine
                    DashboardAmountTile(label: "Settled", value: viewModel.settledAmount)
                    dividerLine
                    DashboardAmountTile(label: "Pending", value: viewModel.pendingAmount)
                }
                .padding(.vertical, 10)
                .background(DashboardTheme.surfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var totalValidOrdersCard: some View {
        DashboardCardChrome {
            VStack(alignment: .leading, spacing: 10) {
                DashboardSectionHeader(title: "Total Valid Orders")

                Text("\(viewModel.totalValidOrders)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DashboardTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var topSellingCard: some View {
        DashboardCardChrome {
            VStack(alignment: .leading, spacing: 10) {
                DashboardSectionHeader(title: "Top Selling Products")

                if viewModel.topProducts.isEmpty {
                    HStack {
                        Text("No Products")
                            .font(.system(size: 14))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("0 units")
                                .font(.system(size: 12))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                            Text("₹0")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    let maxQuantity = viewModel.topProducts
                        .prefix(5)
                        .compactMap { Int($0.totalQuantity.replacingOccurrences(of: ",", with: "")) }
                        .max() ?? 1

                    ForEach(viewModel.topProducts.prefix(5)) { product in
                        topSellingRow(product: product, maxQuantity: max(maxQuantity, 1))
                    }
                }

                Button {} label: {
                    HStack(spacing: 6) {
                        Text("View More")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    private func topSellingRow(product: SellerProfileTopProduct, maxQuantity: Int) -> some View {
        let quantity = Int(product.totalQuantity.replacingOccurrences(of: ",", with: "")) ?? 0
        let progress = maxQuantity > 0 ? Double(quantity) / Double(maxQuantity) : 0

        return VStack(spacing: 6) {
            HStack(alignment: .top) {
                Text(product.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(quantity) units")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Text(product.totalAmount.parsedAmount.currencyLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DashboardTheme.surfaceVariant)
                    Capsule()
                        .fill(DashboardTheme.primaryBlue.opacity(0.75))
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }

    private var paymentModeCard: some View {
        DashboardCardChrome(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    DashboardBulletTitle(title: "Payment Mode Summary")
                    Spacer()
                    Text(viewModel.paymentChartTotalLabel(mode: paymentChartMode))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }

                paymentModeToggle

                HStack(alignment: .top, spacing: 16) {
                    DashboardDonutChart(
                        segments: viewModel.paymentChartSegments(mode: paymentChartMode),
                        centerTitle: viewModel.paymentChartTotalLabel(mode: paymentChartMode),
                        centerSubtitle: nil,
                        size: 110,
                        lineWidth: 14
                    )

                    VStack(spacing: 10) {
                        ForEach(viewModel.paymentLegendRows(mode: paymentChartMode)) { row in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(row.color)
                                    .frame(width: 8, height: 8)
                                Text(row.title)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DashboardTheme.neutralDark)
                                Spacer()
                                Text("\(row.primaryValue) | \(row.percentage)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(DashboardTheme.neutralDark)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var paymentModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(SellerProfilePaymentChartMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        paymentChartMode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(paymentChartMode == mode ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(paymentChartMode == mode ? DashboardTheme.primaryBlue.opacity(0.12) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(DashboardTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(DashboardTheme.neutralMedium.opacity(0.2))
            .frame(width: 1, height: 36)
    }

    private func placeholderCard(title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions
}

private enum SellerProfileScrollAnchor: String {
    case tabBar
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let text: String
}

private struct SellerProfileAppBar: View {
    var title: String
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

struct SellerProfileDateField: View {
    let label: String
    let dateString: String
    var onDateSelected: (String) -> Void

    @State private var showPicker = false

    private var displayDate: Date {
        SellerProfileDateFormat.apiFormatter.date(from: dateString) ?? Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralMedium)

            Button {
                showPicker = true
            } label: {
                HStack {
                    Text(dateString)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { displayDate },
                        set: { newDate in
                            onDateSelected(SellerProfileDateFormat.apiFormatter.string(from: newDate))
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle(label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showPicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    NavigationStack {
        SellerProfileScreen(sellerId: 1)
    }
}
