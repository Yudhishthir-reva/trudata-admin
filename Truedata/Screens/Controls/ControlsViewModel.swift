//
//  ControlsViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class ControlsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var controlsTitle = "Controls"
    @Published private(set) var employeePayload: JSONValue?
    @Published private(set) var staffReportPayload: JSONValue?
    @Published private(set) var riderReportPayload: JSONValue?

    private let service = DashboardServiceManager()
    private var cancellables = Set<AnyCancellable>()

    var pendingLeaveCount: Int {
        employeePayload?.int(for: "pendingLeaveCount") ?? 0
    }

    var todayLeaveCount: Int {
        employeePayload?.int(for: "todayLeaveCount") ?? 0
    }

    var pendingRegularizeCount: Int {
        employeePayload?.int(for: "pendingRegularizeCount") ?? 0
    }

    var todayRegularizeCount: Int {
        employeePayload?.int(for: "todayRegularizeCount", "todayRegulizeCount") ?? 0
    }

    var pendingExpenseCount: Int {
        employeePayload?.int(for: "pendingExpenseCount") ?? 0
    }

    var todayExpenseCount: Int {
        employeePayload?.int(for: "todayExpenseCount") ?? 0
    }

    var totalStaff: Int {
        staffReportPayload?.int(for: "totalStaff") ?? 0
    }

    var presentStaff: Int {
        staffReportPayload?.int(for: "presentStaff") ?? 0
    }

    var absentStaff: Int {
        staffReportPayload?.int(for: "absentStaff") ?? 0
    }

    var totalRider: Int {
        riderReportPayload?.int(for: "totalRider") ?? 0
    }

    var presentRider: Int {
        riderReportPayload?.int(for: "presentRider") ?? 0
    }

    var absentRider: Int {
        riderReportPayload?.int(for: "absentRider") ?? 0
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
            if response.status, let items = response.data?.items {
                self.apply(items: items)
                self.errorMessage = nil
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load controls."
                    : response.message
            }
        }
        .store(in: &cancellables)
    }

    private func apply(items: [DashboardItem]) {
        if let controls = items.first(where: { $0.route == "controls" }),
           !controls.title.isEmptyString {
            controlsTitle = controls.title
        }

        employeePayload = items.first(where: { $0.route == "manage_employees" })?.payload
            ?? items.first(where: { $0.route == "view_leaves" })?.payload
        staffReportPayload = items.first(where: { $0.route == "staff_report" })?.payload
        riderReportPayload = items.first(where: { $0.route == "rider_report" })?.payload
    }
}
