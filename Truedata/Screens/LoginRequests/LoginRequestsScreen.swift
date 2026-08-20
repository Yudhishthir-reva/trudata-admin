//
//  LoginRequestsScreen.swift
//  Truedata
//

import SwiftUI

struct LoginRequestsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LoginRequestsViewModel()
    @State private var showStaffPicker = false
    @State private var historyTarget: LoginHistoryTarget?
    @State private var pendingAction: LoginRequestAction?

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                LoginRequestsAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadRequests() },
                    onHistory: {
                        viewModel.loadStaffListIfNeeded()
                        showStaffPicker = true
                    }
                )

                tabBar
                content
            }

            if viewModel.actioningRequestId != nil {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView("Processing...")
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadRequests() }
        .sheet(isPresented: $showStaffPicker) {
            LoginRequestsStaffPickerSheet(
                staffList: viewModel.staffList,
                isLoading: viewModel.isLoadingStaff,
                onSelect: { staff in
                    showStaffPicker = false
                    historyTarget = LoginHistoryTarget(
                        userId: String(staff.id),
                        userName: staff.name
                    )
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $historyTarget) { target in
            NavigationStack {
                LoginHistoryScreen(userId: target.userId, userName: target.userName)
            }
        }
        .alert(
            pendingAction?.title ?? "Confirm",
            isPresented: pendingActionBinding
        ) {
            Button("No", role: .cancel) {
                pendingAction = nil
            }
            Button("Yes") {
                if let action = pendingAction {
                    viewModel.approveOrReject(requestId: action.requestId, action: action.status)
                }
                pendingAction = nil
            }
        } message: {
            if let action = pendingAction {
                Text(action.message)
            }
        }
        .alert("Success", isPresented: successBinding) {
            Button("OK") { viewModel.successMessage = nil }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var pendingActionBinding: Binding<Bool> {
        Binding(
            get: { pendingAction != nil && viewModel.actioningRequestId == nil },
            set: { if !$0 { pendingAction = nil } }
        )
    }

    private var successBinding: Binding<Bool> {
        Binding(get: { viewModel.successMessage != nil }, set: { if !$0 { viewModel.successMessage = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !viewModel.requests.isEmpty },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LoginRequestTab.allCases) { tab in
                let isSelected = viewModel.selectedTab == tab
                Button {
                    viewModel.selectTab(tab)
                } label: {
                    VStack(spacing: 8) {
                        Text(isSelected ? "\(tab.title) (\(viewModel.requests.count))" : tab.title)
                            .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? DashboardTheme.primaryBlue : DashboardTheme.neutralMedium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Rectangle()
                            .fill(isSelected ? DashboardTheme.primaryBlue : Color.clear)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.requests.isEmpty {
            Spacer()
            ProgressView().tint(DashboardTheme.primaryBlue)
            Spacer()
        } else if let error = viewModel.errorMessage, viewModel.requests.isEmpty {
            errorState(error)
        } else if viewModel.requests.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.requests) { request in
                        LoginRequestCard(
                            request: request,
                            isActioning: viewModel.actioningRequestId == request.id,
                            onApprove: {
                                pendingAction = LoginRequestAction(
                                    requestId: request.id,
                                    userName: request.userName,
                                    status: "approved"
                                )
                            },
                            onReject: {
                                pendingAction = LoginRequestAction(
                                    requestId: request.id,
                                    userName: request.userName,
                                    status: "rejected"
                                )
                            }
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 44))
                .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.5))
            Text("No \(viewModel.selectedTab.title.lowercased()) requests found")
                .font(.system(size: 15))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                viewModel.loadRequests()
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

private struct LoginHistoryTarget: Identifiable, Hashable {
    var id: String { userId }
    var userId: String
    var userName: String
}

private struct LoginRequestAction {
    var requestId: Int
    var userName: String
    var status: String

    var title: String {
        status == "approved" ? "Approve Request" : "Reject Request"
    }

    var confirmTitle: String {
        status == "approved" ? "Approve" : "Reject"
    }

    var message: String {
        let verb = status == "approved" ? "approve" : "reject"
        return "Are you sure you want to \(verb) the device login request for \(userName)?"
    }
}

private struct LoginRequestsAppBar: View {
    var onBack: () -> Void
    var onHome: () -> Void
    var onRefresh: () -> Void
    var onHistory: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("Login Requests")
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

            Button(action: onHistory) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                    Text("History")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
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

private struct LoginRequestCard: View {
    let request: DeviceChangeRequestItem
    let isActioning: Bool
    var onApprove: () -> Void
    var onReject: () -> Void

    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var isHorizontalDrag = false

    private let swipeThreshold: CGFloat = 88
    private let maxSwipeOffset: CGFloat = 120

    var body: some View {
        Group {
            if request.isPending {
                swipeableCard
            } else {
                cardContent
            }
        }
    }

    private var swipeableCard: some View {
        ZStack {
            HStack(spacing: 0) {
                swipeBackground(
                    color: DashboardTheme.dangerRed,
                    icon: "xmark.circle.fill",
                    title: "Reject",
                    alignment: .leading
                )
                .opacity(dragOffset > 0 ? min(dragOffset / swipeThreshold, 1) : 0)

                Spacer(minLength: 0)

                swipeBackground(
                    color: DashboardTheme.successGreen,
                    icon: "checkmark.circle.fill",
                    title: "Approve",
                    alignment: .trailing
                )
                .opacity(dragOffset < 0 ? min(abs(dragOffset) / swipeThreshold, 1) : 0)
            }

            cardContent
                .offset(x: dragOffset)
                .gesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16, coordinateSpace: .local)
            .onChanged { value in
                guard !isActioning else { return }

                if !isHorizontalDrag {
                    isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                }
                guard isHorizontalDrag else { return }

                dragOffset = min(max(value.translation.width, -maxSwipeOffset), maxSwipeOffset)
            }
            .onEnded { value in
                defer {
                    isHorizontalDrag = false
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        dragOffset = 0
                    }
                }
                guard !isActioning, isHorizontalDrag else { return }

                if value.translation.width <= -swipeThreshold {
                    onApprove()
                } else if value.translation.width >= swipeThreshold {
                    onReject()
                }
            }
    }

    private func swipeBackground(
        color: Color,
        icon: String,
        title: String,
        alignment: HorizontalAlignment
    ) -> some View {
        HStack {
            if alignment == .leading {
                swipeActionLabel(icon: icon, title: title)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                swipeActionLabel(icon: icon, title: title)
            }
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color)
    }

    private func swipeActionLabel(icon: String, title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(.white)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Circle()
                    .fill(DashboardTheme.primaryBlue.opacity(0.12))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }

                Text(request.userName.isEmptyString ? "Unknown User" : request.userName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(request.statusLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(request.statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(request.statusColor.opacity(0.15))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                infoPill(icon: "phone.fill", text: request.userMobile.isEmptyString ? "—" : request.userMobile)
                infoPill(icon: "calendar", text: request.requestedAt.isEmptyString ? "—" : request.requestedAt)
            }

            deviceComparisonRow

            if request.isPending {
                Divider()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Hide Actions" : "Take Action (Or Swipe)")
                            .font(.system(size: 14, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(isActioning)

                if isExpanded && !isActioning {
                    HStack(spacing: 8) {
                        Button(action: onApprove) {
                            Label("Approve", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(DashboardTheme.successGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button(action: onReject) {
                            Label("Reject", systemImage: "xmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(DashboardTheme.dangerRed)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .opacity(isActioning ? 0.65 : 1)
    }

    private var deviceComparisonRow: some View {
        HStack(alignment: .top, spacing: 8) {
            deviceColumn(
                title: "OLD DEVICE",
                model: request.oldDeviceModel,
                deviceId: request.oldDeviceId,
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

            deviceColumn(
                title: "NEW DEVICE",
                model: request.newDeviceModel,
                deviceId: request.newDeviceId,
                color: DashboardTheme.successGreen,
                alignment: .trailing
            )
        }
    }

    private func deviceColumn(
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

    private func infoPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(DashboardTheme.neutralMedium)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(hex: "EEF2F7"))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct LoginRequestsStaffPickerSheet: View {
    let staffList: [OrderInsightsStaffMember]
    let isLoading: Bool
    var onSelect: (OrderInsightsStaffMember) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredStaff: [OrderInsightsStaffMember] {
        guard !searchText.isEmptyString else { return staffList }
        return staffList.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.mobile.contains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    TextField("Search staff...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(hex: "EEF2F7"))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)

                if isLoading {
                    Spacer()
                    ProgressView().tint(DashboardTheme.primaryBlue)
                    Spacer()
                } else if filteredStaff.isEmpty {
                    Spacer()
                    Text("No staff found")
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Spacer()
                } else {
                    List(filteredStaff) { staff in
                        Button {
                            onSelect(staff)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(DashboardTheme.primaryBlue.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(DashboardTheme.primaryBlue)
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(staff.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DashboardTheme.neutralDark)
                                    if !staff.mobile.isEmptyString {
                                        Text(staff.mobile)
                                            .font(.system(size: 12))
                                            .foregroundStyle(DashboardTheme.neutralMedium)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
