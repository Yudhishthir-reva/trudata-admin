//
//  PartialReturnOrderScreen.swift
//  Truedata
//

import SwiftUI

struct PartialReturnOrderScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OrderReturnViewModel

    init(orderId: String) {
        _viewModel = StateObject(wrappedValue: OrderReturnViewModel(orderId: orderId, returnType: .partial))
    }

    var body: some View {
        VStack(spacing: 0) {
            OrderDetailAppBar(
                title: "Partial Return",
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
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                returnSummaryCard(payload: payload)

                                Text("Select Items to Return")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.darkMidnightBlue)

                                ForEach(viewModel.returnItems) { item in
                                    PartialReturnItemRow(
                                        item: item,
                                        onQuantityChange: { qty in
                                            viewModel.updateReturnQuantity(for: item.orderItemId, quantity: qty)
                                        }
                                    )
                                }

                                Text("Reason for Return")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.darkMidnightBlue)

                                TextEditor(text: $viewModel.remark)
                                    .frame(minHeight: 90)
                                    .padding(10)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
                                    }
                            }
                            .padding(16)
                            .padding(.bottom, 88)
                        }

                        Button {
                            viewModel.submit()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                Text("Confirm Return (\(viewModel.selectedReturnCount) Items)")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(viewModel.canSubmit ? Color(hex: "673AB7") : Color(hex: "673AB7").opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
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

private struct PartialReturnItemRow: View {
    let item: OrderReturnLineItem
    var onQuantityChange: (Int) -> Void

    @State private var quantityText: String

    init(item: OrderReturnLineItem, onQuantityChange: @escaping (Int) -> Void) {
        self.item = item
        self.onQuantityChange = onQuantityChange
        _quantityText = State(initialValue: String(item.returnQuantity))
    }

    var body: some View {
        HStack(spacing: 12) {
            if !item.imageURL.isEmptyString {
                RemoteImage(url: item.imageURL, contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(hex: "E5E7EB"))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text("IMG")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(3)
                Text("Ordered Qty: \(item.maxQuantity)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button {
                    let current = Int(quantityText) ?? item.returnQuantity
                    let next = max(current - 1, 0)
                    onQuantityChange(next)
                    quantityText = String(next)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(item.returnQuantity <= 0)

                TextField("0", text: $quantityText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 36)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(item.returnQuantity > 0 ? DashboardTheme.primaryBlue : .black)
                    .onChange(of: quantityText) { _, newValue in
                        let filtered = newValue.filter(\.isNumber)
                        if filtered != newValue { quantityText = filtered }
                        let qty = Int(filtered) ?? 0
                        onQuantityChange(qty)
                    }

                Button {
                    let current = Int(quantityText) ?? item.returnQuantity
                    let next = min(current + 1, item.maxQuantity)
                    onQuantityChange(next)
                    quantityText = String(next)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(item.returnQuantity >= item.maxQuantity)
            }
            .padding(4)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            }
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
        .onChange(of: item.returnQuantity) { _, newValue in
            if quantityText != String(newValue) {
                quantityText = String(newValue)
            }
        }
    }
}
