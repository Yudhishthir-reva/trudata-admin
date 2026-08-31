//
//  RetailerAppPaymentScreen.swift
//  Truedata
//

import SwiftUI

struct RetailerAppPaymentScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RetailerAppPaymentViewModel()

    @State private var showFilterSheet: Bool = false
    @State private var itemToApprove: RetailerPaymentItem?
    @State private var approveRemark: String = ""
    @State private var showApproveSheet: Bool = false
    @State private var itemToReject: RetailerPaymentItem?
    @State private var rejectRemark: String = ""
    @State private var showRejectSheet: Bool = false

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Retailer App Payments",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadRequests(isRefresh: true) }
                )

                tabBar
                searchAndFilterBar
                dateRangeBanner

                content
            }

            if viewModel.isActioning {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }

            if let toast = viewModel.toastMessage {
                VStack {
                    Spacer()
                    toastView(toast)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut, value: viewModel.toastMessage)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.loadRequests(isRefresh: true)
        }
        .sheet(isPresented: $showFilterSheet) {
            RetailerAppPaymentFilterSheet(
                currentFilters: viewModel.filters,
                sellerList: viewModel.sellerList,
                isLoadingSellers: viewModel.isLoadingSellers,
                onApply: { newFilters in
                    viewModel.applyFilters(newFilters)
                },
                onReset: {
                    viewModel.resetFiltersToDefault()
                }
            )
        }
        .sheet(isPresented: $showApproveSheet) {
            approveRemarkSheet
        }
        .sheet(isPresented: $showRejectSheet) {
            rejectRemarkSheet
        }
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }



    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !viewModel.items.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(RetailerPaymentStatus.allCases) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text(tab.title)
                                .font(.system(size: 15, weight: viewModel.selectedTab == tab ? .bold : .medium))
                                .foregroundStyle(viewModel.selectedTab == tab ? Color(hex: "1D4ED8") : Color(hex: "4B5563"))

                            let count = viewModel.countForTab(tab)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(viewModel.selectedTab == tab ? Color(hex: "1D4ED8") : Color(hex: "6B7280"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        viewModel.selectedTab == tab ? Color(hex: "DBEAFE") : Color(hex: "E5E7EB")
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 12)

                        Rectangle()
                            .fill(viewModel.selectedTab == tab ? Color(hex: "1D4ED8") : Color.clear)
                            .frame(height: 2.5)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white)
        .overlay(
            Divider().foregroundStyle(Color(hex: "E5E7EB")),
            alignment: .bottom
        )
    }

    // MARK: - Search & Filter Bar

    private var searchAndFilterBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(hex: "9CA3AF"))

                TextField("Search shop, name or mobile", text: $viewModel.searchText)
                    .font(.system(size: 14))
                    .onChange(of: viewModel.searchText) { newValue in
                        viewModel.updateSearch(newValue)
                    }

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.updateSearch("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(hex: "9CA3AF"))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            )

            Button {
                viewModel.loadSellersIfNeeded()
                showFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "1D4ED8"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if viewModel.filters.isFiltered {
                        Circle()
                            .fill(Color(hex: "FACC15"))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Date Range Banner

    private var dateRangeBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "calendar")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "1F2937"))

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.bannerTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "111827"))

                Text("Requests outside this range are hidden, not gone. \(viewModel.countForCurrentTab) shown.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "4B5563"))
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            if viewModel.filters.datePreset != .allTime {
                Button {
                    viewModel.switchToAllTime()
                } label: {
                    Text("All time")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "1D4ED8"))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(hex: "FEF9C3"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "FDE68A"), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
                Spacer()
            }
        } else if let error = viewModel.errorMessage, viewModel.items.isEmpty {
            VStack(spacing: 14) {
                Spacer()
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.loadRequests(isRefresh: true)
                } label: {
                    Text("Retry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color(hex: "1D4ED8"))
                        .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(24)
        } else if viewModel.items.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(hex: "9CA3AF"))
                Text("No payment requests found.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "6B7280"))
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.items) { item in
                        cardView(for: item)
                            .onAppear {
                                viewModel.loadMoreIfNeeded(currentItem: item)
                            }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(DashboardTheme.primaryBlue)
                            .padding(.vertical, 10)
                    }

                    Text("You've reached the end.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "9CA3AF"))
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .refreshable {
                viewModel.loadRequests(isRefresh: true)
            }
        }
    }

    // MARK: - Card View

    private func cardView(for item: RetailerPaymentItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Amount & Status Pill
            HStack(alignment: .center) {
                Text(item.formattedAmount)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: "111827"))

                Spacer()

                statusPill(for: item.statusEnum)
            }

            // Date
            Text(item.formattedDateTime)
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "6B7280"))

            // Shop Icon & Name & Contact
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "DBEAFE"))
                        .frame(width: 38, height: 38)
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "1D4ED8"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.shopName.isEmpty ? item.sellerName : item.shopName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: "111827"))

                    Text(item.personSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "4B5563"))
                }
            }

            // Payment Description
            Text(item.paymentDescription)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "374151"))
                .lineLimit(2)

            // Status-specific Content
            if item.statusEnum == .pending {
                HStack(spacing: 12) {
                    Button {
                        itemToReject = item
                        rejectRemark = ""
                        showRejectSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Reject")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Color(hex: "EF4444"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(hex: "EF4444"), lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button {
                        itemToApprove = item
                        approveRemark = ""
                        showApproveSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                            Text("Approve")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color(hex: "10B981"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.top, 4)
            } else if item.statusEnum == .approved {
                if !item.remark.isEmpty {
                    remarkBox(title: "Remark", text: item.remark, accentColor: Color(hex: "10B981"), bgColor: Color(hex: "ECFDF5"))
                }
            } else if item.statusEnum == .rejected {
                if !item.remark.isEmpty {
                    remarkBox(title: "Remark", text: item.remark, accentColor: Color(hex: "EF4444"), bgColor: Color(hex: "FEF2F2"))
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        )
    }

    private func statusPill(for status: RetailerPaymentStatus) -> some View {
        let (title, textCol, bgCol): (String, Color, Color) = {
            switch status {
            case .pending:
                return ("Pending", Color(hex: "D97706"), Color(hex: "FEF3C7"))
            case .approved:
                return ("Approved", Color(hex: "15803D"), Color(hex: "DCFCE7"))
            case .rejected:
                return ("Rejected", Color(hex: "DC2626"), Color(hex: "FEE2E2"))
            }
        }()

        return Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(textCol)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bgCol)
            .clipShape(Capsule())
    }

    private func remarkBox(title: String, text: String, accentColor: Color, bgColor: Color) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "4B5563"))

                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "111827"))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Spacer()
        }
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Approve Remark Sheet

    private var approveRemarkSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let item = itemToApprove {
                    Text("Approving payment of \(item.formattedAmount) from \(item.shopName.isEmpty ? item.sellerName : item.shopName)")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "4B5563"))
                }

                Text("Enter Approval Remark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "111827"))

                TextField("e.g. Payment verified and approved...", text: $approveRemark, axis: .vertical)
                    .lineLimit(3...5)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color(hex: "F9FAFB"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                    )

                Spacer()

                Button {
                    if let item = itemToApprove {
                        viewModel.approvePayment(item: item, remark: approveRemark)
                    }
                    showApproveSheet = false
                    itemToApprove = nil
                } label: {
                    Text("Approve Payment")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(hex: "10B981"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(20)
            .navigationTitle("Approve Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showApproveSheet = false
                        itemToApprove = nil
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Reject Remark Sheet

    private var rejectRemarkSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if let item = itemToReject {
                    Text("Rejecting payment of \(item.formattedAmount) from \(item.shopName.isEmpty ? item.sellerName : item.shopName)")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "4B5563"))
                }

                Text("Enter Rejection Remark *")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: "111827"))

                TextField("Reason for rejection...", text: $rejectRemark, axis: .vertical)
                    .lineLimit(3...5)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color(hex: "F9FAFB"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                    )

                Spacer()

                Button {
                    if let item = itemToReject {
                        viewModel.rejectPayment(item: item, remark: rejectRemark)
                    }
                    showRejectSheet = false
                    itemToReject = nil
                } label: {
                    Text("Reject Payment")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(rejectRemark.trim.isEmpty ? Color(hex: "9CA3AF") : Color(hex: "EF4444"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(rejectRemark.trim.isEmpty)
            }
            .padding(20)
            .navigationTitle("Reject Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showRejectSheet = false
                        itemToReject = nil
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Toast View

    private func toastView(_ message: String) -> some View {
        HStack {
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "1F2937"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}
