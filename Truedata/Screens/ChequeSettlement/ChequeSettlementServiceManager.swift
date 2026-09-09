//
//  ChequeSettlementServiceManager.swift
//  Truedata
//

import Combine
import Foundation

final class ChequeSettlementServiceManager {

    private let networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getPendingSettleCheques(
        page: Int,
        perPage: Int = 15
    ) -> AnyPublisher<PendingSettleChequeListResponse, Error> {
        networkService.request(
            APIRouter.pendingSettleCheque,
            params: [
                "page": page,
                "per_page": perPage
            ],
            headers: authHeaders
        )
    }

    func getChequeBillList(sellerId: Int) -> AnyPublisher<ChequeBillListResponse, Error> {
        networkService.request(
            APIRouter.chequeBillList,
            params: ["seller_id": sellerId],
            headers: authHeaders
        )
    }

    func settleCheque(
        sellerId: Int,
        chequeId: Int,
        billIds: [Int],
        amount: String,
        isDiscountApplied: Bool,
        discount: String
    ) -> AnyPublisher<StatusMessageResponse, Error> {
        // API expects gross amount = settlement amount + discount (same as payment-settlement).
        let amountValue = Double(amount) ?? 0
        let discountValue = Double(discount) ?? 0
        let finalAmount = isDiscountApplied ? amountValue + discountValue : amountValue

        return networkService.request(
            APIRouter.chequeSettlement,
            params: [
                "seller_id": sellerId,
                "cheque_id": chequeId,
                "bill_id[]": billIds.map(String.init),
                "amount": String(finalAmount),
                "is_disc_apply": isDiscountApplied ? "true" : "false",
                "discount": discount
            ],
            headers: authHeaders
        )
    }
}
