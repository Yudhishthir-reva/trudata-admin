//
//  ViewTargetsScreen.swift
//  Truedata
//

import SwiftUI

struct ViewTargetsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ViewTargetsViewModel()
    @State private var deleteTarget: SalesTargetItem?
    @State private var historyTarget: TargetHistoryContext?
    @State private var draftFilters = TargetFilters()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "View Targets",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load(reset: true) }
                )

                searchAndFilterBar
                content
            }

            if !viewModel.isLoading && viewModel.errorMessage == nil {
                TargetCreateFloatingButton {
                    viewModel.prepareCreateTarget()
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }

            if viewModel.isSaving {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView("Saving...")
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.loadStaffIfNeeded()
            viewModel.load(reset: true)
        }
        .navigationDestination(item: $historyTarget) { context in
            TargetHistoryScreen(targetId: context.targetId, staffName: context.staffName)
        }
        .sheet(isPresented: $viewModel.showTargetForm) {
            TargetFormSheet(
                form: $viewModel.targetForm,
                staffMembers: viewModel.eligibleStaff,
                isLoading: viewModel.isSaving,
                onMonthChange: { viewModel.updateMonth($0) },
                onSave: { viewModel.saveTarget() },
                onDismiss: { viewModel.showTargetForm = false }
            )
        }
        .sheet(isPresented: $viewModel.showFilterSheet) {
            TargetFilterSheet(
                draftFilters: $draftFilters,
                staffMembers: viewModel.eligibleStaff,
                onApply: {
                    viewModel.applyFilters(draftFilters)
                    viewModel.showFilterSheet = false
                },
                onReset: {
                    draftFilters = TargetFilters()
                    viewModel.resetFilters()
                    viewModel.showFilterSheet = false
                },
                onDismiss: { viewModel.showFilterSheet = false }
            )
            .onAppear { draftFilters = viewModel.filters }
        }
        .alert("Delete Target", isPresented: deleteBinding) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Confirm", role: .destructive) {
                if let target = deleteTarget {
                    viewModel.deleteTarget(target)
                }
                deleteTarget = nil
            }
        } message: {
            if let target = deleteTarget {
                Text("Are you sure you want to delete the target for \(target.staffName)?")
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
            get: { viewModel.errorMessage != nil && viewModel.targets.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search by staff name...", text: $viewModel.searchText)
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
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.primaryBlue.opacity(0.35), lineWidth: 1)
            }

            Button {
                viewModel.showFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(width: 48, height: 48)
                        .background(DashboardTheme.primaryBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DashboardTheme.primaryBlue.opacity(0.2), lineWidth: 1)
                        }

                    if viewModel.filters.isActive {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.targets.isEmpty {
            ProgressView("Loading targets...")
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.targets.isEmpty {
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
                    if viewModel.filteredTargets.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.filteredTargets) { target in
                            SalesTargetCard(
                                target: target,
                                onEdit: { viewModel.prepareEditTarget(target) },
                                onHistory: {
                                    historyTarget = TargetHistoryContext(
                                        targetId: target.id,
                                        staffName: target.staffName
                                    )
                                },
                                onDelete: { deleteTarget = target }
                            )
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentTarget: target)
                            }
                        }

                        if viewModel.isLoadingMore {
                            ProgressView()
                                .tint(DashboardTheme.primaryBlue)
                                .padding(.vertical, 16)
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
            Image(systemName: viewModel.searchText.isEmpty ? "flag.fill" : "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.5))
            Text(viewModel.searchText.isEmpty ? "No sales targets found" : "No matches found")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
            Text(viewModel.searchText.isEmpty ? "Create a new target to get started" : "Try adjusting your search query")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
