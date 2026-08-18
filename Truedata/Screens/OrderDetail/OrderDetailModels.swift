//
//  OrderDetailModels.swift
//  Truedata
//

import Foundation
import SwiftUI

struct OrderDetailResponse: Decodable {
    var status: Bool
    var message: String
    var data: OrderDetailData

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = (try? container.decode(OrderDetailData.self, forKey: .data)) ?? OrderDetailData()
    }
}

struct OrderDetailData: Decodable {
    var orderId: Int
    var orderNo: String
    var orderDate: String
    var deliveryDate: String
    var deliveryTime: String
    var sellerName: String
    var sellerShopName: String
    var sellerMobile: String
    var sellerAddress: String
    var manualAddress: String
    var staffName: String
    var riderName: String
    var beatName: String
    var status: String
    var totalPrice: String
    var discount: String
    var transactionStatus: String
    var invoiceLink: String
    var canDownloadInvoice: Bool
    var canDownloadPaymentReceipt: Bool
    var orderNotDelivered: Bool
    var orderDetails: [OrderDetailProduct]

    enum CodingKeys: String, CodingKey {
        case status, discount
        case orderId = "order_id"
        case orderNo = "order_no"
        case orderDate = "order_date"
        case deliveryDate = "delivery_date"
        case deliveryTime = "delivery_time"
        case sellerName = "seller_name"
        case sellerShopName = "seller_shop_name"
        case sellerMobile = "seller_mobile"
        case sellerAddress = "seller_address"
        case manualAddress = "manual_address"
        case staffName = "staff_name"
        case riderName = "rider_name"
        case beatName = "beat_name"
        case totalPrice = "total_price"
        case transactionStatus = "transaction_status"
        case invoiceLink = "invoice_link"
        case canDownloadInvoice = "can_download_invoice"
        case canDownloadPaymentReceipt = "canDownloadPaymentReceipt"
        case orderNotDelivered = "order_not_delivered"
        case orderDetails = "order_details"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        deliveryDate = container.decodeStringLeniently(forKey: .deliveryDate) ?? ""
        deliveryTime = container.decodeStringLeniently(forKey: .deliveryTime) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        sellerShopName = container.decodeStringLeniently(forKey: .sellerShopName) ?? ""
        sellerMobile = container.decodeStringLeniently(forKey: .sellerMobile) ?? ""
        sellerAddress = container.decodeStringLeniently(forKey: .sellerAddress) ?? ""
        manualAddress = container.decodeStringLeniently(forKey: .manualAddress) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        riderName = container.decodeStringLeniently(forKey: .riderName) ?? ""
        beatName = container.decodeStringLeniently(forKey: .beatName) ?? ""
        status = container.decodeStringLeniently(forKey: .status) ?? ""
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0"
        discount = container.decodeStringLeniently(forKey: .discount) ?? "0"
        transactionStatus = container.decodeStringLeniently(forKey: .transactionStatus) ?? ""
        invoiceLink = container.decodeStringLeniently(forKey: .invoiceLink) ?? ""
        canDownloadInvoice = container.decodeBoolLeniently(forKey: .canDownloadInvoice) ?? true
        canDownloadPaymentReceipt = container.decodeBoolLeniently(forKey: .canDownloadPaymentReceipt) ?? false
        orderNotDelivered = container.decodeBoolLeniently(forKey: .orderNotDelivered) ?? false
        orderDetails = (try? container.decode([OrderDetailProduct].self, forKey: .orderDetails)) ?? []
    }

    init() {
        orderId = 0
        orderNo = ""
        orderDate = ""
        deliveryDate = ""
        deliveryTime = ""
        sellerName = ""
        sellerShopName = ""
        sellerMobile = ""
        sellerAddress = ""
        manualAddress = ""
        staffName = ""
        riderName = ""
        beatName = ""
        status = ""
        totalPrice = "0"
        discount = "0"
        transactionStatus = ""
        invoiceLink = ""
        canDownloadInvoice = true
        canDownloadPaymentReceipt = false
        orderNotDelivered = false
        orderDetails = []
    }

    var displayOrderNo: String {
        let value = orderNo.isEmptyString ? "\(orderId)" : orderNo
        return value.hasPrefix("#") ? value : "#\(value)"
    }

    var subtotal: Double {
        orderDetails.reduce(0) { partial, item in
            partial + (Double(item.totalPrice) ?? 0)
        }
    }

    var discountValue: Double {
        Double(discount) ?? 0
    }

    var grandTotal: Double {
        Double(totalPrice) ?? subtotal - discountValue
    }

