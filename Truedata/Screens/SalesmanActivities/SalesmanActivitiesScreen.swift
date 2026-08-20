//
//  SalesmanActivitiesScreen.swift
//  Truedata
//

import SwiftUI

struct SalesmanActivitiesScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SalesmanActivitiesViewModel()

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SalesmanActivitiesAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadStaff(isRefresh: true) }
                )

                content
            }

            if viewModel.isLoading && viewModel.staffMembers.isEmpty {
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadStaff() }
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage, viewModel.staffMembers.isEmpty {
            errorView(error)
        } else if viewModel.staffMembers.isEmpty && !viewModel.isLoading {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.staffMembers) { member in
                        NavigationLink {
                            SalesmanActivityDetailScreen(
                                staffId: member.resolvedStaffId,
                                staffName: member.name
                            )
                        } label: {
                            SalesmanStaffRow(member: member)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DashboardTheme.dangerRed)
            Text(error)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                viewModel.loadStaff(isRefresh: true)
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(DashboardTheme.primaryBlue)
            .clipShape(Capsule())
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.6))
            Text("No staff members found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
            Spacer()
        }
    }
}

// MARK: - App Bar

private struct SalesmanActivitiesAppBar: View {
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("Salesman Activities")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }

            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
    }
}

// MARK: - Staff Row

private struct SalesmanStaffRow: View {
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
