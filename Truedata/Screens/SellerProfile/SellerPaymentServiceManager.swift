//
//  SellerPaymentServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class SellerPaymentServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getPaymentBillList(sellerId: String) -> AnyPublisher<PaymentBillListResponse, Error> {
        networkService.request(
            APIRouter.paymentBillList,
            params: ["seller_id": sellerId],
            headers: authHeaders
        )
    }

    func savePayment(
        sellerId: String,
        date: String,
        amount: String,
        type: String,
        imageData: Data?
    ) -> AnyPublisher<SellerProfileActionResponse, Error> {
        var params: [String: Any] = [
            "date": date,
            "seller_id": sellerId,
            "type": type,
            "amount": amount
        ]

        let file: MultipartFileUpload?
        if let imageData {
            file = MultipartFileUpload(
                fieldName: "image",
                fileName: "cheque.jpg",
                mimeType: "image/jpeg",
                data: imageData
            )
        } else {
            file = nil
        }

        return networkService.uploadMultipart(
            APIRouter.paymentSave,
            params: params,
            file: file,
            headers: authHeaders
        )
    }

    func settlePayment(
        sellerId: String,
        amount: String,
        billIds: [String],
        paymentMode: String,
        discount: String,
        isDiscountApplied: Bool,
        imageData: Data?
    ) -> AnyPublisher<SellerProfileActionResponse, Error> {
        let amountValue = Double(amount) ?? 0
        let discountValue = Double(discount) ?? 0
        let finalAmount = isDiscountApplied ? amountValue + discountValue : amountValue

        var params: [String: Any] = [
            "amount": String(finalAmount),
            "bill_id[]": billIds,
            "seller_id": sellerId,
            "payment_mode": paymentMode,
            "discount": discount,
            "is_disc_apply": isDiscountApplied || !discount.isEmpty
        ]

        let file: MultipartFileUpload?
        if let imageData {
            file = MultipartFileUpload(
                fieldName: "image",
                fileName: "receipt.jpg",
                mimeType: "image/jpeg",
                data: imageData
            )
        } else {
            file = nil
        }

        return networkService.uploadMultipart(
            APIRouter.paymentSettlement,
            params: params,
            file: file,
            headers: authHeaders
        )
    }
}
