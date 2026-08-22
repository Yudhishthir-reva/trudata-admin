//
//  OrderDetailViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class OrderDetailViewModel: ObservableObject {

    let orderId: String

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var order: OrderDetailData?

    private let service = OrderDetailServiceManager()
    private var cancellables = Set<AnyCancellable>()

    init(orderId: String) {
        self.orderId = orderId
    }

    func loadOrderDetail() {
        guard !orderId.isEmptyString else {
            errorMessage = "Order ID is missing."
            return
        }

        isLoading = true
        errorMessage = nil

        service.getOrderDetail(orderId: orderId)
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
                if response.status || response.data.orderId > 0 || !response.data.orderNo.isEmptyString {
                    self.order = response.data
                    self.errorMessage = nil
                } else {
                    self.order = nil
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load order details."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    @Published var isCancelling = false

    func cancelOrder(onComplete: @escaping (Bool, String) -> Void) {
        guard !orderId.isEmptyString else {
            onComplete(false, "Order ID is missing.")
            return
        }

        isCancelling = true
        errorMessage = nil

        service.cancelOrder(orderId: orderId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isCancelling = false
                if case .failure(let error) = completion {
                    let errMsg = (error as? RequestError)?.errorString ?? error.localizedDescription
                    onComplete(false, errMsg)
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isCancelling = false
                if response.status {
                    onComplete(true, response.message.isEmptyString ? "Order cancelled successfully." : response.message)
                } else {
                    onComplete(false, response.message.isEmptyString ? "Failed to cancel order." : response.message)
                }
            }
            .store(in: &cancellables)
    }
}
