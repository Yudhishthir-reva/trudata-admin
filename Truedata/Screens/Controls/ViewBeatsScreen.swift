//
//  ViewBeatsScreen.swift
//  Truedata
//

import SwiftUI

struct ViewBeatsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ViewBeatsViewModel()
    @State private var deleteTarget: BeatListItem?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "View Beats",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load(reset: true) }
                )

                searchBar
                content
            }

            if !viewModel.isLoading && viewModel.errorMessage == nil {
                AttendanceFloatingAddButton {
                    viewModel.prepareAddBeat()
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
            viewModel.loadAreasIfNeeded()
            viewModel.load(reset: true)
        }
        .sheet(isPresented: $viewModel.showBeatForm) {
            BeatFormSheet(
                form: $viewModel.beatForm,
                areas: viewModel.areas,
                availableCities: viewModel.availableCities,
                isLoading: viewModel.isSaving,
                onSelectState: { viewModel.selectState($0) },
                onSelectCity: { viewModel.selectCity($0) },
                onSave: { viewModel.saveBeat() },
                onDismiss: { viewModel.showBeatForm = false }
            )
        }
        .alert("Delete Beat", isPresented: deleteBinding) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Confirm", role: .destructive) {
                if let beat = deleteTarget {
                    viewModel.deleteBeat(beat)
                }
                deleteTarget = nil
            }
        } message: {
            if let beat = deleteTarget {
                Text("Are you sure you want to delete '\(beat.name)'?")
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
            get: { viewModel.errorMessage != nil && viewModel.beats.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var searchBar: some View {
        AppSearchBar(
            placeholder: "Search beats or locations...",
            text: $viewModel.searchText
        )
    }

    @ViewBuilder
    private var content: some View {
        AppContentState(
            isLoading: viewModel.isLoading,
            loadingMessage: "Loading beats...",
            errorMessage: viewModel.errorMessage,
            hasNoLoadedData: viewModel.beats.isEmpty,
            retryTitle: "Try Again",
            onRetry: { viewModel.load(reset: true) }
        ) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.filteredBeats.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.filteredBeats) { beat in
                            BeatListCard(
                                beat: beat,
                                onEdit: { viewModel.prepareEditBeat(beat) },
                                onDelete: { deleteTarget = beat }
                            )
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentBeat: beat)
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
            Text("No Beats Found")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
            Text("Add your first beat using the + button")
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
