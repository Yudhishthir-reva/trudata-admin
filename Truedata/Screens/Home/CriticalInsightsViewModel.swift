//
//  CriticalInsightsViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class CriticalInsightsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var summaryData: CriticalInsightsData?
    @Published var selectedTab: CriticalInsightsTab = .noOrders
    @Published var searchText = ""
    @Published var selectedBeat: String?
    @Published var staffId = ""
    @Published var staffName = "All Staff"
    @Published var staffList: [OrderInsightsStaffMember] = []
    @Published var isLoadingStaff = false
    @Published var isExporting = false
    @Published var exportShareURL: URL?
    @Published var exportAlertMessage: String?

    private let service = CriticalInsightsServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var noOrdersCount: Int {
        summaryData?.noOrderSellers.count ?? 0
    }

    var noPaymentsCount: Int {
        summaryData?.noPaymentSellers.count ?? 0
    }

    var isStaffFilterActive: Bool {
        !staffId.isEmptyString
    }

    var canShowStaffFilter: Bool {
        DashboardRole.canShowStaffFilter(
            role: UserDefaultManager.shared.getUserDefaultsString(key: .userRole)
        )
    }

    var activeTabColor: Color {
        selectedTab == .noOrders ? DashboardTheme.warningYellow : DashboardTheme.dangerRed
    }

    var filteredSellers: [CriticalInsightsSellerItem] {
        let source = selectedTab == .noOrders
            ? (summaryData?.noOrderSellers ?? [])
            : (summaryData?.noPaymentSellers ?? [])

        return source.filter { seller in
            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || seller.name.localizedCaseInsensitiveContains(searchText)
            let matchesBeat = selectedBeat == nil || seller.beatName == selectedBeat
            return matchesSearch && matchesBeat
        }
    }

    var groupedSellers: [(beatName: String, sellers: [CriticalInsightsSellerItem])] {
        let grouped = Dictionary(grouping: filteredSellers) { seller in
            seller.beatName.isEmptyString ? "Unassigned Beat" : seller.beatName
        }
        return grouped.keys.sorted().map { beat in
            (beatName: beat, sellers: grouped[beat] ?? [])
        }
    }

    var emptyStateMessage: String {
        if !searchText.isEmptyString || selectedBeat != nil {
            return "No sellers found matching filters"
        }
        return selectedTab == .noOrders
            ? "All sellers have placed orders in the last 10 days!"
            : "No pending payments from the last 10 days!"
    }

    func initialize() {
        loadSummary()
        loadStaffListIfNeeded()
    }

    func loadSummary(isRefresh: Bool = false) {
        if !isRefresh {
            isLoading = summaryData == nil
        }
        errorMessage = nil

        service.getLastTenDaysSummary(
            staffId: staffId.isEmptyString ? nil : staffId
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
                self.summaryData = response.data
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load critical insights."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    func applyStaffFilter(staffId: String, staffName: String) {
        self.staffId = staffId
        self.staffName = staffName.isEmptyString ? "All Staff" : staffName
        loadSummary()
    }

    func exportExcel() {
        guard !isExporting else { return }
        isExporting = true
        exportAlertMessage = nil

        service.exportExcel(staffId: staffId.isEmptyString ? nil : staffId)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isExporting = false
                if case .failure(let error) = completion {
                    self.exportAlertMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] result in
                guard let self else { return }
                self.isExporting = false

                let directory = FileManager.default.temporaryDirectory
                let fileURL = directory.appendingPathComponent(result.filename)
                do {
                    try result.data.write(to: fileURL, options: .atomic)
                    self.exportShareURL = fileURL
                } catch {
                    self.exportAlertMessage = "Failed to save export file."
                }
            }
            .store(in: &cancellables)
    }

    private func loadStaffListIfNeeded() {
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
