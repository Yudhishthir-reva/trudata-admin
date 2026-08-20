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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    sidebar
                    Divider()
                    optionsPanel
                }
                footerButtons
            }
            .background(Color(hex: "F3F4F6"))
            .navigationTitle("Product Filters")
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

    private var sidebar: some View {
        VStack(spacing: 4) {
            ForEach(ManageProductFilterSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: selectedSection == section ? .bold : .medium))
                        .foregroundStyle(selectedSection == section ? .white : DashboardTheme.neutralDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedSection == section
                                ? DashboardTheme.primaryBlue
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(width: 118)
        .background(Color.white.opacity(0.7))
    }

    @ViewBuilder
    private var optionsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(sectionTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .padding(.bottom, 4)

                switch selectedSection {
                case .category:
                    filterOption(title: "All Categories", isSelected: draftCategoryId.isEmpty) {
                        draftCategoryId = ""
                    }
                    if viewModel.isLoadingCategories {
                        ProgressView().padding(.top, 8)
                    } else {
                        ForEach(viewModel.categories) { category in
                            filterOption(
                                title: category.name,
                                isSelected: draftCategoryId == String(category.id)
                            ) {
                                draftCategoryId = String(category.id)
                            }
                        }
                    }
                case .brand:
                    filterOption(title: "All Brands", isSelected: draftBrandId.isEmpty) {
                        draftBrandId = ""
                    }
                    if viewModel.isLoadingBrands {
                        ProgressView().padding(.top, 8)
                    } else {
                        ForEach(viewModel.brands) { brand in
                            filterOption(
                                title: brand.name,
                                isSelected: draftBrandId == String(brand.id)
                            ) {
                                draftBrandId = String(brand.id)
                            }
                        }
                    }
                case .status:
                    filterOption(title: "All Status", isSelected: draftStatus.isEmpty) {
                        draftStatus = ""
                    }
                    filterOption(title: "Active", isSelected: draftStatus == "1") {
                        draftStatus = "1"
                    }
                    filterOption(title: "Inactive", isSelected: draftStatus == "0") {
                        draftStatus = "0"
                    }
                }
            }
            .padding(16)
        }
    }

    private var sectionTitle: String {
        switch selectedSection {
        case .category: return "CATEGORY"
        case .brand: return "BRAND"
        case .status: return "PRODUCT STATUS"
        }
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.clearFilters()
                dismiss()
            } label: {
                Text("Clear All")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DashboardTheme.primaryBlue, lineWidth: 1.5)
                    }
            }
            .buttonStyle(.plain)

            Button {
                viewModel.applyFilters(
                    categoryId: draftCategoryId,
                    brandId: draftBrandId,
                    status: draftStatus
                )
                dismiss()
            } label: {
                Text("Apply Filters")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(DashboardTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white)
    }

    private func filterOption(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
