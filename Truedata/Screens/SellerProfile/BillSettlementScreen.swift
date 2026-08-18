//
//  BillSettlementScreen.swift
//  Truedata
//

import SwiftUI
import PhotosUI
import UIKit

struct BillSettlementScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BillSettlementViewModel

    init(sellerId: Int) {
        _viewModel = StateObject(wrappedValue: BillSettlementViewModel(sellerId: sellerId))
    }

    var body: some View {
        VStack(spacing: 0) {
            SellerPaymentAppBar(
                title: "Bill Settlement",
                onBack: { dismiss() },
                onHome: { dismiss() },
                onRefresh: { viewModel.loadBillList() }
            )

            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 14) {
                        pendingAmountCard
                        settlementMethodSection
                        discountSection
                        receiptSection
                        billsSection
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, viewModel.selectedBillIDs.isEmpty ? 24 : 100)
                }
                .background(Color(hex: "F3F4F6"))

                if !viewModel.selectedBillIDs.isEmpty || viewModel.isSubmitting {
                    settlementBottomBar
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadBillList() }
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            viewModel.loadSelectedImage()
        }
        .alert("Notice", isPresented: alertBinding) {
            Button("OK") {
                viewModel.errorMessage = nil
                viewModel.successMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? viewModel.successMessage ?? "")
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil || viewModel.successMessage != nil },
            set: { if !$0 {
                viewModel.errorMessage = nil
                viewModel.successMessage = nil
            }}
        )
    }

    private var pendingAmountCard: some View {
        DashboardCardChrome(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pending Amount")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralMedium)

                HStack(spacing: 8) {
                    Image(systemName: "indianrupeesign.circle.fill")
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    TextField("Enter amount", text: $viewModel.pendingAmount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 18, weight: .bold))
                }
            }
        }
    }

    private var settlementMethodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settlement Method")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .padding(.leading, 4)

            HStack(spacing: 10) {
                ForEach(SellerPaymentMode.allCases) { mode in
                    Button {
                        viewModel.paymentMode = mode
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: mode.iconName)
                                .font(.system(size: 20, weight: .semibold))
                            Text(mode.title)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(viewModel.paymentMode == mode ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.paymentMode == mode ? DashboardTheme.primaryBlue.opacity(0.1) : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    viewModel.paymentMode == mode ? DashboardTheme.primaryBlue : DashboardTheme.surfaceVariant,
                                    lineWidth: viewModel.paymentMode == mode ? 2 : 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var discountSection: some View {
        if !viewModel.bills.isEmpty {
            DashboardCardChrome(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        guard viewModel.selectedBillIDs.count == 1 else { return }
                        viewModel.isDiscountApplied.toggle()
                        if !viewModel.isDiscountApplied {
                            viewModel.discountAmount = ""
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(
                                systemName: viewModel.isDiscountApplied && viewModel.selectedBillIDs.count == 1
                                    ? "checkmark.square.fill"
                                    : "square"
                            )
                            .font(.system(size: 22))
                            .foregroundStyle(
                                viewModel.selectedBillIDs.count == 1
                                    ? DashboardTheme.primaryBlue
                                    : DashboardTheme.neutralMedium.opacity(0.5)
                            )

                            Text("Apply Discount?")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(
                                    viewModel.selectedBillIDs.count == 1
                                        ? DashboardTheme.neutralDark
                                        : DashboardTheme.neutralMedium
                                )

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.selectedBillIDs.count != 1)

                    if viewModel.selectedBillIDs.count != 1 {
                        Text("Select a single bill to apply discount.")
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }

                    if viewModel.isDiscountApplied && viewModel.selectedBillIDs.count == 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Discount Given")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DashboardTheme.neutralMedium)

                            HStack(spacing: 8) {
                                Image(systemName: "indianrupeesign.circle.fill")
                                    .foregroundStyle(DashboardTheme.primaryBlue)
                                TextField("Enter discount amount", text: $viewModel.discountAmount)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 15))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        viewModel.discountValidationError != nil
                                            ? AppTheme.errorRed
                                            : DashboardTheme.surfaceVariant,
                                        lineWidth: 1
                                    )
                            }

                            if let error = viewModel.discountValidationError {
                                Text(error)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppTheme.errorRed)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var receiptSection: some View {
        if viewModel.paymentMode == .upi {
            DashboardCardChrome(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Upload Receipt (Required)")
                        .font(.system(size: 14, weight: .bold))

                    if let imageData = viewModel.imageData, let uiImage = UIImage(data: imageData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button {
                                viewModel.clearImage()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white, .black.opacity(0.55))
                            }
                            .padding(8)
                        }
                    } else {
                        PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Choose Receipt Image")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DashboardTheme.primaryBlue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var billsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pending Bills")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .padding(.leading, 4)

            SellerProfileSearchField(
                text: $viewModel.searchQuery,
                placeholder: "Search by Order ID..."
            )

            if viewModel.isLoading && viewModel.bills.isEmpty {
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if let error = viewModel.errorMessage, viewModel.bills.isEmpty {
                VStack(spacing: 10) {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.errorRed)
                        .multilineTextAlignment(.center)
                    DashboardCompactButton(title: "Retry") {
                        viewModel.loadBillList()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if viewModel.filteredBills.isEmpty {
                Text("No pending bills found.")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(viewModel.filteredBills) { bill in
                    PaymentBillCard(
                        bill: bill,
                        isSelected: viewModel.selectedBillIDs.contains(bill.id),
                        onToggle: { viewModel.toggleBillSelection(bill.id) }
                    )
                }
            }
        }
    }

    private var settlementBottomBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if viewModel.isDiscountApplied, (Double(viewModel.discountAmount) ?? 0) > 0 {
                    Text(viewModel.totalSelectedAmount.currencyLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .strikethrough()
                    Text("Net Total")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DashboardTheme.successGreen)
                    Text(viewModel.netTotal.currencyLabel)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DashboardTheme.successGreen)
                } else {
                    Text("Selected Total")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Text(viewModel.totalSelectedAmount.currencyLabel)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
            }

            Spacer()

            Button {
                viewModel.settlePayment {}
            } label: {
                Group {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Settle")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    viewModel.selectedBillIDs.isEmpty || viewModel.discountValidationError != nil
                        ? DashboardTheme.neutralMedium
                        : DashboardTheme.primaryBlue
                )
                .clipShape(Capsule())
            }
            .disabled(
                viewModel.selectedBillIDs.isEmpty
                    || viewModel.discountValidationError != nil
                    || viewModel.isSubmitting
            )
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.shadow(color: .black.opacity(0.08), radius: 8, y: -2))
    }
}

private struct PaymentBillCard: View {
    let bill: PaymentBillItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Order #\(bill.orderId)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Spacer()
                        Text(bill.deductAmountValue.currencyLabel)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }

                    HStack {
                        Text(SellerProfileDateFormat.displayDate(bill.date))
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        Spacer()
                        Text(bill.paymentModeLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DashboardTheme.infoBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DashboardTheme.infoBlue.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(14)
            .background(isSelected ? DashboardTheme.primaryBlue.opacity(0.08) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? DashboardTheme.primaryBlue.opacity(0.45) : DashboardTheme.surfaceVariant, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SellerPaymentAppBar: View {
    var title: String
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: (() -> Void)?

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

            if let onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                }
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
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
    }
}
