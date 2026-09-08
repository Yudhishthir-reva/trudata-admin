//
//  RegularizeApprovalScreen.swift
//  Truedata
//

import SwiftUI

struct RegularizeApprovalScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RegularizeApprovalViewModel()
    @State private var pendingAction: RegularizeStatusAction?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Regularization Requests",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load() }
                )

                AttendanceRequestTabBar(selectedTab: $viewModel.selectedTab)
                content
            }

            if viewModel.isUpdating {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView("Updating...")
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load() }
        .alert(
            pendingAction?.title ?? "Confirm",
            isPresented: pendingActionBinding
        ) {
            Button("No", role: .cancel) {
                pendingAction = nil
            }
            Button("Yes") {
                if let action = pendingAction {
                    viewModel.updateStatus(action)
                }
                pendingAction = nil
            }
        } message: {
            if let action = pendingAction {
                Text(action.message)
            }
        }
        .alert("Success", isPresented: successBinding) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var pendingActionBinding: Binding<Bool> {
        Binding(
            get: { pendingAction != nil && !viewModel.isUpdating },
            set: { if !$0 { pendingAction = nil } }
        )
    }

    private var successBinding: Binding<Bool> {
        Binding(get: { viewModel.successMessage != nil }, set: { if !$0 { viewModel.successMessage = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !viewModel.items.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.load()
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredItems.isEmpty {
            Text("No \(viewModel.selectedTab.rawValue.lowercased()) requests found.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredItems) { item in
                        RegularizeApprovalRequestCard(
                            item: item,
                            indicatorColor: viewModel.selectedTab.indicatorColor,
                            showActions: viewModel.selectedTab == .pending,
                            onApprove: {
                                pendingAction = RegularizeStatusAction(
                                    regularizeId: item.id,
                                    staffId: item.userId,
                                    staffName: item.displayName,
                                    approve: true
                                )
                            },
                            onReject: {
                                pendingAction = RegularizeStatusAction(
                                    regularizeId: item.id,
                                    staffId: item.userId,
                                    staffName: item.displayName,
                                    approve: false
                                )
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct RegularizeApprovalRequestCard: View {
    let item: RegularizeTeamWiseItem
    let indicatorColor: Color
    let showActions: Bool
    var onApprove: () -> Void
    var onReject: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(indicatorColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                Text(item.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)

                infoRow(label: "Date:", value: item.date.isEmpty ? "N/A" : item.date)
                infoRow(label: "Reason:", value: item.remark.isEmpty ? "N/A" : item.remark)

                if showActions {
                    HStack(spacing: 10) {
                        Button(action: onReject) {
                            Text("Reject Regularization")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DashboardTheme.dangerRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(DashboardTheme.dangerRed.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button(action: onApprove) {
                            Text("Approve Regularization")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(DashboardTheme.successGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}
