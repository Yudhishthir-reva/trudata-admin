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
        .sheet(item: $pickerSelection) { selection in
            AddProductPickerSheet(
                title: selection.title,
                options: selection.options,
                onSelect: selection.onSelect
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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

                    InputField(
                        label: "Description",
                        text: $viewModel.description,
                        placeholder: "Enter product description"
                    )

                    InputField(
                        label: "HSN Code *",
                        text: $viewModel.hsnCode,
                        placeholder: "Enter HSN code",
                        isError: viewModel.validationErrors.hsnCode != nil,
                        errorText: viewModel.validationErrors.hsnCode,
                        keyboardType: .numberPad
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

                sectionCard(title: "Product Image (Optional)") {
                    imageSection
                }

                sectionCard(title: "Variants & Pricing") {
                    ForEach(Array(viewModel.productVariants.enumerated()), id: \.element.id) { index, variant in
                        variantCard(variant: variant, index: index)
                    }

                    if viewModel.productVariants.count < 10 {
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

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)

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

        HStack(spacing: 12) {
            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                Text("Choose Photo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            if viewModel.imageData != nil || !viewModel.existingImageURL.isEmptyString {
                Button("Remove") {
                    viewModel.clearImage()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.dangerRed)
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

            HStack(spacing: 10) {
                InputField(
                    label: "MRP *",
                    text: binding(for: variant.id, keyPath: \.mrp),
                    placeholder: "0",
                    isError: fieldErrors?.mrp != nil,
                    errorText: fieldErrors?.mrp,
                    keyboardType: .decimalPad
                )

                InputField(
                    label: "Retailer Price *",
                    text: binding(for: variant.id, keyPath: \.retailerPrice),
                    placeholder: "0",
                    isError: fieldErrors?.retailerPrice != nil,
                    errorText: fieldErrors?.retailerPrice,
                    keyboardType: .decimalPad
                )
            }

            HStack(spacing: 10) {
                InputField(
                    label: "Available Qty *",
                    text: binding(for: variant.id, keyPath: \.quantity),
                    placeholder: "0",
                    isError: fieldErrors?.quantity != nil,
                    errorText: fieldErrors?.quantity,
                    keyboardType: .numberPad
                )

                gstPicker(for: variant, fieldErrors: fieldErrors)
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
