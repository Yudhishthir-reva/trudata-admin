//
//  AppConstant.swift
//  Truedata
//

import Foundation

enum APIBaseURL {
    static let production = "https://trudataa.com/864963/api/"
    static let staging = "https://spicemonk.revateam.com/api/"
}

let BASE_URL = APIBaseURL.production

let currentEnvironment: RequestEnvironmentType = .production

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
