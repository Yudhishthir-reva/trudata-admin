//
//  ProductCalculatorScreen.swift
//  Truedata
//

import SwiftUI

private enum ProductCalculatorTab: String, CaseIterable {
    case margin = "Margin"
    case gst = "GST"
}

private enum MarginField: CaseIterable {
    case mrp
    case ptr
    case margin
}

private enum GSTField: CaseIterable {
    case gstPercent
    case ptrInclusive
    case valueExclusive
}

struct ProductCalculatorScreen: View {

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ProductCalculatorTab = .margin

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))

            VStack(spacing: 0) {
                header
                tabBar

                switch selectedTab {
                case .margin:
                    MarginCalculatorView()
                case .gst:
                    GSTCalculatorView()
                }
            }
            .background(Color(hex: "F8FAFC"))
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "2196F3").opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "function")
                    .foregroundStyle(Color(hex: "2196F3"))
            }
            Text("Calculator")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProductCalculatorTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                        .foregroundStyle(selectedTab == tab ? Color(hex: "2196F3") : DashboardTheme.neutralMedium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(alignment: .bottom) {
                            if selectedTab == tab {
                                Capsule()
                                    .fill(Color(hex: "2196F3"))
                                    .frame(width: 72, height: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }
}

private struct MarginCalculatorView: View {
    @State private var mrp = ""
    @State private var ptr = ""
    @State private var margin = ""
    @State private var focusedField: MarginField = .mrp
    @State private var anchorField: MarginField?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                CalculatorInputCard(
                    label: "MRP",
                    value: mrp,
                    isActive: focusedField == .mrp,
                    isCalculated: calculatedField == .mrp
                ) { focusedField = .mrp; updateAnchor() }

                CalculatorInputCard(
                    label: "PTR (Retailer Price)",
                    value: ptr,
                    isActive: focusedField == .ptr,
                    isCalculated: calculatedField == .ptr
                ) { focusedField = .ptr; updateAnchor() }

                CalculatorInputCard(
                    label: "Margin %",
                    value: margin,
                    isActive: focusedField == .margin,
                    isCalculated: calculatedField == .margin
                ) { focusedField = .margin; updateAnchor() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)

            Spacer(minLength: 0)

            CalculatorKeypad(onKeyPress: handleKeyPress)
        }
    }

    private var calculatedField: MarginField? {
        guard let anchorField, focusedField != anchorField else { return nil }
        return MarginField.allCases.first { $0 != focusedField && $0 != anchorField }
    }

    private func updateAnchor() {
        switch focusedField {
        case .mrp where !mrp.isEmpty: anchorField = .mrp
        case .ptr where !ptr.isEmpty: anchorField = .ptr
        case .margin where !margin.isEmpty: anchorField = .margin
        default: break
        }
    }

    private func handleKeyPress(_ key: String) {
        if key == "C" {
            mrp = ""
            ptr = ""
            margin = ""
            focusedField = .mrp
            anchorField = nil
            return
        }

        var current = value(for: focusedField)
        if key == "DEL" {
            if !current.isEmpty { current.removeLast() }
        } else if key == "." {
            if !current.contains(".") { current += "." }
        } else if current.count < 9 {
            current += key
        }

        setValue(current, for: focusedField)
        recalculate()
    }

    private func value(for field: MarginField) -> String {
        switch field {
        case .mrp: return mrp
        case .ptr: return ptr
        case .margin: return margin
        }
    }

    private func setValue(_ value: String, for field: MarginField) {
        switch field {
        case .mrp: mrp = value
        case .ptr: ptr = value
        case .margin: margin = value
        }
    }

    private func recalculate() {
        guard let calculatedField else { return }
        let dMrp = Double(mrp)
        let dPtr = Double(ptr)
        let dMargin = Double(margin)

        switch calculatedField {
        case .margin:
            if let dMrp, let dPtr, dMrp != 0 {
                margin = formatNumber(((dMrp - dPtr) / dMrp) * 100)
            } else {
                margin = ""
            }
        case .ptr:
            if let dMrp, let dMargin {
                ptr = formatNumber(dMrp * (1 - (dMargin / 100)))
            } else {
                ptr = ""
            }
        case .mrp:
            if let dPtr, let dMargin, dMargin != 100 {
                mrp = formatNumber(dPtr / (1 - (dMargin / 100)))
            } else {
                mrp = ""
            }
        }
    }

    private func formatNumber(_ value: Double) -> String {
        let formatted = String(format: "%.2f", value)
        if formatted.hasSuffix(".00") { return String(formatted.dropLast(3)) }
        if formatted.hasSuffix("0") { return String(formatted.dropLast()) }
        return formatted
    }
}

private struct GSTCalculatorView: View {
    @State private var gstPercent = ""
    @State private var ptrInclusive = ""
    @State private var valueExclusive = ""
    @State private var focusedField: GSTField = .gstPercent
    @State private var anchorField: GSTField?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                CalculatorInputCard(
                    label: "GST %",
                    value: gstPercent,
                    isActive: focusedField == .gstPercent,
                    isCalculated: calculatedField == .gstPercent
                ) { focusedField = .gstPercent; updateAnchor() }

