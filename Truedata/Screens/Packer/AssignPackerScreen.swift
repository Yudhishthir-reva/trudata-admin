import SwiftUI

/// Android `AssignPackerScreen` (home route `assign_paker`): who packs what. Each pending order has
/// its own Assign packer button and each order with a packer its own Change button; ticking several
/// does the same for all of them from the bar at the bottom. Either way: pick a packer from a
/// searchable sheet, then say yes.
struct AssignPackerScreen: View {
    var onHome: () -> Void
    @StateObject private var model = AssignPackerViewModel()
    @State private var pickingBeats = false
    @State private var pickingDate = false

    private var s: AssignPackerUiState { model.state }

    var body: some View {
        CashPage(title: "Assign Packer", onHome: onHome, onRefresh: { model.load() }) {
            AssignPackerList(model: model, onBeats: { pickingBeats = true }, onDate: { pickingDate = true })
        }
        .billSnackbar(message: Binding(get: { model.state.done }, set: { model.state.done = $0 }))
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: s.selected.isEmpty)
        .sheet(isPresented: $pickingBeats) { beatSheet }
        .sheet(isPresented: $pickingDate) {
            PackDatePickerSheet(initial: s.date) { model.setDate($0) }
        }
        .sheet(isPresented: Binding(get: { model.state.sellerPick != nil }, set: { if !$0 { model.closeSellerPicker() } })) {
            if let pick = model.state.sellerPick {
                PackSellerPickerSheet(
                    pick: pick, current: s.seller,
                    onArea: model.sellerArea, onQuery: model.sellerQuery, onMore: model.moreSellers,
                    onPick: model.setSeller
                )
            }
        }
        .sheet(isPresented: Binding(get: { model.state.pickingFor != nil }, set: { if !$0 { model.closePackerSheet() } })) {
            packerSheet
        }
        .overlay { dialogs.animation(.easeOut(duration: 0.18), value: dialogKey) }
    }

    // MARK: Bottom bar

    @ViewBuilder private var bottomBar: some View {
        if !s.selected.isEmpty && s.tab.canAssign {
            let n = s.selected.count
            BillBottomBar {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(n) \(n == 1 ? "order" : "orders") ticked").font(.system(size: 15, weight: .bold)).foregroundStyle(CashStyle.ink)
                        Text(billMoney(s.selectedOrders.reduce(0) { $0 + $1.total })).font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                    }
                    Spacer()
                    Button("Clear") { model.clearSelection() }
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(BillTone.err).padding(8)
                }
                BillPrimaryButton(
                    title: s.tab == .pending ? "Assign packer to \(n)" : "Change packer for \(n)",
                    icon: s.tab == .pending ? "person.badge.plus" : "arrow.left.arrow.right"
                ) { model.pickPackerFor(s.selected) }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: Sheets

    /// The beat picker's "All beats" row; no real beat has id 0.
    private static let allBeats = 0

    private var beatSheet: some View {
        PackPickerSheet(
            title: "Pick a beat",
            subtitle: "Show orders from this beat only",
            icon: "mappin.and.ellipse",
            rows: [PackPickRow(key: Self.allBeats, title: "All beats")] + s.allBeats.map { PackPickRow(key: $0.id, title: $0.name) },
            searchHint: "Search beats",
            current: s.beat?.id ?? Self.allBeats,
            emptyText: "Beats couldn't be loaded."
        ) { id in model.setBeat(model.state.allBeats.first { $0.id == id }) }
    }

    @ViewBuilder private var packerSheet: some View {
        let ids = s.pickingFor ?? []
        let current = s.currentPacker(ids)
        PackPickerSheet(
            title: s.tab == .pending ? "Choose a packer" : "Change packer",
            subtitle: "For \(orderLabel(ids))",
            icon: "person.fill",
            rows: s.packers.map { p in
                PackPickRow(key: p.id, title: p.name,
                            subtitle: [p.staffId, p.mobile].filter { !$0.isEmpty }.joined(separator: " · "),
                            badge: p.id == current ? "Current" : nil)
            },
            searchHint: "Search packers",
            current: current,
            emptyText: "No active packers. Add a staff member with the Paker role first."
        ) { id in
            if let p = model.state.packers.first(where: { $0.id == id }) { model.onPackerPicked(p) }
        }
    }

    /// "order #2026-27/4020" for one, "3 orders" for several.
    private func orderLabel(_ ids: Set<Int>) -> String {
        guard ids.count == 1 else { return "\(ids.count) orders" }
        let no = s.orders.first { ids.contains($0.id) }?.orderNo ?? ""
        return "order \(no)".trimmingCharacters(in: .whitespaces)
    }

    private func capitalized(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

    // MARK: Dialogs

    private var dialogKey: String {
        "\(s.confirm != nil)-\(s.logsFor?.id ?? 0)-\(s.dialogError != nil)"
    }

    @ViewBuilder private var dialogs: some View {
        if let message = s.dialogError {
            BillErrorDialog(message: message) { model.dismissError() }
        } else if let c = s.confirm {
            confirmDialog(c)
        } else if let o = s.logsFor {
            PackListDialog(
                title: "History",
                subtitle: [o.orderNo, o.shopName].filter { !$0.isEmpty }.joined(separator: " · "),
                icon: "clock.arrow.circlepath",
                onDismiss: { model.closeLogs() }
            ) {
                PackHistoryContent(logs: s.logs, error: s.logsError) { model.openLogs(o) }
            }
        }
    }

    private func confirmDialog(_ c: PendingAssign) -> some View {
        let label = capitalized(orderLabel(c.orderIds))
        let sameAsNow = s.currentPacker(c.orderIds) == c.packer.id
        let packingNow = s.orders.contains { c.orderIds.contains($0.id) && $0.board == .packing }
        let message: String
        if sameAsNow {
            message = "\(label) already \(c.orderIds.count == 1 ? "is" : "are") with \(c.packer.name). Assign again anyway?"
        } else if c.reassign {
            message = "\(label) will move to \(c.packer.name)." + (packingNow ? " Boxes packed so far stay." : "")
        } else {
            message = "\(label) will go to \(c.packer.name) for packing."
        }
        return BillConfirmDialog(
            icon: c.reassign ? "arrow.left.arrow.right" : "person.badge.plus",
            title: c.reassign ? "Move to \(c.packer.name)?" : "Assign to \(c.packer.name)?",
            message: message,
            confirmTitle: s.assigning ? "Assigning…" : "Yes, \(c.reassign ? "move" : "assign")",
            dismissTitle: "No",
            onConfirm: { model.confirmAssign() },
            onDismiss: { if !model.state.assigning { model.cancelAssign() } }
        )
        .id("\(c.packer.id)-\(c.orderIds.sorted())")
    }
}

/// The board itself: search, tabs, hint, filters and the cards.
private struct AssignPackerList: View {
    @ObservedObject var model: AssignPackerViewModel
    let onBeats: () -> Void
    let onDate: () -> Void

    var body: some View {
        let s = model.state
        let shown = s.shown
        LazyVStack(alignment: .leading, spacing: 8) {
            PackSearchBox(text: Binding(get: { model.state.query }, set: model.onQuery), hint: "Search bill no")
            PackCountTabs(
                tabs: BoardTab.allCases.map { ($0, $0 == .pending ? "To assign" : $0.title, s.count($0)) },
                selected: s.tab,
                loading: s.isLoading && s.counts.isEmpty,
                onSelect: model.onTab
            )
            PackTabHint(tab: s.tab)
            filters(s)
            if !shown.isEmpty { showingRow(s, shown.count) }
            content(s, shown)
            if s.canLoadMore && !s.isLoading {
                PackLoadMoreRow(page: s.page, error: s.moreError, onMore: model.loadMore)
            }
            if s.isLoading && !s.orders.isEmpty {
                ProgressView().tint(CashStyle.green).frame(maxWidth: .infinity).frame(height: 40)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 12)
    }

    private func filters(_ s: AssignPackerUiState) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                PackFilterPill(label: "Beat", value: s.beat?.name ?? "All beats", icon: "mappin.and.ellipse",
                               active: s.beat != nil, onClick: onBeats, onClear: { model.setBeat(nil) })
                PackFilterPill(label: "Bill date", value: s.date?.label ?? "Any date", icon: "calendar",
                               active: s.date != nil, onClick: onDate, onClear: { model.setDate(nil) })
            }
            PackFilterPill(
                label: "Seller",
                value: s.seller.map { [$0.title, $0.mobile].filter { !$0.isEmpty }.joined(separator: " · ") } ?? "All sellers",
                icon: "storefront", active: s.seller != nil,
                onClick: { model.openSellerPicker() }, onClear: { model.setSeller(nil) }
            )
        }
    }

    private func showingRow(_ s: AssignPackerUiState, _ count: Int) -> some View {
        HStack {
            Text(s.searching || count >= s.count(s.tab) ? packPlural(count, "order") : "Showing \(count) of \(s.count(s.tab))")
                .font(.system(size: 12)).foregroundStyle(CashStyle.muted)
            Spacer()
            if s.tab.canAssign {
                PackSelectAllChip(allOn: s.allShownSelected, count: count) { model.toggleAllShown() }
            }
        }
    }

    @ViewBuilder private func content(_ s: AssignPackerUiState, _ shown: [PackOrderDto]) -> some View {
        if s.isLoading && s.orders.isEmpty {
            PackSkeletonCards(count: 4)
        } else if let error = s.error, s.orders.isEmpty {
            BillErrorState(message: error) { model.load() }
        } else if shown.isEmpty {
            BillEmptyState(title: emptyTitle(s), message: emptyMessage(s), icon: "shippingbox")
        } else {
            ForEach(shown) { o in
                PackBoardOrderCard(
                    order: o, tab: s.tab, selected: s.selected.contains(o.id),
                    onToggle: { model.toggle(o.id) },
                    onAssign: { model.pickPackerFor([o.id]) },
                    onHistory: { model.openLogs(o) }
                )
            }
        }
    }

    private func emptyTitle(_ s: AssignPackerUiState) -> String {
        if s.filtered { return "Nothing matches" }
        switch s.tab {
        case .pending: return "No orders waiting"
        case .assigned: return "No orders with a packer"
        case .packing: return "Nothing in packing"
        case .packed: return "Nothing packed"
        }
    }

    private func emptyMessage(_ s: AssignPackerUiState) -> String {
        if s.filtered { return "Try another beat, date, seller or search." }
        switch s.tab {
        case .pending: return "Every pending order already has a packer."
        case .packed: return "Packed orders wait here until a rider is assigned."
        default: return "Orders show up here as packers work."
        }
    }
}

