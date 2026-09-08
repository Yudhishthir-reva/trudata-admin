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
    @Published var isDownloadingSettlement = false
    @Published var settlementShareURL: URL?

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

    func downloadSettlementReceipt(for order: OrderDetailData, onComplete: @escaping (String) -> Void) {
        let resolvedOrderId = order.orderNo.isEmptyString ? String(order.orderId) : order.orderNo
        guard !resolvedOrderId.isEmptyString else {
            onComplete("Settlement receipt is not available.")
            return
        }

        isDownloadingSettlement = true
        settlementShareURL = nil

        service.downloadSettlementReceipt(orderId: resolvedOrderId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isDownloadingSettlement = false
                if case .failure(let error) = completion {
                    onComplete((error as? RequestError)?.errorString ?? error.localizedDescription)
                }
            } receiveValue: { [weak self] data in
                guard let self else { return }
                self.isDownloadingSettlement = false
                let fileName = "Settlement_\(resolvedOrderId)_\(Int(Date().timeIntervalSince1970)).pdf"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                do {
                    try data.write(to: url, options: .atomic)
                    self.settlementShareURL = url
                } catch {
                    onComplete("Unable to prepare settlement receipt for sharing.")
                }
            }
            .store(in: &cancellables)
    }
}
