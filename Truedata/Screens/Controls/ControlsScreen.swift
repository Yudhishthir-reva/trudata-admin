//
//  ControlsScreen.swift
//  Truedata
//

import SwiftUI

struct ControlsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ControlsViewModel()
    @State private var pendingRouteMessage: String?

    var onNavigate: (String) -> Void = { _ in }

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
                    title: "Controls",
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
        if viewModel.isLoading && viewModel.employeePayload == nil {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.employeePayload == nil {
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
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    ControlsMenuCard(title: viewModel.controlsTitle, onNavigate: handleRoute)

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                        spacing: 16
                    ) {
                        ControlsApprovalCard(
                            kind: .leave,
                            todayCount: viewModel.todayLeaveCount,
                            pendingCount: viewModel.pendingLeaveCount,
                            onTap: { handleRoute("leave_approval") }
                        )

                        ControlsApprovalCard(
                            kind: .regularize,
                            todayCount: viewModel.todayRegularizeCount,
                            pendingCount: viewModel.pendingRegularizeCount,
                            onTap: { handleRoute("regularize_approval") }
                        )

                        ControlsApprovalCard(
                            kind: .expense,
                            todayCount: viewModel.todayExpenseCount,
                            pendingCount: viewModel.pendingExpenseCount,
                            onTap: { handleRoute("expense_approval") }
                        )

                        ControlsReportCard(
                            title: "Staff Report",
                            total: viewModel.totalStaff,
                            present: viewModel.presentStaff,
                            absent: viewModel.absentStaff,
                            onViewReport: { handleRoute("staff_report") }
                        )

                        ControlsReportCard(
                            title: "Rider Report",
                            total: viewModel.totalRider,
                            present: viewModel.presentRider,
                            absent: viewModel.absentRider,
                            onViewReport: { handleRoute("rider_report") }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
    }

    private func handleRoute(_ route: String) {
        switch route {
        case "manage_logins", "new_device_login_requests", "login_requests":
            onNavigate("new_device_login_requests")
        case "seller_report":
            onNavigate("seller_report")
        case "register_staff_member", "add_new_staff_member":
            onNavigate(route)
        case "view_vehicles":
            onNavigate("view_vehicles")
        case "view_beats":
            onNavigate("view_beats")
        case "view_targets":
            onNavigate("view_targets")
        case "view_beat_summary":
            onNavigate("view_beat_summary")
        case "assignment_history":
            onNavigate("assignment_history")
        case "leave_approval":
            onNavigate("leave_approval")
        case "regularize_approval":
            onNavigate("regularize_approval")
        case "staff_report":
            onNavigate("staff_report")
        case "expense_approval":
            onNavigate("expense_approval")
        case "rider_report":
            pendingRouteMessage = "\(route.replacingOccurrences(of: "_", with: " ").capitalized) will be available in the next update."
        default:
            onNavigate(route)
        }
    }
}
