//
//  ChequeSettlementScreen.swift
//  Truedata
//

import SwiftUI

struct ChequeSettlementScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ChequeSettlementViewModel
    @State private var previewImageURL: String?
    @State private var showConfirm = false

    init(sellerId: Int) {
        _viewModel = StateObject(wrappedValue: ChequeSettlementViewModel(sellerId: sellerId))
    }

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: "Settle Approved Cheques",
                onBack: { dismiss() },
                onHome: { dismiss() },
                onRefresh: { viewModel.load() }
            )

            ZStack(alignment: .bottom) {
                DashboardTheme.surface.ignoresSafeArea()

                if viewModel.isLoading && viewModel.cheques.isEmpty && viewModel.bills.isEmpty {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage,
                          viewModel.cheques.isEmpty,
                          viewModel.bills.isEmpty,
                          viewModel.successMessage == nil {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        PrimaryActionButton(title: "Retry") {
                            viewModel.load()
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            sellerHeader
                            discountSection
                            chequeSectionHeader
                            chequesRow
                            billsSectionHeader
                            billsList
                        }
                        .padding(14)
                        .padding(.bottom, viewModel.selectedCheque != nil && !viewModel.selectedBills.isEmpty ? 140 : 40)
                    }

                    if viewModel.selectedCheque != nil && !viewModel.selectedBills.isEmpty {
                        settleBottomBar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                if viewModel.isLoading && (!viewModel.cheques.isEmpty || !viewModel.bills.isEmpty) {
                    Color.white.opacity(0.55).ignoresSafeArea()
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                }

                if viewModel.isSubmitting {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                }
            }
        }
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load() }
        .alert("Success", isPresented: successBinding) {
            Button("OK") {
                viewModel.successMessage = nil
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("Confirm settlement", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Settle") { viewModel.submit() }
        } message: {
            Text(confirmMessage)
        }
        .fullScreenCover(isPresented: Binding(
            get: { previewImageURL != nil },
            set: { if !$0 { previewImageURL = nil } }
        )) {
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
        .animation(.easeInOut(duration: 0.22), value: viewModel.selectedBillIds)
        .animation(.easeInOut(duration: 0.22), value: viewModel.selectedChequeId)
    }

    private var confirmMessage: String {
        var lines = [
            "Settle \(ChequeFormatters.rupees(viewModel.plan.amount)) across \(viewModel.selectedBills.count) bill\(viewModel.selectedBills.count == 1 ? "" : "s") using cheque #\(viewModel.selectedChequeId ?? 0)."
        ]
        if viewModel.plan.discount > 0 {
            lines.append("\(ChequeFormatters.rupees(viewModel.plan.discount)) will be written off.")
        }
        if viewModel.plan.shortfall > 0 {
            lines.append("\(ChequeFormatters.rupees(viewModel.plan.shortfall)) stays outstanding.")
        }
        return lines.joined(separator: "\n")
    }

    private var successBinding: Binding<Bool> {
        Binding(get: { viewModel.successMessage != nil }, set: { if !$0 { viewModel.successMessage = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && (!viewModel.cheques.isEmpty || !viewModel.bills.isEmpty) },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var sellerHeader: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [DashboardTheme.accentTeal, DashboardTheme.primaryBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 4)

            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(DashboardTheme.primaryBlue.opacity(0.10))
                        .frame(width: 40, height: 40)
                    Image(systemName: "storefront.fill")
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.seller.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(1)
                    Text(viewModel.seller.name)
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .lineLimit(1)
                    if !viewModel.seller.mobile.isEmptyString {
                        Text(viewModel.seller.mobile)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DashboardTheme.neutralMedium.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.top, 4)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total pending")
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralLight)
                    Text(ChequeFormatters.rupees(viewModel.totalPending))
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(DashboardTheme.dangerRed)
                }
            }
            .padding(14)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var discountSection: some View {
        if let bill = viewModel.singleSelectedBill {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $viewModel.isDiscountApplied) {
                    Text("Apply discount")
                        .font(.system(size: 14, weight: .semibold))
                }
                .tint(DashboardTheme.primaryBlue)
                .onChange(of: viewModel.isDiscountApplied) { _, enabled in
                    if !enabled { viewModel.discountText = "" }
                }

                Text(
                    "Written off \(bill.orderId.isEmptyString ? "bill #\(bill.id)" : bill.orderId) — the cheque covers the rest"
                )
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)

                if viewModel.isDiscountApplied {
                    TextField("Discount amount", text: $viewModel.discountText)
                        .keyboardType(.decimalPad)
                        .padding(12)
                        .background(DashboardTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
                        }

                    if let error = viewModel.discountError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.dangerRed)
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
            }
        }
    }

    private var chequeSectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Choose a cheque")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text("One cheque per settlement")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            Spacer()
            if !viewModel.cheques.isEmpty {
                Text("\(viewModel.cheques.count) available")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DashboardTheme.primaryBlue.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var chequesRow: some View {
        if viewModel.cheques.isEmpty {
            emptySection(icon: "creditcard.fill", text: "No approved cheques left for this retailer.")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.cheques) { cheque in
                        ChequeChoiceCard(
                            cheque: cheque,
                            isSelected: viewModel.selectedChequeId == cheque.id,
                            onSelect: { viewModel.selectCheque(cheque.id) },
                            onViewImage: { previewImageURL = $0 }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var billsSectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Select bills")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text("\(viewModel.selectedBills.count) of \(viewModel.bills.count) selected")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            Spacer()
            if !viewModel.bills.isEmpty {
                Button(viewModel.selectedBillIds.count == viewModel.bills.count ? "Clear all" : "Select all") {
                    viewModel.toggleAllBills()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryBlue)
            }
        }
    }

    @ViewBuilder
    private var billsList: some View {
        if viewModel.bills.isEmpty {
            emptySection(icon: "doc.text.fill", text: "No outstanding bills — nothing to settle against.")
        } else {
            ForEach(viewModel.bills) { bill in
                BillChoiceRow(
                    bill: bill,
                    isSelected: viewModel.selectedBillIds.contains(bill.id),
                    onToggle: { viewModel.toggleBill(bill.id) }
                )
            }
        }
    }

    private func emptySection(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(DashboardTheme.neutralLight)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
    }

    private var settleBottomBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(ChequeFormatters.rupees(viewModel.plan.amount))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Spacer()
                Text("Settling \(viewModel.selectedBills.count) bill\(viewModel.selectedBills.count == 1 ? "" : "s")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }

            if viewModel.plan.discount > 0 {
                Text("Gross \(ChequeFormatters.rupees(viewModel.plan.billsTotal))")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralLight)
                    .strikethrough()
            }

            if let note = viewModel.settleNote {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }

            if viewModel.plan.shortfall > 0 {
                Text("This cheque covers part of it — \(ChequeFormatters.rupees(viewModel.plan.shortfall)) stays outstanding.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardTheme.pickupOrange)
            }

            Button {
                showConfirm = true
            } label: {
                Text("Settle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.canSubmit ? DashboardTheme.primaryBlue : DashboardTheme.primaryBlue.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSubmit)
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
    }
}

private struct ChequeChoiceCard: View {
    let cheque: ChequeItem
    let isSelected: Bool
    var onSelect: () -> Void
    var onViewImage: (String) -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Cheque #\(cheque.id)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.surfaceVariant)
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                Text(ChequeFormatters.rupees(cheque.spendable))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(DashboardTheme.neutralDark)

                if cheque.isPartlySpent {
                    Text("remaining of \(ChequeFormatters.rupees(cheque.amount))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.pickupOrange)
                }

                metaRow(icon: "calendar.badge.checkmark", text: ChequeFormatters.clearingLabel(cheque.chequeClearDate))
                if !cheque.date.isEmptyString, cheque.date != cheque.chequeClearDate {
                    metaRow(icon: "calendar", text: "Received \(ChequeFormatters.chequeDate(cheque.date))")
                }

                if let image = cheque.image, !image.isEmptyString {
                    Button {
                        onViewImage(image)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 12))
                            Text("View cheque image")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .frame(minWidth: 210, alignment: .leading)
            .background(
                isSelected
                ? DashboardTheme.primaryBlue.opacity(0.06)
                : Color.white
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? DashboardTheme.primaryBlue : DashboardTheme.surfaceVariant,
                        lineWidth: isSelected ? 1.6 : 1
                    )
            }
            .shadow(color: isSelected ? .black.opacity(0.08) : .clear, radius: 3, y: 1)
        }
        .buttonStyle(.plain)
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

private struct BillChoiceRow: View {
    let bill: ChequeBillItem
    let isSelected: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? DashboardTheme.successGreen : DashboardTheme.surfaceVariant)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.orderId.isEmptyString ? "Bill #\(bill.id)" : bill.orderId)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(1)
                    Text(ChequeFormatters.chequeDate(bill.date))
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(ChequeFormatters.rupees(bill.deductAmount))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isSelected ? DashboardTheme.successGreen : DashboardTheme.neutralDark)
                    if bill.amount > bill.deductAmount {
                        Text("of \(ChequeFormatters.rupees(bill.amount))")
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralLight)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(isSelected ? DashboardTheme.successGreen.opacity(0.07) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? DashboardTheme.successGreen : DashboardTheme.surfaceVariant,
                        lineWidth: isSelected ? 1.4 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
