//
//  CriticalInsightsScreen.swift
//  Truedata
//

import SwiftUI

struct CriticalInsightsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CriticalInsightsViewModel()
    @State private var showStaffFilter = false
    @State private var sellerProfileId: Int?

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                CriticalInsightsAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadSummary(isRefresh: true) },
                    isExporting: viewModel.isExporting,
                    showStaffFilter: viewModel.canShowStaffFilter,
                    isStaffFilterActive: viewModel.isStaffFilterActive,
                    onFilter: { showStaffFilter = true },
                    onDownload: { viewModel.exportExcel() }
                )

                if viewModel.isLoading && viewModel.summaryData == nil {
                    Spacer()
                    ProgressView().tint(DashboardTheme.primaryBlue)
                    Spacer()
                } else if let error = viewModel.errorMessage, viewModel.summaryData == nil {
                    errorState(error)
                } else if viewModel.summaryData != nil {
                    tabBar
                    searchBar
                    beatChips
                    sellerList
                } else {
                    emptyState(viewModel.emptyStateMessage)
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.initialize() }
        .sheet(isPresented: $showStaffFilter) {
            CriticalInsightsStaffFilterSheet(
                staffList: viewModel.staffList,
                selectedStaffId: viewModel.staffId,
                onApply: { staffId, staffName in
                    viewModel.applyStaffFilter(staffId: staffId, staffName: staffName)
                }
            )
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
        .alert(
            "Download Failed",
            isPresented: Binding(
                get: { viewModel.exportAlertMessage != nil },
                set: { isPresented in
                    if !isPresented { viewModel.exportAlertMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.exportAlertMessage ?? "")
        }
        .fullScreenCover(isPresented: sellerProfileBinding) {
            if let sellerId = sellerProfileId {
                SellerProfileScreen(sellerId: sellerId)
            }
        }
    }

    private var sellerProfileBinding: Binding<Bool> {
        Binding(
            get: { sellerProfileId != nil },
            set: { isPresented in
                if !isPresented { sellerProfileId = nil }
            }
        )
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(CriticalInsightsTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .background(Color.white)
    }

    private func tabButton(_ tab: CriticalInsightsTab) -> some View {
        let isSelected = viewModel.selectedTab == tab
        let color = tab == .noOrders ? DashboardTheme.warningYellow : DashboardTheme.dangerRed
        let count = tab == .noOrders ? viewModel.noOrdersCount : viewModel.noPaymentsCount

        return Button {
            viewModel.selectedTab = tab
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(tab.title)
                        .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                }
                .foregroundStyle(isSelected ? color : DashboardTheme.neutralMedium)

                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? color : DashboardTheme.neutralMedium)

                Rectangle()
                    .fill(isSelected ? color : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField("Search by seller name", text: $viewModel.searchText)
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmptyString {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(viewModel.activeTabColor.opacity(0.35), lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var beatChips: some View {
        let beats = viewModel.summaryData?.availableBeats ?? []
        if !beats.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    beatChip(title: "All Beats", isSelected: viewModel.selectedBeat == nil) {
                        viewModel.selectedBeat = nil
                    }
                    ForEach(beats, id: \.self) { beat in
                        beatChip(title: beat, isSelected: viewModel.selectedBeat == beat) {
                            viewModel.selectedBeat = beat
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private func beatChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? viewModel.activeTabColor : DashboardTheme.neutralDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? viewModel.activeTabColor.opacity(0.15) : Color.white)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? viewModel.activeTabColor : DashboardTheme.surfaceVariant, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sellerList: some View {
        if viewModel.filteredSellers.isEmpty {
            emptyState(viewModel.emptyStateMessage)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.groupedSellers, id: \.beatName) { group in
                        Text(group.beatName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)

                        ForEach(group.sellers) { seller in
                            CriticalInsightsSellerCard(
                                seller: seller,
                                tabColor: viewModel.activeTabColor,
                                onViewProfile: { sellerProfileId = seller.id }
                            )
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                viewModel.loadSummary()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(DashboardTheme.primaryBlue)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("🎉")
                .font(.system(size: 40))
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CriticalInsightsAppBar: View {
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: () -> Void
    var isExporting: Bool
    var showStaffFilter: Bool
    var isStaffFilterActive: Bool
    var onFilter: () -> Void
    var onDownload: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("Critical Insights")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            if showStaffFilter {
                ZStack(alignment: .topTrailing) {
                    Button(action: onFilter) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                    }
                    if isStaffFilterActive {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }

            Button(action: onDownload) {
                Group {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 34, height: 34)
            }
            .disabled(isExporting)

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

private struct CriticalInsightsSellerCard: View {
    let seller: CriticalInsightsSellerItem
    let tabColor: Color
    var onViewProfile: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            sellerAvatar

            VStack(alignment: .leading, spacing: 4) {
                Text(seller.name.isEmptyString ? "Unknown Seller" : seller.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)

                detailRow(icon: "mappin.and.ellipse", text: seller.beatName.ifEmpty(default: "Unknown"))
                detailRow(icon: "person.crop.rectangle", text: seller.staffName.ifEmpty(default: "Unknown"))

                Button(action: onViewProfile) {
                    HStack(spacing: 2) {
                        Text("View Profile")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(tabColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            if !seller.daysSinceText.isEmptyString {
                VStack(spacing: 0) {
                    Text(seller.daysNumber)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(tabColor)
                    if !seller.daysLabel.isEmptyString {
                        Text(seller.daysLabel)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(tabColor.opacity(0.75))
                            .multilineTextAlignment(.trailing)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(tabColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: tabColor.opacity(0.08), radius: 4, y: 2)
    }

    @ViewBuilder
    private var sellerAvatar: some View {
        Group {
            if seller.imageURL.isEmptyString {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tabColor.opacity(0.15))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(tabColor)
                    }
            } else {
                RemoteImage(url: seller.imageURL, contentMode: .fill)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func detailRow(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .lineLimit(1)
        }
    }
}

private struct CriticalInsightsStaffFilterSheet: View {
    let staffList: [OrderInsightsStaffMember]
    let selectedStaffId: String
    var onApply: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftStaffId: String
    @State private var searchText = ""

    init(
        staffList: [OrderInsightsStaffMember],
        selectedStaffId: String,
        onApply: @escaping (String, String) -> Void
    ) {
        self.staffList = staffList
        self.selectedStaffId = selectedStaffId
        self.onApply = onApply
        _draftStaffId = State(initialValue: selectedStaffId)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                VStack {
                    Text("Staff")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                    Spacer()
                }
                .frame(width: 100)
                .background(Color(hex: "EEF2F7"))

                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        TextField("Search staff...", text: $searchText)
                            .font(.system(size: 14))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
                    }

                    ScrollView {
                        LazyVStack(spacing: 8) {
                            staffRow(name: "All Staff", staffId: "")
                            ForEach(filteredStaff) { staff in
                                staffRow(name: staff.name, staffId: String(staff.id))
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Select Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }
            }
        }
    }

    private var filteredStaff: [OrderInsightsStaffMember] {
        guard !searchText.isEmptyString else { return staffList }
        return staffList.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func staffRow(name: String, staffId: String) -> some View {
        let isSelected = draftStaffId == staffId
        return Button {
            draftStaffId = staffId
            onApply(staffId, name)
            dismiss()
        } label: {
            HStack {
                Text(name)
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralDark)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(isSelected ? DashboardTheme.primaryBlue.opacity(0.08) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? DashboardTheme.primaryBlue.opacity(0.5) : DashboardTheme.surfaceVariant, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension String {
    func ifEmpty(default defaultValue: String) -> String {
        isEmptyString ? defaultValue : self
    }
}
