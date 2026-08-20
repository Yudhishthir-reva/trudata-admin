//
//  SellerReportCommonViews.swift
//  Truedata
//

import SwiftUI

struct SellerReportItemCard: View {
    let seller: SellerReportItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(seller.displayShopName)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Owner: \(seller.name)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(seller.statusLabel)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(seller.isActive ? DashboardTheme.successGreen : DashboardTheme.neutralMedium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        (seller.isActive ? DashboardTheme.successGreen : DashboardTheme.neutralMedium).opacity(0.08)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(
                                (seller.isActive ? DashboardTheme.successGreen : DashboardTheme.neutralMedium).opacity(0.15),
                                lineWidth: 1
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Divider()
                .padding(.vertical, 20)

            VStack(spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    SellerReportDetailItem(
                        icon: "phone.fill",
                        label: "CONTACT",
                        value: seller.mobile
                    )
                    SellerReportDetailItem(
                        icon: "map.fill",
                        label: "BEAT",
                        value: seller.beatName
                    )
                }

                HStack(alignment: .top, spacing: 12) {
                    SellerReportDetailItem(
                        icon: "calendar",
                        label: "REGISTERED ON",
                        value: seller.registeredOnText
                    )
                    SellerReportDetailItem(
                        icon: "person.fill",
                        label: "REGISTERED BY",
                        value: seller.registeredByName.isEmptyString ? "N/A" : seller.registeredByName
                    )
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "E5E7EB").opacity(0.6), lineWidth: 1)
        }
    }
}

