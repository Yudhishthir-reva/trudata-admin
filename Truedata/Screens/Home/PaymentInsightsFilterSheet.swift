//
//  PaymentInsightsFilterSheet.swift
//  Truedata
//

import SwiftUI

struct PaymentInsightsFilterSheet: View {

    @ObservedObject var viewModel: PaymentInsightsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: PaymentInsightsFilterCategory = .dateRange
    @State private var draftStartDate: String
    @State private var draftEndDate: String
    @State private var draftDatePreset: OrderInsightsDatePreset
    @State private var draftPaymentMode: String
    @State private var draftPaymentStatus: String
    @State private var draftStaffId: String
    @State private var draftSellerId: String
    @State private var staffSearch = ""
    @State private var sellerSearch = ""
    @State private var sellerStateId: String?

    init(viewModel: PaymentInsightsViewModel) {
        self.viewModel = viewModel
        let filters = viewModel.currentAppliedFilters()
        _draftStartDate = State(initialValue: filters.startDate)
        _draftEndDate = State(initialValue: filters.endDate)
        _draftDatePreset = State(initialValue: filters.datePreset)
        _draftPaymentMode = State(initialValue: filters.paymentMode)
        _draftPaymentStatus = State(initialValue: filters.paymentStatus)
        _draftStaffId = State(initialValue: filters.staffId)
        _draftSellerId = State(initialValue: filters.sellerId)
    }

    private var categoryItems: [FilterCategoryItem] {
        PaymentInsightsFilterCategory.allCases.map { FilterCategoryItem(id: $0.rawValue, title: $0.rawValue) }
    }

    private var selectedCategoryID: Binding<String> {
        Binding(
            get: { selectedCategory.rawValue },
            set: { if let value = PaymentInsightsFilterCategory(rawValue: $0) { selectedCategory = value } }
        )
    }

    var body: some View {
        AppFilterSheetChrome(
            title: "Payment Filters",
            categories: categoryItems,
            selectedCategoryID: selectedCategoryID,
            resetTitle: "Clear All",
            applyTitle: "Apply",
            showsResetIcon: false,
            showsApplyIcon: false,
            onReset: {
                viewModel.resetToDefaultFilters()
                dismiss()
            },
            onApply: {
                applyDraftFilters()
                dismiss()
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    FilterSectionTitle(title: selectedCategory.rawValue)
                    switch selectedCategory {
                    case .dateRange:
                        dateRangeContent
                    case .paymentMode:
                        paymentModeContent
                    case .paymentStatus:
                        paymentStatusContent
                    case .staff:
                        staffContent
                    case .seller:
                        sellerContent
                    }
                }
                .padding(12)
            }
        }
    }

    private var dateRangeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(OrderInsightsDatePreset.allCases, id: \.self) { preset in
                FilterRadioRow(title: preset.rawValue, isSelected: draftDatePreset == preset) {
                    draftDatePreset = preset
                    if preset != .custom, let range = OrderInsightsDatePreset.dateRange(for: preset) {
                        draftStartDate = range.start
                        draftEndDate = range.end
                    }
                }
            }
            if draftDatePreset == .custom {
                VStack(spacing: 10) {
                    DashboardDatePickerField(dateString: draftStartDate, onDateSelected: { draftStartDate = $0 })
                    DashboardDatePickerField(dateString: draftEndDate, onDateSelected: { draftEndDate = $0 })
                }
            }
        }
    }

    private var paymentModeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(PaymentInsightsPaymentMode.options) { option in
                FilterRadioRow(title: option.title, isSelected: draftPaymentMode == option.id) {
                    draftPaymentMode = option.id
                }
            }
        }
    }

    private var paymentStatusContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(PaymentInsightsPaymentStatus.options) { option in
                FilterRadioRow(title: option.title, isSelected: draftPaymentStatus == option.id) {
                    draftPaymentStatus = option.id
                }
            }
        }
    }

    private var staffContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            FilterSearchField(placeholder: "Search staff...", text: $staffSearch, filledBackground: true)
            FilterRadioRow(title: "All Staff", isSelected: draftStaffId.isEmptyString) { draftStaffId = "" }
            ForEach(filteredStaff) { staff in
                FilterRadioRow(title: staff.name, isSelected: draftStaffId == String(staff.id)) {
                    draftStaffId = String(staff.id)
                }
            }
        }
    }

    private var sellerContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            statePicker(
                title: "State",
                selectedName: sellerStateName,
                options: viewModel.areaStates.map { ($0.name, String($0.id)) },
                onSelect: { id in
                    sellerStateId = id
                    viewModel.loadSellers(isRefresh: true, stateId: id, search: sellerSearch)
                }
            )
            FilterSearchField(placeholder: "Search sellers...", text: $sellerSearch, filledBackground: true)
                .onChange(of: sellerSearch) { _, query in
                    viewModel.loadSellers(isRefresh: true, stateId: sellerStateId, search: query)
                }
            FilterRadioRow(title: "All Sellers", isSelected: draftSellerId.isEmptyString) { draftSellerId = "" }
            ForEach(viewModel.sellerList) { seller in
                FilterRadioRow(title: seller.displayName, isSelected: draftSellerId == String(seller.id)) {
                    draftSellerId = String(seller.id)
                }
            }
            if viewModel.sellerCurrentPage < viewModel.sellerLastPage {
                Button("Load More") {
                    viewModel.loadSellers(isRefresh: false, stateId: sellerStateId, search: sellerSearch)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(DashboardTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var filteredStaff: [OrderInsightsStaffMember] {
        guard !staffSearch.isEmptyString else { return viewModel.staffList }
        return viewModel.staffList.filter { $0.name.localizedCaseInsensitiveContains(staffSearch) }
    }

    private var sellerStateName: String {
        guard let sellerStateId,
              let state = viewModel.areaStates.first(where: { String($0.id) == sellerStateId }) else {
            return "All States"
        }
        return state.name
    }

    private func applyDraftFilters() {
        viewModel.applyFilters(
            PaymentInsightsAppliedFilters(
                startDate: draftStartDate,
                endDate: draftEndDate,
                datePreset: draftDatePreset,
                paymentMode: draftPaymentMode,
                paymentStatus: draftPaymentStatus,
                staffId: draftStaffId,
                sellerId: draftSellerId
            )
        )
    }

    private func statePicker(
        title: String,
        selectedName: String,
        options: [(String, String)],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.1) { option in
                Button(option.0) { onSelect(option.1) }
            }
        } label: {
            HStack {
                Text("\(title): \(selectedName)")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
            }
            .foregroundStyle(DashboardTheme.neutralDark)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(hex: "F3F4F6"))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
