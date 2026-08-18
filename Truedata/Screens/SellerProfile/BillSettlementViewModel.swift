//
//  BillSettlementViewModel.swift
//  Truedata
//

import SwiftUI
import Combine
import PhotosUI

final class BillSettlementViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var bills: [PaymentBillItem] = []
    @Published var pendingAmount = ""
    @Published var searchQuery = ""
    @Published var selectedBillIDs = Set<Int>()
    @Published var paymentMode: SellerPaymentMode?
    @Published var isDiscountApplied = false
    @Published var discountAmount = ""
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var imageData: Data?

    private let sellerId: String
    private let service: SellerPaymentServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(sellerId: Int, service: SellerPaymentServiceManager = SellerPaymentServiceManager()) {
        self.sellerId = String(sellerId)
        self.service = service
    }

    var filteredBills: [PaymentBillItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return bills }
        return bills.filter { $0.orderId.localizedCaseInsensitiveContains(query) }
    }

    var selectedBills: [PaymentBillItem] {
        bills.filter { selectedBillIDs.contains($0.id) }
    }

    var totalSelectedAmount: Double {
        selectedBills.reduce(0) { $0 + $1.deductAmountValue }
    }

    var discountValidationError: String? {
        let discount = Double(discountAmount) ?? 0
        let totalGiven = Double(pendingAmount) ?? 0
        if isDiscountApplied && discount > 0 && discount > totalGiven {
            return "Discount cannot be more than the given amount."
        }
        return nil
    }

    var netTotal: Double {
        let discount = isDiscountApplied ? (Double(discountAmount) ?? 0) : 0
        return max(totalSelectedAmount - discount, 0)
    }

    func loadBillList() {
        isLoading = true
        errorMessage = nil

        service.getPaymentBillList(sellerId: sellerId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status {
                    self.bills = response.data.billList
                    self.pendingAmount = response.data.pendingAmt
                } else {
                    self.errorMessage = response.message.isEmpty ? "Unable to load bills." : response.message
                }
            }
            .store(in: &cancellables)
    }

    func toggleBillSelection(_ billID: Int) {
        if selectedBillIDs.contains(billID) {
            selectedBillIDs.remove(billID)
        } else {
            selectedBillIDs.insert(billID)
        }

        if selectedBillIDs.count != 1 {
            isDiscountApplied = false
            discountAmount = ""
        }
    }

    func loadSelectedImage() {
        guard let selectedPhotoItem else {
            imageData = nil
            return
        }

        Task {
            if let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.imageData = PaymentImageCompression.compressJPEG(data)
                }
            }
        }
    }

    func clearImage() {
        selectedPhotoItem = nil
        imageData = nil
    }

    func settlePayment(onSuccess: @escaping () -> Void) {
        errorMessage = nil

        guard !selectedBillIDs.isEmpty else {
            errorMessage = "Please select at least one bill to settle."
            return
        }
        guard let paymentMode else {
            errorMessage = "Please select a payment method."
            return
        }
        if paymentMode == .upi && imageData == nil {
            errorMessage = "Please upload a receipt for UPI/Online payment."
            return
        }
        if let discountValidationError {
            errorMessage = discountValidationError
            return
        }

        let pendingValue = Double(pendingAmount) ?? 0
        if pendingValue < 0.01 {
            errorMessage = "Minimum amount should be ₹0.01"
            return
        }

        isSubmitting = true

        service.settlePayment(
            sellerId: sellerId,
            amount: pendingAmount,
            billIds: selectedBillIDs.map { String($0) },
            paymentMode: String(paymentMode.rawValue),
            discount: isDiscountApplied ? discountAmount : "",
            isDiscountApplied: isDiscountApplied,
            imageData: imageData
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSubmitting = false
            if case .failure(let error) = completion {
                self.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSubmitting = false
            if response.status {
                self.successMessage = response.message.isEmpty ? "Payment settled successfully." : response.message
                self.selectedBillIDs.removeAll()
                self.clearImage()
                self.loadBillList()
                onSuccess()
            } else {
                self.errorMessage = response.message.isEmpty ? "Unable to settle payment." : response.message
            }
        }
        .store(in: &cancellables)
    }
}
