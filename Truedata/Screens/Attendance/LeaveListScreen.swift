//
//  LeaveListScreen.swift
//  Truedata
//

import SwiftUI

struct LeaveListScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LeaveViewModel()
    @State private var showAddLeave = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "View Leaves",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load() }
                )

                AttendanceRequestTabBar(selectedTab: $viewModel.selectedTab)
                content
            }

            if !viewModel.isLoading && viewModel.errorMessage == nil {
                AttendanceFloatingAddButton {
                    showAddLeave = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.load() }
        .navigationDestination(isPresented: $showAddLeave) {
            AddLeaveScreen(onSubmitted: { viewModel.load() })
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.load()
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.filteredItems.isEmpty {
            Text("No leave requests found for this category.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredItems) { item in
                        AttendanceListCard(
                            indicatorColor: viewModel.selectedTab.indicatorColor,
                            lines: cardLines(for: item)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 88)
            }
        }
    }

    private func cardLines(for item: LeaveItem) -> [String] {
        var lines = [
            "From: \(item.startDate.isEmpty ? "N/A" : item.startDate) To: \(item.endDate.isEmpty ? "N/A" : item.endDate)",
            "Leave Type: \(item.leaveType.isEmpty ? "N/A" : item.leaveType)"
        ]
        if !item.remark.isEmpty {
            lines.append("Remark: \(item.remark)")
        }
        return lines
    }
}
