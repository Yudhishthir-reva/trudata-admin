//
//  MarkAttendanceViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class MarkAttendanceViewModel: ObservableObject {

    @Published var checkInState: AttendanceCheckInState = .checkIn
    @Published var markType = "in"
    @Published var checkInTime = "No data available"
    @Published var checkOutTime = "No data available"
    @Published var history: [AttendanceHistoryItem] = []

    @Published var isLoadingStatus = false
    @Published var isLoadingHistory = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    @Published var showPunchSheet = false
    @Published var punchSuccessMessage: String?
    @Published var punchErrorMessage: String?

    @Published var selectedHistoryItem: AttendanceHistoryItem?
    @Published var showDetailSheet = false

    @Published private(set) var currentTime = AttendanceTimeFormatter.liveClockParts()
    @Published private(set) var currentDate = AttendanceTimeFormatter.headerDate()

    private let service: MarkAttendanceServiceManager
    private var cancellables = Set<AnyCancellable>()
    private var clockTimer: AnyCancellable?

    init(service: MarkAttendanceServiceManager = MarkAttendanceServiceManager()) {
        self.service = service
        startClock()
    }

    var punchSheetTitle: String {
        markType == "in" ? "Perform Check-in" : "Perform Check-out"
    }

    var slideConfirmText: String {
        markType == "in" ? "Slide to Check-in" : "Slide to Check-out"
    }

    func load() {
        loadStatus()
        loadHistory()
    }

    func refresh() {
        load()
    }

    func openPunchSheet() {
        guard checkInState != .done else { return }
        punchSuccessMessage = nil
        punchErrorMessage = nil
        showPunchSheet = true
    }

    func closePunchSheet() {
        guard !isSubmitting else { return }
        showPunchSheet = false
        punchSuccessMessage = nil
        punchErrorMessage = nil
    }

    func openHistoryDetail(_ item: AttendanceHistoryItem) {
        selectedHistoryItem = item
        showDetailSheet = true
    }

    func closeDetailSheet() {
        showDetailSheet = false
        selectedHistoryItem = nil
    }

    func performPunch(location: LocationSnapshot?) {
        guard let location else {
            punchErrorMessage = "Unable to get location. Please try again."
            return
        }

        isSubmitting = true
        punchErrorMessage = nil
        punchSuccessMessage = nil

        service.markAttendance(
            markType: markType,
            latitude: String(location.latitude),
            longitude: String(location.longitude),
            address: location.address
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isSubmitting = false
            if case .failure(let error) = completion {
                self.punchErrorMessage = error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            if response.status {
                let message: String
                if self.markType == "in" {
                    message = "Punch in completed at \(response.data.inTime)"
                } else {
                    message = "Punch out completed at \(response.data.outTime ?? "")"
                }
                self.punchSuccessMessage = message
                self.loadStatus()
                self.loadHistory()
            } else {
                self.punchErrorMessage = response.message.isEmpty ? "Unable to mark attendance." : response.message
            }
        }
        .store(in: &cancellables)
    }

    private func loadStatus() {
        isLoadingStatus = true
        errorMessage = nil

        service.checkAttendanceStatus()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingStatus = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                let data = response.data
                self.checkInTime = data.inTime
                self.checkOutTime = data.outTime

                if data.inTimeStatus && !data.outTimeStatus {
                    self.markType = "out"
                    self.checkInState = .checkOut
                } else if !data.inTimeStatus {
                    self.markType = "in"
                    self.checkInState = .checkIn
                } else {
                    self.markType = "done"
                    self.checkInState = .done
                }
            }
            .store(in: &cancellables)
    }

    private func loadHistory() {
        isLoadingHistory = true

        service.fetchAttendanceList()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingHistory = false
                if case .failure(let error) = completion, self.errorMessage == nil {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.history = response.data.sorted { $0.date > $1.date }
            }
            .store(in: &cancellables)
    }

    private func startClock() {
        clockTimer?.cancel()
        clockTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.currentTime = AttendanceTimeFormatter.liveClockParts(from: date)
                self?.currentDate = AttendanceTimeFormatter.headerDate(from: date)
            }
    }
}
