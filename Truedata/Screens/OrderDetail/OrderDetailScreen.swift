import SwiftUI
import AVFoundation
import Combine

struct OrderDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OrderDetailViewModel
    @State private var previewImageURL: String?
    @State private var actionMessage: String?
    @State private var showCancelConfirm = false
    @State private var showUnassignConfirm = false
    @State private var showChangeSeller = false
    @State private var showEditOrder = false
    @State private var showReturnTypeDialog = false
    @State private var showFullReturn = false
    @State private var showPartialReturn = false
    @State private var sellerProfileId: Int?

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
                Color(hex: "F4F6F8")
                    .ignoresSafeArea()

                content

                if viewModel.isCancelling || viewModel.isUnassigning || viewModel.isDownloadingSettlement {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(Color(hex: "1F7A3E"))
                        .scaleEffect(1.2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(hex: "1F7A3E").ignoresSafeArea(edges: .top))
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
                viewModel.cancelOrder { success, message in
                    actionMessage = message
                    if success {
                        viewModel.loadOrderDetail()
                    }
                }
            }
            Button("Dismiss", role: .cancel) {}
        }
        .confirmationDialog(
            "Unassign this order?",
            isPresented: $showUnassignConfirm,
            titleVisibility: .visible
        ) {
            Button("Unassign Order", role: .destructive) {
                viewModel.unassignOrder { success, message in
                    actionMessage = message
                    if success {
                        dismiss()
                    }
                }
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
                EditOrderSheet(
                    order: order,
                    onSaved: {
                        viewModel.loadOrderDetail()
                    },
                    onGoHome: {
                        dismiss()
                    },
                    onViewSeller: { sellerId in
                        sellerProfileId = sellerId
                    }
                )
            }
        }
        .fullScreenCover(isPresented: sellerProfileBinding) {
            if let sellerId = sellerProfileId {
                SellerProfileScreen(sellerId: sellerId)
            }
        }
        .fullScreenCover(isPresented: $showFullReturn) {
            FullReturnOrderScreen(orderId: orderId)
        }
        .fullScreenCover(isPresented: $showPartialReturn) {
            PartialReturnOrderScreen(orderId: orderId)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.settlementShareURL != nil },
            set: { isPresented in
                if !isPresented { viewModel.settlementShareURL = nil }
            }
        )) {
            if let url = viewModel.settlementShareURL {
                ActivityShareSheet(items: [url])
            }
        }
        .overlay {
            if showReturnTypeDialog, let order = viewModel.order {
                ReturnOrderTypeDialog(
                    orderNo: order.orderNo.isEmptyString ? "\(order.orderId)" : order.orderNo,
                    onDismiss: { showReturnTypeDialog = false },
                    onTypeSelected: { type in
                        showReturnTypeDialog = false
                        switch type {
                        case .full:
                            showFullReturn = true
                        case .partial:
                            showPartialReturn = true
                        }
                    }
                )
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

    private var sellerProfileBinding: Binding<Bool> {
        Binding(
            get: { sellerProfileId != nil },
            set: { if !$0 { sellerProfileId = nil } }
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.order == nil {
            VStack {
                Spacer()
                ProgressView()
                    .tint(Color(hex: "1F7A3E"))
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
                VStack(spacing: 14) {
                    orderHeroCard(order)
                    orderItemsCard(order)
                    paymentDetailsCard(order)
                    sellerInfoCard(order)
                    if order.hasAnyRemark {
                        remarksCard(order)
                    }
                    bottomActions(order)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Top Hero Card (Forest Green)

    private func orderHeroCard(_ order: OrderDetailData) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top Row: Order ID & Date + Grand Total
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ORDER")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .tracking(0.5)

                    Text(order.displayOrderNo)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    if !order.orderDate.isEmptyString {
                        Text(order.orderDate)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("GRAND TOTAL")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .tracking(0.5)

                    Text(order.grandTotal.priceLabel)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            // Chips Row: Delivery Status, Payment Status, Order Source
            FlowLayout(spacing: 8, lineSpacing: 8) {
                heroStatusChip(
                    icon: deliveryStatusIcon(order.status),
                    text: deliveryStatusText(order.status)
                )

                heroStatusChip(
                    icon: paymentStatusIcon(order.transactionStatus),
                    text: paymentStatusText(order.transactionStatus)
                )

                if !order.orderSourceDisplay.isEmptyString {
                    heroStatusChip(
                        icon: order.orderSourceIcon,
                        text: order.orderSourceDisplay
                    )
                }

                if order.orderNotDelivered {
                    heroStatusChip(
                        icon: "exclamationmark.arrow.circlepath",
                        text: "Rescheduled"
                    )
                }
            }

            // Bottom 2 Mini Metric Cards
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Items")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.75))

                    Text("\(order.orderDetails.count)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Shop")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.75))

                    Text(order.shopDisplay.isEmptyString ? (order.sellerName.isEmptyString ? "N/A" : order.sellerName) : order.shopDisplay)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "1F7A3E"), Color(hex: "1A6B36")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: "1F7A3E").opacity(0.2), radius: 10, y: 4)
    }

    private func heroStatusChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.18))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    private func deliveryStatusIcon(_ status: String) -> String {
        switch status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "delivered", "3": return "checkmark.circle.fill"
        case "cancel", "4": return "xmark.circle.fill"
        case "pending", "0": return "clock.fill"
        case "pickup", "2": return "archivebox.fill"
        case "to deliver", "to delivered", "1": return "shippingbox.fill"
        default: return "checkmark.circle.fill"
        }
    }

    private func deliveryStatusText(_ status: String) -> String {
        let chip = OrderDetailStatusMapper.deliveryStatus(status)
        return chip.text
    }

    private func paymentStatusIcon(_ status: String) -> String {
        switch status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "complete", "completed", "2", "paid": return "checkmark.seal.fill"
        case "remaining", "1": return "hourglass.bottomhalf.filled"
        case "pending", "0": return "hourglass"
        default: return "creditcard.fill"
        }
    }

    private func paymentStatusText(_ status: String) -> String {
        let trimmed = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "complete" || trimmed == "completed" || trimmed == "2" || trimmed == "paid" {
            return "Payment: Paid"
        } else if trimmed == "pending" || trimmed == "0" {
            return "Payment: Pending"
        } else if trimmed == "remaining" || trimmed == "1" {
            return "Payment: Partially Paid"
        } else if !status.isEmptyString {
            return "Payment: \(status.capitalized)"
        }
        return "Payment: Pending"
    }

    // MARK: - Order Items Card

    private func orderItemsCard(_ order: OrderDetailData) -> some View {
        OrderDetailCard {
            VStack(alignment: .leading, spacing: 14) {
                OrderDetailSectionHeader(
                    icon: "cart.fill",
                    title: "Order Items (\(order.orderDetails.count))"
                )

                if order.orderDetails.isEmpty {
                    Text("No items in this order.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "6B7280"))
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(order.orderDetails.enumerated()), id: \.element.id) { index, item in
                            productRow(item)
                            if index < order.orderDetails.count - 1 {
                                Divider().overlay(Color(hex: "F3F4F6"))
                            }
                        }
                    }
                }
            }
        }
    }

    private func productRow(_ item: OrderDetailProduct) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Group {
                if item.productImage.isEmptyString {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "F3F4F6"))
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 16))
                                .foregroundStyle(Color(hex: "9CA3AF"))
                        }
                } else {
                    RemoteImage(url: item.productImage)
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 0.8)
            )
            .onTapGesture {
                if !item.productImage.isEmptyString {
                    previewImageURL = item.productImage
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.productName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "1F2937"))
                    .lineLimit(2)

                if !item.variantName.isEmptyString {
                    Text(item.variantName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "6B7280"))
                }

                Text(item.quantityPriceLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "6B7280"))
            }

            Spacer(minLength: 8)

            Text(item.totalPrice.priceLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: "1F2937"))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Payment Details Card

    private func paymentDetailsCard(_ order: OrderDetailData) -> some View {
        OrderDetailCard {
            VStack(alignment: .leading, spacing: 14) {
                OrderDetailSectionHeader(
                    icon: "creditcard.fill",
                    title: "Payment Details"
                )

                VStack(spacing: 10) {
                    paymentRow("Subtotal", order.subtotal.priceLabel)
                    paymentRow(
                        "Discount",
                        "- \(order.discountValue.priceLabel)",
                        valueColor: Color(hex: "EF4444")
                    )

                    Divider().overlay(Color(hex: "E5E7EB"))

                    HStack {
                        Text("Grand Total")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "1F2937"))
                        Spacer()
                        Text(order.grandTotal.priceLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "1F2937"))
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: - Seller & Staff Information Card

    private func sellerInfoCard(_ order: OrderDetailData) -> some View {
        OrderDetailCard {
            VStack(alignment: .leading, spacing: 14) {
                OrderDetailSectionHeader(
                    icon: "storefront.fill",
                    title: "Seller & Staff Information"
                )

                VStack(spacing: 12) {
                    if !order.orderSourceDisplay.isEmptyString {
                        infoRow(icon: order.orderSourceIcon, label: "Order Source", value: order.orderSourceDisplay)
                    }
                    infoRow(icon: "storefront.fill", label: "Shop", value: order.shopDisplay)
                    infoRow(icon: "person.fill", label: "Seller", value: order.sellerName)

                    if !order.sellerMobile.isEmptyString {
                        mobileInfoRow(mobile: order.sellerMobile)
                    }

                    infoRow(icon: "person.badge.key.fill", label: "Sale Person", value: order.staffName)
                    infoRow(icon: "bicycle", label: "Rider", value: order.riderName)

                    if SellerProfileLink.resolvedId(order.sellerId) != nil {
                        ViewSellerProfileButton(sellerId: order.sellerId)
                            .padding(.top, 2)
                    }

                    if !order.deliveryDate.isEmptyString {
                        infoRow(icon: "calendar", label: "Delivery Date", value: order.deliveryDate)
                    }
                    if !order.deliveryTime.isEmptyString {
                        infoRow(icon: "clock.fill", label: "Delivery Time", value: order.deliveryTime)
                    }

                    infoRow(icon: "map.fill", label: "Beat", value: order.beatName)
                    infoRow(icon: "location.fill", label: "Full Address", value: order.sellerAddress)

                    if !order.manualAddress.isEmptyString {
                        infoRow(icon: "mappin.and.ellipse", label: "Manual Address", value: order.manualAddress)
                    }
                }
            }
        }
    }

    // MARK: - Remarks & Voice Notes Card

    private func remarksCard(_ order: OrderDetailData) -> some View {
        OrderDetailCard {
            VStack(alignment: .leading, spacing: 14) {
                OrderDetailSectionHeader(
                    icon: "text.bubble.fill",
                    title: "Remarks & Voice Notes",
                    iconColor: Color(hex: "F59E0B"),
                    badgeBgColor: Color(hex: "FFFBEB")
                )

                if order.hasRetailerAudioRemark {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Retailer Voice Note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "1F7A3E"))
                        OrderDetailAudioPlayerView(audioURLString: order.retailerAudioRemark)
                    }
                }

                if order.hasRetailerRemark {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Retailer Remark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "1F7A3E"))
                        OrderDetailTextRemarkView(remark: order.retailerRemark)
                    }
                }

                if order.hasAudioRemark {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Salesperson Voice Note")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "6B7280"))
                        OrderDetailAudioPlayerView(audioURLString: order.audioRemark)
                    }
                }

                if order.hasRemark {
                    VStack(alignment: .leading, spacing: 4) {
                        if order.hasRetailerRemark || order.hasRetailerAudioRemark {
                            Text("Salesperson / Admin Remark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(hex: "6B7280"))
                        }
                        OrderDetailTextRemarkView(remark: order.remark)
                    }
                }

                if order.remarkHistory.count > 1 || (order.remarkHistory.count == 1 && (order.hasRetailerRemark || order.hasRetailerAudioRemark)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Remark History")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "1F2937"))

                        ForEach(order.remarkHistory) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.createdBy.isEmptyString ? "Staff" : item.createdBy.capitalized)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Color(hex: "1F7A3E"))
                                    Spacer()
                                    if !item.createdAt.isEmptyString {
                                        Text(item.createdAt)
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color(hex: "6B7280"))
                                    }
                                }
                                if item.hasAudio {
                                    OrderDetailAudioPlayerView(audioURLString: item.audioRemark)
                                }
                                if item.hasText {
                                    OrderDetailTextRemarkView(remark: item.remark)
                                }
                            }
                            .padding(10)
                            .background(Color(hex: "F8FAFC"))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottom Actions

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

            if order.showsReturnOrder {
                Button {
                    showReturnTypeDialog = true
                } label: {
                    orderActionButton(
                        title: "Return Order",
                        icon: "arrow.uturn.backward.circle.fill",
                        color: Color(hex: "673AB7")
                    )
                }
                .buttonStyle(.plain)
            }

            if order.showsUnassignOrder {
                Button {
                    showUnassignConfirm = true
                } label: {
                    orderActionButton(
                        title: "Unassign Order",
                        icon: "person.crop.circle.badge.minus",
                        color: DashboardTheme.warningYellow,
                        isDisabled: viewModel.isUnassigning
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isUnassigning)
            }

            if order.showsDownloadInvoice {
                Button {
                    downloadInvoice(order)
                } label: {
                    orderActionButton(
                        title: "Download Invoice",
                        icon: "arrow.down.circle.fill",
                        color: Color(hex: "1F7A3E")
                    )
                }
                .buttonStyle(.plain)
            }

            if order.showsDownloadSettlementReceipt {
                Button {
                    downloadSettlementReceipt(order)
                } label: {
                    orderActionButton(
                        title: "Download Settlement Receipt",
                        icon: "arrow.down.circle.fill",
                        color: Color(hex: "1F2937"),
                        isDisabled: viewModel.isDownloadingSettlement
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isDownloadingSettlement)
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
        viewModel.downloadSettlementReceipt(for: order) { message in
            actionMessage = message
        }
    }

    private func downloadInvoice(_ order: OrderDetailData) {
        guard !order.invoiceLink.isEmptyString, let url = URL(string: order.invoiceLink.trim) else {
            actionMessage = "Invoice link is not available."
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - Helper Views & Rows

    private func paymentRow(_ label: String, _ value: String, valueColor: Color = Color(hex: "1F2937")) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "6B7280"))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(valueColor)
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "1F7A3E"))
                .frame(width: 18)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "6B7280"))
                .frame(width: 100, alignment: .leading)

            Text(value.isEmptyString ? "N/A" : value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(hex: "1F2937"))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func mobileInfoRow(mobile: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "phone.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "1F7A3E"))
                .frame(width: 18)

            Text("Mobile")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "6B7280"))
                .frame(width: 100, alignment: .leading)

            Spacer()

            if let url = URL(string: "tel://\(mobile)") {
                Button {
                    UIApplication.shared.open(url)
                } label: {
                    HStack(spacing: 4) {
                        Text(mobile)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: "1F7A3E"))
                        Image(systemName: "phone.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "1F7A3E"))
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(mobile)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "1F2937"))
            }
        }
    }
}

