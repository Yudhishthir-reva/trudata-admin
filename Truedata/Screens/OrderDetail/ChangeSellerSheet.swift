//
//  ChangeSellerSheet.swift
//  Truedata
//

import SwiftUI

struct ChangeSellerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChangeSellerViewModel
    var onUpdated: () -> Void

    init(
        order: OrderDetailData,
        orderId: String,
        onUpdated: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: ChangeSellerViewModel(
                order: order,
                orderId: orderId
            )
        )
        self.onUpdated = onUpdated
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        currentSellerSection
                        filtersSection
                        searchField
                        sellerListSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }

                footerButtons
            }
            .background(Color(hex: "F3F4F6"))
            .navigationTitle("Change Seller")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .frame(width: 28, height: 28)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { viewModel.initialize() }
        .onChange(of: viewModel.didUpdateSuccessfully) { _, didUpdate in
            guard didUpdate else { return }
            onUpdated()
            dismiss()
        }
        .alert("Notice", isPresented: errorBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }

    private var currentSellerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Seller:")
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(viewModel.currentSellerDisplay)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filtersSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                filterDropdown(
                    label: "State",
                    value: stateName,
                    options: viewModel.areaStates.map { ($0.name, String($0.id)) },
                    onSelect: { viewModel.selectState($0) },
                    onClear: { viewModel.selectState(nil) }
                )

                filterDropdown(
                    label: "City",
                    value: cityName,
                    options: (viewModel.selectedState?.cities ?? []).map { ($0.name, String($0.id)) },
                    onSelect: { viewModel.selectCity($0) },
                    onClear: { viewModel.selectCity(nil) },
                    isEnabled: viewModel.selectedStateId != nil
                )
            }

            filterDropdown(
                label: "Beat",
                value: beatName,
                options: (viewModel.selectedCity?.beats ?? []).map { ($0.name, String($0.id)) },
                onSelect: { viewModel.selectBeat($0) },
                onClear: { viewModel.selectBeat(nil) },
                isEnabled: viewModel.selectedCityId != nil,
                includeAllOption: true
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField("Search by seller name...", text: $viewModel.sellerSearch)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
        .onChange(of: viewModel.sellerSearch) { _, query in
            viewModel.updateSearchQuery(query)
        }
    }

    @ViewBuilder
    private var sellerListSection: some View {
        if viewModel.isLoadingAreas || (viewModel.isLoadingSellers && viewModel.displayableSellerList.isEmpty) {
            HStack {
                Spacer()
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
                Spacer()
            }
            .padding(.vertical, 24)
        } else if !viewModel.canBrowseSellers {
            Text("Select state and city to browse sellers.")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else if viewModel.displayableSellerList.isEmpty {
            Text("No sellers found.")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 0) {
                ForEach(viewModel.displayableSellerList) { seller in
                    sellerRow(seller)
                    if seller.id != viewModel.displayableSellerList.last?.id {
                        Divider().overlay(DashboardTheme.surfaceVariant.opacity(0.8))
                    }
                }

                if viewModel.canLoadMoreSellers || viewModel.isLoadingMoreSellers {
                    Button {
                        viewModel.loadSellers(isRefresh: false)
                    } label: {
                        Group {
                            if viewModel.isLoadingMoreSellers {
                                ProgressView()
                                    .tint(DashboardTheme.primaryBlue)
                            } else {
                                Text("Load More")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
            }
        }
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button {
                viewModel.updateSeller()
            } label: {
                Group {
                    if viewModel.isUpdating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Update Seller")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(viewModel.canUpdateSeller ? DashboardTheme.primaryBlue : DashboardTheme.primaryBlue.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canUpdateSeller)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    private var stateName: String {
        viewModel.selectedState?.name ?? "Select State"
    }

    private var cityName: String {
        viewModel.selectedCity?.name ?? "Select City"
    }

    private var beatName: String {
        guard viewModel.selectedBeatId != nil else { return "All Beats" }
        return viewModel.selectedCity?.beats.first(where: { String($0.id) == viewModel.selectedBeatId })?.name ?? "All Beats"
    }

    private func sellerRow(_ seller: OrderInsightsSellerItem) -> some View {
        Button {
            viewModel.selectedSellerId = String(seller.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: viewModel.selectedSellerId == String(seller.id) ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(
                        viewModel.selectedSellerId == String(seller.id)
                        ? DashboardTheme.primaryBlue
                        : DashboardTheme.neutralMedium
                    )
                Text(seller.displayName)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func filterDropdown(
        label: String,
        value: String,
        options: [(String, String)],
        onSelect: @escaping (String) -> Void,
        onClear: @escaping () -> Void,
        isEnabled: Bool = true,
        includeAllOption: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralMedium)

            HStack(spacing: 0) {
                Menu {
                    if includeAllOption {
                        Button("All Beats") { onClear() }
                    }
                    ForEach(options, id: \.1) { option in
                        Button(option.0) { onSelect(option.1) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(value)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isEnabled ? DashboardTheme.neutralDark : DashboardTheme.neutralMedium.opacity(0.7))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                }
                .disabled(!isEnabled || (options.isEmpty && !includeAllOption))

                if hasSelection(for: label) {
                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        label == "City" && viewModel.selectedCityId != nil
                        ? DashboardTheme.primaryBlue
                        : DashboardTheme.surfaceVariant,
                        lineWidth: 1
                    )
            }
        }
    }

    private func hasSelection(for label: String) -> Bool {
        switch label {
        case "State": return viewModel.selectedStateId != nil
        case "City": return viewModel.selectedCityId != nil
        case "Beat": return viewModel.selectedBeatId != nil
        default: return false
        }
    }
}
