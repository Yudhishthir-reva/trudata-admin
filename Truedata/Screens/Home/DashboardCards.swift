//
//  DashboardCards.swift
//  Truedata
//

import SwiftUI

struct DashboardItemCard: View {
    let item: DashboardItem
    var role: String = ""
    var startDate: String = ""
    var endDate: String = ""
    var globalTopSellingFallback: JSONValue?
    var onFetch: () -> Void = {}
    var onNavigate: (String) -> Void = { _ in }
    var onStartDateChange: (String) -> Void = { _ in }
    var onEndDateChange: (String) -> Void = { _ in }
    var dateValidationError: String?

    var body: some View {
        switch item.route {
        case "assign_order":
            assignOrderCard
        case "approve_bills":
            approveBillsCard
        case "order_approval", "approve_orders":
            orderApprovalCard
        case "approve_sellers_to_make_order":
            approveSellersCard
        case "b2c_orders":
            b2cOrdersCard
        case "new_device_login_requests":
            loginRequestsCard
        case "scheduled_revisits":
            scheduledRevisitsCard
        case "manage_orders":
            manageOrdersCard
        case "payment_history":
            paymentHistoryCard
        case "all_time_orders_summary":
            allTimeOrdersCard
        case "last_10_day_summery":
            criticalInsightsCard
        case "today_staff_activities":
            staffActivitiesCard
        case "salesman_activities":
            salesmanActivitiesCard
        case "order_not_delivered_history":
            orderNotDeliveredCard
        case "quick_share":
            quickShareCard
        case "catalogue":
            catalogueCard
        case "registered_sellers":
            sellersCard
        case "view_products":
            productsCard
        case "your_targets":
            targetsCard
        case "attendance", "mark_attendance":
            attendanceCard
        case "staff_report":
            staffReportCard
        case "view_leaves", "leave_approval":
            leavesCard
        case "regularization_requests", "regularize_approval":
            regularizationCard
        case "today_achievements":
            todayAchievementsCard
        case "rider_report":
            riderReportCard
        case "manage_employees":
            manageEmployeesCard
        case "controls":
            controlsCard
        case "support":
            supportCard
        default:
            genericCard
        }
    }

    private var payload: JSONValue? { item.payload }

    // MARK: - Action rows

    private var assignOrderCard: some View {
        DashboardActionRowCard(
            title: displayTitle("Assign Order"),
            pendingCount: payload?["assignOrderCounts"]?.int(for: "allPendingOrderCount", "todayPendingOrderCount") ?? 0,
            pendingSuffix: "Pending",
            buttonTitle: "Assign Orders",
            statusIcon: "doc.text.fill",
            action: { onNavigate("assign_order") }
        )
    }

    private var approveBillsCard: some View {
        DashboardActionRowCard(
            title: displayTitle("Approve Bills"),
            pendingCount: payload?.nestedInt(in: ["Bills", "bills"], keys: ["allPendingBills"]) ?? 0,
            pendingSuffix: "Pending",
            buttonTitle: "Review Bills",
            statusIcon: "doc.plaintext.fill",
            action: { onNavigate("approve_bills") }
        )
    }

    private var orderApprovalCard: some View {
        DashboardActionRowCard(
            title: displayTitle("Order Approval"),
            pendingCount: payload?.int(for: "pendingRequests", "pending_requests", "pendingOrders", "pending_orders") ?? 0,
            pendingSuffix: "Pending",
            buttonTitle: "Review",
            statusIcon: "clock.fill",
            action: { onNavigate("order_approval") }
        )
    }

    private var approveSellersCard: some View {
        DashboardActionRowCard(
            title: displayTitle("Approve Sellers"),
            pendingCount: payload?.int(for: "pendingRequests", "pending_requests") ?? 0,
            pendingSuffix: "Pending",
            buttonTitle: "Review",
            statusIcon: "person.crop.circle.badge.clock",
            action: { onNavigate("approve_sellers_to_make_order") }
        )
    }

    private var loginRequestsCard: some View {
        DashboardActionRowCard(
            title: displayTitle("New Device Login Requests"),
            pendingCount: payload?.int(for: "login_request_number", "loginRequestNumber") ?? 0,
            pendingSuffix: "Requests",
            buttonTitle: "Review",
            bulletColors: [DashboardTheme.warningYellow, DashboardTheme.primaryBlue],
            statusIcon: "key.fill",
            emptyText: "No Requests",
            action: { onNavigate("new_device_login_requests") }
        )
    }

    // MARK: - Scheduled revisits

