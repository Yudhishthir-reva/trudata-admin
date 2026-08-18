//
//  HomePrefetchStore.swift
//  Truedata
//

import Foundation

final class HomePrefetchStore {

    static let shared = HomePrefetchStore()

    var areas: StartNewOrderAllAreaResponse?
    var staffList: OrderInsightsStaffListResponse?
    var locationConfig: LocationConfigResponse?

    private init() {}

    func clear() {
        areas = nil
        staffList = nil
        locationConfig = nil
    }
}
