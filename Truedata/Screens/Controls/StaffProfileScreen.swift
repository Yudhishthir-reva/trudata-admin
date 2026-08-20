//
//  StaffProfileScreen.swift
//  Truedata
//

import SwiftUI

struct StaffProfileScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: StaffProfileViewModel
    @State private var selectedAttendanceItem: AttendanceHistoryItem?
    @State private var mapErrorMessage: String?

    init(context: StaffProfileContext) {
        _viewModel = StateObject(wrappedValue: StaffProfileViewModel(context: context))
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: viewModel.screenTitle,
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.refreshCurrentTab() }
                )

                ScrollView {
                    VStack(spacing: 0) {
                        profileHeader
                        mapButton
                        tabBar
                        tabContent
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadInitialData() }
        .sheet(item: $selectedAttendanceItem) { item in
            AttendanceDetailSheet(item: item) {
                selectedAttendanceItem = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Notice", isPresented: mapAlertBinding) {
            Button("OK") { mapErrorMessage = nil }
        } message: {
            Text(mapErrorMessage ?? "")
        }
    }

    private var mapAlertBinding: Binding<Bool> {
        Binding(get: { mapErrorMessage != nil }, set: { if !$0 { mapErrorMessage = nil } })
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Group {
                if viewModel.context.profilePic.isEmptyString {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.45))
                } else {
                    RemoteImage(url: viewModel.context.profilePic, contentMode: .fill)
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .background(Circle().fill(DashboardTheme.surfaceVariant))

            Text(viewModel.context.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .multilineTextAlignment(.center)

            Text("\(viewModel.context.displayStaffId) • \(viewModel.context.role)")
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var mapButton: some View {
        Button {
            openLatestLocationOnMap()
        } label: {
            Text("View location on map")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DashboardTheme.primaryBlue)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(StaffProfileTab.allCases) { tab in
                let isSelected = viewModel.selectedTab == tab
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? DashboardTheme.primaryBlue : AppTheme.aliceBlue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .attendance:
            attendanceContent
        case .location:
            locationContent
        }
    }

    @ViewBuilder
    private var attendanceContent: some View {
        if viewModel.isLoadingAttendance && viewModel.attendanceItems.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let error = viewModel.attendanceError, viewModel.attendanceItems.isEmpty {
            emptyStateView(
                title: error,
                subtitle: "Try again later",
                actionTitle: "Retry",
                action: { viewModel.loadAttendance() }
            )
        } else if viewModel.attendanceItems.isEmpty {
            emptyStateView(
                title: "No attendance found for this month",
                subtitle: "Try again later",
                actionTitle: "Retry",
                action: { viewModel.loadAttendance() }
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.attendanceItems) { item in
                    StaffProfileAttendanceCard(item: item) {
                        selectedAttendanceItem = item
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var locationContent: some View {
        if viewModel.isLoadingLocation && viewModel.locationItems.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else if let error = viewModel.locationError, viewModel.locationItems.isEmpty {
            emptyStateView(
                title: error,
                subtitle: "Try again later",
                actionTitle: "Retry",
                action: { viewModel.loadLocations(reset: true) }
            )
        } else if viewModel.locationItems.isEmpty {
            emptyStateView(
                title: "No locations found",
                subtitle: "There are no locations available for this team member.",
                actionTitle: "Retry",
                action: { viewModel.loadLocations(reset: true) }
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.locationItems.enumerated()), id: \.element.id) { index, item in
                    StaffProfileLocationCard(item: item)
                        .onAppear {
                            if index == viewModel.locationItems.count - 1 {
                                viewModel.loadMoreLocationsIfNeeded()
                            }
                        }
                }

                if viewModel.isLoadingMoreLocations {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func emptyStateView(
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 42))
                .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.45))
                .padding(.top, 32)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)

            PrimaryActionButton(title: actionTitle, action: action)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }

    private func openLatestLocationOnMap() {
        guard let location = viewModel.latestLocation, location.hasMapCoordinates else {
            mapErrorMessage = "Location is not available."
            return
        }

        SellerContactActions.openMap(
            latitude: location.latitude,
            longitude: location.longitude,
            address: location.address,
            label: viewModel.context.name
        ) { result in
            if case .failure(let error) = result {
                mapErrorMessage = error.localizedDescription
            }
        }
    }
}

private struct StaffProfileAttendanceCard: View {
    let item: AttendanceHistoryItem
    var onViewMore: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(DashboardTheme.successGreen)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 12) {
                Text(item.formattedDate)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)

                HStack {
                    Label(item.formattedInTime, systemImage: "arrow.down.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Label(item.formattedOutTime, systemImage: "arrow.up.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Button(action: onViewMore) {
                    Text("View more")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
        }
        .background(Color(hex: "F7F8FA"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StaffProfileLocationCard: View {
    let item: StaffLocationLogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("\(item.batteryLevel)%", systemImage: "battery.100")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
                Text(item.createdDateTime.isEmpty ? "N/A" : item.createdDateTime)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }

            Text(item.address.isEmpty ? "Address not available" : item.address)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralDark)
                .fixedSize(horizontal: false, vertical: true)

            Text("Coordinates: \(item.coordinateLabel)")
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralMedium)

            if let accuracy = item.accuracyStatus, !accuracy.isEmpty {
                Text("Accuracy: \(accuracy)")
                    .font(.system(size: 13))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
        }
        .padding(14)
        .background(Color(hex: "F7F8FA"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
