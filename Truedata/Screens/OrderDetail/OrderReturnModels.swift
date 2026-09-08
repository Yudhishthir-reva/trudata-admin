//
//  OrderReturnModels.swift
//  Truedata
//

import Foundation

enum OrderReturnType {
    case full
    case partial
}

struct OrderReturnLineItem: Identifiable, Hashable {
    var id: Int { orderItemId }
    var orderItemId: Int
    var label: String
    var imageURL: String
    var maxQuantity: Int
    var returnQuantity: Int

    static func fromEditItem(_ item: EditOrderLineItem) -> OrderReturnLineItem? {
        guard item.orderItemId > 0, item.quantity > 0 else { return nil }
        let label = item.variantName.isEmptyString ? item.productName : item.variantName
        return OrderReturnLineItem(
            orderItemId: item.orderItemId,
            label: label,
            imageURL: item.productImage,
            maxQuantity: item.quantity,
            returnQuantity: 0
        )
    }
}
