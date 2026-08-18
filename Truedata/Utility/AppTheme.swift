//
//  AppTheme.swift
//  Truedata
//

import SwiftUI

enum AppTheme {
    static let darkMidnightBlue = Color(hex: "002B45")
    static let cerulean = Color(hex: "005273")
    static let aliceBlue = Color(hex: "F0F8FF")
    static let blue = Color(hex: "0077B6")
    static let silver = Color(hex: "9CA3AF")
    static let gainsboro = Color(hex: "D1D5DB")
    static let whiteSmoke = Color(hex: "F5F5F5")
    static let slateGray = Color(hex: "6B7280")
    static let logoCyan = Color(hex: "29ABE2")
    static let splashBackground = Color(hex: "002B45")
    static let authHeader = Color(hex: "0F2C42")
    static let authGrid = Color(hex: "1A4668")

    static let errorRed = Color(hex: "DC2626")
    static let errorRedBg = Color(hex: "FFF1F2")
    static let errorRedText = Color(hex: "7F1D1D")

    static let brandBackgroundTop = Color(hex: "DEE6F8")
    static let brandBackgroundMid = Color(hex: "E7EBEF")
    static let brandBackgroundBottom = Color(hex: "E7EBEF")

    static let brandRed = darkMidnightBlue
    static let brandRedDark = Color(hex: "001C2E")
    static let ctaGradient = LinearGradient(
        colors: [darkMidnightBlue, Color(hex: "14446A")],
        startPoint: .top,
        endPoint: .bottom
    )

    static let textPrimary = Color(hex: "1C2B3A")
    static let textSecondary = slateGray
    static let textMuted = silver

    static let fieldBackground = whiteSmoke
    static let fieldBorder = gainsboro
    static let fieldDivider = gainsboro

    static let homeCanvas = Color.white
    static let homeHeaderTop = darkMidnightBlue
    static let homeHeaderBottom = Color(hex: "14446A")
    static let imageTile = Color(hex: "EEF3F8")
}
