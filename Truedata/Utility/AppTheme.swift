//
//  AppTheme.swift
//  Truedata
//

import SwiftUI

enum AppTheme {
    /// Matches Android `USE_GREEN_THEME = true` Brand palette (SpiceMonk green).
    static let useGreenTheme = true

    // Brand tokens — under green these keep their historical names but resolve to forest greens
    // (same pattern as Android `DarkMidnightBlue` / `Cerulean` / `AliceBlue` / `Blue`).
    static let darkMidnightBlue = Color(hex: useGreenTheme ? "0E4A28" : "002B45")
    static let cerulean = Color(hex: useGreenTheme ? "167444" : "005273")
    static let aliceBlue = Color(hex: useGreenTheme ? "FFFFFF" : "F0F8FF")
    static let blue = Color(hex: useGreenTheme ? "1E8A52" : "0077B6")
    static let brandContainer = Color(hex: useGreenTheme ? "E8F5EE" : "F0F8FF")
    static let brandBorder = Color(hex: useGreenTheme ? "14311F" : "1A2436")

    static let silver = Color(hex: "9CA3AF")
    static let gainsboro = Color(hex: "D1D5DB")
    static let whiteSmoke = Color(hex: "F5F5F5")
    static let slateGray = Color(hex: "6B7280")
    static let logoCyan = Color(hex: useGreenTheme ? "1E8A52" : "29ABE2")
    static let splashBackground = darkMidnightBlue
    static let authHeader = Color(hex: useGreenTheme ? "0F2E1E" : "0F2C42")
    static let authGrid = Color(hex: useGreenTheme ? "1A5636" : "1A4668")

    static let errorRed = Color(hex: "DC2626")
    static let errorRedBg = Color(hex: "FFF1F2")
    static let errorRedText = Color(hex: "7F1D1D")

    static let brandBackgroundTop = Color(hex: useGreenTheme ? "FFFFFF" : "DEE6F8")
    static let brandBackgroundMid = Color(hex: useGreenTheme ? "F7F9F8" : "E7EBEF")
    static let brandBackgroundBottom = Color(hex: useGreenTheme ? "F7F9F8" : "E7EBEF")

    static let brandRed = darkMidnightBlue
    static let brandRedDark = Color(hex: useGreenTheme ? "0A331C" : "001C2E")
    static let ctaGradient = LinearGradient(
        colors: [
            darkMidnightBlue,
            Color(hex: useGreenTheme ? "1D8750" : "14446A")
        ],
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
    static let homeHeaderBottom = Color(hex: useGreenTheme ? "1D8750" : "14446A")
    static let imageTile = Color(hex: useGreenTheme ? "E8F5EE" : "EEF3F8")

    static let heroTop = Color(hex: useGreenTheme ? "0E4A28" : "00203A")
    static let heroMid = Color(hex: useGreenTheme ? "167444" : "0B4A72")
    static let heroBottom = Color(hex: useGreenTheme ? "1D8750" : "0E7490")
    static let heroGlow = Color(hex: useGreenTheme ? "34D399" : "22D3EE")
}