private struct SellerReportDetailItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(DashboardTheme.primaryBlue.opacity(0.06))
                    .frame(width: 26, height: 26)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.primaryBlue.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.8))
                    .tracking(0.8)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SellerReportFilterSheet: View {
    @Binding var draftFilters: SellerReportFilters
    let staffMembers: [RegisteredStaffMember]
    let areas: [OrderInsightsStateArea]
    var onApply: () -> Void
    var onReset: () -> Void
    var onDismiss: () -> Void

    @State private var selectedCategory = "Date Range"
    @State private var staffSearch = ""
    @State private var draftStateId: Int?
    @State private var draftCityId: Int?
    @State private var draftBeatId: Int?

    private let categories = ["Date Range", "Registered by", "Beat/Area"]

    private var draftCities: [OrderInsightsCityArea] {
        guard let draftStateId else { return [] }
        return areas.first(where: { $0.id == draftStateId })?.cities ?? []
    }

    private var draftBeats: [OrderInsightsBeatArea] {
        guard let draftCityId else { return [] }
        return areas.flatMap(\.cities).first(where: { $0.id == draftCityId })?.beats ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category)
                                    .font(.system(size: 12, weight: selectedCategory == category ? .bold : .medium))
                                    .foregroundStyle(
                                        selectedCategory == category
                                            ? DashboardTheme.primaryBlue
                                            : DashboardTheme.neutralDark.opacity(0.7)
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                                    .background(selectedCategory == category ? Color.white : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 115)
                    .background(DashboardTheme.surfaceVariant.opacity(0.2))

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            switch selectedCategory {
                            case "Date Range":
                                dateRangeContent
                            case "Registered by":
                                staffContent
                            default:
                                beatContent
                            }
                        }
                        .padding(16)
                    }
                }
                .frame(maxHeight: .infinity)

                HStack(spacing: 12) {
                    Button(action: onReset) {
                        Text("Clear All")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DashboardTheme.primaryBlue.opacity(0.4), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    PrimaryActionButton(title: "Apply Filters", isEnabled: true) {
                        applyDraftFilters()
                        onApply()
                    }
                }
                .padding(16)
            }
            .navigationTitle("Filter Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onDismiss)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            guard let beatId = Int(draftFilters.beatId) else { return }
            for state in areas {
                for city in state.cities {
                    if city.beats.contains(where: { $0.id == beatId }) {
                        draftStateId = state.id
                        draftCityId = city.id
                        draftBeatId = beatId
                        return
                    }
                }
            }
        }
    }

    private var dateRangeContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(AchievementHistoryDatePreset.allCases, id: \.self) { preset in
                filterOption(
                    text: preset.rawValue,
                    isSelected: draftFilters.datePreset == preset
                ) {
                    draftFilters.datePreset = preset
                    if preset != .custom, let range = AchievementHistoryDatePreset.dateRange(for: preset) {
                        draftFilters.startDate = range.start
                        draftFilters.endDate = range.end
                    }
                }
            }

            if draftFilters.datePreset == .custom {
                TargetDatePickerField(label: "Start Date", dateString: draftFilters.startDate) {
                    draftFilters.startDate = $0
                }
                TargetDatePickerField(label: "End Date", dateString: draftFilters.endDate) {
                    draftFilters.endDate = $0
                }
            }
        }
    }

    private var staffContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search name...", text: $staffSearch)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
            }

            filterOption(text: "All Persons", isSelected: draftFilters.staffId.isEmpty) {
                draftFilters.staffId = ""
                draftFilters.staffName = ""
            }

            ForEach(filteredStaff) { staff in
                filterOption(
                    text: staff.name,
                    isSelected: draftFilters.staffId == String(staff.id)
                ) {
                    draftFilters.staffId = String(staff.id)
                    draftFilters.staffName = staff.name
                }
            }
        }
    }

    private var filteredStaff: [RegisteredStaffMember] {
        guard !staffSearch.isEmptyString else { return staffMembers }
        return staffMembers.filter { $0.name.localizedCaseInsensitiveContains(staffSearch) }
    }

    private var beatContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Registered Area")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DashboardTheme.primaryBlue)

            areaPicker(
                label: "State",
                value: draftStateId.flatMap { id in areas.first(where: { $0.id == id })?.name } ?? "Select State",
                options: areas.map { ($0.name, $0.id) },
                onSelect: { _, id in
                    draftStateId = id
                    draftCityId = nil
                    draftBeatId = nil
                },
                onClear: {
                    draftStateId = nil
                    draftCityId = nil
                    draftBeatId = nil
                }
            )

            if draftStateId != nil {
                areaPicker(
                    label: "City",
                    value: draftCityId.flatMap { id in draftCities.first(where: { $0.id == id })?.name } ?? "Select City",
                    options: draftCities.map { ($0.name, $0.id) },
                    onSelect: { _, id in
                        draftCityId = id
                        draftBeatId = nil
                    },
                    onClear: {
                        draftCityId = nil
                        draftBeatId = nil
                    }
                )
            }

            if draftCityId != nil {
                areaPicker(
                    label: "Beat",
                    value: draftBeatId.flatMap { id in draftBeats.first(where: { $0.id == id })?.name } ?? "Select Beat",
                    options: draftBeats.map { ($0.name, $0.id) },
                    onSelect: { name, id in
                        draftBeatId = id
                        draftFilters.beatName = name
                    },
                    onClear: {
                        draftBeatId = nil
                        draftFilters.beatName = ""
                    }
                )
            }
        }
    }

    private func areaPicker(
        label: String,
        value: String,
        options: [(String, Int)],
        onSelect: @escaping (String, Int) -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.1) { name, id in
                Button(name) { onSelect(name, id) }
            }
            if value != "Select State" && value != "Select City" && value != "Select Beat" {
                Button("Clear", role: .destructive, action: onClear)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Text(value)
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
            }
        }
    }

    private func filterOption(text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium.opacity(0.5),
                            lineWidth: 1.5
                        )
                        .frame(width: 18, height: 18)
                    if isSelected {
                        Circle()
                            .fill(DashboardTheme.primaryBlue)
                            .frame(width: 10, height: 10)
                    }
                }
                Text(text)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralDark)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func applyDraftFilters() {
        if draftFilters.datePreset != .custom,
           let range = AchievementHistoryDatePreset.dateRange(for: draftFilters.datePreset) {
            draftFilters.startDate = range.start
            draftFilters.endDate = range.end
        }
        draftFilters.beatId = draftBeatId.map(String.init) ?? ""
        if draftFilters.beatId.isEmpty {
            draftFilters.beatName = ""
        }
    }
}
