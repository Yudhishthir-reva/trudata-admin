import SwiftUI

/// What the pack screen is asking about; one pop-up at a time, as on Android.
private enum PackOrderPrompt: Equatable {
    case start, newBox, complete, reopen
    case addItem(box: PackBox, initial: PackLine?)
    /// A box quantity change waiting for its yes.
    case setItem(box: PackBox, line: PackLine, qty: Int)
    case deleteBox(PackBox)
    case removeItem(box: PackBox, item: PackBoxItem)

    var key: String {
        switch self {
        case .start: return "start"
        case .newBox: return "box"
        case .complete: return "complete"
        case .reopen: return "reopen"
        case .addItem(let box, let line): return "add-\(box.id)-\(line?.id ?? 0)"
        case .setItem(let box, let line, let qty): return "set-\(box.id)-\(line.id)-\(qty)"
        case .deleteBox(let box): return "delete-\(box.id)"
        case .removeItem(let box, let item): return "remove-\(box.id)-\(item.id)"
        }
    }
}

/// Android `PackOrderScreen`: one order's lines and boxes. Assigned → Start packing; In Packing →
/// boxes can be added, filled, emptied and deleted, then Mark packed; Packed → Reopen packing.
/// Every change asks first.
struct PackOrderScreen: View {
    let orderId: Int
    var onHome: () -> Void
    @StateObject private var model: PackOrderViewModel
    @State private var prompt: PackOrderPrompt?

    init(orderId: Int, onHome: @escaping () -> Void) {
        self.orderId = orderId
        self.onHome = onHome
        _model = StateObject(wrappedValue: PackOrderViewModel(orderId: orderId))
    }

    var body: some View {
        let d = model.detail
        CashPage(title: d.map { $0.orderNo.isEmpty ? "Pack order" : $0.orderNo } ?? "Pack order", onHome: onHome, onRefresh: { model.load() }) {
            content
        }
        .billSnackbar(message: $model.message)
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .overlay { dialogs.animation(.easeOut(duration: 0.18), value: "\(prompt?.key ?? "")-\(model.dialogError != nil)") }
    }

    @ViewBuilder private var content: some View {
        if model.isLoading && model.detail == nil {
            PackSkeletonCards(count: 3).padding(.horizontal, 4)
        } else if let d = model.detail {
            PackOrderBody(detail: d, busy: model.busy, onAdd: { prompt = .addItem(box: $0, initial: $1) },
                          onDelete: { prompt = .deleteBox($0) }, onRemove: { prompt = .removeItem(box: $0, item: $1) })
                .padding(.horizontal, 4).padding(.bottom, 12)
        } else {
            BillErrorState(message: model.error ?? "Couldn't load the order.") { model.load() }
        }
    }

    // MARK: Bottom bar

    /// Gone on to a rider: no Start packing, and no Reopen to change boxes already shipped.
    @ViewBuilder private var bottomBar: some View {
        if let d = model.detail, d.afterPacking == nil {
            switch d.stage {
            case .assigned:
                BillBottomBar {
                    BillPrimaryButton(title: "Start packing", icon: "play.fill", loading: model.busy == .start) { prompt = .start }
                }
            case .packing:
                BillBottomBar {
                    Text(packingSummary(d)).font(.system(size: 13)).foregroundStyle(CashStyle.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 10) {
                        BillSecondaryButton(title: model.busy == .box ? "Adding…" : "New box", icon: "plus", enabled: model.busy == nil) {
                            prompt = .newBox
                        }
                        BillPrimaryButton(title: "Mark packed", icon: "checkmark.circle", loading: model.busy == .complete) {
                            prompt = .complete
                        }
                    }
                }
            case .packed:
                BillBottomBar {
                    BillSecondaryButton(title: model.busy == .reopen ? "Reopening…" : "Reopen packing", icon: "lock.open.fill",
                                        enabled: model.busy == nil) { prompt = .reopen }
                }
            }
        }
    }

    private func packingSummary(_ d: PackOrderDetail) -> String {
        var parts: [String] = []
        if d.packedKnown { parts.append("\(d.packedUnits) of \(d.totalUnits) units packed") }
        if let p = d.packedKg, let t = d.totalKg { parts.append("\(PackWeight.format(p)) of \(PackWeight.format(t))") }
        parts.append(packPlural(d.boxes.count, "box", "boxes"))
        return parts.joined(separator: " · ")
    }

