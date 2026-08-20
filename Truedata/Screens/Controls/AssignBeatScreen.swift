//
//  AssignBeatScreen.swift
//  Truedata
//

import SwiftUI

struct AssignBeatScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AssignBeatViewModel()
    @State private var deleteTarget: AssignedBeatDetailItem?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Assign Beats",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load(reset: true) }
                )

                searchBar
                content
            }

            if !viewModel.isLoading && viewModel.errorMessage == nil {
                AttendanceFloatingAddButton {
                    viewModel.prepareNewAssignment()
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }

            if viewModel.isOperationLoading {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView("Please wait...")
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.loadSupportingDataIfNeeded()
            viewModel.load(reset: true)
        }
        .sheet(isPresented: $viewModel.showAssignSheet) {
            AssignBeatFormSheet(
                form: $viewModel.assignForm,
                staffMembers: viewModel.eligibleStaff,
                beats: viewModel.availableBeats,
                isLoading: viewModel.isOperationLoading,
                isLoadingBeats: viewModel.isLoadingBeats,
                onSelectStaff: { viewModel.selectStaff($0) },
                onToggleBeat: { viewModel.toggleBeatSelection($0) },
                onSubmit: { viewModel.submitAssignment() },
                onDismiss: { viewModel.showAssignSheet = false }
            )
        }
        .alert("Remove Assignment", isPresented: deleteBinding) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Confirm", role: .destructive) {
                if let item = deleteTarget {
                    viewModel.deleteAssignment(item)
                }
                deleteTarget = nil
            }
        } message: {
            if let item = deleteTarget {
                Text("Remove '\(item.beatName)' from this staff member?")
            }
        }
        .alert("Notice", isPresented: toastBinding) {
            Button("OK", role: .cancel) { viewModel.toastMessage = nil }
        } message: {
            Text(viewModel.toastMessage ?? "")
        }
        .alert("Notice", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    private var toastBinding: Binding<Bool> {
        Binding(
            get: { viewModel.toastMessage != nil },
            set: { if !$0 { viewModel.toastMessage = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && viewModel.assignedBeats.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField("Search staff or beat name...", text: $viewModel.searchText)
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.assignedBeats.isEmpty {
            ProgressView("Loading assignments...")
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.assignedBeats.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Try Again") {
                    viewModel.load(reset: true)
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.filteredAssignments.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.filteredAssignments) { staff in
                            AssignedBeatStaffCard(
                                staff: staff,
                                onToggleStatus: { viewModel.toggleAssignmentStatus($0) },
                                onDelete: { deleteTarget = $0 }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 96)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No Assignments Found")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
            Text("Create a new assignment using the + button")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
