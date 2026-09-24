//
//  PendingSettleChequeScreen.swift
//  Truedata
//

import SwiftUI

struct PendingSettleChequeScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PendingSettleChequeViewModel()
    @State private var selectedSellerId: Int?
    @State private var previewImageURL: String?

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: "Cheques Awaiting Settlement",
                onBack: { dismiss() },
                onHome: { dismiss() },
                onRefresh: { viewModel.load(isRefresh: true) }
            )

            ZStack {
                DashboardTheme.surface.ignoresSafeArea()

                if viewModel.isLoading && viewModel.sellers.isEmpty {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                } else if let error = viewModel.errorMessage, viewModel.sellers.isEmpty {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        PrimaryActionButton(title: "Retry") {
                            viewModel.load(isRefresh: true)
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                } else if viewModel.sellers.isEmpty {
                    VStack(spacing: 8) {
                        Text("Nothing left to settle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Text("Approved cheques waiting to be applied to bills show up here.")
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .multilineTextAlignment(.center)
                        PrimaryActionButton(title: "Refresh") {
                            viewModel.load(isRefresh: true)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                    }
                    .padding(24)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            QueueSummaryCard(
                                retailerCount: viewModel.sellers.count,
                                chequeCount: viewModel.chequeCount,
                                totalAmount: viewModel.totalChequeAmount,
                                hasMore: viewModel.hasMore
                            )

                            ForEach(viewModel.sellers) { seller in
                                SellerChequeCard(
                                    seller: seller,
                                    onViewImage: { previewImageURL = $0 },
                                    onSettle: { selectedSellerId = seller.sellerId }
                                )
                                .onAppear {
                                    viewModel.loadMoreIfNeeded(current: seller)
                                }
                            }

                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .tint(DashboardTheme.primaryBlue)
                                    .padding(.vertical, 12)
                            }

                            if !viewModel.hasMore {
                                Text("You've reached the end.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DashboardTheme.neutralLight)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }

                            Spacer().frame(height: 48)
                        }
                        .padding(14)
                    }
                }
            }
        }
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Refresh when returning from settle screen; skip duplicate fire if already loading.
            if !viewModel.isLoading && !viewModel.isLoadingMore {
                viewModel.load(isRefresh: true)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedSellerId != nil },
            set: { if !$0 { selectedSellerId = nil } }
        )) {
            if let sellerId = selectedSellerId {
                ChequeSettlementScreen(sellerId: sellerId)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { previewImageURL != nil },
            set: { if !$0 { previewImageURL = nil } }
        )) {
            chequeImagePreview
        }
    }

    @ViewBuilder
    private var chequeImagePreview: some View {
        if let url = previewImageURL {
            ZStack {
                Color.black.ignoresSafeArea()
                RemoteImage(url: url, contentMode: .fit)
                    .padding(24)
                VStack {
                    HStack {
                        Spacer()
                        Button { previewImageURL = nil } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
        }
    }
}

private struct QueueSummaryCard: View {
    let retailerCount: Int
    let chequeCount: Int
    let totalAmount: Double
    let hasMore: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hasMore ? "Cheque money loaded so far" : "Cheque money to settle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            Text(ChequeFormatters.rupees(totalAmount))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white)
            Text(
                "\(chequeCount) cheque\(chequeCount == 1 ? "" : "s") across \(retailerCount) retailer\(retailerCount == 1 ? "" : "s")"
            )
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.85))
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [DashboardTheme.primaryBlue, DashboardTheme.primaryBlueDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct SellerChequeCard: View {
    let seller: PendingSettleChequeSeller
    var onViewImage: (String) -> Void
    var onSettle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [DashboardTheme.accentTeal, DashboardTheme.primaryBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 4)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(DashboardTheme.primaryBlue.opacity(0.10))
                            .frame(width: 40, height: 40)
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(seller.displayTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .lineLimit(1)
                        Text(seller.name)
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ChequeFormatters.rupees(seller.totalChequeAmount))
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(DashboardTheme.accentTeal)
                        Text("on \(seller.chequeCount) cheque\(seller.chequeCount == 1 ? "" : "s")")
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralLight)
                    }
                }

                if let mobile = SellerContactVisibility.visibleMobile(seller.mobile) {
                    Text(mobile)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DashboardTheme.neutralMedium.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.top, 10)
                }

                if !seller.cheques.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(seller.cheques) { cheque in
                            ChequeSummaryChip(cheque: cheque, onViewImage: onViewImage)
                        }
                    }
                    .padding(.top, 12)
                }

                Button(action: onSettle) {
                    HStack(spacing: 7) {
                        Text("Settle")
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DashboardTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
            .padding(14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

private struct ChequeSummaryChip: View {
    let cheque: ChequeItem
    var onViewImage: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.accentTeal)
                Text("Cheque #\(cheque.id)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
                Text(ChequeFormatters.rupees(cheque.spendable))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }

            if cheque.isPartlySpent {
                Text("remaining of \(ChequeFormatters.rupees(cheque.amount))")
                    .font(.system(size: 11))
                    .foregroundStyle(DashboardTheme.pickupOrange)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    metaRow(icon: "calendar.badge.checkmark", text: ChequeFormatters.clearingLabel(cheque.chequeClearDate))
                    if !cheque.date.isEmptyString, cheque.date != cheque.chequeClearDate {
                        metaRow(icon: "calendar", text: "Received \(ChequeFormatters.chequeDate(cheque.date))")
                    }
                }
                Spacer(minLength: 8)
                if let image = cheque.image, !image.isEmptyString {
                    Button {
                        onViewImage(image)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 12))
                            Text("Image")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(DashboardTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }

    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(DashboardTheme.neutralLight)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .lineLimit(1)
        }
    }
}
