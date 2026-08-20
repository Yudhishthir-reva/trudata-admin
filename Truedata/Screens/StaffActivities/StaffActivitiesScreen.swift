//
//  StaffActivitiesScreen.swift
//  Truedata
//

import SwiftUI

struct StaffActivitiesScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: StaffActivitiesViewModel
    let role: String

    init(startDate: String = "", endDate: String = "", role: String = "") {
        _viewModel = StateObject(
            wrappedValue: StaffActivitiesViewModel(startDate: startDate, endDate: endDate)
        )
        self.role = role
    }

    private var showAmountDetails: Bool {
        DashboardRole.canShowStaffAmountDetails(role: role)
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Staff Activities",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.retry() }
                )

                filterPanel
                content
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load(isRefresh: true) }
    }

    private var filterPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search by Staff Name", text: Binding(
                    get: { viewModel.staffNameSearch },
                    set: { viewModel.updateStaffNameSearch($0) }
                ))
                .font(.system(size: 14))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AchievementHistoryDatePreset.selectablePresets) { preset in
                        Button {
                            viewModel.applyDatePreset(preset)
                        } label: {
                            Text(preset.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(
                                    viewModel.selectedDatePreset == preset ? .white : DashboardTheme.neutralDark
                                )
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.selectedDatePreset == preset
                                        ? DashboardTheme.primaryBlue
                                        : Color.white
                                )
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule()
                                        .stroke(DashboardTheme.neutralMedium.opacity(0.2), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            HStack(spacing: 8) {
                DashboardDatePickerField(
                    dateString: viewModel.startDate,
                    onDateSelected: { viewModel.updateStartDate($0) }
                )
                DashboardDatePickerField(
                    dateString: viewModel.endDate,
                    onDateSelected: { viewModel.updateEndDate($0) }
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()
        }
        .background(Color.white)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.activities.isEmpty {
            Spacer()
            ProgressView().tint(DashboardTheme.primaryBlue)
            Spacer()
        } else if let error = viewModel.errorMessage, viewModel.activities.isEmpty {
            errorView(error)
        } else if viewModel.activities.isEmpty {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    StaffActivityTableHeader(
                        showAmountDetails: showAmountDetails,
                        staffColumnTitle: "STAFF NAME"
                    )

                    ForEach(Array(viewModel.activities.enumerated()), id: \.element.id) { index, item in
                        StaffActivityTableRow(
                            row: StaffActivityDisplayRow(item: item),
                            rank: index + 1,
                            showAmountDetails: showAmountDetails
                        )
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentItem: item)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(DashboardTheme.primaryBlue)
                            .padding(.vertical, 16)
                    } else if !viewModel.activities.isEmpty {
                        Text("You've reached the end.")
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
            }
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DashboardTheme.dangerRed)
            Text(error)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                viewModel.retry()
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(DashboardTheme.primaryBlue)
            .clipShape(Capsule())
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No staff activities found for the selected criteria.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
