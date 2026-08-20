//
//  AddRegularizationScreen.swift
//  Truedata
//

import SwiftUI

struct AddRegularizationScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddRegularizationViewModel()
    var onSubmitted: () -> Void = {}

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Add Regularization",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: {}
                )

                ScrollView {
                    VStack(spacing: 16) {
                        AttendanceDatePickerField(
                            label: "Date to Correct",
                            dateString: viewModel.dateToCorrect,
                            allowsFutureDates: false,
                            onDateSelected: { viewModel.dateToCorrect = $0 }
                        )

                        InputField(
                            label: "Reason",
                            text: $viewModel.reason,
                            placeholder: "Enter your reason"
                        )

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
        .alert("Success", isPresented: $viewModel.showSuccessAlert) {
            Button("OK") {
                viewModel.successMessage = nil
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage ?? "Regularization applied successfully")
        }
    }
}
