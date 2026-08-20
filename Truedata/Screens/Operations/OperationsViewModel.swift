//
//  OperationsViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class OperationsViewModel: ObservableObject {

    let screenType: OperationsScreenType

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var items: [OperationsTile] = []

    private let service = DashboardServiceManager()
    private var cancellables = Set<AnyCancellable>()

    init(screenType: OperationsScreenType) {
        self.screenType = screenType
    }

    func load() {
        isLoading = true
        errorMessage = nil

        let today = DashboardDateFormat.todayString
        service.loadHome(
            deviceId: DeviceInfo.current().deviceId,
            startDate: today,
            endDate: today
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            if case .failure(let error) = completion {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            if response.status, let data = response.data {
                self.items = Self.filteredItems(from: data.items, screenType: self.screenType)
                self.errorMessage = nil
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load \(self.screenType.title.lowercased()) data."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    static func filteredItems(from allItems: [DashboardItem], screenType: OperationsScreenType) -> [OperationsTile] {
        var expanded: [OperationsTile] = allItems.map(OperationsTile.init)

        for item in allItems where item.route == "manage_employees" && screenType == .controls {
            expanded.append(OperationsTile(id: "leave_approval_\(item.itemId)", title: "Leave Approvals", route: "leave_approval", payload: item.payload))
            expanded.append(OperationsTile(id: "regularize_approval_\(item.itemId)", title: "Regularize Approvals", route: "regularize_approval", payload: item.payload))
            expanded.append(OperationsTile(id: "expense_approval_\(item.itemId)", title: "Expense Approvals", route: "expense_approval", payload: item.payload))
        }

        let filtered = expanded.filter { tile in
            guard !tile.route.isEmptyString, !tile.title.isEmptyString else { return false }
            if ["leave_approval", "regularize_approval", "expense_approval"].contains(tile.route) {
                return screenType == .controls
            }
            return screenType.allowedRoutes.contains(tile.route)
        }

        let order = screenType.routeOrder
        return filtered.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.route) ?? Int.max
            let right = order.firstIndex(of: rhs.route) ?? Int.max
            if left != right { return left < right }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}
