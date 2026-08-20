//
//  AddLeaveScreen.swift
//  Truedata
//

import SwiftUI

struct AddLeaveScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddLeaveViewModel()
    var onSubmitted: () -> Void = {}

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                SellersAppBar(
                    title: "Apply Leave",
                    onBack: { dismiss() },
                    onHome: { dismiss() },
                    onRefresh: { viewModel.loadLeaveTypes() }
                )

                ScrollView {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            AttendanceDatePickerField(
                                label: "From Date",
                                dateString: viewModel.fromDate,
                                allowsFutureDates: true,
                                onDateSelected: { viewModel.fromDate = $0 }
                            )
                            AttendanceDatePickerField(
                                label: "To Date",
                                dateString: viewModel.toDate,
                                allowsFutureDates: true,
                                onDateSelected: { viewModel.toDate = $0 }
                            )
                        }

                        AttendancePickerField(
                            label: "Select Leave Type",
                            value: viewModel.selectedLeaveTypeName,
                            placeholder: "Choose leave type",
                            onTap: { viewModel.showLeaveTypePicker = true }
                        )

                        InputField(
                            label: "Remark",
                            text: $viewModel.remark,
                            placeholder: "Add a brief remark..."
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
        .onAppear { viewModel.loadLeaveTypes() }
        .sheet(isPresented: $viewModel.showLeaveTypePicker) {
            AttendanceOptionPickerSheet(
                title: "Select Leave Type",
                options: viewModel.leaveTypes.map(\.name),
                onSelect: { name in
                    if let type = viewModel.leaveTypes.first(where: { $0.name == name }) {
                        viewModel.selectLeaveType(type)
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Success", isPresented: $viewModel.showSuccessAlert) {
            Button("OK") {
                viewModel.successMessage = nil
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage ?? "Leave applied successfully")
        }
    }
}