// MARK: - Styled Card & Section Header

struct OrderDetailCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }
}

struct OrderDetailSectionHeader: View {
    let icon: String
    let title: String
    var iconColor: Color = Color(hex: "1F7A3E")
    var badgeBgColor: Color = Color(hex: "E8F5E9")

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(badgeBgColor)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "1F2937"))

            Spacer(minLength: 0)
        }
    }
}

// MARK: - App Bar

struct OrderDetailAppBar: View {
    let title: String
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }

            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "1F7A3E"))
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

// MARK: - Remarks Components

private struct OrderDetailTextRemarkView: View {
    let remark: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: "F59E0B"))

            Text(remark)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "FFFBEB"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct OrderDetailAudioPlayerView: View {
    let audioURLString: String
    @StateObject private var player = OrderDetailAudioPlayer()

    var body: some View {
        HStack(spacing: 12) {
            Button(action: { player.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(DashboardTheme.primaryBlue)
                        .frame(width: 38, height: 38)

                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: player.isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    HStack(spacing: 3) {
                        ForEach(0..<24, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(DashboardTheme.primaryBlue.opacity(0.25))
                                .frame(width: 3, height: waveformHeight(for: i))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 3) {
                        ForEach(0..<24, id: \.self) { i in
                            let barProgress = Double(i) / 24.0
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(barProgress <= player.progress ? DashboardTheme.primaryBlue : DashboardTheme.primaryBlue.opacity(0.25))
                                .frame(width: 3, height: waveformHeight(for: i))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newProg = value.location.x / geometry.size.width
                            player.seek(to: Double(newProg))
                        }
                )
            }
            .frame(height: 24)

            Text(player.formattedTime)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .frame(minWidth: 42, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "F0F4FA"))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear {
            player.loadAudio(from: audioURLString)
        }
        .onDisappear {
            player.cleanup()
        }
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let pattern: [CGFloat] = [8, 14, 18, 10, 16, 22, 12, 18, 14, 20, 16, 10, 18, 22, 14, 12, 20, 16, 10, 14, 18, 12, 8, 6]
        return pattern[index % pattern.count]
    }
}

final class OrderDetailAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var progress: Double = 0

    private var avPlayer: AVPlayer?
    private var avAudioPlayer: AVAudioPlayer?
    private var timeObserverToken: Any?
    private var timer: Timer?
    private var tempFileURL: URL?

    func loadAudio(from source: String) {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if trimmed.hasPrefix("data:audio") || (trimmed.count > 100 && !trimmed.hasPrefix("http")) {
            loadBase64(trimmed)
            return
        }

        let resolvedURLString: String
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            resolvedURLString = trimmed
        } else {
            let base = BASE_URL.replacingOccurrences(of: "/api/", with: "/")
            resolvedURLString = base.hasSuffix("/") ? "\(base)\(trimmed)" : "\(base)/\(trimmed)"
        }

        if let url = URL(string: resolvedURLString) {
            loadRemoteURL(url)
        }
    }

    private func loadBase64(_ base64String: String) {
        let mimeHint = base64String.lowercased()
        let fileExtension: String
        if mimeHint.contains("audio/mp4") || mimeHint.contains("audio/m4a") || mimeHint.contains("audio/x-m4a") {
            fileExtension = "m4a"
        } else if mimeHint.contains("audio/mpeg") || mimeHint.contains("audio/mp3") {
            fileExtension = "mp3"
        } else if mimeHint.contains("audio/wav") {
            fileExtension = "wav"
        } else if mimeHint.contains("audio/aac") {
            fileExtension = "aac"
        } else {
            fileExtension = "m4a"
        }

        let clean = base64String.components(separatedBy: ",").last ?? base64String
        guard let data = Data(base64Encoded: clean, options: .ignoreUnknownCharacters), !data.isEmpty else {
            #if DEBUG
            print("Error loading base64 audio: invalid base64")
            #endif
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("order-audio-\(UUID().uuidString).\(fileExtension)")
            try data.write(to: url)
            self.tempFileURL = url

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.delegate = self
                player.prepareToPlay()
                self.duration = player.duration
                self.avAudioPlayer = player
            } catch {
                // Fallback for formats AVAudioPlayer rejects (some mp4 containers).
                loadRemoteURL(url)
            }
        } catch {
            #if DEBUG
            print("Error loading base64 audio: \(error)")
            #endif
        }
    }

    private func loadRemoteURL(_ url: URL) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        self.avPlayer = player

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            let current = CMTimeGetSeconds(time)
            if !current.isNaN {
                self.currentTime = current
                let dur = CMTimeGetSeconds(self.avPlayer?.currentItem?.duration ?? .zero)
                if dur > 0 && !dur.isNaN {
                    self.duration = dur
                    self.progress = min(max(current / dur, 0), 1)
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
    }

    func togglePlayPause() {
        if let player = avAudioPlayer {
            if player.isPlaying {
                player.pause()
                isPlaying = false
                stopTimer()
            } else {
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playback, mode: .default)
                try? session.setActive(true)
                player.play()
                isPlaying = true
                startTimer()
            }
            return
        }

        guard let player = avPlayer else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)
            if progress >= 1.0 {
                player.seek(to: .zero)
                progress = 0
                currentTime = 0
            }
            player.play()
            isPlaying = true
        }
    }

    func seek(to newProgress: Double) {
        let clamped = min(max(newProgress, 0), 1)
        progress = clamped
        let targetTime = duration * clamped
        currentTime = targetTime

        if let player = avAudioPlayer {
            player.currentTime = targetTime
        } else if let player = avPlayer {
            player.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
        }
    }

    @objc private func playerItemDidReachEnd() {
        isPlaying = false
        progress = 0
        currentTime = 0
        avPlayer?.seek(to: .zero)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        progress = 0
        currentTime = 0
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.avAudioPlayer else { return }
            self.currentTime = player.currentTime
            if self.duration > 0 {
                self.progress = min(max(player.currentTime / self.duration, 0), 1)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func cleanup() {
        if let token = timeObserverToken {
            avPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        NotificationCenter.default.removeObserver(self)
        avPlayer?.pause()
        avPlayer = nil
        avAudioPlayer?.stop()
        avAudioPlayer = nil
        stopTimer()
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
        }
    }

    deinit {
        cleanup()
    }

    var formattedTime: String {
        let displaySeconds = isPlaying || currentTime > 0 ? Int(currentTime) : Int(duration)
        let mins = displaySeconds / 60
        let secs = displaySeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

private extension Double {
    var priceLabel: String {
        String(self).priceLabel
    }
}

// MARK: - Return Order Type Dialog

struct ReturnOrderTypeDialog: View {
    let orderNo: String
    var onDismiss: () -> Void
    var onTypeSelected: (OrderReturnType) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "673AB7").opacity(0.1))
                        .frame(width: 72, height: 72)
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color(hex: "673AB7"))
                }

                VStack(spacing: 8) {
                    Text("Return Order")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppTheme.darkMidnightBlue)
                    Text("Select return type for Order #\(orderNo)")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    returnTypeButton(
                        title: "Full Return",
                        subtitle: "Return all items in this order",
                        icon: "xmark.circle.fill",
                        iconColor: DashboardTheme.dangerRed
                    ) {
                        onTypeSelected(.full)
                    }

                    returnTypeButton(
                        title: "Partial Return",
                        subtitle: "Return selected items only",
                        icon: "list.bullet.rectangle",
                        iconColor: Color(hex: "673AB7")
                    ) {
                        onTypeSelected(.partial)
                    }
                }

                Button("Cancel", action: onDismiss)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 24)
        }
    }

    private func returnTypeButton(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.darkMidnightBlue)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "F9FAFB"))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        OrderDetailScreen(orderId: "12345")
    }
}
