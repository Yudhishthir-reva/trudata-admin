//
//  NetworkServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class NetworkServiceManager: NetworkServiceManagable {

    static let shared = NetworkServiceManager()

    private init() {}

    func request<T: Decodable>(
        _ endpoint: RouterManagable,
        params: RequestConstants.Param,
        headers: RequestConstants.Header
    ) -> AnyPublisher<T, Error> {
        guard NetworkMonitor.shared.isConnected else {
            return Fail(error: RequestError.noInternet)
                .eraseToAnyPublisher()
        }

        guard let url = URL(string: endpoint.urlString) else {
            return Fail(error: RequestError.invalidURL)
                .eraseToAnyPublisher()
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.requestType.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let hasPayload = !Self.fields(from: params).isEmpty
        if hasPayload {
            request.setValue(
                endpoint.contentType.headerValue(boundary: boundary),
                forHTTPHeaderField: "Content-Type"
            )
        }

        #if DEBUG
        print("===================================================================")
        print("API:\n", url)
        print("===================================================================")
        print("Parameter:\n", params)
        print("===================================================================")
        print("Header:\n", headers)
        print("===================================================================")
        #endif

        if hasPayload {
            switch endpoint.contentType {
            case .json:
                do {
                    request.httpBody = try JSONSerialization.data(
                        withJSONObject: params,
                        options: .fragmentsAllowed
                    )
                } catch {
                    return Fail(error: error)
                        .eraseToAnyPublisher()
                }
            case .urlEncoded:
                request.httpBody = Self.urlEncodedBody(from: params)
            case .multipartForm:
                request.httpBody = Self.multipartBody(from: params, boundary: boundary)
            }
        }

        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        return URLSession.shared.dataTaskPublisher(for: request)
            .subscribe(on: DispatchQueue.global(qos: .background))
            .mapError { error -> Error in
                if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                    return RequestError.noInternet
                }
                return error
            }
            .tryMap { data, response -> Data in
                #if DEBUG
                print(response)
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: [])
                    print("==================================================================")
                    print("Response:\n", json)
                    print("==================================================================")
                } catch {
                    print(error)
                }
                #endif

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw RequestError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return data
                default:
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String, !message.isEmpty {
                        throw RequestError.apiMessage(message)
                    }
                    throw RequestError.unknownError
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    func uploadMultipart<T: Decodable>(
        _ endpoint: RouterManagable,
        params: RequestConstants.Param,
        file: MultipartFileUpload?,
        files: [MultipartFileUpload] = [],
        headers: RequestConstants.Header
    ) -> AnyPublisher<T, Error> {
        guard NetworkMonitor.shared.isConnected else {
            return Fail(error: RequestError.noInternet)
                .eraseToAnyPublisher()
        }

        guard let url = URL(string: endpoint.urlString) else {
            return Fail(error: RequestError.invalidURL)
                .eraseToAnyPublisher()
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.requestType.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            RequestContentType.multipartForm.headerValue(boundary: boundary),
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = Self.multipartBody(from: params, boundary: boundary, file: file, files: files)

        #if DEBUG
        print("===================================================================")
        print("API (multipart):\n", url)
        print("===================================================================")
        print("Parameter:\n", params)
        print("File attached:", file != nil)
        print("Extra files:", files.count)
        print("===================================================================")
        #endif

        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        return URLSession.shared.dataTaskPublisher(for: request)
            .subscribe(on: DispatchQueue.global(qos: .background))
            .mapError { error -> Error in
                if error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
                    return RequestError.noInternet
                }
                return error
            }
            .tryMap { data, response -> Data in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw RequestError.invalidResponse
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return data
                default:
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String, !message.isEmpty {
                        throw RequestError.apiMessage(message)
                    }
                    throw RequestError.unknownError
                }
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }

    private static func multipartBody(
        from params: RequestConstants.Param,
        boundary: String,
        file: MultipartFileUpload? = nil,
        files: [MultipartFileUpload] = []
    ) -> Data {
        var body = Data()

        for (key, value) in fields(from: params) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }

        var uploads = files
        if let file {
            uploads.append(file)
        }

        for upload in uploads {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(
                Data(
                    "Content-Disposition: form-data; name=\"\(upload.fieldName)\"; filename=\"\(upload.fileName)\"\r\n".utf8
                )
            )
            body.append(Data("Content-Type: \(upload.mimeType)\r\n\r\n".utf8))
            body.append(upload.data)
            body.append(Data("\r\n".utf8))
        }

        body.append(Data("--\(boundary)--\r\n".utf8))

        return body
    }

    private static func urlEncodedBody(from params: RequestConstants.Param) -> Data {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        let pairs = fields(from: params).map { field -> String in
            let encodedKey = field.key.addingPercentEncoding(withAllowedCharacters: allowed) ?? field.key
            let encodedValue = field.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? field.value
            return "\(encodedKey)=\(encodedValue)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }

    private static func fields(from params: RequestConstants.Param) -> [(key: String, value: String)] {
        guard let dictionary = params as? [String: Any] else { return [] }
        var result: [(key: String, value: String)] = []

        for (key, value) in dictionary {
            if let strings = value as? [String] {
                strings.forEach { string in
                    result.append((key: key, value: string))
                }
            } else if let integers = value as? [Int] {
                integers.forEach { integer in
                    result.append((key: key, value: String(integer)))
                }
            } else {
                result.append((key: key, value: String(describing: value)))
            }
        }

        return result.sorted { lhs, rhs in
            lhs.key < rhs.key
        }
    }
}
