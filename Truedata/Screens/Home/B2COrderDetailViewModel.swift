//
//  B2COrderDetailViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

class B2COrderDetailViewModel: ObservableObject {

    let orderId: Int
    @Published var orderDetail: B2COrderDetailData?
    @Published var isLoading = false
    @Published var isUpdatingStatus = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let service: B2COrdersServiceManager

    init(orderId: Int, service: B2COrdersServiceManager = B2COrdersServiceManager()) {
        self.orderId = orderId
        self.service = service
    }

    func loadOrderDetail() {
        isLoading = true
        errorMessage = nil

        service.getB2COrderDetail(orderId: orderId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status, let data = response.data {
                    self.orderDetail = data
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString ? "Failed to load order details" : response.message
                }
            }
            .store(in: &cancellables)
    }

    func updateStatus(
        to statusCode: Int,
        reason: String = "",
        completion: ((Bool, String) -> Void)? = nil
    ) {
        isUpdatingStatus = true

        service.updateB2COrderStatus(orderId: orderId, status: statusCode, reason: reason)
            .receive(on: RunLoop.main)
            .sink { [weak self] result in
                guard let self else { return }
                self.isUpdatingStatus = false
                if case .failure(let error) = result {
                    let msg = (error as? RequestError)?.errorString ?? error.localizedDescription
                    self.toastMessage = msg
                    completion?(false, msg)
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isUpdatingStatus = false
                let msg = response.message.isEmptyString ? "Status updated successfully" : response.message
                self.toastMessage = msg
                if response.status {
                    self.loadOrderDetail()
                    completion?(true, msg)
                } else {
                    completion?(false, msg)
                }
            }
            .store(in: &cancellables)
    }
}
