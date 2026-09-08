//
//  ChequeSettlementViewModel.swift
//  Truedata
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class ChequeSettlementViewModel: ObservableObject {

    let sellerId: Int

    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var seller = ChequeSettlementSeller()
    @Published var cheques: [ChequeItem] = []
    @Published var bills: [ChequeBillItem] = []
    @Published var totalPending: Double = 0
    @Published var selectedChequeId: Int?
    @Published var selectedBillIds = Set<Int>()
    @Published var isDiscountApplied = false
    @Published var discountText = ""

    private let service = ChequeSettlementServiceManager()
    private var cancellables = Set<AnyCancellable>()

    init(sellerId: Int) {
        self.sellerId = sellerId
    }

    var selectedCheque: ChequeItem? {
        cheques.first(where: { $0.id == selectedChequeId })
    }

    var selectedBills: [ChequeBillItem] {
        bills.filter { selectedBillIds.contains($0.id) }
    }

    var singleSelectedBill: ChequeBillItem? {
        selectedBills.count == 1 ? selectedBills.first : nil
    }

    var typedDiscount: Double {
        Double(discountText) ?? 0
    }

    var discountError: String? {
        guard isDiscountApplied else { return nil }
        if discountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        if typedDiscount <= 0 {
            return "Enter a discount amount."
        }
        if let bill = singleSelectedBill, typedDiscount > bill.deductAmount {
            return "Discount cannot be more than the bill amount of \(ChequeFormatters.rupees(bill.deductAmount))."
        }
        return nil
    }

    var plan: ChequeSettlementPlan {
        let discount = (isDiscountApplied && discountError == nil) ? typedDiscount : 0
        return ChequeSettlementPlan.make(
            billsTotal: selectedBills.reduce(0) { $0 + $1.deductAmount },
            chequeAvailable: selectedCheque?.spendable ?? 0,
            discount: discount
        )
    }

    var canSubmit: Bool {
        selectedCheque != nil
            && !selectedBills.isEmpty
            && plan.isSettleable
            && discountError == nil
            && !isSubmitting
    }

    var settleNote: String? {
        var parts: [String] = []
        if plan.discount > 0 {
            parts.append("\(ChequeFormatters.rupees(plan.discount)) written off")
        }
        if plan.chequeLeftover > 0 {
            parts.append("\(ChequeFormatters.rupees(plan.chequeLeftover)) left on the cheque")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    func load() {
        isLoading = true
        errorMessage = nil

        service.getChequeBillList(sellerId: sellerId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status {
                    self.seller = response.data.seller
                    self.cheques = response.data.cheques
                    self.bills = response.data.billList
                    self.totalPending = response.data.totalPending
                    self.pruneStaleSelections()
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load cheque bills."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func selectCheque(_ chequeId: Int) {
        selectedChequeId = chequeId
    }

    func toggleBill(_ billId: Int) {
        if selectedBillIds.contains(billId) {
            selectedBillIds.remove(billId)
        } else {
            selectedBillIds.insert(billId)
        }
        if selectedBillIds.count != 1 {
            isDiscountApplied = false
            discountText = ""
        }
    }

    func toggleAllBills() {
        if selectedBillIds.count == bills.count {
            selectedBillIds.removeAll()
        } else {
            selectedBillIds = Set(bills.map(\.id))
        }
        if selectedBillIds.count != 1 {
            isDiscountApplied = false
            discountText = ""
        }
    }

    func submit() {
        guard let chequeId = selectedChequeId else {
            errorMessage = "Please select a cheque."
            return
        }
        guard canSubmit else {
            errorMessage = discountError ?? "Select a cheque and at least one bill to settle."
            return
        }

        isSubmitting = true
        errorMessage = nil

        service.settleCheque(
            sellerId: sellerId,
            chequeId: chequeId,
            billIds: Array(selectedBillIds).sorted(),
            amount: ChequeFormatters.plainAmount(plan.amount),
            isDiscountApplied: plan.discount > 0,
            discount: ChequeFormatters.plainAmount(plan.discount)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSubmitting = false
            if case .failure(let error) = completion {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSubmitting = false
            if response.status {
                self.successMessage = response.message.isEmptyString
                    ? "Cheque settlement completed successfully."
                    : response.message
                self.selectedBillIds.removeAll()
                self.discountText = ""
                self.isDiscountApplied = false
                self.load()
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to settle cheque."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    private func pruneStaleSelections() {
        let liveCheques = Set(cheques.map(\.id))
        let liveBills = Set(bills.map(\.id))

        if let selected = selectedChequeId, liveCheques.contains(selected) {
            // keep current selection
        } else if cheques.count == 1 {
            selectedChequeId = cheques.first?.id
        } else {
            selectedChequeId = nil
        }

        selectedBillIds = selectedBillIds.intersection(liveBills)
        if selectedBillIds.count != 1 {
            isDiscountApplied = false
            discountText = ""
        }
    }
}
