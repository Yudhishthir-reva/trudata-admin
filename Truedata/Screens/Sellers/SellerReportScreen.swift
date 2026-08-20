//
//  SellerReportScreen.swift
//  Truedata
//

import SwiftUI

struct SellerReportScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SellerReportViewModel()
    @State private var draftFilters = SellerReportFilters.initialToday()

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Seller Report",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.refresh() }
                )

                headerCard
                content
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadInitial() }
        .sheet(isPresented: $viewModel.showFilterSheet) {
            SellerReportFilterSheet(
                draftFilters: $draftFilters,
                staffMembers: viewModel.staffMembers,
                areas: viewModel.areas,
                onApply: {
                    viewModel.applyFilters(draftFilters)
                    viewModel.showFilterSheet = false
                },
                onReset: {
                    draftFilters = .initialToday()
                    viewModel.resetFilters()
                    viewModel.showFilterSheet = false
                },
                onDismiss: { viewModel.showFilterSheet = false }
            )
        }
        .alert("Notice", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && viewModel.sellers.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var headerCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Registrations")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Text("\(viewModel.total) Sellers")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                Spacer()

                Button {
                    draftFilters = viewModel.filters
                    viewModel.showFilterSheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .frame(width: 44, height: 44)
                            .background(DashboardTheme.primaryBlue.opacity(0.1))
                            .clipShape(Circle())

                        if viewModel.filters.hasActiveFilters {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search by shop name, owner, mobile...", text: $viewModel.searchText)
                    .font(.system(size: 13))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.searchText) { _, value in
                        viewModel.onSearchChanged(value)
                    }
            }
            .padding(.horizontal, 12)
            .frame(height: 52)
            .background(Color(hex: "F3F4F6").opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "E5E7EB").opacity(0.5), lineWidth: 1)
            }
            .padding(.top, 16)

            if viewModel.filters.hasActiveFilters {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DashboardTheme.successGreen)
                    Text("Active Filters")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DashboardTheme.successGreen)
                    Rectangle()
                        .fill(DashboardTheme.successGreen.opacity(0.3))
                        .frame(width: 1, height: 10)
                    Text(viewModel.filters.datePreset.rawValue)
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DashboardTheme.successGreen.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.top, 12)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.sellers.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.sellers.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Try Again") {
                    viewModel.refresh()
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.sellers.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "person")
                    .font(.system(size: 48))
                    .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.4))
                Text("No registrations found")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.sellers) { seller in
                        SellerReportItemCard(seller: seller)
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentSeller: seller)
                            }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(DashboardTheme.primaryBlue)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}
