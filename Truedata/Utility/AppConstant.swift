//
//  AppConstant.swift
//  Truedata
//

import Foundation

enum APIBaseURL {
    static let production = "https://spicemonk.in/965874/api/"
    static let staging = "https://spicemonk.in/965874/api/"
}

let BASE_URL = APIBaseURL.staging

let currentEnvironment: RequestEnvironmentType = .stagging

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
