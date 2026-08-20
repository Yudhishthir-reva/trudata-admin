//
//  StaffCommonViews.swift
//  Truedata
//

import SwiftUI

struct StaffMemberTabBar: View {
    @Binding var selectedTab: StaffMemberTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(StaffMemberTab.allCases) { tab in
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

struct StaffMemberCard: View {
    let member: RegisteredStaffMember
    let selectedTab: StaffMemberTab
    var onToggleStatus: () -> Void
    var onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(member.name) (\(member.roleId))")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(member.status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(member.isActive ? DashboardTheme.successGreen : DashboardTheme.dangerRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        (member.isActive ? DashboardTheme.successGreen : DashboardTheme.dangerRed).opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            HStack(spacing: 4) {
                Text("City:")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text(member.cityId.isEmptyString ? "—" : member.cityId)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            HStack(spacing: 0) {
                Button(action: onToggleStatus) {
                    Text(selectedTab == .active ? "Deactivate" : "Activate")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "002B45"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 44)

                Button(action: onEdit) {
                    Text("Edit")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "002B45"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(hex: "FAFBFC"))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }
}

struct StaffPickerSheet: View {
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
    }
}
