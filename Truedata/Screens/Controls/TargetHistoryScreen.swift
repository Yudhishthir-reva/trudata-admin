//
//  TargetHistoryScreen.swift
//  Truedata
//

import SwiftUI

struct TargetHistoryScreen: View {

    let targetId: Int
    let staffName: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TargetHistoryViewModel()
    @State private var showCelebration = false

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "\(staffName)'s Target History",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load(targetId: targetId) }
                )

                content
            }

            if showCelebration {
                BalloonCelebrationView(style: .fullScreen, duration: 3.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showCelebration = false
                    }
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load(targetId: targetId) }
        .onChange(of: viewModel.target) { _, target in
            if target?.status == .complete {
                showCelebration = true
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.target == nil {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.target == nil {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.load(targetId: targetId)
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let target = viewModel.target {
            ScrollView {
                VStack(spacing: 0) {
                    TargetHistoryHeroSection(target: target, staffName: staffName)

                    VStack(alignment: .leading, spacing: 12) {
                        TargetContributingOrdersHeader(count: viewModel.orders.count)

                        if viewModel.orders.isEmpty {
                            TargetHistoryEmptyOrdersView()
                        } else {
                            ForEach(viewModel.orders) { order in
                                NavigationLink {
                                    OrderDetailScreen(orderId: order.orderId)
                                } label: {
                                    TargetHistoryOrderRow(order: order)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

private struct TargetHistoryEmptyOrdersView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(DashboardTheme.surfaceVariant)
            Text("No contributing orders found.")
                .font(.system(size: 15))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
