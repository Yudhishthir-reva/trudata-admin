//
//  ManageProductsScreen.swift
//  Truedata
//

import SwiftUI

struct ManageProductsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ManageProductsViewModel()
    @State private var showFilterSheet = false

    var onAddProduct: () -> Void = {}
    var onEditProduct: (Int) -> Void = { _ in }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Manage Products",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.refresh() }
                )

                searchBar
                content
            }

            addProductButton
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadInitial() }
        .sheet(isPresented: $showFilterSheet) {
            ManageProductsFilterSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .productFormDidSave)) { _ in
            viewModel.refresh()
        }
        .alert("Notice", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && viewModel.products.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search products...", text: $viewModel.searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.searchText) { _, value in
                        viewModel.onSearchChanged(value)
                    }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.primaryBlue.opacity(0.35), lineWidth: 1)
            }

            Button {
                showFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DashboardTheme.primaryBlue)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.products.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.products.isEmpty {
            Text("No products found for selected filters.")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.products) { product in
                        ManageProductCard(
                            product: product,
                            isExpanded: viewModel.expandedProductIds.contains(product.id),
                            isUpdatingStatus: viewModel.updatingProductId == product.id && viewModel.isUpdatingStatus,
                            onToggleExpand: { viewModel.toggleExpanded(product.id) },
                            onEdit: {
                                onEditProduct(product.id)
                            },
                            onStatusChange: { isActive in
                                viewModel.toggleProductStatus(product, isActive: isActive)
                            }
                        )
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentProduct: product)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 88)
            }
        }
    }

    private var addProductButton: some View {
        Button {
            onAddProduct()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(DashboardTheme.primaryBlue)
                .clipShape(Circle())
                .shadow(color: DashboardTheme.primaryBlue.opacity(0.35), radius: 8, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

private struct ManageProductCard: View {
    let product: ManageProductItem
    let isExpanded: Bool
    let isUpdatingStatus: Bool
    var onToggleExpand: () -> Void
    var onEdit: () -> Void
    var onStatusChange: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onToggleExpand) {
                    HStack(alignment: .top, spacing: 12) {
                        productThumbnail
                        productSummary
                    }
                }
                .buttonStyle(.plain)

                statusToggle
            }
            .padding(16)

            if isExpanded {
                Divider()
                expandedContent
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }

    private var productThumbnail: some View {
        RemoteImage(url: product.image)
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            }
    }

    private var productSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(product.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "1F2937"))
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
                .buttonStyle(.plain)
            }

            Text(product.statusLabel)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(product.isActive ? Color(hex: "15803D") : Color(hex: "B91C1C"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(product.isActive ? Color(hex: "E7FBEF") : Color(hex: "FCECEC"))
                .clipShape(Capsule())

            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                Text(product.category.isEmptyString ? "Uncategorized" : product.category)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            HStack {
                Text(product.variantCountLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DashboardTheme.primaryBlue.opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
        }
    }

    private var statusToggle: some View {
        Group {
            if isUpdatingStatus {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Toggle("", isOn: Binding(
                    get: { product.isActive },
                    set: { onStatusChange($0) }
                ))
                .labelsHidden()
                .tint(DashboardTheme.successGreen)
            }
        }
        .frame(width: 52)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(icon: "doc.text", title: "Description")
            Text(product.description.isEmptyString ? "No description available." : product.description)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralDark)

            sectionHeader(icon: "indianrupeesign.circle", title: "Variants & Pricing")
            if product.variants.isEmpty {
                variantRow(name: "Default", price: product.price, stock: 0)
            } else {
                ForEach(product.variants) { variant in
                    variantRow(name: variant.name, price: variant.price, stock: variant.stockValue)
                }
            }

            sectionHeader(icon: "shippingbox", title: "Product Information")
            infoRow(label: "HSN Code", value: product.hsnCode.isEmptyString ? "-" : product.hsnCode)
            infoRow(
                label: "Status",
                value: product.statusLabel,
                valueColor: product.isActive ? DashboardTheme.successGreen : DashboardTheme.dangerRed
            )
            infoRow(label: "Total Variants", value: "\(max(product.variants.count, 1))")
            infoRow(
                label: "Total Stock",
                value: "\(product.totalStock)",
                valueColor: product.totalStock == 0 ? DashboardTheme.dangerRed : DashboardTheme.neutralDark
            )
        }
        .padding(16)
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryBlue)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
    }

    private func variantRow(name: String, price: String, stock: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                Text("₹\(price.priceLabel)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(stock == 0 ? DashboardTheme.dangerRed : DashboardTheme.successGreen)
                    .frame(width: 8, height: 8)
                Text("\(stock)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(stock == 0 ? DashboardTheme.dangerRed : DashboardTheme.neutralDark)
            }
        }
        .padding(12)
        .background(Color(hex: "F9FAFB"))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func infoRow(label: String, value: String, valueColor: Color = DashboardTheme.neutralDark) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(valueColor)
        }
    }
}
