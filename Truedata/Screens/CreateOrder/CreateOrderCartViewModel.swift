//
//  CreateOrderCartViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

enum CreateOrderFinishAction {
    case viewOrders
    case goToDashboard
    case viewSeller
}

final class CreateOrderCartViewModel: ObservableObject {

    let sellerId: Int

    @Published private(set) var items: [EditOrderLineItem] = []
    @Published private(set) var sessionCartId: Int = 0
    @Published private(set) var syncedCartLineIds: [Int] = []
    @Published private(set) var submitItems: [CreateOrderSubmitLineItem] = []
    @Published private(set) var sellerShopName = ""
    @Published private(set) var sellerAddress = ""
    @Published private(set) var apiGrandTotal: Double = 0
    @Published private(set) var isSyncing = false
    @Published private(set) var isSubmitting = false
    @Published var showSuccessScreen = false
    @Published var errorMessage: String?

    private let service: CreateOrderServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(sellerId: Int, service: CreateOrderServiceManager = CreateOrderServiceManager()) {
        self.sellerId = sellerId
        self.service = service
    }

    var totalItems: Int {
        items.filter { $0.quantity > 0 }.count
    }

    var grandTotal: Double {
        if apiGrandTotal > 0 {
            return apiGrandTotal
        }
        return items.reduce(0) { $0 + $1.lineTotal }
    }

    var hasItems: Bool {
        totalItems > 0
    }

    var isCartSynced: Bool {
        !submitItems.isEmpty && !syncedCartLineIds.isEmpty
    }

    var successMessage: String {
        "Your order has been placed successfully."
    }

    func quantity(forVariantId variantId: Int, productId: Int = 0) -> Int {
        items.first(where: { item in
            item.variantId == variantId && (productId == 0 || item.productId == productId)
        })?.quantity ?? 0
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
            items[index].quantity = clamped
            items[index].productId = product.id
            items[index].productName = product.name
            items[index].variantName = variant.name
            items[index].brandName = brandName
            items[index].productImage = product.image
            if items[index].perPrice <= 0, perPrice > 0 {
                items[index].perPrice = perPrice
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

        submitItems = []
        syncedCartLineIds = []
        apiGrandTotal = 0
    }

    func updateQuantity(for itemId: String, quantity: Int) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        let clamped = max(0, quantity)
        items[index].quantity = clamped
        submitItems = []
        syncedCartLineIds = []
        apiGrandTotal = 0
    }

    func removeItem(_ itemId: String) {
        items.removeAll { $0.id == itemId }
        submitItems = []
        syncedCartLineIds = []
        apiGrandTotal = 0
    }

    func proceedToSubmit(onComplete: @escaping (Bool) -> Void) {
        guard hasItems, !isSyncing else {
            onComplete(false)
            return
        }

        isSyncing = true
        errorMessage = nil

        let initPublisher: AnyPublisher<Int, Error>
        if sessionCartId > 0 {
            initPublisher = Just(sessionCartId)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            initPublisher = service.initCart(sellerId: sellerId)
                .tryMap { response in
                    guard response.status, response.cartId > 0 else {
                        throw RequestError.apiMessage(
                            response.message.isEmptyString
                                ? "Failed to initialize cart."
                                : response.message
                        )
                    }
                    return response.cartId
                }
                .eraseToAnyPublisher()
        }

        initPublisher
            .flatMap { [weak self] cartId -> AnyPublisher<CreateOrderAddCartResponse, Error> in
                guard let self else {
                    return Fail(error: RequestError.invalidPayloadData).eraseToAnyPublisher()
                }
                self.sessionCartId = cartId
                return self.service.addCart(cartId: cartId, items: self.items)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSyncing = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    onComplete(false)
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSyncing = false

                guard response.status else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to sync cart."
                        : response.message
                    onComplete(false)
                    return
                }

                self.applySyncResponse(response)
                onComplete(true)
            }
            .store(in: &cancellables)
    }

    func submitOrder(
        remark: String,
        audioRemark: String,
        latitude: String,
        longitude: String
    ) {
        let cartIds = syncedCartLineIds
        guard !cartIds.isEmpty, !isSubmitting else { return }

        isSubmitting = true
        errorMessage = nil

        service.submitOrder(
            cartIds: cartIds,
            latitude: latitude,
            longitude: longitude,
            remark: remark,
            audioRemark: audioRemark
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
                self.showSuccessScreen = true
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to place order."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    private func applySyncResponse(_ response: CreateOrderAddCartResponse) {
        if !response.sellerShopName.isEmptyString {
            sellerShopName = response.sellerShopName
        }
        if !response.sellerAddress.isEmptyString {
            sellerAddress = response.sellerAddress
        }
        if response.grandTotal > 0 {
            apiGrandTotal = response.grandTotal
        }
        if !response.cartLineIds.isEmpty {
            syncedCartLineIds = response.cartLineIds
        }
        if !response.submitItems.isEmpty {
            submitItems = response.submitItems
        }

        if !response.syncedItems.isEmpty {
            applySyncedCartItems(response.syncedItems)
        }

        if submitItems.isEmpty {
            submitItems = items.filter { $0.quantity > 0 }.map { item in
                let grams = CreateOrderVariantParser.weightInGrams(for: item.variantName)
                    ?? CreateOrderVariantParser.weightInGrams(for: item.productName)
                    ?? 0
                let weightKg = grams > 0 ? (grams * Double(item.quantity)) / 1000.0 : 0
                return CreateOrderSubmitLineItem(
                    id: item.id,
                    productName: item.productName,
                    variantName: item.variantName,
                    quantity: item.quantity,
                    lineTotal: item.lineTotal,
                    gstLabel: "",
                    weightKg: weightKg
                )
            }
        }

        if syncedCartLineIds.isEmpty {
            syncedCartLineIds = items.compactMap { item in
                item.cartLineId > 0 ? item.cartLineId : nil
            }
        }
        if syncedCartLineIds.isEmpty, sessionCartId > 0 {
            syncedCartLineIds = [sessionCartId]
        }
    }

    private func applySyncedCartItems(_ syncedItems: [EditOrderLineItem]) {
        let priceByVariantId = pricesByVariantId(from: syncedItems)
        let cartLineIdByVariantId = cartLineIdsByVariantId(from: syncedItems)

        syncedCartLineIds = syncedItems.compactMap { item in
            item.cartLineId > 0 ? item.cartLineId : nil
        }

        items = items.map { item in
            var updated = item
            if updated.perPrice <= 0, let price = priceByVariantId[updated.variantId] {
                updated.perPrice = price
            }
            if updated.cartLineId <= 0, let cartLineId = cartLineIdByVariantId[updated.variantId] {
                updated.cartLineId = cartLineId
            }
            return updated
        }
    }

    private func cartLineIdsByVariantId(from items: [EditOrderLineItem]) -> [Int: Int] {
        var cartLineIds: [Int: Int] = [:]
        for item in items where item.variantId > 0 && item.cartLineId > 0 {
            cartLineIds[item.variantId] = item.cartLineId
        }
        return cartLineIds
    }

    private func pricesByVariantId(from items: [EditOrderLineItem]) -> [Int: Double] {
        var prices: [Int: Double] = [:]
        for item in items where item.variantId > 0 && item.perPrice > 0 {
            prices[item.variantId] = item.perPrice
        }
        return prices
    }
}
