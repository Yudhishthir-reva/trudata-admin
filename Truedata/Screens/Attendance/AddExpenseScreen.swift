//
//  AddExpenseScreen.swift
//  Truedata
//

import SwiftUI
import PhotosUI
import UIKit

struct AddExpenseScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddExpenseViewModel()
    var onSubmitted: () -> Void = {}

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Add Expense",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: {}
                )

                ScrollView {
                    VStack(spacing: 16) {
                        AttendanceDatePickerField(
                            label: "Expense Date",
                            dateString: viewModel.expenseDate,
                            allowsFutureDates: false,
                            onDateSelected: { viewModel.expenseDate = $0 }
                        )

                        InputField(
                            label: "Amount",
                            text: $viewModel.amount,
                            placeholder: "Enter expense amount",
                            keyboardType: .decimalPad
                        )

                        InputField(
                            label: "Remark",
                            text: $viewModel.remark,
                            placeholder: "Add a brief remark..."
                        )

                        imageSection

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.errorRed)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        PrimaryActionButton(
                            title: "Submit",
                            isLoading: viewModel.isSubmitting,
                            isEnabled: viewModel.canSubmit
                        ) {
                            viewModel.submit(onSuccess: onSubmitted)
                        }
                    }
                    .padding(16)
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
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            viewModel.loadSelectedImage()
        }
        .alert("Success", isPresented: $viewModel.showSuccessAlert) {
            Button("OK") {
                viewModel.successMessage = nil
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage ?? "Expense added successfully.")
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Expense Image (Optional)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.cerulean)

            if let imageData = viewModel.imageData, let uiImage = UIImage(data: imageData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        viewModel.clearImage()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            } else {
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 20))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                        Text("Upload Image")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(AppTheme.aliceBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppTheme.blue, lineWidth: 2)
                    }
                }
            }
        }
    }
}
