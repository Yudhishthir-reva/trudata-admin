//
//  EditOrderViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class EditOrderViewModel: ObservableObject {

    let orderId: String
    let sellerId: Int
    let fallbackOrderNo: String
    let fallbackDiscount: Double
    let deliveryDate: String

    @Published var orderNo: String
    @Published var sellerShopName: String
    @Published var discount: Double
    @Published var items: [EditOrderLineItem] = []
    @Published private(set) var sessionCartId: Int = 0
    @Published private(set) var apiTotalPrice: Double = 0
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isSubmitting = false
    @Published var shouldShowSubmitScreen = false
    @Published var errorMessage: String?
    @Published var didSaveSuccessfully = false

    private let service = OrderDetailServiceManager()
    private let createOrderService = CreateOrderServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedRemoteDetails = false
    private var resolvedSellerId: Int
    private var apiOrderId: String

    init(order: OrderDetailData) {
        orderId = order.displayOrderNo
        sellerId = order.sellerId
        resolvedSellerId = order.sellerId
        apiOrderId = order.orderId > 0 ? String(order.orderId) : order.displayOrderNo
        fallbackOrderNo = order.displayOrderNo
        fallbackDiscount = order.discountValue
        deliveryDate = order.deliveryDate
        orderNo = order.displayOrderNo
        sellerShopName = order.sellerShopName.ifEmpty(default: order.sellerName)
        discount = order.discountValue
        items = order.orderDetails.enumerated().map { index, detail in
            EditOrderLineItem.from(detail: detail, index: index)
        }
    }

    func reloadEditDetails() {
        hasLoadedRemoteDetails = false
        sessionCartId = 0
        loadEditDetails()
    }

    var totalItems: Int {
        items.filter { $0.quantity > 0 }.count
    }

    var grandTotal: Double {
        let lineTotal = items.reduce(0) { $0 + $1.lineTotal }
        let computed = max(lineTotal - discount, 0)
        if computed > 0 {
            return computed
        }
        if apiTotalPrice > 0 {
            return max(apiTotalPrice - discount, 0)
        }
        return 0
    }

    var canSaveChanges: Bool {
        sessionCartId > 0 && !items.filter({ $0.quantity > 0 }).isEmpty && !isSaving
    }

    func loadEditDetails() {
        guard !hasLoadedRemoteDetails else { return }
        isLoading = true
        errorMessage = nil

        service.getOrderDetailsForEdit(orderId: orderId)
            .flatMap { [weak self] detailsResponse -> AnyPublisher<(EditOrderDetailsResponse, InitCartForEditResponse), Error> in
                guard let self else {
                    return Fail(error: RequestError.invalidPayloadData).eraseToAnyPublisher()
                }

                guard detailsResponse.status else {
                    let message = detailsResponse.message.isEmptyString
                        ? "Failed to load order details for edit."
                        : detailsResponse.message
                    return Fail(error: RequestError.apiMessage(message)).eraseToAnyPublisher()
                }

                let sellerId = detailsResponse.payload.sellerId > 0
                    ? detailsResponse.payload.sellerId
                    : self.sellerId

                return self.service.initCartForEdit(
                    orderId: self.editOrderReference(from: detailsResponse.payload),
                    sellerId: sellerId
                )
                    .map { (detailsResponse, $0) }
                    .eraseToAnyPublisher()
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] detailsResponse, initResponse in
                guard let self else { return }
                self.isLoading = false
                self.hasLoadedRemoteDetails = true

                if !initResponse.status || initResponse.cartId <= 0 {
                    self.errorMessage = initResponse.message.isEmptyString
                        ? "Failed to initialize edit cart."
                        : initResponse.message
                    return
                }

                self.sessionCartId = initResponse.cartId
                self.resolvedSellerId = detailsResponse.payload.sellerId > 0
                    ? detailsResponse.payload.sellerId
                    : self.sellerId

                if !detailsResponse.payload.items.isEmpty {
                    self.applyPayload(detailsResponse.payload)
                } else if !detailsResponse.message.isEmptyString {
                    self.errorMessage = detailsResponse.message
                }
            }
            .store(in: &cancellables)
    }

    func updateQuantity(for itemId: String, quantity: Int) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].quantity = max(0, quantity)
    }

    func quantity(forVariantId variantId: Int) -> Int {
        items.first(where: { $0.variantId == variantId })?.quantity ?? 0
    }

    func updateProductVariant(
        product: ActiveProductItem,
        brandName: String,
        variant: ActiveProductVariant,
        quantity: Int
    ) {
        let clamped = max(0, min(quantity, CreateOrderVariantParser.maxPacketsLimit))
        let perPrice = variant.ogPriceValue > 0 ? variant.ogPriceValue : variant.priceValue

        if let index = items.firstIndex(where: { $0.variantId == variant.id }) {
            if clamped == 0 {
                items.remove(at: index)
            } else {
                items[index].quantity = clamped
                items[index].productId = product.id
                items[index].productName = product.name
                items[index].variantName = variant.name
                items[index].brandName = brandName
                items[index].productImage = product.image
                if items[index].perPrice <= 0, perPrice > 0 {
                    items[index].perPrice = perPrice
                }
            }
        } else if clamped > 0 {
            items.append(
                EditOrderLineItem(
                    id: "line-\(product.id)-\(variant.id)-\(items.count)",
                    orderItemId: 0,
                    cartLineId: 0,
                    productId: product.id,
                    variantId: variant.id,
                    productName: product.name,
                    variantName: variant.name,
                    brandName: brandName,
                    productImage: product.image,
                    perPrice: perPrice,
                    quantity: clamped
                )
            )
        }
    }

    func removeItem(_ itemId: String) {
        items.removeAll { $0.id == itemId }
    }

    func proceedToSubmit() {
        guard canSaveChanges else { return }

        isSaving = true
        errorMessage = nil
        shouldShowSubmitScreen = false

        service.addCartForEdit(
            orderId: editOrderReference(),
            cartId: sessionCartId,
            items: items
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            self?.isSaving = false
            if case .failure(let error) = completion {
                self?.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSaving = false

            if !response.status {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to sync cart."
                    : response.message
                return
            }

            if response.payload.totalPrice > 0 {
                self.apiTotalPrice = response.payload.totalPrice
            }

            if !response.payload.items.isEmpty {
                self.applySyncedCartItems(response.payload.items)
            }

            self.shouldShowSubmitScreen = true
        }
        .store(in: &cancellables)
    }

    func submitOrder(remark: String, audioRemark: String = "") {
        guard sessionCartId > 0, !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil

        service.createOrderForEdit(
            orderId: apiOrderId,
            cartId: sessionCartId,
            deliveryDate: formattedDeliveryDate,
            discount: discount,
            remark: remark,
            audioRemark: audioRemark
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            self?.isSubmitting = false
            if case .failure(let error) = completion {
                self?.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isSubmitting = false
            if response.status {
                self.didSaveSuccessfully = true
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to update order."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    private var formattedDeliveryDate: String {
        let trimmed = deliveryDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmptyString else {
            return Self.todayDeliveryDate
        }

        let inputFormats = ["dd-MM-yyyy", "yyyy-MM-dd", "dd/MM/yyyy"]
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_IN")

        for format in inputFormats {
            parser.dateFormat = format
            if let date = parser.date(from: trimmed) {
                let output = DateFormatter()
                output.locale = parser.locale
                output.dateFormat = "dd-MM-yyyy"
                return output.string(from: date)
            }
        }

        return trimmed
    }

    private static var todayDeliveryDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_IN")
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: Date())
    }

    private func editOrderReference(from payload: EditOrderDetailsPayload? = nil) -> String {
        if let payload, !payload.orderNo.isEmptyString {
            return payload.orderNo.hasPrefix("#") ? payload.orderNo : "#\(payload.orderNo)"
        }
        if !orderNo.isEmptyString {
            return orderNo
        }
        return orderId
    }

    private func applySyncedCartItems(_ syncedItems: [EditOrderLineItem]) {
        let priceByVariantId = pricesByVariantId(from: syncedItems)

        guard !priceByVariantId.isEmpty else { return }

        items = items.map { item in
            var updated = item
            if updated.perPrice <= 0, let price = priceByVariantId[updated.variantId] {
                updated.perPrice = price
            }
            return updated
        }
    }

    private func pricesByVariantId(from items: [EditOrderLineItem]) -> [Int: Double] {
        var prices: [Int: Double] = [:]
        for item in items where item.variantId > 0 && item.perPrice > 0 {
            prices[item.variantId] = item.perPrice
        }
        return prices
    }

    private func applyPayload(_ payload: EditOrderDetailsPayload) {
        let previousPrices = pricesByVariantId(from: items)

        if payload.sellerId > 0 {
            resolvedSellerId = payload.sellerId
        }
        if payload.numericOrderId > 0 {
            apiOrderId = String(payload.numericOrderId)
        }
        if !payload.sellerShopName.isEmptyString {
            sellerShopName = payload.sellerShopName
        }
        if !payload.orderNo.isEmptyString {
            orderNo = payload.orderNo.hasPrefix("#") ? payload.orderNo : "#\(payload.orderNo)"
        }
        if payload.discount > 0 {
            discount = payload.discount
        }
        if payload.totalPrice > 0 {
            apiTotalPrice = payload.totalPrice
        }

        items = payload.items.map { item in
            var updated = item
            if updated.perPrice <= 0, let price = previousPrices[updated.variantId] {
                updated.perPrice = price
            }
            return updated
        }

        if items.contains(where: { $0.perPrice <= 0 && $0.variantId > 0 }) {
            enrichPrices(from: payload.brandIds)
        }
    }

    private func enrichPrices(from brandIds: [Int]) {
        guard !brandIds.isEmpty else { return }

        let sellerIdString = String(resolvedSellerId > 0 ? resolvedSellerId : sellerId)
        let publishers = brandIds.map { brandId in
            createOrderService
                .getActiveProducts(sellerId: sellerIdString, brandId: brandId, isEditMode: true)
                .map(\.data)
                .replaceError(with: [ActiveProductItem]())
        }

        Publishers.MergeMany(publishers)
            .collect()
            .receive(on: RunLoop.main)
            .sink { [weak self] productGroups in
                guard let self else { return }

                var priceByVariantId: [Int: Double] = [:]
                for products in productGroups {
                    for product in products {
                        for variant in product.variants where variant.id > 0 {
                            let price = Double(variant.ogPrice) ?? Double(variant.price) ?? 0
                            if price > 0 {
                                priceByVariantId[variant.id] = price
                            }
                        }
                    }
                }

                guard !priceByVariantId.isEmpty else { return }

                self.items = self.items.map { item in
                    var updated = item
                    if updated.perPrice <= 0, let price = priceByVariantId[updated.variantId], price > 0 {
                        updated.perPrice = price
                    }
                    return updated
                }
            }
            .store(in: &cancellables)
    }
}

private extension String {
    func ifEmpty(default defaultValue: String) -> String {
        isEmptyString ? defaultValue : self
    }
}
