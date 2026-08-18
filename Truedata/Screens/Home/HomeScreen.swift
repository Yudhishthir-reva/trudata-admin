//
//  HomeScreen.swift
//  Truedata
//

import SwiftUI
import Combine

enum HomeDestination: Hashable {
    case assignOrder
    case approveBills
    case orderApproval
    case viewPendingBills(sellerId: Int, staffId: Int, sellerName: String)
    case orderInsights(startDate: String, endDate: String)
    case startNewOrder
}

struct HomeScreen: View {

    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var showLogoutDialog = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            homeContent
                .navigationDestination(for: HomeDestination.self) { destination in
                    switch destination {
                    case .assignOrder:
                        AssignOrderScreen()
                    case .approveBills:
                        ApproveBillsScreen()
                    case .orderApproval:
                        OrderApprovalScreen { item in
                            navigationPath.append(
                                HomeDestination.viewPendingBills(
                                    sellerId: item.sellerId,
                                    staffId: item.staffId,
                                    sellerName: item.shopName
                                )
                            )
                        }
                    case .viewPendingBills(let sellerId, let staffId, let sellerName):
                        ViewPendingBillsScreen(
                            sellerId: sellerId,
                            staffId: staffId,
                            sellerName: sellerName
                        )
                    case .orderInsights(let startDate, let endDate):
                        OrderInsightsScreen(startDate: startDate, endDate: endDate)
                    case .startNewOrder:
                        StartNewOrderScreen()
                    }
                }
        }
    }

    private var homeContent: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "DEE6F8"), Color(hex: "E7EBEF")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if permissionManager.canShowDashboard {
                VStack(spacing: 0) {
                    HomeAppBar(
                        title: viewModel.screenTitle,
                        role: viewModel.role,
                        profileUrl: viewModel.profileUrl,
                        onRefresh: { viewModel.loadHome(isRefresh: true) },
                        onLogout: { showLogoutDialog = true }
                    )

                    content
                }
            } else {
                PermissionRequestView(
                    isLocationPermanentlyDenied: permissionManager.isLocationPermanentlyDenied,
                    showNotificationPermission: permissionManager.needsNotificationPermission,
                    showLocationServicesDisabled: !permissionManager.locationServicesEnabled,
                    onGrantPermission: { permissionManager.requestPermissions() },
                    onOpenSettings: { permissionManager.openAppSettings() },
                    onEnableLocationServices: { permissionManager.openLocationSettings() }
                )
            }
        }
        .onAppear {
            permissionManager.refreshStatus()
            loadDashboardIfReady()
        }
        .onChange(of: permissionManager.canShowDashboard) { _, canShow in
            if canShow {
                loadDashboardIfReady()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            permissionManager.refreshStatus()
        }
        .alert("Logout", isPresented: $showLogoutDialog) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                viewModel.logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .overlay {
            if viewModel.isLoggingOut {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .tint(AppTheme.darkMidnightBlue)
            }
        }
    }

    private func navigate(to route: String) {
        switch route {
        case "assign_order":
            navigationPath.append(HomeDestination.assignOrder)
        case "approve_bills":
            navigationPath.append(HomeDestination.approveBills)
        case "order_approval", "approve_orders", "approve_sellers_to_make_order":
            navigationPath.append(HomeDestination.orderApproval)
        case "order_insights":
            navigationPath.append(
                HomeDestination.orderInsights(
                    startDate: viewModel.startDate,
                    endDate: viewModel.endDate
                )
            )
        case "start_new_order":
            navigationPath.append(HomeDestination.startNewOrder)
        default:
            break
        }
    }

    private func loadDashboardIfReady() {
        guard permissionManager.canShowDashboard, viewModel.response == nil else { return }
        viewModel.loadHome()
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.7))
                            .frame(height: 120)
                    }
                }
                .padding(16)
            }
        } else if let error = viewModel.errorMessage, viewModel.response == nil {
            VStack(spacing: 12) {
                Text("Error")
                    .font(.system(size: 18, weight: .semibold))
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.loadHome()
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.response != nil && !viewModel.isBeatSelected {
            VStack(spacing: 12) {
                Text("Select Your Beat")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Beat selection will open here, same as Android.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            if !section.title.isEmptyString {
                                Text(section.title)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(.horizontal, 4)
                            }

                            LazyVStack(spacing: 10) {
                                ForEach(section.items) { item in
                                    DashboardItemCard(
                                        item: item,
                                        role: viewModel.role,
                                        startDate: viewModel.startDate,
                                        endDate: viewModel.endDate,
                                        onFetch: { viewModel.fetchDashboardData() },
                                        onNavigate: navigate,
                                        onStartDateChange: { newDate in
                                            viewModel.updateDateRange(start: newDate, end: viewModel.endDate)
                                        },
                                        onEndDateChange: { newDate in
                                            viewModel.updateDateRange(start: viewModel.startDate, end: newDate)
                                        },
                                        dateValidationError: viewModel.dateValidationError
                                    )
                                }
                            }
                        }
                    }

                    OperationsCard(operations: viewModel.operationTitles)
                    Text("You've reached the end")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textMuted)
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .refreshable {
                viewModel.loadHome(isRefresh: true)
            }
        }
    }
}

#Preview {
    HomeScreen()
}
