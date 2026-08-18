//
//  AssignOrderViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

enum AssignOrderSelectionStep: Int, CaseIterable {
    case rider = 0
    case vehicle = 1
    case beats = 2

    var title: String {
        switch self {
        case .rider: return "Select Rider"
        case .vehicle: return "Select Vehicle"
        case .beats: return "Select Beats"
        }
    }
}

final class AssignOrderViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var riders: [RiderItem] = []
    @Published var beats: [BeatWithOrdersItem] = []
    @Published var vehicles: [VehicleItem] = []
    @Published var orders: [AssignOrderItem] = []

    @Published var selectedRider: RiderItem?
    @Published var selectedVehicle: VehicleItem?
    @Published var selectedBeats: [BeatWithOrdersItem] = []
    @Published var selectedOrderIds: Set<String> = []

    @Published var selectionStep: AssignOrderSelectionStep = .rider
    @Published var showSelectionSheet = false
    @Published var showSuccessAlert = false
    @Published var successMessage = ""
    @Published var expandedBeatId: Int?

    private let service = AssignOrderServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var canAssign: Bool {
        selectedRider != nil &&
        selectedVehicle != nil &&
        !selectedBeats.isEmpty &&
        !selectedOrderIds.isEmpty
    }

    var groupedOrders: [(beat: BeatWithOrdersItem, orders: [AssignOrderItem])] {
        selectedBeats.map { beat in
            let beatOrders = orders.filter { $0.beatId == String(beat.id) || $0.beatName == beat.name }
            return (beat, beatOrders)
        }
    }

    func onAppear() {
        loadBootstrapData()
        if selectedRider == nil || selectedVehicle == nil || selectedBeats.isEmpty {
            showSelectionSheet = true
        }
    }

    func loadBootstrapData() {
        isLoading = true
        errorMessage = nil

        let ridersPub = resultPublisher(service.getRiderList())
        let beatsPub = resultPublisher(service.getBeatAssignOrderWise())
        let vehiclesPub = resultPublisher(service.getVehicleList())

        Publishers.Zip3(ridersPub, beatsPub, vehiclesPub)
            .receive(on: RunLoop.main)
            .sink { [weak self] ridersResult, beatsResult, vehiclesResult in
                guard let self else { return }
                self.isLoading = false

                switch ridersResult {
                case .success(let response):
                    self.riders = response.data
                case .failure(let error):
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }

                switch beatsResult {
                case .success(let response):
                    self.beats = response.data
                case .failure(let error):
                    if self.errorMessage == nil {
                        self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    }
                }

                switch vehiclesResult {
                case .success(let response):
                    self.vehicles = response.vehicleList.filter(\.isVisible)
                case .failure(let error):
                    if self.errorMessage == nil {
                        self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                    }
                }
            }
            .store(in: &cancellables)
    }

    func loadOrdersForSelectedBeats() {
        guard !selectedBeats.isEmpty else {
            orders = []
            return
        }

        isLoading = true
        errorMessage = nil
        let beatIds = selectedBeats.map(\.id)

        service.getAssignOrderBeatWiseList(beatIds: beatIds)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status || response.data.isEmpty {
                    self.orders = response.data.map(\.asModel)
                    self.expandedBeatId = self.selectedBeats.first?.id
                } else {
                    self.errorMessage = response.message.isEmptyString ? "Failed to load orders." : response.message
                    self.orders = []
                }
            }
            .store(in: &cancellables)
    }

    func toggleBeatSelection(_ beat: BeatWithOrdersItem) {
        if selectedBeats.contains(where: { $0.id == beat.id }) {
            selectedBeats.removeAll { $0.id == beat.id }
        } else {
            selectedBeats.append(beat)
        }
    }

    func selectAllBeats(_ select: Bool, from source: [BeatWithOrdersItem]? = nil) {
        let beats = source ?? self.beats
        if select {
            var updated = selectedBeats
            for beat in beats where !updated.contains(where: { $0.id == beat.id }) {
                updated.append(beat)
            }
            selectedBeats = updated
        } else {
            let ids = Set(beats.map(\.id))
            selectedBeats.removeAll { ids.contains($0.id) }
        }
    }

    func toggleOrder(_ orderId: String) {
        if selectedOrderIds.contains(orderId) {
            selectedOrderIds.remove(orderId)
        } else {
            selectedOrderIds.insert(orderId)
        }
    }

    func completeSelectionIfPossible() {
        guard selectedRider != nil, selectedVehicle != nil, !selectedBeats.isEmpty else { return }
        showSelectionSheet = false
        loadOrdersForSelectedBeats()
    }

    func goToNextSelectionStep() {
        switch selectionStep {
        case .rider:
            guard selectedRider != nil else { return }
            selectionStep = .vehicle
        case .vehicle:
            guard selectedVehicle != nil else { return }
            selectionStep = .beats
        case .beats:
            completeSelectionIfPossible()
        }
    }

    func assignOrdersToRider() {
        guard let rider = selectedRider, let vehicle = selectedVehicle else { return }
        guard !selectedBeats.isEmpty, !selectedOrderIds.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        service.assignOrders(
            riderId: String(rider.id),
            vehicleId: String(vehicle.id),
            inUseStatus: vehicle.inUse,
            beatIds: selectedBeats.map { String($0.id) },
            orderIds: Array(selectedOrderIds)
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            if case .failure(let error) = completion {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            if response.status {
                self.successMessage = response.message.isEmptyString
                    ? "Orders assigned successfully."
                    : response.message
                self.showSuccessAlert = true
                self.resetAfterSuccess()
            } else {
                self.errorMessage = response.message.isEmptyString ? "Order assignment failed." : response.message
            }
        }
        .store(in: &cancellables)
    }

    private func resetAfterSuccess() {
        selectedOrderIds = []
        orders = []
        loadBootstrapData()
        loadOrdersForSelectedBeats()
    }

    private func resultPublisher<T>(_ publisher: AnyPublisher<T, Error>) -> AnyPublisher<Result<T, Error>, Never> {
        publisher
            .map { (value: T) -> Result<T, Error> in .success(value) }
            .catch { (error: Error) -> Just<Result<T, Error>> in
                Just(.failure(error))
            }
            .eraseToAnyPublisher()
    }
}
