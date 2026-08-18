//
//  LoginServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class LoginServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func login(
        params: RequestConstants.Param,
        headers: RequestConstants.Header = [:]
    ) -> AnyPublisher<AuthResponse, Error> {
        networkService.request(APIRouter.loginUser, params: params, headers: headers)
    }
}

struct AuthResponse: Decodable {
    var status: Bool?
    var message: [String]
    var token: String?
    var userId: String
    var role: String?
    var name: String?

    enum CodingKeys: String, CodingKey {
        case status, message, token, role, name
        case userId = "user_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status)
        token = container.decodeStringLeniently(forKey: .token)
        userId = container.decodeStringLeniently(forKey: .userId) ?? ""
        role = container.decodeStringLeniently(forKey: .role)
        name = container.decodeStringLeniently(forKey: .name)

        if let list = try? container.decode([String].self, forKey: .message) {
            message = list
        } else if let string = container.decodeStringLeniently(forKey: .message) {
            message = [string]
        } else {
            message = []
        }
    }
}
