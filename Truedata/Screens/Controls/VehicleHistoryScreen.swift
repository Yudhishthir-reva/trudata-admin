//
//  VehicleHistoryScreen.swift
//  Truedata
//

import SwiftUI

struct VehicleHistoryScreen: View {

    let vehicleId: Int

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VehicleHistoryViewModel()

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Vehicle History",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load(vehicleId: vehicleId) }
                )

                content
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load(vehicleId: vehicleId) }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.logs.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.logs.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.load(vehicleId: vehicleId)
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let vehicle = viewModel.vehicle {
                        VehicleHistoryHeaderCard(vehicle: vehicle)
                    }

                    Text("Assignment Logs")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)

                    if viewModel.logs.isEmpty {
                        Text("No history found for this vehicle.")
                            .font(.system(size: 14))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(Array(viewModel.logs.enumerated()), id: \.element.id) { index, log in
                            VehicleHistoryLogRow(
                                log: log,
                                isLast: index == viewModel.logs.count - 1
                            )
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}
