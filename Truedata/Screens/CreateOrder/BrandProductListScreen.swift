//
//  BrandProductListScreen.swift
//  Truedata
//

import SwiftUI

struct BrandProductListScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BrandProductListViewModel

    private let editOrderViewModel: EditOrderViewModel?
    private let onViewCart: (() -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(
        sellerId: Int,
        brandId: Int,
        brandName: String,
        isEditMode: Bool = false,
        editOrderViewModel: EditOrderViewModel? = nil,
        onViewCart: (() -> Void)? = nil
    ) {
        self.editOrderViewModel = editOrderViewModel
        self.onViewCart = onViewCart
        _viewModel = StateObject(
            wrappedValue: BrandProductListViewModel(
                sellerId: sellerId,
                brandId: brandId,
                brandName: brandName,
                isEditMode: isEditMode
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            CreateOrderAppBar(
                title: viewModel.brandName,
                onBack: { dismiss() },
                onHome: { dismiss() },
                onRefresh: { viewModel.loadProducts() }
            )

            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(Color.white)

                ZStack {
                    Color(hex: "F3F4F6").ignoresSafeArea()

                    if viewModel.isLoading && viewModel.products.isEmpty {
                        ProgressView()
                            .tint(DashboardTheme.primaryBlue)
                    } else if let error = viewModel.errorMessage, viewModel.products.isEmpty {
                        errorState(error)
                    } else if viewModel.filteredProducts.isEmpty {
                        emptySearchState
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
                                ForEach(viewModel.filteredProducts) { product in
                                    NavigationLink {
                                        ProductDetailScreen(
                                            product: product,
                                            brandName: viewModel.brandName,
                                            sellerId: viewModel.sellerId,
                                            brandId: viewModel.brandId,
                                            editOrderViewModel: editOrderViewModel,
                                            onViewCart: onViewCart
                                        )
                                    } label: {
                                        BrandProductGridCard(product: product)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 4)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }

            if let editOrderViewModel, let onViewCart {
                EditOrderCartFooterContainer(
                    viewModel: editOrderViewModel,
                    onViewCart: onViewCart
                )
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadProducts() }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField(viewModel.searchPlaceholder, text: $viewModel.searchQuery)
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DashboardTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var emptySearchState: some View {
        VStack(spacing: 8) {
            Text("No products found for \"\(viewModel.searchQuery)\"")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.errorRed)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            DashboardCompactButton(title: "Retry") {
                viewModel.loadProducts()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BrandProductGridCard: View {
    let product: ActiveProductItem

    private let imageHeight: CGFloat = 118
    private let titleHeight: CGFloat = 38
    private let cardHeight: CGFloat = 186

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white)

                RemoteImage(url: product.image, contentMode: .fit)
                    .padding(6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: imageHeight)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DashboardTheme.surfaceVariant, lineWidth: 2)
            }

            Text(product.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .frame(height: titleHeight, alignment: .top)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight, alignment: .top)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

struct CreateOrderAppBar: View {
    var title: String
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                }
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
