//
//  ManageProductsFilterSheet.swift
//  Truedata
//

import SwiftUI

struct ManageProductsFilterSheet: View {

    @ObservedObject var viewModel: ManageProductsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSection: ManageProductFilterSection = .category
    @State private var draftCategoryId = ""
    @State private var draftBrandId = ""
    @State private var draftStatus = ""

    init(viewModel: ManageProductsViewModel) {
        self.viewModel = viewModel
        _draftCategoryId = State(initialValue: viewModel.selectedCategoryId)
        _draftBrandId = State(initialValue: viewModel.selectedBrandId)
        _draftStatus = State(initialValue: viewModel.selectedStatus)
    }

    private var categoryItems: [FilterCategoryItem] {
        ManageProductFilterSection.allCases.map { FilterCategoryItem(id: $0.rawValue, title: $0.rawValue) }
    }

    private var selectedCategoryID: Binding<String> {
        Binding(
            get: { selectedSection.rawValue },
            set: { if let value = ManageProductFilterSection(rawValue: $0) { selectedSection = value } }
        )
    }

    var body: some View {
        AppFilterSheetChrome(
            title: "Product Filters",
            categories: categoryItems,
            selectedCategoryID: selectedCategoryID,
            resetTitle: "Clear All",
            applyTitle: "Apply Filters",
            showsResetIcon: false,
            showsApplyIcon: false,
            onReset: {
                viewModel.clearFilters()
                dismiss()
            },
            onApply: {
                viewModel.applyFilters(
                    categoryId: draftCategoryId,
                    brandId: draftBrandId,
                    status: draftStatus
                )
                dismiss()
            }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    FilterSectionTitle(title: sectionTitle)
                    switch selectedSection {
                    case .category:
                        FilterRadioRow(title: "All Categories", isSelected: draftCategoryId.isEmpty) {
                            draftCategoryId = ""
                        }
                        if viewModel.isLoadingCategories {
                            ProgressView().padding(.top, 8)
                        } else {
                            ForEach(viewModel.categories) { category in
                                FilterRadioRow(
                                    title: category.name,
                                    isSelected: draftCategoryId == String(category.id)
                                ) {
                                    draftCategoryId = String(category.id)
                                }
                            }
                        }
                    case .brand:
                        FilterRadioRow(title: "All Brands", isSelected: draftBrandId.isEmpty) {
                            draftBrandId = ""
                        }
                        if viewModel.isLoadingBrands {
                            ProgressView().padding(.top, 8)
                        } else {
                            ForEach(viewModel.brands) { brand in
                                FilterRadioRow(
                                    title: brand.name,
                                    isSelected: draftBrandId == String(brand.id)
                                ) {
                                    draftBrandId = String(brand.id)
                                }
                            }
                        }
                    case .status:
                        FilterRadioRow(title: "All Status", isSelected: draftStatus.isEmpty) {
                            draftStatus = ""
                        }
                        FilterRadioRow(title: "Active", isSelected: draftStatus == "1") {
                            draftStatus = "1"
                        }
                        FilterRadioRow(title: "Inactive", isSelected: draftStatus == "0") {
                            draftStatus = "0"
                        }
                    }
                }
                .padding(16)
            }
        }
    }

    private var sectionTitle: String {
        switch selectedSection {
        case .category: return "Category"
        case .brand: return "Brand"
        case .status: return "Product Status"
        }
    }
}
