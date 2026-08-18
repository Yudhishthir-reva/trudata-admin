//
//  RearrangeSellersScreen.swift
//  Truedata
//

import SwiftUI

struct RearrangeSellersScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RearrangeSellersViewModel
    var onSaved: ([StartNewOrderSeller]) -> Void

    init(
        beatId: Int,
        sellers: [StartNewOrderSeller],
        onSaved: @escaping ([StartNewOrderSeller]) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: RearrangeSellersViewModel(beatId: beatId, sellers: sellers)
        )
        self.onSaved = onSaved
    }

    var body: some View {
        ZStack {
            Color(hex: "F3F4F6").ignoresSafeArea()

            VStack(spacing: 0) {
                RearrangeSellersAppBar(
                    onBack: { dismiss() },
                    onHome: { dismiss() }
                )

                List {
                    ForEach(viewModel.sellers) { seller in
                        RearrangeSellerRow(
                            seller: seller,
                            index: (viewModel.sellers.firstIndex(where: { $0.id == seller.id }) ?? 0) + 1
                        )
                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove(perform: viewModel.move)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
                .padding(.top, 8)

                saveButton
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.didSaveSuccessfully) { _, didSave in
            guard didSave else { return }
            onSaved(viewModel.sellers)
            dismiss()
        }
        .alert(
            "Notice",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var saveButton: some View {
        Button {
            viewModel.saveOrder()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.white)
                    Text("Saving...")
                        .font(.system(size: 16, weight: .medium))
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Save New Order")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(DashboardTheme.primaryBlue.opacity(viewModel.isSaving ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: DashboardTheme.primaryBlue.opacity(0.2), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSaving || viewModel.sellers.isEmpty)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(hex: "F3F4F6"))
    }
}

private struct RearrangeSellerRow: View {
    let seller: StartNewOrderSeller
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(DashboardTheme.primaryBlue.opacity(0.08))
                    .frame(width: 32, height: 32)

                Text("\(index)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(seller.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(seller.name.isEmptyString ? "Unknown" : seller.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .lineLimit(1)

                    if !seller.mobile.isEmptyString {
                        Text("• \(seller.mobile)")
                            .font(.system(size: 13))
                            .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.neutralMedium.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct RearrangeSellersAppBar: View {
    var onBack: () -> Void
    var onHome: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Text("Rearrange Sellers")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onHome) {
                Image(systemName: "house.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(AppTheme.darkMidnightBlue.ignoresSafeArea(edges: .top))
    }
}

#Preview {
    NavigationStack {
        RearrangeSellersScreen(
            beatId: 1,
            sellers: [],
            onSaved: { _ in }
        )
    }
}
