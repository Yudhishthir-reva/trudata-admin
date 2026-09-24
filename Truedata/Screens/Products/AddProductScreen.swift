//
//  AddProductScreen.swift
//  Truedata
//

import SwiftUI
import PhotosUI

struct AddProductScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddProductViewModel
    @State private var pickerSelection: AddProductPicker?
    @State private var showStaffPicker = false
    @State private var showCamera = false

    init(editProductId: Int? = nil) {
        _viewModel = StateObject(wrappedValue: AddProductViewModel(editProductId: editProductId))
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: viewModel.screenTitle,
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadInitialData() }
                )

                if viewModel.isLoading || viewModel.isLoadingDetail {
                    ProgressView(viewModel.isLoadingDetail ? "Loading product..." : "Loading form data...")
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
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            viewModel.loadSelectedImage()
        }
        .onChange(of: viewModel.otherPhotoItems) { _, _ in
            viewModel.loadOtherImages()
        }
        .sheet(item: $pickerSelection) { selection in
            AddProductPickerSheet(
                title: selection.title,
                options: selection.options,
                onSelect: selection.onSelect
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStaffPicker) {
            AddProductStaffPickerSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraImagePicker(
                sourceType: .camera,
                onImageCaptured: { image in
                    viewModel.imageData = image.jpegData(compressionQuality: 0.8)
                    showCamera = false
                },
                onCancel: { showCamera = false }
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
                sectionCard(title: "Basic Information") {
                    InputField(
                        label: "Product Name *",
                        text: $viewModel.name,
                        placeholder: "Enter product name",
                        isError: viewModel.validationErrors.name != nil,
                        errorText: viewModel.validationErrors.name
                    )

                    HStack(spacing: 10) {
                        InputField(
                            label: "HSN Code *",
                            text: $viewModel.hsnCode,
                            placeholder: "4–8 digits",
                            isError: viewModel.validationErrors.hsnCode != nil,
                            errorText: viewModel.validationErrors.hsnCode,
                            keyboardType: .numberPad
                        )

                        InputField(
                            label: "Shelf life",
                            text: $viewModel.shelfLife,
                            placeholder: "e.g. 6 months",
                            isError: viewModel.validationErrors.shelfLife != nil,
                            errorText: viewModel.validationErrors.shelfLife
                        )
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ProductFormLimits.shelfLifeSuggestions, id: \.self) { suggestion in
                                let selected = viewModel.shelfLife.caseInsensitiveCompare(suggestion) == .orderedSame
                                Button {
                                    viewModel.shelfLife = suggestion
                                } label: {
                                    Text(suggestion)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(selected ? .white : DashboardTheme.neutralDark)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selected ? DashboardTheme.primaryBlue : Color(hex: "F3F4F6"))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    InputField(
                        label: "Description",
                        text: $viewModel.description,
                        placeholder: "Ingredients, pack details, usage… (optional)",
                        isError: viewModel.validationErrors.description != nil,
                        errorText: viewModel.validationErrors.description
                    )
                }

                sectionCard(title: "Brand & Category") {
                    pickerField(
                        label: "Brand *",
                        value: viewModel.selectedBrandName,
                        placeholder: "Select brand",
                        isError: viewModel.validationErrors.brand != nil,
                        errorText: viewModel.validationErrors.brand
                    ) {
                        pickerSelection = AddProductPicker(
                            title: "Select Brand",
                            options: viewModel.brandsWithCategories.map(\.name)
                        ) { name in
                            if let brand = viewModel.brandsWithCategories.first(where: { $0.name == name }) {
                                viewModel.selectBrand(brand)
                            }
                        }
                    }

                    pickerField(
                        label: "Category *",
                        value: viewModel.selectedCategoryName,
                        placeholder: viewModel.selectedBrandId == nil ? "Select brand first" : "Select category",
                        isError: viewModel.validationErrors.category != nil,
                        errorText: viewModel.validationErrors.category
                    ) {
                        guard viewModel.selectedBrandId != nil else { return }
                        pickerSelection = AddProductPicker(
                            title: "Select Category",
                            options: viewModel.availableCategories.map(\.name)
                        ) { name in
                            if let category = viewModel.availableCategories.first(where: { $0.name == name }) {
                                viewModel.selectCategory(category)
                            }
                        }
                    }
                }

                sectionCard(
                    title: "Returns",
                    subtitle: viewModel.isReturnable
                        ? "Customers can return this product"
                        : "This product can't be returned"
                ) {
                    Toggle("Returnable", isOn: $viewModel.isReturnable)
                        .tint(DashboardTheme.primaryBlue)

                    InputField(
                        label: viewModel.isReturnable ? "Return policy" : "Return note",
                        text: $viewModel.returnableDescription,
                        placeholder: viewModel.isReturnable
                            ? "e.g. Return within 7 days if seal is unbroken"
                            : "e.g. Non-returnable item",
                        isError: viewModel.validationErrors.returnableDescription != nil,
                        errorText: viewModel.validationErrors.returnableDescription
                    )
                }

                sectionCard(title: "Assigned Staff (Optional)") {
                    staffSection
                }

                sectionCard(title: "Cover & Gallery") {
                    imageSection
                }

                sectionCard(title: "Variants & Pricing") {
                    ForEach(Array(viewModel.productVariants.enumerated()), id: \.element.id) { index, variant in
                        variantCard(variant: variant, index: index)
                    }

                    if viewModel.productVariants.count < ProductFormLimits.maxVariants {
                        Button {
                            viewModel.addVariant()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Variant")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(DashboardTheme.primaryBlue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                PrimaryActionButton(title: viewModel.submitButtonTitle) {
                    viewModel.submit(onSuccess: {})
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.bottom, 24)
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
    }

    private func pickerField(
        label: String,
        value: String,
        placeholder: String,
        isError: Bool,
        errorText: String?,
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
                        .foregroundStyle(value.isEmptyString ? AppTheme.slateGray : AppTheme.darkMidnightBlue)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(isError ? AppTheme.errorRedBg : AppTheme.whiteSmoke)
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

    @ViewBuilder
    private var staffSection: some View {
        if viewModel.isStaffLoading {
            ProgressView()
                .tint(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity)
        } else if let staffError = viewModel.staffError {
            VStack(spacing: 8) {
                Text(staffError)
                    .font(.system(size: 13))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                Button("Retry") { viewModel.loadStaff() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
        } else {
            if !viewModel.selectedStaffOptions.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.selectedStaffOptions) { staff in
                        HStack(spacing: 6) {
                            Text(staff.name)
                                .font(.system(size: 12, weight: .semibold))
                            Button {
                                viewModel.toggleStaff(staff.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(DashboardTheme.primaryBlue.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }

            Button {
                showStaffPicker = true
            } label: {
                HStack {
                    Text(viewModel.selectedStaffIds.isEmpty ? "Assign sale persons" : "Edit assigned staff")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "person.badge.plus")
                }
                .foregroundStyle(DashboardTheme.primaryBlue)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(DashboardTheme.primaryBlue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var imageSection: some View {
        if let imageData = viewModel.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if !viewModel.existingImageURL.isEmptyString {
            RemoteImage(url: viewModel.existingImageURL)
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }

        HStack(spacing: 14) {
            Button {
                showCamera = true
            } label: {
                Label("Camera", systemImage: "camera.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                Label("Cover", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .buttonStyle(.plain)

            if viewModel.imageData != nil || !viewModel.existingImageURL.isEmptyString {
                Button("Remove cover") {
                    viewModel.clearMainImage()
                    if viewModel.isEditMode {
                        viewModel.existingImageURL = ""
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.dangerRed)
                .buttonStyle(.plain)
            }
        }

        Text("Gallery \(viewModel.existingOtherImageURLs.count + viewModel.otherImageData.count)/\(ProductFormLimits.maxOtherImages)")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DashboardTheme.neutralMedium)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.existingOtherImageURLs, id: \.self) { url in
                    RemoteImage(url: url)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                ForEach(Array(viewModel.otherImageData.enumerated()), id: \.offset) { index, data in
                    ZStack(alignment: .topTrailing) {
                        if let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        Button {
                            viewModel.removeOtherImage(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white, DashboardTheme.dangerRed)
                        }
                        .offset(x: 4, y: -4)
                    }
                }

                if viewModel.otherImageSlotsLeft > 0 {
                    PhotosPicker(
                        selection: $viewModel.otherPhotoItems,
                        maxSelectionCount: viewModel.otherImageSlotsLeft,
                        matching: .images
                    ) {
                        VStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Add")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(DashboardTheme.primaryBlue)
                        .frame(width: 72, height: 72)
                        .background(DashboardTheme.primaryBlue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private func variantCard(variant: ProductFormVariant, index: Int) -> some View {
        let fieldErrors = viewModel.validationErrors.variants[variant.id]

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Variant \(index + 1)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                Spacer()
                if viewModel.productVariants.count > 1 {
                    Button {
                        viewModel.removeVariant(at: index)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(DashboardTheme.dangerRed)
                    }
                    .buttonStyle(.plain)
                }
            }

            pickerField(
                label: "Variant *",
                value: variant.variantName,
                placeholder: "Select variant",
                isError: fieldErrors?.variant != nil,
                errorText: fieldErrors?.variant
            ) {
                pickerSelection = AddProductPicker(
                    title: "Select Variant",
                    options: viewModel.variantOptions.map(\.fullName)
                ) { name in
                    if let option = viewModel.variantOptions.first(where: { $0.fullName == name }) {
                        viewModel.selectVariantOption(option, for: variant.id)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Sold to")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.cerulean)

                Picker("Sold to", selection: binding(for: variant.id, keyPath: \.variantFor)) {
                    ForEach(VariantAudience.allCases) { audience in
                        Text(audience.label).tag(audience)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 10) {
                InputField(
                    label: variant.variantFor.needsRetailerPrice ? "Retailer Price *" : "Retailer Price",
                    text: binding(for: variant.id, keyPath: \.retailerPrice),
                    placeholder: variant.variantFor.needsRetailerPrice ? "0" : "Optional",
                    isError: fieldErrors?.retailerPrice != nil,
                    errorText: fieldErrors?.retailerPrice,
                    keyboardType: .decimalPad
                )

                InputField(
                    label: variant.variantFor.needsCustomerPrice ? "Customer Price *" : "Customer Price",
                    text: binding(for: variant.id, keyPath: \.customerPrice),
                    placeholder: variant.variantFor.needsCustomerPrice ? "0" : "Optional",
                    isError: fieldErrors?.customerPrice != nil,
                    errorText: fieldErrors?.customerPrice,
                    keyboardType: .decimalPad
                )
            }

            InputField(
                label: "MRP *",
                text: binding(for: variant.id, keyPath: \.mrp),
                placeholder: "0",
                isError: fieldErrors?.mrp != nil,
                errorText: fieldErrors?.mrp,
                keyboardType: .decimalPad
            )

            HStack(spacing: 10) {
                gstPicker(for: variant, fieldErrors: fieldErrors)

                InputField(
                    label: "Stock *",
                    text: binding(for: variant.id, keyPath: \.quantity),
                    placeholder: "0",
                    isError: fieldErrors?.quantity != nil,
                    errorText: fieldErrors?.quantity,
                    keyboardType: .numberPad
                )
            }

            HStack(spacing: 10) {
                InputField(
                    label: "Min qty *",
                    text: binding(for: variant.id, keyPath: \.minOrderQty),
                    placeholder: "1",
                    isError: fieldErrors?.minOrderQty != nil,
                    errorText: fieldErrors?.minOrderQty,
                    keyboardType: .numberPad
                )

                InputField(
                    label: "Max qty",
                    text: binding(for: variant.id, keyPath: \.maxOrderQty),
                    placeholder: "Optional",
                    isError: fieldErrors?.maxOrderQty != nil,
                    errorText: fieldErrors?.maxOrderQty,
                    keyboardType: .numberPad
                )
            }
        }
        .padding(12)
        .background(Color(hex: "F9FAFB"))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func gstPicker(for variant: ProductFormVariant, fieldErrors: ProductVariantFieldErrors?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("GST *")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(fieldErrors?.gst != nil ? AppTheme.errorRed : AppTheme.cerulean)

            Menu {
                ForEach(ProductFormGSTOption.allCases) { option in
                    Button(option.label) {
                        updateVariantField(variant.id, keyPath: \.gstRate, value: option.rawValue)
                    }
                }
            } label: {
                HStack {
                    Text("\(variant.gstRate)%")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.darkMidnightBlue)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(fieldErrors?.gst != nil ? AppTheme.errorRedBg : AppTheme.whiteSmoke)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(fieldErrors?.gst != nil ? AppTheme.errorRed : AppTheme.gainsboro, lineWidth: 2)
                }
            }

            if let gstError = fieldErrors?.gst {
                Text(gstError)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.errorRed)
            }
        }
    }

    private func binding(for variantId: UUID, keyPath: WritableKeyPath<ProductFormVariant, String>) -> Binding<String> {
        Binding(
            get: {
                viewModel.productVariants.first(where: { $0.id == variantId })?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                updateVariantField(variantId, keyPath: keyPath, value: newValue)
            }
        )
    }

    private func binding(for variantId: UUID, keyPath: WritableKeyPath<ProductFormVariant, VariantAudience>) -> Binding<VariantAudience> {
        Binding(
            get: {
                viewModel.productVariants.first(where: { $0.id == variantId })?[keyPath: keyPath] ?? .both
            },
            set: { newValue in
                guard var variant = viewModel.productVariants.first(where: { $0.id == variantId }) else { return }
                variant[keyPath: keyPath] = newValue
                viewModel.updateVariant(variant)
            }
        )
    }

    private func updateVariantField(
        _ variantId: UUID,
        keyPath: WritableKeyPath<ProductFormVariant, String>,
        value: String
    ) {
        guard var variant = viewModel.productVariants.first(where: { $0.id == variantId }) else { return }
        variant[keyPath: keyPath] = value
        viewModel.updateVariant(variant)
    }
}

private struct AddProductPicker: Identifiable {
    let id = UUID()
    let title: String
    let options: [String]
    let onSelect: (String) -> Void
}

private struct AddProductPickerSheet: View {
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

private struct AddProductStaffPickerSheet: View {
    @ObservedObject var viewModel: AddProductViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [ProductStaffOption] {
        guard !search.isEmptyString else { return viewModel.staffOptions }
        return viewModel.staffOptions.filter {
            $0.name.localizedCaseInsensitiveContains(search)
                || $0.mobile.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { staff in
                Button {
                    viewModel.toggleStaff(staff.id)
                } label: {
                    HStack {
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
                        Spacer()
                        if viewModel.selectedStaffIds.contains(staff.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DashboardTheme.primaryBlue)
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Search staff")
            .navigationTitle("Assign Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