    private var scheduledRevisitsCard: some View {
        let sellers = scheduledSellers
        return DashboardCardChrome(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                DashboardBulletTitle(title: displayTitle("Scheduled Revisits"), systemImage: "clock.fill")

                if sellers.isEmpty {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(DashboardTheme.surfaceVariant)
                                .frame(width: 56, height: 56)
                            Image(systemName: "clock.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                        Text("No Revisits Scheduled")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Text("All caught up! No sellers scheduled for revisits today.")
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    HStack(spacing: 8) {
                        Text("👆")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hold & Create Order")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DashboardTheme.infoBlue)
                            Text("Hold any seller for 0.7s to quickly create an order")
                                .font(.system(size: 11))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DashboardTheme.infoBlue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(sellers) { seller in
                                ScheduledSellerAvatar(
                                    seller: seller,
                                    onLongPress: {
                                        onNavigate("create_order_with_seller:\(seller.id)")
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
    }

    // MARK: - Today's orders

    private var manageOrdersCard: some View {
        let today = payload?["todayOrders"] ?? payload?["today_orders"] ?? payload?["todayOrder"] ?? payload
        let payModes = today?["paymentCollectionByPayMode"] ?? payload?["paymentCollectionByPayMode"]
        let cash = payModes?.double(for: "cashAmount", "CashAmount") ?? 0
        let upi = payModes?.double(for: "upiAmount", "UPIAmount") ?? 0
        let cheque = payModes?.double(for: "chequeAmount", "ChequeAmount") ?? 0
        let totalCollection = cash + upi + cheque
        let totalAmount = today?.double(for: "todayTotalAmount", "today_total_amount")
            ?? payload?.double(for: "todayTotalAmount", "today_total_amount")
            ?? 0
        let deliveredAmount = today?.double(for: "todayDeliveredAmount", "today_delivered_amount")
            ?? payload?.double(for: "todayDeliveredAmount", "today_delivered_amount")
            ?? 0
        let pendingAmount = today?.double(for: "todayPendingAmount", "today_pending_amount")
            ?? payload?.double(for: "todayPendingAmount", "today_pending_amount")
            ?? 0
        let approvedCollection = today?.double(for: "todayApprovedCollectionAmount", "today_approved_collection_amount")
            ?? payload?.double(for: "todayApprovedCollectionAmount", "today_approved_collection_amount")
            ?? 0

        let pendingOrders = today?.int(for: "pending", "pendingOrders", "pending_orders")
            ?? payload?.int(for: "pending", "pendingOrders", "pending_orders")
            ?? 0
        let deliveredOrders = today?.int(for: "delivered", "deliveredOrders", "delivered_orders")
            ?? payload?.int(for: "delivered", "deliveredOrders", "delivered_orders")
            ?? 0
        let assignedOrders = today?.int(for: "assigned", "assignedOrders", "assigned_orders")
            ?? payload?.int(for: "assigned", "assignedOrders", "assigned_orders")
            ?? 0
        let pickupOrders = today?.int(for: "pickup", "pickupOrders", "pickup_orders")
            ?? payload?.int(for: "pickup", "pickupOrders", "pickup_orders")
            ?? 0
        let toDeliverOrders = today?.int(for: "to_deliver", "toDeliver")
            ?? payload?.int(for: "to_deliver", "toDeliver")
            ?? 0
        let returnedOrders = today?.int(for: "returned", "returnedOrders", "returned_orders")
            ?? payload?.int(for: "returned", "returnedOrders", "returned_orders")
            ?? 0
        let cancelledOrders = today?.int(for: "cancelled", "cancelledOrders", "cancelled_orders")
            ?? payload?.int(for: "cancelled", "cancelledOrders", "cancelled_orders")
            ?? 0

        // Match Android OrderStatusData.total — sum of all statuses (not pending alone).
        let sumOfAllOrders = pendingOrders + deliveredOrders + assignedOrders + pickupOrders + toDeliverOrders + returnedOrders + cancelledOrders
        let apiTotal = today?.int(for: "total", "totalOrders", "total_orders", "totalCount", "total_count")
            ?? payload?.int(for: "total", "totalOrders", "total_orders", "totalCount", "total_count")
        let totalOrdersCount = sumOfAllOrders > 0 ? sumOfAllOrders : (apiTotal ?? pendingOrders)

        let explicitValid = today?.int(for: "totalWithoutCancelled", "total_without_cancelled", "totalValidOrders", "total_valid_orders", "validOrders", "valid_orders")
            ?? payload?.int(for: "totalWithoutCancelled", "total_without_cancelled", "totalValidOrders", "total_valid_orders", "validOrders", "valid_orders")

        let validOrders: Int = {
            if let explicit = explicitValid, explicit > 0 {
                return explicit
            }
            // Match Android OrderStatusData.totalWithoutCancelled = total - cancelled
            return max(sumOfAllOrders - cancelledOrders, 0)
        }()

        let hasCollection = totalCollection > 0
        let products = topSellingProducts(
            from: today,
            fallback: globalTopSellingFallback ?? payload
        )

        return DashboardCardChrome(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 16) {
                DashboardBulletTitle(title: displayTitle("Today's Orders"))

                HStack(spacing: 8) {
                    DashboardDatePickerField(
                        dateString: startDate.isEmptyString ? todayDateString : startDate,
                        onDateSelected: onStartDateChange
                    )
                    DashboardDatePickerField(
                        dateString: endDate.isEmptyString ? todayDateString : endDate,
                        onDateSelected: onEndDateChange
                    )
                }

                if let dateValidationError, !dateValidationError.isEmptyString {
                    Text(dateValidationError)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.dangerRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: onFetch) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                        Text("Fetch")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DashboardTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(alignment: .top, spacing: 12) {
                    if hasCollection {
                        VStack(spacing: 8) {
                            DashboardDonutChart(
                                segments: collectionSegments(cash: cash, upi: upi, cheque: cheque),
                                centerTitle: totalCollection.compactCurrencyLabel,
                                centerSubtitle: "Collections by Mode\n(\(totalCollection.currencyLabel))"
                            )
                            VStack(spacing: 4) {
                                DashboardLegendRow(color: DashboardTheme.accentTeal, title: "Cash", value: cash.currencyLabel)
                                DashboardLegendRow(color: DashboardTheme.secondaryPurple, title: "UPI", value: upi.currencyLabel)
                                DashboardLegendRow(color: DashboardTheme.primaryBlue, title: "Cheque", value: cheque.currencyLabel)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        DashboardDonutChart(
                            segments: orderStatusChartSegments(from: today),
                            centerTitle: "\(totalOrdersCount)",
                            centerSubtitle: "Total Orders"
                        )
                        .frame(maxWidth: .infinity)
                    }

                    VStack(spacing: 8) {
                        DashboardDonutChart(
                            segments: [
                                DashboardChartSegment(value: deliveredAmount, color: DashboardTheme.successGreen),
                                DashboardChartSegment(value: pendingAmount, color: DashboardTheme.warningYellow)
                            ].filter { $0.value > 0 },
                            centerTitle: totalAmount.compactCurrencyLabel,
                            centerSubtitle: "Today Order Amount\n(\(totalAmount.currencyLabel))"
                        )
                        orderStatusLegend(from: today)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 10) {
                    DashboardOutlinedButton(title: "View History", systemImage: "arrow.right") {
                        onNavigate("order_insights")
                    }
                    Button(action: { onNavigate("start_new_order") }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Create Order")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(DashboardTheme.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                DashboardSectionHeader(title: "Today's Sales")
                HStack {
                    DashboardAmountTile(label: "Total", value: totalAmount)
                    Divider().frame(height: 36)
                    DashboardAmountTile(label: "Delivered", value: deliveredAmount)
                    Divider().frame(height: 36)
                    DashboardAmountTile(label: "Pending", value: pendingAmount)
                }
                .padding(.vertical, 8)
                .background(DashboardTheme.surfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if approvedCollection > 0 {
                    Divider()
                    DashboardSectionHeader(title: "Today's Collection")
                    VStack(spacing: 4) {
                        Text("Settled Amount")
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        Text(approvedCollection.currencyLabel)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DashboardTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Divider()
                DashboardSectionHeader(title: "Total Valid Orders")
                Text("\(max(validOrders, 0))")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DashboardTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Divider()
                topSellingProductsSection(products) {
                    onNavigate("manage_orders_top_selling")
                }
            }
        }
    }

    // MARK: - Payment history

    private var paymentHistoryCard: some View {
        let transactions = payload?["Transactions"]
        let cashAmount = paymentAmount(from: transactions, mode: "CashAmount")
        let upiAmount = paymentAmount(from: transactions, mode: "UPIAmount")
        let chequeAmount = paymentAmount(from: transactions, mode: "ChequeAmount")
        let cashCount = paymentCount(from: transactions, mode: "Cash")
        let upiCount = paymentCount(from: transactions, mode: "UPI")
        let chequeCount = paymentCount(from: transactions, mode: "Cheque")
        let total = cashAmount + upiAmount + chequeAmount
        let billCount = transactions?["Approved"]?.string(for: "totalBillCount") ?? "0"

        return DashboardCardChrome {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(displayTitle("Payment Insights"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(billCount)
                            .font(.system(size: 17, weight: .bold))
                        Text("Bills with Settlements")
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 8) {
                        DashboardDonutChart(
                            segments: [
                                DashboardChartSegment(value: cashAmount, color: DashboardTheme.successGreen),
                                DashboardChartSegment(value: upiAmount, color: DashboardTheme.infoBlue),
                                DashboardChartSegment(value: chequeAmount, color: DashboardTheme.warningYellow)
                            ].filter { $0.value > 0 },
                            centerTitle: total.compactCurrencyLabel,
                            centerSubtitle: nil
                        )
                        Text("Total Amount")
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        Text(total.currencyLabel)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 10) {
                        paymentLegendItem(color: DashboardTheme.successGreen, title: "Cash", count: cashCount, amount: cashAmount, total: total)
                        paymentLegendItem(color: DashboardTheme.infoBlue, title: "UPI", count: upiCount, amount: upiAmount, total: total)
                        paymentLegendItem(color: DashboardTheme.warningYellow, title: "Cheque", count: chequeCount, amount: chequeAmount, total: total)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Spacer()
                    Button(action: { onNavigate("payment_history") }) {
                        Text("View History >")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - All time

    private var allTimeOrdersCard: some View {
        let orders = payload?["alltimeOrders"]
        let pendingBills = payload?.int(for: "allPendingBills") ?? 0
        return VStack(spacing: 8) {
            DashboardCardChrome {
                HStack {
                    DashboardBulletTitle(
                        title: "All Pending Bills",
                        colors: [DashboardTheme.warningYellow, DashboardTheme.dangerRed]
                    )
                    Spacer()
                    DashboardCompactButton(
                        title: "Settle Pending Bills",
                        color: DashboardTheme.warningYellow,
                        action: { onNavigate("payment_history_bills") }
                    )
                }
            }

            DashboardCardChrome {
                VStack(alignment: .leading, spacing: 12) {
                    DashboardBulletTitle(title: "All Time Orders")
                    HStack(spacing: 8) {
                        DashboardStatPill(
                            title: "Pending",
                            value: "\(orders?.int(for: "pending") ?? 0)",
                            valueColor: DashboardTheme.warningYellow,
                            action: { onNavigate("order_history_pending_this_year") }
                        )
                        DashboardStatPill(
                            title: "Dispatched",
                            value: "\(orders?.int(for: "to_deliver", "toDeliver") ?? 0)",
                            valueColor: DashboardTheme.infoBlue,
                            action: { onNavigate("order_history_to_deliver_this_year") }
                        )
                        DashboardStatPill(
                            title: "Delivered",
                            value: "\(orders?.int(for: "delivered") ?? 0)",
                            valueColor: DashboardTheme.successGreen,
                            action: { onNavigate("order_history_delivered_this_year") }
                        )
                    }
                    if pendingBills > 0 {
                        Text("Pending bills: \(pendingBills)")
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }
            }
        }
    }

    private var criticalInsightsCard: some View {
        DashboardCardChrome {
            HStack {
                DashboardBulletTitle(
                    title: displayTitle("Critical Insights"),
                    colors: [DashboardTheme.warningYellow, DashboardTheme.pickupOrange]
                )
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .foregroundStyle(DashboardTheme.warningYellow)
                Spacer()
                DashboardCompactButton(
                    title: "View Summary →",
                    color: DashboardTheme.warningYellow,
                    action: { onNavigate("last_10_day_summery") }
                )
            }
        }
    }

    // MARK: - Staff

    private var staffActivitiesCard: some View {
        let activities = staffActivityRows
        let showAmounts = DashboardRole.canShowStaffAmountDetails(role: role)
        return DashboardCardChrome(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DashboardTheme.primaryBlue)
                        .frame(width: 4, height: 18)
                    Text(displayTitle("Today Staff Activities"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
                .padding(.bottom, 12)

                StaffActivityTableHeader(showAmountDetails: showAmounts)
                    .padding(.horizontal, -16)

                if activities.isEmpty {
                    VStack(spacing: 6) {
                        Text("No Activity Yet")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Text("Orders and sales will appear here.")
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(Array(activities.prefix(5).enumerated()), id: \.offset) { index, row in
                        Button {
                            onNavigate("today_staff_activities")
                        } label: {
                            StaffActivityTableRow(
                                row: StaffActivityDisplayRow(
                                    name: row.name,
                                    orders: row.orders,
                                    sales: row.sales,
                                    collection: row.collection
                                ),
                                rank: index + 1,
                                showAmountDetails: showAmounts
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, -16)
                    }
                }

                StaffActivitiesPillButton(title: "View All Activities") {
                    onNavigate("today_staff_activities")
                }
                .padding(.top, 12)
            }
        }
    }

    private var salesmanActivitiesCard: some View {
        let count = payload?.int(for: "workingStaffCount", "working_staff_count") ?? 0
        return DashboardCardChrome(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                DashboardBulletTitle(title: displayTitle("Salesman Activities"))
                HStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    Text("\(count)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
                .frame(maxWidth: .infinity)
                Text("working staff today")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .frame(maxWidth: .infinity)
                DashboardOutlinedButton(
                    title: "View Staff",
                    systemImage: "arrow.right",
                    action: { onNavigate("salesman_activities") }
                )
            }
        }
    }

    private var orderNotDeliveredCard: some View {
        let today = payload?.string(for: "totalFailedOrdersCountToday", "total_failed_orders_count_today") ?? "0"
        let allTime = payload?.string(for: "totalFailedOrdersCountAllTime", "total_failed_orders_count_all_time") ?? "0"
        return DashboardCardChrome {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        DashboardBulletTitle(
                            title: displayTitle("Order Not Delivered History"),
                            colors: [DashboardTheme.dangerRed, DashboardTheme.warningYellow]
                        )
                        Text("Failed deliveries")
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        Text(today == "0" ? "None Today" : "\(today) Today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        statBlock(label: "Today", value: today, color: DashboardTheme.warningYellow)
                        statBlock(label: "All Time", value: allTime, color: DashboardTheme.dangerRed)
                    }
                    Spacer()
                    DashboardCompactButton(
                        title: "View",
                        color: DashboardTheme.dangerRed,
                        action: { onNavigate("order_not_delivered_history") }
                    )
                }
            }
        }
    }

    private var quickShareCard: some View {
        let enabled = payload?.boolValue ?? payload?["isShow"]?.boolValue ?? true
        return DashboardCardChrome {
            HStack {
                DashboardBulletTitle(title: displayTitle("Quick Share"))
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(enabled ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                    Text(enabled ? "Available" : "Unavailable")
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    DashboardCompactButton(title: "View", action: { onNavigate("quick_share") })
                }
            }
        }
    }

    private var catalogueCard: some View {
        DashboardCardChrome {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    DashboardBulletTitle(
                        title: displayTitle("Catalogue"),
                        colors: [DashboardTheme.secondaryPurple, DashboardTheme.primaryBlue]
                    )
                    Text("Browse all products and variants")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                Spacer()
                Button(action: { onNavigate("catalogue") }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                        Text("View Catalogue")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DashboardTheme.secondaryPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sellersCard: some View {
        let total = payload?.int(for: "totalSellerCount", "total_seller_count") ?? 0
        let active = payload?.int(for: "activeSellerCount", "active_seller_count") ?? 0
        let inactive = payload?.int(for: "inactiveSellerCount", "inactive_seller_count") ?? 0
        let showAdd = payload?["addSellerButtonIsShow"]?.boolValue ?? false
        return summaryCard(
            title: displayTitle("Sellers"),
            colors: [DashboardTheme.accentTeal, DashboardTheme.infoBlue],
            stats: [
                ("storefront.fill", total, DashboardTheme.accentTeal),
                ("checkmark.circle.fill", active, DashboardTheme.successGreen),
                ("pause.circle.fill", inactive, DashboardTheme.neutralMedium)
            ],
            primaryTitle: "View All →",
            primaryColor: DashboardTheme.accentTeal,
            secondaryTitle: showAdd ? "+ Add" : nil,
            secondaryColor: DashboardTheme.successGreen,
            primaryAction: { onNavigate("registered_sellers") },
            secondaryAction: showAdd ? { onNavigate("add_new_sellers") } : nil
        )
    }

    private var productsCard: some View {
        let total = payload?.int(for: "allProducts", "all_products") ?? 0
        let active = payload?.int(for: "activeProducts", "active_products") ?? 0
        let inactive = payload?.int(for: "inactiveProducts", "inactive_products") ?? 0
        let products = topSellingProducts(from: nil, fallback: payload)

        return DashboardCardChrome(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        DashboardBulletTitle(
                            title: displayTitle("Products"),
                            colors: [DashboardTheme.infoBlue, DashboardTheme.primaryBlue]
                        )
                        HStack(spacing: 10) {
                            productStatChip(systemName: "square.stack.3d.up.fill", value: total, color: DashboardTheme.infoBlue)
                            productStatChip(systemName: "checkmark.circle.fill", value: active, color: DashboardTheme.successGreen)
                            productStatChip(systemName: "pause.circle.fill", value: inactive, color: DashboardTheme.neutralMedium)
                        }
                    }
                    Spacer(minLength: 0)
                    DashboardCompactButton(title: "View Products →", color: DashboardTheme.infoBlue, action: {
                        onNavigate("view_products")
                    })
                }

                if !products.isEmpty {
                    Divider()
                    topSellingProductsSection(products, showViewMore: false)
                }
            }
        }
    }

    private func productStatChip(systemName: String, value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemName)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
    }

    private var targetsCard: some View {
        let current = payload?["current_month"]
        return DashboardCardChrome {
            VStack(alignment: .leading, spacing: 10) {
                DashboardBulletTitle(title: displayTitle("Your Targets"))
                DashboardStatRow(label: current?.string(for: "month").isEmptyString == false ? current?.string(for: "month") ?? "Target" : "Target", value: (current?.string(for: "target_amount") ?? "0").priceLabel)
                DashboardStatRow(label: "Achieved", value: (current?.string(for: "achieved_amount") ?? "0").priceLabel)
            }
        }
    }

    // MARK: - B2C Orders

    private var b2cOrdersCard: some View {
        let todayOrders = payload?.int(for: "today_orders", "todayOrders") ?? 0
        let orderAmount = payload?.double(for: "order_amount", "orderAmount") ?? 0
        let running = payload?.int(for: "running", "running_orders") ?? 0

        return VStack(alignment: .leading, spacing: 16) {
            // Header Row
            HStack(alignment: .center, spacing: 12) {
                // Orange bag icon box
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "FFEDD5"))
                        .frame(width: 44, height: 44)

                    Image(systemName: "bag.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(hex: "EA580C"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayTitle("B2C Orders"))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(hex: "111827"))

                    Text("\(running) waiting on you")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(hex: "EA580C"))
                }

                Spacer()

                Button {
                    onNavigate("b2c_orders")
                } label: {
                    HStack(spacing: 4) {
                        Text("Manage")
                            .font(.system(size: 14, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "EA580C"))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Stat Boxes
            HStack(spacing: 10) {
                // Today Orders (Blue)
                Button {
                    onNavigate("b2c_orders")
                } label: {
                    VStack(spacing: 6) {
                        Text("\(todayOrders)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color(hex: "1D4ED8"))

                        Text("Today\nOrders")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "64748B"))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .background(Color(hex: "F0F7FF"))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(hex: "DBEAFE"), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Order Amount (Dark/Slate)
                Button {
                    onNavigate("b2c_orders")
                } label: {
                    VStack(spacing: 6) {
                        Text(String(format: "₹%.2f", orderAmount))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color(hex: "0F172A"))
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)

                        Text("Order\nAmount")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "64748B"))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .background(Color(hex: "F8FAFC"))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(hex: "E2E8F0"), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Running (Orange)
                Button {
                    onNavigate("b2c_orders")
                } label: {
                    VStack(spacing: 6) {
                        Text("\(running)")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color(hex: "EA580C"))

                        Text("Running")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "64748B"))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 96)
                    .background(Color(hex: "FFF7ED"))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(hex: "FFEDD5"), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "FED7AA").opacity(0.8), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Attendance

    private var attendanceCard: some View {
        let inTime = payload?.string(for: "in_time") ?? ""
        let outTime = payload?.string(for: "out_time") ?? ""
        let inStatus = payload?["in_time_status"]?.boolValue ?? (!inTime.isEmptyString && inTime != "No data available")
        let outStatus = payload?["out_time_status"]?.boolValue ?? (!outTime.isEmptyString && outTime != "No data available")

        let statusText: String
        let statusColor: Color
        let statusIcon: String
        if inStatus && outStatus {
            statusText = "Shift Complete"
            statusColor = DashboardTheme.successGreen
            statusIcon = "checkmark.circle.fill"
        } else if inStatus {
            statusText = "Working"
            statusColor = DashboardTheme.warningYellow
            statusIcon = "clock.fill"
        } else {
            statusText = "Check In Pending"
            statusColor = DashboardTheme.neutralMedium
            statusIcon = "arrow.right.to.line.compact"
        }

        return DashboardCardChrome(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    DashboardBulletTitle(
                        title: displayTitle("Mark Attendance"),
                        colors: [DashboardTheme.primaryBlue, DashboardTheme.accentTeal],
                        systemImage: "clock.badge.checkmark.fill"
                    )
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 11))
                        Text(statusText)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
                }

                HStack(spacing: 10) {
                    attendanceTimePill(
                        label: "Punch In",
                        time: inTime.isEmptyString ? "--:--" : inTime,
                        icon: "arrow.right.circle.fill",
                        color: inStatus ? DashboardTheme.successGreen : DashboardTheme.neutralMedium
                    )
                    attendanceTimePill(
                        label: "Punch Out",
                        time: outTime.isEmptyString || outTime == "No data available" ? "--:--" : outTime,
                        icon: "arrow.left.circle.fill",
                        color: outStatus ? DashboardTheme.successGreen : DashboardTheme.neutralMedium
                    )
                }

                DashboardOutlinedButton(
                    title: inStatus && !outStatus ? "Punch Out / View Attendance" : "Mark Attendance",
                    systemImage: "hand.tap.fill",
                    action: { onNavigate("attendance") }
                )
            }
        }
    }

    private func attendanceTimePill(label: String, time: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Text(time)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(DashboardTheme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity)
    }

    // MARK: - Staff Report

    private var staffReportCard: some View {
        let total = payload?.int(for: "totalStaff", "total_staff") ?? 0
        let present = payload?.int(for: "presentStaff", "present_staff") ?? 0
        let absent = payload?.int(for: "absentStaff", "absent_staff") ?? max(total - present, 0)

        return DashboardCardChrome(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    DashboardBulletTitle(
                        title: displayTitle("Staff Report"),
                        colors: [DashboardTheme.primaryBlue, DashboardTheme.infoBlue],
                        systemImage: "person.3.sequence.fill"
                    )
                    Spacer()
                    DashboardCompactButton(
                        title: "View Report →",
                        color: DashboardTheme.primaryBlue,
                        action: { onNavigate("staff_report") }
                    )
                }

                HStack(spacing: 8) {
                    DashboardStatPill(
                        title: "Total Staff",
                        value: "\(total)",
                        valueColor: DashboardTheme.primaryBlue,
                        action: { onNavigate("staff_report") }
                    )
                    DashboardStatPill(
                        title: "Present",
                        value: "\(present)",
                        valueColor: DashboardTheme.successGreen,
                        action: { onNavigate("staff_report") }
                    )
                    DashboardStatPill(
                        title: "Absent",
                        value: "\(absent)",
                        valueColor: DashboardTheme.dangerRed,
                        action: { onNavigate("staff_report") }
                    )
                }
            }
        }
    }

    // MARK: - Leaves

    private var leavesCard: some View {
        let pending = payload?.int(for: "pendingLeaveCount", "pending_leave_count") ?? 0
        let total = payload?.int(for: "totalLeaveCount", "total_leave_count") ?? 0
        let today = payload?.int(for: "todayLeaveCount", "today_leave_count") ?? 0

        return DashboardCardChrome(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    DashboardBulletTitle(
                        title: displayTitle("Leaves"),
                        colors: [DashboardTheme.dangerRed, DashboardTheme.warningYellow],
                        systemImage: "calendar.badge.minus"
                    )
                    Spacer()
                    DashboardCompactButton(
                        title: "View Leaves →",
                        color: DashboardTheme.dangerRed,
                        action: { onNavigate("view_leaves") }
                    )
                }

                HStack(spacing: 8) {
                    DashboardStatPill(
                        title: "Pending",
                        value: "\(pending)",
                        valueColor: pending > 0 ? DashboardTheme.dangerRed : DashboardTheme.neutralMedium,
                        action: { onNavigate("view_leaves") }
                    )
                    DashboardStatPill(
                        title: "Today",
                        value: "\(today)",
                        valueColor: DashboardTheme.warningYellow,
                        action: { onNavigate("view_leaves") }
                    )
                    DashboardStatPill(
                        title: "Total",
                        value: "\(total)",
                        valueColor: DashboardTheme.infoBlue,
                        action: { onNavigate("view_leaves") }
                    )
                }
            }
        }
    }

    // MARK: - Regularization

    private var regularizationCard: some View {
        let pending = payload?.int(for: "pendingRegularizeCount", "pending_regularize_count") ?? 0
        let total = payload?.int(for: "allRegularizeCount", "totalRegularizeCount", "total_regularize_count") ?? 0
        let today = payload?.int(for: "todayRegulizeCount", "todayRegularizeCount", "today_regularize_count") ?? 0

        return DashboardCardChrome(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    DashboardBulletTitle(
                        title: displayTitle("Regularize"),
                        colors: [DashboardTheme.warningYellow, DashboardTheme.pickupOrange],
                        systemImage: "calendar.badge.clock"
                    )
                    Spacer()
                    DashboardCompactButton(
                        title: "View Requests →",
                        color: DashboardTheme.warningYellow,
                        action: { onNavigate("regularization_requests") }
                    )
                }

                HStack(spacing: 8) {
                    DashboardStatPill(
                        title: "Pending",
                        value: "\(pending)",
                        valueColor: pending > 0 ? DashboardTheme.warningYellow : DashboardTheme.neutralMedium,
                        action: { onNavigate("regularization_requests") }
                    )
                    DashboardStatPill(
                        title: "Today",
                        value: "\(today)",
                        valueColor: DashboardTheme.pickupOrange,
                        action: { onNavigate("regularization_requests") }
                    )
                    DashboardStatPill(
                        title: "Total",
                        value: "\(total)",
                        valueColor: DashboardTheme.infoBlue,
                        action: { onNavigate("regularization_requests") }
                    )
                }
            }
        }
    }

    // MARK: - Today Achievements

    private var todayAchievementsCard: some View {
        let sellerCount = payload?.int(for: "todaySellerCount", "today_seller_count") ?? 0
        let collectionAmount = payload?.double(for: "todayCollectionAmount", "today_collection_amount") ?? 0
        let approvedCollection = payload?.double(for: "todayApprovedCollectionAmount") ?? 0

        return DashboardCardChrome(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    DashboardBulletTitle(
                        title: displayTitle("Today Achievements"),
                        colors: [DashboardTheme.rankGold, DashboardTheme.pickupOrange],
                        systemImage: "trophy.fill"
                    )
                    Spacer()
                    DashboardCompactButton(
                        title: "View History →",
                        color: DashboardTheme.rankGold,
                        action: { onNavigate("today_achievements") }
                    )
                }

                HStack(spacing: 8) {
                    DashboardStatPill(
                        title: "Sellers Visited",
                        value: "\(sellerCount)",
                        valueColor: DashboardTheme.infoBlue,
                        action: { onNavigate("today_achievements") }
                    )
                    DashboardStatPill(
                        title: "Collection",
                        value: collectionAmount.currencyLabel,
                        valueColor: DashboardTheme.successGreen,
                        action: { onNavigate("today_achievements") }
                    )
                    DashboardStatPill(
                        title: "Settled",
                        value: approvedCollection.currencyLabel,
                        valueColor: DashboardTheme.secondaryPurple,
                        action: { onNavigate("today_achievements") }
                    )
                }
            }
        }
    }

    // MARK: - Rider Report

    private var riderReportCard: some View {
        let total = payload?.int(for: "totalRider", "total_rider") ?? 0
        let present = payload?.int(for: "presentRider", "present_rider") ?? 0
        let absent = payload?.int(for: "absentRider", "absent_rider") ?? max(total - present, 0)

        return DashboardCardChrome(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    DashboardBulletTitle(
                        title: displayTitle("Rider Report"),
                        colors: [DashboardTheme.accentTeal, DashboardTheme.primaryBlue],
                        systemImage: "bicycle"
                    )
                    Spacer()
                    DashboardCompactButton(
                        title: "View Report →",
                        color: DashboardTheme.accentTeal,
                        action: { onNavigate("rider_report") }
                    )
                }

                HStack(spacing: 8) {
                    DashboardStatPill(
                        title: "Total Riders",
                        value: "\(total)",
                        valueColor: DashboardTheme.accentTeal,
                        action: { onNavigate("rider_report") }
                    )
                    DashboardStatPill(
                        title: "Present",
                        value: "\(present)",
                        valueColor: DashboardTheme.successGreen,
                        action: { onNavigate("rider_report") }
                    )
                    DashboardStatPill(
                        title: "Absent",
                        value: "\(absent)",
                        valueColor: DashboardTheme.dangerRed,
                        action: { onNavigate("rider_report") }
                    )
                }
            }
        }
    }

    // MARK: - Manage Employees

    private var manageEmployeesCard: some View {
        let pendingLeave = payload?.int(for: "pendingLeaveCount", "pending_leave_count") ?? 0
        let pendingRegularize = payload?.int(for: "pendingRegularizeCount", "pending_regularize_count") ?? 0
        let pendingExpense = payload?.int(for: "pendingExpenseCount", "pending_expense_count") ?? 0

        return DashboardCardChrome(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    DashboardBulletTitle(
                        title: displayTitle("Manage Employees"),
                        colors: [DashboardTheme.secondaryPurple, DashboardTheme.primaryBlue],
                        systemImage: "person.text.rectangle.fill"
                    )
                    Spacer()
                    DashboardCompactButton(
                        title: "Controls →",
                        color: DashboardTheme.secondaryPurple,
                        action: { onNavigate("controls") }
                    )
                }

                HStack(spacing: 8) {
                    DashboardStatPill(
                        title: "Leaves",
                        value: "\(pendingLeave) P",
                        valueColor: pendingLeave > 0 ? DashboardTheme.dangerRed : DashboardTheme.neutralMedium,
                        action: { onNavigate("view_leaves") }
                    )
                    DashboardStatPill(
                        title: "Regularize",
                        value: "\(pendingRegularize) P",
                        valueColor: pendingRegularize > 0 ? DashboardTheme.warningYellow : DashboardTheme.neutralMedium,
                        action: { onNavigate("regularization_requests") }
                    )
                    DashboardStatPill(
                        title: "Expenses",
                        value: "\(pendingExpense) P",
                        valueColor: pendingExpense > 0 ? DashboardTheme.successGreen : DashboardTheme.neutralMedium,
                        action: { onNavigate("expense_approval") }
                    )
                }
            }
        }
    }

    // MARK: - Controls

    private var controlsCard: some View {
        DashboardCardChrome(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    DashboardBulletTitle(
                        title: displayTitle("Controls"),
                        colors: [DashboardTheme.primaryBlue, DashboardTheme.secondaryPurple],
                        systemImage: "slider.horizontal.3"
                    )
                    Spacer()
                    DashboardCompactButton(
                        title: "Open Controls →",
                        color: DashboardTheme.primaryBlue,
                        action: { onNavigate("controls") }
                    )
                }

                HStack(spacing: 8) {
                    quickShortcutPill(title: "Staff", icon: "person.2.fill", color: DashboardTheme.primaryBlue) {
                        onNavigate("register_staff_member")
                    }
                    quickShortcutPill(title: "Vehicles", icon: "car.fill", color: DashboardTheme.successGreen) {
                        onNavigate("view_vehicles")
                    }
                    quickShortcutPill(title: "Beats", icon: "mappin.and.ellipse", color: DashboardTheme.pickupOrange) {
                        onNavigate("view_beats")
                    }
                    quickShortcutPill(title: "Targets", icon: "chart.pie.fill", color: DashboardTheme.secondaryPurple) {
                        onNavigate("view_targets")
                    }
                }
            }
        }
    }

