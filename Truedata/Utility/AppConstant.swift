//
//  AppConstant.swift
//  Truedata
//

import Foundation

enum APIBaseURL {
    static let production = "https://spicemonk.in/965874/api/"
    static let staging = "https://spicemonk.trudataa.com/api"
}

/// Sirf yahi line badlo: `.production` ya `.stagging`
let currentEnvironment: RequestEnvironmentType = .stagging

let BASE_URL: String = {
    switch currentEnvironment {
    case .stagging:
        return APIBaseURL.staging
    case .production:
        return APIBaseURL.production
    }
}()

let kDateFormatterHHMMA: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "hh:mm a"
    return dateFormatter
}()

let kDateFormatterDDMMYYYY: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "dd-MM-yyyy"
    return dateFormatter
}()

let kDateFormatterDDMMYYYYss: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return dateFormatter
}()
