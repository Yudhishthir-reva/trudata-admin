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
            .navigationTitle("Quick Share Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
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
            ForEach(QuickShareFilterSection.allCases) { section in
                Button { selectedSection = section } label: {
                    Text(section.rawValue)
                        .font(.system(size: 14, weight: selectedSection == section ? .bold : .medium))
                        .foregroundStyle(selectedSection == section ? .white : DashboardTheme.neutralDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedSection == section ? DashboardTheme.primaryBlue : Color.clear)
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
            VStack(alignment: .leading, spacing: 8) {
                switch selectedSection {
                case .staff:
                    filterOption(title: "All Staff", isSelected: draftStaffId.isEmptyString) {
                        draftStaffId = ""
                        draftStaffName = "All Staff"
                    }
                    ForEach(viewModel.staffList) { staff in
                        filterOption(title: staff.name, isSelected: draftStaffId == String(staff.id)) {
                            draftStaffId = String(staff.id)
                            draftStaffName = staff.name
                        }
                    }
                case .seller:
                    TextField("Search sellers...", text: $sellerSearch)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 4)

                    filterOption(title: "All Sellers", isSelected: draftSellerId.isEmptyString) {
                        draftSellerId = ""
                        draftSellerName = "All Sellers"
                    }
                    ForEach(filteredSellers) { seller in
                        filterOption(
                            title: seller.displayName,
                            isSelected: draftSellerId == String(seller.id)
                        ) {
                            draftSellerId = String(seller.id)
                            draftSellerName = seller.displayName
                        }
                    }
                case .orderStatus:
                    ForEach(QuickShareOrderStatusOption.allOptions) { option in
                        filterOption(title: option.label, isSelected: draftOrderStatus == option.id) {
                            draftOrderStatus = option.id
                            draftOrderStatusLabel = option.label
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private var filteredSellers: [OrderInsightsSellerItem] {
        guard !sellerSearch.isEmptyString else { return viewModel.sellerList }
        return viewModel.sellerList.filter {
            $0.displayName.localizedCaseInsensitiveContains(sellerSearch)
        }
    }

    private func filterOption(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? DashboardTheme.primaryBlue.opacity(0.08) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var footerButtons: some View {
        HStack(spacing: 12) {
            Button("Reset") {
                draftStaffId = ""
                draftStaffName = "All Staff"
                draftSellerId = ""
                draftSellerName = "All Sellers"
                draftOrderStatus = ""
                draftOrderStatusLabel = "All Orders"
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DashboardTheme.neutralMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
            }

            Button("Apply") {
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
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(DashboardTheme.primaryBlue)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .background(Color.white)
    }
}