    // MARK: Dialogs

    @ViewBuilder private var dialogs: some View {
        if let message = model.dialogError {
            BillErrorDialog(message: message) { model.dialogError = nil }
        } else if let prompt {
            promptView(prompt).id(prompt.key)
        }
    }

    @ViewBuilder private func promptView(_ p: PackOrderPrompt) -> some View {
        let orderNo = model.detail?.orderNo ?? ""
        switch p {
        case .start:
            confirm(icon: "play.fill", title: "Start packing?",
                    message: "\(orderNo) moves to Packing and you can start adding boxes.".trimmingCharacters(in: .whitespaces),
                    yes: "Yes, start") { model.startPacking() }
        case .newBox:
            confirm(icon: "plus", title: "Add a new box?",
                    message: "Box \((model.detail?.boxes.count ?? 0) + 1) is added to this order, empty. Put items in it next.",
                    yes: "Yes, add") { model.newBox() }
        case .complete:
            confirm(icon: "checkmark.circle", title: "Mark as packed?",
                    message: "The order goes to Assign Order for a rider. You can't change the boxes after this.",
                    yes: "Yes, packed") { model.completePacking() }
        case .reopen:
            confirm(icon: "lock.open.fill", title: "Reopen packing?",
                    message: "The order goes back to Packing so the boxes can be changed. Mark it packed again when done.",
                    yes: "Yes, reopen") { model.reopen() }
        case .deleteBox(let box):
            confirm(icon: "trash", title: "Delete \(box.name)?", message: "The box is empty, so nothing else changes.",
                    yes: "Yes, delete", color: BillTone.err) { model.deleteBox(box) }
        case .removeItem(let box, let item):
            confirm(icon: "xmark", title: "Remove from \(box.name)?", message: "\(item.qty) × \(item.name) goes back to the unpacked list.",
                    yes: "Yes, remove", color: BillTone.err) { model.removeItem(box: box, item: item) }
        case .setItem(let box, let line, let qty):
            setItemConfirm(box: box, line: line, qty: qty)
        case .addItem(let box, let initial):
            let known = model.detail?.packedKnown != false
            // A line can take what's left plus what this box already holds. Without counts from
            // the server, every line is offered and the server refuses too many.
            let lines = (model.detail?.lines ?? []).filter { !known || $0.left > 0 || box.qtyOf($0.id) > 0 }
            PackBoxItemDialog(box: box, lines: lines, packedKnown: known, initial: initial,
                              onSet: { line, qty in prompt = .setItem(box: box, line: line, qty: qty) },
                              onDismiss: { prompt = nil })
        }
    }

    private func setItemConfirm(box: PackBox, line: PackLine, qty: Int) -> some View {
        let inBox = box.qtyOf(line.id)
        let variant = line.variant.isEmpty ? "" : " (\(line.variant))"
        let title: String
        let message: String
        if qty == 0 {
            title = "Take out of \(box.name)?"
            message = "All \(inBox) × \(line.name) come out of \(box.name)."
        } else if inBox > 0 {
            title = "Change to \(qty) in \(box.name)?"
            message = "\(line.name)\(variant): \(inBox) → \(qty) in \(box.name)."
        } else {
            title = "Put \(qty) in \(box.name)?"
            message = "\(qty) × \(line.name)\(variant) go into \(box.name)."
        }
        return confirm(icon: qty == 0 ? "xmark" : "shippingbox", title: title, message: message,
                       yes: qty == 0 ? "Yes, take out" : "Yes", color: qty == 0 ? BillTone.err : CashStyle.green) {
            model.setItem(box: box, line: line, qty: qty)
        }
    }

    private func confirm(icon: String, title: String, message: String, yes: String,
                         color: Color = CashStyle.green, action: @escaping () -> Void) -> some View {
        BillConfirmDialog(icon: icon, title: title, message: message, confirmTitle: yes, confirmColor: color, dismissTitle: "No",
                          onConfirm: { prompt = nil; action() }, onDismiss: { prompt = nil })
    }
}

// MARK: - Body

/// The header, the items and one section per box.
private struct PackOrderBody: View {
    let detail: PackOrderDetail
    let busy: PackBusy?
    let onAdd: (PackBox, PackLine?) -> Void
    let onDelete: (PackBox) -> Void
    let onRemove: (PackBox, PackBoxItem) -> Void

