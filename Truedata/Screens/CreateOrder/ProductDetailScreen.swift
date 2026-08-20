//
//  ProductDetailScreen.swift
//  Truedata
//

import SwiftUI
import UIKit

struct ProductDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ProductDetailViewModel
    @State private var showEditSpecialPrices = false

    private let editOrderViewModel: EditOrderViewModel?
    private let createOrderCartViewModel: CreateOrderCartViewModel?
    private let onViewCart: (() -> Void)?
    private let onProceedToSubmit: (() -> Void)?
    @State private var showCartSheet = false

    init(
        product: ActiveProductItem,
        brandName: String,
        sellerId: Int,
        brandId: Int,
        editOrderViewModel: EditOrderViewModel? = nil,
        createOrderCartViewModel: CreateOrderCartViewModel? = nil,
        onViewCart: (() -> Void)? = nil,
        onProceedToSubmit: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: ProductDetailViewModel(
                product: product,
                brandName: brandName,
                sellerId: sellerId,
                brandId: brandId,
                editOrderViewModel: editOrderViewModel,
                createOrderCartViewModel: createOrderCartViewModel
            )
        )
        self.editOrderViewModel = editOrderViewModel
        self.createOrderCartViewModel = createOrderCartViewModel
        self.onViewCart = onViewCart
        self.onProceedToSubmit = onProceedToSubmit
    }

    var body: some View {
        VStack(spacing: 0) {
            CreateOrderAppBar(
                title: "Product Details",
                onBack: { dismiss() },
                onHome: { dismiss() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    productHeaderCard

                    if !viewModel.product.variants.isEmpty {
                        Text("Select variants")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .padding(.horizontal, 4)

                        ForEach(viewModel.product.variants) { variant in
                            ProductVariantCard(
                                variant: variant,
                                quantity: viewModel.quantity(for: variant.id),
                                onQuantityChange: { viewModel.updateQuantity(for: variant.id, quantity: $0) }
                            )
                        }
                    } else {
                        Text("No variants available for this product.")
                            .font(.system(size: 14))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, cartBottomPadding)
            }
            .background(Color(hex: "F3F4F6"))

            if let editOrderViewModel, let onViewCart {
                EditOrderCartFooterContainer(
                    viewModel: editOrderViewModel,
                    onViewCart: onViewCart
                )
            } else if let createOrderCartViewModel {
                CreateOrderCartFooterContainer(
                    viewModel: createOrderCartViewModel,
                    onViewCart: { resolvedOnViewCart() }
                )
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCartSheet) {
            if let createOrderCartViewModel {
                CreateOrderCartSheet(
                    cartViewModel: createOrderCartViewModel,
                    onDismiss: { showCartSheet = false },
                    onAddMore: { showCartSheet = false },
                    onContinue: {
                        showCartSheet = false
                        onProceedToSubmit?()
                    }
                )
            }
        }
        .sheet(isPresented: $showEditSpecialPrices) {
            EditSpecialPricesSheet(
                variants: viewModel.product.variants,
                isSaving: viewModel.isSavingSpecialPrices,
                onCancel: { showEditSpecialPrices = false },
                onSave: { prices in
                    viewModel.saveSpecialPrices(prices) {
                        showEditSpecialPrices = false
                    }
                }
            )
        }
        .alert("Notice", isPresented: $viewModel.showSpecialPriceAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.specialPriceMessage ?? "")
        }
    }

    private var cartBottomPadding: CGFloat {
        if editOrderViewModel != nil {
            return 24
        }
        return createOrderCartViewModel?.hasItems == true ? 88 : 24
    }

    private func resolvedOnViewCart() {
        if let onViewCart {
            onViewCart()
        } else {
            showCartSheet = true
        }
    }

    private var productHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteImage(url: viewModel.product.image, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .padding(16)
                .background(DashboardTheme.surfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(spacing: 6) {
                Text(viewModel.categoryBrandLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            HStack(alignment: .top, spacing: 8) {
                Text(viewModel.product.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showEditSpecialPrices = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(width: 32, height: 32)
                        .background(DashboardTheme.primaryBlue.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProductVariantCard: View {
    let variant: ActiveProductVariant
    let quantity: Int
    let onQuantityChange: (Int) -> Void

    private var weightInGrams: Double {
        CreateOrderVariantParser.weightInGrams(for: variant.name) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("\(variant.name) (General Price: ₹\(variant.ogPriceValue.formattedPrice))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("GST: \(variant.gstLabel)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(DashboardTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            HStack(spacing: 8) {
                Text("₹\(variant.priceValue.formattedPrice)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)

                if variant.mrpValue > variant.priceValue {
                    Text("₹\(variant.mrpValue.formattedPrice)")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .strikethrough()
                }

                Spacer()

                if variant.discountPercentage > 0 {
                    Text(variant.discountLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DashboardTheme.successGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DashboardTheme.successGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
            }

            SyncedKgPktQuantityFields(
                weightInGrams: weightInGrams,
                quantity: quantity,
                onQuantityChange: onQuantityChange
            )
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }
}

private extension Double {
    var formattedPrice: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.2f", self)
    }
}
