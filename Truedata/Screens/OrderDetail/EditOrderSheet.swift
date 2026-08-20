//
//  EditOrderSheet.swift
//  Truedata
//

import SwiftUI
import UIKit

struct EditOrderSheet: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditOrderViewModel
    @State private var showChooseBrand = false
    var onSaved: () -> Void
    var onGoHome: (() -> Void)?
    var onViewSeller: ((Int) -> Void)?

    init(
        order: OrderDetailData,
        onSaved: @escaping () -> Void,
        onGoHome: (() -> Void)? = nil,
        onViewSeller: ((Int) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: EditOrderViewModel(order: order))
        self.onSaved = onSaved
        self.onGoHome = onGoHome
        self.onViewSeller = onViewSeller
    }

    var body: some View {
        NavigationStack {
            sheetContent
                .navigationDestination(isPresented: $viewModel.shouldShowSubmitScreen) {
                    EditOrderSubmitScreen(viewModel: viewModel, onFinish: handleFinish)
                }
                .navigationDestination(isPresented: $showChooseBrand) {
                    EditOrderChooseBrandScreen(
                        sellerId: viewModel.sellerId,
                        editOrderViewModel: viewModel,
                        onViewCart: { showChooseBrand = false }
                    )
                }
        }
        .onChange(of: showChooseBrand) { _, isShowing in
            if !isShowing {
                viewModel.reloadEditDetails()
            }
        }
    }

    private func handleFinish(_ action: EditOrderFinishAction) {
        switch action {
        case .viewOrders:
            onSaved()
            dismiss()
        case .goToDashboard:
            onSaved()
            dismiss()
            onGoHome?()
        case .viewSeller:
            let sellerId = viewModel.effectiveSellerId
            onSaved()
            dismiss()
            onViewSeller?(sellerId)
        }
    }

    private var sheetContent: some View {
        VStack(spacing: 0) {
            headerSection

            ZStack {
                Color(hex: "F3F4F6").ignoresSafeArea()

                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.items) { item in
                                EditOrderItemRow(
                                    item: item,
                                    onQuantityChange: { viewModel.updateQuantity(for: item.id, quantity: $0) },
                                    onDelete: { viewModel.removeItem(item.id) }
                                )

                                if item.id != viewModel.items.last?.id {
                                    Divider().overlay(DashboardTheme.surfaceVariant.opacity(0.8))
                                }
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 120)
                    }
                }
            }

            footerSection
        }
        .background(Color(hex: "F3F4F6"))
        .onAppear { viewModel.loadEditDetails() }
        .alert("Notice", isPresented: errorBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(hex: "D1D5DB"))
                .frame(width: 42, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 10)

            Text("Editing Order \(viewModel.orderNo)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            HStack(alignment: .center) {
                Text("Review Your Order")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)

                Spacer(minLength: 8)

                Button {
                    showChooseBrand = true
                } label: {
                    Text("Add More")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(DashboardTheme.primaryBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Color.white)
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Total Items")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
                Text("\(viewModel.totalItems)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }

            Divider().overlay(DashboardTheme.surfaceVariant)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grand Total")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Text(viewModel.grandTotal.priceLabel)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                Spacer(minLength: 12)

                Button {
                    viewModel.proceedToSubmit()
                } label: {
                    Group {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save Changes")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                    .background(viewModel.canSaveChanges ? AppTheme.darkMidnightBlue : AppTheme.darkMidnightBlue.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSaveChanges)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.white)
        .overlay(alignment: .top) {
            Divider().overlay(DashboardTheme.surfaceVariant)
        }
    }
}

private struct EditOrderItemRow: View {
    let item: EditOrderLineItem
    var onQuantityChange: (Int) -> Void
    var onDelete: () -> Void

    private var weightInGrams: Double {
        CreateOrderVariantParser.weightInGrams(for: item.variantName)
            ?? CreateOrderVariantParser.weightInGrams(for: item.productName)
            ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                productImage

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text(item.productName.uppercased())
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: onDelete) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DashboardTheme.dangerRed)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(item.brandName)
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.neutralMedium)

                    HStack(alignment: .firstTextBaseline) {
                        Text(item.unitPriceLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)

                        Spacer(minLength: 8)

                        Text(item.lineTotal.priceLabel)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                }
            }

            HStack(spacing: 8) {
                SyncedKgPktQuantityFields(
                    weightInGrams: weightInGrams,
                    quantity: item.quantity,
                    onQuantityChange: onQuantityChange
                )

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var productImage: some View {
        Group {
            if item.productImage.isEmptyString {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(DashboardTheme.surfaceVariant)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
            } else {
                RemoteImage(url: item.productImage, contentMode: .fit)
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension Double {
    var priceLabel: String {
        String(self).priceLabel
    }
}
