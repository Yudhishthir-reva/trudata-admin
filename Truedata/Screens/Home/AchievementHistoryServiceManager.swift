//
//  AchievementHistoryServiceManager.swift
//  Truedata
//

import Foundation
import Combine

class AchievementHistoryServiceManager {

    var networkService: NetworkServiceManagable

    init(networkService: NetworkServiceManagable = NetworkServiceManager.shared) {
        self.networkService = networkService
    }

    private var authHeaders: RequestConstants.Header {
        UserDefaultManager.shared.authHeader
    }

    func fetchAchievementHistory(
        startDate: String,
        endDate: String
    ) -> AnyPublisher<AchievementHistoryResponse, Error> {
        networkService.request(
            APIRouter.todayAchievementsDetails,
            params: [
                "start_date": startDate,
                "end_date": endDate
            ],
            headers: authHeaders
        )
    }
}
