//
//  OrderReturnViewModel.swift
//  Truedata
//

import Combine
import CoreLocation
import Foundation

@MainActor
final class OrderReturnViewModel: ObservableObject {

    let orderId: String
    let returnType: OrderReturnType

    @Published var isFetchingDetails = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var remark = ""
    @Published var payload: EditOrderDetailsPayload?
    @Published var returnItems: [OrderReturnLineItem] = []

    private let service = OrderDetailServiceManager()
    private var cancellables = Set<AnyCancellable>()

    init(orderId: String, returnType: OrderReturnType) {
        self.orderId = orderId
        self.returnType = returnType
    }

    var canSubmit: Bool {
        guard !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if returnType == .partial {
            return returnItems.contains { $0.returnQuantity > 0 }
        }
        return payload != nil
    }

    var selectedReturnCount: Int {
        returnItems.filter { $0.returnQuantity > 0 }.count
    }

    var totalOrderedItems: Int {
        returnItems.reduce(0) { $0 + $1.maxQuantity }
    }

    func loadDetails() {
        guard !orderId.isEmptyString else {
            errorMessage = "Order ID is missing."
            return
        }

        isFetchingDetails = true
        errorMessage = nil

        service.getOrderDetailsForEdit(orderId: orderId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isFetchingDetails = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.payload = response.payload
                    self.returnItems = response.payload.items.compactMap(OrderReturnLineItem.fromEditItem)
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load order details."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func updateReturnQuantity(for orderItemId: Int, quantity: Int) {
        guard let index = returnItems.firstIndex(where: { $0.orderItemId == orderItemId }) else { return }
        let maxQty = returnItems[index].maxQuantity
        let clamped = min(max(quantity, 0), maxQty)
        returnItems[index].returnQuantity = clamped
    }

    func submit() {
        let trimmedRemark = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRemark.isEmpty else {
            errorMessage = "Please enter a remark/reason."
            return
        }

        if returnType == .partial, !returnItems.contains(where: { $0.returnQuantity > 0 }) {
            errorMessage = "Please select at least one item to return."
            return
        }

        isSubmitting = true
        errorMessage = nil

        LocationManager.shared.getCurrentLocation { [weak self] location in
            guard let self else { return }
            let latitude = location.map { String($0.coordinate.latitude) } ?? "0.0"
            let longitude = location.map { String($0.coordinate.longitude) } ?? "0.0"
            let resolvedOrderId = self.resolvedOrderId

            let publisher: AnyPublisher<StatusMessageResponse, Error>
            switch self.returnType {
            case .full:
                publisher = self.service.submitFullReturn(
                    orderId: resolvedOrderId,
                    latitude: latitude,
                    longitude: longitude,
                    remark: trimmedRemark
                )
            case .partial:
                let selectedItems = self.returnItems
                    .filter { $0.returnQuantity > 0 }
                    .map { (orderItemId: $0.orderItemId, quantity: $0.returnQuantity) }
                publisher = self.service.submitPartialReturn(
                    orderId: resolvedOrderId,
                    latitude: latitude,
                    longitude: longitude,
                    remark: trimmedRemark,
                    items: selectedItems
                )
            }

            publisher
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
                            ? "Return submitted successfully."
                            : response.message
                    } else {
                        self.errorMessage = response.message.isEmptyString
                            ? "Failed to submit return."
                            : response.message
                    }
                }
                .store(in: &self.cancellables)
        }
    }

    private var resolvedOrderId: String {
        if let numericOrderId = payload?.numericOrderId, numericOrderId > 0 {
            return String(numericOrderId)
        }
        return orderId
    }
}
