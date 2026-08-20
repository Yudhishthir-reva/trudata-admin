//
//  BeatCommonViews.swift
//  Truedata
//

import SwiftUI

struct BeatListCard: View {
    let beat: BeatListItem
    var onEdit: () -> Void
    var onDelete: () -> Void

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
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 20))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(beat.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(2)

                    Text(beat.locationText)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)

                    Text("Created: \(beat.createdDateText)")
                        .font(.system(size: 10))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(beat.isActive ? "Active" : "Inactive")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(beat.isActive ? DashboardTheme.successGreen : DashboardTheme.neutralMedium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (beat.isActive ? DashboardTheme.successGreen : DashboardTheme.neutralMedium).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(12)

            Divider()

            HStack(spacing: 0) {
                BeatActionButton(title: "Edit", color: DashboardTheme.primaryBlue, action: onEdit)
                BeatVerticalDivider()
                BeatActionButton(title: "Delete", color: DashboardTheme.dangerRed, action: onDelete)
            }
            .frame(height: 40)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }
}

private struct BeatActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct BeatVerticalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: "E5E7EB"))
            .frame(width: 1)
    }
}

struct BeatFormSheet: View {
    @Binding var form: BeatFormData
    let areas: [OrderInsightsStateArea]
    let availableCities: [OrderInsightsCityArea]
    let isLoading: Bool
    var onSelectState: (OrderInsightsStateArea) -> Void
    var onSelectCity: (OrderInsightsCityArea) -> Void
    var onSave: () -> Void
    var onDismiss: () -> Void

    @State private var showStatePicker = false
    @State private var showCityPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Beat Name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        TextField("Beat Name", text: $form.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    pickerField(
                        label: "State",
                        value: form.stateName.isEmptyString ? "Select State" : form.stateName,
                        isPlaceholder: form.stateName.isEmptyString
                    ) {
                        showStatePicker = true
                    }

                    pickerField(
                        label: "City",
                        value: form.cityName.isEmptyString ? "Select City" : form.cityName,
                        isPlaceholder: form.cityName.isEmptyString,
                        isEnabled: !form.stateId.isEmpty
                    ) {
                        showCityPicker = true
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)

                        HStack(spacing: 24) {
                            statusOption(title: "Active", isSelected: form.status == "1") {
                                form.status = "1"
                            }
                            statusOption(title: "Inactive", isSelected: form.status == "0") {
                                form.status = "0"
                            }
                        }
                    }

                    PrimaryActionButton(
                        title: isLoading
                            ? (form.isEditMode ? "Updating..." : "Creating...")
                            : (form.isEditMode ? "Update Beat" : "Create Beat"),
                        isEnabled: !isLoading && form.isValid
                    ) {
                        onSave()
                    }
                }
                .padding(16)
            }
            .navigationTitle(form.isEditMode ? "Edit Beat" : "Add New Beat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if !isLoading { onDismiss() }
                    }
                }
            }
            .sheet(isPresented: $showStatePicker) {
                BeatPickerSheet(
                    title: "Select State",
                    options: areas.map(\.name),
                    onSelect: { name in
                        if let state = areas.first(where: { $0.name == name }) {
                            onSelectState(state)
                        }
                    }
                )
            }
            .sheet(isPresented: $showCityPicker) {
                BeatPickerSheet(
                    title: "Select City",
                    options: availableCities.map(\.name),
                    onSelect: { name in
                        if let city = availableCities.first(where: { $0.name == name }) {
                            onSelectCity(city)
                        }
                    }
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func pickerField(
        label: String,
        value: String,
        isPlaceholder: Bool,
        isEnabled: Bool = true,
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
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
        }
    }

    private func statusOption(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? DashboardTheme.successGreen : DashboardTheme.neutralMedium)
                Text(title)
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct BeatPickerSheet: View {
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
