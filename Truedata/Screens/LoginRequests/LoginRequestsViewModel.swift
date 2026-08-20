//
//  LoginRequestsViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class LoginRequestsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var requests: [DeviceChangeRequestItem] = []
    @Published var selectedTab: LoginRequestTab = .pending
    @Published var actioningRequestId: Int?
    @Published var staffList: [OrderInsightsStaffMember] = []
    @Published var isLoadingStaff = false

    private let service = LoginRequestsServiceManager()
    private var cancellables = Set<AnyCancellable>()

    func loadRequests() {
        isLoading = requests.isEmpty
        errorMessage = nil

        service.getDeviceChangeRequests(status: selectedTab.apiStatus)
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
                if response.status || !response.data.isEmpty {
                    self.requests = response.data
                    self.errorMessage = nil
                } else {
                    self.requests = []
                    self.errorMessage = "Failed to load login requests."
                }
            }
            .store(in: &cancellables)
    }

    func selectTab(_ tab: LoginRequestTab) {
        selectedTab = tab
        loadRequests()
    }

    func approveOrReject(requestId: Int, action: String) {
        actioningRequestId = requestId
        errorMessage = nil
        successMessage = nil

        service.approveOrRejectRequest(requestId: requestId, status: action)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.actioningRequestId = nil
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.actioningRequestId = nil
                if response.status {
                    self.successMessage = response.message.isEmptyString
                        ? "Request updated successfully."
                        : response.message
                    self.loadRequests()
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to update request."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func loadStaffListIfNeeded() {
        guard staffList.isEmpty, !isLoadingStaff else { return }
        isLoadingStaff = true

        service.getStaffList()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isLoadingStaff = false
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingStaff = false
                if response.status {
                    self.staffList = response.data
                }
            }
            .store(in: &cancellables)
    }
}

final class LoginHistoryViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var history: [DeviceChangeHistoryItem] = []

    private let service = LoginRequestsServiceManager()
    private var cancellables = Set<AnyCancellable>()

    func loadHistory(userId: String) {
        isLoading = history.isEmpty
        errorMessage = nil

        service.getDeviceChangeHistory(userId: userId)
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
                if response.status || !response.data.isEmpty {
                    self.history = response.data
                    self.errorMessage = nil
                } else {
                    self.history = []
                    self.errorMessage = "Failed to load login history."
                }
            }
            .store(in: &cancellables)
    }
}