                CalculatorInputCard(
                    label: "PTR (Price to Retailer)",
                    value: ptrInclusive,
                    isActive: focusedField == .ptrInclusive,
                    isCalculated: calculatedField == .ptrInclusive
                ) { focusedField = .ptrInclusive; updateAnchor() }

                CalculatorInputCard(
                    label: "Value (Without GST)",
                    value: valueExclusive,
                    isActive: focusedField == .valueExclusive,
                    isCalculated: calculatedField == .valueExclusive
                ) { focusedField = .valueExclusive; updateAnchor() }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)

            Spacer(minLength: 0)

            CalculatorKeypad(onKeyPress: handleKeyPress)
        }
    }

    private var calculatedField: GSTField? {
        guard let anchorField, focusedField != anchorField else { return nil }
        return GSTField.allCases.first { $0 != focusedField && $0 != anchorField }
    }

    private func updateAnchor() {
        switch focusedField {
        case .gstPercent where !gstPercent.isEmpty: anchorField = .gstPercent
        case .ptrInclusive where !ptrInclusive.isEmpty: anchorField = .ptrInclusive
        case .valueExclusive where !valueExclusive.isEmpty: anchorField = .valueExclusive
        default: break
        }
    }

    private func handleKeyPress(_ key: String) {
        if key == "C" {
            gstPercent = ""
            ptrInclusive = ""
            valueExclusive = ""
            focusedField = .gstPercent
            anchorField = nil
            return
        }

        var current = value(for: focusedField)
        if key == "DEL" {
            if !current.isEmpty { current.removeLast() }
        } else if key == "." {
            if !current.contains(".") { current += "." }
        } else if current.count < 9 {
            current += key
        }

        setValue(current, for: focusedField)
        recalculate()
    }

    private func value(for field: GSTField) -> String {
        switch field {
        case .gstPercent: return gstPercent
        case .ptrInclusive: return ptrInclusive
        case .valueExclusive: return valueExclusive
        }
    }

    private func setValue(_ value: String, for field: GSTField) {
        switch field {
        case .gstPercent: gstPercent = value
        case .ptrInclusive: ptrInclusive = value
        case .valueExclusive: valueExclusive = value
        }
    }

    private func recalculate() {
        guard let calculatedField else { return }
        let dGst = Double(gstPercent)
        let dPtr = Double(ptrInclusive)
        let dValue = Double(valueExclusive)

        switch calculatedField {
        case .valueExclusive:
            if let dPtr, let dGst {
                valueExclusive = formatNumber(dPtr / (1 + (dGst / 100)))
            } else {
                valueExclusive = ""
            }
        case .ptrInclusive:
            if let dValue, let dGst {
                ptrInclusive = formatNumber(dValue * (1 + (dGst / 100)))
            } else {
                ptrInclusive = ""
            }
        case .gstPercent:
            if let dPtr, let dValue, dValue != 0 {
                gstPercent = formatNumber(((dPtr - dValue) / dValue) * 100)
            } else {
                gstPercent = ""
            }
        }
    }

    private func formatNumber(_ value: Double) -> String {
        let formatted = String(format: "%.2f", value)
        if formatted.hasSuffix(".00") { return String(formatted.dropLast(3)) }
        if formatted.hasSuffix("0") { return String(formatted.dropLast()) }
        return formatted
    }
}

private struct CalculatorInputCard: View {
    let label: String
    let value: String
    let isActive: Bool
    let isCalculated: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isActive ? Color(hex: "2196F3") : DashboardTheme.neutralMedium)
                    Text(value.isEmpty ? "0" : value)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(value.isEmpty ? DashboardTheme.neutralMedium.opacity(0.5) : DashboardTheme.neutralDark)
                }
                Spacer()
                if isCalculated {
                    Text("Auto")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DashboardTheme.successGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DashboardTheme.successGreen.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 85, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isActive ? Color(hex: "2196F3") : (isCalculated ? DashboardTheme.successGreen : Color.clear),
                        lineWidth: 2
                    )
            }
            .shadow(color: .black.opacity(isActive ? 0.08 : 0.04), radius: isActive ? 8 : 2, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct CalculatorKeypad: View {
    let onKeyPress: (String) -> Void

    private let rows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "DEL"]
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Button(action: { onKeyPress("C") }) {
                    Text("CLEAR ALL")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DashboardTheme.dangerRed)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }

            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        Button(action: { onKeyPress(key) }) {
                            Group {
                                if key == "DEL" {
                                    Image(systemName: "delete.left")
                                        .font(.system(size: 18))
                                        .foregroundStyle(DashboardTheme.neutralMedium)
                                } else {
                                    Text(key)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(DashboardTheme.neutralDark)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DashboardTheme.neutralMedium.opacity(0.12), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color(hex: "2196F3").opacity(0.08), radius: 16, y: -4)
    }
}
