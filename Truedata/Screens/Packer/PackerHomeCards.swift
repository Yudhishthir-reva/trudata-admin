import SwiftUI

// Android `PackerWidgets.kt`: the home cards for the two packer routes. The server sends them with
// no data, so each card loads its own counts, each with its own view model so the two never share
// counts. They load as they come on screen and again whenever an order is packed on this phone.

/// Home card for the `order_paker` route: the packer's queue at a glance.
struct PackerQueueCard: View {
    let title: String
    let onOpen: () -> Void
    @StateObject private var model = PackerWidgetViewModel()

    var body: some View {
        let s = model.state
        PackerWidgetCard(title: title.isEmpty ? "My Packing" : title, icon: "shippingbox", action: "Open", onOpen: onOpen) {
            if s.failed {
                Text("Couldn't load your orders").font(.system(size: 12.5)).foregroundStyle(CashStyle.muted)
            } else {
                HStack(spacing: 8) {
                    PackerWidgetCount(label: PackStage.assigned.title, value: s.toPack, accent: BillTone.warn, loading: s.loading)
                    PackerWidgetCount(label: PackStage.packing.title, value: s.packing, accent: BillTone.info, loading: s.loading)
                    PackerWidgetCount(label: PackStage.packed.title, value: s.packed, accent: BillTone.ok, loading: s.loading)
                }
            }
        }
        .task { await model.loadMine() }
    }
}

/// Home card for the `assign_paker` route: how many pending orders still need a packer.
struct AssignPackerCard: View {
    let title: String
    let onOpen: () -> Void
    @StateObject private var model = PackerWidgetViewModel()

    private var line: String {
        let s = model.state
        if s.loading { return "Loading pending orders…" }
        if s.failed { return "Couldn't load pending orders" }
        if s.pending == 0 { return "Every pending order has a packer" }
        return "\(s.pending) pending \(s.pending == 1 ? "order needs" : "orders need") a packer"
    }

    var body: some View {
        let busy = model.state.pending > 0
        PackerWidgetCard(title: title.isEmpty ? "Assign Packer" : title, icon: "person.badge.plus", action: "Assign", onOpen: onOpen) {
            Text(line).font(.system(size: 13, weight: busy ? .semibold : .regular))
                .foregroundStyle(busy ? CashStyle.ink : CashStyle.muted)
        }
        .task { await model.loadPending() }
    }
}

private struct PackerWidgetCard<Content: View>: View {
    let title: String
    let icon: String
    let action: String
    let onOpen: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    BillIconDisc(icon: icon, color: CashStyle.green, size: 36)
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(CashStyle.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 4) {
                        Text(action).font(.system(size: 13, weight: .bold))
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(CashStyle.green, in: RoundedRectangle(cornerRadius: 10))
                }
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "E0E9E3"), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

private struct PackerWidgetCount: View {
    let label: String
    let value: Int
    let accent: Color
    let loading: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(loading ? "–" : "\(value)").font(.system(size: 20, weight: .heavy)).foregroundStyle(accent)
            Text(label).font(.system(size: 11.5)).foregroundStyle(CashStyle.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
