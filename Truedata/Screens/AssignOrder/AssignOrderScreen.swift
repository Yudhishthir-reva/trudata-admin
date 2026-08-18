//
//  AssignOrderScreen.swift
//  Truedata
//

import SwiftUI

struct AssignOrderScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AssignOrderViewModel()
    @State private var searchText = ""

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                AssignOrderAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: {
                        viewModel.loadBootstrapData()
                        viewModel.loadOrdersForSelectedBeats()
                    }
                )

                ScrollView {
                    LazyVStack(spacing: 10) {
                        assignmentSummary

                        if viewModel.isLoading {
                            ProgressView()
                                .tint(DashboardTheme.primaryBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }

                        if let error = viewModel.errorMessage {
                            errorCard(error)
                        }

                        mainContent
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, viewModel.canAssign ? 110 : 24)
                }
            }

            if viewModel.canAssign {
                assignBar
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $viewModel.showSelectionSheet) {
            AssignOrderSelectionSheet(viewModel: viewModel)
                .presentationDetents([.fraction(0.78)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.hidden)
        }
        .alert("Success", isPresented: $viewModel.showSuccessAlert) {
            Button("OK") {}
        } message: {
            Text(viewModel.successMessage)
        }
    }

    // MARK: - Summary

    private var assignmentSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Assignment Summary")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Spacer()
                Button {
                    viewModel.selectionStep = .rider
                    viewModel.showSelectionSheet = true
                } label: {
                    Text("Edit")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DashboardTheme.primaryBlue.opacity(0.1))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(DashboardTheme.primaryBlue.opacity(0.3), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                summaryChip(
                    icon: "person.fill",
                    text: viewModel.selectedRider?.name ?? "No rider",
                    isActive: viewModel.selectedRider != nil
                )
                summaryChip(
                    icon: "car.fill",
                    text: vehicleSummaryText,
                    isActive: viewModel.selectedVehicle != nil
                )
                summaryChip(
                    icon: "mappin.and.ellipse",
                    text: beatsSummaryText,
                    isActive: !viewModel.selectedBeats.isEmpty,
                    badge: viewModel.selectedBeats.isEmpty ? nil : "\(viewModel.selectedBeats.count)"
                )
            }

            if !viewModel.selectedOrderIds.isEmpty {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.successGreen)
                    Text("\(viewModel.selectedOrderIds.count) order(s) selected")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.successGreen)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 0.5)
        }
    }

    private var vehicleSummaryText: String {
        guard let vehicle = viewModel.selectedVehicle else { return "No vehicle" }
        if vehicle.noPlate.isEmptyString { return vehicle.name }
        return "\(vehicle.name) (\(vehicle.noPlate))"
    }

    private var beatsSummaryText: String {
        guard !viewModel.selectedBeats.isEmpty else { return "No beats" }
        if viewModel.selectedBeats.count == 1 {
            return viewModel.selectedBeats[0].name
        }
        return "\(viewModel.selectedBeats.count) beats"
    }

    private func summaryChip(icon: String, text: String, isActive: Bool, badge: String? = nil) -> some View {
        HStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                if let badge {
                    Text(badge)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(DashboardTheme.primaryBlue)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content

    @ViewBuilder
    private var mainContent: some View {
        if viewModel.selectedRider == nil || viewModel.selectedVehicle == nil || viewModel.selectedBeats.isEmpty {
            AssignOrderEmptyState(
                title: "Select Rider, Vehicle & Beats",
                description: "Choose a rider, vehicle and beats to view unassigned orders",
                actionTitle: "Select Now"
            ) {
                viewModel.selectionStep = .rider
                viewModel.showSelectionSheet = true
            }
        } else if viewModel.orders.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil {
            AssignOrderEmptyState(
                title: "No Unassigned Orders",
                description: "All orders in selected beats are already assigned",
                actionTitle: "Change Selection"
            ) {
                viewModel.selectionStep = .rider
                viewModel.showSelectionSheet = true
            }
        } else {
            orderListContent
        }
    }

    private var orderListContent: some View {
        Group {
            if viewModel.selectedBeats.count == viewModel.beats.count && !viewModel.beats.isEmpty {
                orderSearchField
                ForEach(filteredOrders) { order in
                    AssignOrderRow(
                        order: order,
                        isSelected: viewModel.selectedOrderIds.contains(order.id),
                        onToggle: { viewModel.toggleOrder(order.id) }
                    )
                }
            } else {
                ForEach(viewModel.groupedOrders, id: \.beat.id) { group in
                    beatSection(beat: group.beat, orders: group.orders)
                }
            }
        }
    }

    private func beatSection(beat: BeatWithOrdersItem, orders: [AssignOrderItem]) -> some View {
        let isExpanded = viewModel.expandedBeatId == beat.id
        let selectedCount = orders.filter { viewModel.selectedOrderIds.contains($0.id) }.count
        let filtered = searchText.isEmpty
            ? orders
            : orders.filter { $0.sellerShopName.localizedCaseInsensitiveContains(searchText) }

        return VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    viewModel.expandedBeatId = isExpanded ? nil : beat.id
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(beat.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(selectedCount) of \(orders.count) orders selected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    Spacer()
                    if selectedCount > 0 {
                        Text("\(selectedCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(DashboardTheme.primaryBlue)
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(DashboardTheme.neutralDark)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                orderSearchField
                ForEach(filtered) { order in
                    AssignOrderRow(
                        order: order,
                        isSelected: viewModel.selectedOrderIds.contains(order.id),
                        onToggle: { viewModel.toggleOrder(order.id) }
                    )
                }
            }
        }
    }

    private var orderSearchField: some View {
        AssignOrderSearchField(
            placeholder: "Search orders by shop name...",
            text: $searchText
        )
    }

    private var filteredOrders: [AssignOrderItem] {
        guard !searchText.isEmpty else { return viewModel.orders }
        return viewModel.orders.filter { $0.sellerShopName.localizedCaseInsensitiveContains(searchText) }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.errorRed)
                .multilineTextAlignment(.center)
            DashboardOutlinedButton(title: "Retry") {
                viewModel.loadOrdersForSelectedBeats()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var assignBar: some View {
        VStack {
            Spacer()
            Button {
                viewModel.assignOrdersToRider()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Assign \(viewModel.selectedOrderIds.count) Order(s)")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DashboardTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .background(
                Color.white
                    .shadow(color: .black.opacity(0.08), radius: 10, y: -2)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

// MARK: - App Bar

private struct AssignOrderAppBar: View {
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("Assign Order to Rider")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }

            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
    }
}

// MARK: - Empty State

private struct AssignOrderEmptyState: View {
    let title: String
    let description: String
    let actionTitle: String
    var action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "clipboard")
                .font(.system(size: 34))
                .foregroundStyle(DashboardTheme.neutralMedium)

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .multilineTextAlignment(.center)

            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(DashboardTheme.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Search Field

private struct AssignOrderSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField(placeholder, text: $text)
                .font(.system(size: 14, weight: .medium))
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Order Row

private struct AssignOrderRow: View {
    let order: AssignOrderItem
    let isSelected: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 6) {
                            Text(order.invoiceId)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DashboardTheme.infoBlue)
                            if order.orderNotDelivered {
                                Text("Rescheduled")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(AppTheme.errorRed)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.errorRedBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                        }
                        Spacer()
                        Text("₹\(order.totalAmount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DashboardTheme.primaryBlue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    infoLine(icon: "person.fill", label: "Sale Person", value: order.staffName)

                    Divider().opacity(0.4)

                    infoLine(icon: "storefront.fill", label: "Shop • Date", value: "\(order.sellerShopName) • \(order.date)")

                    if !order.sellerAddress.isEmptyString {
                        infoLine(icon: "mappin.and.ellipse", label: "Address", value: order.sellerAddress)
                    }
                }
            }
            .padding(10)
            .background(isSelected ? DashboardTheme.primaryBlue.opacity(0.04) : Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.surfaceVariant, lineWidth: isSelected ? 1 : 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func infoLine(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Selection Sheet

private struct AssignOrderSelectionSheet: View {
    @ObservedObject var viewModel: AssignOrderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView {
                VStack(spacing: 10) {
                    AssignOrderSearchField(
                        placeholder: searchPlaceholder,
                        text: $searchText
                    )

                    stepContent
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            sheetBottomActions
        }
        .background(Color.white)
        .onChange(of: viewModel.selectionStep) { _, _ in
            searchText = ""
        }
    }

    private var searchPlaceholder: String {
        switch viewModel.selectionStep {
        case .rider: return "Search riders..."
        case .vehicle: return "Search vehicles..."
        case .beats: return "Search beats..."
        }
    }

    private var sheetHeader: some View {
        HStack(spacing: 8) {
            if viewModel.selectionStep != .rider {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectionStep = AssignOrderSelectionStep(rawValue: viewModel.selectionStep.rawValue - 1) ?? .rider
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .frame(width: 32, height: 32)
                }
            }

            Text(viewModel.selectionStep.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)

            Spacer()

            AssignOrderStepIndicator(currentStep: viewModel.selectionStep, viewModel: viewModel)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.selectionStep {
        case .rider:
            riderStep
        case .vehicle:
            vehicleStep
        case .beats:
            beatsStep
        }
    }

    private var riderStep: some View {
        LazyVStack(spacing: 6) {
            if filteredRiders.isEmpty {
                emptyListText("No riders available")
            } else {
                ForEach(filteredRiders) { rider in
                    RiderSelectionCard(
                        name: rider.name,
                        isSelected: viewModel.selectedRider?.id == rider.id
                    ) {
                        viewModel.selectedRider = rider
                    }
                }
            }
        }
    }

    private var vehicleStep: some View {
        LazyVStack(spacing: 6) {
            if viewModel.vehicles.isEmpty {
                emptyListText("No available vehicles")
            } else {
                ForEach(filteredVehicles) { vehicle in
                    VehicleSelectionCard(
                        vehicle: vehicle,
                        isSelected: viewModel.selectedVehicle?.id == vehicle.id
                    ) {
                        guard vehicle.isSelectable else { return }
                        viewModel.selectedVehicle = vehicle
                    }
                }
            }
        }
    }

    private var beatsStep: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    viewModel.selectAllBeats(!isAllBeatsSelected, from: filteredBeats)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isAllBeatsSelected ? "checkmark.square.fill" : "square")
                            .foregroundStyle(isAllBeatsSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                        Text("Select All")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                if !viewModel.selectedBeats.isEmpty {
                    Text("\(viewModel.selectedBeats.count) beat(s) selected")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DashboardTheme.primaryBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(filteredBeats) { beat in
                    BeatSelectionChip(
                        title: beat.name,
                        isSelected: viewModel.selectedBeats.contains(where: { $0.id == beat.id })
                    ) {
                        viewModel.toggleBeatSelection(beat)
                    }
                }
            }
        }
    }

    private var isAllBeatsSelected: Bool {
        !filteredBeats.isEmpty &&
        filteredBeats.allSatisfy { beat in viewModel.selectedBeats.contains(where: { $0.id == beat.id }) }
    }

    private var filteredRiders: [RiderItem] {
        guard !searchText.isEmpty else { return viewModel.riders }
        return viewModel.riders.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredVehicles: [VehicleItem] {
        guard !searchText.isEmpty else { return viewModel.vehicles }
        return viewModel.vehicles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.noPlate.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredBeats: [BeatWithOrdersItem] {
        guard !searchText.isEmpty else { return viewModel.beats }
        return viewModel.beats.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func emptyListText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(DashboardTheme.neutralMedium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    private var sheetBottomActions: some View {
        HStack(spacing: 8) {
            if viewModel.selectionStep != .rider {
                Button("Back") {
                    withAnimation {
                        viewModel.selectionStep = AssignOrderSelectionStep(rawValue: viewModel.selectionStep.rawValue - 1) ?? .rider
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button(viewModel.selectionStep == .beats ? "Apply" : "Next") {
                if viewModel.selectionStep == .beats {
                    viewModel.completeSelectionIfPossible()
                    dismiss()
                } else {
                    viewModel.goToNextSelectionStep()
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(canProceed ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(!canProceed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    private var canProceed: Bool {
        switch viewModel.selectionStep {
        case .rider: return viewModel.selectedRider != nil
        case .vehicle: return viewModel.selectedVehicle != nil
        case .beats: return !viewModel.selectedBeats.isEmpty
        }
    }
}

// MARK: - Step Indicator

private struct AssignOrderStepIndicator: View {
    let currentStep: AssignOrderSelectionStep
    @ObservedObject var viewModel: AssignOrderViewModel

    var body: some View {
        HStack(spacing: 4) {
            stepCircle(number: 1, isActive: currentStep == .rider, isCompleted: viewModel.selectedRider != nil)
            connector
            stepCircle(number: 2, isActive: currentStep == .vehicle, isCompleted: viewModel.selectedVehicle != nil)
            connector
            stepCircle(number: 3, isActive: currentStep == .beats, isCompleted: !viewModel.selectedBeats.isEmpty)
        }
    }

    private var connector: some View {
        Rectangle()
            .fill(DashboardTheme.surfaceVariant)
            .frame(width: 12, height: 2)
            .clipShape(Capsule())
    }

    private func stepCircle(number: Int, isActive: Bool, isCompleted: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    isCompleted ? DashboardTheme.successGreen :
                    isActive ? DashboardTheme.primaryBlue :
                    DashboardTheme.surfaceVariant
                )
                .frame(width: 24, height: 24)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(number)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? .white : DashboardTheme.neutralMedium)
            }
        }
    }
}

// MARK: - Selection Cards

private struct RiderSelectionCard: View {
    let name: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.surfaceVariant)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(isSelected ? .white : DashboardTheme.neutralMedium)
                    }

                Text(name)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralDark)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
            }
            .padding(10)
            .background(isSelected ? DashboardTheme.primaryBlue.opacity(0.06) : Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.surfaceVariant, lineWidth: isSelected ? 1.5 : 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct VehicleSelectionCard: View {
    let vehicle: VehicleItem
    let isSelected: Bool
    var action: () -> Void

    private var statusColor: Color {
        switch vehicle.inUse {
        case "0": return DashboardTheme.successGreen
        case "1": return DashboardTheme.warningYellow
        case "2": return DashboardTheme.dangerRed
        default: return DashboardTheme.neutralMedium
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(
                        isSelected ? DashboardTheme.primaryBlue :
                        vehicle.isSelectable ? DashboardTheme.surfaceVariant :
                        DashboardTheme.surfaceVariant.opacity(0.6)
                    )
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "car.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(
                                isSelected ? .white :
                                vehicle.isSelectable ? DashboardTheme.neutralMedium :
                                DashboardTheme.neutralMedium.opacity(0.5)
                            )
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle.name)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(
                            isSelected ? DashboardTheme.primaryBlue :
                            vehicle.isSelectable ? DashboardTheme.neutralDark :
                            DashboardTheme.neutralMedium.opacity(0.6)
                        )

                    HStack(spacing: 6) {
                        Text(vehicle.noPlate)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralMedium)

                        Text(vehicle.usageStatusLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }

                    if vehicle.isAssignedToAnotherRider {
                        Text("Assigned to: \(vehicle.riderName)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(hex: "F59E0B"))
                    }
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DashboardTheme.primaryBlue)
                } else if !vehicle.isSelectable {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.5))
                }
            }
            .padding(12)
            .background(
                isSelected ? DashboardTheme.primaryBlue.opacity(0.06) :
                vehicle.isSelectable ? Color.white :
                Color.white.opacity(0.55)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? DashboardTheme.primaryBlue : Color.clear, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!vehicle.isSelectable)
    }
}

private struct BeatSelectionChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralDark)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .padding(.horizontal, 8)
                .background(isSelected ? DashboardTheme.primaryBlue.opacity(0.12) : Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.surfaceVariant, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AssignOrderScreen()
    }
}
