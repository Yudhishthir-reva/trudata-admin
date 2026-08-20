//
//  ChooseBrandScreen.swift
//  Truedata
//

import SwiftUI

struct ChooseBrandScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChooseBrandViewModel
    @StateObject private var cartViewModel: CreateOrderCartViewModel
    @State private var showCartSheet = false
    @State private var showSubmitScreen = false

    private let sellerId: Int
    private let onFinish: ((CreateOrderFinishAction) -> Void)?

    init(sellerId: Int, onFinish: ((CreateOrderFinishAction) -> Void)? = nil) {
        self.sellerId = sellerId
        self.onFinish = onFinish
        _viewModel = StateObject(wrappedValue: ChooseBrandViewModel(sellerId: sellerId))
        _cartViewModel = StateObject(wrappedValue: CreateOrderCartViewModel(sellerId: sellerId))
    }

    var body: some View {
        VStack(spacing: 0) {
            CreateOrderAppBar(
                title: "Choose a Brand",
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
                                .foregroundStyle(DashboardTheme.neutralDark)
                                .padding(.top, 4)

                            ForEach(viewModel.brands) { brand in
                                NavigationLink {
                                    BrandProductListScreen(
                                        sellerId: sellerId,
                                        brandId: brand.id,
                                        brandName: brand.name,
                                        cartViewModel: cartViewModel,
                                        onViewCart: { showCartSheet = true },
                                        onProceedToSubmit: { showSubmitScreen = true }
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
                        .padding(.bottom, cartViewModel.hasItems ? 88 : 24)
                    }
                }
            }

            CreateOrderCartFooterContainer(
                viewModel: cartViewModel,
                onViewCart: { showCartSheet = true }
            )
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadData() }
        .navigationDestination(isPresented: $showSubmitScreen) {
            CreateOrderSubmitScreen(
                cartViewModel: cartViewModel,
                onFinish: handleFinish
            )
        }
        .sheet(isPresented: $showCartSheet) {
            CreateOrderCartSheet(
                cartViewModel: cartViewModel,
                onDismiss: { showCartSheet = false },
                onAddMore: { showCartSheet = false },
                onContinue: { showSubmitScreen = true }
            )
        }
    }

    private func handleFinish(_ action: CreateOrderFinishAction) {
        if let onFinish {
            onFinish(action)
        } else {
            dismiss()
        }
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

struct BrandSelectionRow: View {
    let brand: BrandListItem

    var body: some View {
        HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 48, height: 48)

                    RemoteImage(url: brand.image, contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Text(brand.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(DashboardTheme.surfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TopSellingSuggestionRow: View {
    let suggestion: TopSellingProductSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RemoteImage(url: suggestion.productImage, contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(suggestion.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    LabelDotText(
                        color: DashboardTheme.successGreen,
                        text: "\(suggestion.totalQuantity) available"
                    )

                    if suggestion.lastOrderedQty > 0 {
                        LabelDotText(
                            color: DashboardTheme.warningYellow,
                            text: "Last ordered quantity: \(suggestion.lastOrderedQty)"
                        )
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(DashboardTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TopSellingSuggestionPlaceholderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.8))
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.8))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 140, height: 10)
            }

            Spacer()
        }
        .padding(12)
        .background(DashboardTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct LabelDotText: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .lineLimit(1)
        }
    }
}
