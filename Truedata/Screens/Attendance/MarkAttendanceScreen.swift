//
//  MarkAttendanceScreen.swift
//  Truedata
//

import SwiftUI

struct MarkAttendanceScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MarkAttendanceViewModel()
    @StateObject private var locationHelper = LocationHelper()

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Mark Attendance",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: {
                        locationHelper.refreshLocation()
                        viewModel.refresh()
                    }
                )

                if viewModel.isLoadingStatus && viewModel.checkInTime == "No data available" {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            timeHeader
                                .padding(.top, 32)

                            checkInButton
                                .padding(.top, 24)

                            statusCards
                                .padding(.horizontal, 16)
                                .padding(.top, 24)

                            historySection
                                .padding(.top, 24)
                                .padding(.bottom, 24)
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            locationHelper.refreshLocation()
            viewModel.load()
        }
        .sheet(isPresented: $viewModel.showPunchSheet) {
            punchSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(viewModel.isSubmitting)
        }
        .sheet(isPresented: $viewModel.showDetailSheet) {
            if let item = viewModel.selectedHistoryItem {
                AttendanceDetailSheet(item: item, onClose: viewModel.closeDetailSheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var timeHeader: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(viewModel.currentTime.hour)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.black)
                Text(":")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.black)
                Text(viewModel.currentTime.minute)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.black)
                Text(viewModel.currentTime.period)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.leading, 4)
            }

            Text(viewModel.currentDate)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var checkInButton: some View {
        AttendanceActionButton(state: viewModel.checkInState) {
            viewModel.openPunchSheet()
        }
    }

    private var statusCards: some View {
        HStack(spacing: 16) {
            AttendanceStatusCard(title: "Check in at", value: viewModel.checkInTime)
            AttendanceStatusCard(title: "Check out at", value: viewModel.checkOutTime)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Attendance History")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)

            if viewModel.isLoadingHistory {
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else if viewModel.history.isEmpty {
                Text("No attendance history for this period.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 32)
                    .padding(.horizontal, 16)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.history) { item in
                        AttendanceHistoryCard(item: item) {
                            viewModel.openHistoryDetail(item)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var punchSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.punchSheetTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)

                Spacer()

                Button {
                    viewModel.closePunchSheet()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.slateGray)
                        .frame(width: 32, height: 32)
                        .background(Color(hex: "E5E7EB"))
                        .clipShape(Circle())
                }
                .disabled(viewModel.isSubmitting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(spacing: 16) {
                    locationSection

                    if viewModel.isSubmitting {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(DashboardTheme.primaryBlue)
                            Text("Submitting attendance...")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.vertical, 24)
                    } else if let error = viewModel.punchErrorMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(AppTheme.errorRed)
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.errorRed)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 16)
                    } else if let success = viewModel.punchSuccessMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(DashboardTheme.successGreen)
                            Text(success)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 24)
                    } else if canProceedWithLocation {
                        SlideToConfirmView(text: viewModel.slideConfirmText) {
                            viewModel.performPunch(location: locationHelper.snapshot)
                        }
                        .padding(.vertical, 8)
                    } else {
                        Text("Please wait for location to be acquired")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 24)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(Color.white)
        .onAppear {
            locationHelper.refreshLocation()
        }
        .onChange(of: viewModel.punchSuccessMessage) { _, message in
            guard message != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                viewModel.closePunchSheet()
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        if locationHelper.isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
                Text("Getting your location...")
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .padding(.bottom, 8)
        } else if let error = locationHelper.errorMessage {
            VStack(spacing: 10) {
                Text("⚠️ \(error)")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.errorRed)
                    .multilineTextAlignment(.center)
                Button("Retry Location") {
                    locationHelper.refreshLocation()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .padding(.bottom, 8)
        } else if let address = locationHelper.snapshot?.address, !address.isEmpty {
            Text(address)
                .font(.system(size: 15))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
        } else {
            Text("Location information not available")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
        }
    }

    private var canProceedWithLocation: Bool {
        guard let snapshot = locationHelper.snapshot else { return false }
        return !snapshot.address.isEmpty && !locationHelper.isLoading
    }
}

private struct AttendanceActionButton: View {
    let state: AttendanceCheckInState
    let onTap: () -> Void

    private var config: (ring: Color, icon: Color, text: String, showDone: Bool) {
        switch state {
        case .checkIn:
            return (Color(hex: "E8F5E9"), DashboardTheme.successGreen, "CHECK IN", false)
        case .checkOut:
            return (Color(hex: "FFEBEE"), Color(hex: "E53935"), "CHECK OUT", false)
        case .done:
            return (Color(hex: "F5F5F5"), AppTheme.textSecondary, "", true)
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(config.ring)
                    .frame(width: 220, height: 220)

                Circle()
                    .fill(.white)
                    .frame(width: 150, height: 150)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

                if config.showDone {
                    Text("You are done for\nthe day!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(config.icon)
                        Text(config.text)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(config.icon)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .done)
    }
}

private struct AttendanceStatusCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
            Text(displayValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(value == "No data available" ? AppTheme.textMuted : .black)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }

    private var displayValue: String {
        guard value != "No data available" else { return value }
        if value.contains(":") && value.count <= 8 {
            return value
        }
        return AttendanceTimeFormatter.displayTime(from: value)
    }
}

private struct AttendanceHistoryCard: View {
    let item: AttendanceHistoryItem
    let onViewMore: () -> Void

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
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(item.formattedInTime)
                            .font(.system(size: 14, weight: .medium))
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(item.formattedOutTime)
                            .font(.system(size: 14, weight: .medium))
                    }
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }
}
