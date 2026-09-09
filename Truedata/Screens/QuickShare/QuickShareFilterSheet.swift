//
//  QuickShareFilterSheet.swift
//  Truedata
//

import SwiftUI

struct QuickShareFilterSheet: View {

    @ObservedObject var viewModel: QuickShareViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSection: QuickShareFilterSection = .staff
    @State private var draftStaffId = ""
    @State private var draftStaffName = "All Staff"
    @State private var draftSellerId = ""
    @State private var draftSellerName = "All Sellers"
    @State private var draftOrderStatus = ""
    @State private var draftOrderStatusLabel = "All Orders"
    @State private var sellerSearch = ""

    init(viewModel: QuickShareViewModel) {
        self.viewModel = viewModel
        _draftStaffId = State(initialValue: viewModel.selectedStaffId)
        _draftStaffName = State(initialValue: viewModel.selectedStaffName)
        _draftSellerId = State(initialValue: viewModel.selectedSellerId)
        _draftSellerName = State(initialValue: viewModel.selectedSellerName)
        _draftOrderStatus = State(initialValue: viewModel.selectedOrderStatus)
        _draftOrderStatusLabel = State(initialValue: viewModel.selectedOrderStatusLabel)
    }

    private var categoryItems: [FilterCategoryItem] {
        QuickShareFilterSection.allCases.map { FilterCategoryItem(id: $0.rawValue, title: $0.rawValue) }
    }

    private var selectedCategoryID: Binding<String> {
        Binding(
            get: { selectedSection.rawValue },
            set: { if let value = QuickShareFilterSection(rawValue: $0) { selectedSection = value } }
        )
    }

    var body: some View {
        AppFilterSheetChrome(
            title: "Quick Share Filters",
            categories: categoryItems,
            selectedCategoryID: selectedCategoryID,
            resetTitle: "Reset",
            applyTitle: "Apply",
            showsResetIcon: false,
            showsApplyIcon: false,
            onReset: {
                draftStaffId = ""
                draftStaffName = "All Staff"
                draftSellerId = ""
                draftSellerName = "All Sellers"
                draftOrderStatus = ""
                draftOrderStatusLabel = "All Orders"
            },
            onApply: {
                viewModel.applyFilters(
                    staffId: draftStaffId,
                    staffName: draftStaffName,
                    sellerId: draftSellerId,
                    sellerName: draftSellerName,
                    orderStatus: draftOrderStatus,
                    orderStatusLabel: draftOrderStatusLabel
                )
                dismiss()
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    FilterSectionTitle(title: selectedSection.rawValue)
                    switch selectedSection {
                    case .staff:
                        FilterRadioRow(title: "All Staff", isSelected: draftStaffId.isEmptyString) {
                            draftStaffId = ""
                            draftStaffName = "All Staff"
                        }
                        ForEach(viewModel.staffList) { staff in
                            FilterRadioRow(title: staff.name, isSelected: draftStaffId == String(staff.id)) {
                                draftStaffId = String(staff.id)
                                draftStaffName = staff.name
                            }
                        }
                    case .seller:
                        FilterSearchField(placeholder: "Search sellers...", text: $sellerSearch, filledBackground: true)
                        FilterRadioRow(title: "All Sellers", isSelected: draftSellerId.isEmptyString) {
                            draftSellerId = ""
                            draftSellerName = "All Sellers"
                        }
                        ForEach(filteredSellers) { seller in
                            FilterRadioRow(
                                title: seller.displayName,
                                isSelected: draftSellerId == String(seller.id)
                            ) {
                                draftSellerId = String(seller.id)
                                draftSellerName = seller.displayName
                            }
                        }
                    case .orderStatus:
                        ForEach(QuickShareOrderStatusOption.allOptions) { option in
                            FilterRadioRow(title: option.label, isSelected: draftOrderStatus == option.id) {
                                draftOrderStatus = option.id
                                draftOrderStatusLabel = option.label
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    private var filteredSellers: [OrderInsightsSellerItem] {
        guard !sellerSearch.isEmptyString else { return viewModel.sellerList }
        return viewModel.sellerList.filter {
            $0.displayName.localizedCaseInsensitiveContains(sellerSearch)
        }
    }
}
