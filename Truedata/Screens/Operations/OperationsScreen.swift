//
//  OperationsScreen.swift
//  Truedata
//

import SwiftUI

struct OperationsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OperationsViewModel
    @State private var pendingRouteMessage: String?

    var onNavigate: (String) -> Void

    init(screenType: OperationsScreenType, onNavigate: @escaping (String) -> Void = { _ in }) {
        _viewModel = StateObject(wrappedValue: OperationsViewModel(screenType: screenType))
        self.onNavigate = onNavigate
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "DEE6F8"), Color(hex: "E7EBEF")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: viewModel.screenType.title,
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load() }
                )

                content
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load() }
        .alert("Notice", isPresented: pendingRouteBinding) {
            Button("OK", role: .cancel) { pendingRouteMessage = nil }
        } message: {
            Text(pendingRouteMessage ?? "")
        }
    }

    private var pendingRouteBinding: Binding<Bool> {
        Binding(
            get: { pendingRouteMessage != nil },
            set: { if !$0 { pendingRouteMessage = nil } }
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.load()
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.items.isEmpty {
            Text("No items available for this section.")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                if viewModel.screenType == .seller {
                    SellerOperationsGrid(
                        sellersTile: viewModel.items.first { $0.route == "registered_sellers" },
                        productsTile: viewModel.items.first { $0.route == "view_products" },
                        onNavigate: handleRoute
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                } else if viewModel.screenType == .activity {
                    ActivityOperationsContent(
                        tile: viewModel.items.first { $0.route == "today_achievements" },
                        onViewDetails: { handleRoute("today_achievements") }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(viewModel.items) { tile in
                            OperationsActionCard(
                                content: OperationsCardContent.make(from: tile),
                                onAction: { handleRoute(tile.route) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private func handleRoute(_ route: String) {
        switch route {
        case "registered_sellers", "view_products", "today_achievements", "attendance",
             "mark_attendance", "regularization_requests", "view_leaves", "add_new_sellers",
             "controls", "manage_employees", "staff_report", "rider_report",
             "expense_approval", "apply_reimbursements":
            onNavigate(route)
        default:
            pendingRouteMessage = "\(route.replacingOccurrences(of: "_", with: " ").capitalized) will be available in the next update."
        }
    }
}

private struct OperationsActionCard: View {
    let content: OperationsCardContent
    var onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DashboardTheme.primaryBlue, DashboardTheme.secondaryPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 4, height: 4)
                Text(content.tile.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            VStack(spacing: 6) {
                Image(systemName: content.iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(content.iconColor)
                Text(content.statusText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(content.statusColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 12)

            Button(action: onAction) {
                HStack(spacing: 4) {
                    Text(content.actionTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardTheme.primaryBlue.opacity(0.08), lineWidth: 1)
        }
    }
}
