//
//  EditSpecialPricesSheet.swift
//  Truedata
//

import SwiftUI

struct EditSpecialPricesSheet: View {

    let variants: [ActiveProductVariant]
    let isSaving: Bool
    let onCancel: () -> Void
    let onSave: ([Int: String]) -> Void

    @State private var specialPrices: [Int: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(variants.enumerated()), id: \.element.id) { index, variant in
                        VStack(spacing: 12) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(variant.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(DashboardTheme.neutralDark)

                                    Text("Retail: ₹\(variant.priceValue.formattedPrice)")
                                        .font(.system(size: 13))
                                        .foregroundStyle(DashboardTheme.neutralMedium)
                                }

                                Spacer(minLength: 8)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Special Price")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(DashboardTheme.neutralMedium)

                                    TextField("", text: binding(for: variant.id))
                                        .keyboardType(.decimalPad)
                                        .font(.system(size: 15))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
                                        }
                                        .frame(width: 110)
                                }
                            }

                            if index < variants.count - 1 {
                                Divider()
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Edit Special Prices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            onSave(specialPrices)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func binding(for variantID: Int) -> Binding<String> {
        Binding(
            get: { specialPrices[variantID] ?? "" },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber || $0 == "." }
                specialPrices[variantID] = filtered
            }
        )
    }
}

private extension Double {
    var formattedPrice: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }
}
