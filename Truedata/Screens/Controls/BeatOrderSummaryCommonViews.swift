//
//  BeatOrderSummaryCommonViews.swift
//  Truedata
//

import SwiftUI

struct BeatSummaryOverallCard: View {
    let summary: BeatOverallSummary

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Order Value")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Text(formatCurrency(summary.totalOrderAmount))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Settled Value")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Text(formatCurrency(summary.totalSettledAmount))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Divider().overlay(Color.white.opacity(0.15))

            HStack {
                summaryStat(label: "Beats", value: "\(summary.totalBeats)")
                Spacer()
                summaryStat(label: "Orders", value: "\(summary.totalOrders)")
                Spacer()
                summaryStat(label: "Delivered", value: "\(summary.totalDeliveredOrders)")
                Spacer()
                summaryStat(label: "Cancelled", value: "\(summary.totalCancelledOrders)")
                Spacer()
                summaryStat(label: "Out of range", value: "\(summary.outOfRangeOrders)")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(DashboardTheme.primaryBlue)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: DashboardTheme.primaryBlue.opacity(0.25), radius: 8, y: 4)
    }

    private func summaryStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        String(amount).priceLabel
    }
}

struct BeatSummaryItemCard: View {
    let beat: BeatSummaryItem
    var onViewOrders: ([String]) -> Void
    var onViewStaffOrders: (String, [String]) -> Void

    @State private var expanded = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    expanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(DashboardTheme.primaryBlue.opacity(0.08))
                            .frame(width: 36, height: 36)
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(beat.beatName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .lineLimit(1)
                        Text(beat.activeBeatStaff)
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .lineLimit(1)
                        if !beat.locationText.isEmpty {
                            Text(beat.locationText)
                                .font(.system(size: 11))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            HStack {
                beatQuickStat(label: "Placed", value: "\(beat.placedOrders.count)", color: DashboardTheme.primaryBlue)
                Spacer()
                beatQuickStat(
                    label: "Order Value",
                    value: String(format: "₹%.2f", beat.placedOrders.totalAmount),
                    color: DashboardTheme.neutralDark
                )
                Spacer()
                beatQuickStat(
                    label: "Collected Value",
                    value: String(format: "₹%.2f", beat.placedOrders.totalCollectedAmount),
                    color: DashboardTheme.neutralDark
                )
                Spacer()
                beatQuickStat(label: "Cancelled", value: "\(beat.cancelledOrders.count)", color: DashboardTheme.dangerRed)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(DashboardTheme.surfaceVariant.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            if expanded {
                VStack(spacing: 10) {
                    if !beat.placedOrders.orderIds.isEmpty {
                        Button("View All Beat Orders") {
                            onViewOrders(beat.placedOrders.orderIds)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()
                    }

                    Text("STAFF BREAKDOWN")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if beat.staffWiseBreakdown.isEmpty {
                        Text("No activity recorded.")
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(beat.staffWiseBreakdown) { staff in
                            BeatSummaryStaffRow(staff: staff) {
                                onViewStaffOrders(staff.staffName, staff.orderIds)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }

    private func beatQuickStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
    }
}

private struct BeatSummaryStaffRow: View {
    let staff: BeatStaffBreakdownItem
    var onViewOrders: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(DashboardTheme.surfaceVariant)
                    .frame(width: 28, height: 28)
                Text(staff.staffName.prefix(1).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(staff.staffName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text("Orders: \(staff.totalOrders)")
                    .font(.system(size: 10))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(Int(staff.totalAmount))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DashboardTheme.successGreen)
                if !staff.orderIds.isEmpty {
                    Button("View Orders", action: onViewOrders)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
            }
        }
    }
}

struct BeatSummaryOrderListSheet: View {
    let title: String
    let orderIds: [String]
    var onSelectOrder: (String) -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                if orderIds.isEmpty {
                    Text("No orders available")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(orderIds, id: \.self) { orderId in
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(DashboardTheme.primaryBlue)
                                    Text(orderId)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(DashboardTheme.neutralDark)
                                }
                                Spacer()
                                Button {
                                    onSelectOrder(orderId)
                                } label: {
                                    HStack(spacing: 2) {
                                        Text("View")
                                            .font(.system(size: 11, weight: .bold))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 8, weight: .bold))
                                    }
                                    .foregroundStyle(DashboardTheme.primaryBlue)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(DashboardTheme.surfaceVariant.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", action: onDismiss)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct BeatSummaryFilterSheet: View {
    @Binding var draftFilters: BeatSummaryFilters
    let beatOptions: [BeatSummaryBeatOption]
    let staffMembers: [RegisteredStaffMember]
    var onApply: () -> Void
    var onReset: () -> Void
    var onDismiss: () -> Void

    @State private var showBeatPicker = false
    @State private var showStaffPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Date Range")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(AchievementHistoryDatePreset.selectablePresets) { preset in
                            Button {
                                draftFilters.datePreset = preset
                                if let range = AchievementHistoryDatePreset.dateRange(for: preset) {
                                    draftFilters.startDate = range.start
                                    draftFilters.endDate = range.end
                                }
                            } label: {
                                Text(preset.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(
                                        draftFilters.datePreset == preset ? .white : DashboardTheme.neutralDark
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        draftFilters.datePreset == preset
                                            ? DashboardTheme.primaryBlue
                                            : DashboardTheme.surfaceVariant
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
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

                    pickerField(
                        label: "Beat",
                        value: draftFilters.beatName.isEmpty ? "All Beats" : draftFilters.beatName,
                        isPlaceholder: draftFilters.beatName.isEmpty
                    ) {
                        showBeatPicker = true
                    }

                    pickerField(
                        label: "Staff",
                        value: draftFilters.staffName.isEmpty ? "All Staff" : draftFilters.staffName,
                        isPlaceholder: draftFilters.staffName.isEmpty
                    ) {
                        showStaffPicker = true
                    }

                    HStack(spacing: 12) {
                        Button("Reset", action: onReset)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(DashboardTheme.neutralMedium.opacity(0.4), lineWidth: 1)
                            }

                        PrimaryActionButton(title: "Apply", action: onApply)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                }
            }
            .sheet(isPresented: $showBeatPicker) {
                BeatSummaryOptionPickerSheet(
                    title: "Select Beat",
                    options: [("All Beats", "")] + beatOptions.map { ($0.displayName, $0.id) },
                    onSelect: { name, id in
                        draftFilters.beatId = id
                        draftFilters.beatName = id.isEmpty ? "" : name
                    }
                )
            }
            .sheet(isPresented: $showStaffPicker) {
                BeatSummaryOptionPickerSheet(
                    title: "Select Staff",
                    options: [("All Staff", "")] + staffMembers.map { ($0.name, String($0.id)) },
                    onSelect: { name, id in
                        draftFilters.staffId = id
                        draftFilters.staffName = id.isEmpty ? "" : name
                    }
                )
            }
        }
        .presentationDetents([.large])
    }

    private func pickerField(
        label: String,
        value: String,
        isPlaceholder: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
            Button(action: action) {
                HStack {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(isPlaceholder ? DashboardTheme.neutralMedium : DashboardTheme.neutralDark)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct BeatSummaryOptionPickerSheet: View {
    let title: String
    let options: [(String, String)]
    let onSelect: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [(String, String)] {
        guard !search.isEmptyString else { return options }
        return options.filter { $0.0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.1) { option in
                Button(option.0) {
                    onSelect(option.0, option.1)
                    dismiss()
                }
                .foregroundStyle(AppTheme.darkMidnightBlue)
            }
            .searchable(text: $search, prompt: "Search")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
