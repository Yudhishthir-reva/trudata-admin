//
//  TargetServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class TargetServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchTargetList(
        page: Int,
        staffId: String,
        targetStatus: String,
        month: String
    ) -> AnyPublisher<SalesTargetListResponse, Error> {
        var params: [String: Any] = ["page": page]
        if !staffId.isEmpty { params["staff_id"] = staffId }
        if !targetStatus.isEmpty { params["target_status"] = targetStatus }
        if !month.isEmpty { params["month"] = month }
        return networkService.request(APIRouter.salesTargetList, params: params, headers: authHeaders)
    }

    func fetchStaffList() -> AnyPublisher<RegisteredStaffListResponse, Error> {
        networkService.request(APIRouter.staffList, params: [:], headers: authHeaders)
    }

    func createTarget(
        staffId: String,
        targetAmount: String,
        month: String,
        targetStartDate: String,
        targetEndDate: String
    ) -> AnyPublisher<TargetStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.createSalesTarget,
            params: [
                "staff_id": staffId,
                "target_amount": targetAmount,
                "month": month,
                "target_start_date": targetStartDate,
                "target_end_date": targetEndDate,
                "target_status": "1"
            ],
            headers: authHeaders
        )
    }

    func updateTarget(
        targetId: String,
        staffId: String,
        targetAmount: String,
        month: String,
        targetStartDate: String,
        targetEndDate: String,
        targetStatus: String
    ) -> AnyPublisher<TargetStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.updateTarget,
            params: [
                "target_id": targetId,
                "staff_id": staffId,
                "target_amount": targetAmount,
                "month": month,
                "target_start_date": targetStartDate,
                "target_end_date": targetEndDate,
                "target_status": targetStatus
            ],
            headers: authHeaders
        )
    }

    func deleteTarget(targetId: String) -> AnyPublisher<TargetStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.deleteTarget,
            params: ["target_id": targetId],
            headers: authHeaders
        )
    }

    func fetchTargetHistory(targetId: String) -> AnyPublisher<TargetHistoryResponse, Error> {
        networkService.request(
            APIRouter.targetHistory,
            params: ["target_id": targetId],
            headers: authHeaders
        )
    }
}
