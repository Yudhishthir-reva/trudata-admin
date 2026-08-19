//
//  OrderDetailScreen.swift
//  Truedata
//

import SwiftUI

struct OrderDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OrderDetailViewModel
    @State private var previewImageURL: String?
    @State private var actionMessage: String?
    @State private var showCancelConfirm = false
    @State private var showChangeSeller = false
    @State private var showEditOrder = false

    init(orderId: String) {
        _viewModel = StateObject(wrappedValue: OrderDetailViewModel(orderId: orderId))
    }

    var body: some View {
        VStack(spacing: 0) {
            OrderDetailAppBar(
                title: "Order Details",
                onBack: { dismiss() },
                onHome: { dismiss() },
                onRefresh: { viewModel.loadOrderDetail() }
            )

            ZStack {
                Color(hex: "F3F4F6")
                    .ignoresSafeArea()

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear { viewModel.loadOrderDetail() }
        .alert("Notice", isPresented: alertBinding) {
            Button("OK") { actionMessage = nil }
        } message: {
            Text(actionMessage ?? "")
        }
        .confirmationDialog(
            "Cancel this order?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel Order", role: .destructive) {
                actionMessage = "Cancel order is not available in iOS yet."
            }
            Button("Dismiss", role: .cancel) {}
        }
        .fullScreenCover(isPresented: imagePreviewBinding) {
            if let url = previewImageURL {
                OrderProductImagePreview(imageURL: url) {
                    previewImageURL = nil
                }
            }
        }
        .sheet(isPresented: $showChangeSeller) {
            if let order = viewModel.order {
                ChangeSellerSheet(
                    order: order,
                    orderId: orderId,
                    onUpdated: { viewModel.loadOrderDetail() }
                )
            }
        }
        .fullScreenCover(isPresented: $showEditOrder) {
            if let order = viewModel.order {
                EditOrderSheet(order: order) {
                    viewModel.loadOrderDetail()
                }
            }
        }
    }

    private var orderId: String {
        viewModel.orderId
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { actionMessage != nil }, set: { if !$0 { actionMessage = nil } })
    }

    private var imagePreviewBinding: Binding<Bool> {
        Binding(get: { previewImageURL != nil }, set: { if !$0 { previewImageURL = nil } })
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.order == nil {
            VStack {
                Spacer()
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.order == nil {
            VStack(spacing: 14) {
                Spacer()
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.errorRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                DashboardCompactButton(title: "Retry") {
                    viewModel.loadOrderDetail()
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let order = viewModel.order {
            ScrollView {
                VStack(spacing: 10) {
                    orderMainCard(order)
                    paymentDetailsCard(order)
                    sellerInfoCard(order)
                    bottomActions(order)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Main Card (header + items)

    private func orderMainCard(_ order: OrderDetailData) -> some View {
        OrderDetailStyledCard {
            VStack(alignment: .leading, spacing: 0) {
                orderHeader(order)
                Divider().overlay(DashboardTheme.surfaceVariant)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Order Items (\(order.orderDetails.count))")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .padding(.top, 8)

                    if order.orderDetails.isEmpty {
                        Text("No items in this order.")
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(order.orderDetails) { item in
                            productRow(item)
                            if item.id != order.orderDetails.last?.id {
                                Divider().overlay(DashboardTheme.surfaceVariant.opacity(0.8))
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }

    private func orderHeader(_ order: OrderDetailData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.displayOrderNo)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)

                    if order.orderNotDelivered {
                        Text("Rescheduled")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DashboardTheme.warningYellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DashboardTheme.warningYellow.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Spacer(minLength: 8)

                Text(order.orderDate)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.trailing)
            }

            HStack(spacing: 8) {
                statusChip(OrderDetailStatusMapper.deliveryStatus(order.status))
                statusChip(OrderDetailStatusMapper.paymentStatus(order.transactionStatus))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private func productRow(_ item: OrderDetailProduct) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Group {
                if item.productImage.isEmptyString {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DashboardTheme.surfaceVariant)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                } else {
                    RemoteImage(url: item.productImage)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                if !item.productImage.isEmptyString {
                    previewImageURL = item.productImage
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.productName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)
                if !item.variantName.isEmptyString {
                    Text(item.variantName)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .lineLimit(1)
                }
                Text(item.quantityPriceLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.85))
            }

            Spacer(minLength: 4)

            Text(item.totalPrice.priceLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Payment Details

    private func paymentDetailsCard(_ order: OrderDetailData) -> some View {
        OrderDetailStyledCard {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Payment Details")

                paymentRow("Subtotal", order.subtotal.priceLabel)
                paymentRow("Discount", "- \(order.discountValue.priceLabel)", valueColor: DashboardTheme.dangerRed)

                Divider().overlay(DashboardTheme.surfaceVariant)

                HStack {
                    Text("Grand Total")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    Spacer()
                    Text(order.grandTotal.priceLabel)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
                .padding(.top, 2)
            }
            .padding(10)
        }
    }

    // MARK: - Seller Info

    private func sellerInfoCard(_ order: OrderDetailData) -> some View {
        OrderDetailStyledCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Seller & Staff Information")

                sellerInfoRow(icon: "storefront.fill", label: "Shop", value: order.shopDisplay)
                sellerInfoRow(icon: "person.fill", label: "Seller", value: order.sellerName)
                sellerInfoRow(icon: "person.badge.key.fill", label: "Sale Person", value: order.staffName)
                sellerInfoRow(icon: "bicycle", label: "Rider", value: order.riderName)

                if !order.deliveryDate.isEmptyString {
                    sellerInfoRow(icon: "calendar", label: "Delivery Date", value: order.deliveryDate)
                }
                if !order.deliveryTime.isEmptyString {
                    sellerInfoRow(icon: "clock.fill", label: "Delivery Time", value: order.deliveryTime)
                }

                sellerInfoRow(icon: "map.fill", label: "Beat", value: order.beatName)
                sellerInfoRow(icon: "location.fill", label: "Full Address", value: order.sellerAddress)

                if !order.manualAddress.isEmptyString {
                    sellerInfoRow(icon: "mappin.and.ellipse", label: "Manual Address", value: order.manualAddress)
                }
            }
            .padding(10)
        }
    }

    // MARK: - Bottom Buttons

    private func bottomActions(_ order: OrderDetailData) -> some View {
        VStack(spacing: 8) {
            if order.showsEditSeller {
                Button {
                    showChangeSeller = true
                } label: {
                    orderActionButton(
                        title: "Edit Seller",
                        icon: "storefront.fill",
                        color: DashboardTheme.secondaryPurple
                    )
                }
                .buttonStyle(.plain)
            }

            if order.showsEditOrder {
                Button {
                    showEditOrder = true
                } label: {
                    orderActionButton(
                        title: "Edit Order",
                        icon: "pencil",
                        color: Color(hex: "166534")
                    )
                }
                .buttonStyle(.plain)
            }

            if order.showsDownloadInvoice {
                Button {
                    downloadInvoice(order)
                } label: {
                    orderActionButton(
                        title: "Download Invoice",
                        icon: "arrow.down.circle.fill",
                        color: DashboardTheme.primaryBlue,
                        isDisabled: order.invoiceLink.isEmptyString
                    )
                }
                .buttonStyle(.plain)
                .disabled(order.invoiceLink.isEmptyString)
            }

            if order.showsDownloadSettlementReceipt {
                Button {
                    downloadSettlementReceipt(order)
                } label: {
                    orderActionButton(
                        title: "Download Settlement Receipt",
                        icon: "arrow.down.circle.fill",
                        color: AppTheme.darkMidnightBlue,
                        isDisabled: order.paymentReceiptLink.isEmptyString
                    )
                }
                .buttonStyle(.plain)
                .disabled(order.paymentReceiptLink.isEmptyString)
            }

            if order.showsCancelOrder {
                Button {
                    showCancelConfirm = true
                } label: {
                    orderActionButton(
                        title: "Cancel Order",
                        icon: "xmark.circle.fill",
                        color: DashboardTheme.dangerRed
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private func orderActionButton(
        title: String,
        icon: String,
        color: Color,
        isDisabled: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isDisabled ? color.opacity(0.45) : color)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func downloadSettlementReceipt(_ order: OrderDetailData) {
        guard !order.paymentReceiptLink.isEmptyString,
              let url = URL(string: order.paymentReceiptLink.trim) else {
            actionMessage = "Settlement receipt link is not available."
            return
        }
        UIApplication.shared.open(url)
    }

    private func downloadInvoice(_ order: OrderDetailData) {
        guard !order.invoiceLink.isEmptyString, let url = URL(string: order.invoiceLink.trim) else {
            actionMessage = "Invoice link is not available."
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(DashboardTheme.neutralDark)
    }

    private func statusChip(_ info: OrderDetailStatusChip) -> some View {
        HStack(spacing: 4) {
            Image(systemName: info.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(info.text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(info.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(info.backgroundColor)
        .clipShape(Capsule())
    }

    private func paymentRow(_ label: String, _ value: String, valueColor: Color = DashboardTheme.neutralDark) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(valueColor)
        }
    }

    private func sellerInfoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.7))
                .frame(width: 16)

            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(width: 98, alignment: .leading)

            Text(value.isEmptyString ? "N/A" : value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// MARK: - Styled Card

private struct OrderDetailStyledCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
            }
            .shadow(color: DashboardTheme.primaryBlue.opacity(0.04), radius: 6, y: 2)
    }
}

// MARK: - App Bar

private struct OrderDetailAppBar: View {
    let title: String
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: () -> Void

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
        .frame(maxWidth: .infinity)
        .background(AppTheme.darkMidnightBlue)
    }
}

// MARK: - Image Preview

private struct OrderProductImagePreview: View {
    let imageURL: String
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RemoteImage(url: imageURL, contentMode: .fit)
                .padding(24)
            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

private extension Double {
    var priceLabel: String {
        String(self).priceLabel
    }
}

#Preview {
    NavigationStack {
        OrderDetailScreen(orderId: "12345")
    }
}
