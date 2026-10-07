//
//  AllSourceOrdersServiceManager.swift
//  Truedata
//

import Foundation
import Combine

final class AllSourceOrdersServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    /// `POST V2/all-order-list` — JSON body. Omit `order_source` for all sources (never send `"all"`).
    func fetchOrders(
        orderSource: String,
        startDate: String,
        endDate: String,
        page: Int,
        perPage: Int = 20,
        search: String
    ) -> AnyPublisher<AllSourceOrdersResponse, Error> {
        var params: [String: Any] = [
            "status": "all",
            "page": page,
            "per_page": perPage
        ]

        let source = orderSource.trimmingCharacters(in: .whitespacesAndNewlines)
        if !source.isEmpty {
            params["order_source"] = source
        }

        let start = startDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = endDate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !start.isEmpty { params["start_date"] = start }
        if !end.isEmpty { params["end_date"] = end }

        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty { params["search"] = query }

        return networkService.request(APIRouter.allOrderList, params: params, headers: authHeaders)
    }
}
