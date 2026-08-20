//
//  LoginHistoryScreen.swift
//  Truedata
//

import SwiftUI

struct LoginHistoryScreen: View {

    let userId: String
    let userName: String

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LoginHistoryViewModel()

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                LoginHistoryAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadHistory(userId: userId) }
                )

                content
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadHistory(userId: userId) }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.history.isEmpty {
            Spacer()
            ProgressView().tint(DashboardTheme.primaryBlue)
            Spacer()
        } else if let error = viewModel.errorMessage, viewModel.history.isEmpty {
            errorState(error)
        } else if viewModel.history.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 44))
                    .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.5))
                Text("No login history found")
                    .font(.system(size: 15))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    headerCard

                    ForEach(viewModel.history) { item in
                        LoginHistoryCard(item: item)
                    }
                }
                .padding(16)
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(DashboardTheme.primaryBlue.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(userName.isEmptyString ? "Staff" : userName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Text("\(viewModel.history.count) device change\(viewModel.history.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                viewModel.loadHistory(userId: userId)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(DashboardTheme.primaryBlue)
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct LoginHistoryAppBar: View {
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

            Text("Login History")
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

private struct LoginHistoryCard: View {
    let item: DeviceChangeHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                Text(item.changedAt.isEmptyString ? "—" : item.changedAt)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(DashboardTheme.neutralMedium)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(hex: "EEF2F7"))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            HStack(alignment: .top, spacing: 8) {
                historyDeviceColumn(
                    title: "OLD DEVICE",
                    model: item.oldDeviceModel,
                    deviceId: item.oldDeviceId,
                    color: DashboardTheme.dangerRed,
                    alignment: .leading
                )

                Circle()
                    .fill(DashboardTheme.primaryBlue.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                    .padding(.top, 18)

                historyDeviceColumn(
                    title: "NEW DEVICE",
                    model: item.newDeviceModel,
                    deviceId: item.newDeviceId,
                    color: DashboardTheme.successGreen,
                    alignment: .trailing
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    private func historyDeviceColumn(
        title: String,
        model: String,
        deviceId: String,
        color: Color,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralMedium)

            HStack(spacing: 4) {
                if alignment == .leading {
                    Image(systemName: "iphone")
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                }

                Text(model.isEmptyString ? "Unknown" : model)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)

                if alignment == .trailing {
                    Image(systemName: "iphone")
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                }
            }

            Text(deviceId.isEmptyString ? "—" : deviceId)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}
