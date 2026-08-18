//
//  AddPaymentViewModel.swift
//  Truedata
//

import SwiftUI
import Combine
import PhotosUI

final class AddPaymentViewModel: ObservableObject {

    @Published var amount = ""
    @Published var date = ""
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var imageData: Data?
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let sellerId: String
    private let service: SellerPaymentServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(sellerId: Int, service: SellerPaymentServiceManager = SellerPaymentServiceManager()) {
        self.sellerId = String(sellerId)
        self.service = service
        self.date = SellerProfileDateFormat.apiFormatter.string(from: Date())
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

    func savePayment(onSuccess: @escaping () -> Void) {
        errorMessage = nil

        if amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Amount cannot be empty."
            return
        }
        if Double(amount) == nil {
            errorMessage = "Invalid amount."
            return
        }
        if date.isEmpty {
            errorMessage = "Please select a date."
            return
        }
        if imageData == nil {
            errorMessage = "An image is required for cheque payment."
            return
        }

        isSaving = true

        service.savePayment(
            sellerId: sellerId,
            date: date,
            amount: amount,
            type: "2",
            imageData: imageData
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSaving = false
            if case .failure(let error) = completion {
                self.errorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSaving = false
            if response.status {
                self.successMessage = response.message.isEmpty ? "Payment saved successfully." : response.message
                onSuccess()
            } else {
                self.errorMessage = response.message.isEmpty ? "Unable to save payment." : response.message
            }
        }
        .store(in: &cancellables)
    }
}
