//
//  ProductCatalogueServiceManager.swift
//  Truedata
//

import Foundation
import Combine

struct CatalogPdfResponse: Decodable {
    var status: Bool
    var message: String
    var data: CatalogPdfData?

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.joined(separator: "\n")
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = try? container.decode(CatalogPdfData.self, forKey: .data)
    }
}

struct CatalogPdfData: Decodable {
    var downloadURL: String

    enum CodingKeys: String, CodingKey {
        case downloadURL = "download_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        downloadURL = container.decodeStringLeniently(forKey: .downloadURL) ?? ""
    }
}

class ProductCatalogueServiceManager {

    private let networkService: NetworkServiceManagable
    private let createOrderService: CreateOrderServiceManager

    init(
        networkService: NetworkServiceManagable = NetworkServiceManager.shared,
        createOrderService: CreateOrderServiceManager = CreateOrderServiceManager()
    ) {
        self.networkService = networkService
        self.createOrderService = createOrderService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchBrands() -> AnyPublisher<BrandListResponse, Error> {
        createOrderService.getBrandList()
    }

    func fetchCatalogueProducts(brandId: Int?) -> AnyPublisher<ActiveProductListResponse, Error> {
        var params: [String: Any] = ["seller_id": "0"]
        if let brandId {
            params["brand_id"] = brandId
        }
        return networkService.request(
            APIRouter.productSearchWiseList,
            params: params,
            headers: authHeaders
        )
    }

    func downloadCatalogPDF(brandId: Int?) -> AnyPublisher<Data, Error> {
        fetchCatalogPdfURL(brandId: brandId)
            .flatMap { [weak self] url -> AnyPublisher<Data, Error> in
                guard let self else {
                    return Fail(error: RequestError.unknownError).eraseToAnyPublisher()
                }
                return self.downloadBinary(from: url)
            }
            .eraseToAnyPublisher()
    }

    private func fetchCatalogPdfURL(brandId: Int?) -> AnyPublisher<String, Error> {
        var params: [String: Any] = [:]
        if let brandId {
            params["brand_id"] = brandId
        }

        return networkService.request(
            APIRouter.catelogPdf,
            params: params,
            headers: authHeaders
        )
        .tryMap { (response: CatalogPdfResponse) -> String in
            guard response.status else {
                throw RequestError.apiMessage(
                    response.message.isEmptyString ? "Unable to download catalog PDF." : response.message
                )
            }
            guard let url = response.data?.downloadURL, !url.isEmptyString else {
                throw RequestError.apiMessage("Catalog PDF URL is empty.")
            }
            return url
        }
        .eraseToAnyPublisher()
    }

    private func downloadBinary(from urlString: String) -> AnyPublisher<Data, Error> {
        Future { promise in
            guard NetworkMonitor.shared.isConnected else {
                promise(.failure(RequestError.noInternet))
                return
            }

            guard let url = URL(string: urlString) else {
                promise(.failure(RequestError.invalidURL))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/pdf", forHTTPHeaderField: "Accept")

            self.authHeaders.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

            URLSession.shared.dataTask(with: request) { data, _, error in
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

                promise(.success(data))
            }.resume()
        }
        .eraseToAnyPublisher()
    }

    private static func isPDFData(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        return String(data: data.prefix(4), encoding: .ascii) == "%PDF"
    }

    private static func errorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        if let message = json["message"] as? String, !message.isEmptyString {
            return message
        }
        if let messages = json["message"] as? [String], let first = messages.first, !first.isEmptyString {
            return first
        }
        return nil
    }
}
