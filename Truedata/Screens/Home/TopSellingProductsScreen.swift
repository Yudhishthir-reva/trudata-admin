//
//  TopSellingProductsScreen.swift
//  Truedata
//

import SwiftUI

struct TopSellingProductsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TopSellingProductsViewModel
    @State private var showFilterSheet = false

    init(startDate: String? = nil, endDate: String? = nil, sellerId: String = "") {
        _viewModel = StateObject(
            wrappedValue: TopSellingProductsViewModel(
                startDate: startDate,
                endDate: endDate,
                sellerId: sellerId
            )
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                TopSellingProductsAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadProducts(isRefresh: true) },
                    isExporting: viewModel.isExportingExcel,
                    onDownload: { viewModel.exportExcel() }
                )

                searchAndFilterBar
                mainContent
            }

            if viewModel.isLoading && viewModel.products.isEmpty {
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.initialize() }
        .sheet(isPresented: $showFilterSheet) {
            TopSellingProductsFilterSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.excelShareURL != nil },
            set: { isPresented in
                if !isPresented { viewModel.excelShareURL = nil }
            }
        )) {
            if let url = viewModel.excelShareURL {
                ActivityShareSheet(items: [url])
            }
        }
        .alert(
            "Download Failed",
            isPresented: Binding(
                get: { viewModel.exportAlertMessage != nil },
                set: { isPresented in
                    if !isPresented { viewModel.exportAlertMessage = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.exportAlertMessage ?? "")
        }
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search...", text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.updateSearch($0) }
                ))
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if !viewModel.searchText.isEmptyString {
                    Button { viewModel.updateSearch("") } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.neutralMedium.opacity(0.35), lineWidth: 1)
            }

            Button { showFilterSheet = true } label: {
                ZStack(alignment: .topTrailing) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Filter")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color.clear)
                    .overlay {
                        Capsule()
                            .stroke(DashboardTheme.primaryBlue.opacity(0.55), lineWidth: 1)
                    }

                    if viewModel.isFilterActive {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(hex: "F3F4F6"))
    }

    @ViewBuilder
    private var mainContent: some View {
        if let error = viewModel.errorMessage, viewModel.products.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    viewModel.loadProducts(isRefresh: true)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(DashboardTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !viewModel.isLoading && viewModel.products.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Text("No products found")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.products.enumerated()), id: \.element.id) { index, product in
                        TopSellingProductListRow(rank: index + 1, product: product)
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentProduct: product)
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

private struct TopSellingProductsAppBar: View {
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: () -> Void
    var isExporting: Bool
    var onDownload: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("Top Selling Products")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onDownload) {
                Group {
                    if isExporting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 34, height: 34)
            }
            .disabled(isExporting)

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

private struct TopSellingProductListRow: View {
    let rank: Int
    let product: AllTopSellingProductItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(DashboardTheme.neutralMedium.opacity(0.15))
                    .frame(width: 22, height: 22)
                Text("\(rank)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }

            RemoteImage(url: product.imageUrl, contentMode: .fill)
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DashboardTheme.neutralMedium.opacity(0.2), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(2)
                Text("\(product.totalQuantity) Units sold")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(product.totalAmount.currencyLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DashboardTheme.primaryBlue)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.neutralMedium.opacity(0.15), lineWidth: 1)
        }
    }
}
