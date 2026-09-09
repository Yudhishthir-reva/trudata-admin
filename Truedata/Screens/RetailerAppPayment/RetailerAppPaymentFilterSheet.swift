//
//  RetailerAppPaymentFilterSheet.swift
//  Truedata
//

import SwiftUI

struct RetailerAppPaymentFilterSheet: View {

    @Environment(\.dismiss) private var dismiss

    let currentFilters: RetailerPaymentFilters
    let sellerList: [OrderInsightsSellerItem]
    let isLoadingSellers: Bool
    var locksSellerSelection: Bool = false
    var onApply: (RetailerPaymentFilters) -> Void
    var onReset: () -> Void

    @State private var draftFilters: RetailerPaymentFilters
    @State private var selectedTab: FilterTab = .dateRange
    @State private var retailerSearchText: String = ""

    enum FilterTab: String, CaseIterable {
        case dateRange = "Date Range"
        case retailer = "Retailer"
    }

    init(
        currentFilters: RetailerPaymentFilters,
        sellerList: [OrderInsightsSellerItem],
        isLoadingSellers: Bool,
        locksSellerSelection: Bool = false,
        onApply: @escaping (RetailerPaymentFilters) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.currentFilters = currentFilters
        self.sellerList = sellerList
        self.isLoadingSellers = isLoadingSellers
        self.locksSellerSelection = locksSellerSelection
        self.onApply = onApply
        self.onReset = onReset
        _draftFilters = State(initialValue: currentFilters)
    }

    private var availableTabs: [FilterTab] {
        locksSellerSelection ? [.dateRange] : FilterTab.allCases
    }

    private var categoryItems: [FilterCategoryItem] {
        availableTabs.map { FilterCategoryItem(id: $0.rawValue, title: $0.rawValue) }
    }

    private var selectedCategoryID: Binding<String> {
        Binding(
            get: { selectedTab.rawValue },
            set: { if let value = FilterTab(rawValue: $0) { selectedTab = value } }
        )
    }

    var body: some View {
        AppFilterSheetChrome(
            title: "Payment Filters",
            categories: categoryItems,
            selectedCategoryID: selectedCategoryID,
            resetTitle: "Use Default",
            applyTitle: "Apply Filters",
            usesNavigationChrome: false,
            onReset: {
                onReset()
                dismiss()
            },
            onApply: {
                onApply(draftFilters)
                dismiss()
            }
        ) {
            switch selectedTab {
            case .dateRange:
                dateRangeSection
            case .retailer:
                retailerSection
            }
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
    }

    private var dateRangeSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                FilterSectionTitle(title: "Date Range")

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(RetailerPaymentDatePreset.allCases) { preset in
                        FilterRadioRow(
                            title: preset.rawValue,
                            isSelected: draftFilters.datePreset == preset
                        ) {
                            draftFilters.datePreset = preset
                            let range = preset.dateRange()
                            draftFilters.startDate = range.start
                            draftFilters.endDate = range.end
                        }
                    }
                }

                if draftFilters.datePreset == .custom {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Custom Range (YYYY-MM-DD)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "4B5563"))

                        HStack(spacing: 10) {
                            TextField("Start Date", text: $draftFilters.startDate)
                                .font(.system(size: 13))
                                .padding(8)
                                .background(Color(hex: "F9FAFB"))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "D1D5DB"), lineWidth: 1))

                            TextField("End Date", text: $draftFilters.endDate)
                                .font(.system(size: 13))
                                .padding(8)
                                .background(Color(hex: "F9FAFB"))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "D1D5DB"), lineWidth: 1))
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
        }
    }

    private var filteredSellers: [OrderInsightsSellerItem] {
        if retailerSearchText.trim.isEmpty {
            return sellerList
        }
        let q = retailerSearchText.trim.lowercased()
        return sellerList.filter {
            $0.shopName.lowercased().contains(q) ||
            $0.name.lowercased().contains(q) ||
            $0.mobile.contains(q)
        }
    }

    private var retailerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FilterSectionTitle(title: "Retailer")
                .padding(.horizontal, 16)
                .padding(.top, 16)

            FilterSearchField(placeholder: "Search retailers...", text: $retailerSearchText, filledBackground: true)
                .padding(.horizontal, 16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    FilterRadioRow(
                        title: "All Retailers",
                        isSelected: draftFilters.sellerId == nil || draftFilters.sellerId?.isEmpty == true
                    ) {
                        draftFilters.sellerId = nil
                        draftFilters.sellerName = nil
                    }

                    if isLoadingSellers && sellerList.isEmpty {
                        ProgressView()
                            .tint(DashboardTheme.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(filteredSellers) { seller in
                            let sId = String(seller.id)
                            let isSelected = draftFilters.sellerId == sId
                            let title = seller.shopName.isEmpty ? seller.name : seller.shopName
                            let subtitle: String? = {
                                if !seller.name.isEmpty && !seller.shopName.isEmpty && seller.name != seller.shopName {
                                    return seller.name
                                }
                                return nil
                            }()

                            FilterRadioRow(
                                title: title,
                                subtitle: subtitle,
                                isSelected: isSelected
                            ) {
                                draftFilters.sellerId = sId
                                draftFilters.sellerName = title
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
}
