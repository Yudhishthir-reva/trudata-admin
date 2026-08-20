//
//  AddSellerScreen.swift
//  Truedata
//

import SwiftUI

struct AddSellerScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddSellerViewModel
    @StateObject private var locationHelper = LocationHelper()
    @State private var activePhotoKind: AddSellerPhotoKind?
    @State private var showCamera = false
    @State private var pickerSelection: AddSellerPicker?

    init(editSellerId: Int? = nil) {
        _viewModel = StateObject(wrappedValue: AddSellerViewModel(editSellerId: editSellerId))
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: viewModel.screenTitle,
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { locationHelper.refreshLocation() }
                )

                if viewModel.isLoading && viewModel.areas.isEmpty {
                    ProgressView("Loading area data...")
                        .tint(DashboardTheme.primaryBlue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.isLoadingDetail {
                    ProgressView("Loading seller details...")
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
        .onAppear {
            locationHelper.refreshLocation()
            viewModel.loadInitialData(locationSnapshot: locationHelper.snapshot)
        }
        .onChange(of: locationHelper.snapshot?.latitude) { _, _ in
            if let snapshot = locationHelper.snapshot {
                viewModel.updateLocation(snapshot)
            }
        }
        .sheet(item: $pickerSelection) { selection in
            AddSellerPickerSheet(
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
                    label: "Seller Name",
                    text: $viewModel.sellerName,
                    placeholder: "Enter seller's full name",
                    isError: viewModel.validationErrors.sellerName != nil,
                    errorText: viewModel.validationErrors.sellerName
                )

                InputField(
                    label: "Shop Name",
                    text: $viewModel.shopName,
                    placeholder: "Enter shop name",
                    isError: viewModel.validationErrors.shopName != nil,
                    errorText: viewModel.validationErrors.shopName
                )

                InputField(
                    label: "Registered By",
                    text: $viewModel.registeredByName,
                    isEnabled: false
                )

                pickerField(
                    label: "Staff Assigned",
                    value: viewModel.assignedToName,
                    placeholder: "Select staff member",
                    isError: viewModel.validationErrors.assignedTo != nil,
                    errorText: viewModel.validationErrors.assignedTo
                ) {
                    let options = viewModel.selectableStaff
                    pickerSelection = AddSellerPicker(
                        title: "Staff Assigned",
                        options: options.map(\.name)
                    ) { name in
                        if let staff = options.first(where: { $0.name == name }) {
                            viewModel.selectStaff(staff)
                        }
                    }
                }

                InputField(
                    label: "Mobile",
                    text: $viewModel.mobile,
                    placeholder: "Enter mobile number",
                    isError: viewModel.validationErrors.mobile != nil,
                    errorText: viewModel.validationErrors.mobile,
                    keyboardType: .phonePad
                )

                InputField(
                    label: "WhatsApp",
                    text: $viewModel.whatsapp,
                    placeholder: "Enter WhatsApp number",
                    keyboardType: .phonePad
                )

                InputField(
                    label: "Email",
                    text: $viewModel.email,
                    placeholder: "Enter email address",
                    isError: viewModel.validationErrors.email != nil,
                    errorText: viewModel.validationErrors.email,
                    keyboardType: .emailAddress,
                    textContentType: .emailAddress
                )

                pickerField(
                    label: "State",
                    value: viewModel.stateName,
                    placeholder: "Select state",
                    isError: viewModel.validationErrors.state != nil,
                    errorText: viewModel.validationErrors.state
                ) {
                    pickerSelection = AddSellerPicker(
                        title: "State",
                        options: viewModel.areas.map(\.name)
                    ) { name in
                        if let state = viewModel.areas.first(where: { $0.name == name }) {
                            viewModel.selectState(state)
                        }
                    }
                }

                pickerField(
                    label: "City",
                    value: viewModel.cityName,
                    placeholder: "Select city",
                    isError: viewModel.validationErrors.city != nil,
                    errorText: viewModel.validationErrors.city
                ) {
                    pickerSelection = AddSellerPicker(
                        title: "City",
                        options: viewModel.availableCities.map(\.name)
                    ) { name in
                        if let city = viewModel.availableCities.first(where: { $0.name == name }) {
                            viewModel.selectCity(city)
                        }
                    }
                }

                pickerField(
                    label: "Beat",
                    value: viewModel.beatName,
                    placeholder: "Select beat",
                    isError: viewModel.validationErrors.beat != nil,
                    errorText: viewModel.validationErrors.beat
                ) {
                    pickerSelection = AddSellerPicker(
                        title: "Beat",
                        options: viewModel.availableBeats.map(\.name)
                    ) { name in
                        if let beat = viewModel.availableBeats.first(where: { $0.name == name }) {
                            viewModel.selectBeat(beat)
                        }
                    }
                }

                pickerField(
                    label: "Seller Type",
                    value: viewModel.sellerTypeName,
                    placeholder: "Select seller type",
                    isError: viewModel.validationErrors.sellerType != nil,
                    errorText: viewModel.validationErrors.sellerType
                ) {
                    pickerSelection = AddSellerPicker(
                        title: "Seller Type",
                        options: viewModel.sellerTypes.map(\.name)
                    ) { name in
                        if let type = viewModel.sellerTypes.first(where: { $0.name == name }) {
                            viewModel.selectSellerType(type)
                        }
                    }
                }

                InputField(
                    label: "GST No",
                    text: $viewModel.gstNo,
                    placeholder: "Enter GST number (optional)",
                    isError: viewModel.validationErrors.gstNo != nil,
                    errorText: viewModel.validationErrors.gstNo
                )

                InputField(
                    label: "Landmark",
                    text: $viewModel.landmark,
                    placeholder: "Enter landmark"
                )

                InputField(
                    label: "Manual Address",
                    text: $viewModel.manualAddress,
                    placeholder: "Enter manual address"
                )

                locationCard

                if !viewModel.isEditMode {
                    photoSection(title: "Profile Photo", image: viewModel.profileImage, kind: .profile)
                    photoSection(title: "Aadhar Front", image: viewModel.aadharFrontImage, kind: .aadharFront)
                    photoSection(title: "Aadhar Back", image: viewModel.aadharBackImage, kind: .aadharBack)
                }

                PrimaryActionButton(title: viewModel.isEditMode ? "Update Seller" : "Add Seller") {
                    viewModel.submit(locationSnapshot: locationHelper.snapshot)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GPS Location")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.cerulean)

            Text(viewModel.gpsLocation)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.darkMidnightBlue)

            Text(viewModel.address.isEmptyString ? "Fetching address..." : viewModel.address)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.slateGray)

            if locationHelper.isLoading {
                ProgressView()
                    .scaleEffect(0.9)
            } else if let error = locationHelper.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.errorRed)
            }

            Button("Refresh Location") {
                locationHelper.refreshLocation()
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DashboardTheme.primaryBlue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.gainsboro, lineWidth: 1)
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

    private func photoSection(title: String, image: UIImage?, kind: AddSellerPhotoKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.cerulean)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 10) {
                Button("Camera") {
                    activePhotoKind = kind
                    showCamera = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryBlue)

                if image != nil {
                    Button("Remove") {
                        viewModel.setPhoto(nil, kind: kind)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.dangerRed)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.gainsboro, lineWidth: 1)
        }
    }
}

private struct AddSellerPicker: Identifiable {
    let id = UUID()
    let title: String
    let options: [String]
    let onSelect: (String) -> Void
}

private struct AddSellerPickerSheet: View {
    let title: String
    let options: [String]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [String] {
        guard !search.isEmptyString else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { option in
                Button(option) {
                    onSelect(option)
                    dismiss()
                }
                .foregroundStyle(AppTheme.darkMidnightBlue)
            }
            .searchable(text: $search, prompt: "Search")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
