import SwiftUI

// Android `PackerUi.kt` and the shared bits of `PackerScreens.kt`: count tabs, filter pills, the
// picker sheets, skeleton cards and the order card, drawn with the bill register's CcKit port
// (BillTone, BillPill, BillIconDisc, …) so the packer screens match the cash and bill screens.

/// The two `CcColors` the bill register port didn't need.
enum PackTone {
    static let infoBg = Color(hex: "E0F2FE")
    static let divider = Color(hex: "F1F3F5")
    static let shimmer = Color(hex: "E9ECEF")
}

func packPlural(_ n: Int, _ word: String, _ words: String? = nil) -> String {
    "\(n) \(n == 1 ? word : (words ?? word + "s"))"
}

// MARK: - Count tabs

/// A tab per status with its count stacked over the label, so four tabs fit a phone without
/// cutting "Packing (12)". The picked tab's pill slides under it.
struct PackCountTabs<T: Hashable>: View {
    let tabs: [(value: T, label: String, count: Int)]
    let selected: T
    /// Counts aren't known yet: show a dash rather than a misleading 0.
    var loading = false
    let onSelect: (T) -> Void

    private var index: Int { tabs.firstIndex { $0.value == selected } ?? 0 }

    var body: some View {
        GeometryReader { proxy in
            let cell = proxy.size.width / CGFloat(max(tabs.count, 1))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(LinearGradient(colors: [CashStyle.deep, CashStyle.green], startPoint: .leading, endPoint: .trailing))
                    .frame(width: cell, height: 52)
                    .offset(x: cell * CGFloat(index))
                    .animation(.spring(response: 0.32, dampingFraction: 0.8), value: index)
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { _, tab in
                        cellView(tab.value, tab.label, tab.count).frame(width: cell)
                    }
                }
            }
        }
        .frame(height: 52)
        .padding(3)
        .background(BillTone.track, in: RoundedRectangle(cornerRadius: 14))
    }

    private func cellView(_ value: T, _ label: String, _ count: Int) -> some View {
        let on = value == selected
        return Button { onSelect(value) } label: {
            VStack(spacing: 0) {
                Text(loading ? "–" : "\(count)").font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(on ? .white : CashStyle.ink).lineLimit(1)
                Text(label).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(on ? .white : CashStyle.muted).lineLimit(1).minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .contentShape(RoundedRectangle(cornerRadius: 11))
            .animation(.easeInOut(duration: 0.22), value: on)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skeleton

/// Grey placeholder cards with a soft sweep, shown while a list loads.
struct PackSkeletonCards: View {
    var count = 4
    @State private var sweep = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        bar(0.35, 12)
                        Spacer()
                        bar(0.25, 12)
                    }
                    bar(0.7, 16)
                    bar(0.5, 11)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border, lineWidth: 1))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { sweep = true }
        }
    }

    private func bar(_ fraction: CGFloat, _ height: CGFloat) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width * fraction
            RoundedRectangle(cornerRadius: 6)
                .fill(BillTone.track)
                .overlay {
                    LinearGradient(colors: [BillTone.track, PackTone.shimmer, BillTone.track], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 160)
                        .offset(x: sweep ? width + 80 : -160)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .frame(width: width, height: height)
        }
        .frame(height: height)
    }
}

// MARK: - Filters and search

/// A dropdown-looking button that opens a picker: "Beat · All beats". While `active`, a cross
/// drops the filter without opening its picker.
struct PackFilterPill: View {
    let label: String
    let value: String
    let icon: String
    let active: Bool
    let onClick: () -> Void
    var onClear: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(active ? CashStyle.green : CashStyle.muted).frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(CashStyle.muted)
                Text(value).font(.system(size: 13.5, weight: .bold)).foregroundStyle(CashStyle.ink).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if active, let onClear {
                Button(action: onClear) {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(CashStyle.muted)
                        .frame(width: 28, height: 28).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear \(label)")
            } else {
                Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold)).foregroundStyle(CashStyle.muted)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(active ? CashStyle.pale : .white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(active ? CashStyle.green : CashStyle.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onClick)
        .animation(.easeInOut(duration: 0.2), value: active)
    }
}

