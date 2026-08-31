//
//  B2COrderDetailScreen.swift
//  Truedata
//

import SwiftUI

struct B2COrderDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: B2COrderDetailViewModel

    @State private var showConfirmDialog = false
    @State private var showDispatchDialog = false
    @State private var showDeliverDialog = false
    @State private var showCancelDialog = false
    @State private var cancelReason = ""

    init(orderId: Int) {
        _viewModel = StateObject(wrappedValue: B2COrderDetailViewModel(orderId: orderId))
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                appBar

                if viewModel.isLoading && viewModel.orderDetail == nil {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.orderDetail == nil {
                    errorView(error)
                } else if let order = viewModel.orderDetail {
                    ScrollView {
                        VStack(spacing: 14) {
                            orderHeaderCard(order)
                            customerShippingCard(order)
                            productListCard(order)
                            priceBreakdownCard(order)
                            downloadInvoiceButton(order)

                            if order.canConfirm || order.canDispatch || order.canDeliver || order.canCancel {
                                adminActionButtons(order)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        viewModel.loadOrderDetail()
                    }
                }
            }

            if viewModel.isUpdatingStatus {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
                    .scaleEffect(1.2)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.loadOrderDetail()
        }
        .confirmationDialog(
            "Confirm this Order?",
            isPresented: $showConfirmDialog,
            titleVisibility: .visible
        ) {
            Button("Confirm Order") {
                viewModel.updateStatus(to: 1)
            }
            Button("Dismiss", role: .cancel) {}
        }
        .confirmationDialog(
            "Dispatch this Order?",
            isPresented: $showDispatchDialog,
            titleVisibility: .visible
        ) {
            Button("Dispatch Order") {
                viewModel.updateStatus(to: 2)
            }
            Button("Dismiss", role: .cancel) {}
        }
        .confirmationDialog(
            "Mark as Delivered?",
            isPresented: $showDeliverDialog,
            titleVisibility: .visible
        ) {
            Button("Mark Delivered") {
                viewModel.updateStatus(to: 3)
            }
            Button("Dismiss", role: .cancel) {}
        }
        .alert("Cancel Order", isPresented: $showCancelDialog) {
            TextField("Reason for cancellation (optional)", text: $cancelReason)
            Button("Cancel Order", role: .destructive) {
                let trimmed = cancelReason.trimmingCharacters(in: .whitespacesAndNewlines)
                viewModel.updateStatus(to: 4, reason: trimmed)
                cancelReason = ""
            }
            Button("Dismiss", role: .cancel) {
                cancelReason = ""
            }
        } message: {
            Text("Are you sure you want to cancel this order?")
        }
        .alert(
            "Notification",
            isPresented: Binding(
                get: { viewModel.toastMessage != nil },
                set: { if !$0 { viewModel.toastMessage = nil } }
            )
        ) {
            Button("OK") {
                viewModel.toastMessage = nil
            }
        } message: {
            Text(viewModel.toastMessage ?? "")
        }
    }

    private var appBar: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("Order Details")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button {
                viewModel.loadOrderDetail()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }

            Button {
                dismiss()
            } label: {
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

    // MARK: - Card 1: Order Header Card

    private func orderHeaderCard(_ order: B2COrderDetailData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(order.orderNo.isEmptyString ? "#\(order.id)" : order.orderNo)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color(hex: "111827"))

                Spacer()

                Text(order.date)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "6B7280"))
            }

            FlowLayout(spacing: 8, lineSpacing: 8) {
                // Delivery Status pill
                HStack(spacing: 6) {
                    Circle()
                        .fill(order.statusColor)
                        .frame(width: 7, height: 7)
                    Text("Delivery Status: \(order.status.isEmptyString ? "Delivered" : order.status)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(order.statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(order.statusColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                // Payment pill
                HStack(spacing: 5) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "2563EB"))

                    let payLabel = order.paymentLabel.isEmptyString
                        ? (order.paymentStatus.isEmptyString ? "Paid" : order.paymentStatus.capitalized)
                        : order.paymentLabel

                    Text("Payment: \(payLabel)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "2563EB"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "EFF6FF"))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }

    // MARK: - Card 2: Customer & Shipping Information

    private func customerShippingCard(_ order: B2COrderDetailData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Customer & Shipping Information")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))

            VStack(alignment: .leading, spacing: 12) {
                // User Name
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "6B7280"))
                        .frame(width: 16)

                    HStack(spacing: 4) {
                        Text("User Name:")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "6B7280"))
                        Text(order.customerName.isEmptyString ? "-" : order.customerName)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "111827"))
                    }
                }

                // Mobile Number
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "6B7280"))
                        .frame(width: 16)

                    HStack(spacing: 4) {
                        Text("Mobile Number:")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "6B7280"))
                        Text(order.customerMobile.isEmptyString ? "-" : order.customerMobile)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "111827"))
                    }
                }

                // Complete Address
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "6B7280"))
                        .frame(width: 16)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Complete Address:")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "6B7280"))

                        Text(order.customerAddress.isEmptyString ? "-" : order.customerAddress)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "374151"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Payment Mode
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "6B7280"))
                        .frame(width: 16)

                    HStack(spacing: 4) {
                        Text("Payment Mode:")
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "6B7280"))

                        let mode = order.paymentLabel.isEmptyString
                            ? (order.paymentType.isEmptyString ? "Cash on Delivery" : order.paymentType)
                            : order.paymentLabel

                        Text(mode)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "111827"))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }

    // MARK: - Card 3: Product List

    private func productListCard(_ order: B2COrderDetailData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Product List (\(order.items.count) Items)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))

            VStack(spacing: 14) {
                ForEach(order.items) { item in
                    productItemRow(item)
                    if item.id != order.items.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }

    private func productItemRow(_ item: B2COrderDetailItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if item.productImage.isEmptyString {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "D1D5DB"))
                } else {
                    RemoteImage(url: item.productImage, contentMode: .fill)
                }
            }
            .frame(width: 56, height: 56)
            .background(Color(hex: "F3F4F6"))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                // Product Name & Price
                HStack(alignment: .top) {
                    Text(item.productName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "111827"))
                        .lineLimit(2)

                    Spacer()

                    Text(item.price > 0 ? item.price.currencyLabel : item.customerPrice.currencyLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "111827"))
                }

                // Variant Pill & Qty
                HStack(spacing: 8) {
                    if !item.weight.isEmptyString {
                        Text("Variant: \(item.weight)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "4B5563"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "F3F4F6"))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }

                    Text("Qty: \(item.qty)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "4B5563"))
                }

                // MRP and Price
                HStack(spacing: 8) {
                    if item.mrp > item.customerPrice {
                        HStack(spacing: 2) {
                            Text("MRP: ")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "9CA3AF"))
                            Text(item.mrp.currencyLabel)
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "9CA3AF"))
                                .strikethrough()
                        }
                    }

                    Text("Price: \(item.customerPrice.currencyLabel)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "16A34A"))
                }

                // Savings
                if item.saveAmount > 0 || item.discountPercent > 0 {
                    let saveText = item.saveAmount > 0 ? "Saved \(item.saveAmount.currencyLabel)" : ""
                    let discText = item.discountPercent > 0 ? "(\(Int(item.discountPercent))% OFF)" : ""
                    Text("\(saveText) \(discText)".trimmingCharacters(in: .whitespaces))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: "16A34A"))
                }
            }
        }
    }

    // MARK: - Card 4: Payment & Price Breakdown

    private func priceBreakdownCard(_ order: B2COrderDetailData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment & Price Breakdown")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))

            VStack(spacing: 9) {
                if order.totalMrp > 0 {
                    breakdownRow(label: "Total MRP", value: order.totalMrp.currencyLabel)
                }

                breakdownRow(label: "Sub-Total", value: order.itemsTotal.currencyLabel)

                if order.totalSave > 0 {
                    breakdownRow(
                        label: "Total Discount / Savings",
                        value: "- \(order.totalSave.currencyLabel)",
                        valueColor: Color(hex: "16A34A")
                    )
                }

                if order.deliveryCharge > 0 {
                    breakdownRow(label: "Delivery Charge", value: order.deliveryCharge.currencyLabel)
                }

                if order.handlingCharge > 0 {
                    breakdownRow(label: "Handling Charge", value: order.handlingCharge.currencyLabel)
                }

                if order.packingCharge > 0 {
                    breakdownRow(label: "Packing Charge", value: order.packingCharge.currencyLabel)
                }

                if order.couponDiscount > 0 {
                    breakdownRow(
                        label: "Coupon Discount \(order.couponCode.map { "(\($0))" } ?? "")",
                        value: "- \(order.couponDiscount.currencyLabel)",
                        valueColor: Color(hex: "16A34A")
                    )
                }

                Divider()
                    .padding(.vertical, 4)

                HStack {
                    Text("Grand Total")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: "111827"))

                    Spacer()

                    Text(order.totalAmount.currencyLabel)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "1D4ED8"))
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 6, y: 2)
    }

    private func breakdownRow(label: String, value: String, valueColor: Color = Color(hex: "111827")) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "6B7280"))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(valueColor)
        }
    }

    // MARK: - Download Invoice Button

    private func downloadInvoiceButton(_ order: B2COrderDetailData) -> some View {
        Button {
            if !order.invoiceLink.isEmptyString, let url = URL(string: order.invoiceLink) {
                openURL(url)
            } else {
                // Download or request invoice fallback
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 14, weight: .bold))
                Text("Download Invoice")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(hex: "1D4ED8"))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Admin Status Actions (if allowed)

    private func adminActionButtons(_ order: B2COrderDetailData) -> some View {
        HStack(spacing: 10) {
            if order.canConfirm {
                adminBtn(title: "Confirm", color: DashboardTheme.primaryBlue) {
                    showConfirmDialog = true
                }
            }

            if order.canDispatch {
                adminBtn(title: "Dispatch", color: DashboardTheme.pickupOrange) {
                    showDispatchDialog = true
                }
            }

            if order.canDeliver {
                adminBtn(title: "Deliver", color: DashboardTheme.successGreen) {
                    showDeliverDialog = true
                }
            }

            if order.canCancel {
                adminBtn(title: "Cancel", color: DashboardTheme.dangerRed) {
                    showCancelDialog = true
                }
            }
        }
    }

    private func adminBtn(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DashboardTheme.dangerRed)
            Text(error)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                viewModel.loadOrderDetail()
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(DashboardTheme.primaryBlue)
            .clipShape(Capsule())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
