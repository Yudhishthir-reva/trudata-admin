//
//  MarkAttendanceServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class MarkAttendanceServiceManager {

    private let networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    private var userId: String {
        UserDefaultManager.shared.getUserDefaultsString(key: .userId)
    }

    func checkAttendanceStatus() -> AnyPublisher<AttendanceStatusResponse, Error> {
        let params: [String: Any] = ["userId": userId]
        return networkService.request(APIRouter.checkAttendanceStatus, params: params, headers: authHeaders)
    }

    func fetchAttendanceList() -> AnyPublisher<AttendanceListResponse, Error> {
        let params: [String: Any] = ["userId": userId]
        return networkService.request(APIRouter.attendanceList, params: params, headers: authHeaders)
    }

    func markAttendance(
        markType: String,
        latitude: String,
        longitude: String,
        address: String
    ) -> AnyPublisher<MarkAttendanceResponse, Error> {
        let params: [String: Any] = [
            "markType": markType,
            "userId": userId,
            "latitude": latitude,
            "longitude": longitude,
            "address": address
        ]
        return networkService.request(APIRouter.markAttendance, params: params, headers: authHeaders)
    }
}
