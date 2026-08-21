//
//  QuickShareScreen.swift
//  Truedata
//

import SwiftUI

struct QuickShareScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QuickShareViewModel()
    @State private var showFilterSheet = false

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Quick Share",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.refresh() }
                )

                ScrollView {
                    VStack(spacing: 12) {
                        dateCard
                        viewModeToggle

                        if viewModel.viewMode == .exportAll {
                            exportButton
                        } else {
                            ordersContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, viewModel.viewMode == .selectOrders && !viewModel.selectedOrderIds.isEmpty ? 90 : 24)
                }
            }

            if viewModel.viewMode == .selectOrders && !viewModel.selectedOrderIds.isEmpty {
                VStack {
                    Spacer()
                    Button {
                        viewModel.exportInvoicePDF()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 18, weight: .semibold))

                            Text("Generate Bulk Invoice (\(viewModel.selectedOrderIds.count))")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(DashboardTheme.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isExporting)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }

            if viewModel.isExporting {
                Color.black.opacity(0.12).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                    Text("Generating PDF...")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                }
                .padding(24)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadInitial() }
        .sheet(isPresented: $showFilterSheet) {
            QuickShareFilterSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.exportShareURL != nil },
            set: { isPresented in
                if !isPresented { viewModel.exportShareURL = nil }
            }
        )) {
            if let url = viewModel.exportShareURL {
                ActivityShareSheet(items: [url])
            }
        }
        .alert("Export Failed", isPresented: Binding(
            get: { viewModel.exportAlertMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.exportAlertMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.exportAlertMessage ?? "")
        }
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                Text("Date")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text("*")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.dangerRed)

                Spacer()

                Button { showFilterSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 12, weight: .semibold))
                        Text(viewModel.hasActiveFilters ? "Filtered" : "Filters")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.hasActiveFilters ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(
                                viewModel.hasActiveFilters
                                    ? DashboardTheme.primaryBlue
                                    : DashboardTheme.neutralMedium.opacity(0.5),
                                lineWidth: 1
                            )
                    }
                }
                .buttonStyle(.plain)
            }

            QuickShareDateField(dateString: viewModel.selectedDate) { date in
                viewModel.onDateChanged(date)
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }

    private var viewModeToggle: some View {
        HStack(spacing: 4) {
            ForEach(QuickShareViewMode.allCases) { mode in
                Button {
                    viewModel.onViewModeChanged(mode)
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: viewModel.viewMode == mode ? .semibold : .medium))
                        .foregroundStyle(viewModel.viewMode == mode ? .white : DashboardTheme.neutralDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(viewModel.viewMode == mode ? DashboardTheme.primaryBlue : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(hex: "E9ECEF").opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var exportButton: some View {
        Button {
            viewModel.exportInvoicePDF()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                Text(exportButtonTitle)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(DashboardTheme.primaryBlue)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isExporting)
    }

    private var exportButtonTitle: String {
        if viewModel.viewMode == .selectOrders, !viewModel.selectedOrderIds.isEmpty {
            return "Generate Bulk Invoice (\(viewModel.selectedOrderIds.count))"
        }
        return "Export Invoice PDF"
    }

    @ViewBuilder
    private var ordersContent: some View {
        if viewModel.isLoadingOrders && viewModel.orders.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if viewModel.orders.isEmpty {
            Text("No orders found for selected date and filters.")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            if !viewModel.selectedOrderIds.isEmpty {
                HStack {
                    Text("\(viewModel.selectedOrderIds.count) order(s) selected")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    Spacer()
                    Button("Clear") {
                        viewModel.selectedOrderIds.removeAll()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.dangerRed)
                }
            }

            LazyVStack(spacing: 10) {
                ForEach(viewModel.orders) { order in
                    QuickShareOrderRow(
                        order: order,
                        isSelected: viewModel.selectedOrderIds.contains(order.id)
                    ) {
                        viewModel.toggleOrderSelection(order.id)
                    }
                    .onAppear {
                        viewModel.loadMoreOrdersIfNeeded(currentOrder: order)
                    }
                }

                if viewModel.isLoadingMoreOrders {
                    ProgressView()
                        .padding(.vertical, 12)
                }
            }
        }
    }
}

private struct QuickShareDateField: View {
    let dateString: String
    var onDateSelected: (String) -> Void

    @State private var showPicker = false

    var body: some View {
        Button { showPicker = true } label: {
            HStack {
                Text(dateString)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.darkMidnightBlue)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            DashboardDatePickerSheetWrapper(
                initialDate: OrderInsightsDateFormat.parse(dateString) ?? Date(),
                onCancel: { showPicker = false },
                onConfirm: { date in
                    onDateSelected(OrderInsightsDateFormat.string(from: date))
                    showPicker = false
                }
            )
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
        }
    }
}

private struct DashboardDatePickerSheetWrapper: View {
    let initialDate: Date
    var onCancel: () -> Void
    var onConfirm: (Date) -> Void

    @State private var selectedDate: Date

    init(initialDate: Date, onCancel: @escaping () -> Void, onConfirm: @escaping (Date) -> Void) {
        self.initialDate = initialDate
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        VStack(spacing: 16) {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(DashboardTheme.primaryBlue)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .foregroundStyle(DashboardTheme.primaryBlue)
                Button("OK") { onConfirm(selectedDate) }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(DashboardTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(16)
        .background(AppTheme.aliceBlue)
    }
}

private struct QuickShareOrderRow: View {
    let order: OrderInsightsOrder
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(order.orderNo)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                            
                            Text(order.orderDate)
                                .font(.system(size: 12))
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Text("₹\(order.totalAmount.priceLabel)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                    }
                    
                    Text(order.sellerName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralDark)

                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                        Text("Mobile: \(order.sellerPhone)")
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)
                            Text("Staff: \(order.staffName)")
                                .font(.system(size: 11))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.gray)
                            Text("Rider: \(order.riderName.isEmptyString ? "not assigned" : order.riderName)")
                                .font(.system(size: 11))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                    }

                    Text(order.status)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? DashboardTheme.primaryBlue : Color(hex: "E5E7EB"), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch order.status.lowercased() {
        case "pending":
            return Color.orange
        case "delivered":
            return Color.green
        case "cancelled":
            return Color.red
        default:
            return DashboardTheme.primaryBlue
        }
    }
}
