//
//  AssignBeatCommonViews.swift
//  Truedata
//

import SwiftUI

struct AssignedBeatStaffCard: View {
    let staff: AssignedBeatStaffItem
    var onToggleStatus: (AssignedBeatDetailItem) -> Void
    var onDelete: (AssignedBeatDetailItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DashboardTheme.primaryBlue.opacity(0.12),
                                    Color(hex: "8B5CF6").opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(staff.staffName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(2)

                    Text("\(staff.activeBeatCount) active · \(staff.beatData.count) total beats")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)

            if staff.beatData.isEmpty {
                Text("No beats assigned")
                    .font(.system(size: 13))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            } else {
                Divider()
                VStack(spacing: 0) {
                    ForEach(staff.beatData) { beat in
                        AssignedBeatRow(
                            beat: beat,
                            onToggleStatus: { onToggleStatus(beat) },
                            onDelete: { onDelete(beat) }
                        )
                        if beat.id != staff.beatData.last?.id {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }
}

private struct AssignedBeatRow: View {
    let beat: AssignedBeatDetailItem
    var onToggleStatus: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.primaryBlue)
                .frame(width: 20)

            Text(beat.beatName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)

            Toggle("", isOn: Binding(
                get: { beat.isActive },
                set: { _ in onToggleStatus() }
            ))
            .labelsHidden()
            .tint(DashboardTheme.successGreen)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.dangerRed)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct AssignBeatFormSheet: View {
    @Binding var form: AssignBeatFormState
    let staffMembers: [RegisteredStaffMember]
    let beats: [BeatListItem]
    let isLoading: Bool
    let isLoadingBeats: Bool
    var onSelectStaff: (RegisteredStaffMember) -> Void
    var onToggleBeat: (String) -> Void
    var onSubmit: () -> Void
    var onDismiss: () -> Void

    @State private var showStaffPicker = false
    @State private var beatSearch = ""

    private var filteredBeats: [BeatListItem] {
        let query = beatSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return beats }
        return beats.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    pickerField(
                        label: "Staff Member",
                        value: form.selectedStaffName.isEmpty ? "Select Staff" : form.selectedStaffName,
                        isPlaceholder: form.selectedStaffName.isEmpty
                    ) {
                        showStaffPicker = true
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Select Beats")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DashboardTheme.neutralDark)
                            Spacer()
                            if !form.selectedBeatIds.isEmpty {
                                Text("\(form.selectedBeatIds.count) selected")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(DashboardTheme.primaryBlue)
                            }
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(DashboardTheme.neutralMedium)
                            TextField("Search beats...", text: $beatSearch)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                        }

                        if isLoadingBeats {
                            ProgressView("Loading beats...")
                                .tint(DashboardTheme.primaryBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else if filteredBeats.isEmpty {
                            Text("No beats available")
                                .font(.system(size: 14))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(filteredBeats) { beat in
                                    AssignBeatSelectionRow(
                                        beat: beat,
                                        isSelected: form.selectedBeatIds.contains(String(beat.id)),
                                        onToggle: { onToggleBeat(String(beat.id)) }
                                    )
                                    if beat.id != filteredBeats.last?.id {
                                        Divider().padding(.leading, 44)
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                            }
                        }
                    }

                    PrimaryActionButton(
                        title: isLoading ? "Assigning..." : "Confirm Assignment",
                        isEnabled: !isLoading && form.isValid
                    ) {
                        onSubmit()
                    }
                }
                .padding(16)
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if !isLoading { onDismiss() }
                    }
                }
            }
            .sheet(isPresented: $showStaffPicker) {
                AssignBeatPickerSheet(
                    title: "Select Staff",
                    options: staffMembers.map(\.name),
                    onSelect: { name in
                        if let staff = staffMembers.first(where: { $0.name == name }) {
                            onSelectStaff(staff)
                        }
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

private struct AssignBeatSelectionRow: View {
    let beat: BeatListItem
    let isSelected: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)

                VStack(alignment: .leading, spacing: 2) {
                    Text(beat.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(2)
                    Text(beat.locationText)
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

private struct AssignBeatPickerSheet: View {
    let title: String
    let options: [String]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [String] {
        guard !search.isEmptyString else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { option in
                Button(option) {
                    onSelect(option)
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
