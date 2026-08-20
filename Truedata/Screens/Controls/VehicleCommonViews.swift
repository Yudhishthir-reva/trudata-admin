//
//  VehicleCommonViews.swift
//  Truedata
//

import SwiftUI

struct VehicleListTabBar: View {
    @Binding var selectedTab: VehicleListTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(VehicleListTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : DashboardTheme.neutralDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? DashboardTheme.primaryBlue : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DashboardTheme.primaryBlue.opacity(isSelected ? 0 : 0.15), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct VehicleCard: View {
    let vehicle: AdminVehicleItem
    var onEdit: () -> Void
    var onHistory: () -> Void
    var onDelete: () -> Void
    var onAssign: () -> Void
    var onUnassign: () -> Void

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
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(2)

                    Text("Model: \(vehicle.model)")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)

                    Text("Plate: \(vehicle.plateNumber)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VehicleUsageBadge(label: vehicle.usageStatusLabel, inUse: vehicle.inUse)
            }
            .padding(12)

            Divider()

            HStack(spacing: 0) {
                VehicleActionButton(title: "Edit", color: DashboardTheme.primaryBlue, action: onEdit)
                VehicleVerticalDivider()
                VehicleActionButton(title: "History", color: DashboardTheme.primaryBlue, action: onHistory)
                VehicleVerticalDivider()
                VehicleActionButton(title: "Delete", color: DashboardTheme.dangerRed, action: onDelete)
                VehicleVerticalDivider()
                if vehicle.isAvailable {
                    VehicleActionButton(title: "Assign", color: DashboardTheme.primaryBlue, action: onAssign)
                } else {
                    VehicleActionButton(title: "Unassign", color: DashboardTheme.dangerRed, action: onUnassign)
                }
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

struct RiderVehicleCard: View {
    let rider: AdminVehicleRider

    var body: some View {
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
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(rider.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Text(rider.mobile)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }

                if rider.hasVehicleAssigned {
                    Text("Vehicle: \(rider.assignedVehicleName ?? "—")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    if let plate = rider.assignedVehiclePlate, !plate.isEmptyString {
                        Text("Plate: \(plate)")
                            .font(.system(size: 10))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                } else {
                    Text("No vehicle assigned")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "F59E0B"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(rider.isActive ? "Active" : "Inactive")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(rider.isActive ? DashboardTheme.successGreen : DashboardTheme.dangerRed)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (rider.isActive ? DashboardTheme.successGreen : DashboardTheme.dangerRed).opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }
}

private struct VehicleUsageBadge: View {
    let label: String
    let inUse: String

    private var color: Color {
        switch inUse {
        case "0": return DashboardTheme.successGreen
        case "1": return Color(hex: "3B82F6")
        case "2": return Color(hex: "F59E0B")
        default: return DashboardTheme.neutralMedium
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            }
    }
}

private struct VehicleActionButton: View {
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

private struct VehicleVerticalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: "E5E7EB"))
            .frame(width: 1)
    }
}

struct AssignVehicleSheet: View {
    let riders: [AdminVehicleRider]
    @Binding var selectedRiderId: String?
    let isLoading: Bool
    var onSubmit: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if riders.isEmpty {
                    Text("No available riders found.")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            Text("Select a rider:")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 4)

                            ForEach(riders) { rider in
                                let riderId = String(rider.id)
                                let isSelected = selectedRiderId == riderId
                                Button {
                                    selectedRiderId = riderId
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                            .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(rider.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(DashboardTheme.neutralDark)
                                            Text("Mobile: \(rider.mobile)")
                                                .font(.system(size: 12))
                                                .foregroundStyle(DashboardTheme.neutralMedium)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(isSelected ? DashboardTheme.primaryBlue.opacity(0.08) : Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }

                PrimaryActionButton(
                    title: isLoading ? "Assigning..." : "Assign Vehicle",
                    isEnabled: !isLoading && selectedRiderId != nil
                ) {
                    onSubmit()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .navigationTitle("Assign Vehicle to Rider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct VehicleFormSheet: View {
    @Binding var form: VehicleFormData
    let isLoading: Bool
    var onSave: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Vehicle Name")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        TextField("Vehicle Name", text: $form.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        TextField("Model", text: $form.model)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Plate Number")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        TextField("Plate Number", text: $form.plateNumber)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)

                        HStack(spacing: 24) {
                            Button {
                                form.status = "1"
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: form.status == "1" ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(DashboardTheme.successGreen)
                                    Text("Active")
                                        .foregroundStyle(DashboardTheme.neutralDark)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                form.status = "0"
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: form.status == "0" ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(DashboardTheme.neutralMedium)
                                    Text("Inactive")
                                        .foregroundStyle(DashboardTheme.neutralDark)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    PrimaryActionButton(
                        title: isLoading
                            ? (form.isEditMode ? "Updating..." : "Creating...")
                            : (form.isEditMode ? "Update Vehicle" : "Create Vehicle"),
                        isEnabled: !isLoading
                    ) {
                        onSave()
                    }
                }
                .padding(16)
            }
            .navigationTitle(form.isEditMode ? "Edit Vehicle" : "Add New Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if !isLoading { onDismiss() }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct VehicleHistoryHeaderCard: View {
    let vehicle: AdminVehicleItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(vehicle.plateNumber)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            HStack {
                historyStat(label: "Model", value: vehicle.model)
                Spacer()
                historyStat(label: "Status", value: vehicle.usageStatusLabel)
                Spacer()
                historyStat(label: "Created", value: formatVehicleDate(vehicle.createdAt))
            }
        }
        .padding(16)
        .background(DashboardTheme.primaryBlue)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func historyStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

struct VehicleHistoryLogRow: View {
    let log: VehicleHistoryLog
    let isLast: Bool

    private var statusColor: Color {
        switch log.inUse {
        case "1": return Color(hex: "F59E0B")
        case "2": return DashboardTheme.primaryBlue
        case "0": return DashboardTheme.successGreen
        default: return DashboardTheme.neutralMedium
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                if !isLast {
                    Rectangle()
                        .fill(Color(hex: "E5E7EB"))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(log.statusLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)

                if let rider = log.rider {
                    Text("Rider: \(rider.name)")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }

                Text(formatVehicleDate(log.dateTime.isEmptyString ? log.createdAt : log.dateTime))
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            .padding(.bottom, isLast ? 0 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private func formatVehicleDate(_ value: String) -> String {
    guard !value.isEmptyString else { return "—" }
    let inputFormats = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
        "yyyy-MM-dd'T'HH:mm:ss'Z'"
    ]
    let output = DateFormatter()
    output.dateFormat = "dd MMM yyyy, hh:mm a"

    for format in inputFormats {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        if let date = formatter.date(from: value) {
            return output.string(from: date)
        }
    }
    return value
}
