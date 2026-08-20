//
//  StaffServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class StaffServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchStaffList() -> AnyPublisher<RegisteredStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func fetchRoles() -> AnyPublisher<StaffRoleResponse, Error> {
        networkService.request(APIRouter.getRoles, params: [:], headers: authHeaders)
    }

    func fetchAllAreas() -> AnyPublisher<StartNewOrderAllAreaResponse, Error> {
        let userId = UserDefaultManager.shared.getUserDefaultsString(key: .userId)
        var params: [String: Any] = [:]
        if !userId.isEmptyString { params["user_id"] = userId }
        return networkService.request(APIRouter.getAllArea, params: params, headers: authHeaders)
    }

    func addStaff(
        params: [String: Any],
        files: [MultipartFileUpload]
    ) -> AnyPublisher<StaffStatusMessageResponse, Error> {
        networkService.uploadMultipart(
            APIRouter.addStaff,
            params: params,
            file: nil,
            files: files,
            headers: authHeaders
        )
    }

    func updateStaff(params: [String: Any]) -> AnyPublisher<StaffStatusMessageResponse, Error> {
        networkService.uploadMultipart(
            APIRouter.updateStaff,
            params: params,
            file: nil,
            files: [],
            headers: authHeaders
        )
    }

    func updateStaffStatus(staffId: Int, status: Int) -> AnyPublisher<StaffStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.updateStaffStatus,
            params: [
                "staff_id": staffId,
                "status": status
            ],
            headers: authHeaders
        )
    }
}
