//
//  RegisteredSellersScreen.swift
//  Truedata
//

import SwiftUI

struct RegisteredSellersScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RegisteredSellersViewModel()
    @State private var showFilterSheet = false
    @State private var statusDialog: (title: String, message: String)?

    var onEditSeller: (Int) -> Void = { _ in }
    var onProfileSeller: (Int) -> Void = { _ in }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Registered Sellers",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.refresh() }
                )

                searchBar
                content
            }

            if viewModel.isUpdatingStatus {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView("Updating...")
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadInitial() }
        .sheet(isPresented: $showFilterSheet) {
            RegisteredSellersFilterSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert(statusDialog?.title ?? "Confirm", isPresented: statusDialogBinding) {
            Button("No", role: .cancel) {
                viewModel.cancelStatusUpdate()
                statusDialog = nil
            }
            Button("Yes") {
                viewModel.confirmStatusUpdate()
                statusDialog = nil
            }
        } message: {
            if let dialog = statusDialog {
                Text(dialog.message)
            }
        }
        .alert("Notice", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var statusDialogBinding: Binding<Bool> {
        Binding(
            get: { statusDialog != nil },
            set: { if !$0 { statusDialog = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && viewModel.sellers.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search...", text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.searchText) { _, value in
                        viewModel.onSearchChanged(value)
                    }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.primaryBlue.opacity(0.35), lineWidth: 1)
            }

            Button {
                showFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
                .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isApplyingFilters || (viewModel.isLoading && viewModel.sellers.isEmpty) {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.sellers.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.refresh()
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.sellers.isEmpty {
            Text("No sellers found for selected filters.")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    HStack {
                        Text("\(viewModel.total) Sellers Found")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Spacer()
                    }
                    .padding(.horizontal, 4)

                    ForEach(viewModel.sellers) { seller in
                        RegisteredSellerCard(
                            seller: seller,
                            showDeactivate: viewModel.showDeactBtn,
                            onDeactivate: {
                                statusDialog = viewModel.prepareStatusUpdate(for: seller)
                            },
                            onEdit: {
                                onEditSeller(seller.id)
                            },
                            onProfile: {
                                onProfileSeller(seller.id)
                            }
                        )
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentSeller: seller)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}

struct SellersAppBar: View {
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

private struct RegisteredSellerCard: View {
    let seller: RegisteredSellerItem
    let showDeactivate: Bool
    var onDeactivate: () -> Void
    var onEdit: () -> Void
    var onProfile: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(seller.cardTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "1F2937"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let color = seller.flagColor {
                        Circle()
                            .fill(color)
                            .frame(width: 12, height: 12)
                    }

                    Text(seller.statusLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(seller.isActive ? Color(hex: "15803D") : Color(hex: "B91C1C"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            seller.isActive ? Color(hex: "E7FBEF") : Color(hex: "FCECEC")
                        )
                        .clipShape(Capsule())
                }

                HStack {
                    detailLabel("Mobile:", value: seller.mobile)
                    Spacer()
                    detailLabel("City:", value: seller.cityId)
                }

                detailLabel("Beat:", value: seller.beatId)
            }
            .padding(16)

            Divider()

            HStack(spacing: 0) {
                if showDeactivate {
                    actionButton(seller.isActive ? "Deactivate" : "Activate", action: onDeactivate)
                    Divider().frame(height: 28)
                }
                actionButton("Edit", action: onEdit)
                Divider().frame(height: 28)
                actionButton("Profile", action: onProfile)
            }
            .frame(height: 44)
        }
        .background(Color(hex: "FAFBFC"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }

    private func detailLabel(_ label: String, value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "374151"))
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "374151"))
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "002B45"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private extension RegisteredSellerItem {
    var flagColor: Color? {
        switch colorId {
        case 1: return DashboardTheme.successGreen
        case 3: return DashboardTheme.dangerRed
        case 4: return DashboardTheme.warningYellow
        default: return nil
        }
    }
}

private struct RegisteredSellersFilterSheet: View {
    @ObservedObject var viewModel: RegisteredSellersViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draftStateId: Int?
    @State private var draftCityId: Int?
    @State private var draftBeatId: Int?
    @State private var draftStatus: String

    init(viewModel: RegisteredSellersViewModel) {
        self.viewModel = viewModel
        _draftStateId = State(initialValue: viewModel.stateId)
        _draftCityId = State(initialValue: viewModel.cityId)
        _draftBeatId = State(initialValue: viewModel.beatId)
        _draftStatus = State(initialValue: viewModel.statusFilter)
    }

    private var draftCities: [OrderInsightsCityArea] {
        guard let draftStateId else { return [] }
        return viewModel.areas.first(where: { $0.id == draftStateId })?.cities ?? []
    }

    private var draftBeats: [OrderInsightsBeatArea] {
        guard let draftCityId else { return [] }
        return viewModel.areas.flatMap(\.cities).first(where: { $0.id == draftCityId })?.beats ?? []
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Picker("Status", selection: $draftStatus) {
                        Text("All").tag("")
                        Text("Active").tag("1")
                        Text("Inactive").tag("0")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Area") {
                    Picker("State", selection: $draftStateId) {
                        Text("All States").tag(Optional<Int>.none)
                        ForEach(viewModel.areas) { state in
                            Text(state.name).tag(Optional(state.id))
                        }
                    }
                    .onChange(of: draftStateId) { _, _ in
                        draftCityId = nil
                        draftBeatId = nil
                    }

                    Picker("City", selection: $draftCityId) {
                        Text("All Cities").tag(Optional<Int>.none)
                        ForEach(draftCities) { city in
                            Text(city.name).tag(Optional(city.id))
                        }
                    }
                    .disabled(draftStateId == nil)
                    .onChange(of: draftCityId) { _, _ in
                        draftBeatId = nil
                    }

                    Picker("Beat", selection: $draftBeatId) {
                        Text("All Beats").tag(Optional<Int>.none)
                        ForEach(draftBeats) { beat in
                            Text(beat.name).tag(Optional(beat.id))
                        }
                    }
                    .disabled(draftCityId == nil)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        viewModel.resetFilters()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        let stateName = viewModel.areas.first(where: { $0.id == draftStateId })?.name
                        let cityName = draftCities.first(where: { $0.id == draftCityId })?.name
                        let beatName = draftBeats.first(where: { $0.id == draftBeatId })?.name
                        viewModel.applyFilters(
                            stateId: draftStateId,
                            cityId: draftCityId,
                            beatId: draftBeatId,
                            status: draftStatus,
                            stateName: stateName,
                            cityName: cityName,
                            beatName: beatName
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
