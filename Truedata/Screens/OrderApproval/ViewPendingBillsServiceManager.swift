//
//  ViewPendingBillsServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class ViewPendingBillsServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    /// `staffId` 0 means "whoever is logged in", as Android's "default" does. `perPage` is asked
    /// for; a server that ignores it pages by 10 and the ViewModel still fetches every page.
    func getPendingPaymentBills(
        sellerId: Int,
        staffId: Int,
        page: Int,
        perPage: Int? = nil
    ) -> AnyPublisher<PendingPaymentBillsResponse, Error> {
        let staff = staffId > 0
            ? staffId
            : Int(UserDefaultManager.shared.getUserDefaultsString(key: .userId)) ?? 0
        var params: [String: Any] = [
            "seller_id": sellerId,
            "staff_id": staff,
            "page": page
        ]
        if let perPage { params["per_page"] = perPage }
        return networkService.request(
            APIRouter.viewPendingPaymentBillList,
            params: params,
            headers: authHeaders
        )
    }
}
