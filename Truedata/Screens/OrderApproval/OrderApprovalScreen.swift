//
//  OrderApprovalScreen.swift
//  Truedata
//

import SwiftUI

struct OrderApprovalScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = OrderApprovalViewModel()
    @State private var itemToApprove: OrderApprovalItem?
    var onViewBills: (OrderApprovalItem) -> Void

    init(onViewBills: @escaping (OrderApprovalItem) -> Void = { _ in }) {
        self.onViewBills = onViewBills
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                OrderApprovalAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadRequests() }
                )

                if !viewModel.dynamicTabs.isEmpty {
                    statusTabs
                }

                content
            }

            if viewModel.isApproving {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.loadRequests() }
        .alert("Approve Request", isPresented: approveAlertBinding) {
            Button("Cancel", role: .cancel) {
                itemToApprove = nil
            }
            Button("Approve") {
                if let item = itemToApprove {
                    viewModel.approveRequest(item)
                }
                itemToApprove = nil
            }
        } message: {
            if let item = itemToApprove {
                Text("Approve order access request for \(item.shopName)?")
            }
        }
        .alert("Success", isPresented: successAlertBinding) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var approveAlertBinding: Binding<Bool> {
        Binding(
            get: { itemToApprove != nil && !viewModel.isApproving },
            set: { if !$0 { itemToApprove = nil } }
        )
    }

    private var successAlertBinding: Binding<Bool> {
        Binding(get: { viewModel.successMessage != nil }, set: { if !$0 { viewModel.successMessage = nil } })
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !viewModel.items.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var statusTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(viewModel.dynamicTabs.enumerated()), id: \.element.id) { index, tab in
                    Button {
                        viewModel.selectedTabIndex = index
                    } label: {
                        HStack(spacing: 6) {
                            Text(tab.label)
                                .font(.system(size: 14, weight: viewModel.selectedTabIndex == index ? .bold : .medium))
                            Text("\(tab.count)")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    (viewModel.selectedTabIndex == index
                                     ? DashboardTheme.primaryBlue
                                     : DashboardTheme.neutralMedium).opacity(0.12)
                                )
                                .clipShape(Capsule())
                        }
                        .foregroundStyle(
                            viewModel.selectedTabIndex == index
                            ? DashboardTheme.primaryBlue
                            : DashboardTheme.neutralMedium
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if viewModel.selectedTabIndex == index {
                                Rectangle()
                                    .fill(DashboardTheme.primaryBlue)
                                    .frame(height: 3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .background(Color.white)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            Spacer()
            ProgressView().tint(DashboardTheme.primaryBlue)
            Spacer()
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
            VStack(spacing: 14) {
                Spacer()
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.errorRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                DashboardCompactButton(title: "Retry") {
                    viewModel.loadRequests()
                }
                Spacer()
            }
        } else if viewModel.filteredItems.isEmpty {
            VStack {
                Spacer()
                Text("No requests found.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.filteredItems) { item in
                        OrderApprovalRequestCard(
                            item: item,
                            onApprove: { itemToApprove = item },
                            onViewBills: { onViewBills(item) }
                        )
                    }
                }
                .padding(12)
            }
            .refreshable {
                viewModel.loadRequests()
            }
        }
    }
}

// MARK: - App Bar

private struct OrderApprovalAppBar: View {
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

            Text("Order Approval")
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

// MARK: - Request Card

private struct OrderApprovalRequestCard: View {
    let item: OrderApprovalItem
    var onApprove: () -> Void
    var onViewBills: () -> Void

    private var pendingBillColor: Color {
        item.pendingBills < 3 ? DashboardTheme.successGreen : DashboardTheme.dangerRed
    }

    var body: some View {
        HStack(spacing: 0) {
            if item.isPending {
                Rectangle()
                    .fill(DashboardTheme.primaryBlue)
                    .frame(width: 4)
            }

            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "storefront.fill", label: "Shop", value: item.shopName)
                infoRow(icon: "person.fill", label: "Sales Person", value: item.staff)
                infoRow(icon: "calendar", label: "Requested On", value: item.formattedDate)

                Divider()

                HStack {
                    Text("Pending Bills")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Spacer()
                    Text("\(item.pendingBills)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(pendingBillColor)
                }

                HStack(spacing: 8) {
                    Button(action: onViewBills) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text("View Bills")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(DashboardTheme.primaryBlue, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)

                    if item.isPending {
                        Button(action: onApprove) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Approve")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DashboardTheme.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.surfaceVariant, lineWidth: 0.5)
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(width: 16)
            Text("\(label):")
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    NavigationStack {
        OrderApprovalScreen()
    }
}
