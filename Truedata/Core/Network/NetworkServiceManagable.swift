//
//  NetworkServiceManagable.swift
//  Truedata
//

import Foundation
import Combine

struct MultipartFileUpload {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let data: Data
}

protocol NetworkServiceManagable {
    func request<T: Decodable>(
        _ endpoint: RouterManagable,
        params: RequestConstants.Param,
        headers: RequestConstants.Header
    ) -> AnyPublisher<T, Error>

    func uploadMultipart<T: Decodable>(
        _ endpoint: RouterManagable,
        params: RequestConstants.Param,
        file: MultipartFileUpload?,
        files: [MultipartFileUpload],
        headers: RequestConstants.Header
    ) -> AnyPublisher<T, Error>
}

extension NetworkServiceManagable {
    func uploadMultipart<T: Decodable>(
        _ endpoint: RouterManagable,
        params: RequestConstants.Param,
        file: MultipartFileUpload?,
        headers: RequestConstants.Header
    ) -> AnyPublisher<T, Error> {
        uploadMultipart(endpoint, params: params, file: file, files: [], headers: headers)
    }
}
