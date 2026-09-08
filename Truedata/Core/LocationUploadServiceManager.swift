//
//  LocationUploadServiceManager.swift
//  Truedata
//

import Combine
import Foundation

final class LocationUploadServiceManager {

    private let networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    func uploadLocation(
        latitude: Double,
        longitude: Double,
        address: String,
        batteryLevel: Int,
        accuracyMeter: String,
        accuracyStatus: String
    ) -> AnyPublisher<HomePrefetchAck, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        let params: [String: Any] = [
            "userId": userId,
            "latitude": String(latitude),
            "longitude": String(longitude),
            "address": address,
            "battery_level": String(batteryLevel),
            "accuracy_meter": accuracyMeter,
            "accuracy_status": accuracyStatus
        ]

        return networkService.uploadMultipart(
            APIRouter.addLocation,
            params: params,
            file: nil,
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
