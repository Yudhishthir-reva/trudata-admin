//
//  TopSellingProductsServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class TopSellingProductsServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchTopSellingProducts(
        page: Int,
        startDate: String,
        endDate: String,
        sellerId: String,
        staffId: String,
        searchQuery: String
    ) -> AnyPublisher<TopSellingProductsListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if !startDate.isEmptyString { params["start_date"] = startDate }
        if !endDate.isEmptyString { params["end_date"] = endDate }
        if !sellerId.isEmptyString { params["seller_id"] = sellerId }
        if !staffId.isEmptyString { params["staff_id"] = staffId }
        if !searchQuery.isEmptyString { params["search"] = searchQuery }

        return networkService.request(
            APIRouter.allTopSellingProducts,
            params: params,
            headers: authHeaders
        )
    }

    func getStaffList() -> AnyPublisher<OrderInsightsStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func getSellerList(
        page: Int,
        stateId: String? = nil,
        cityId: String? = nil,
        beatId: String? = nil,
        shopName: String? = nil
    ) -> AnyPublisher<OrderInsightsSellerListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if let stateId, !stateId.isEmptyString { params["state_id"] = stateId }
        if let cityId, !cityId.isEmptyString { params["city_id"] = cityId }
        if let beatId, !beatId.isEmptyString { params["beat_id"] = beatId }
        if let shopName, !shopName.isEmptyString { params["shop_name"] = shopName }
        return networkService.request(APIRouter.sellerList2, params: params, headers: authHeaders)
    }

    func getAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }

    func exportTopSellingProductsExcel(
        startDate: String,
        endDate: String,
        sellerId: String,
        staffId: String
    ) -> AnyPublisher<TopSellingExcelExportResult, Error> {
        Future { promise in
            guard NetworkMonitor.shared.isConnected else {
                promise(.failure(RequestError.noInternet))
                return
            }

            let router = APIRouter.allTopSellingProductsExportExcel
            guard let url = URL(string: router.urlString) else {
                promise(.failure(RequestError.invalidURL))
                return
            }

            var params: [String: String] = [:]
            if !startDate.isEmptyString { params["start_date"] = startDate }
            if !endDate.isEmptyString { params["end_date"] = endDate }
            if !sellerId.isEmptyString { params["seller_id"] = sellerId }
            if !staffId.isEmptyString { params["staff_id"] = staffId }

            var request = URLRequest(url: url)
            request.httpMethod = router.requestType.rawValue
            request.setValue(
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet, application/octet-stream, */*",
                forHTTPHeaderField: "Accept"
            )
            request.setValue(
                router.contentType.headerValue(boundary: ""),
                forHTTPHeaderField: "Content-Type"
            )
            request.httpBody = Self.urlEncodedBody(from: params)

            let headers = UserDefaultManager.shared.authHeader
            headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    promise(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    promise(.failure(RequestError.invalidResponse))
                    return
                }

                guard let data, !data.isEmpty else {
                    promise(.failure(RequestError.unknownError))
                    return
                }

                if !(200...299).contains(httpResponse.statusCode) {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String, !message.isEmpty {
                        promise(.failure(RequestError.apiMessage(message)))
                    } else {
                        promise(.failure(RequestError.unknownError))
                    }
                    return
                }

                let filename = Self.filename(
                    from: httpResponse,
                    startDate: startDate,
                    endDate: endDate
                )
                promise(.success(TopSellingExcelExportResult(data: data, filename: filename)))
            }.resume()
        }
        .eraseToAnyPublisher()
    }

    private static func urlEncodedBody(from params: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        let pairs = params
            .sorted { $0.key < $1.key }
            .map { key, value -> String in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
        return Data(pairs.joined(separator: "&").utf8)
    }

    private static func filename(from response: HTTPURLResponse, startDate: String, endDate: String) -> String {
        if let header = response.value(forHTTPHeaderField: "Content-Disposition"),
           let parsed = parseFilename(from: header) {
            return parsed
        }
        return "TopSelling_\(startDate)_\(endDate).xlsx"
    }

    private static func parseFilename(from header: String) -> String? {
        let pattern = #"filename[*]?=['"]?([^'";]+)['"]?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(header.startIndex..<header.endIndex, in: header)
        guard let match = regex.firstMatch(in: header, options: [], range: range),
              match.numberOfRanges > 1,
              let filenameRange = Range(match.range(at: 1), in: header) else {
            return nil
        }
        return String(header[filenameRange])
    }
}
