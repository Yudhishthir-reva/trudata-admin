//
//  ExpenseListScreen.swift
//  Truedata
//

import SwiftUI

struct ExpenseListScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ExpenseViewModel()
    @State private var showAddExpense = false
    @State private var pendingAction: ExpenseStatusAction?
    @State private var previewImageURL: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Expense Requests",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load() }
                )

                AttendanceRequestTabBar(selectedTab: $viewModel.selectedTab)
                content
            }

            if !viewModel.isLoading && viewModel.errorMessage == nil {
                AttendanceFloatingAddButton {
                    showAddExpense = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
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
        .navigationDestination(isPresented: $showAddExpense) {
            AddExpenseScreen(onSubmitted: { viewModel.load() })
        }
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
        .sheet(isPresented: previewImageBinding) {
            if let url = previewImageURL {
                ExpenseImagePreviewSheet(imageURL: url)
            }
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

    private var previewImageBinding: Binding<Bool> {
        Binding(get: { previewImageURL != nil }, set: { if !$0 { previewImageURL = nil } })
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
            Text("No expense requests found for this category.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredItems) { item in
                        ExpenseRequestCard(
                            item: item,
                            indicatorColor: viewModel.selectedTab.indicatorColor,
                            showActions: viewModel.selectedTab == .pending,
                            onApprove: {
                                pendingAction = ExpenseStatusAction(
                                    expenseId: item.id,
                                    staffId: item.staffId,
                                    staffName: item.staffName,
                                    amount: item.amountLabel,
                                    remark: item.remark,
                                    approve: true
                                )
                            },
                            onReject: {
                                pendingAction = ExpenseStatusAction(
                                    expenseId: item.id,
                                    staffId: item.staffId,
                                    staffName: item.staffName,
                                    amount: item.amountLabel,
                                    remark: item.remark,
                                    approve: false
                                )
                            },
                            onImageTap: {
                                if let image = item.expenseImage, item.hasImage {
                                    previewImageURL = image
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 88)
            }
        }
    }
}

private struct ExpenseRequestCard: View {
    let item: ExpenseItem
    let indicatorColor: Color
    let showActions: Bool
    var onApprove: () -> Void
    var onReject: () -> Void
    var onImageTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(indicatorColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.amountLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                        Text(item.expenseDate.isEmpty ? "N/A" : item.expenseDate)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if item.hasImage, let imageURL = item.expenseImage {
                        Button(action: onImageTap) {
                            RemoteImage(url: imageURL, contentMode: .fill)
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !item.staffName.isEmpty {
                    Text("Staff: \(item.staffName)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.darkMidnightBlue)
                }

                if !item.remark.isEmpty {
                    Text("Remark: \(item.remark)")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                if showActions {
                    HStack(spacing: 10) {
                        Button(action: onReject) {
                            Text("Reject")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DashboardTheme.dangerRed)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(DashboardTheme.dangerRed.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button(action: onApprove) {
                            Text("Approve")
                                .font(.system(size: 14, weight: .semibold))
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
}

private struct ExpenseImagePreviewSheet: View {
    let imageURL: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                RemoteImage(url: imageURL, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .background(Color.black)
            .navigationTitle("Expense Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