/// One line under the tabs saying what to do here.
private struct PackTabHint: View {
    let tab: BoardTab

    private var text: String {
        switch tab {
        case .pending: return "Tap Assign packer on an order, or tick several and assign them together."
        case .assigned: return "Not started yet. Tap Change to give an order to another packer."
        case .packing: return "In packing. Tap Change to hand an order to another packer; boxes stay."
        case .packed: return "Packed orders are locked. The packer can reopen one to change its boxes."
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tab == .packed ? "lock.fill" : "info.circle.fill").font(.system(size: 15)).foregroundStyle(BillTone.info)
            Text(text).font(.system(size: 12)).foregroundStyle(BillTone.info).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(PackTone.infoBg, in: RoundedRectangle(cornerRadius: 12))
        .id(tab)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: tab)
    }
}

private struct PackSelectAllChip: View {
    let allOn: Bool
    let count: Int
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                PackCheckbox(on: allOn)
                Text(allOn ? "None" : "All \(count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(CashStyle.ink)
            }
            .padding(.trailing, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Android `BoardOrderCard`: a tick box while the tab can assign, the order, its packer and the
/// history / assign / change buttons along the foot.
private struct PackBoardOrderCard: View {
    let order: PackOrderDto
    let tab: BoardTab
    let selected: Bool
    let onToggle: () -> Void
    let onAssign: () -> Void
    let onHistory: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if tab.canAssign { PackCheckbox(on: selected) }
                details
            }
            .padding(.leading, tab.canAssign ? 4 : 14).padding(.trailing, 14).padding(.top, 12).padding(.bottom, 10)
            .contentShape(Rectangle())
            .onTapGesture { if tab.canAssign { onToggle() } }
            PackTone.divider.frame(height: 1)
            footer
        }
        .background(selected ? CashStyle.pale : .white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? CashStyle.green : CashStyle.border, lineWidth: 1))
        .animation(.easeInOut(duration: 0.18), value: selected)
    }

    private var beatLine: String {
        [order.beatName.isEmpty ? nil : order.beatName, order.itemsCount.map { packPlural($0, "item") }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(order.orderNo).font(.system(size: 12, weight: .bold)).foregroundStyle(CashStyle.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let bill = order.billDate { Text("Bill \(bill)").font(.system(size: 11.5)).foregroundStyle(CashStyle.muted) }
            }
            Text(order.shopName.isEmpty ? order.sellerName : order.shopName)
                .font(.system(size: 15, weight: .bold)).foregroundStyle(CashStyle.ink).lineLimit(1)
            if !order.sellerName.isEmpty && order.sellerName != order.shopName {
                Text(order.sellerName).font(.system(size: 12)).foregroundStyle(CashStyle.muted).lineLimit(1)
            }
            HStack(spacing: 3) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 11)).foregroundStyle(BillTone.faint)
                Text(beatLine).font(.system(size: 12)).foregroundStyle(CashStyle.muted).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let kg = order.weightKg { PackWeightChip(kg: kg).padding(.trailing, 5) }
                Text(billMoney(order.total)).font(.system(size: 14, weight: .bold)).foregroundStyle(CashStyle.ink)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.fill").font(.system(size: 13))
                .foregroundStyle(order.hasPacker ? BillTone.info : BillTone.faint)
            VStack(alignment: .leading, spacing: 0) {
                Text(order.hasPacker ? (order.packerName ?? "") : "No packer yet")
                    .font(.system(size: 13, weight: order.hasPacker ? .semibold : .regular))
                    .foregroundStyle(order.hasPacker ? BillTone.info : CashStyle.muted).lineLimit(1)
                if order.hasPacker, let on = order.assignedOn {
                    Text("Assigned \(on)").font(.system(size: 11)).foregroundStyle(CashStyle.muted).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PackCardAction(title: "History", icon: "clock.arrow.circlepath", color: CashStyle.muted, filled: false, action: onHistory)
            switch tab {
            case .pending:
                PackCardAction(title: "Assign packer", icon: "person.badge.plus", color: CashStyle.green, filled: true, action: onAssign)
            case .assigned, .packing:
                PackCardAction(title: "Change", icon: "arrow.left.arrow.right", color: CashStyle.green, filled: false, action: onAssign)
            case .packed:
                PackCardAction(title: "Locked", icon: "lock.fill", color: BillTone.ok, filled: false, action: nil)
            }
        }
        .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 6)
    }
}

