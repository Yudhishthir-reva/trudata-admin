//
//  UserDefaultManager.swift
//  Truedata
//

import Foundation

class UserDefaultManager {

    static let shared = UserDefaultManager()

    enum PersistenceKeys: String {
        case userId
        case userMobile
        case userName
        case userRole
        case authToken
        case refreshToken
        case tokenExpiry
        case locationServiceEnabled
        case isUserWorking
        case locationUpdateInterval
        case locationPriority
    }

    func setUserDefaultsString(value: String, key: PersistenceKeys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
        UserDefaults.standard.synchronize()
    }

    func setUserDefaultsBool(value: Bool, key: PersistenceKeys) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
        UserDefaults.standard.synchronize()
    }

    func getUserDefaultsString(key: PersistenceKeys) -> String {
        UserDefaults.standard.value(forKey: key.rawValue) as? String ?? ""
    }

    func getUserDefaultsBool(key: PersistenceKeys) -> Bool {
        UserDefaults.standard.value(forKey: key.rawValue) as? Bool ?? false
    }

    func setTokenExpiry(secondsFromNow: Int?) {
        guard let secondsFromNow, secondsFromNow > 0 else {
            UserDefaults.standard.removeObject(forKey: PersistenceKeys.tokenExpiry.rawValue)
            return
        }
        let expiry = Date().addingTimeInterval(TimeInterval(secondsFromNow))
        UserDefaults.standard.set(expiry.timeIntervalSince1970, forKey: PersistenceKeys.tokenExpiry.rawValue)
    }

    var tokenExpiry: Date? {
        let stored = UserDefaults.standard.double(forKey: PersistenceKeys.tokenExpiry.rawValue)
        guard stored > 0 else { return nil }
        return Date(timeIntervalSince1970: stored)
    }

    var isUserLoggedIn: Bool {
        !getUserDefaultsString(key: .authToken).isEmptyString
    }

    var authHeader: RequestConstants.Header {
        let token = getUserDefaultsString(key: .authToken)
        guard !token.isEmptyString else { return [:] }
        return ["Authorization": "Bearer \(token)"]
    }

    func resetUserData() {
        setUserDefaultsString(value: "", key: .userId)
        setUserDefaultsString(value: "", key: .userMobile)
        setUserDefaultsString(value: "", key: .userName)
        setUserDefaultsString(value: "", key: .userRole)
        setUserDefaultsString(value: "", key: .authToken)
        setUserDefaultsString(value: "", key: .refreshToken)
        setTokenExpiry(secondsFromNow: nil)
        setUserDefaultsBool(value: false, key: .locationServiceEnabled)
        setUserDefaultsBool(value: false, key: .isUserWorking)
        setUserDefaultsString(value: "", key: .locationUpdateInterval)
        setUserDefaultsString(value: "", key: .locationPriority)
    }

    func updateLocationConfig(_ config: LocationConfigData) {
        setUserDefaultsBool(value: config.serviceEnabled, key: .locationServiceEnabled)
        setUserDefaultsBool(value: config.isUserWorking, key: .isUserWorking)
        setUserDefaultsString(value: config.updateIntervalSeconds, key: .locationUpdateInterval)
        setUserDefaultsString(value: config.priority, key: .locationPriority)
    }

    var isLocationTrackingNeeded: Bool {
        getUserDefaultsBool(key: .locationServiceEnabled) && getUserDefaultsBool(key: .isUserWorking)
    }
}
