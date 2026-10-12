import SwiftUI

struct OfficeStaffHome: View {
    let items: [DashboardItem]
    let onNavigate: (String) -> Void

    private func item(_ route: String) -> DashboardItem? { items.first { $0.route == route } }
    private var attendance: JSONValue? { item("attendance")?.payload }
    private var checkedIn: Bool { attendance?["in_time_status"]?.boolValue ?? false }
    private var checkedOut: Bool { attendance?["out_time_status"]?.boolValue ?? false }
    private let shortcuts = [
        ("cash_collection", "Cash Collection", "banknote", "Submit today's cash"),
        ("advance_payment", "My Payment Advance", "indianrupeesign.circle", "Advances & repayments"),
        ("view_leaves", "Leaves", "calendar", "Apply & track"),
        ("regularization_requests", "Regularize", "clock", "Fix a missed punch"),
        ("apply_reimbursements", "Expenses", "receipt", "Claim expenses")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("TODAY").font(.caption.bold())
                    Text(checkedOut && checkedIn ? "Day complete" : checkedIn ? "You're checked in" : "You haven't checked in").font(.title2.bold())
                    HStack {
                        VStack(alignment: .leading) { Text("In").font(.caption); Text(time("in_time", done: checkedIn)) }
                        Spacer()
                        VStack(alignment: .leading) { Text("Out").font(.caption); Text(time("out_time", done: checkedOut)) }
                    }
                    Button { onNavigate("attendance") } label: {
                        Label(checkedOut && checkedIn ? "View attendance" : checkedIn ? "Check out" : "Check in", systemImage: "clock")
                            .frame(maxWidth: .infinity).padding(12)
                            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                }.padding(20).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
                    .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 22))
                Text("Quick actions").font(.title3.bold())
                ForEach(shortcuts, id: \.0) { route, title, icon, detail in
                    if let entry = item(route) {
                        action(title: entry.title.isEmpty ? title : entry.title, detail: detail, icon: icon, route: route)
                    }
                }
                action(title: "Utility", detail: "All your tools", icon: "square.grid.2x2", route: "utility")
                if item("view_leaves") != nil || item("regularization_requests") != nil || item("apply_reimbursements") != nil {
                    Text("My requests").font(.title3.bold())
                    requestRow("Leaves", route: "view_leaves", pending: ["pendingLeaveCount", "pending_leave_count"], total: ["totalLeaveCount", "total_leave_count"])
                    requestRow("Regularize", route: "regularization_requests", pending: ["pendingRegularizeCount", "pending_regularize_count"], total: ["allRegularizeCount", "totalRegulizeCount"])
                    requestRow("Expenses", route: "apply_reimbursements", pending: ["pendingExpenseCount", "pending_expense_count"], total: ["totalExpenseCount", "total_expense_count"])
                }
            }.padding(16)
        }
    }

    private func time(_ key: String, done: Bool) -> String {
        let text = attendance?[key]?.stringValue ?? ""
        return done && !text.isEmpty && !text.lowercased().contains("no data") ? text : "—"
    }

    private func action(title: String, detail: String, icon: String, route: String) -> some View {
        Button { onNavigate(route) } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundStyle(CashStyle.green).frame(width: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(CashStyle.green)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }

    @ViewBuilder private func requestRow(_ title: String, route: String, pending: [String], total: [String]) -> some View {
        if let entry = item(route) {
            let pendingCount = pending.compactMap { entry.payload?[$0]?.intValue }.max() ?? 0
            let totalCount = total.compactMap { entry.payload?[$0]?.intValue }.max() ?? 0
            action(title: title, detail: "\(pendingCount) pending · \(totalCount) total", icon: "doc.text", route: route)
        }
    }
}
