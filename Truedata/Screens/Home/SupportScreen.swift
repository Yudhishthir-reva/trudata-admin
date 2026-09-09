//
//  SupportScreen.swift
//  Truedata
//

import SwiftUI

struct SupportScreen: View {

    @Environment(\.dismiss) private var dismiss

    let salesPhoneNumber: String
    let riderPhoneNumber: String

    @State private var callError: String?

    var body: some View {
        VStack(spacing: 0) {
            SellersAppBar(
                title: "Support",
                onBack: { dismiss() },
                onHome: { dismiss() },
                onRefresh: {}
            )

            ScrollView {
                VStack(spacing: 16) {
                    SupportContactCard(
                        title: "Sales Support",
                        subtitle: "For order issues, billing queries, and general support",
                        phoneNumber: displayPhone(salesPhoneNumber),
                        background: Color(hex: "E8F5E8"),
                        accent: Color(hex: "2E7D32"),
                        onCall: { dial(salesPhoneNumber) }
                    )

                    SupportContactCard(
                        title: "Rider Support",
                        subtitle: "For delivery issues, rider assistance, and logistics",
                        phoneNumber: displayPhone(riderPhoneNumber),
                        background: Color(hex: "FFF3E0"),
                        accent: Color(hex: "E65100"),
                        onCall: { dial(riderPhoneNumber) }
                    )

                    Text("These numbers are for business emergencies and support only. Please use responsibly.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "C62828"))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "FFEBEE"))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(16)
            }
            .background(DashboardTheme.surface)
        }
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
        .toolbar(.hidden, for: .navigationBar)
        .alert("Unable to Call", isPresented: Binding(
            get: { callError != nil },
            set: { if !$0 { callError = nil } }
        )) {
            Button("OK", role: .cancel) { callError = nil }
        } message: {
            Text(callError ?? "")
        }
    }

    private func displayPhone(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "N/A" : trimmed
    }

    private func dial(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.uppercased() != "N/A", trimmed.uppercased() != "NA" else {
            callError = "Phone number is not available."
            return
        }
        SellerContactActions.call(trimmed) { result in
            if case .failure(let error) = result {
                callError = error.localizedDescription
            }
        }
    }
}

private struct SupportContactCard: View {
    let title: String
    let subtitle: String
    let phoneNumber: String
    let background: Color
    let accent: Color
    var onCall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(accent)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "666666"))

            Button(action: onCall) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phoneNumber)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "212121"))
                        Text("Tap to call")
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    Spacer()
                    Image(systemName: "phone.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.85))
                        .clipShape(Circle())
                }
                .padding(12)
                .background(Color.white.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}
