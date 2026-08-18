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

    init(product: ActiveProductItem, brandName: String, sellerId: Int, brandId: Int) {
        _viewModel = StateObject(
            wrappedValue: ProductDetailViewModel(
                product: product,
                brandName: brandName,
                sellerId: sellerId,
                brandId: brandId
            )
        )
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
                .padding(.bottom, 24)
            }
            .background(Color(hex: "F3F4F6"))
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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

    @State private var kgInput = ""
    @State private var packetInput = ""
    @State private var isKgFocused = false
    @State private var isPacketFocused = false

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

            HStack(spacing: 8) {
                if weightInGrams > 0 {
                    VariantQuantityField(
                        text: $kgInput,
                        label: "Kg",
                        keyboardType: .decimalPad,
                        onFocusChange: { isKgFocused = $0 },
                        onTextChange: handleKgInputChange,
                        onCommit: syncKgFromInput
                    )
                }

                VariantQuantityField(
                    text: $packetInput,
                    label: "Pkt",
                    keyboardType: .numberPad,
                    onFocusChange: { isPacketFocused = $0 },
                    onTextChange: handlePacketInputChange,
                    onCommit: syncPacketsFromInput
                )
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
        .onAppear { syncInputsFromQuantity() }
        .onChange(of: quantity) { _, _ in
            if !isKgFocused && !isPacketFocused {
                syncInputsFromQuantity()
            }
        }
    }

    private func syncInputsFromQuantity() {
        kgInput = CreateOrderVariantParser.formattedKg(quantity: quantity, weightInGrams: weightInGrams)
        packetInput = quantity > 0 ? String(quantity) : ""
    }

    private func syncKgFromInput() {
        guard let parsedKg = Double(kgInput), parsedKg >= 0, parsedKg <= CreateOrderVariantParser.maxKgsLimit else {
            syncInputsFromQuantity()
            return
        }

        if parsedKg == 0 {
            onQuantityChange(0)
            return
        }

        guard weightInGrams > 0 else { return }
        let packets = Int((parsedKg * 1000) / weightInGrams)
        onQuantityChange(min(packets, CreateOrderVariantParser.maxPacketsLimit))
    }

    private func syncPacketsFromInput() {
        guard let parsed = Int(packetInput), parsed >= 0, parsed <= CreateOrderVariantParser.maxPacketsLimit else {
            syncInputsFromQuantity()
            return
        }
        onQuantityChange(parsed)
    }

    private func handleKgInputChange(_ newValue: String) {
        guard newValue.isEmpty || newValue.range(of: "^\\d*\\.?\\d*$", options: .regularExpression) != nil else {
            kgInput = CreateOrderVariantParser.formattedKg(quantity: quantity, weightInGrams: weightInGrams)
            return
        }

        guard let parsedKg = Double(newValue) else {
            if newValue.isEmpty { onQuantityChange(0) }
            return
        }

        guard parsedKg >= 0, parsedKg <= CreateOrderVariantParser.maxKgsLimit, weightInGrams > 0 else { return }
        let packets = parsedKg == 0 ? 0 : Int((parsedKg * 1000) / weightInGrams)
        if packets != quantity {
            onQuantityChange(min(packets, CreateOrderVariantParser.maxPacketsLimit))
        }
    }

    private func handlePacketInputChange(_ newValue: String) {
        guard newValue.isEmpty || newValue.range(of: "^\\d*$", options: .regularExpression) != nil else {
            packetInput = quantity > 0 ? String(quantity) : ""
            return
        }

        guard let parsed = Int(newValue) else {
            if newValue.isEmpty { onQuantityChange(0) }
            return
        }

        if parsed != quantity {
            onQuantityChange(min(parsed, CreateOrderVariantParser.maxPacketsLimit))
        }
    }
}

private struct VariantQuantityField: View {
    @Binding var text: String
    let label: String
    let keyboardType: UIKeyboardType
    let onFocusChange: (Bool) -> Void
    let onTextChange: (String) -> Void
    let onCommit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            TextField("0", text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.leading)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    onTextChange(newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    onFocusChange(focused)
                    if !focused { onCommit() }
                }

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DashboardTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity)
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