/// Android `SearchBox`: a white rounded field with a search icon and a clear cross.
struct PackSearchBox: View {
    @Binding var text: String
    let hint: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(CashStyle.muted)
            TextField(hint, text: $text)
                .font(.system(size: 15))
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold)).foregroundStyle(CashStyle.muted)
                        .frame(width: 32, height: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14).frame(height: 54)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border, lineWidth: 1))
    }
}

// MARK: - Small marks

/// An order's total weight, set apart from the line it sits on so a packer finds it at a glance.
struct PackWeightChip: View {
    let kg: Double
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "scalemass.fill").font(.system(size: 10))
            Text(PackWeight.format(kg)).font(.system(size: 12, weight: .bold)).lineLimit(1)
        }
        .foregroundStyle(CashStyle.green)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 8))
    }
}

/// An order past packing reads its rider status in grey; otherwise Assigned amber, In Packing
/// blue, Packed green.
struct PackStagePill: View {
    let stage: PackStage
    let status: Int
    var body: some View {
        if let after = PackStage.afterPackingTitle(status) {
            BillPill(text: after, fg: BillTone.mutedFg, bg: BillTone.mutedBg)
        } else {
            switch stage {
            case .assigned: BillPill(text: stage.title, fg: BillTone.warn, bg: BillTone.warnBg)
            case .packing: BillPill(text: stage.title, fg: BillTone.info, bg: PackTone.infoBg)
            case .packed: BillPill(text: stage.title, fg: BillTone.ok, bg: BillTone.okBg)
            }
        }
    }
}

/// The ticked / unticked square Android's Material checkbox draws.
struct PackCheckbox: View {
    let on: Bool
    var body: some View {
        Image(systemName: on ? "checkmark.square.fill" : "square")
            .font(.system(size: 20))
            .foregroundStyle(on ? CashStyle.green : BillTone.faint)
            .frame(width: 40, height: 40)
    }
}