    private func quickShortcutPill(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var supportCard: some View {
        let sales = payload?.string(for: "forSales", "for_sales") ?? ""
        return DashboardCardChrome {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    DashboardBulletTitle(
                        title: displayTitle("Support"),
                        colors: [DashboardTheme.dangerRed, DashboardTheme.pickupOrange]
                    )
                    Text(
                        sales.isEmptyString
                        ? "Call for support and emergencies."
                        : "Call \(sales) for support and emergencies."
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .lineLimit(2)
                }
                Spacer(minLength: 8)
                Button(action: { onNavigate("support") }) {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                        Text("Call")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DashboardTheme.dangerRed)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var genericCard: some View {
        Button(action: {
            if !item.route.isEmptyString {
                onNavigate(item.route)
            }
        }) {
            DashboardCardChrome {
                VStack(alignment: .leading, spacing: 8) {
                    DashboardBulletTitle(title: displayTitle(item.route.replacingOccurrences(of: "_", with: " ").capitalized))
                    if payload?["in_time"] != nil {
                        DashboardStatRow(label: "In", value: payload?.string(for: "in_time") ?? "-")
                        DashboardStatRow(label: "Out", value: payload?.string(for: "out_time") ?? "-")
                    } else if let totalStaff = payload?.int(for: "totalStaff"), totalStaff > 0 {
                        DashboardStatRow(label: "Present", value: "\(payload?.int(for: "presentStaff") ?? 0)/\(totalStaff)")
                    } else if let totalRider = payload?.int(for: "totalRider"), totalRider > 0 {
                        DashboardStatRow(label: "Present", value: "\(payload?.int(for: "presentRider") ?? 0)/\(totalRider)")
                    } else if let pending = payload?.int(for: "pendingRequests"), pending > 0 {
                        DashboardPendingTag(count: pending, suffix: "Pending")
                    } else if let pendingLeave = payload?.int(for: "pendingLeaveCount"), pendingLeave > 0 {
                        DashboardPendingTag(count: pendingLeave, suffix: "Pending")
                    } else if let pendingRegularize = payload?.int(for: "pendingRegularizeCount"), pendingRegularize > 0 {
                        DashboardPendingTag(count: pendingRegularize, suffix: "Pending")
                    } else {
                        Text("Tap to open")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func displayTitle(_ fallback: String) -> String {
        item.title.isEmptyString ? fallback : item.title
    }

    private var todayDateString: String {
        DashboardDateFormat.todayString
    }

    private var scheduledSellers: [ScheduledSeller] {
        let list = payload?["scheduledRevisits"]?.arrayValue ?? payload?.arrayValue ?? []
        return list.compactMap { entry in
            let name = entry.string(for: "name", "seller_name")
            guard !name.isEmptyString else { return nil }
            return ScheduledSeller(
                id: entry.int(for: "id", "seller_id"),
                name: name,
                shopName: entry.string(for: "shopName", "shop_name")
            )
        }
    }

    private var staffActivityRows: [StaffActivityRow] {
        let list = payload?.arrayValue.isEmpty == false ? payload?.arrayValue ?? [] : payload?["data"]?.arrayValue ?? []
        return list.map { entry in
            let name = entry.string(for: "staff_name", "staffName", "name").trimmingCharacters(in: .whitespacesAndNewlines)
            let orders = entry.int(for: "today_orders_count", "todayOrdersCount", "orders_count")
            let sales = entry.double(for: "today_orders_total", "todayOrdersTotal", "orders_total")
            let collection = entry.double(for: "today_transactions_sum", "todayTransactionsSum", "transactions_sum")
            return StaffActivityRow(
                name: name,
                orders: orders,
                sales: sales,
                collection: collection
            )
        }
    }

    private func summaryCard(
        title: String,
        colors: [Color],
        stats: [(String, Int, Color)],
        primaryTitle: String,
        primaryColor: Color,
        secondaryTitle: String?,
        secondaryColor: Color,
        primaryAction: @escaping () -> Void = {},
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        DashboardCardChrome {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 8) {
                    DashboardBulletTitle(title: title, colors: colors)
                    HStack(spacing: 10) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                            HStack(spacing: 3) {
                                Image(systemName: stat.0)
                                    .font(.system(size: 12))
                                    .foregroundStyle(stat.2)
                                Text("\(stat.1)")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    DashboardCompactButton(title: primaryTitle, color: primaryColor, action: primaryAction)
                    if let secondaryTitle {
                        DashboardCompactButton(title: secondaryTitle, color: secondaryColor, action: secondaryAction ?? {})
                    }
                }
            }
        }
    }

    private func collectionSegments(cash: Double, upi: Double, cheque: Double) -> [DashboardChartSegment] {
        [
            DashboardChartSegment(value: cash, color: DashboardTheme.accentTeal),
            DashboardChartSegment(value: upi, color: DashboardTheme.secondaryPurple),
            DashboardChartSegment(value: cheque, color: DashboardTheme.primaryBlue)
        ].filter { $0.value > 0 }
    }

    private func orderStatusChartSegments(from today: JSONValue?) -> [DashboardChartSegment] {
        [
            DashboardChartSegment(value: Double(today?.int(for: "delivered") ?? 0), color: DashboardTheme.successGreen),
            DashboardChartSegment(value: Double(today?.int(for: "pending") ?? 0), color: DashboardTheme.warningYellow),
            DashboardChartSegment(value: Double(today?.int(for: "to_deliver", "toDeliver") ?? 0), color: DashboardTheme.infoBlue),
            DashboardChartSegment(value: Double(today?.int(for: "assigned") ?? 0), color: DashboardTheme.primaryBlue),
            DashboardChartSegment(value: Double(today?.int(for: "pickup") ?? 0), color: DashboardTheme.pickupOrange),
            DashboardChartSegment(value: Double(today?.int(for: "cancelled") ?? 0), color: DashboardTheme.dangerRed),
            DashboardChartSegment(value: Double(today?.int(for: "returned") ?? 0), color: DashboardTheme.neutralMedium)
        ].filter { $0.value > 0 }
    }

    private func orderStatusLegend(from today: JSONValue?) -> some View {
        let items: [(String, Int, Color)] = [
            ("Delivered", today?.int(for: "delivered") ?? 0, DashboardTheme.successGreen),
            ("Pending", today?.int(for: "pending") ?? 0, DashboardTheme.warningYellow),
            ("To Deliver", today?.int(for: "to_deliver", "toDeliver") ?? 0, DashboardTheme.infoBlue),
            ("Assigned", today?.int(for: "assigned") ?? 0, DashboardTheme.primaryBlue),
            ("Pickup", today?.int(for: "pickup") ?? 0, DashboardTheme.pickupOrange),
            ("Cancelled", today?.int(for: "cancelled") ?? 0, DashboardTheme.dangerRed),
            ("Returned", today?.int(for: "returned") ?? 0, DashboardTheme.neutralMedium)
        ]
        return VStack(spacing: 4) {
            ForEach(items.filter { $0.1 >= 0 }, id: \.0) { item in
                HStack(spacing: 6) {
                    Circle().fill(item.2).frame(width: 6, height: 6)
                    Text(item.0)
                        .font(.system(size: 10))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    Spacer()
                    Text("\(item.1)")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
        }
    }

    private func topSellingProducts(from today: JSONValue?, fallback: JSONValue? = nil) -> [TopSellingProduct] {
        var products = topSellingProductsFromArray(
            today?["productsCountAndAmount"] ?? today?["products_count_and_amount"]
        )

        if products.isEmpty {
            products = topSellingProductsFromMap(
                today?["topSellingProducts"] ?? fallback?["topSellingProducts"]
            )
        }

        return products
    }

    private func topSellingProductsFromArray(_ value: JSONValue?) -> [TopSellingProduct] {
        let list = value?.arrayValue ?? []
        return list.compactMap { entry in
            let name = entry.string(for: "productName", "product_name", "name")
            guard !name.isEmptyString, !isPlaceholderProductName(name) else { return nil }

            let quantity = entry.int(for: "totalQuantity", "total_quantity", "count", "quantity")
            let amount = entry.double(for: "totalAmount", "total_amount", "amount")
            guard quantity > 0 || amount > 0 else { return nil }

            return TopSellingProduct(name: name, quantity: quantity, amount: amount)
        }
    }

    private func topSellingProductsFromMap(_ value: JSONValue?) -> [TopSellingProduct] {
        guard let object = value?.objectValue, !object.isEmpty else { return [] }

        return object
            .map { key, entry in
                TopSellingProduct(
                    name: key,
                    quantity: entry.intValue,
                    amount: entry.doubleValue
                )
            }
            .filter { product in
                !isPlaceholderProductName(product.name) && (product.quantity > 0 || product.amount > 0)
            }
            .sorted { lhs, rhs in
                if lhs.quantity != rhs.quantity { return lhs.quantity > rhs.quantity }
                return lhs.amount > rhs.amount
            }
    }

    private func isPlaceholderProductName(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "no products" || normalized == "no product"
    }

    @ViewBuilder
    private func topSellingProductsSection(
        _ products: [TopSellingProduct],
        showViewMore: Bool = true,
        onViewMore: (() -> Void)? = nil
    ) -> some View {
        DashboardSectionHeader(title: "Top Selling Products")
        if products.isEmpty {
            Text("No top selling products to show.")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        } else {
            VStack(spacing: 10) {
                ForEach(products.prefix(5)) { product in
                    HStack {
                        Text(product.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(topSellingProductDetail(for: product))
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }
            }
            if showViewMore {
                DashboardOutlinedButton(title: "View More", systemImage: "arrow.right") {
                    onViewMore?()
                }
            }
        }
    }

    private func topSellingProductDetail(for product: TopSellingProduct) -> String {
        if product.amount > 0 && product.quantity > 0 {
            return "\(product.quantity) units | \(product.amount.currencyLabel)"
        }
        if product.quantity > 0 {
            return "\(product.quantity) units"
        }
        return product.amount.currencyLabel
    }

    private func paymentAmount(from transactions: JSONValue?, mode: String) -> Double {
        let buckets = ["Approved", "Pending", "Rejected"]
        return buckets.reduce(0.0) { partial, bucket in
            partial + (transactions?[bucket]?.double(for: mode) ?? 0)
        }
    }

    private func paymentCount(from transactions: JSONValue?, mode: String) -> Int {
        let buckets = ["Approved", "Pending", "Rejected"]
        return buckets.reduce(0) { partial, bucket in
            partial + (transactions?[bucket]?.int(for: mode) ?? 0)
        }
    }

    private func paymentLegendItem(color: Color, title: String, count: Int, amount: Double, total: Double) -> some View {
        let percent = total > 0 ? Int((amount / total) * 100) : 0
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            Text("\(count) payments")
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(amount.currencyLabel)
                .font(.system(size: 13, weight: .bold))
            Text("\(percent)%")
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
    }

    private func statBlock(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
    }
}

private struct ScheduledSeller: Identifiable {
    let id: Int
    let name: String
    let shopName: String
}

private struct ScheduledSellerAvatar: View {
    let seller: ScheduledSeller
    var onLongPress: () -> Void = {}

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 2)
                    .frame(width: 58, height: 58)
                Circle()
                    .fill(DashboardTheme.primaryBlue.opacity(0.08))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Text(seller.initials)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }
            }
            Text(seller.name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .frame(width: 84)
            Text(seller.shopName)
                .font(.system(size: 10))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .lineLimit(1)
                .frame(width: 84)
        }
        .onLongPressGesture(minimumDuration: 0.7) {
            onLongPress()
        }
    }
}

private extension ScheduledSeller {
    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

private struct StaffActivityRow {
    let name: String
    let orders: Int
    let sales: Double
    let collection: Double
}

private struct TopSellingProduct: Identifiable {
    let id = UUID()
    let name: String
    let quantity: Int
    let amount: Double
}

struct DashboardStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

struct OperationsCard: View {
    let operations: [String]
    var onOperationTap: (String) -> Void = { _ in }

    /// Matches Android `ProfessionalLightColors.TileColors`.
    private let tileColors: [[Color]] = [
        [Color(hex: "E0F7FA"), Color(hex: "B2EBF2")],
        [Color(hex: "E8F5E9"), Color(hex: "C8E6C9")],
        [Color(hex: "FFF3E0"), Color(hex: "FFE0B2")],
        [Color(hex: "EDE7F6"), Color(hex: "D1C4E9")],
        [Color(hex: "F3E5F5"), Color(hex: "E1BEE7")],
        [Color(hex: "E1F5FE"), Color(hex: "B3E5FC")],
        [Color(hex: "F0F4C3"), Color(hex: "E6EE9C")],
        [Color(hex: "FFFDE7"), Color(hex: "FFF9C4")],
        [Color(hex: "F1F8E9"), Color(hex: "DCEDC8")],
        [Color(hex: "E0F2F1"), Color(hex: "B2DFDB")],
        [Color(hex: "FAFAFA"), Color(hex: "F5F5F5")],
        [Color(hex: "ECEFF1"), Color(hex: "CFD8DC")]
    ]

    var body: some View {
        DashboardCardChrome {
            VStack(alignment: .leading, spacing: 14) {
                DashboardBulletTitle(title: "Other Operations")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(operations.enumerated()), id: \.element) { index, title in
                        let colors = tileColors[index % tileColors.count]
                        Button {
                            onOperationTap(title)
                        } label: {
                            Text(title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(
                                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
