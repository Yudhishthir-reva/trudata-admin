//
//  AssignBeatViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class AssignBeatViewModel: ObservableObject {

    @Published var searchText = ""
    @Published var assignedBeats: [AssignedBeatStaffItem] = []
    @Published var staffMembers: [RegisteredStaffMember] = []
    @Published var availableBeats: [BeatListItem] = []
    @Published var assignForm = AssignBeatFormState()

    @Published var isLoading = false
    @Published var isOperationLoading = false
    @Published var isLoadingBeats = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    @Published var showAssignSheet = false

    private let service = AssignBeatServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var fetchTask: AnyCancellable?

    var filteredAssignments: [AssignedBeatStaffItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return assignedBeats }
        return assignedBeats.filter { item in
            item.staffName.localizedCaseInsensitiveContains(query)
                || item.beatData.contains { $0.beatName.localizedCaseInsensitiveContains(query) }
        }
    }

    var eligibleStaff: [RegisteredStaffMember] {
        staffMembers.filter(AssignBeatStaffFilter.isEligible)
    }

    func load(reset: Bool = true) {
        if reset { isLoading = assignedBeats.isEmpty }
        errorMessage = nil

        fetchTask?.cancel()
        fetchTask = service.fetchAssignedBeatList()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion, self.assignedBeats.isEmpty {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status {
                    self.assignedBeats = response.data
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load assigned beats."
                        : response.message
                }
            }
    }

    func loadSupportingDataIfNeeded() {
        guard staffMembers.isEmpty else { return }
        service.fetchStaffList()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                guard let self, response.status else { return }
                self.staffMembers = response.data
            }
            .store(in: &cancellables)
    }

    func prepareNewAssignment() {
        assignForm.reset()
        showAssignSheet = true
        loadAllBeatsIfNeeded()
    }

    func loadAllBeatsIfNeeded() {
        guard availableBeats.isEmpty else { return }
        isLoadingBeats = true

        loadBeatPage(page: 1, accumulated: [])
    }

    private func loadBeatPage(page: Int, accumulated: [BeatListItem]) {
        service.fetchBeatList(page: page, search: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case .failure = completion {
                    self.isLoadingBeats = false
                    self.availableBeats = accumulated
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                guard response.status else {
                    self.isLoadingBeats = false
                    self.availableBeats = accumulated
                    return
                }

                var merged = accumulated
                merged.append(contentsOf: response.data.beats)

                if response.data.hasNextPage {
                    self.loadBeatPage(page: page + 1, accumulated: merged)
                } else {
                    self.availableBeats = merged
                    self.isLoadingBeats = false
                }
            }
            .store(in: &cancellables)
    }

    func selectStaff(_ staff: RegisteredStaffMember) {
        assignForm.selectedStaffId = String(staff.id)
        assignForm.selectedStaffName = staff.name
    }

    func toggleBeatSelection(_ beatId: String) {
        if assignForm.selectedBeatIds.contains(beatId) {
            assignForm.selectedBeatIds.remove(beatId)
        } else {
            assignForm.selectedBeatIds.insert(beatId)
        }
    }

    func submitAssignment() {
        guard assignForm.isValid else { return }
        isOperationLoading = true

        service.assignBeats(
            staffId: assignForm.selectedStaffId,
            beatIds: Array(assignForm.selectedBeatIds)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isOperationLoading = false
            if case .failure(let error) = completion {
                self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isOperationLoading = false
            if response.status {
                self.showAssignSheet = false
                self.assignForm.reset()
                self.toastMessage = response.message.isEmptyString
                    ? "Beats assigned successfully."
                    : response.message
                self.load(reset: false)
            } else {
                self.toastMessage = response.message.isEmptyString
                    ? "Failed to assign beats."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    func deleteAssignment(_ item: AssignedBeatDetailItem) {
        isOperationLoading = true
        service.deleteAssignment(assignId: item.assignBeatId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isOperationLoading = false
                if case .failure(let error) = completion {
                    self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isOperationLoading = false
                if response.status {
                    self.toastMessage = response.message.isEmptyString
                        ? "Assignment removed."
                        : response.message
                    self.load(reset: false)
                } else {
                    self.toastMessage = response.message.isEmptyString
                        ? "Delete failed."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func toggleAssignmentStatus(_ item: AssignedBeatDetailItem) {
        let newStatus = item.isActive ? "0" : "1"
        service.updateAssignmentStatus(assignId: item.assignBeatId, status: newStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                if response.status {
                    self.toastMessage = response.message.isEmptyString
                        ? "Status updated."
                        : response.message
                    self.load(reset: false)
                } else {
                    self.toastMessage = response.message.isEmptyString
                        ? "Update failed."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }
}
