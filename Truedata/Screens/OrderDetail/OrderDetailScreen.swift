import SwiftUI
import AVFoundation
import Combine

struct OrderDetailScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OrderDetailViewModel
    @State private var previewImageURL: String?
    @State private var actionMessage: String?
    @State private var showCancelConfirm = false
    @State private var showChangeSeller = false
    @State private var showEditOrder = false
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
                Color(hex: "F3F4F6")
                    .ignoresSafeArea()

                content

                if viewModel.isCancelling {
                    Color.black.opacity(0.15)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                        .scaleEffect(1.2)
                }
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
                viewModel.cancelOrder { success, message in
                    actionMessage = message
                    if success {
                        viewModel.loadOrderDetail()
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

                if order.hasAnyRemark {
                    Divider().overlay(DashboardTheme.surfaceVariant)
                    remarksSection(order)
                }

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
        VStack(alignment: .leading, spacing: 10) {
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

            FlowLayout(spacing: 8, lineSpacing: 8) {
                statusChip(OrderDetailStatusMapper.deliveryStatus(order.status))
                statusChip(OrderDetailStatusMapper.paymentStatus(order.transactionStatus))

                if !order.orderSourceDisplay.isEmptyString {
                    orderSourceChip(order)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private func orderSourceChip(_ order: OrderDetailData) -> some View {
        HStack(spacing: 4) {
            Image(systemName: order.orderSourceIcon)
                .font(.system(size: 10))
            Text(order.orderSourceDisplay)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(order.orderSourceDisplay == "By Retailer" ? Color(hex: "0D9488") : DashboardTheme.primaryBlue)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            (order.orderSourceDisplay == "By Retailer" ? Color(hex: "0D9488") : DashboardTheme.primaryBlue)
                .opacity(0.12)
        )
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func remarksSection(_ order: OrderDetailData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Remarks")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)

                Spacer()

                if order.hasAudioRemark || order.hasRetailerAudioRemark {
                    Text("History")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.dangerRed)
                }
            }

            // Salesperson Remark
            if order.hasAudioRemark {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Salesperson Voice Note")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    OrderDetailAudioPlayerView(audioURLString: order.audioRemark)
                }
            }

            if order.hasRemark {
                VStack(alignment: .leading, spacing: 4) {
                    if order.hasRetailerRemark || order.hasRetailerAudioRemark {
                        Text("Salesperson Remark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    OrderDetailTextRemarkView(remark: order.remark)
                }
            }

            // Retailer Remark
            if order.hasRetailerAudioRemark {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Retailer Voice Note")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    OrderDetailAudioPlayerView(audioURLString: order.retailerAudioRemark)
                }
            }

            if order.hasRetailerRemark {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Retailer Remark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    OrderDetailTextRemarkView(remark: order.retailerRemark)
                }
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

                if !order.orderSourceDisplay.isEmptyString {
                    sellerInfoRow(icon: order.orderSourceIcon, label: "Order Source", value: order.orderSourceDisplay)
                }
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
                        color: DashboardTheme.primaryBlue
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
                        color: AppTheme.darkMidnightBlue
                    )
                }
                .buttonStyle(.plain)
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
        let clean = base64String.components(separatedBy: ",").last ?? base64String
        guard let data = Data(base64Encoded: clean, options: .ignoreUnknownCharacters) else { return }
        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("order-audio-\(UUID().uuidString).m4a")
            try data.write(to: url)
            self.tempFileURL = url
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.duration = player.duration
            self.avAudioPlayer = player
        } catch {
            print("Error loading base64 audio: \(error)")
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

#Preview {
    NavigationStack {
        OrderDetailScreen(orderId: "12345")
    }
}
