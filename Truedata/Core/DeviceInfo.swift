//
//  DeviceInfo.swift
//  Truedata
//

import Foundation
import UIKit

struct DeviceInfo: Encodable {
    let appVersion: String
    let buildNo: String
    let deviceModel: String
    let androidVersion: String
    let device: String
    let cpu: String
    let hardware: String
    let deviceId: String
    let buildType: String

    static func current() -> DeviceInfo {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "N/A"
        let build = info?["CFBundleVersion"] as? String ?? "N/A"
        #if DEBUG
        let buildType = "Debug"
        #else
        let buildType = "Release"
        #endif

        return DeviceInfo(
            appVersion: version,
            buildNo: build,
            deviceModel: UIDevice.current.model,
            androidVersion: "iOS \(UIDevice.current.systemVersion)",
            device: UIDevice.current.name,
            cpu: "arm64",
            hardware: UIDevice.current.systemName,
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            buildType: buildType
        )
    }

    var jsonString: String {
        guard let data = try? JSONEncoder().encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
}
