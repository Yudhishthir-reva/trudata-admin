//
//  EditOrderChooseBrandScreen.swift
//  Truedata
//

import SwiftUI

struct EditOrderChooseBrandScreen: View {

    @ObservedObject var editOrderViewModel: EditOrderViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChooseBrandViewModel

    private let sellerId: Int
    private let onViewCart: () -> Void

    init(sellerId: Int, editOrderViewModel: EditOrderViewModel, onViewCart: @escaping () -> Void) {
        self.sellerId = sellerId
        self.editOrderViewModel = editOrderViewModel
        self.onViewCart = onViewCart
        _viewModel = StateObject(wrappedValue: ChooseBrandViewModel(sellerId: sellerId))
    }

    var body: some View {
        VStack(spacing: 0) {
            CreateOrderAppBar(
                title: "Edit Order – Choose Brand",
                onBack: { dismiss() },
                onHome: { dismiss() },
                onRefresh: { viewModel.loadData() }
            )

            ZStack {
                Color(hex: "F3F4F6").ignoresSafeArea()

                if viewModel.isLoadingBrands && viewModel.brands.isEmpty {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                } else if let error = viewModel.brandsError, viewModel.brands.isEmpty {
                    errorState(error)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Brand")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DashboardTheme.primaryBlue)
                                .padding(.top, 4)

                            ForEach(viewModel.brands) { brand in
                                NavigationLink {
                                    BrandProductListScreen(
                                        sellerId: sellerId,
                                        brandId: brand.id,
                                        brandName: brand.name,
                                        isEditMode: true,
                                        editOrderViewModel: editOrderViewModel,
                                        onViewCart: onViewCart
                                    )
                                } label: {
                                    BrandSelectionRow(brand: brand)
                                }
                                .buttonStyle(.plain)
                            }

                            topSellingSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }

            EditOrderCartFooterContainer(
                viewModel: editOrderViewModel,
                onViewCart: onViewCart
            )
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadData() }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.errorRed)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            DashboardCompactButton(title: "Retry") {
                viewModel.loadBrands()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var topSellingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)

                Text("Top Selling Suggestions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)

                Spacer()

                if viewModel.isLoadingSuggestions {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(DashboardTheme.primaryBlue)
                } else if !viewModel.suggestions.isEmpty {
                    Text("\(viewModel.suggestions.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DashboardTheme.primaryBlue.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 12)

            if viewModel.isLoadingSuggestions && viewModel.suggestions.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    TopSellingSuggestionPlaceholderRow()
                }
            } else {
                ForEach(viewModel.suggestions) { suggestion in
                    TopSellingSuggestionRow(suggestion: suggestion)
                }
            }
        }
    }
}

struct EditOrderCartFooter: View {
    let itemCount: Int
    let grandTotal: Double
    let buttonTitle: String
    var onAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(itemCount) Items")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Text(grandTotal.priceLabel)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            Spacer(minLength: 8)

            Button(action: onAction) {
                Text(buttonTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(AppTheme.darkMidnightBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.darkMidnightBlue.opacity(0.12))
                .frame(height: 1)
        }
    }
}

struct EditOrderCartFooterContainer: View {
    @ObservedObject var viewModel: EditOrderViewModel
    var onViewCart: () -> Void

    var body: some View {
        if viewModel.totalItems > 0 {
            EditOrderCartFooter(
                itemCount: viewModel.totalItems,
                grandTotal: viewModel.grandTotal,
                buttonTitle: "View Cart",
                onAction: onViewCart
            )
        }
    }
}

struct CreateOrderCartFooterContainer: View {
    @ObservedObject var viewModel: CreateOrderCartViewModel
    var onViewCart: () -> Void

    var body: some View {
        if viewModel.hasItems {
            EditOrderCartFooter(
                itemCount: viewModel.totalItems,
                grandTotal: viewModel.grandTotal,
                buttonTitle: "View Cart",
                onAction: onViewCart
            )
        }
    }
}

private extension Double {
    var priceLabel: String {
        String(self).priceLabel
    }
}
