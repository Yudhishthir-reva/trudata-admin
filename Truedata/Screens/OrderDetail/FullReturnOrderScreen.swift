//
//  FullReturnOrderScreen.swift
//  Truedata
//

import SwiftUI

struct FullReturnOrderScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OrderReturnViewModel

    init(orderId: String) {
        _viewModel = StateObject(wrappedValue: OrderReturnViewModel(orderId: orderId, returnType: .full))
    }

    var body: some View {
        VStack(spacing: 0) {
            OrderDetailAppBar(
                title: "Full Return",
                onBack: { dismiss() },
                onHome: { dismiss() },
                onRefresh: { viewModel.loadDetails() }
            )

            ZStack {
                Color(hex: "F3F4F6").ignoresSafeArea()

                if viewModel.isFetchingDetails {
                    ProgressView()
                        .tint(DashboardTheme.primaryBlue)
                } else if let payload = viewModel.payload {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            returnSummaryCard(payload: payload)

                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(DashboardTheme.dangerRed)
                                Text("You are about to return all items in this order. This action cannot be undone.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DashboardTheme.dangerRed)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DashboardTheme.dangerRed.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text("Reason for Return")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppTheme.darkMidnightBlue)

                            TextEditor(text: $viewModel.remark)
                                .frame(minHeight: 110)
                                .padding(10)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                }

                            Button {
                                viewModel.submit()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Confirm Full Return")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(viewModel.canSubmit ? DashboardTheme.dangerRed : DashboardTheme.dangerRed.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
                        }
                        .padding(16)
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                        PrimaryActionButton(title: "Retry") {
                            viewModel.loadDetails()
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding()
                }

                if viewModel.isSubmitting {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView("Submitting...")
                        .tint(DashboardTheme.primaryBlue)
                }
            }
        }
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadDetails() }
        .alert("Success", isPresented: successBinding) {
            Button("OK") {
                viewModel.successMessage = nil
                dismiss()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        .alert("Error", isPresented: errorBinding) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var successBinding: Binding<Bool> {
        Binding(get: { viewModel.successMessage != nil }, set: { if !$0 { viewModel.successMessage = nil } })
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && viewModel.payload != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

 func returnSummaryCard(payload: EditOrderDetailsPayload) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Order \(payload.orderNo.isEmpty ? "#\(payload.numericOrderId)" : payload.orderNo)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
            }
            Spacer()
            Text("Total Items: \(payload.items.reduce(0) { $0 + $1.quantity })")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DashboardTheme.primaryBlue)
        }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
    }
}
