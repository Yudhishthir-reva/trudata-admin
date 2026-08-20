//
//  StaffProfileViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class StaffProfileViewModel: ObservableObject {

    let context: StaffProfileContext

    @Published var selectedTab: StaffProfileTab = .attendance
    @Published var attendanceItems: [AttendanceHistoryItem] = []
    @Published var locationItems: [StaffLocationLogItem] = []
    @Published var isLoadingAttendance = false
    @Published var isLoadingLocation = false
    @Published var isLoadingMoreLocations = false
    @Published var attendanceError: String?
    @Published var locationError: String?

    private let service = StaffReportServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var locationPage = 1
    private var canLoadMoreLocations = false

    init(context: StaffProfileContext) {
        self.context = context
    }

    var screenTitle: String {
        "\(context.name)'s Profile"
    }

    var latestLocation: StaffLocationLogItem? {
        locationItems.last
    }

    func loadInitialData() {
        loadAttendance()
        loadLocations(reset: true)
    }

    func refreshCurrentTab() {
        switch selectedTab {
        case .attendance:
            loadAttendance()
        case .location:
            loadLocations(reset: true)
        }
    }

    func loadAttendance() {
        isLoadingAttendance = true
        attendanceError = nil

        service.fetchTeamAttendance(
            memberId: context.memberId,
            month: StaffProfileDateFormat.currentMonth
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoadingAttendance = false
            if case .failure(let error) = completion, self.attendanceItems.isEmpty {
                self.attendanceError = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoadingAttendance = false
            if response.status {
                self.attendanceItems = response.data
                self.attendanceError = nil
            } else {
                self.attendanceError = response.message.isEmptyString
                    ? "Failed to load attendance."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    func loadLocations(reset: Bool) {
        if reset {
            locationPage = 1
            canLoadMoreLocations = false
            if locationItems.isEmpty {
                isLoadingLocation = true
            }
        } else {
            isLoadingMoreLocations = true
        }
        locationError = nil

        service.fetchTeamLocations(
            memberId: context.memberId,
            date: StaffProfileDateFormat.currentDate,
            page: locationPage
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoadingLocation = false
            self.isLoadingMoreLocations = false
            if case .failure(let error) = completion, self.locationItems.isEmpty {
                self.locationError = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoadingLocation = false
            self.isLoadingMoreLocations = false

            guard response.status else {
                self.locationError = response.message.isEmptyString
                    ? "Failed to load locations."
                    : response.message
                return
            }

            if reset {
                self.locationItems = response.data.data
            } else {
                let existingIDs = Set(self.locationItems.map(\.id))
                let newItems = response.data.data.filter { !existingIDs.contains($0.id) }
                self.locationItems.append(contentsOf: newItems)
            }

            self.locationPage = response.data.currentPage
            self.canLoadMoreLocations = response.data.currentPage < response.data.lastPage
            self.locationError = nil
        }
        .store(in: &cancellables)
    }

    func loadMoreLocationsIfNeeded() {
        guard canLoadMoreLocations, !isLoadingMoreLocations else { return }
        locationPage += 1
        loadLocations(reset: false)
    }
}
