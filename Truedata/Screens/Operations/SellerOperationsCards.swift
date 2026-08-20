//
//  SellerOperationsCards.swift
//  Truedata
//

import SwiftUI

struct SellerOperationsGrid: View {
    let sellersTile: OperationsTile?
    let productsTile: OperationsTile?
    var onNavigate: (String) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
            spacing: 16
        ) {
            SellerSummaryCard(
                title: sellersTile?.title.isEmpty == false ? sellersTile!.title : "Sellers",
                total: sellersTile?.payload?.int(for: "totalSellerCount", "total_seller_count") ?? 0,
                active: sellersTile?.payload?.int(for: "activeSellerCount", "active_seller_count") ?? 0,
                inactive: sellersTile?.payload?.int(for: "inactiveSellerCount", "inactive_seller_count") ?? 0,
                showAddSeller: sellersTile?.payload?["addSellerButtonIsShow"]?.boolValue ?? true,
                onViewAll: { onNavigate("registered_sellers") },
                onAddSeller: { onNavigate("add_new_sellers") }
            )

            ProductSummaryCard(
                title: productsTile?.title.isEmpty == false ? productsTile!.title : "Products",
                total: productsTile?.payload?.int(for: "allProducts", "all_products") ?? 0,
                active: productsTile?.payload?.int(for: "activeProducts", "active_products") ?? 0,
                inactive: productsTile?.payload?.int(for: "inactiveProducts", "inactive_products") ?? 0,
                onViewAll: { onNavigate("view_products") }
            )
        }
    }
}

private struct SellerSummaryCard: View {
    let title: String
    let total: Int
    let active: Int
    let inactive: Int
    let showAddSeller: Bool
    var onViewAll: () -> Void
    var onAddSeller: () -> Void

    var body: some View {
        OperationsSummaryCard(title: title) {
            if total > 0 {
                VStack(spacing: 4) {
                    OperationsStatRow(
                        icon: "storefront.fill",
                        label: "Total",
                        value: total,
                        color: DashboardTheme.primaryBlue,
                        background: DashboardTheme.primaryBlue.opacity(0.08)
                    )
                    OperationsStatRow(
                        icon: "checkmark.circle.fill",
                        label: "Active",
                        value: active,
                        color: DashboardTheme.successGreen,
                        background: DashboardTheme.successGreen.opacity(0.08)
                    )
                    OperationsStatRow(
                        icon: "xmark.circle.fill",
                        label: "Inactive",
                        value: inactive,
                        color: DashboardTheme.dangerRed,
                        background: DashboardTheme.dangerRed.opacity(0.08)
                    )
                }

                VStack(spacing: 2) {
                    OperationsTextAction(title: "View All", color: DashboardTheme.primaryBlue, action: onViewAll)
                    if showAddSeller {
                        OperationsTextAction(
                            title: "Add Seller",
                            color: DashboardTheme.successGreen,
                            systemImage: "plus",
                            action: onAddSeller
                        )
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "storefront")
                        .font(.system(size: 24))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Text("No sellers")
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    if showAddSeller {
                        OperationsTextAction(
                            title: "Add Seller",
                            color: DashboardTheme.successGreen,
                            systemImage: "plus",
                            action: onAddSeller
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }
}

private struct ProductSummaryCard: View {
    let title: String
    let total: Int
    let active: Int
    let inactive: Int
    var onViewAll: () -> Void

    var body: some View {
        OperationsSummaryCard(title: title) {
            if total > 0 {
                VStack(spacing: 4) {
                    OperationsStatRow(
                        icon: "square.stack.3d.up.fill",
                        label: "Total",
                        value: total,
                        color: DashboardTheme.infoBlue,
                        background: DashboardTheme.infoBlue.opacity(0.08)
                    )
                    OperationsStatRow(
                        icon: "checkmark.square.fill",
                        label: "Active",
                        value: active,
                        color: DashboardTheme.successGreen,
                        background: DashboardTheme.successGreen.opacity(0.08)
                    )
                    OperationsStatRow(
                        icon: "xmark.square.fill",
                        label: "Inactive",
                        value: inactive,
                        color: DashboardTheme.dangerRed,
                        background: DashboardTheme.dangerRed.opacity(0.08)
                    )
                }

                OperationsTextAction(title: "View All", color: DashboardTheme.primaryBlue, action: onViewAll)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 24))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Text("No products")
                        .font(.system(size: 11))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    OperationsTextAction(title: "View All", color: DashboardTheme.primaryBlue, action: onViewAll)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }
}

private struct OperationsSummaryCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DashboardTheme.primaryBlue, DashboardTheme.secondaryPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 4, height: 4)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DashboardTheme.neutralDark)
                    .lineLimit(1)
            }

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardTheme.primaryBlue.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct OperationsStatRow: View {
    let icon: String
    let label: String
    let value: Int
    let color: Color
    let background: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)

            Spacer(minLength: 0)

            Text("\(value)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct OperationsTextAction: View {
    let title: String
    let color: Color
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
