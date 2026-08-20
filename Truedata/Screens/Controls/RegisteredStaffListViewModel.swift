//
//  RegisteredStaffListViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class RegisteredStaffListViewModel: ObservableObject {

    @Published var selectedTab: StaffMemberTab = .active
    @Published var searchText = ""
    @Published var staffMembers: [RegisteredStaffMember] = []
    @Published var isLoading = false
    @Published var isUpdatingStatus = false
    @Published var errorMessage: String?
    @Published var pendingStatusUpdate: RegisteredStaffMember?

    private let service = StaffServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var filteredMembers: [RegisteredStaffMember] {
        let byStatus = staffMembers.filter { member in
            selectedTab == .active ? member.isActive : !member.isActive
        }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return byStatus
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return byStatus.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.mobile.localizedCaseInsensitiveContains(query)
                || $0.roleId.localizedCaseInsensitiveContains(query)
        }
    }

    func load() {
        isLoading = staffMembers.isEmpty
        errorMessage = nil

        service.fetchStaffList()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion, self.staffMembers.isEmpty {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status {
                    self.staffMembers = response.data
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load staff members."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func requestStatusUpdate(for member: RegisteredStaffMember) {
        pendingStatusUpdate = member
    }

    func cancelStatusUpdate() {
        pendingStatusUpdate = nil
    }

    func confirmStatusUpdate() {
        guard let member = pendingStatusUpdate else { return }
        let newStatus = selectedTab == .active ? 0 : 1
        isUpdatingStatus = true
        pendingStatusUpdate = nil

        service.updateStaffStatus(staffId: member.id, status: newStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isUpdatingStatus = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isUpdatingStatus = false
                if response.status {
                    self.load()
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Unable to update staff status."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func statusDialog(for member: RegisteredStaffMember) -> (title: String, message: String) {
        let action = selectedTab == .active ? "Deactivate" : "Activate"
        return (
            title: "\(action) \(member.name)?",
            message: "Are you sure you want to \(action.lowercased()) \(member.name)?"
        )
    }
}
