//
//  AssignOrderServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class AssignOrderServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func getRiderList() -> AnyPublisher<RiderListResponse, Error> {
        networkService.request(APIRouter.getRiderList, params: [:], headers: authHeaders)
    }

    func getBeatAssignOrderWise() -> AnyPublisher<BeatWithOrdersResponse, Error> {
        networkService.request(APIRouter.getBeatAssignOrderWise, params: [:], headers: authHeaders)
    }

    func getVehicleList() -> AnyPublisher<VehicleListResponse, Error> {
        networkService.request(APIRouter.vehicleList, params: [:], headers: authHeaders)
    }

    func getAssignOrderBeatWiseList(beatIds: [Int]) -> AnyPublisher<AssignOrderListResponse, Error> {
        let params: [String: Any] = ["beat_id[]": beatIds.map(String.init)]
        return networkService.request(APIRouter.getAssignOrderBeatWiseList, params: params, headers: authHeaders)
    }

    func assignOrders(
        riderId: String,
        vehicleId: String,
        inUseStatus: String,
        beatIds: [String],
        orderIds: [String]
    ) -> AnyPublisher<StatusMessageResponse, Error> {
        let params: [String: Any] = [
            "order_id[]": orderIds,
            "beat_id[]": beatIds,
            "rider_id": riderId,
            "vehicle_id": vehicleId,
            "in_use": inUseStatus
        ]
        return networkService.request(APIRouter.orderAssignSave, params: params, headers: authHeaders)
    }
}