    var body: some View {
        let d = detail
        // Only once packing is under way: on an order not started yet every line is pending.
        let pending = d.stage == .packing && d.packedKnown ? d.lines.filter { $0.left > 0 }.count : 0
        LazyVStack(alignment: .leading, spacing: 10) {
            PackOrderHeader(detail: d)
            PackSection(title: "Items", icon: "shippingbox", subtitle: itemsSubtitle(d, pending)) {
                if d.lines.isEmpty {
                    Text("The server sent no items for this order.").font(.system(size: 13)).foregroundStyle(CashStyle.muted)
                }
                ForEach(d.lines) { PackLineRow(line: $0, packedKnown: d.packedKnown, highlight: pending > 0 && $0.left > 0) }
            }
            if d.stage != .assigned {
                if d.boxes.isEmpty {
                    BillEmptyState(title: "No boxes yet", message: "Tap New box, then add items to it.", icon: "shippingbox")
                }
                ForEach(d.boxes) { box in
                    PackBoxSection(box: box, detail: d, editable: d.stage == .packing && busy == nil,
                                   onAdd: onAdd, onDelete: onDelete, onRemove: onRemove)
                }
            }
        }
        .animation(.easeInOut(duration: 0.24), value: d)
    }

    private func itemsSubtitle(_ d: PackOrderDetail, _ pending: Int) -> String {
        var parts = [packPlural(d.lines.count, "product"), packPlural(d.totalUnits, "unit")]
        if pending > 0 { parts.append("\(pending) pending") }
        return parts.joined(separator: " · ")
    }
}

/// Android `CcSection` with its trailing slot (the box's "+ Add item" and delete).
private struct PackSection<Trailing: View, Content: View>: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                BillIconDisc(icon: icon, color: CashStyle.green)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(CashStyle.ink)
                    if let subtitle, !subtitle.isEmpty { Text(subtitle).font(.system(size: 11)).foregroundStyle(CashStyle.muted) }
                }
                Spacer(minLength: 0)
                trailing()
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border, lineWidth: 1))
    }
}

extension PackSection where Trailing == EmptyView {
    init(title: String, icon: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, icon: icon, subtitle: subtitle, trailing: { EmptyView() }, content: content)
    }
}

private struct PackOrderHeader: View {
    let detail: PackOrderDetail

    private var dates: String {
        let d = detail
        let bill = (PackDates.label(d.date) ?? (d.date.isEmpty ? nil : d.date)).map { "Bill \($0)" }
        let assigned = PackDates.label(d.assignDate).map { "Assigned \($0)" }
        return [bill, assigned].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        let d = detail
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(d.shopName.isEmpty ? d.sellerName : d.shopName).font(.system(size: 16, weight: .bold)).foregroundStyle(CashStyle.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PackStagePill(stage: d.stage, status: d.status)
            }
            if !d.sellerName.isEmpty && d.sellerName != d.shopName {
                Text(d.sellerName).font(.system(size: 13)).foregroundStyle(CashStyle.muted)
            }
            Text([d.orderNo, d.beatName].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(CashStyle.muted)
            if !dates.isEmpty { Text(dates).font(.system(size: 12)).foregroundStyle(CashStyle.muted) }
            if let total = d.totalKg { weights(d, total) }
            if d.totalUnits > 0 && d.packedKnown { progress(d) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border, lineWidth: 1))
    }

    private func weights(_ d: PackOrderDetail, _ total: Double) -> some View {
        HStack(spacing: 8) {
            PackWeightStat(label: "Total weight", kg: total, color: CashStyle.ink)
            if let packed = d.packedKg, let left = d.leftKg {
                PackWeightStat(label: "Packed", kg: packed, color: BillTone.ok)
                PackWeightStat(label: "Left", kg: left, color: left > 0 ? BillTone.warn : BillTone.ok)
            }
        }
        .padding(.top, 6)
    }

    private func progress(_ d: PackOrderDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            BillClearedBar(cleared: d.packedUnits, total: d.totalUnits, track: BillTone.track, fill: CashStyle.green)
            Text("\(d.packedUnits) / \(d.totalUnits) units packed").font(.system(size: 11.5)).foregroundStyle(CashStyle.muted)
        }
        .padding(.top, 6)
    }
}

