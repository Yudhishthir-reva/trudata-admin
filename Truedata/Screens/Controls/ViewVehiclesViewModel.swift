//
//  ViewVehiclesViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class ViewVehiclesViewModel: ObservableObject {

    @Published var selectedTab: VehicleListTab = .vehicles
    @Published var searchText = ""
    @Published var vehicles: [AdminVehicleItem] = []
    @Published var riders: [AdminVehicleRider] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isAssigning = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?

    @Published var showAssignSheet = false
    @Published var showUnassignDialog = false
    @Published var showVehicleForm = false
    @Published var selectedVehicle: AdminVehicleItem?
    @Published var selectedRiderId: String?
    @Published var vehicleForm = VehicleFormData()

    private let service = VehicleServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var filteredVehicles: [AdminVehicleItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return vehicles
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return vehicles.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.model.localizedCaseInsensitiveContains(query)
                || $0.plateNumber.localizedCaseInsensitiveContains(query)
        }
    }

    var filteredRiders: [AdminVehicleRider] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return riders
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return riders.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.staffId.localizedCaseInsensitiveContains(query)
                || $0.mobile.localizedCaseInsensitiveContains(query)
                || ($0.assignedVehicleName?.localizedCaseInsensitiveContains(query) == true)
                || ($0.assignedVehiclePlate?.localizedCaseInsensitiveContains(query) == true)
        }
    }

    var availableRiders: [AdminVehicleRider] {
        riders.filter { !$0.hasVehicleAssigned && $0.isActive }
    }

    func load() {
        isLoading = vehicles.isEmpty && riders.isEmpty
        errorMessage = nil

        service.fetchVehicleList()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion, self.vehicles.isEmpty {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status {
                    self.vehicles = response.data.vehicles
                    self.riders = response.data.riders
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load vehicles."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func prepareAddVehicle() {
        vehicleForm = VehicleFormData()
        showVehicleForm = true
    }

    func prepareEditVehicle(_ vehicle: AdminVehicleItem) {
        vehicleForm = VehicleFormData(
            vehicleId: String(vehicle.id),
            name: vehicle.name,
            model: vehicle.model,
            plateNumber: vehicle.plateNumber,
            status: vehicle.status
        )
        showVehicleForm = true
    }

    func saveVehicle() {
        let trimmedName = vehicleForm.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = vehicleForm.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlate = vehicleForm.plateNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedModel.isEmpty, !trimmedPlate.isEmpty else {
            errorMessage = "Please fill all vehicle details."
            return
        }

        isSaving = true
        errorMessage = nil

        let publisher: AnyPublisher<VehicleStatusMessageResponse, Error>
        if let vehicleId = vehicleForm.vehicleId {
            publisher = service.updateVehicle(
                vehicleId: vehicleId,
                name: trimmedName,
                model: trimmedModel,
                plateNumber: trimmedPlate,
                status: vehicleForm.status
            )
        } else {
            publisher = service.createVehicle(
                name: trimmedName,
                model: trimmedModel,
                plateNumber: trimmedPlate,
                status: vehicleForm.status
            )
        }

        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSaving = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSaving = false
                if response.status {
                    let wasEditMode = self.vehicleForm.isEditMode
                    self.showVehicleForm = false
                    self.vehicleForm = VehicleFormData()
                    self.toastMessage = response.message.isEmptyString
                        ? (wasEditMode ? "Vehicle updated successfully." : "Vehicle created successfully.")
                        : response.message
                    self.load()
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to save vehicle."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func deleteVehicle(_ vehicle: AdminVehicleItem) {
        isSaving = true
        service.deleteVehicle(vehicleId: String(vehicle.id))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSaving = false
                if case .failure(let error) = completion {
                    self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSaving = false
                if response.status {
                    self.toastMessage = response.message.isEmptyString
                        ? "Vehicle deleted successfully."
                        : response.message
                    self.load()
                } else {
                    self.toastMessage = response.message.isEmptyString
                        ? "Failed to delete vehicle."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func openAssignSheet(for vehicle: AdminVehicleItem) {
        selectedVehicle = vehicle
        selectedRiderId = nil
        showAssignSheet = true
    }

    func openUnassignDialog(for vehicle: AdminVehicleItem) {
        selectedVehicle = vehicle
        showUnassignDialog = true
    }

    func dismissAssignmentDialogs() {
        showAssignSheet = false
        showUnassignDialog = false
        selectedVehicle = nil
        selectedRiderId = nil
    }

    func assignVehicle() {
        guard let vehicle = selectedVehicle else { return }
        guard let riderId = selectedRiderId else {
            errorMessage = "Please select a rider."
            return
        }

        isAssigning = true
        service.assignVehicle(vehicleId: String(vehicle.id), riderId: riderId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isAssigning = false
                if case .failure(let error) = completion {
                    self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isAssigning = false
                if response.status {
                    self.dismissAssignmentDialogs()
                    self.toastMessage = response.message.isEmptyString
                        ? "Vehicle assigned successfully."
                        : response.message
                    self.load()
                } else {
                    self.toastMessage = response.message.isEmptyString
                        ? "Failed to assign vehicle."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func unassignVehicle() {
        guard let vehicle = selectedVehicle,
              let assignmentId = vehicle.vehicleAssigned?.id else {
            toastMessage = "Invalid assignment data."
            return
        }

        isAssigning = true
        service.unassignVehicle(assignmentId: String(assignmentId))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isAssigning = false
                if case .failure(let error) = completion {
                    self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isAssigning = false
                if response.status {
                    self.dismissAssignmentDialogs()
                    self.toastMessage = response.message.isEmptyString
                        ? "Vehicle unassigned successfully."
                        : response.message
                    self.load()
                } else {
                    self.toastMessage = response.message.isEmptyString
                        ? "Failed to unassign vehicle."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }
}
