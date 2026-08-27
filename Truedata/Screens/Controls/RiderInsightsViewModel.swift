//
//  RiderInsightsViewModel.swift
//  Truedata
//

import Foundation
import Combine
import SwiftUI

@MainActor
class RiderInsightsViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var payload: RiderActivityDashboardPayload?

    @Published var selectedPreset: RiderDatePreset = .today
    @Published var startDate: String = ""
    @Published var endDate: String = ""
    @Published var searchText: String = ""
    @Published var viewMode: RiderViewMode = .insights
    @Published var selectedRiderName: String?

    private let service: RiderInsightsServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(service: RiderInsightsServiceManager = RiderInsightsServiceManager()) {
        self.service = service
        let range = RiderDatePreset.today.dateRange
        self.startDate = range.start
        self.endDate = range.end
    }

    func load(isRefresh: Bool = false) {
        if !isRefresh {
            isLoading = true
        }
        errorMessage = nil

        service.fetchRiderHistory(startDate: startDate, endDate: endDate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status, let data = response.data {
                    self.payload = data
                } else {
                    self.errorMessage = response.message.isEmptyString ? "Unable to load rider insights." : response.message
                }
            }
            .store(in: &cancellables)
    }

    func selectPreset(_ preset: RiderDatePreset) {
        selectedPreset = preset
        let range = preset.dateRange
        startDate = range.start
        endDate = range.end
        load()
    }

    func updateCustomDates(start: String, end: String) {
        startDate = start
        endDate = end
        load()
    }

    func selectRider(_ name: String) {
        selectedRiderName = name
    }

    func clearSelectedRider() {
        selectedRiderName = nil
    }

    // MARK: - Mapped Order Lists

    var statusMap: [Int: String] {
        var map: [Int: String] = [:]
        for item in payload?.orderStatusMap ?? [] {
            map[item.key] = item.label
        }
        return map
    }

    private func getStatusLabel(for statusKeyStr: String, defaultLabel: String = "Unknown") -> String {
        guard let key = Int(statusKeyStr) else { return defaultLabel }
        return statusMap[key] ?? defaultLabel
    }

    var deliveredOrders: [RiderOrderDisplayItem] {
        guard let data = payload else { return [] }
        return data.deliveredOrders.history.map { dto in
            RiderOrderDisplayItem(
                orderId: dto.orderId,
                totalPrice: Double(dto.totalPrice) ?? 0.0,
                orderStatusKey: 3,
                orderStatusLabel: "Delivered",
                riderName: dto.rider?.name.isEmptyString == false ? dto.rider!.name : "N/A",
                sellerName: dto.seller?.shopName.isEmptyString == false ? dto.seller!.shopName : "N/A",
                staffName: dto.staff?.name.isEmptyString == false ? dto.staff!.name : "N/A",
                distance: nil,
                address: nil,
                latitude: nil,
                longitude: nil
            )
        }
    }

    var allRidersOrders: [RiderOrderDisplayItem] {
        guard let data = payload else { return [] }
        return data.allRiders.history.map { dto in
            RiderOrderDisplayItem(
                orderId: dto.orderId,
                totalPrice: Double(dto.totalPrice) ?? 0.0,
                orderStatusKey: Int(dto.orderStatus) ?? -1,
                orderStatusLabel: self.getStatusLabel(for: dto.orderStatus, defaultLabel: "Order"),
                riderName: dto.rider?.name.isEmptyString == false ? dto.rider!.name : "N/A",
                sellerName: dto.seller?.shopName.isEmptyString == false ? dto.seller!.shopName : "N/A",
                staffName: dto.staff?.name.isEmptyString == false ? dto.staff!.name : "N/A",
                distance: nil,
                address: nil,
                latitude: nil,
                longitude: nil
            )
        }
    }

    var assignedRidersOrders: [RiderOrderDisplayItem] {
        guard let data = payload else { return [] }
        return data.assignedRiders.history.map { dto in
            RiderOrderDisplayItem(
                orderId: dto.orderId,
                totalPrice: Double(dto.totalPrice) ?? 0.0,
                orderStatusKey: Int(dto.orderStatus) ?? -1,
                orderStatusLabel: self.getStatusLabel(for: dto.orderStatus, defaultLabel: "Assigned"),
                riderName: dto.riderName ?? "N/A",
                sellerName: dto.shopName ?? "N/A",
                staffName: dto.salePersonName ?? "N/A",
                distance: dto.totalDistance,
                address: dto.riderCurrentAddress,
                latitude: dto.currentLat,
                longitude: dto.currentLng
            )
        }
    }

    var pickedUpRidersOrders: [RiderOrderDisplayItem] {
        guard let data = payload else { return [] }
        return data.pickedUpRiders.history.map { dto in
            RiderOrderDisplayItem(
                orderId: dto.orderId,
                totalPrice: Double(dto.totalPrice) ?? 0.0,
                orderStatusKey: Int(dto.orderStatus) ?? -1,
                orderStatusLabel: self.getStatusLabel(for: dto.orderStatus, defaultLabel: "Picked Up"),
                riderName: dto.riderName ?? "N/A",
                sellerName: dto.shopName ?? "N/A",
                staffName: dto.salePersonName ?? "N/A",
                distance: dto.totalDistance,
                address: dto.riderCurrentAddress,
                latitude: dto.currentLat,
                longitude: dto.currentLng
            )
        }
    }

    var activeRidersOrders: [RiderOrderDisplayItem] {
        guard let data = payload else { return [] }
        return data.activeRiders.history.map { dto in
            RiderOrderDisplayItem(
                orderId: dto.orderId,
                totalPrice: Double(dto.totalPrice) ?? 0.0,
                orderStatusKey: Int(dto.orderStatus) ?? -1,
                orderStatusLabel: self.getStatusLabel(for: dto.orderStatus, defaultLabel: "Active"),
                riderName: dto.riderName ?? "N/A",
                sellerName: dto.shopName ?? "N/A",
                staffName: dto.salePersonName ?? "N/A",
                distance: dto.totalDistance.isEmptyString ? "0" : dto.totalDistance,
                address: dto.riderCurrentAddress.isEmptyString ? "No address" : dto.riderCurrentAddress,
                latitude: dto.currentLat,
                longitude: dto.currentLng
            )
        }
    }

    var topRiders: [TopRiderItem] {
        guard let data = payload else { return [] }
        return data.topRiders.history.map { dto in
            TopRiderItem(
                riderId: dto.riderId,
                name: dto.riderName,
                totalDelivered: Int(dto.totalDelivered) ?? 0
            )
        }
    }

    // MARK: - KPI Statistics

    var deliveredCount: Int {
        payload?.deliveredOrders.count ?? deliveredOrders.count
    }

    var allOrdersCount: Int {
        payload?.allRiders.count ?? allRidersOrders.count
    }

    var assignedCount: Int {
        payload?.assignedRiders.count ?? assignedRidersOrders.count
    }

    var pickedUpCount: Int {
        payload?.pickedUpRiders.count ?? pickedUpRidersOrders.count
    }

    var activeCount: Int {
        payload?.activeRiders.count ?? activeRidersOrders.count
    }

    var topRidersCount: Int {
        payload?.topRiders.count ?? topRiders.count
    }

    var totalRidersCount: Int {
        let distinctRiders = Set(allRidersOrders.map { $0.riderName.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && $0 != "N/A" })
        return distinctRiders.count
    }

    var deliveryRatePercentage: Int {
        let total = allOrdersCount
        guard total > 0 else { return 0 }
        let delivered = deliveredCount
        return Int((Double(delivered) / Double(total)) * 100.0)
    }

    // MARK: - Filtered Orders for Tabs

    private func filterOrders(_ orders: [RiderOrderDisplayItem]) -> [RiderOrderDisplayItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return orders }
        return orders.filter { order in
            order.orderId.lowercased().contains(query) ||
            order.riderName.lowercased().contains(query) ||
            order.sellerName.lowercased().contains(query) ||
            order.staffName.lowercased().contains(query)
        }
    }

    var filteredAssignedOrders: [RiderOrderDisplayItem] {
        filterOrders(assignedRidersOrders)
    }

    var filteredPickedUpOrders: [RiderOrderDisplayItem] {
        filterOrders(pickedUpRidersOrders)
    }

    var filteredActiveOrders: [RiderOrderDisplayItem] {
        filterOrders(activeRidersOrders)
    }

    var filteredDeliveredOrders: [RiderOrderDisplayItem] {
        filterOrders(deliveredOrders)
    }

    // MARK: - Rider Reports Summary

    var allRidersSummary: [RiderSummaryItem] {
        let grouped = Dictionary(grouping: allRidersOrders, by: { $0.riderName.trimmingCharacters(in: .whitespacesAndNewlines) })
        return grouped
            .filter { !$0.key.isEmpty && $0.key != "N/A" }
            .map { (name, orders) in
                RiderSummaryItem(riderName: name, totalOrders: orders.count)
            }
            .sorted(by: { $0.totalOrders > $1.totalOrders })
    }

    var filteredRidersSummary: [RiderSummaryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allRidersSummary }
        return allRidersSummary.filter { $0.riderName.lowercased().contains(query) }
    }

    var selectedRiderProfile: RiderProfileItem? {
        guard let name = selectedRiderName else { return nil }
        let orders = allRidersOrders.filter { $0.riderName == name }
        let lastActive = activeRidersOrders.last(where: { $0.riderName == name })

        let delivered = orders.count { $0.orderStatusLabel.lowercased() == "delivered" }
        let totalVal = orders.reduce(0.0) { $0 + $1.totalPrice }

        return RiderProfileItem(
            name: name,
            totalOrders: orders.count,
            deliveredCount: delivered,
            totalAmount: totalVal,
            orders: orders,
            lastKnownAddress: lastActive?.address,
            lastKnownLatitude: lastActive?.latitude,
            lastKnownLongitude: lastActive?.longitude
        )
    }
}
