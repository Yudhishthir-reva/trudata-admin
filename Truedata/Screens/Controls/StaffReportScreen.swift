//
//  StaffReportScreen.swift
//  Truedata
//

import SwiftUI

struct StaffReportScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StaffReportViewModel()
    @State private var selectedMember: SalesmanStaffMember?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Staff Reports",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load(isRefresh: true) }
                )

                searchBar
                content
            }

            if viewModel.isLoading && viewModel.staffMembers.isEmpty {
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load() }
        .navigationDestination(item: $selectedMember) { member in
            StaffProfileScreen(context: StaffProfileContext(member: member))
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField("Type to search team members...", text: $viewModel.searchText)
                .font(.system(size: 15))
            if !viewModel.searchText.isEmptyString {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "F7F8FA"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage, viewModel.staffMembers.isEmpty {
            errorView(error)
        } else if viewModel.filteredMembers.isEmpty && !viewModel.isLoading {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredMembers) { member in
                        Button {
                            selectedMember = member
                        } label: {
                            StaffReportMemberRow(member: member)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .padding(.bottom, 24)
            }
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text(error)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            PrimaryActionButton(title: "Retry") {
                viewModel.load(isRefresh: true)
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.5))
            Text("No team members found")
                .font(.system(size: 15))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Spacer()
        }
    }
}

private struct StaffReportMemberRow: View {
    let member: SalesmanStaffMember

    var body: some View {
        HStack(spacing: 12) {
            profileImage

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)

                Text(member.roleId)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            attendanceBadge
        }
        .padding(12)
        .background(Color(hex: "F7F8FA"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var profileImage: some View {
        Group {
            if member.profilePic.isEmptyString {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.45))
            } else {
                RemoteImage(url: member.profilePic, contentMode: .fill)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .background(Circle().fill(DashboardTheme.surfaceVariant))
    }

    private var attendanceBadge: some View {
        Text(member.attendanceLabel)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(member.isPresent ? DashboardTheme.successGreen : DashboardTheme.dangerRed)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                (member.isPresent ? DashboardTheme.successGreen : DashboardTheme.dangerRed)
                    .opacity(0.12)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
