//
//  ApproveBillsScreen.swift
//  Truedata
//

import SwiftUI

struct ApproveBillsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ApproveBillsViewModel()
    @State private var billToApprove: PendingBillItem?
    @State private var imagePreviewURL: String?

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                ApproveBillsAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() }
                )

                content
            }

            if viewModel.isApproving {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.loadPendingBills() }
        .alert("Approve Payment", isPresented: approveAlertBinding) {
            Button("Cancel", role: .cancel) {
                billToApprove = nil
            }
            Button("Approve") {
                if let bill = billToApprove {
                    viewModel.approveBill(bill)
                }
                billToApprove = nil
            }
        } message: {
            if let bill = billToApprove {
                Text("Approve \(bill.amount.priceLabel) payment from \(bill.sellerName)?")
            }
        }
        .alert("Success", isPresented: successAlertBinding) {
            Button("OK") {
                viewModel.successMessage = nil
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: imagePreviewBinding) {
            if let url = imagePreviewURL {
                BillImagePreviewScreen(imageURL: url) {
                    imagePreviewURL = nil
                }
            }
        }
    }

    private var approveAlertBinding: Binding<Bool> {
        Binding(
            get: { billToApprove != nil && !viewModel.isApproving },
            set: { if !$0 { billToApprove = nil } }
        )
    }

    private var successAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.successMessage != nil },
            set: { if !$0 { viewModel.successMessage = nil } }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !viewModel.bills.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var imagePreviewBinding: Binding<Bool> {
        Binding(
            get: { imagePreviewURL != nil },
            set: { if !$0 { imagePreviewURL = nil } }
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.bills.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
                Spacer()
            }
        } else if let error = viewModel.errorMessage, viewModel.bills.isEmpty {
            VStack(spacing: 14) {
                Spacer()
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.errorRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                DashboardCompactButton(title: "Retry") {
                    viewModel.loadPendingBills()
                }
                Spacer()
            }
        } else if viewModel.bills.isEmpty {
            VStack {
                Spacer()
                Text("No pending bills found.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.bills) { bill in
                        PendingBillCard(
                            bill: bill,
                            onApprove: { billToApprove = bill },
                            onViewImage: { imagePreviewURL = bill.image }
                        )
                    }
                }
                .padding(8)
            }
            .refreshable {
                viewModel.loadPendingBills()
            }
        }
    }
}

// MARK: - App Bar

private struct ApproveBillsAppBar: View {
    var onBack: () -> Void
    var onHome: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("Approve Pending Bills")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

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
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
    }
}

// MARK: - Bill Card

private struct PendingBillCard: View {
    let bill: PendingBillItem
    var onApprove: () -> Void
    var onViewImage: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(bill.sellerName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(bill.amount.priceLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                Divider()

                billInfoRow(label: "Staff", value: bill.riderName)
                billInfoRow(label: "Mode", value: bill.orderId)
                billInfoRow(label: "Date", value: bill.date)

                if !bill.image.isEmptyString {
                    Button(action: onViewImage) {
                        HStack {
                            Text("Image:")
                                .font(.system(size: 11))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.system(size: 12))
                                Text("View")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(DashboardTheme.primaryBlue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            Button(action: onApprove) {
                Text("Approve")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DashboardTheme.primaryBlue)
            }
            .buttonStyle(.plain)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 0.5)
        }
    }

    private func billInfoRow(label: String, value: String) -> some View {
        HStack {
            Text("\(label):")
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(1)
        }
    }
}

// MARK: - Image Preview

private struct BillImagePreviewScreen: View {
    let imageURL: String
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Bill Image")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))

                RemoteImage(url: imageURL, contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(zoomGesture)
                    .padding(12)

                Text("Pinch to zoom")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.bottom, 16)
            }
        }
    }

    private var zoomGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(max(lastScale * value, 0.5), 5)
                }
                .onEnded { _ in
                    lastScale = scale
                    if scale <= 1 {
                        scale = 1
                        lastScale = 1
                        offset = .zero
                        lastOffset = .zero
                    }
                },
            DragGesture()
                .onChanged { value in
                    guard scale > 1 else { return }
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    lastOffset = offset
                }
        )
    }
}

#Preview {
    NavigationStack {
        ApproveBillsScreen()
    }
}
