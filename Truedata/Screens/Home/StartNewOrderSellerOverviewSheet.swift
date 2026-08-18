//
//  StartNewOrderSellerOverviewSheet.swift
//  Truedata
//

import SwiftUI

struct StartNewOrderSellerOverviewSheet: View {

    let seller: StartNewOrderSeller
    var isRequestingAccess: Bool
    var onClose: () -> Void
    var onRequestAccess: () -> Void
    var onViewBills: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            ScrollView {
                VStack(spacing: 16) {
                    sellerHeader
                    pendingBillsCard
                    overviewSection(title: "Contact Info") {
                        overviewRow(label: "Mobile", value: seller.mobile)
                        overviewRow(label: "WhatsApp", value: seller.whatsappNo.isEmptyString ? "N/A" : seller.whatsappNo)
                        overviewRow(label: "Email", value: seller.email.isEmptyString ? "N/A" : seller.email)
                    }
                    overviewSection(title: "Location") {
                        overviewRow(label: "Address", value: seller.address.isEmptyString ? "N/A" : seller.address, multiline: true)
                        overviewRow(label: "City/State", value: "\(seller.cityId), \(seller.stateId)")
                        overviewRow(label: "Beat ID", value: seller.beatId)
                    }
                    overviewSection(title: "Account") {
                        overviewRow(label: "ID", value: seller.sellerId)
                        overviewRow(label: "Type", value: seller.sellerTypeId.isEmptyString ? "N/A" : seller.sellerTypeId)
                        overviewRow(label: "Status", value: seller.status.isEmptyString ? "N/A" : seller.status)
                        overviewRow(label: "Joined", value: seller.joinedDate.isEmptyString ? "N/A" : seller.joinedDate)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }

            bottomActions
        }
        .background(Color(hex: "F3F4F6"))
    }

    private var sheetHeader: some View {
        HStack {
            Text("Seller Overview")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .frame(width: 32, height: 32)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var sellerHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            Group {
                if seller.profilePic.isEmptyString {
                    Circle()
                        .fill(DashboardTheme.surfaceVariant)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                } else {
                    RemoteImage(url: seller.profilePic)
                        .clipShape(Circle())
                }
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(seller.displayName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(2)

                Text(seller.name)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)

                Text(seller.accessStatusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(seller.createOrderStatus ? DashboardTheme.successGreen : DashboardTheme.dangerRed)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (seller.createOrderStatus ? DashboardTheme.successGreen : DashboardTheme.dangerRed)
                            .opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var pendingBillsCard: some View {
        if seller.transactionCount > 0 {
            Button(action: onViewBills) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(seller.transactionCount) Pending Bills")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Tap to review pending payments")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(16)
                .background(DashboardTheme.dangerRed)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func overviewSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .tracking(0.8)

            VStack(spacing: 12) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DashboardTheme.surfaceVariant.opacity(0.55))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.neutralMedium.opacity(0.12), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func overviewRow(label: String, value: String, multiline: Bool = false) -> some View {
        HStack(alignment: multiline ? .top : .center, spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
                .multilineTextAlignment(.trailing)
                .lineLimit(multiline ? 3 : 1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Text("Close")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(DashboardTheme.surfaceVariant)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: onRequestAccess) {
                Group {
                    if isRequestingAccess {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(seller.createOrderStatus ? "Access Granted" : "Request Access")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    seller.createOrderStatus
                        ? DashboardTheme.neutralMedium.opacity(0.35)
                        : DashboardTheme.secondaryPurple
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isRequestingAccess || seller.createOrderStatus)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}
