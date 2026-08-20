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
    case orderInsights(
        startDate: String,
        endDate: String,
        datePreset: OrderInsightsDatePreset? = nil,
        orderStatus: String? = nil
    )
    case topSellingProducts(startDate: String, endDate: String, sellerId: String = "")
    case paymentInsights(
        startDate: String,
        endDate: String,
        initialTab: PaymentInsightsViewMode = .report,
        datePreset: OrderInsightsDatePreset? = nil,
        paymentStatus: String? = nil
    )
    case startNewOrder
    case createOrder(sellerId: Int)
    case criticalInsights
    case loginRequests
    case myProfile
    case registeredSellers
    case addSeller(sellerId: Int?)
    case sellerProfile(sellerId: Int)
    case manageProducts
    case addProduct
    case editProduct(productId: Int)
    case quickShare
    case operations(OperationsScreenType)
    case controls
    case markAttendance
    case regularizationRequests
    case viewLeaves
    case achievementHistory(startDate: String, endDate: String)
    case productCatalogue
    case productCalculator
    case failedOrders
    case salesmanActivities
    case staffActivities(role: String)
    case registeredStaffMembers
    case staffReport
    case addStaffMember(staffId: Int?)
    case viewVehicles
    case viewBeats
    case viewTargets
    case viewBeatSummary
    case assignBeats
    case sellerReport
    case expenseApprovals
}

