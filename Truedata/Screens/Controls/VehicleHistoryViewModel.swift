//
//  VehicleHistoryViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class VehicleHistoryViewModel: ObservableObject {

    @Published var vehicle: AdminVehicleItem?
    @Published var logs: [VehicleHistoryLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = VehicleServiceManager()
    private var cancellables = Set<AnyCancellable>()

    func load(vehicleId: Int) {
        isLoading = logs.isEmpty
        errorMessage = nil

        service.fetchVehicleHistory(vehicleId: String(vehicleId))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion, self.logs.isEmpty {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status, let data = response.data {
                    self.vehicle = data.vehicle
                    self.logs = data.logs
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load vehicle history."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }
}
