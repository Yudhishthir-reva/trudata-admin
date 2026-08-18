//
//  UpdateSellerStatusViewModel.swift
//  Truedata
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class UpdateSellerStatusViewModel: ObservableObject {

    @Published var capturedImage: UIImage?
    @Published var remark = ""
    @Published var nextVisitDate = ""
    @Published var isSubmitting = false
    @Published var validationMessage: String?
    @Published var errorMessage: String?
    @Published var didSubmitSuccessfully = false

    let sellerId: String
    let sellerName: String

    private let service: StartNewOrderServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(
        sellerId: String,
        sellerName: String,
        service: StartNewOrderServiceManager = StartNewOrderServiceManager()
    ) {
        self.sellerId = sellerId
        self.sellerName = sellerName
        self.service = service
    }

    func setCapturedImage(_ image: UIImage) {
        capturedImage = image
        validationMessage = nil
    }

    func submit(locationSnapshot: LocationSnapshot?) {
        validationMessage = nil
        errorMessage = nil

        guard let capturedImage else {
            validationMessage = "Please take a selfie first"
            return
        }

        guard let snapshot = locationSnapshot else {
            validationMessage = "Location is required. Please ensure GPS is enabled."
            return
        }

        guard !snapshot.address.isEmpty else {
            validationMessage = "Unable to get address. Please try refreshing location."
            return
        }

        guard let imageData = capturedImage.jpegData(compressionQuality: 0.75) else {
            validationMessage = "Unable to process captured image."
            return
        }

        isSubmitting = true

        service.submitShopLocationVisited(
            sellerId: sellerId,
            latitude: String(format: "%.6f", snapshot.latitude),
            longitude: String(format: "%.6f", snapshot.longitude),
            nextVisitDate: nextVisitDate,
            remark: remark,
            address: snapshot.address,
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
            if response.status {
                self.didSubmitSuccessfully = true
            } else {
                self.errorMessage = response.message.isEmpty
                    ? "Failed to submit shop location visit"
                    : response.message
            }
        }
        .store(in: &cancellables)
    }
}
