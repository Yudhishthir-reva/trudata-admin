//
//  AddStaffScreen.swift
//  Truedata
//

import SwiftUI

struct AddStaffScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddStaffViewModel
    @State private var activePhotoKind: StaffPhotoKind?
    @State private var showCamera = false
    @State private var pickerSelection: StaffPickerItem?

    init(editStaffId: Int? = nil, editMember: RegisteredStaffMember? = nil) {
        _viewModel = StateObject(
            wrappedValue: AddStaffViewModel(
                editStaffId: editStaffId ?? editMember?.id,
                editMember: editMember
            )
        )
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: viewModel.screenTitle,
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: {}
                )

                if viewModel.isLoading && viewModel.areas.isEmpty {
                    ProgressView("Loading...")
                        .tint(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    formContent
                }
            }

            if viewModel.isSubmitting {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView("Submitting...")
                    .tint(DashboardTheme.primaryBlue)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadInitialData() }
        .sheet(item: $pickerSelection) { selection in
            StaffPickerSheet(
                title: selection.title,
                options: selection.options,
                onSelect: selection.onSelect
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(
                onImageCaptured: { image in
                    if let kind = activePhotoKind {
                        viewModel.setPhoto(image, kind: kind)
                    }
                    showCamera = false
                    activePhotoKind = nil
                },
                onCancel: {
                    showCamera = false
                    activePhotoKind = nil
                }
            )
            .ignoresSafeArea()
        }
        .alert("Success", isPresented: $viewModel.showSuccessAlert) {
            Button("Continue") { dismiss() }
        } message: {
            Text(viewModel.successMessage)
        }
        .alert("Notice", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 14) {
                InputField(
                    label: "Name",
                    text: $viewModel.name,
                    placeholder: "Enter full name",
                    isError: viewModel.validationErrors.name != nil,
                    errorText: viewModel.validationErrors.name
                )

                InputField(
                    label: "Mobile Number",
                    text: $viewModel.mobile,
                    placeholder: "Enter mobile number",
                    isError: viewModel.validationErrors.phone != nil,
                    errorText: viewModel.validationErrors.phone,
                    isEnabled: !viewModel.isEditMode,
                    keyboardType: .phonePad
                )

                InputField(
                    label: "Email",
                    text: $viewModel.email,
                    placeholder: "Enter email address",
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )

                pickerField(
                    label: "State",
                    value: viewModel.stateName,
                    placeholder: "Choose a state",
                    isError: viewModel.validationErrors.state != nil,
                    errorText: viewModel.validationErrors.state
                ) {
                    pickerSelection = StaffPickerItem(
                        title: "Select State",
                        options: viewModel.areas.map(\.name),
                        onSelect: { name in
                            if let state = viewModel.areas.first(where: { $0.name == name }) {
                                viewModel.selectState(state)
                            }
                        }
                    )
                }

                if viewModel.stateId != nil {
                    pickerField(
                        label: "City",
                        value: viewModel.cityName,
                        placeholder: "Choose a city",
                        isError: viewModel.validationErrors.city != nil,
                        errorText: viewModel.validationErrors.city
                    ) {
                        pickerSelection = StaffPickerItem(
                            title: "Select City",
                            options: viewModel.availableCities.map(\.name),
                            onSelect: { name in
                                if let city = viewModel.availableCities.first(where: { $0.name == name }) {
                                    viewModel.selectCity(city)
                                }
                            }
                        )
                    }
                }

                pickerField(
                    label: "Designation",
                    value: viewModel.roleName,
                    placeholder: "Select role",
                    isError: viewModel.validationErrors.role != nil,
                    errorText: viewModel.validationErrors.role
                ) {
                    pickerSelection = StaffPickerItem(
                        title: "Select Designation",
                        options: viewModel.roles.map(\.name),
                        onSelect: { name in
                            if let role = viewModel.roles.first(where: { $0.name == name }) {
                                viewModel.selectRole(role)
                            }
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Joining Date")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(viewModel.validationErrors.joiningDate != nil ? AppTheme.errorRed : AppTheme.cerulean)

                    if viewModel.isEditMode {
                        Text(viewModel.joiningDate.isEmptyString ? "—" : viewModel.joiningDate)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.darkMidnightBlue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .frame(height: 52)
                            .background(AppTheme.whiteSmoke)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        DashboardDatePickerField(
                            dateString: viewModel.joiningDate,
                            onDateSelected: { viewModel.joiningDate = $0 }
                        )
                    }

                    if let error = viewModel.validationErrors.joiningDate {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.errorRed)
                    }
                }

                if !viewModel.isEditMode {
                    photoSection(title: StaffPhotoKind.profile.title, image: viewModel.profileImage, kind: .profile)
                    photoSection(title: StaffPhotoKind.aadharFront.title, image: viewModel.aadharFrontImage, kind: .aadharFront)
                    photoSection(title: StaffPhotoKind.aadharBack.title, image: viewModel.aadharBackImage, kind: .aadharBack)
                }

                PrimaryActionButton(title: viewModel.isEditMode ? "Update Staff" : "Add Staff") {
                    viewModel.submit()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private func pickerField(
        label: String,
        value: String,
        placeholder: String,
        isError: Bool = false,
        errorText: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isError ? AppTheme.errorRed : AppTheme.cerulean)

            Button(action: action) {
                HStack {
                    Text(value.isEmptyString ? placeholder : value)
                        .font(.system(size: 16))
                        .foregroundStyle(value.isEmptyString ? AppTheme.silver : AppTheme.darkMidnightBlue)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.slateGray)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(AppTheme.whiteSmoke)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isError ? AppTheme.errorRed : AppTheme.gainsboro, lineWidth: 2)
                }
            }
            .buttonStyle(.plain)

            if isError, let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.errorRed)
            }
        }
    }

    private func photoSection(title: String, image: UIImage?, kind: StaffPhotoKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.cerulean)

            Button {
                activePhotoKind = kind
                showCamera = true
            } label: {
                HStack(spacing: 12) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .frame(width: 56, height: 56)
                            .background(DashboardTheme.primaryBlue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Text(image == nil ? kind.placeholder : "Tap to retake photo")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.slateGray)

                    Spacer()
                }
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.gainsboro, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

private struct StaffPickerItem: Identifiable {
    let id = UUID()
    let title: String
    let options: [String]
    let onSelect: (String) -> Void
}
