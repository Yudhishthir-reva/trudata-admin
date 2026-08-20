//
//  FailedOrdersScreen.swift
//  Truedata
//

import SwiftUI

struct FailedOrdersScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FailedOrdersViewModel()
    @State private var showFilterSheet = false

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                FailedOrdersAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadOrders(isRefresh: true) }
                )

                searchAndFilterBar
                content
            }

            if viewModel.isLoading && viewModel.orders.isEmpty {
                ProgressView()
                    .tint(DashboardTheme.dangerRed)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.initialize() }
        .sheet(isPresented: $showFilterSheet) {
            FailedOrdersFilterSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField("Search by Order ID...", text: Binding(
                    get: { viewModel.searchText },
                    set: { viewModel.updateSearch($0) }
                ))
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                if !viewModel.searchText.isEmptyString {
                    Button { viewModel.updateSearch("") } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.neutralMedium.opacity(0.35), lineWidth: 1)
            }

            Button { showFilterSheet = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(DashboardTheme.dangerRed)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if viewModel.isFilterActive {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .offset(x: -4, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(hex: "F3F4F6"))
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.errorMessage, viewModel.orders.isEmpty {
            errorView(error)
        } else if viewModel.orders.isEmpty && !viewModel.isLoading {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.orders) { order in
                        NavigationLink {
                            OrderDetailScreen(orderId: order.orderId)
                        } label: {
                            FailedOrderCard(order: order)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            viewModel.loadMoreIfNeeded(currentOrder: order)
                        }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(DashboardTheme.dangerRed)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
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
                viewModel.loadOrders(isRefresh: true)
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(DashboardTheme.dangerRed)
            .clipShape(Capsule())
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.6))
            Text("No failed orders found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
            Text("Try adjusting your filters or search")
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Spacer()
        }
    }
}

// MARK: - App Bar

private struct FailedOrdersAppBar: View {
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

            Text("Failed Orders")
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

// MARK: - Order Card

private struct FailedOrderCard: View {
    let order: FailedOrderItem

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            DashboardTheme.dangerRed.opacity(0.8),
                            DashboardTheme.dangerRed
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(DashboardTheme.dangerRed)
                            Text(order.displayOrderNo)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(DashboardTheme.neutralDark)
                        }
                        Text(order.displayDate)
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }

                    Spacer()

                    Text(order.totalAmount.priceLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.dangerRed)
                }

                VStack(alignment: .leading, spacing: 4) {
                    detailRow(icon: "person.fill", label: "Seller", value: order.resolvedSellerName)
                    detailRow(icon: "phone.fill", label: "Mobile", value: order.resolvedSellerPhone)
                    if let riderName = order.resolvedRiderName {
                        detailRow(icon: "person.fill", label: "Rider", value: riderName)
                    }
                }

                if let reason = order.failureReason {
                    Text("Reason: \(reason)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DashboardTheme.dangerRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DashboardTheme.dangerRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardTheme.dangerRed.opacity(0.3), lineWidth: 2)
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(width: 14)
            Text("\(label): \(value)")
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(1)
        }
    }
}
