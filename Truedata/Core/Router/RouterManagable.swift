//
//  RouterManagable.swift
//  Truedata
//

import Foundation

protocol RouterManagable {
    var endPointUrl: String { get }
    var requestType: RequestMethodType { get }
    var urlString: String { get }
    var contentType: RequestContentType { get }
    var baseURL: String { get }
}

extension RouterManagable {

    var baseURL: String {
        BASE_URL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    var urlString: String {
        "\(baseURL)/\(endPointUrl)"
    }

    var requestType: RequestMethodType {
        .post
    }

    var contentType: RequestContentType {
        .urlEncoded
    }
}
