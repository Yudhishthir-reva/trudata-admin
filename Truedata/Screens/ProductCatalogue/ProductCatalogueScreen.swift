//
//  ProductCatalogueScreen.swift
//  Truedata
//

import SwiftUI

struct ProductCatalogueScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProductCatalogueViewModel()
    var onOpenCalculator: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            catalogueAppBar

            ScrollView {
                VStack(spacing: 12) {
                    brandSelectionSection

                    pdfOptionsBar

                    if !viewModel.selectedProductIds.isEmpty {
                        Text("\(viewModel.selectedProductIds.count) products selected for PDF")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    content
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(hex: "F3F4F6"))
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .bottomTrailing) {
            if !viewModel.selectedProductIds.isEmpty {
                selectedProductsFAB
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
            }
        }
        .overlay {
            if viewModel.showDownloadDialog {
                DownloadCatalogDialog(
                    brandName: viewModel.selectedBrandName,
                    hideMrp: $viewModel.hideMrp,
                    hideSellingPrice: $viewModel.hideSellingPrice,
                    onDownload: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showDownloadDialog = false
                        }
                        viewModel.downloadCatalogPDF()
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showDownloadDialog = false
                        }
                    }
                )
            }
        }
        .onAppear { viewModel.loadInitial() }
        .sheet(isPresented: Binding(
            get: { viewModel.exportShareURL != nil },
            set: { isPresented in
                if !isPresented { viewModel.exportShareURL = nil }
            }
        )) {
            if let url = viewModel.exportShareURL {
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

    private var catalogueAppBar: some View {
        AppTopBar(
            title: "Product Catalogue",
            onBack: { dismiss() }
        ) {
            Button(action: onOpenCalculator) {
                Image(systemName: "function")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showDownloadDialog = true
                }
            }) {
                Group {
                    if viewModel.isDownloading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isDownloading)
        }
    }

    private var pdfOptionsBar: some View {
        HStack {
            Button {
                viewModel.hideMrp.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.hideMrp ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundStyle(viewModel.hideMrp ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                    Text("Hide MRP")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                viewModel.hideSellingPrice.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.hideSellingPrice ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundStyle(viewModel.hideSellingPrice ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                    Text("Hide Selling Price")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var brandSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Brand")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    brandChip(title: "All Brands", isSelected: viewModel.selectedBrandId == nil) {
                        viewModel.selectBrand(id: nil, name: "All Brands")
                    }

                    ForEach(viewModel.brands) { brand in
                        brandChip(title: brand.name, isSelected: viewModel.selectedBrandId == brand.id) {
                            viewModel.selectBrand(id: brand.id, name: brand.name)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func brandChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : DashboardTheme.neutralDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.surfaceVariant)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.products.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let error = viewModel.errorMessage, viewModel.products.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.refresh()
                }
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 24)
        } else if viewModel.products.isEmpty {
            Text("No products found.")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.products) { product in
                    ProductCatalogueItemCard(
                        product: product,
                        isSelected: viewModel.selectedProductIds.contains(product.id),
                        onToggleSelection: { viewModel.toggleSelection(for: product.id) }
                    )
                }
            }
        }
    }

    private var selectedProductsFAB: some View {
        Button(action: { viewModel.downloadCatalogPDF() }) {
            HStack(spacing: 8) {
                if viewModel.isDownloading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "doc.richtext")
                    Text("\(viewModel.selectedProductIds.count)")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(DashboardTheme.primaryBlue)
            .clipShape(Capsule())
            .shadow(color: DashboardTheme.primaryBlue.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isDownloading)
    }
}

private struct ProductCatalogueItemCard: View {
    let product: ActiveProductItem
    let isSelected: Bool
    var onToggleSelection: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                RemoteImage(url: product.image, contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .background(DashboardTheme.surfaceVariant)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(product.category)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .lineLimit(1)
                        if let brand = product.brand, !brand.isEmptyString {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                            Text(brand)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                                .lineLimit(1)
                        }
                    }

                    Text(product.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(2)

                    Text("\(product.variants.count) variant\(product.variants.count == 1 ? "" : "s") available")
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }

                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralDark)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            .onLongPressGesture(minimumDuration: 0.35) {
                onToggleSelection()
            }

            if isExpanded, !product.variants.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Available Variants")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)

                    ForEach(product.variants) { variant in
                        CatalogueVariantRow(variant: variant)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 4)
                .background(DashboardTheme.surfaceVariant.opacity(0.45))
            }
        }
        .background(isSelected ? DashboardTheme.primaryBlue.opacity(0.05) : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.surfaceVariant, lineWidth: isSelected ? 2 : 1)
        }
    }
}

private struct CatalogueVariantRow: View {
    let variant: ActiveProductVariant

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(variant.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("GST: \(variant.gstLabel)")
                    .font(.system(size: 10))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(DashboardTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }

            HStack(spacing: 8) {
                Text(variant.priceValue.currencyLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)

                if variant.mrpValue > variant.priceValue {
                    Text(variant.mrpValue.currencyLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .strikethrough()
                }

                if variant.discountPercentage > 0 {
                    Text(variant.discountLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DashboardTheme.successGreen)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(DashboardTheme.successGreen.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
            }

            if variant.ogPriceValue != variant.priceValue {
                Text("General Price: \(variant.ogPriceValue.currencyLabel)")
                    .font(.system(size: 10))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }
}

// MARK: - Download Catalog Dialog

private struct DownloadCatalogDialog: View {
    let brandName: String
    @Binding var hideMrp: Bool
    @Binding var hideSellingPrice: Bool
    var onDownload: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 14) {
                Text("Download Catalog PDF")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Brand: \(brandName)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DashboardTheme.primaryBlue)

                    Text("PDF Display Options:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .padding(.top, 4)

                    Button {
                        hideMrp.toggle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: hideMrp ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18))
                                .foregroundStyle(hideMrp ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                            Text("Hide MRP")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DashboardTheme.neutralDark)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    Button {
                        hideSellingPrice.toggle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: hideSellingPrice ? "checkmark.square.fill" : "square")
                                .font(.system(size: 18))
                                .foregroundStyle(hideSellingPrice ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                            Text("Hide Selling Price")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(DashboardTheme.neutralDark)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 12) {
                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDownload()
                    } label: {
                        Text("Download")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(DashboardTheme.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 16, x: 0, y: 8)
            .padding(.horizontal, 32)
        }
        .transition(.opacity)
    }
}

