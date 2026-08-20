//
//  CreateOrderCartSheet.swift
//  Truedata
//

import SwiftUI
import UIKit

struct CreateOrderCartSheet: View {

    @ObservedObject var cartViewModel: CreateOrderCartViewModel
    var onDismiss: () -> Void
    var onAddMore: () -> Void
    var onContinue: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if cartViewModel.items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(cartViewModel.items) { item in
                                CreateOrderCartItemRow(
                                    item: item,
                                    onQuantityChange: { cartViewModel.updateQuantity(for: item.id, quantity: $0) },
                                    onDelete: { cartViewModel.removeItem(item.id) }
                                )

                                if item.id != cartViewModel.items.last?.id {
                                    Divider().overlay(DashboardTheme.surfaceVariant.opacity(0.8))
                                }
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                    }
                }

                footerSection
            }
            .background(Color(hex: "F3F4F6"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Review Your Order")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAddMore) {
                        Text("Add More")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .alert("Notice", isPresented: errorBinding) {
            Button("OK") { cartViewModel.errorMessage = nil }
        } message: {
            Text(cartViewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { cartViewModel.errorMessage != nil },
            set: { if !$0 { cartViewModel.errorMessage = nil } }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "cart")
                .font(.system(size: 36))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text("Your cart is empty")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Total Items")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
                Text("\(cartViewModel.totalItems)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }

            Divider().overlay(DashboardTheme.surfaceVariant)

            HStack {
                Text("Grand Total")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
                Text(cartViewModel.grandTotal.priceLabel)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            HStack(spacing: 10) {
                Button(action: onAddMore) {
                    Text("Add More")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DashboardTheme.primaryBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    cartViewModel.proceedToSubmit { success in
                        guard success else { return }
                        onDismiss()
                        onContinue()
                    }
                } label: {
                    Group {
                        if cartViewModel.isSyncing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.darkMidnightBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(cartViewModel.isSyncing || !cartViewModel.hasItems)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.darkMidnightBlue.opacity(0.12))
                .frame(height: 1)
        }
    }
}

private struct CreateOrderCartItemRow: View {
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
                RemoteImage(url: item.productImage, contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .background(DashboardTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.productName.uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(2)

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
}

private extension Double {
    var priceLabel: String {
        String(self).priceLabel
    }
}

struct CreateOrderSubmitScreen: View {

    @ObservedObject var cartViewModel: CreateOrderCartViewModel
    @StateObject private var locationHelper = LocationHelper()
    @StateObject private var audioRecorder = AudioRemarkRecorder()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var remark = ""

    var onFinish: (CreateOrderFinishAction) -> Void

    var body: some View {
        ZStack {
            submitContent

            if cartViewModel.showSuccessScreen {
                CreateOrderSuccessOverlay(
                    message: cartViewModel.successMessage,
                    onViewOrders: { onFinish(.viewOrders) },
                    onGoToDashboard: { onFinish(.goToDashboard) },
                    onViewSeller: { onFinish(.viewSeller) }
                )
            }
        }
    }

    private var submitContent: some View {
        VStack(spacing: 0) {
            CreateOrderAppBar(
                title: "Review Delivery Details",
                onBack: { dismiss() },
                onHome: { onFinish(.goToDashboard) }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sellerCard
                    orderSummaryCard
                    remarksCard
                    audioRemarkCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .background(Color(hex: "F3F4F6"))

            footerSection
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Notice", isPresented: errorBinding) {
            Button("OK") { cartViewModel.errorMessage = nil }
        } message: {
            Text(cartViewModel.errorMessage ?? "")
        }
        .onAppear {
            audioRecorder.refreshPermission()
            locationHelper.refreshLocation()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                audioRecorder.refreshPermission()
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { cartViewModel.errorMessage != nil },
            set: { if !$0 { cartViewModel.errorMessage = nil } }
        )
    }

    private var sellerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Seller details")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)

            Text(cartViewModel.sellerShopName.isEmptyString ? "Seller" : cartViewModel.sellerShopName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)

            if !cartViewModel.sellerAddress.isEmptyString {
                Text(cartViewModel.sellerAddress)
                    .font(.system(size: 13))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var orderSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Order Summary")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)

            ForEach(cartViewModel.submitItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.productName.uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(DashboardTheme.neutralDark)

                            Text(item.quantityLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(DashboardTheme.neutralMedium)

                            if !item.weightLabel.isEmptyString {
                                Text(item.weightLabel)
                                    .font(.system(size: 12))
                                    .foregroundStyle(DashboardTheme.neutralMedium)
                            }
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(item.lineTotal.priceLabel)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(DashboardTheme.primaryBlue)

                            if !item.gstLabel.isEmptyString {
                                Text(item.gstLabel)
                                    .font(.system(size: 12))
                                    .foregroundStyle(DashboardTheme.neutralMedium)
                            }
                        }
                    }
                }
                .padding(12)
                .background(DashboardTheme.surfaceVariant.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if item.id != cartViewModel.submitItems.last?.id {
                    Divider().overlay(DashboardTheme.surfaceVariant)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var remarksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("Remarks")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text("(optional)")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }

            Text("Enter text remark (optional)")
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)

            TextField(
                "Any special instructions...",
                text: $remark,
                axis: .vertical
            )
            .lineLimit(3...5)
            .font(.system(size: 14))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var audioRemarkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio Remark (Max 60s)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)

            switch audioRecorder.permissionState {
            case .unknown, .denied:
                VStack(alignment: .leading, spacing: 12) {
                    Text("Microphone permission is required to record voice remarks.")
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.neutralMedium)

                    Button {
                        if audioRecorder.permissionState == .denied {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } else {
                            audioRecorder.requestPermission()
                        }
                    } label: {
                        Text(audioRecorder.permissionState == .denied ? "Open Settings" : "Grant Permission")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(DashboardTheme.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(hex: "F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            case .granted:
                HStack(spacing: 12) {
                    Button {
                        audioRecorder.toggleRecording()
                    } label: {
                        Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(audioRecorder.isRecording ? DashboardTheme.dangerRed : DashboardTheme.primaryBlue)
                    }
                    .buttonStyle(.plain)
                    .disabled(audioRecorder.isPlaying)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            audioRecorder.isRecording
                                ? "Recording..."
                                : (audioRecorder.hasRecording ? "Voice remark ready" : "Hold to record")
                        )
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)

                        Text("\(audioRecorder.formattedElapsed) / 1:00")
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(hex: "F9FAFB"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var footerSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Grand Total")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
                Text(cartViewModel.grandTotal.priceLabel)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            Button {
                submitOrder()
            } label: {
                Group {
                    if cartViewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Submit Order")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.darkMidnightBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(cartViewModel.isSubmitting)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.white)
        .overlay(alignment: .top) {
            Divider().overlay(DashboardTheme.surfaceVariant)
        }
    }

    private func submitOrder() {
        guard let snapshot = locationHelper.snapshot else {
            cartViewModel.errorMessage = locationHelper.errorMessage
                ?? "Unable to fetch location. Please enable GPS and try again."
            locationHelper.refreshLocation()
            return
        }

        cartViewModel.submitOrder(
            remark: remark.trimmingCharacters(in: .whitespacesAndNewlines),
            audioRemark: audioRecorder.audioRemarkPayload,
            latitude: String(snapshot.latitude),
            longitude: String(snapshot.longitude)
        )
    }
}

struct CreateOrderSuccessOverlay: View {
    let message: String
    var onViewOrders: () -> Void
    var onGoToDashboard: () -> Void
    var onViewSeller: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "34C759"),
                                    Color(hex: "28A745")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: Color(hex: "34C759").opacity(0.35), radius: 10, y: 4)

                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("Order Placed Successfully")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                VStack(spacing: 10) {
                    Button(action: onViewOrders) {
                        Text("View Orders")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.darkMidnightBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onGoToDashboard) {
                        Text("Go to Dashboard")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "EAF2FF"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onViewSeller) {
                        Text("View Seller")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 28)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)
            .padding(.horizontal, 28)
        }
    }
}
