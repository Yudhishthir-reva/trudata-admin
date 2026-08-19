//
//  CreateOrderQuantityFields.swift
//  Truedata
//

import SwiftUI
import UIKit

struct SyncedKgPktQuantityFields: View {
    let weightInGrams: Double
    let quantity: Int
    var onQuantityChange: (Int) -> Void

    @State private var kgInput = ""
    @State private var packetInput = ""
    @State private var isKgFocused = false
    @State private var isPacketFocused = false

    var body: some View {
        HStack(spacing: 8) {
            if weightInGrams > 0 {
                CreateOrderQuantityField(
                    text: $kgInput,
                    label: "Kg",
                    keyboardType: .decimalPad,
                    onFocusChange: handleKgFocusChange,
                    onTextChange: handleKgInputChange
                )
            }

            CreateOrderQuantityField(
                text: $packetInput,
                label: "Pkt",
                keyboardType: .numberPad,
                onFocusChange: handlePacketFocusChange,
                onTextChange: handlePacketInputChange
            )
        }
        .onAppear { syncBothFieldsFromQuantity() }
        .onChange(of: quantity) { _, _ in
            if !isKgFocused && !isPacketFocused {
                syncBothFieldsFromQuantity()
            }
        }
    }

    private func handleKgFocusChange(_ focused: Bool) {
        isKgFocused = focused
        if !focused {
            finalizeKgInput()
        }
    }

    private func handlePacketFocusChange(_ focused: Bool) {
        isPacketFocused = focused
        if !focused {
            finalizePacketInput()
        }
    }

    private func syncBothFieldsFromQuantity() {
        kgInput = CreateOrderVariantParser.formattedKg(quantity: quantity, weightInGrams: weightInGrams)
        packetInput = quantity > 0 ? String(quantity) : ""
    }

    private func syncPacketFromQuantity(_ packets: Int) {
        guard !isPacketFocused else { return }
        packetInput = packets > 0 ? String(packets) : ""
    }

    private func syncKgFromQuantity(_ packets: Int) {
        guard !isKgFocused else { return }
        kgInput = CreateOrderVariantParser.formattedKg(quantity: packets, weightInGrams: weightInGrams)
    }

    private func finalizeKgInput() {
        guard let parsedKg = Double(kgInput), parsedKg >= 0 else {
            syncBothFieldsFromQuantity()
            return
        }

        if parsedKg == 0 {
            applyQuantity(0)
            return
        }

        guard weightInGrams > 0 else { return }
        let packets = CreateOrderVariantParser.packets(fromKg: parsedKg, weightInGrams: weightInGrams)
        applyQuantity(packets)
    }

    private func finalizePacketInput() {
        guard let parsed = Int(packetInput), parsed >= 0 else {
            syncBothFieldsFromQuantity()
            return
        }
        applyQuantity(parsed)
    }

    private func handleKgInputChange(_ newValue: String) {
        guard newValue.isEmpty || newValue.range(of: "^\\d*\\.?\\d*$", options: .regularExpression) != nil else {
            kgInput = CreateOrderVariantParser.formattedKg(quantity: quantity, weightInGrams: weightInGrams)
            return
        }

        if newValue.isEmpty {
            syncPacketFromQuantity(0)
            applyQuantity(0)
            return
        }

        guard let parsedKg = Double(newValue),
              parsedKg >= 0,
              parsedKg <= CreateOrderVariantParser.maxKgsLimit,
              weightInGrams > 0 else { return }

        let packets = CreateOrderVariantParser.packets(fromKg: parsedKg, weightInGrams: weightInGrams)
        syncPacketFromQuantity(packets)
        applyQuantity(packets)
    }

    private func handlePacketInputChange(_ newValue: String) {
        guard newValue.isEmpty || newValue.range(of: "^\\d*$", options: .regularExpression) != nil else {
            packetInput = quantity > 0 ? String(quantity) : ""
            return
        }

        if newValue.isEmpty {
            syncKgFromQuantity(0)
            applyQuantity(0)
            return
        }

        guard let parsed = Int(newValue),
              parsed >= 0,
              parsed <= CreateOrderVariantParser.maxPacketsLimit else { return }

        syncKgFromQuantity(parsed)
        applyQuantity(parsed)
    }

    private func applyQuantity(_ packets: Int) {
        let clamped = max(0, min(packets, CreateOrderVariantParser.maxPacketsLimit))
        guard clamped != quantity else { return }
        onQuantityChange(clamped)
    }
}

struct CreateOrderQuantityField: View {
    @Binding var text: String
    let label: String
    let keyboardType: UIKeyboardType
    let onFocusChange: (Bool) -> Void
    let onTextChange: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            TextField("0", text: $text)
                .keyboardType(keyboardType)
                .font(.system(size: 15, weight: .medium))
                .multilineTextAlignment(.leading)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    onTextChange(newValue)
                }
                .onChange(of: isFocused) { _, focused in
                    onFocusChange(focused)
                }

            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DashboardTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity)
    }
}
