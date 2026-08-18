//
//  UpdateSellerStatusScreen.swift
//  Truedata
//

import SwiftUI

struct UpdateSellerStatusScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: UpdateSellerStatusViewModel
    @StateObject private var locationHelper = LocationHelper()
    @State private var showCamera = false
    @State private var showImagePreview = false
    @State private var showDatePicker = false
    @State private var selectedDate = Date()

    init(sellerId: String, sellerName: String) {
        _viewModel = StateObject(
            wrappedValue: UpdateSellerStatusViewModel(
                sellerId: sellerId,
                sellerName: sellerName
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            SellerPaymentAppBar(
                title: "Update Seller Status",
                onBack: { dismiss() },
                onHome: { dismiss() }
            )

            ScrollView {
                VStack(spacing: 14) {
                    shopInfoCard
                    selfieCard
                    locationCard
                    nextVisitDateCard
                    remarkCard

                    if let validationMessage = viewModel.validationMessage {
                        validationBanner(validationMessage)
                    }

                    submitButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(hex: "F3F4F6"))
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { locationHelper.refreshLocation() }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(
                onImageCaptured: { image in
                    viewModel.setCapturedImage(image)
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showImagePreview) {
            if let image = viewModel.capturedImage {
                NavigationStack {
                    VStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .padding()
                        Spacer()
                    }
                    .navigationTitle("Captured Image")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Close") { showImagePreview = false }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker(
                    "Next Visit Date",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            viewModel.nextVisitDate = DashboardDateFormat.string(from: selectedDate)
                            showDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showDatePicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Notice", isPresented: alertBinding) {
            Button("OK") {
                if viewModel.didSubmitSuccessfully {
                    dismiss()
                }
                viewModel.errorMessage = nil
                viewModel.didSubmitSuccessfully = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "Shop location visit submitted successfully!")
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil || viewModel.didSubmitSuccessfully },
            set: { if !$0 {
                viewModel.errorMessage = nil
                viewModel.didSubmitSuccessfully = false
            }}
        )
    }

    private var shopInfoCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DashboardTheme.primaryBlue, DashboardTheme.accentTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "storefront.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(viewModel.sellerName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .multilineTextAlignment(.center)

            Text("Shop Name")
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    DashboardTheme.primaryBlue.opacity(0.08),
                    DashboardTheme.accentTeal.opacity(0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: DashboardTheme.primaryBlue.opacity(0.05), radius: 6, y: 2)
    }

    private var selfieCard: some View {
        formCard {
            sectionHeader(icon: "camera.fill", title: "Selfie at Shop Location", required: true)

            if let image = viewModel.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [DashboardTheme.primaryBlue, DashboardTheme.accentTeal],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                    .padding(.top, 16)

                HStack(spacing: 10) {
                    Button {
                        showImagePreview = true
                    } label: {
                        actionChip(title: "View", icon: "eye.fill", style: .outline)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showCamera = true
                    } label: {
                        actionChip(title: "Retake", icon: "arrow.clockwise", style: .filled)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
            } else {
                Button {
                    showCamera = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                        Text("Tap to capture")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                    .frame(width: 180, height: 180)
                    .background(DashboardTheme.primaryBlue.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(DashboardTheme.primaryBlue.opacity(0.3), lineWidth: 2)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
        }
    }

    private var locationCard: some View {
        formCard {
            sectionHeader(icon: "location.fill", title: "Current Location", required: true)

            Group {
                if locationHelper.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("Fetching location...")
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.infoBlue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(DashboardTheme.infoBlue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if let snapshot = locationHelper.snapshot, !snapshot.address.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(snapshot.address)
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.neutralDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(DashboardTheme.successGreen.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(DashboardTheme.successGreen.opacity(0.2), lineWidth: 1)
                            }

                        HStack(spacing: 6) {
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                            Text(
                                String(format: "%.6f, %.6f", snapshot.latitude, snapshot.longitude)
                            )
                            .font(.system(size: 11))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                    }
                } else {
                    Text(locationHelper.errorMessage ?? "Unable to get location")
                        .font(.system(size: 13))
                        .foregroundStyle(DashboardTheme.dangerRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(DashboardTheme.dangerRed.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.top, 14)

            Button {
                locationHelper.refreshLocation()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Refresh Location")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(DashboardTheme.primaryBlue)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(locationHelper.isLoading)
            .padding(.top, 10)
        }
    }

    private var nextVisitDateCard: some View {
        formCard {
            sectionHeader(icon: "calendar", title: "Next Available Date")

            Text("Next Visit Date")
                .font(.system(size: 12))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .padding(.top, 14)

            Button {
                if let parsed = DashboardDateFormat.parse(viewModel.nextVisitDate) {
                    selectedDate = parsed
                } else {
                    selectedDate = Date()
                }
                showDatePicker = true
            } label: {
                HStack {
                    Text(
                        viewModel.nextVisitDate.isEmptyString
                        ? "Select next visit date"
                        : viewModel.nextVisitDate
                    )
                    .font(.system(size: 14))
                    .foregroundStyle(
                        viewModel.nextVisitDate.isEmptyString
                        ? DashboardTheme.neutralMedium
                        : DashboardTheme.neutralDark
                    )
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private var remarkCard: some View {
        formCard {
            sectionHeader(icon: "square.and.pencil", title: "Remark (Optional)")

            TextField(
                "Add any additional notes...",
                text: $viewModel.remark,
                axis: .vertical
            )
            .lineLimit(3...5)
            .font(.system(size: 13))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.neutralMedium.opacity(0.25), lineWidth: 1)
            }
            .padding(.top, 14)
        }
    }

    private var submitButton: some View {
        Button {
            viewModel.submit(locationSnapshot: locationHelper.snapshot)
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(.white)
                    Text("Submitting...")
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Submit Shop Visit")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(viewModel.isSubmitting ? DashboardTheme.neutralMedium : DashboardTheme.primaryBlue)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSubmitting)
    }

    private func validationBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(DashboardTheme.dangerRed)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DashboardTheme.dangerRed)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(DashboardTheme.dangerRed.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.dangerRed.opacity(0.3), lineWidth: 1)
        }
    }

    private func sectionHeader(icon: String, title: String, required: Bool = false) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(DashboardTheme.primaryBlue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralDark)

            if required {
                Text("*")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.dangerRed)
            }

            Spacer(minLength: 0)
        }
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: DashboardTheme.primaryBlue.opacity(0.05), radius: 6, y: 2)
    }

    private enum ActionChipStyle {
        case outline
        case filled
    }

    private func actionChip(title: String, icon: String, style: ActionChipStyle) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(title)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(style == .filled ? .white : DashboardTheme.infoBlue)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(style == .filled ? DashboardTheme.primaryBlue : Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            if style == .outline {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(DashboardTheme.infoBlue.opacity(0.35), lineWidth: 1)
            }
        }
    }
}
