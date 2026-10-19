//
//  ManualAttendanceServiceManager.swift
//  Truedata
//

import Foundation
import Combine

/// `manual-attendance/…` sits outside `APIRouter` the same way Cash Collection and Payment Advance
/// do: one struct that interpolates the path prefix, JSON in, JSON out.
struct ManualAttendanceEndpoint: RouterManagable {
    let path: String
    var endPointUrl: String { "manual-attendance/\(path)" }
    var contentType: RequestContentType { .json }
}

final class ManualAttendanceServiceManager {
    private let network: NetworkServiceManagable

    init(network: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.network = network
    }

    /// Everyone but the caller, with what is already marked on `date` (`yyyy-MM-dd`).
    func fetchStaffList(date: String) -> AnyPublisher<ManualAttendanceStaffListResponse, Error> {
        network.request(
            ManualAttendanceEndpoint(path: "staff-list"),
            params: ["date": date],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    /// Marks `marks` (user id → attendance type code) on `date`. The server upserts, so re-marking a
    /// day replaces it.
    func mark(date: String, marks: [Int: ManualAttendanceType]) -> AnyPublisher<ManualAttendanceMarkResponse, Error> {
        let attendances = marks
            .sorted { $0.key < $1.key }
            .map { ["user_id": $0.key, "attendance_type": $0.value.rawValue] }
        return network.request(
            ManualAttendanceEndpoint(path: "mark"),
            params: ["date": date, "attendances": attendances],
            headers: UserDefaultManager.shared.authHeader
        )
    }

    func fetchHistory(date: String) -> AnyPublisher<ManualAttendanceHistoryResponse, Error> {
        network.request(
            ManualAttendanceEndpoint(path: "history"),
            params: ["date": date],
            headers: UserDefaultManager.shared.authHeader
        )
    }
}
