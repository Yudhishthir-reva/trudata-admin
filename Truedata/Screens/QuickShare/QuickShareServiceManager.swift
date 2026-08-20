//
//  QuickShareServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class QuickShareServiceManager {

    private let networkService: NetworkServiceManagable
    private let orderInsightsService: OrderInsightsServiceManager

    init(
        networkService: NetworkServiceManagable = NetworkServiceManager.shared,
        orderInsightsService: OrderInsightsServiceManager = OrderInsightsServiceManager()
    ) {
        self.networkService = networkService
        self.orderInsightsService = orderInsightsService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchStaffList() -> AnyPublisher<OrderInsightsStaffListResponse, Error> {
        orderInsightsService.getStaffList()
    }

    func fetchSellerList(page: Int, shopName: String? = nil) -> AnyPublisher<OrderInsightsSellerListResponse, Error> {
        orderInsightsService.getSellerList(page: page, shopName: shopName)
    }

    func fetchOrders(
        page: Int,
        date: String,
        staffId: String,
        sellerId: String,
        orderStatus: String
    ) -> AnyPublisher<OrderInsightsResponse, Error> {
        orderInsightsService.getOrderHistory(
            page: page,
            startDate: date,
            endDate: date,
            status: orderStatus,
            staffId: staffId,
            sellerId: sellerId,
            isCreatedOrderHistory: true
        )
    }

    func downloadQuickSharePDF(
        orderDate: String,
        staffId: String?,
        sellerId: String?,
        orderStatus: String?
    ) -> AnyPublisher<Data, Error> {
        var params: [String: Any] = ["order_date": orderDate]
        if let staffId, !staffId.isEmptyString { params["staff_id"] = staffId }
        if let sellerId, !sellerId.isEmptyString { params["seller_id"] = sellerId }
        if let orderStatus, !orderStatus.isEmptyString { params["order_status"] = orderStatus }
        return downloadPDF(router: .quickShareOrderInvoice, params: params, acceptPDF: true)
    }

    func downloadBulkInvoicePDF(selectedOrderNos: [String]) -> AnyPublisher<Data, Error> {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: selectedOrderNos),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return Fail(error: RequestError.unknownError).eraseToAnyPublisher()
        }
        return downloadPDF(
            router: .generateBulkInvoice,
            params: ["selected_orders": jsonString],
            acceptPDF: true
        )
    }

    private func downloadPDF(
        router: APIRouter,
        params: [String: Any],
        acceptPDF: Bool
    ) -> AnyPublisher<Data, Error> {
        Future { promise in
            guard NetworkMonitor.shared.isConnected else {
                promise(.failure(RequestError.noInternet))
                return
            }

            guard let url = URL(string: router.urlString) else {
                promise(.failure(RequestError.invalidURL))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = router.requestType.rawValue
            request.httpBody = Self.urlEncodedBody(from: params)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue(acceptPDF ? "application/pdf" : "application/json", forHTTPHeaderField: "Accept")

            self.authHeaders.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    promise(.failure(error))
                    return
                }

                guard let data, !data.isEmpty else {
                    promise(.failure(RequestError.unknownError))
                    return
                }

                if Self.isPDFData(data) {
                    promise(.success(data))
                    return
                }

                if let message = Self.errorMessage(from: data) {
                    promise(.failure(RequestError.apiMessage(message)))
                    return
                }

                promise(.failure(RequestError.unknownError))
            }.resume()
        }
        .eraseToAnyPublisher()
    }

    private static func isPDFData(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        return data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let message = json["message"] as? String, !message.isEmpty {
            return message
        }
        if let messages = json["message"] as? [String], let first = messages.first, !first.isEmpty {
            return first
        }
        return nil
    }

    private static func urlEncodedBody(from params: [String: Any]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        let pairs = params.map { key, value -> String in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = String(describing: value).addingPercentEncoding(withAllowedCharacters: allowed)
                ?? String(describing: value)
            return "\(encodedKey)=\(encodedValue)"
        }.sorted()
        return Data(pairs.joined(separator: "&").utf8)
    }
}