/// A small button on a card's footer; a nil `action` draws it as a label.
private struct PackCardAction: View {
    let title: String
    let icon: String
    let color: Color
    let filled: Bool
    let action: (() -> Void)?

    var body: some View {
        let label = HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(title).font(.system(size: 12.5, weight: .bold)).lineLimit(1)
        }
        .foregroundStyle(filled ? .white : color)
        .padding(.horizontal, 10).frame(height: 34)
        // Keeps its full label ("Assign packer"); the packer name beside it gives way instead.
        .fixedSize(horizontal: true, vertical: false)
        .background(filled ? color : color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

        if let action {
            Button(action: action) { label }.buttonStyle(.plain)
        } else {
            label
        }
    }
}

/// The history dialog's body: error, loading, nothing yet, or the log lines.
struct PackHistoryContent: View {
    let logs: [PackLogDto]?
    let error: String?
    let onRetry: () -> Void

    var body: some View {
        Group {
            if let error {
                BillErrorState(message: error, onRetry: onRetry)
            } else if let logs {
                if logs.isEmpty {
                    BillEmptyState(title: "Nothing logged yet", message: "Assigning, packing and box changes show up here.", icon: "clock.arrow.circlepath")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(logs) { PackLogRow(log: $0) }
                        }
                        .padding(.bottom, 16)
                    }
                }
            } else {
                PackSkeletonCards(count: 3)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.22), value: logs == nil)
    }
}
