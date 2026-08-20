//
//  ViewTargetsViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class ViewTargetsViewModel: ObservableObject {

    @Published var searchText = ""
    @Published var targets: [SalesTargetItem] = []
    @Published var staffMembers: [RegisteredStaffMember] = []
    @Published var filters = TargetFilters()
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?

    @Published var showTargetForm = false
    @Published var showFilterSheet = false
    @Published var targetForm = TargetFormData()

    private let service = TargetServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 1
    private var hasNextPage = false
    private var fetchTask: AnyCancellable?

    var filteredTargets: [SalesTargetItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return targets
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return targets.filter { $0.staffName.localizedCaseInsensitiveContains(query) }
    }

    var eligibleStaff: [RegisteredStaffMember] {
        staffMembers.filter {
            $0.roleId.caseInsensitiveCompare("Sale Person") == .orderedSame
                || $0.roleId.caseInsensitiveCompare("Sales Manager") == .orderedSame
        }
    }

    func load(reset: Bool = true) {
        if reset {
            currentPage = 1
            hasNextPage = false
            isLoading = targets.isEmpty
        } else {
            guard hasNextPage, !isLoadingMore else { return }
            isLoadingMore = true
            currentPage += 1
        }

        errorMessage = nil
        let page = currentPage

        fetchTask?.cancel()
        fetchTask = service.fetchTargetList(
            page: page,
            staffId: filters.staffId,
            targetStatus: filters.targetStatus,
            month: filters.month
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if case .failure(let error) = completion, self.targets.isEmpty {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if response.status {
                if reset {
                    self.targets = response.data.targets
                } else {
                    let existingIds = Set(self.targets.map(\.id))
                    let newItems = response.data.targets.filter { !existingIds.contains($0.id) }
                    self.targets.append(contentsOf: newItems)
                }
                self.currentPage = response.data.currentPage
                self.hasNextPage = response.data.hasNextPage
                self.errorMessage = nil
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load targets."
                    : response.message
            }
        }
    }

    func loadStaffIfNeeded() {
        guard staffMembers.isEmpty else { return }
        service.fetchStaffList()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                if response.status {
                    self?.staffMembers = response.data
                }
            }
            .store(in: &cancellables)
    }

    func loadMoreIfNeeded(currentTarget: SalesTargetItem) {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let last = filteredTargets.last, last.id == currentTarget.id else { return }
        load(reset: false)
    }

    func applyFilters(_ filters: TargetFilters) {
        self.filters = filters
        load(reset: true)
    }

    func resetFilters() {
        filters = TargetFilters()
        load(reset: true)
    }

    func prepareCreateTarget() {
        let defaults = TargetAPIDateFormat.defaultCreateRange()
        targetForm = TargetFormData(
            month: defaults.month,
            targetStartDate: defaults.start,
            targetEndDate: defaults.end,
            targetStatus: "1"
        )
        loadStaffIfNeeded()
        showTargetForm = true
    }

    func prepareEditTarget(_ target: SalesTargetItem) {
        targetForm = TargetFormData(
            targetId: target.id,
            staffId: target.staffId,
            staffName: target.staffName,
            targetAmount: target.targetAmount,
            month: target.month,
            targetStartDate: target.targetStartDate,
            targetEndDate: target.targetEndDate,
            targetStatus: target.targetStatus
        )
        loadStaffIfNeeded()
        showTargetForm = true
    }

    func updateMonth(_ month: String) {
        targetForm.month = month
        if let range = TargetAPIDateFormat.monthRange(for: month) {
            targetForm.targetStartDate = range.start
            targetForm.targetEndDate = range.end
        }
    }

    func saveTarget() {
        let trimmedAmount = targetForm.targetAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetForm.staffId.isEmpty else {
            toastMessage = "Staff, Amount, and Month are required."
            return
        }
        guard !trimmedAmount.isEmpty else {
            toastMessage = "Staff, Amount, and Month are required."
            return
        }
        guard !targetForm.month.isEmpty else {
            toastMessage = "Staff, Amount, and Month are required."
            return
        }

        isSaving = true
        toastMessage = nil

        let publisher: AnyPublisher<TargetStatusMessageResponse, Error>
        if let targetId = targetForm.targetId {
            publisher = service.updateTarget(
                targetId: String(targetId),
                staffId: targetForm.staffId,
                targetAmount: trimmedAmount,
                month: targetForm.month,
                targetStartDate: targetForm.targetStartDate,
                targetEndDate: targetForm.targetEndDate,
                targetStatus: targetForm.targetStatus
            )
        } else {
            publisher = service.createTarget(
                staffId: targetForm.staffId,
                targetAmount: trimmedAmount,
                month: targetForm.month,
                targetStartDate: targetForm.targetStartDate,
                targetEndDate: targetForm.targetEndDate
            )
        }

        publisher
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
                    let wasEditMode = self.targetForm.isEditMode
                    self.showTargetForm = false
                    self.targetForm = TargetFormData()
                    self.toastMessage = response.message.isEmptyString
                        ? (wasEditMode ? "Target updated successfully." : "Target created successfully.")
                        : response.message
                    self.load(reset: true)
                } else {
                    self.toastMessage = response.message.isEmptyString
                        ? "Failed to save target."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func deleteTarget(_ target: SalesTargetItem) {
        isSaving = true
        service.deleteTarget(targetId: String(target.id))
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
                        ? "Target deleted successfully."
                        : response.message
                    self.load(reset: true)
                } else {
                    self.toastMessage = response.message.isEmptyString
                        ? "Failed to delete target."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }
}
