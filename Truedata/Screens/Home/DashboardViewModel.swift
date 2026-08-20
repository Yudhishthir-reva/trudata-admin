//
//  DashboardViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

class DashboardViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var response: DashboardResponse?
    @Published var isLoggingOut = false
    @Published var startDate: String = DashboardDateFormat.todayString
    @Published var endDate: String = DashboardDateFormat.todayString
    @Published var dateValidationError: String?

    private var cancellables = Set<AnyCancellable>()
    private let service = DashboardServiceManager()
    private var hasInitialLoadCompleted = false

    var screenTitle: String {
        let title = response?.data?.screenTitle ?? ""
        return title.isEmptyString ? UserDefaultManager.shared.getUserDefaultsString(key: .userName) : title
    }

    var role: String {
        let value = response?.role ?? UserDefaultManager.shared.getUserDefaultsString(key: .userRole)
        return DashboardRole.normalized(value)
    }

    var displayRole: String {
        let raw = response?.role ?? UserDefaultManager.shared.getUserDefaultsString(key: .userRole)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var profileUrl: String {
        response?.data?.profileUrl ?? ""
    }

    var isBeatSelected: Bool {
        response?.isBeatSelected ?? true
    }

    var maintenanceMode: Bool {
        response?.maintenanceMode ?? false
    }

    var attendanceScreen: Bool {
        response?.attendanceScreen ?? false
    }

    var attendanceRoute: String {
        let route = response?.attendanceRoute ?? "attendance"
        return route.isEmptyString ? "attendance" : route
    }

    var items: [DashboardItem] {
        response?.data?.items ?? []
    }

    var sections: [DashboardSection] {
        let all = response?.data?.sections ?? []
        guard DashboardRole.shouldHideMyAreaSection(role: role) else { return all }
        return all.filter { DashboardRole.normalized($0.title) != "my area" }
    }

    var gridColumns: Int {
        max(response?.data?.columns ?? 2, 1)
    }

    var operationTitles: [String] {
        var operations = ["Actions", "Seller", "Activity"]
        if DashboardRole.canShowControlsOperation(role: role) {
            operations.append("Controls")
        }
        return operations
    }

    /// Top selling map from the Products tile — used when manage_orders has placeholder data.
    var globalTopSellingFallback: JSONValue? {
        items.first(where: { $0.route == "view_products" })?.payload
    }

    func loadHome(isRefresh: Bool = false) {
        if isRefresh {
            isRefreshing = true
        } else if response == nil {
            isLoading = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil

        let today = DashboardDateFormat.todayString
        service.loadHome(
            deviceId: DeviceInfo.current().deviceId,
            startDate: startDate.isEmptyString ? today : startDate,
            endDate: endDate.isEmptyString ? today : endDate
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isRefreshing = false
            if case .failure(let error) = completion {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] model in
            guard let self else { return }
            self.isLoading = false
            self.isRefreshing = false
            if model.status {
                self.response = model
                if !model.role.isEmptyString {
                    UserDefaultManager.shared.setUserDefaultsString(value: model.role, key: .userRole)
                }
                self.hasInitialLoadCompleted = true
                self.errorMessage = nil
                HomePrefetchManager.shared.fetchLocationConfig()
                HomePrefetchManager.shared.prefetchBaseApisIfNeeded()
            } else {
                self.errorMessage = model.message.isEmptyString ? "Failed to load dashboard." : model.message
            }
        }
        .store(in: &cancellables)
    }

    func loadHomeForResume() {
        guard hasInitialLoadCompleted else {
            loadHome()
            return
        }
        loadHome(isRefresh: true)
    }

    func logout() {
        isLoggingOut = true
        service.logout()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.finishLogout()
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }

    private func finishLogout() {
        isLoggingOut = false
        HomePrefetchManager.shared.reset()
        UserDefaultManager.shared.resetUserData()
        AppRootManager.shared.setRootView(view: AuthScreen())
    }

    func updateDateRange(start: String, end: String) {
        startDate = start
        endDate = end
        dateValidationError = nil
    }

    func fetchDashboardData() {
        guard validateDateRange() else { return }
        loadHome(isRefresh: true)
    }

    private func validateDateRange() -> Bool {
        guard let start = DashboardDateFormat.parse(startDate),
              let end = DashboardDateFormat.parse(endDate) else {
            dateValidationError = "Invalid date format"
            return false
        }

        if start > end {
            dateValidationError = "Start date cannot be after end date"
            return false
        }

        dateValidationError = nil
        return true
    }
}
