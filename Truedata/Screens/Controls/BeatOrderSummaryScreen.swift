//
//  BeatOrderSummaryScreen.swift
//  Truedata
//

import SwiftUI

struct BeatOrderSummaryScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = BeatOrderSummaryViewModel()
    @State private var draftFilters = BeatSummaryFilters.initialToday()
    @State private var orderListContext: BeatSummaryOrderListContext?
    @State private var selectedOrderId: String?

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Beat Order Summary",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.load(reset: true) }
                )

                searchAndFilterHeader
                content
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.loadSupportingDataIfNeeded()
            viewModel.load(reset: true)
        }
        .sheet(isPresented: $viewModel.showFilterSheet) {
            BeatSummaryFilterSheet(
                draftFilters: $draftFilters,
                beatOptions: viewModel.beatOptions,
                staffMembers: viewModel.staffMembers,
                onApply: {
                    viewModel.applyFilters(draftFilters)
                    viewModel.showFilterSheet = false
                },
                onReset: {
                    draftFilters = BeatSummaryFilters.initialToday()
                    viewModel.resetFilters()
                    viewModel.showFilterSheet = false
                },
                onDismiss: { viewModel.showFilterSheet = false }
            )
            .onAppear { draftFilters = viewModel.filters }
        }
        .sheet(item: $orderListContext) { context in
            BeatSummaryOrderListSheet(
                title: context.title,
                orderIds: context.orderIds,
                onSelectOrder: { orderId in
                    orderListContext = nil
                    selectedOrderId = BeatSummaryOrderIDParser.normalizedOrderId(orderId)
                },
                onDismiss: { orderListContext = nil }
            )
        }
        .navigationDestination(item: $selectedOrderId) { orderId in
            OrderDetailScreen(orderId: orderId)
        }
    }

    private var searchAndFilterHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search by Order ID, Staff, Beat...", text: $viewModel.searchText)
                    .font(.system(size: 15))
                if !viewModel.searchText.isEmptyString {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            }

            HStack(spacing: 12) {
                Button {
                    viewModel.showFilterSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                        Text(viewModel.dateSubtitle)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(DashboardTheme.primaryBlue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.showFilterSheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                viewModel.filters.activeFilterCount > 0 ? .white : DashboardTheme.neutralDark
                            )
                            .frame(width: 42, height: 42)
                            .background(
                                viewModel.filters.activeFilterCount > 0
                                    ? DashboardTheme.primaryBlue
                                    : Color.white
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                            }

                        if viewModel.filters.activeFilterCount > 0 {
                            Circle()
                                .fill(DashboardTheme.warningYellow)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "F3F4F6"))
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.summaryData == nil {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.summaryData == nil {
            VStack(spacing: 12) {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .multilineTextAlignment(.center)
                PrimaryActionButton(title: "Retry") {
                    viewModel.load(reset: true)
                }
                .padding(.horizontal, 40)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.searchText.isEmpty, let summary = viewModel.summaryData?.overallSummary {
                        BeatSummaryOverallCard(summary: summary)
                    }

                    HStack {
                        Text(viewModel.searchText.isEmpty ? "Beat Breakdown" : "Search Results (\(viewModel.filteredBeats.count))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        Spacer()
                        if viewModel.searchText.isEmpty {
                            Text("\(viewModel.summaryData?.beatWiseSummary.count ?? 0) Beats")
                                .font(.system(size: 11))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                    }
                    .padding(.horizontal, 2)

                    if viewModel.filteredBeats.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.filteredBeats) { beat in
                            BeatSummaryItemCard(
                                beat: beat,
                                onViewOrders: { orderIds in
                                    orderListContext = BeatSummaryOrderListContext(
                                        title: beat.beatName,
                                        orderIds: orderIds
                                    )
                                },
                                onViewStaffOrders: { name, orderIds in
                                    orderListContext = BeatSummaryOrderListContext(
                                        title: name,
                                        orderIds: orderIds
                                    )
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.searchText.isEmpty ? "chart.bar.doc.horizontal" : "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.5))
            Text(viewModel.searchText.isEmpty ? "No data available" : "No results found for \"\(viewModel.searchText)\"")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
