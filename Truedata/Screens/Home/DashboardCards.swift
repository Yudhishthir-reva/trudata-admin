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
            action: {}
        )
    }

    // MARK: - Scheduled revisits

    private var scheduledRevisitsCard: some View {
        let sellers = scheduledSellers
        return DashboardCardChrome(cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                DashboardBulletTitle(title: displayTitle("Scheduled Revisits"), systemImage: "clock.fill")

                if sellers.isEmpty {
                    Text("No revisits scheduled today.")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.neutralMedium)
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
                                ScheduledSellerAvatar(seller: seller)
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
        let today = payload?["todayOrders"] ?? payload
        let payModes = today?["paymentCollectionByPayMode"]
        let cash = payModes?.double(for: "cashAmount", "CashAmount") ?? 0
        let upi = payModes?.double(for: "upiAmount", "UPIAmount") ?? 0
        let cheque = payModes?.double(for: "chequeAmount", "ChequeAmount") ?? 0
        let totalCollection = cash + upi + cheque
        let totalAmount = today?.double(for: "todayTotalAmount", "today_total_amount") ?? 0
        let deliveredAmount = today?.double(for: "todayDeliveredAmount", "today_delivered_amount") ?? 0
        let pendingAmount = today?.double(for: "todayPendingAmount", "today_pending_amount") ?? 0
        let settledAmount = today?.double(for: "todayApprovedCollectionAmount", "todayCollectionAmount") ?? 0
        let products = topSellingProducts(from: today)

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

                if settledAmount > 0 {
                    DashboardSectionHeader(title: "Today's Collection")
                    VStack(spacing: 4) {
                        Text("Settled Amount")
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        Text(settledAmount.currencyLabel)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DashboardTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if !products.isEmpty {
                    DashboardSectionHeader(title: "Top Selling Products")
                    VStack(spacing: 10) {
                        ForEach(products.prefix(5)) { product in
                            HStack {
                                Text(product.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(DashboardTheme.neutralDark)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(product.quantity) units | \(product.amount.currencyLabel)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DashboardTheme.neutralMedium)
                            }
                        }
                    }
                    DashboardOutlinedButton(title: "View More", systemImage: "arrow.right")
                }

                let validOrders = today?.int(for: "totalWithoutCancelled") ?? today?.int(for: "pending") ?? 0
                if validOrders > 0 {
                    DashboardSectionHeader(title: "Total Valid Orders")
                    Text("\(validOrders)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DashboardTheme.surfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                    Text("View History >")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
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
                    DashboardCompactButton(title: "Settle Pending Bills", color: DashboardTheme.warningYellow, action: {})
                }
            }

            DashboardCardChrome {
                VStack(alignment: .leading, spacing: 12) {
                    DashboardBulletTitle(title: "All Time Orders")
                    HStack(spacing: 8) {
                        DashboardStatPill(title: "Pending", value: "\(orders?.int(for: "pending") ?? 0)", valueColor: DashboardTheme.warningYellow)
                        DashboardStatPill(title: "Dispatched", value: "\(orders?.int(for: "to_deliver", "toDeliver") ?? 0)", valueColor: DashboardTheme.infoBlue)
                        DashboardStatPill(title: "Delivered", value: "\(orders?.int(for: "delivered") ?? 0)", valueColor: DashboardTheme.successGreen)
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
                DashboardCompactButton(title: "View Summary →", color: DashboardTheme.warningYellow, action: {})
            }
        }
    }

    // MARK: - Staff

    private var staffActivitiesCard: some View {
        let activities = staffActivityRows
        let showAmounts = ["admin", "sales manager"].contains(role.lowercased())
        return DashboardCardChrome(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DashboardTheme.primaryBlue)
                        .frame(width: 4, height: 18)
                    Text(displayTitle("Today Staff Activities"))
                        .font(.system(size: 17, weight: .bold))
                }

                HStack {
                    Text("#").frame(width: 24)
                    Text("STAFF").frame(maxWidth: .infinity, alignment: .leading)
                    Text("ORDERS").frame(width: 70, alignment: .trailing)
                    if showAmounts {
                        Text("SALES / COLLEC.").frame(width: 110, alignment: .trailing)
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)

                if activities.isEmpty {
                    Text("No staff activity today.")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                } else {
                    ForEach(Array(activities.prefix(5).enumerated()), id: \.offset) { index, row in
                        HStack {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(index == 0 ? DashboardTheme.pickupOrange : DashboardTheme.neutralMedium)
                                .frame(width: 24)
                            Text(row.name)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(row.orders) orders")
                                .font(.system(size: 12))
                                .frame(width: 70, alignment: .trailing)
                            if showAmounts {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(row.sales.currencyLabel)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(DashboardTheme.pickupOrange)
                                    Text(row.collection.currencyLabel)
                                        .font(.system(size: 11))
                                }
                                .frame(width: 110, alignment: .trailing)
                            }
                        }
                    }
                    DashboardOutlinedButton(title: "View All Activities", systemImage: "arrow.right")
                }
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
                DashboardOutlinedButton(title: "View Staff", systemImage: "arrow.right")
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
                    DashboardCompactButton(title: "View", color: DashboardTheme.dangerRed, action: {})
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
                    DashboardCompactButton(title: "View", action: {})
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
                Button(action: {}) {
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
            secondaryColor: DashboardTheme.successGreen
        )
    }

    private var productsCard: some View {
        let total = payload?.int(for: "allProducts", "all_products") ?? 0
        let active = payload?.int(for: "activeProducts", "active_products") ?? 0
        let inactive = payload?.int(for: "inactiveProducts", "inactive_products") ?? 0
        return summaryCard(
            title: displayTitle("Products"),
            colors: [DashboardTheme.infoBlue, DashboardTheme.primaryBlue],
            stats: [
                ("square.stack.3d.up.fill", total, DashboardTheme.infoBlue),
                ("checkmark.circle.fill", active, DashboardTheme.successGreen),
                ("pause.circle.fill", inactive, DashboardTheme.neutralMedium)
            ],
            primaryTitle: "View Products →",
            primaryColor: DashboardTheme.infoBlue,
            secondaryTitle: nil,
            secondaryColor: DashboardTheme.infoBlue
        )
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

    private var genericCard: some View {
        DashboardCardChrome {
            VStack(alignment: .leading, spacing: 8) {
                DashboardBulletTitle(title: displayTitle(item.route.replacingOccurrences(of: "_", with: " ").capitalized))
                if payload?["in_time"] != nil {
                    DashboardStatRow(label: "In", value: payload?.string(for: "in_time") ?? "-")
                    DashboardStatRow(label: "Out", value: payload?.string(for: "out_time") ?? "-")
                } else if let pending = payload?.int(for: "pendingRequests"), pending > 0 {
                    DashboardPendingTag(count: pending, suffix: "Pending")
                } else {
                    Text("Tap to open")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
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
        return list.compactMap { entry in
            let name = entry.string(for: "staff_name", "staffName", "name")
            guard !name.isEmptyString else { return nil }
            return StaffActivityRow(
                name: name,
                orders: entry.int(for: "today_orders_count", "todayOrdersCount"),
                sales: entry.double(for: "today_orders_total", "todayOrdersTotal"),
                collection: entry.double(for: "today_transactions_sum", "todayTransactionsSum")
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
        secondaryColor: Color
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
                    DashboardCompactButton(title: primaryTitle, color: primaryColor, action: {})
                    if let secondaryTitle {
                        DashboardCompactButton(title: secondaryTitle, color: secondaryColor, action: {})
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

    private func topSellingProducts(from today: JSONValue?) -> [TopSellingProduct] {
        let list = today?["productsCountAndAmount"]?.arrayValue ?? today?["products_count_and_amount"]?.arrayValue ?? []
        return list.compactMap { entry in
            let name = entry.string(for: "productName", "product_name")
            guard !name.isEmptyString else { return nil }
            return TopSellingProduct(
                name: name,
                quantity: entry.int(for: "totalQuantity", "total_quantity"),
                amount: entry.double(for: "totalAmount", "total_amount")
            )
        }
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

    private let tileColors: [[Color]] = [
        [Color(hex: "E0F7FA"), Color(hex: "B2EBF2")],
        [Color(hex: "E8F5E9"), Color(hex: "C8E6C9")],
        [Color(hex: "FFF3E0"), Color(hex: "FFE0B2")],
        [Color(hex: "EDE7F6"), Color(hex: "D1C4E9")]
    ]

    var body: some View {
        DashboardCardChrome {
            VStack(alignment: .leading, spacing: 14) {
                DashboardBulletTitle(title: "Other Operations")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(operations.enumerated()), id: \.element) { index, title in
                        let colors = tileColors[index % tileColors.count]
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
}
