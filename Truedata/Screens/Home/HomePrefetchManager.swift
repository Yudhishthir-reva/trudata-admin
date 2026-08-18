//
//  HomePrefetchManager.swift
//  Truedata
//

import Combine
import Foundation

final class HomePrefetchManager {

    static let shared = HomePrefetchManager()

    private let service = HomePrefetchServiceManager()
    private var hasPrefetchedBaseApis = false
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func prefetchBaseApisIfNeeded() {
        guard !hasPrefetchedBaseApis else { return }
        hasPrefetchedBaseApis = true

        let today = DashboardDateFormat.todayString

        prefetch(service.fetchAllAreas()) { HomePrefetchStore.shared.areas = $0 }
        prefetch(service.fetchRoles()) { _ in }
        prefetch(service.fetchSellerTypes()) { _ in }
        prefetch(service.fetchStaffList()) { HomePrefetchStore.shared.staffList = $0 }
        prefetch(service.fetchLeaveTypes()) { _ in }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.prefetch(self.service.fetchStaffList()) { HomePrefetchStore.shared.staffList = $0 }
            self.prefetch(self.service.fetchSellerList()) { _ in }
            self.prefetch(self.service.fetchTransactionHistory(startDate: today, endDate: today)) { _ in }
            self.prefetch(self.service.fetchBillSettlementHistory(startDate: today, endDate: today)) { _ in }
            self.prefetch(self.service.fetchTodayAchievements(startDate: today, endDate: today)) { _ in }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.prefetch(self.service.fetchCategories()) { _ in }
            self.prefetch(self.service.fetchVariants()) { _ in }
            self.prefetch(self.service.fetchBrands()) { _ in }
            self.prefetch(self.service.fetchStaffList()) { HomePrefetchStore.shared.staffList = $0 }
            self.prefetch(self.service.fetchTopSellingProducts(startDate: today, endDate: today)) { _ in }
            self.prefetch(self.service.fetchProducts(page: 1)) { _ in }
        }
    }

    func fetchLocationConfig() {
        service.fetchLocationConfig()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { response in
                    guard response.status, let data = response.data else { return }
                    HomePrefetchStore.shared.locationConfig = response
                    UserDefaultManager.shared.updateLocationConfig(data)
                }
            )
            .store(in: &cancellables)
    }

    func reset() {
        hasPrefetchedBaseApis = false
        cancellables.removeAll()
        HomePrefetchStore.shared.clear()
    }

    private func prefetch<T>(
        _ publisher: AnyPublisher<T, Error>,
        onSuccess: @escaping (T) -> Void
    ) {
        publisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: onSuccess
            )
            .store(in: &cancellables)
    }
}