    var shopDisplay: String {
        if sellerShopName.isEmptyString && sellerMobile.isEmptyString { return "N/A" }
        if sellerMobile.isEmptyString { return sellerShopName }
        if sellerShopName.isEmptyString { return sellerMobile }
        return "\(sellerShopName) (\(sellerMobile))"
    }
}

struct OrderDetailProduct: Decodable, Identifiable, Hashable {
    var id: String { "\(productName)-\(variantName)-\(qty)-\(perPrice)" }
    var productName: String
    var variantName: String
    var qty: String
    var perPrice: String
    var totalPrice: String
    var productImage: String

    enum CodingKeys: String, CodingKey {
        case qty
        case productName = "product_name"
        case variantName = "variant_name"
        case perPrice = "per_price"
        case totalPrice = "total_price"
        case productImage = "product_image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productName = container.decodeStringLeniently(forKey: .productName) ?? ""
        variantName = container.decodeStringLeniently(forKey: .variantName) ?? ""
        qty = container.decodeStringLeniently(forKey: .qty) ?? "0"
        perPrice = container.decodeStringLeniently(forKey: .perPrice) ?? "0"
        totalPrice = container.decodeStringLeniently(forKey: .totalPrice) ?? "0"
        productImage = container.decodeStringLeniently(forKey: .productImage) ?? ""
    }

    var quantityPriceLabel: String {
        "\(qty) x \(perPrice.priceLabel)"
    }
}

struct OrderDetailStatusChip: Hashable {
    var text: String
    var color: Color
    var icon: String
    var backgroundColor: Color
}

enum OrderDetailStatusMapper {

    static func deliveryStatus(_ status: String) -> OrderDetailStatusChip {
        let label = "Delivery Status"
        switch status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "pending", "0":
            return OrderDetailStatusChip(
                text: "\(label): Pending",
                color: DashboardTheme.warningYellow,
                icon: "clock.fill",
                backgroundColor: DashboardTheme.warningYellow.opacity(0.15)
            )
        case "to delivered", "to deliver", "1":
            return OrderDetailStatusChip(
                text: "\(label): To Deliver",
                color: DashboardTheme.infoBlue,
                icon: "shippingbox.fill",
                backgroundColor: DashboardTheme.infoBlue.opacity(0.15)
            )
        case "pickup", "picked up", "2":
            return OrderDetailStatusChip(
                text: "\(label): Pickup",
                color: DashboardTheme.pickupOrange,
                icon: "archivebox.fill",
                backgroundColor: DashboardTheme.pickupOrange.opacity(0.15)
            )
        case "delivered", "completed", "deliver", "3":
            return OrderDetailStatusChip(
                text: "\(label): Delivered",
                color: DashboardTheme.successGreen,
                icon: "checkmark.circle.fill",
                backgroundColor: DashboardTheme.successGreen.opacity(0.15)
            )
        case "cancel", "4":
            return OrderDetailStatusChip(
                text: "\(label): Cancelled",
                color: DashboardTheme.dangerRed,
                icon: "xmark.circle.fill",
                backgroundColor: DashboardTheme.dangerRed.opacity(0.15)
            )
        default:
            let readable = BillOrderStatus(key: status).label
            return OrderDetailStatusChip(
                text: "\(label): \(readable)",
                color: DashboardTheme.neutralMedium,
                icon: "questionmark.circle.fill",
                backgroundColor: DashboardTheme.neutralMedium.opacity(0.15)
            )
        }
    }

    static func paymentStatus(_ status: String) -> OrderDetailStatusChip {
        switch status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "pending", "0":
            return OrderDetailStatusChip(
                text: "Payment: Pending",
                color: DashboardTheme.primaryBlue,
                icon: "hourglass",
                backgroundColor: DashboardTheme.primaryBlue.opacity(0.15)
            )
        case "remaining", "1":
            return OrderDetailStatusChip(
                text: "Payment: Partially Paid",
                color: DashboardTheme.warningYellow,
                icon: "hourglass.bottomhalf.filled",
                backgroundColor: DashboardTheme.warningYellow.opacity(0.15)
            )
        case "complete", "completed", "2":
            return OrderDetailStatusChip(
                text: "Payment: Paid",
                color: DashboardTheme.successGreen,
                icon: "checkmark.seal.fill",
                backgroundColor: DashboardTheme.successGreen.opacity(0.15)
            )
        default:
            let value = status.isEmptyString ? "Unknown" : status
            return OrderDetailStatusChip(
                text: "Payment: \(value)",
                color: DashboardTheme.neutralMedium,
                icon: "creditcard.fill",
                backgroundColor: DashboardTheme.neutralMedium.opacity(0.15)
            )
        }
    }
}
