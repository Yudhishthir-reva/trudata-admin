//
//  StartNewOrderScreen.swift
//  Truedata
//

import SwiftUI

struct StartNewOrderScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StartNewOrderViewModel()
    @State private var showAddSellerAlert = false
    @State private var showRearrangeSellers = false
    @State private var selectedSellerForOverview: StartNewOrderSeller?
    @State private var selectedSellerForProfile: StartNewOrderSeller?
    @State private var selectedSellerForStatusUpdate: StartNewOrderSeller?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                StartNewOrderAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() }
                )

                ScrollView {
                    LazyVStack(spacing: 12) {
                        beatSelectionCard

                        if viewModel.selectedBeatId != nil || viewModel.isFindingSellers {
                            sellerSelectionSection
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 88)
                }
            }

            addSellerButton
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.initialize() }
        .navigationDestination(isPresented: $showRearrangeSellers) {
            if let beatId = viewModel.selectedBeatId {
                RearrangeSellersScreen(
                    beatId: beatId,
                    sellers: viewModel.sellers,
                    onSaved: { updatedSellers in
                        viewModel.applyReorderedSellers(updatedSellers)
                    }
                )
            }
        }
        .navigationDestination(item: $selectedSellerForProfile) { seller in
            SellerProfileScreen(sellerId: seller.id)
        }
        .navigationDestination(item: $selectedSellerForStatusUpdate) { seller in
            UpdateSellerStatusScreen(
                sellerId: String(seller.id),
                sellerName: seller.displayName
            )
        }
        .sheet(item: $selectedSellerForOverview) { seller in
            StartNewOrderSellerOverviewSheet(
                seller: seller,
                isRequestingAccess: viewModel.isRequestingAccess,
                onClose: { selectedSellerForOverview = nil },
                onRequestAccess: { viewModel.requestAccess(for: seller) },
                onViewBills: {
                    selectedSellerForOverview = nil
                    viewModel.errorMessage = "Pending bills for \(seller.displayName) will open here."
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: viewModel.showApprovalSuccess) { _, didSucceed in
            guard didSucceed else { return }
            selectedSellerForOverview = nil
        }
        .alert("Request sent to Admin", isPresented: $viewModel.showApprovalSuccess) {
            Button("OK") {
                viewModel.resetApprovalSuccess()
            }
        } message: {
            Text("Your request has been sent to the admin for approval. You will be notified once the request is processed.")
        }
        .alert("Add Seller", isPresented: $showAddSellerAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add Seller flow will open here, same as Android.")
        }
        .alert(
            "Notice",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Step 1

    private var beatSelectionCard: some View {
        StartNewOrderStepCard {
            StartNewOrderStepHeader(
                step: 1,
                title: "Select Beat",
                isComplete: viewModel.isBeatCollapsed && viewModel.selectedBeatId != nil
            )

            if viewModel.isBeatCollapsed && viewModel.selectedBeatId != nil {
                collapsedBeatContent
            } else if viewModel.isFindingSellers && viewModel.selectedBeatId != nil && !viewModel.isBeatCollapsed {
                loadingSellersView
            } else {
                expandedBeatContent
            }
        }
    }

    private var collapsedBeatContent: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.selectedBeatName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)

                if !viewModel.selectedLocationSubtitle.isEmptyString {
                    Text(viewModel.selectedLocationSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
            }

            Spacer(minLength: 0)

            Button("Change") {
                viewModel.changeBeatSelection()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(DashboardTheme.primaryBlue)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var loadingSellersView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
            Text("Loading sellers...")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var expandedBeatContent: some View {
        VStack(spacing: 12) {
            locationStepRow
                .padding(.horizontal, 8)

            Divider()
                .padding(.horizontal, 16)

            searchBar
                .padding(.horizontal, 16)

            locationList
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    private var locationStepRow: some View {
        HStack(spacing: 0) {
            locationStepItem(
                label: "State",
                value: viewModel.selectedState?.name,
                isActive: viewModel.selectionStep == .state,
                isEnabled: viewModel.canEditStateAndCity || !viewModel.isStateAndCityPrefilled
            ) {
                viewModel.setSelectionStep(.state)
            }

            stepDivider

            locationStepItem(
                label: "City",
                value: viewModel.selectedCity?.name,
                isActive: viewModel.selectionStep == .city,
                isEnabled: viewModel.selectedState != nil
                    && (viewModel.canEditStateAndCity || !viewModel.isStateAndCityPrefilled)
            ) {
                viewModel.setSelectionStep(.city)
            }

            stepDivider

            locationStepItem(
                label: "Beat",
                value: viewModel.selectedBeat?.name,
                isActive: viewModel.selectionStep == .beat,
                isEnabled: viewModel.selectedCity != nil
            ) {
                viewModel.setSelectionStep(.beat)
            }
        }
    }

    private var stepDivider: some View {
        Rectangle()
            .fill(DashboardTheme.neutralMedium.opacity(0.15))
            .frame(width: 1, height: 44)
    }

    private func locationStepItem(
        label: String,
        value: String?,
        isActive: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isActive && isEnabled ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)

                    Text(label)
                        .font(.system(size: 13, weight: isActive && isEnabled ? .bold : .semibold))
                        .foregroundStyle(isEnabled ? DashboardTheme.neutralDark : DashboardTheme.neutralMedium.opacity(0.6))
                }

                Text(value ?? "Select")
                    .font(.system(size: 12, weight: value == nil ? .regular : .semibold))
                    .foregroundStyle(value == nil ? DashboardTheme.neutralMedium : DashboardTheme.neutralDark)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.primaryBlue.opacity(0.75))

            TextField("Search...", text: Binding(
                get: { viewModel.currentSearchQuery },
                set: { viewModel.updateSearchQuery($0) }
            ))
            .font(.system(size: 14))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !viewModel.currentSearchQuery.isEmptyString {
                Button { viewModel.clearCurrentSearch() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
            }

            Image(systemName: "mic.fill")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var locationList: some View {
        if viewModel.isLoadingAreas {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else {
            switch viewModel.selectionStep {
            case .state:
                locationItems(viewModel.filteredStates, name: \.name) { viewModel.selectState($0) }
            case .city:
                locationItems(viewModel.filteredCities, name: \.name) { viewModel.selectCity($0) }
            case .beat:
                locationItems(viewModel.filteredBeats, name: \.name) { viewModel.selectBeat($0) }
            }
        }
    }

    private func locationItems<T: Identifiable>(
        _ items: [T],
        name: KeyPath<T, String>,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        let visibleItems = Array(items.prefix(viewModel.visibleListLimit))
        let hasMore = items.count > visibleItems.count

        return VStack(spacing: 0) {
            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                Button {
                    onSelect(item)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)

                        Text(item[keyPath: name])
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .rotationEffect(.degrees(90))
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                if index < visibleItems.count - 1 {
                    Divider()
                }
            }

            if hasMore {
                Button(action: { viewModel.showMoreItems() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                        Text("More below")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(DashboardTheme.primaryBlue.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
            }
        }
    }

    // MARK: - Step 2

    private var sellerSelectionSection: some View {
        VStack(spacing: 10) {
            StartNewOrderStepCard {
                StartNewOrderStepHeader(step: 2, title: "Choose a Seller", isComplete: false)

                if viewModel.isFindingSellers {
                    loadingSellersView
                } else if viewModel.sellers.isEmpty {
                    Text("No sellers found for the selected beat. Please try another area.")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 28)
                } else {
                    VStack(spacing: 12) {
                        HStack {
                            Spacer(minLength: 0)
                            Button {
                                showRearrangeSellers = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Rearrange Sellers")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(DashboardTheme.primaryBlue)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)

                        sellerTabs
                            .padding(.horizontal, 8)

                        sellerSearchBar
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
            }

            if !viewModel.isFindingSellers && !viewModel.sellers.isEmpty {
                ForEach(viewModel.filteredSellers) { seller in
                    StartNewOrderSellerCard(
                        seller: seller,
                        onCreateOrder: { viewModel.sellerSelected(seller) },
                        onViewProfile: {
                            selectedSellerForProfile = seller
                        },
                        onRequestAccess: {
                            selectedSellerForOverview = seller
                        },
                        onSellerNotAvailable: {
                            selectedSellerForStatusUpdate = seller
                        }
                    )
                }

                if viewModel.filteredSellers.isEmpty {
                    Text("No sellers match your search in this tab.")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
        }
    }

    private var sellerTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(viewModel.sellerTabs) { tabItem in
                    sellerTabButton(tabItem)
                }
            }
        }
    }

    private func sellerTabButton(_ tabItem: StartNewOrderSellerTabItem) -> some View {
        let isSelected = viewModel.selectedSellerTab == tabItem.tab

        return Button {
            viewModel.selectSellerTab(tabItem.tab)
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Text(tabItem.title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)

                    Text("\(tabItem.count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSelected ? DashboardTheme.primaryBlue.opacity(0.12) : DashboardTheme.surfaceVariant)
                        )
                }

                Rectangle()
                    .fill(isSelected ? DashboardTheme.primaryBlue : Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
    }

    private var sellerSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.primaryBlue.opacity(0.75))

            TextField("Search Seller", text: $viewModel.sellerSearchQuery)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !viewModel.sellerSearchQuery.isEmptyString {
                Button { viewModel.sellerSearchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
            }

            Image(systemName: "mic.fill")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
        }
    }

    private var addSellerButton: some View {
        Button {
            showAddSellerAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                Text("Add Seller")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(DashboardTheme.primaryBlue)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: DashboardTheme.primaryBlue.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Shared Components

private struct StartNewOrderStepCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: DashboardTheme.primaryBlue.opacity(0.05), radius: 8, y: 2)
    }
}

private struct StartNewOrderStepHeader: View {
    let step: Int
    let title: String
    var isComplete: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [DashboardTheme.primaryBlue, DashboardTheme.secondaryPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 8, height: 8)

            Text("Step \(step): \(title)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DashboardTheme.successGreen)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
}

private struct StartNewOrderSellerCard: View {
    let seller: StartNewOrderSeller
    var onCreateOrder: () -> Void
    var onViewProfile: () -> Void
    var onRequestAccess: () -> Void
    var onSellerNotAvailable: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                sellerAvatar

                VStack(alignment: .leading, spacing: 4) {
                    Text(seller.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(1)

                    Text(seller.contactLine)
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .lineLimit(1)

                    if !seller.shopVisitedStatus.isEmptyString {
                        Text(seller.shopVisitedStatus)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .lineLimit(3)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    if let flagColor = seller.flagColor {
                        Circle()
                            .fill(flagColor)
                            .frame(width: 10, height: 10)
                    }

                    Menu {
                        Button("Seller Not Available") {
                            onSellerNotAvailable()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .rotationEffect(.degrees(90))
                            .frame(width: 28, height: 28)
                    }
                }
            }

            if seller.transactionCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.dangerRed)

                    Text("\(seller.transactionCount) Pending Bills")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.dangerRed)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(DashboardTheme.dangerRed.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 8) {
                Button(action: onCreateOrder) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text("Order")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(seller.createOrderStatus ? .white : DashboardTheme.neutralMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(seller.createOrderStatus ? DashboardTheme.primaryBlue : DashboardTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!seller.createOrderStatus)

                Button(action: onViewProfile) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Profile")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(DashboardTheme.primaryBlue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if !seller.createOrderStatus {
                Button(action: onRequestAccess) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Request Access")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(DashboardTheme.secondaryPurple)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(DashboardTheme.secondaryPurple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    seller.shopVisitedLocationIncorrect
                        ? DashboardTheme.dangerRed.opacity(0.8)
                        : DashboardTheme.neutralMedium.opacity(0.15),
                    lineWidth: seller.shopVisitedLocationIncorrect ? 1.5 : 1
                )
        }
    }

    private var sellerAvatar: some View {
        VStack(spacing: 4) {
            Group {
                if seller.profilePic.isEmptyString {
                    Circle()
                        .fill(DashboardTheme.surfaceVariant)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                } else {
                    RemoteImage(url: seller.profilePic)
                        .clipShape(Circle())
                }
            }
            .frame(width: 48, height: 48)
            .overlay {
                Circle()
                    .stroke(seller.flagColor ?? DashboardTheme.neutralMedium.opacity(0.2), lineWidth: seller.flagColor == nil ? 1 : 2)
            }

            if let description = seller.colorDescription, !description.isEmptyString {
                Text(description)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(seller.flagColor ?? DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                    .frame(width: 56)
                    .lineLimit(2)
            }
        }
    }
}

private struct StartNewOrderAppBar: View {
    var onBack: () -> Void
    var onHome: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("Start New Order")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

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

#Preview {
    NavigationStack {
        StartNewOrderScreen()
    }
}
