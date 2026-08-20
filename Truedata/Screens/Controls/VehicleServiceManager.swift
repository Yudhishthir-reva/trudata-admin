//
//  VehicleServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class VehicleServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchVehicleList() -> AnyPublisher<AdminVehicleListResponse, Error> {
        networkService.request(APIRouter.vehicleListAdmin, params: [:], headers: authHeaders)
    }

    func createVehicle(
        name: String,
        model: String,
        plateNumber: String,
        status: String
    ) -> AnyPublisher<VehicleStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.createVehicle,
            params: [
                "name": name,
                "modal": model,
                "no_plate": plateNumber,
                "status": status
            ],
            headers: authHeaders
        )
    }

    func updateVehicle(
        vehicleId: String,
        name: String,
        model: String,
        plateNumber: String,
        status: String
    ) -> AnyPublisher<VehicleStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.updateVehicle,
            params: [
                "vehicle_id": vehicleId,
                "name": name,
                "modal": model,
                "no_plate": plateNumber,
                "status": status
            ],
            headers: authHeaders
        )
    }

    func deleteVehicle(vehicleId: String) -> AnyPublisher<VehicleStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.deleteVehicle,
            params: ["vehicle_id": vehicleId],
            headers: authHeaders
        )
    }

    func fetchVehicleHistory(vehicleId: String) -> AnyPublisher<VehicleHistoryResponse, Error> {
        networkService.request(
            APIRouter.vehicleHistory,
            params: ["vehicle_id": vehicleId],
            headers: authHeaders
        )
    }

    func assignVehicle(vehicleId: String, riderId: String) -> AnyPublisher<VehicleStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.assignVehicleToRider,
            params: [
                "vehicle_id": vehicleId,
                "rider_id": riderId
            ],
            headers: authHeaders
        )
    }

    func unassignVehicle(assignmentId: String) -> AnyPublisher<VehicleStatusMessageResponse, Error> {
        networkService.request(
            APIRouter.unassignVehicle,
            params: ["id": assignmentId],
            headers: authHeaders
        )
    }
}
