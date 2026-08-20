//
//  MyProfileScreen.swift
//  Truedata
//

import SwiftUI

struct MyProfileScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = MyProfileViewModel()
    @State private var showLogoutDialog = false
    @State private var documentPreviewURL: String?

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                MyProfileAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadProfile() }
                )

                content
            }

            if viewModel.isLoggingOut {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadProfile() }
        .alert("Logout", isPresented: $showLogoutDialog) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                viewModel.logout()
            }
        } message: {
            Text("Are you sure you want to logout?")
        }
        .fullScreenCover(isPresented: documentPreviewBinding) {
            if let url = documentPreviewURL {
                MyProfileDocumentPreviewScreen(imageURL: url) {
                    documentPreviewURL = nil
                }
            }
        }
    }

    private var documentPreviewBinding: Binding<Bool> {
        Binding(
            get: { documentPreviewURL != nil },
            set: { isPresented in
                if !isPresented { documentPreviewURL = nil }
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.profile == nil {
            Spacer()
            ProgressView().tint(DashboardTheme.primaryBlue)
            Spacer()
        } else if let error = viewModel.errorMessage, viewModel.profile == nil {
            errorState(error)
        } else if let profile = viewModel.profile {
            ScrollView {
                VStack(spacing: 16) {
                    profileHeader(profile)
                    infoCard(title: "Employment Details") {
                        infoRow(icon: "briefcase.fill", label: "Role", value: profile.roleName)
                        infoRow(icon: "calendar", label: "Joining Date", value: profile.joiningDate)
                        infoRow(icon: "checkmark.circle.fill", label: "Status", value: profile.statusText)
                    }
                    infoCard(title: "Contact Information") {
                        infoRow(icon: "phone.fill", label: "Mobile", value: profile.mobile)
                        infoRow(icon: "envelope.fill", label: "Email", value: profile.email)
                        infoRow(icon: "building.2.fill", label: "Location", value: profile.locationText)
                    }
                    infoCard(title: "Documents") {
                        documentRow(title: "View Aadhar Front") {
                            documentPreviewURL = profile.aadharFrontPic
                        }
                        documentRow(title: "View Aadhar Back") {
                            documentPreviewURL = profile.aadharBackPic
                        }
                    }

                    Button {
                        showLogoutDialog = true
                    } label: {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DashboardTheme.dangerRed)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
    }

    private func profileHeader(_ profile: MyProfileData) -> some View {
        VStack(spacing: 14) {
            Group {
                if profile.profilePic.isEmptyString {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .overlay {
                            Text(String((profile.name.isEmptyString ? "U" : profile.name).prefix(1)).uppercased())
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                        }
                } else {
                    RemoteImage(url: profile.profilePic, contentMode: .fill)
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())

            Text(profile.name.isEmptyString ? "User" : profile.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text(profile.roleWithStaffId)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DashboardTheme.primaryBlue, Color(hex: "632BC7")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private func infoCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(DashboardTheme.primaryBlue)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Text(value.isEmptyString ? "—" : value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
        }
        .padding(.vertical, 6)
    }

    private func documentRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)

                Spacer()
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Retry") {
                viewModel.loadProfile()
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

private struct MyProfileAppBar: View {
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

            Text("My Profile")
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

private struct MyProfileDocumentPreviewScreen: View {
    let imageURL: String
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Document")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))

                RemoteImage(url: imageURL, contentMode: .fit)
                    .padding(12)
            }
        }
    }
}