private struct PackWeightStat: View {
    let label: String
    let kg: Double
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 11)).foregroundStyle(CashStyle.muted).lineLimit(1)
            Text(PackWeight.format(kg)).font(.system(size: 15, weight: .heavy)).foregroundStyle(color).lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BillTone.track, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// "500 gms × 4 = 2 kg": the variant when it is the unit's weight, else the weight itself.
private func packWeightSum(_ variant: String, _ unitKg: Double, _ qty: Int) -> String {
    let unit = !variant.isEmpty && PackWeight.ofVariant(variant) == unitKg ? variant : PackWeight.format(unitKg)
    return "\(unit) × \(qty) = \(PackWeight.format(unitKg * Double(qty)))"
}

/// The product's photo, or a box icon while it loads, fails or isn't sent.
private struct PackProductThumb: View {
    let url: String
    var body: some View {
        ZStack {
            Image(systemName: "shippingbox").font(.system(size: 17)).foregroundStyle(BillTone.faint)
            if let link = URL(string: url), !url.isEmpty {
                AsyncImage(url: link) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                    .frame(width: 40, height: 40)
            }
        }
        .frame(width: 40, height: 40)
        .background(BillTone.track)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// `highlight` marks a line still waiting for its boxes, so the last few stand out of a long order.
private struct PackLineRow: View {
    let line: PackLine
    let packedKnown: Bool
    let highlight: Bool

    private var detail: String {
        guard let unit = line.unitKg else { return line.variant }
        let sum = packWeightSum(line.variant, unit, line.qty)
        if sum.hasPrefix(line.variant) { return sum }
        return [line.variant, sum].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 10) {
            PackProductThumb(url: line.image)
            VStack(alignment: .leading, spacing: 1) {
                Text(line.name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(CashStyle.ink).lineLimit(2)
                if !detail.isEmpty { Text(detail).font(.system(size: 11.5)).foregroundStyle(CashStyle.muted) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            counts
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(highlight ? BillTone.warnBg : .clear, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private var counts: some View {
        if !packedKnown {
            Text("× \(line.qty)").font(.system(size: 13.5, weight: .bold)).foregroundStyle(CashStyle.ink)
        } else {
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 4) {
                    Text("\(line.packed)/\(line.qty)").font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(line.left == 0 ? BillTone.ok : highlight ? BillTone.warn : CashStyle.ink)
                    if line.left == 0 {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(BillTone.ok)
                            .accessibilityLabel("Packed")
                    }
                }
                if (line.left > 0 && line.packed > 0) || highlight {
                    Text([ "\(line.left) left", line.leftKg.map(PackWeight.format)].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(highlight ? BillTone.warn : CashStyle.muted)
                }
            }
        }
    }
}

/// One box: its items, "+ Add item" and, while empty, a delete button.
private struct PackBoxSection: View {
    let box: PackBox
    let detail: PackOrderDetail
    let editable: Bool
    let onAdd: (PackBox, PackLine?) -> Void
    let onDelete: (PackBox) -> Void
    let onRemove: (PackBox, PackBoxItem) -> Void

    private var packing: Bool { detail.stage == .packing }

    private var subtitle: String {
        let what = box.items.isEmpty ? packPlural(box.itemsCount, "product")
            : "\(packPlural(box.items.count, "product")) · \(packPlural(box.units, "unit"))"
        let kg = box.kg.flatMap { $0 > 0 ? PackWeight.format($0) : nil }
        return [what, kg].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        PackSection(title: box.name, icon: "box.truck", subtitle: subtitle) {
            if packing { actions }
        } content: {
            if !box.items.isEmpty {
                ForEach(box.items) { item in itemRow(item) }
            } else if box.itemsCount > 0 {
                Text("The server didn't send this box's contents.").font(.system(size: 13)).foregroundStyle(BillTone.faint)
            } else {
                Text("Empty").font(.system(size: 13)).foregroundStyle(BillTone.faint)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 0) {
            Button { onAdd(box, nil) } label: {
                Text("+ Add item").font(.system(size: 13, weight: .bold)).foregroundStyle(CashStyle.green).padding(8)
            }
            .buttonStyle(.plain).disabled(!editable)
            // The server deletes only an empty box.
            if box.isEmpty {
                Button { onDelete(box) } label: {
                    Image(systemName: "trash").font(.system(size: 16)).foregroundStyle(BillTone.err).frame(width: 40, height: 40)
                }
                .buttonStyle(.plain).disabled(!editable)
                .accessibilityLabel("Delete \(box.name)")
            }
        }
        .opacity(editable ? 1 : 0.5)
    }

    private func itemRow(_ i: PackBoxItem) -> some View {
        let line = detail.lines.first { $0.id == i.orderDetailId }
        let variant = i.variant.isEmpty ? (line?.variant ?? "") : i.variant
        let info = [variant.isEmpty ? nil : variant, i.kg.map(PackWeight.format)].compactMap { $0 }.joined(separator: " · ")
        return HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(i.name.isEmpty ? (line?.name ?? "Item \(i.orderDetailId)") : i.name).font(.system(size: 13.5)).foregroundStyle(CashStyle.ink)
                if !info.isEmpty { Text(info).font(.system(size: 11)).foregroundStyle(CashStyle.muted) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("× \(i.qty)").font(.system(size: 13.5, weight: .bold)).foregroundStyle(CashStyle.ink)
            if packing {
                Button { onRemove(box, i) } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(CashStyle.muted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain).disabled(!editable)
                .accessibilityLabel("Remove \(i.name)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if editable, let line { onAdd(box, line) } }
    }
}

// MARK: - Box item dialog

/// Picks a line and sets how many of it are in `box`. The number is the box's total for the line
/// (the server replaces, not adds), so a line already in the box opens on what it holds.
private struct PackBoxItemDialog: View {
    let box: PackBox
    let lines: [PackLine]
    let packedKnown: Bool
    let initial: PackLine?
    let onSet: (PackLine, Int) -> Void
    let onDismiss: () -> Void
    @State private var picked: PackLine?
    @State private var qty = ""
    @State private var started = false

    private func maxOf(_ l: PackLine) -> Int { packedKnown ? box.qtyOf(l.id) + l.left : l.qty }
    private func startQty(_ l: PackLine) -> Int { box.qtyOf(l.id) > 0 ? box.qtyOf(l.id) : maxOf(l) }

    var body: some View {
        PackListDialog(title: initial != nil ? "Change in \(box.name)" : "Add to \(box.name)",
                       subtitle: "Pick an item, then how many are in this box", icon: "plus", onDismiss: onDismiss) {
            if lines.isEmpty {
                Text("Every item is already in a box.").font(.system(size: 13)).foregroundStyle(CashStyle.muted)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(lines) { lineRow($0) }
                    }
                }
                if let l = picked { qtyRow(l) } else { Spacer().frame(height: 12) }
            }
        }
        .onAppear {
            guard !started else { return }
            started = true
            picked = initial
            qty = initial.map { String(startQty($0)) } ?? ""
        }
    }

    private func lineRow(_ l: PackLine) -> some View {
        let on = picked?.id == l.id
        let inBox = box.qtyOf(l.id)
        let left = packedKnown
            ? ["\(l.left) left", l.leftKg.flatMap { $0 > 0 ? PackWeight.format($0) : nil }].compactMap { $0 }.joined(separator: " · ")
            : "\(l.qty) ordered"
        return Button { picked = l; qty = String(startQty(l)) } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(l.name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(CashStyle.ink)
                    if !l.variant.isEmpty { Text(l.variant).font(.system(size: 11.5)).foregroundStyle(CashStyle.muted) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(left).font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                    if inBox > 0 { Text("\(inBox) in this box").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(CashStyle.green) }
                }
            }
            .padding(12)
            .background(on ? CashStyle.pale : .white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? CashStyle.green : CashStyle.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func qtyRow(_ l: PackLine) -> some View {
        let max = maxOf(l)
        let n = Int(qty) ?? -1
        let inBox = box.qtyOf(l.id)
        let removing = n == 0 && inBox > 0
        // 0 only takes out what's there; it never adds an empty row.
        let enabled = (n >= 1 && n <= max && n != inBox) || removing
        let title = removing ? "Remove" : inBox > 0 ? "Update" : "Add"
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("In this box (max \(max))").font(.system(size: 11, weight: .semibold)).foregroundStyle(CashStyle.muted)
                TextField("", text: Binding(get: { qty }, set: { qty = String($0.filter(\.isNumber).prefix(5)) }))
                    .keyboardType(.numberPad).font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 12).frame(height: 52)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CashStyle.bright, lineWidth: 1.5))
            BillPrimaryButton(title: title, color: removing ? BillTone.err : CashStyle.green, enabled: enabled) { onSet(l, n) }
        }
        .padding(.vertical, 12)
    }
}
