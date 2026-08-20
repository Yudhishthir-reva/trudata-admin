//
//  EditOrderSubmitScreen.swift
//  Truedata
//

import SwiftUI
import UIKit

enum EditOrderFinishAction {
    case viewOrders
    case goToDashboard
    case viewSeller
}

struct EditOrderSubmitScreen: View {

    @ObservedObject var viewModel: EditOrderViewModel
    @StateObject private var audioRecorder = AudioRemarkRecorder()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var remark = ""
    var onFinish: (EditOrderFinishAction) -> Void

    init(
        viewModel: EditOrderViewModel,
        onFinish: @escaping (EditOrderFinishAction) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            submitContent

            if viewModel.showSuccessScreen {
                EditOrderSuccessOverlay(
                    message: viewModel.successMessage,
                    onViewOrders: { onFinish(.viewOrders) },
                    onGoToDashboard: { onFinish(.goToDashboard) },
                    onViewSeller: { onFinish(.viewSeller) }
                )
            }
        }
    }

    private var submitContent: some View {
        VStack(spacing: 0) {
            SellerPaymentAppBar(
                title: "Edit Order \(viewModel.orderNo)",
                onBack: { dismiss() },
                onHome: { dismiss() }
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
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            audioRecorder.refreshPermission()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                audioRecorder.refreshPermission()
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }

    private var sellerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Seller Details")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)

            Text(viewModel.sellerShopName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
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

            ForEach(activeItems) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.productName.uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)

                    Text(itemSummaryLabel(for: item))
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.neutralMedium)

                    Text(item.lineTotal.priceLabel)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                if item.id != activeItems.last?.id {
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
                VStack(spacing: 12) {
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
                            Text(audioRecorder.isRecording ? "Recording..." : (audioRecorder.hasRecording ? "Voice remark ready" : "Tap mic to record"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DashboardTheme.neutralDark)

                            Text("\(audioRecorder.formattedElapsed) / 1:00")
                                .font(.system(size: 12))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }

                        Spacer()
                    }

                    if audioRecorder.hasRecording {
                        HStack(spacing: 10) {
                            Button {
                                audioRecorder.togglePlayback()
                            } label: {
                                Label(
                                    audioRecorder.isPlaying ? "Stop" : "Play",
                                    systemImage: audioRecorder.isPlaying ? "stop.fill" : "play.fill"
                                )
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DashboardTheme.primaryBlue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(DashboardTheme.primaryBlue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                audioRecorder.deleteRecording()
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(DashboardTheme.dangerRed)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(DashboardTheme.dangerRed.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
                Text(viewModel.grandTotal.priceLabel)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            Button {
                viewModel.submitOrder(
                    remark: remark.trimmingCharacters(in: .whitespacesAndNewlines),
                    audioRemark: audioRecorder.audioRemarkPayload
                )
            } label: {
                Group {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Update Order")
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
            .disabled(viewModel.isSubmitting)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color.white)
        .overlay(alignment: .top) {
            Divider().overlay(DashboardTheme.surfaceVariant)
        }
    }

    private var activeItems: [EditOrderLineItem] {
        viewModel.items.filter { $0.quantity > 0 }
    }

    private func itemSummaryLabel(for item: EditOrderLineItem) -> String {
        let grams = CreateOrderVariantParser.weightInGrams(for: item.variantName)
            ?? CreateOrderVariantParser.weightInGrams(for: item.productName)
            ?? 0
        let totalKg = grams > 0 ? (grams * Double(item.quantity)) / 1000.0 : 0

        if !item.variantName.isEmptyString {
            if totalKg > 0 {
                return "\(item.quantity) pkt X \(item.variantName) (Totaling \(String(format: "%.1f", totalKg)) kg)"
            }
            return "\(item.quantity) pkt X \(item.variantName)"
        }

        return "\(item.quantity) pkt"
    }
}

private struct EditOrderSuccessOverlay: View {
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

                Text("Order Updated Successfully")
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

private extension Double {
    var priceLabel: String {
        String(self).priceLabel
    }
}
