//
//  RegisteredStaffListScreen.swift
//  Truedata
//

import SwiftUI

struct RegisteredStaffListScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RegisteredStaffListViewModel()
    @State private var statusDialog: (title: String, message: String)?
    @State private var editTarget: RegisteredStaffMember?

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Registered Staff Members",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load() }
                )

                StaffMemberTabBar(selectedTab: $viewModel.selectedTab)
                searchBar
                content
            }

            if viewModel.isUpdatingStatus {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView("Updating...")
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load() }
        .navigationDestination(item: $editTarget) { member in
            AddStaffScreen(editMember: member)
        }
        .alert(statusDialog?.title ?? "Confirm", isPresented: statusDialogBinding) {
            Button("No", role: .cancel) {
                viewModel.cancelStatusUpdate()
                statusDialog = nil
            }
            Button("Yes") {
                viewModel.confirmStatusUpdate()
                statusDialog = nil
            }
        } message: {
            if let dialog = statusDialog {
                Text(dialog.message)
            }
        }
        .alert("Notice", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var statusDialogBinding: Binding<Bool> {
        Binding(
            get: { statusDialog != nil },
            set: { if !$0 { statusDialog = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && viewModel.staffMembers.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var searchBar: some View {
        AppSearchBar(
            placeholder: "Search staff members...",
            text: $viewModel.searchText,
            verticalPadding: 0
        )
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var content: some View {
        AppContentState(
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            hasNoLoadedData: viewModel.staffMembers.isEmpty,
            isEmpty: viewModel.filteredMembers.isEmpty,
            onRetry: { viewModel.load() },
            empty: {
                Text(emptyMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            },
            content: {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.filteredMembers) { member in
                            StaffMemberCard(
                                member: member,
                                selectedTab: viewModel.selectedTab,
                                onToggleStatus: {
                                    viewModel.requestStatusUpdate(for: member)
                                    statusDialog = viewModel.statusDialog(for: member)
                                },
                                onEdit: { editTarget = member }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        )
    }

    private var emptyMessage: String {
        if !viewModel.searchText.isEmptyString {
            return "No \(viewModel.selectedTab.rawValue.lowercased()) members found matching \"\(viewModel.searchText)\"."
        }
        return "No \(viewModel.selectedTab.rawValue.lowercased()) members found."
    }
}
