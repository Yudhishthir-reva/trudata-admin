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
        onApply: @escaping (RetailerPaymentFilters) -> Void,
        onReset: @escaping () -> Void
    ) {
        self.currentFilters = currentFilters
        self.sellerList = sellerList
        self.isLoadingSellers = isLoadingSellers
        self.onApply = onApply
        self.onReset = onReset
        _draftFilters = State(initialValue: currentFilters)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().foregroundStyle(Color(hex: "E5E7EB"))

            HStack(alignment: .top, spacing: 0) {
                leftRail
                    .frame(width: 125)
                    .background(Color(hex: "F9FAFB"))

                Divider().foregroundStyle(Color(hex: "E5E7EB"))

                rightContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
            }
            .frame(maxHeight: .infinity)

            Divider().foregroundStyle(Color(hex: "E5E7EB"))
            bottomActionBar
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Payment Filters")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "4B5563"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "F3F4F6"))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Left Rail

    private var leftRail: some View {
        VStack(spacing: 6) {
            ForEach(FilterTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    HStack {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundStyle(selectedTab == tab ? Color.white : Color(hex: "374151"))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab ? Color(hex: "1D4ED8") : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            Spacer()
        }
        .padding(10)
    }

    // MARK: - Right Content

    @ViewBuilder
    private var rightContent: some View {
        switch selectedTab {
        case .dateRange:
            dateRangeSection
        case .retailer:
            retailerSection
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("DATE RANGE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "1E40AF"))
                    .tracking(0.8)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(RetailerPaymentDatePreset.allCases) { preset in
                        Button {
                            draftFilters.datePreset = preset
                            let range = preset.dateRange()
                            draftFilters.startDate = range.start
                            draftFilters.endDate = range.end
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: draftFilters.datePreset == preset ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(draftFilters.datePreset == preset ? Color(hex: "1D4ED8") : Color(hex: "9CA3AF"))

                                Text(preset.rawValue)
                                    .font(.system(size: 14, weight: draftFilters.datePreset == preset ? .semibold : .regular))
                                    .foregroundStyle(Color(hex: "111827"))

                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
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

    // MARK: - Retailer Section

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
            Text("RETAILER")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "1E40AF"))
                .tracking(0.8)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "9CA3AF"))

                TextField("Search retailers...", text: $retailerSearchText)
                    .font(.system(size: 13))

                if !retailerSearchText.isEmpty {
                    Button {
                        retailerSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "9CA3AF"))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "F9FAFB"))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "E5E7EB"), lineWidth: 1))
            .padding(.horizontal, 16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Button {
                        draftFilters.sellerId = nil
                        draftFilters.sellerName = nil
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: (draftFilters.sellerId == nil || draftFilters.sellerId?.isEmpty == true) ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle((draftFilters.sellerId == nil || draftFilters.sellerId?.isEmpty == true) ? Color(hex: "1D4ED8") : Color(hex: "9CA3AF"))

                            Text("All Retailers")
                                .font(.system(size: 14, weight: (draftFilters.sellerId == nil || draftFilters.sellerId?.isEmpty == true) ? .semibold : .regular))
                                .foregroundStyle(Color(hex: "111827"))

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    if isLoadingSellers && sellerList.isEmpty {
                        ProgressView()
                            .tint(Color(hex: "1D4ED8"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(filteredSellers) { seller in
                            let sId = String(seller.id)
                            let isSelected = draftFilters.sellerId == sId

                            Button {
                                draftFilters.sellerId = sId
                                draftFilters.sellerName = seller.shopName.isEmpty ? seller.name : seller.shopName
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(isSelected ? Color(hex: "1D4ED8") : Color(hex: "9CA3AF"))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(seller.shopName.isEmpty ? seller.name : seller.shopName)
                                            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                            .foregroundStyle(Color(hex: "111827"))

                                        if !seller.name.isEmpty && !seller.shopName.isEmpty && seller.name != seller.shopName {
                                            Text(seller.name)
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color(hex: "6B7280"))
                                        }
                                    }

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button {
                onReset()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Use Default")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color(hex: "374151"))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                onApply(draftFilters)
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                    Text("Apply Filters")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Color(hex: "1D4ED8"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
    }
}
