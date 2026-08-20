//
//  ControlsCommonViews.swift
//  Truedata
//

import SwiftUI

struct ControlsMenuCard: View {
    let title: String
    var onNavigate: (String) -> Void

    var body: some View {
        DashboardCardChrome {
            VStack(alignment: .leading, spacing: 10) {
                DashboardBulletTitle(title: title)

                ControlsSection(title: "Staff") {
                    ControlsChip(title: "View Staff", icon: "list.bullet.rectangle", color: DashboardTheme.primaryBlue) {
                        onNavigate("register_staff_member")
                    }
                    ControlsChip(title: "Add Staff", icon: "person.badge.plus", color: DashboardTheme.secondaryPurple) {
                        onNavigate("add_new_staff_member")
                    }
                }

                ControlsSection(title: "Assets") {
                    ControlsChip(title: "Vehicles", icon: "car.fill", color: DashboardTheme.successGreen) {
                        onNavigate("view_vehicles")
                    }
                    ControlsChip(title: "Beats", icon: "mappin.and.ellipse", color: DashboardTheme.pickupOrange) {
                        onNavigate("view_beats")
                    }
                }

                ControlsSection(title: "Reports") {
                    ControlsChip(title: "Targets", icon: "chart.pie.fill", color: Color(hex: "8E44AD")) {
                        onNavigate("view_targets")
                    }
                    ControlsChip(title: "Summary", icon: "chart.bar.fill", color: Color(hex: "16A085")) {
                        onNavigate("view_beat_summary")
                    }
                }

                ControlsSection(title: "More") {
                    ControlsChip(title: "Beat Assign", icon: "list.bullet", color: Color(hex: "D35400")) {
                        onNavigate("assignment_history")
                    }
                    ControlsChip(title: "Sellers", icon: "storefront.fill", color: Color(hex: "2980B9")) {
                        onNavigate("seller_report")
                    }
                }

                ControlsSection(title: "Admin") {
                    ControlsChip(title: "Logins", icon: "desktopcomputer", color: DashboardTheme.dangerRed) {
                        onNavigate("new_device_login_requests")
                    }
                }
            }
        }
    }
}

private struct ControlsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .tracking(0.8)
                .padding(.horizontal, 2)

            FlowLayout(spacing: 6) {
                content
            }
        }
    }
}

private struct ControlsChip: View {
    let title: String
    let icon: String
    let color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DashboardTheme.neutralDark)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(color.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct ControlsApprovalCard: View {
    enum Kind {
        case leave
        case regularize
        case expense

        var title: String {
            switch self {
            case .leave: return "Leave Approval"
            case .regularize: return "Regularize Approval"
            case .expense: return "Expense Approval"
            }
        }

        var icon: String {
            switch self {
            case .leave: return "calendar.badge.minus"
            case .regularize: return "calendar.badge.clock"
            case .expense: return "doc.text.fill"
            }
        }

        var highlightColor: Color {
            switch self {
            case .leave: return DashboardTheme.dangerRed
            case .regularize: return DashboardTheme.warningYellow
            case .expense: return DashboardTheme.successGreen
            }
        }
    }

    let kind: Kind
    let todayCount: Int
    let pendingCount: Int
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                DashboardBulletTitle(title: kind.title)

                Spacer(minLength: 8)

                VStack(spacing: 6) {
                    Image(systemName: kind.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(DashboardTheme.primaryBlue)

                    VStack(spacing: 2) {
                        ControlsStatValue(
                            value: todayCount,
                            label: "Today",
                            highlight: kind.highlightColor,
                            highlighted: todayCount > 0
                        )
                        ControlsStatValue(
                            value: pendingCount,
                            label: "Pending"
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DashboardTheme.primaryBlue.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ControlsStatValue: View {
    let value: Int
    let label: String
    var highlight: Color = DashboardTheme.neutralDark
    var highlighted: Bool = false

    var body: some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(highlighted ? highlight : DashboardTheme.neutralDark)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
    }
}

struct ControlsReportCard: View {
    let title: String
    let total: Int
    let present: Int
    let absent: Int
    var onViewReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DashboardBulletTitle(title: title)

            Spacer(minLength: 8)

            VStack(spacing: 4) {
                ControlsReportRow(label: "Total", value: total, icon: "person.3.fill", color: DashboardTheme.primaryBlue)
                ControlsReportRow(label: "Present", value: present, icon: "checkmark.circle.fill", color: DashboardTheme.successGreen)
                ControlsReportRow(label: "Absent", value: absent, icon: "person.fill.xmark", color: DashboardTheme.dangerRed)
            }

            Spacer(minLength: 8)

            Button(action: onViewReport) {
                HStack(spacing: 4) {
                    Text("View Report")
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(DashboardTheme.primaryBlue)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(DashboardTheme.primaryBlue.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct ControlsReportRow: View {
    let label: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DashboardTheme.neutralMedium)

            Spacer(minLength: 4)

            Text("\(value)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Simple horizontal wrapping layout for control chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for placement in result.placements {
            subviews[placement.index].place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var placements: [Placement] = []

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            placements.append(Placement(index: index, x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return ArrangementResult(
            size: CGSize(width: maxWidth, height: y + rowHeight),
            placements: placements
        )
    }

    private struct Placement {
        let index: Int
        let x: CGFloat
        let y: CGFloat
    }

    private struct ArrangementResult {
        let size: CGSize
        let placements: [Placement]
    }
}
