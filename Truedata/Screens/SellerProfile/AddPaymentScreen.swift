//
//  AddPaymentScreen.swift
//  Truedata
//

import SwiftUI
import PhotosUI
import UIKit

struct AddPaymentScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddPaymentViewModel
    @State private var selectedDate = Date()
    @State private var showDatePicker = false

    init(sellerId: Int, appBarTitle: String) {
        self.appBarTitle = appBarTitle
        _viewModel = StateObject(wrappedValue: AddPaymentViewModel(sellerId: sellerId))
    }

    private let appBarTitle: String

    var body: some View {
        VStack(spacing: 0) {
            SellerPaymentAppBar(
                title: appBarTitle,
                onBack: { dismiss() },
                onHome: { dismiss() }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Payment Method: Cheque")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)

                    amountField
                    dateField
                    imageSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(Color(hex: "F3F4F6"))

            saveButton
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            viewModel.loadSelectedImage()
        }
        .alert("Notice", isPresented: alertBinding) {
            Button("OK") {
                viewModel.errorMessage = nil
                viewModel.successMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? viewModel.successMessage ?? "")
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker(
                    "Payment Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Select Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            viewModel.date = SellerProfileDateFormat.apiFormatter.string(from: selectedDate)
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
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil || viewModel.successMessage != nil },
            set: { if !$0 {
                viewModel.errorMessage = nil
                viewModel.successMessage = nil
            }}
        )
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Amount")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)

            HStack(spacing: 8) {
                Image(systemName: "indianrupeesign.circle.fill")
                    .foregroundStyle(DashboardTheme.primaryBlue)
                TextField("Enter amount", text: $viewModel.amount)
                    .keyboardType(.numberPad)
                    .font(.system(size: 15))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
            }
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Date")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)

            Button {
                if let date = SellerProfileDateFormat.apiFormatter.date(from: viewModel.date) {
                    selectedDate = date
                }
                showDatePicker = true
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    Text(
                        viewModel.date.isEmpty
                            ? "Select date"
                            : SellerProfileDateFormat.displayDate(viewModel.date)
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(viewModel.date.isEmpty ? DashboardTheme.neutralMedium : DashboardTheme.neutralDark)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(DashboardTheme.surfaceVariant, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cheque Image (Required)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)

            if let imageData = viewModel.imageData, let uiImage = UIImage(data: imageData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button {
                        viewModel.clearImage()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white, .black.opacity(0.55))
                    }
                    .padding(10)
                }
            } else {
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 28))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                        Text("Upload Cheque Image")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                            .foregroundStyle(DashboardTheme.primaryBlue.opacity(0.45))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var saveButton: some View {
        Button {
            viewModel.savePayment {
                dismiss()
            }
        } label: {
            Group {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save Payment")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DashboardTheme.primaryBlue)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .disabled(viewModel.isSaving)
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.shadow(color: .black.opacity(0.08), radius: 8, y: -2))
    }
}