/// The next page's spinner, which asks for that page as it comes into view, or a retry line.
struct PackLoadMoreRow: View {
    let page: Int
    let error: String?
    let onMore: () -> Void
    var body: some View {
        if error == nil {
            ProgressView().tint(CashStyle.green).frame(maxWidth: .infinity).frame(height: 40)
                .task(id: page) { onMore() }
        } else {
            Button(action: onMore) {
                Text("Couldn't load more. Tap to try again.").font(.system(size: 13, weight: .semibold)).foregroundStyle(BillTone.err)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Order card (My Packing)

/// Android `OrderCard` as My Packing draws it: the stage pill, no price, the whole card opens it.
struct PackOrderCard: View {
    let order: PackOrderDto

    private var subtitle: String {
        [order.beatName.isEmpty ? nil : order.beatName, order.itemsCount.map { packPlural($0, "item") }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private var dates: String {
        [order.billDate.map { "Bill \($0)" }, order.assignedOn.map { "Assigned \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(order.orderNo).font(.system(size: 12, weight: .bold)).foregroundStyle(CashStyle.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PackStagePill(stage: order.stage, status: order.status)
            }
            Text(order.shopName.isEmpty ? order.sellerName : order.shopName)
                .font(.system(size: 14.5, weight: .bold)).foregroundStyle(CashStyle.ink).lineLimit(1)
            if !order.sellerName.isEmpty && order.sellerName != order.shopName {
                Text(order.sellerName).font(.system(size: 12)).foregroundStyle(CashStyle.muted).lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(subtitle).font(.system(size: 12)).foregroundStyle(CashStyle.muted).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let kg = order.weightKg { PackWeightChip(kg: kg) }
            }
            if !dates.isEmpty {
                Text(dates).font(.system(size: 11.5)).foregroundStyle(CashStyle.muted).lineLimit(1)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - History

/// One line of an order's history: what happened, when, by whom.
struct PackLogRow: View {
    let log: PackLogDto

    private var who: String {
        let by = log.doneBy.map { "by \($0)" }
        let packer = log.packerName.flatMap { $0 == log.doneBy ? nil : "packer \($0)" }
        return [by, packer].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(log.title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(CashStyle.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(PackDates.label(log.createdAt) ?? log.createdAt).font(.system(size: 11)).foregroundStyle(CashStyle.muted)
            }
            if !log.note.isEmpty { Text(log.note).font(.system(size: 12.5)).foregroundStyle(CashStyle.ink) }
            if !who.isEmpty { Text(who).font(.system(size: 11.5)).foregroundStyle(CashStyle.muted) }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BillTone.track, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - List dialog

/// Android `CcListDialog`: a tall white pop-up with an icon disc, a title, a close cross and a
/// list under them. It springs in; a tap outside closes it.
struct PackListDialog<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var shown = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(shown ? 0.4 : 0).ignoresSafeArea()
                    .onTapGesture(perform: onDismiss)
                VStack(alignment: .leading, spacing: 12) {
                    header
                    content()
                }
                .padding([.horizontal, .top], 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: proxy.size.height * 0.88, alignment: .top)
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 16)
                .scaleEffect(shown ? 1 : 0.9)
                .opacity(shown ? 1 : 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: shown)
        .transition(.opacity)
        .onAppear { shown = true }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let icon { BillIconDisc(icon: icon, color: CashStyle.green, size: 38) }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 17, weight: .heavy)).foregroundStyle(CashStyle.ink)
                if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(CashStyle.muted) }
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(CashStyle.muted)
                    .frame(width: 40, height: 40).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }
}

// MARK: - Picker sheet

/// One row in a picker sheet.
struct PackPickRow<K: Hashable>: Identifiable {
    let key: K
    let title: String
    var subtitle = ""
    var badge: String? = nil
    var id: K { key }
}

/// Android `PickerSheet` in its single-pick form: a search box over a list; a tap picks one row
/// and closes.
struct PackPickerSheet<K: Hashable>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let rows: [PackPickRow<K>]
    let searchHint: String
    let current: K?
    var emptyText = "Nothing to pick."
    let onPick: (K) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var shown: [PackPickRow<K>] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return rows }
        return rows.filter { $0.title.localizedCaseInsensitiveContains(q) || $0.subtitle.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PackSheetHeader(icon: icon, title: title, subtitle: subtitle)
            PackSearchBox(text: $query, hint: searchHint)
            ScrollView {
                LazyVStack(spacing: 6) {
                    if shown.isEmpty {
                        Text(rows.isEmpty ? emptyText : "Nothing matches \"\(query)\".")
                            .font(.system(size: 13)).foregroundStyle(CashStyle.muted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 20).padding(.horizontal, 4)
                    }
                    ForEach(shown) { row in
                        PackChoiceRow(title: row.title, subtitle: row.subtitle, badge: row.badge, on: row.key == current) {
                            // Picked first: a sheet bound to the model's state closes itself on the pick.
                            onPick(row.key)
                            dismiss()
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 16).padding(.top, 20)
        .background(BillTone.page.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

/// A sheet's icon disc, title and one line of help.
struct PackSheetHeader: View {
    let icon: String
    let title: String
    let subtitle: String?
    var body: some View {
        HStack(spacing: 10) {
            BillIconDisc(icon: icon, color: CashStyle.green, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 17, weight: .heavy)).foregroundStyle(CashStyle.ink)
                if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(CashStyle.muted) }
            }
            Spacer(minLength: 0)
        }
    }
}

/// A pickable row: title, a muted line, an optional badge and a radio mark.
struct PackChoiceRow: View {
    let title: String
    var subtitle = ""
    var badge: String? = nil
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(CashStyle.ink).lineLimit(2)
                    if !subtitle.isEmpty { Text(subtitle).font(.system(size: 11.5)).foregroundStyle(CashStyle.muted).lineLimit(1) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let badge {
                    Text(badge).font(.system(size: 11, weight: .bold)).foregroundStyle(CashStyle.muted)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(BillTone.track, in: RoundedRectangle(cornerRadius: 10))
                }
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 18))
                    .foregroundStyle(on ? CashStyle.green : BillTone.faint)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minHeight: 56)
            .background(on ? CashStyle.pale : .white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? CashStyle.green : CashStyle.border, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Seller picker

/// Finds a seller the way the order filters do: narrow by state, then city, then beat, and search
/// shop names; the list pages in from the server as it scrolls. A tap picks the seller and closes.
struct PackSellerPickerSheet: View {
    let pick: SellerPickState
    let current: PackSeller?
    let onArea: (_ stateId: Int?, _ cityId: Int?, _ beatId: Int?) -> Void
    let onQuery: (String) -> Void
    let onMore: () -> Void
    let onPick: (PackSeller?) -> Void

    private var countLine: String {
        if pick.loading { return "Loading sellers…" }
        if let error = pick.error { return error }
        return packPlural(pick.total, "seller")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PackSheetHeader(icon: "storefront", title: "Pick a seller", subtitle: "Narrow by area, or search shop, owner or mobile")
                .padding(.bottom, 4)
            HStack(spacing: 6) {
                PackAreaMenu(label: "State", value: pick.state?.name, options: pick.areas, enabled: !pick.areas.isEmpty) {
                    onArea($0, nil, nil)
                }
                PackAreaMenu(label: "City", value: pick.city?.name, options: pick.state?.children ?? [], enabled: pick.state != nil) {
                    onArea(pick.stateId, $0, nil)
                }
                PackAreaMenu(label: "Beat", value: pick.beat?.name, options: pick.city?.children ?? [], enabled: pick.city != nil) {
                    onArea(pick.stateId, pick.cityId, $0)
                }
            }
            PackSearchBox(text: Binding(get: { pick.query }, set: onQuery), hint: "Search shop, owner or mobile")
            Text(countLine).font(.system(size: 12))
                .foregroundStyle(pick.error != nil && !pick.loading ? BillTone.err : CashStyle.muted)
                .padding(.top, 2).padding(.leading, 2)
            list
        }
        .padding(.horizontal, 16).padding(.top, 20)
        .background(BillTone.page.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func sellerLine(_ s: PackSeller) -> String {
        [s.name == s.title ? "" : s.name, s.mobile, s.beat, s.active ? "" : "Inactive"]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var list: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(spacing: 6) {
                    PackChoiceRow(title: "All sellers", subtitle: "Show every seller's orders", on: current == nil) { onPick(nil) }
                        .id("top")
                    if pick.loading && pick.sellers.isEmpty {
                        PackSkeletonCards(count: 4)
                    } else if !pick.loading && pick.sellers.isEmpty && pick.error == nil {
                        Text("No sellers match.").font(.system(size: 13)).foregroundStyle(CashStyle.muted)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 20).padding(.horizontal, 4)
                    }
                    ForEach(pick.sellers) { s in
                        PackChoiceRow(title: s.title, subtitle: sellerLine(s), on: current?.id == s.id) { onPick(s) }
                    }
                    if pick.canLoadMore {
                        Text("Loading more…").font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                            .frame(maxWidth: .infinity).padding(12)
                            .task(id: pick.page) { onMore() }
                    }
                }
                .padding(.bottom, 12)
            }
            // A new area or search starts the list again from the top.
            .onChange(of: "\(pick.stateId ?? 0)-\(pick.cityId ?? 0)-\(pick.beatId ?? 0)-\(pick.query)") { _, _ in
                reader.scrollTo("top", anchor: .top)
            }
        }
    }
}

/// A compact dropdown for one level of the area tree; the first row clears it.
private struct PackAreaMenu: View {
    let label: String
    let value: String?
    let options: [PackArea]
    let enabled: Bool
    let onPick: (Int?) -> Void

    private var allTitle: String { label == "City" ? "All cities" : "All \(label.lowercased())s" }

    var body: some View {
        Menu {
            Button(allTitle) { onPick(nil) }
            ForEach(options) { o in Button(o.name) { onPick(o.id) } }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(CashStyle.muted)
                HStack(spacing: 2) {
                    Text(value ?? "All").font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(enabled ? CashStyle.ink : BillTone.faint).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(CashStyle.muted)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(value != nil ? CashStyle.pale : .white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(value != nil ? CashStyle.green : CashStyle.border, lineWidth: 1))
        }
        .disabled(!enabled)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Date picker

/// Android `AdvanceDatePickerDialog`: a calendar up to today, Cancel and OK.
struct PackDatePickerSheet: View {
    let initial: PackDay?
    let onPick: (PackDay) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        VStack(spacing: 8) {
            DatePicker("Bill date", selection: $date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(CashStyle.green)
            HStack(spacing: 18) {
                Spacer()
                Button("Cancel") { dismiss() }.font(.system(size: 15, weight: .medium)).foregroundStyle(CashStyle.green)
                Button("OK") {
                    onPick(PackDay(date: date))
                    dismiss()
                }
                .font(.system(size: 15, weight: .bold)).foregroundStyle(CashStyle.green)
            }
            .padding(.horizontal, 8)
        }
        .padding(16)
        .background(Color.white.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .onAppear { date = min(initial?.date ?? Date(), Date()) }
    }
}