struct HomeScreen: View {

    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var showLogoutDialog = false
    @State private var navigationPath = NavigationPath()
    @State private var didRedirectToAttendance = false
    @State private var pendingRouteMessage: String?

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
                    case .orderInsights(let startDate, let endDate, let datePreset, let orderStatus):
                        OrderInsightsScreen(
                            startDate: startDate,
                            endDate: endDate,
                            datePreset: datePreset,
                            orderStatus: orderStatus
                        )
                    case .topSellingProducts(let startDate, let endDate, let sellerId):
                        TopSellingProductsScreen(
                            startDate: startDate,
                            endDate: endDate,
                            sellerId: sellerId
                        )
                    case .paymentInsights(let startDate, let endDate, let initialTab, let datePreset, let paymentStatus):
                        PaymentInsightsScreen(
                            startDate: startDate,
                            endDate: endDate,
                            initialTab: initialTab,
                            datePreset: datePreset,
                            paymentStatus: paymentStatus
                        )
                    case .startNewOrder:
                        StartNewOrderScreen(
                            onCreateOrder: { sellerId in
                                navigationPath.append(HomeDestination.createOrder(sellerId: sellerId))
                            },
                            onAddSeller: {
                                navigationPath.append(HomeDestination.addSeller(sellerId: nil))
                            },
                            onViewPendingBills: { seller in
                                let staffId = Int(UserDefaultManager.shared.getUserDefaultsString(key: .userId)) ?? 0
                                navigationPath.append(
                                    HomeDestination.viewPendingBills(
                                        sellerId: seller.id,
                                        staffId: staffId,
                                        sellerName: seller.displayName
                                    )
                                )
                            }
                        )
                    case .createOrder(let sellerId):
                        ChooseBrandScreen(sellerId: sellerId) { action in
                            handleCreateOrderFinish(action, sellerId: sellerId)
                        }
                    case .criticalInsights:
                        CriticalInsightsScreen()
                    case .loginRequests:
                        LoginRequestsScreen()
                    case .myProfile:
                        MyProfileScreen()
                    case .registeredSellers:
                        RegisteredSellersScreen(
                            onEditSeller: { sellerId in
                                navigationPath.append(HomeDestination.addSeller(sellerId: sellerId))
                            },
                            onProfileSeller: { sellerId in
                                navigationPath.append(HomeDestination.sellerProfile(sellerId: sellerId))
                            }
                        )
                    case .addSeller(let sellerId):
                        AddSellerScreen(editSellerId: sellerId)
                    case .sellerProfile(let sellerId):
                        SellerProfileScreen(sellerId: sellerId, usesNavigationStack: false)
                    case .manageProducts:
                        ManageProductsScreen(
                            onAddProduct: {
                                navigationPath.append(HomeDestination.addProduct)
                            },
                            onEditProduct: { productId in
                                navigationPath.append(HomeDestination.editProduct(productId: productId))
                            }
                        )
                    case .addProduct:
                        AddProductScreen()
                    case .editProduct(let productId):
                        AddProductScreen(editProductId: productId)
                    case .quickShare:
                        QuickShareScreen()
                    case .operations(let screenType):
                        OperationsScreen(screenType: screenType, onNavigate: navigate)
                    case .controls:
                        ControlsScreen(onNavigate: navigate)
                    case .markAttendance:
                        MarkAttendanceScreen()
                    case .regularizationRequests:
                        RegularizationListScreen()
                    case .viewLeaves:
                        LeaveListScreen()
                    case .achievementHistory(let startDate, let endDate):
                        AchievementHistoryScreen(startDate: startDate, endDate: endDate)
                    case .productCatalogue:
                        ProductCatalogueScreen(
                            onOpenCalculator: {
                                navigationPath.append(HomeDestination.productCalculator)
                            }
                        )
                    case .productCalculator:
                        ProductCalculatorScreen()
                    case .failedOrders:
                        FailedOrdersScreen()
                    case .salesmanActivities:
                        SalesmanActivitiesScreen()
                    case .staffActivities(let role):
                        StaffActivitiesScreen(role: role)
                    case .registeredStaffMembers:
                        RegisteredStaffListScreen()
                    case .staffReport:
                        StaffReportScreen()
                    case .addStaffMember(let staffId):
                        AddStaffScreen(editStaffId: staffId)
                    case .viewVehicles:
                        ViewVehiclesScreen()
                    case .viewBeats:
                        ViewBeatsScreen()
                    case .viewTargets:
                        ViewTargetsScreen()
                    case .viewBeatSummary:
                        BeatOrderSummaryScreen()
                    case .assignBeats:
                        AssignBeatScreen()
                    case .sellerReport:
                        SellerReportScreen()
                    case .expenseApprovals:
                        ExpenseListScreen()
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
                if viewModel.maintenanceMode {
                    MaintenanceScreen()
                } else {
                    VStack(spacing: 0) {
                        HomeAppBar(
                            title: viewModel.isBeatSelected ? viewModel.screenTitle : "Select Your Beat",
                            role: viewModel.isBeatSelected ? viewModel.displayRole : "",
                            profileUrl: viewModel.isBeatSelected ? viewModel.profileUrl : "",
                            onProfileTap: viewModel.isBeatSelected ? { navigationPath.append(HomeDestination.myProfile) } : {},
                            onRefresh: {
                                if viewModel.isBeatSelected {
                                    viewModel.loadHome(isRefresh: true)
                                }
                            },
                            onLogout: { showLogoutDialog = true }
                        )

                        content
                    }
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
            applyMaintenanceModeIfNeeded()
            redirectToAttendanceIfNeeded()
        }
        .onChange(of: permissionManager.canShowDashboard) { _, canShow in
            if canShow {
                loadDashboardIfReady()
            }
        }
        .onChange(of: viewModel.response?.attendanceScreen) { _, _ in
            redirectToAttendanceIfNeeded()
        }
        .onChange(of: viewModel.maintenanceMode) { _, _ in
            applyMaintenanceModeIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            permissionManager.refreshStatus()
            if permissionManager.canShowDashboard, viewModel.response != nil {
                viewModel.loadHomeForResume()
            }
        }
        .alert("Logout", isPresented: $showLogoutDialog) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                viewModel.logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .alert("Notice", isPresented: pendingRouteBinding) {
            Button("OK", role: .cancel) { pendingRouteMessage = nil }
        } message: {
            Text(pendingRouteMessage ?? "")
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
        case "manage_orders", "all_time_orders_summary":
            navigationPath.append(
                HomeDestination.orderInsights(
                    startDate: viewModel.startDate,
                    endDate: viewModel.endDate
                )
            )
        case "controls", "manage_employees":
            navigationPath.append(HomeDestination.controls)
        case "add_new_staff_member":
            navigationPath.append(HomeDestination.addStaffMember(staffId: nil))
        case "view_vehicles":
            navigationPath.append(HomeDestination.viewVehicles)
        case "view_beats":
            navigationPath.append(HomeDestination.viewBeats)
        case "view_targets":
            navigationPath.append(HomeDestination.viewTargets)
        case "view_beat_summary":
            navigationPath.append(HomeDestination.viewBeatSummary)
        case "assignment_history":
            navigationPath.append(HomeDestination.assignBeats)
        case "leave_approval", "view_leaves":
            navigationPath.append(HomeDestination.viewLeaves)
        case "regularize_approval", "regularization_requests":
            navigationPath.append(HomeDestination.regularizationRequests)
        case "staff_report":
            navigationPath.append(HomeDestination.staffReport)
        case "register_staff_member":
            navigationPath.append(HomeDestination.registeredStaffMembers)
        case "expense_approval", "apply_reimbursements":
            navigationPath.append(HomeDestination.expenseApprovals)
        case "rider_report":
            pendingRouteMessage = "\(route.replacingOccurrences(of: "_", with: " ").capitalized) will be available in the next update."
        case "seller_report":
            navigationPath.append(HomeDestination.sellerReport)
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
        case "order_history_pending_this_year":
            navigationPath.append(
                HomeDestination.orderInsights(
                    startDate: "",
                    endDate: "",
                    datePreset: .thisYear,
                    orderStatus: "0"
                )
            )
        case "order_history_to_deliver_this_year":
            navigationPath.append(
                HomeDestination.orderInsights(
                    startDate: "",
                    endDate: "",
                    datePreset: .thisYear,
                    orderStatus: "1"
                )
            )
        case "order_history_delivered_this_year":
            navigationPath.append(
                HomeDestination.orderInsights(
                    startDate: "",
                    endDate: "",
                    datePreset: .thisYear,
                    orderStatus: "3"
                )
            )
        case "manage_orders_top_selling":
            navigationPath.append(
                HomeDestination.topSellingProducts(
                    startDate: viewModel.startDate,
                    endDate: viewModel.endDate
                )
            )
        case "payment_history":
            navigationPath.append(
                HomeDestination.paymentInsights(
                    startDate: viewModel.startDate,
                    endDate: viewModel.endDate
                )
            )
        case "payment_history_bills":
            navigationPath.append(
                HomeDestination.paymentInsights(
                    startDate: "",
                    endDate: "",
                    initialTab: .bills,
                    datePreset: .thisYear,
                    paymentStatus: "0"
                )
            )
        case "start_new_order", "manage_orders_create":
            navigationPath.append(HomeDestination.startNewOrder)
        case "last_10_day_summery", "critical_insights":
            navigationPath.append(HomeDestination.criticalInsights)
        case "new_device_login_requests", "manage_logins", "login_requests":
            navigationPath.append(HomeDestination.loginRequests)
        case "registered_sellers":
            navigationPath.append(HomeDestination.registeredSellers)
        case "add_new_sellers":
            navigationPath.append(HomeDestination.addSeller(sellerId: nil))
        case "view_products":
            navigationPath.append(HomeDestination.manageProducts)
        case "quick_share":
            navigationPath.append(HomeDestination.quickShare)
        case "catalogue":
            navigationPath.append(HomeDestination.productCatalogue)
        case "order_not_delivered_history":
            navigationPath.append(HomeDestination.failedOrders)
        case "salesman_activities":
            navigationPath.append(HomeDestination.salesmanActivities)
        case "today_staff_activities":
            navigationPath.append(HomeDestination.staffActivities(role: viewModel.role))
        case "attendance", "mark_attendance":
            navigationPath.append(HomeDestination.markAttendance)
        case "today_achievements":
            navigationPath.append(
                HomeDestination.achievementHistory(
                    startDate: viewModel.startDate,
                    endDate: viewModel.endDate
                )
            )
        default:
            if route.hasPrefix("create_order_with_seller:") {
                let idPart = route.replacingOccurrences(of: "create_order_with_seller:", with: "")
                if let sellerId = Int(idPart), sellerId > 0 {
                    navigationPath.append(HomeDestination.createOrder(sellerId: sellerId))
                }
            }
            break
        }
    }

    private func loadDashboardIfReady() {
        guard permissionManager.canShowDashboard, viewModel.response == nil else { return }
        viewModel.loadHome()
    }

    private var pendingRouteBinding: Binding<Bool> {
        Binding(
            get: { pendingRouteMessage != nil },
            set: { if !$0 { pendingRouteMessage = nil } }
        )
    }

    private func applyMaintenanceModeIfNeeded() {
        guard viewModel.maintenanceMode else { return }
        navigationPath = NavigationPath()
        didRedirectToAttendance = false
    }

    private func redirectToAttendanceIfNeeded() {
        guard !didRedirectToAttendance,
              let response = viewModel.response,
              response.attendanceScreen,
              !response.maintenanceMode else { return }
        didRedirectToAttendance = true
        navigate(to: viewModel.attendanceRoute)
    }

    private func handleCreateOrderFinish(_ action: CreateOrderFinishAction, sellerId: Int) {
        switch action {
        case .viewOrders:
            navigationPath = NavigationPath()
            navigationPath.append(
                HomeDestination.orderInsights(
                    startDate: viewModel.startDate,
                    endDate: viewModel.endDate
                )
            )
        case .goToDashboard:
            navigationPath = NavigationPath()
        case .viewSeller:
            navigationPath = NavigationPath()
            navigationPath.append(HomeDestination.sellerProfile(sellerId: sellerId))
        }
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
            StartNewOrderScreen(
                presentation: .dashboardBeatSelection,
                onBeatSaved: { viewModel.loadHome(isRefresh: true) }
            )
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
                                        globalTopSellingFallback: viewModel.globalTopSellingFallback,
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

                    OperationsCard(
                        operations: viewModel.operationTitles,
                        onOperationTap: { title in
                            if let type = OperationsScreenType(rawValue: title) {
                                if type == .controls {
                                    navigationPath.append(HomeDestination.controls)
                                } else {
                                    navigationPath.append(HomeDestination.operations(type))
                                }
                            }
                        }
                    )
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
