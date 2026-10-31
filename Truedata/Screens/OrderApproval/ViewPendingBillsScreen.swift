//
//  ViewPendingBillsScreen.swift
//  Truedata
//

import SwiftUI

// Android `PendingBillsScreen.kt` / `PendingBillsSheets.kt`, in the Utility (cash collection)
// style: a seller's bills by payment status, with search (order no, shop, sales person) and a
// filter sheet. The whole list is loaded, so both run on the phone; what is narrowed always shows.

/// Android `CcColors.InfoBg`; `BillTone` has the ink but not the background.
private let pendingInfoBg = Color(hex: "E0F2FE")

struct ViewPendingBillsScreen: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ViewPendingBillsViewModel
    @State private var showFilters = false
    @State private var details: PendingPaymentBill?
    @State private var orderTarget = ""
    @State private var showOrder = false
    @State private var loadedOnce = false
    private let onHome: (() -> Void)?

    /// `staffId` 0 loads as the logged-in user, like Android's "default". `onHome` defaults to a
    /// plain back for callers (Seller Profile) that sit outside Home's navigation path.
    init(sellerId: Int, staffId: Int, sellerName: String, onHome: (() -> Void)? = nil) {
        self.onHome = onHome
        _viewModel = StateObject(
            wrappedValue: ViewPendingBillsViewModel(sellerId: sellerId, staffId: staffId, sellerName: sellerName)
        )
    }

    var body: some View {
        CashPage(
            title: viewModel.title,
            onHome: { if let onHome { onHome() } else { dismiss() } },
            onRefresh: { viewModel.load() }
        ) {
            PendingBillsContent(
                viewModel: viewModel,
                onOpenFilters: { showFilters = true },
                onDetails: { details = $0 },
                onOpenOrder: openOrder
            )
        }
        // Loaded once, not on every appear, so coming back from an order keeps the list,
        // its filters and where it was scrolled.
        .onAppear {
            guard !loadedOnce else { return }
            loadedOnce = true
            viewModel.load()
        }
        .sheet(isPresented: $showFilters) {
            PendingBillsFilterSheet(
                bills: viewModel.bills,
                query: viewModel.query,
                labels: viewModel.labels,
                filter: viewModel.filter,
                onApply: { viewModel.setFilter($0) }
            )
        }
        .sheet(item: $details) { bill in
            PendingBillHistorySheet(bill: bill, labels: viewModel.labels) {
                details = nil
                // After the sheet has gone, or the push is swallowed by the dismissal.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { openOrder(bill.orderId) }
            }
        }
        .navigationDestination(isPresented: $showOrder) {
            OrderDetailScreen(orderId: orderTarget)
                .toolbar(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
        }
    }

    private func openOrder(_ orderId: String) {
        guard !orderId.isEmpty else { return }
        orderTarget = orderId
        showOrder = true
    }
}

// MARK: - Content

private struct PendingBillsContent: View {
    @ObservedObject var viewModel: ViewPendingBillsViewModel
    let onOpenFilters: () -> Void
    let onDetails: (PendingPaymentBill) -> Void
    let onOpenOrder: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isLoading {
                ProgressView().tint(CashStyle.green).controlSize(.large)
                    .frame(maxWidth: .infinity).padding(40)
            } else if let error = viewModel.errorMessage, viewModel.bills.isEmpty {
                BillErrorState(message: error) { viewModel.load() }
            } else if viewModel.bills.isEmpty {
                BillEmptyState(title: "No bills", message: "This seller has no bills to show.", icon: "doc.plaintext")
            } else {
                loaded
            }
        }
    }

    @ViewBuilder
    private var loaded: some View {
        PendingBillsDueHero(viewModel: viewModel)
        PendingBillsSearchRow(
            query: $viewModel.query,
            activeFilters: viewModel.filter.activeCount,
            onOpenFilters: onOpenFilters
        )
        if viewModel.isNarrowing { PendingBillsActiveFilters(viewModel: viewModel) }
        if !viewModel.isComplete { PendingBillsLoadProgress(viewModel: viewModel) }
        BillSegmented(
            options: PendingBillStatusKey.all.map { ($0, "\(pendingStatusLabel($0)) \(viewModel.count(in: $0))") },
            selection: Binding(get: { viewModel.tab }, set: { viewModel.setTab($0) })
        )
        PendingBillsList(viewModel: viewModel, onDetails: onDetails, onOpenOrder: onOpenOrder)
    }
}

private func pendingStatusLabel(_ key: String) -> String {
    switch key {
    case PendingBillStatusKey.pending: return "Pending"
    case PendingBillStatusKey.remaining: return "Remaining"
    case PendingBillStatusKey.complete: return "Complete"
    default: return key
    }
}

/// Android `statusPill`: Pending warn, Remaining info, Complete ok, anything else muted.
private struct PendingBillStatusPill: View {
    let key: String
    var body: some View {
        switch key.trimmingCharacters(in: .whitespaces) {
        case PendingBillStatusKey.pending: BillPill(text: "Pending", fg: BillTone.warn, bg: BillTone.warnBg)
        case PendingBillStatusKey.remaining: BillPill(text: "Remaining", fg: BillTone.info, bg: pendingInfoBg)
        case PendingBillStatusKey.complete: BillPill(text: "Complete", fg: BillTone.ok, bg: BillTone.okBg)
        default: BillPill(text: key, fg: BillTone.mutedFg, bg: BillTone.mutedBg)
        }
    }
}

// MARK: - Hero

/// Still to collect across the bills the search and filters keep (all tabs).
private struct PendingBillsDueHero: View {
    @ObservedObject var viewModel: ViewPendingBillsViewModel

    var body: some View {
        let open = viewModel.narrowed.filter { $0.statusKey != PendingBillStatusKey.complete }
        let narrowing = viewModel.isNarrowing
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text((narrowing ? "Due · filtered" : "Total due").uppercased())
                    .font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(.white.opacity(0.68))
                Spacer()
                if narrowing { BillPill(text: "Filtered", fg: BillTone.warn, bg: BillTone.warnBg) }
            }
            Text(billMoney(open.reduce(0) { $0 + $1.due }))
                .font(.system(size: 26, weight: .heavy)).foregroundStyle(.white)
            HStack(spacing: 8) {
                stat("Unpaid bills", "\(open.count)")
                stat("Billed", billMoney(open.reduce(0) { $0 + $1.total }))
                stat("Paid bills", "\(viewModel.count(in: PendingBillStatusKey.complete))")
            }
            .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(colors: BillTone.heroBrand, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [BillTone.glow.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 220)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.72))
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Search and filter chips

/// Search box and the filter button; the button fills and shows a count when filters apply.
private struct PendingBillsSearchRow: View {
    @Binding var query: String
    let activeFilters: Int
    let onOpenFilters: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            field
            filterButton
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(CashStyle.muted)
            TextField("Order no, shop or sales person", text: $query)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .lineLimit(1)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CashStyle.muted).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 14).padding(.trailing, 6)
        .frame(height: 54)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BillTone.fieldBorder, lineWidth: 1))
    }

    private var filterButton: some View {
        let on = activeFilters > 0
        return Button(action: onOpenFilters) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(on ? .white : CashStyle.green)
                .frame(width: 54, height: 54)
                .background(on ? CashStyle.green : .white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? CashStyle.green : BillTone.fieldBorder, lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    if on {
                        Text("\(activeFilters)")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 19, height: 19)
                            .background(BillTone.warn, in: Circle())
                            .offset(x: 5, y: -5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
    }
}

private let pendingChipDay: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = PendingBillsFilter.calendar
    formatter.timeZone = PendingBillsFilter.calendar.timeZone
    formatter.dateFormat = "d MMM"
    return formatter
}()

private func pendingNamesLabel(_ prefix: String, _ names: [String]) -> String {
    names.count == 1 ? "\(prefix): \(names[0])" : "\(prefix): \(names.count)"
}

private func pendingDueLabel(_ min: Double?, _ max: Double?) -> String {
    switch (min, max) {
    case let (min?, max?): return "Due \(billMoney(min))–\(billMoney(max))"
    case let (min?, nil): return "Due ≥ \(billMoney(min))"
    default: return "Due ≤ \(billMoney(max ?? 0))"
    }
}

/// One removable chip per filter in use, so nothing narrows the list unseen.
private struct PendingBillsActiveFilters: View {
    @ObservedObject var viewModel: ViewPendingBillsViewModel

    private struct Chip: Identifiable {
        let id: String
        let label: String
        let remove: () -> Void
    }

    private var chips: [Chip] {
        let f = viewModel.filter
        let labels = viewModel.labels
        let set = viewModel.setFilter
        var chips: [Chip] = []
        let query = viewModel.query.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            chips.append(Chip(id: "query", label: "\u{201C}\(query)\u{201D}") { viewModel.query = "" })
        }
        if f.from != nil || f.to != nil {
            var cleared = f; cleared.from = nil; cleared.to = nil
            chips.append(Chip(id: "date", label: dateLabel(f)) { set(cleared) })
        }
        if !f.salesPeople.isEmpty {
            var cleared = f; cleared.salesPeople = []
            chips.append(Chip(id: "sales", label: pendingNamesLabel("Sales", f.salesPeople.sorted())) { set(cleared) })
        }
        if !f.shops.isEmpty {
            var cleared = f; cleared.shops = []
            chips.append(Chip(id: "shop", label: pendingNamesLabel("Shop", f.shops.sorted())) { set(cleared) })
        }
        if !f.modes.isEmpty {
            var cleared = f; cleared.modes = []
            chips.append(Chip(id: "mode", label: pendingNamesLabel("Mode", f.modes.sorted().map(labels.mode))) { set(cleared) })
        }
        if !f.orderStatuses.isEmpty {
            var cleared = f; cleared.orderStatuses = []
            let names = f.orderStatuses.sorted().map(labels.orderStatus)
            chips.append(Chip(id: "order", label: pendingNamesLabel("Order", names)) { set(cleared) })
        }
        if f.minDue != nil || f.maxDue != nil {
            var cleared = f; cleared.minDue = nil; cleared.maxDue = nil
            chips.append(Chip(id: "due", label: pendingDueLabel(f.minDue, f.maxDue)) { set(cleared) })
        }
        return chips
    }

    private func dateLabel(_ f: PendingBillsFilter) -> String {
        switch (f.from, f.to) {
        case let (from?, to?) where from == to: return pendingChipDay.string(from: from)
        case let (from?, to?): return "\(pendingChipDay.string(from: from)) – \(pendingChipDay.string(from: to))"
        case let (from?, nil): return "From \(pendingChipDay.string(from: from))"
        case let (nil, to?): return "Until \(pendingChipDay.string(from: to))"
        default: return ""
        }
    }

    var body: some View {
        let chips = chips
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 16)).foregroundStyle(CashStyle.green)
                ForEach(chips) { chip in PendingRemovableChip(label: chip.label, onRemove: chip.remove) }
                if chips.count > 1 {
                    Button { viewModel.clearFilters() } label: {
                        Text("Clear all").font(.system(size: 12.5, weight: .bold)).foregroundStyle(BillTone.err)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct PendingRemovableChip: View {
    let label: String
    let onRemove: () -> Void
    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(CashStyle.deep).lineLimit(1)
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(CashStyle.green)
            }
            .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 6)
            .background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(CashStyle.green.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove \(label)")
    }
}

// MARK: - Load progress

/// While later pages arrive: how far along, so a short list isn't read as the whole story.
private struct PendingBillsLoadProgress: View {
    @ObservedObject var viewModel: ViewPendingBillsViewModel

    var body: some View {
        let failed = viewModel.restError != nil
        VStack(alignment: .leading, spacing: 6) {
            if failed {
                HStack {
                    Text("Loaded \(viewModel.bills.count) of \(viewModel.serverTotal) bills. The rest didn't load.")
                        .font(.system(size: 12.5)).foregroundStyle(BillTone.err)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Retry") { viewModel.retryRest() }
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(BillTone.err)
                }
            } else {
                Text("Loading all bills… \(viewModel.bills.count) of \(viewModel.serverTotal). Search covers what has loaded.")
                    .font(.system(size: 12.5)).foregroundStyle(BillTone.info)
                BillClearedBar(cleared: viewModel.bills.count, total: viewModel.serverTotal, track: .white, fill: BillTone.info)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(failed ? BillTone.errBg : pendingInfoBg, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - List

private struct PendingBillsList: View {
    @ObservedObject var viewModel: ViewPendingBillsViewModel
    let onDetails: (PendingPaymentBill) -> Void
    let onOpenOrder: (String) -> Void

    var body: some View {
        let shown = viewModel.shown
        if shown.isEmpty {
            emptyTab
        } else {
            summary(shown)
            // Lazy: a seller can run to hundreds of bills once every page is in.
            LazyVStack(spacing: 10) {
                ForEach(shown) { bill in
                    PendingBillCard(
                        bill: bill,
                        labels: viewModel.labels,
                        showShop: viewModel.singleSeller == nil,
                        onDetails: { onDetails(bill) },
                        onOpenOrder: { onOpenOrder(bill.orderId) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var emptyTab: some View {
        if viewModel.isNarrowing {
            VStack(spacing: 0) {
                BillEmptyState(
                    title: "No bills match",
                    message: "Nothing in this tab matches your search and filters.",
                    icon: "text.magnifyingglass"
                )
                Button { viewModel.clearFilters() } label: {
                    Text("Clear search and filters").font(.system(size: 14, weight: .bold)).foregroundStyle(CashStyle.green)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        } else {
            BillEmptyState(title: "Nothing here", message: "No bill has this status.", icon: "doc.plaintext")
        }
    }

    private func summary(_ shown: [PendingPaymentBill]) -> some View {
        let due = shown.reduce(0) { $0 + $1.due }
        return HStack {
            Text(billCount(shown.count)).font(.system(size: 12)).foregroundStyle(CashStyle.muted)
            Spacer()
            if due > 0 {
                Text("Due \(billMoney(due))").font(.system(size: 12, weight: .bold)).foregroundStyle(BillTone.warn)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct PendingBillCard: View {
    let bill: PendingPaymentBill
    let labels: PendingBillLabels
    let showShop: Bool
    let onDetails: () -> Void
    let onOpenOrder: () -> Void

    /// "{staff} · Order: {status} · {mode}"; the mode only once something was collected.
    private var metaLine: String {
        var parts: [String] = []
        let staff = bill.staffName.trimmingCharacters(in: .whitespaces)
        if !staff.isEmpty { parts.append(staff) }
        parts.append("Order: \(labels.orderStatus(bill.orderStatus))")
        if bill.modeKey != pendingBillNoMode { parts.append(labels.mode(bill.modeKey)) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(bill.displayOrderId).font(.system(size: 14, weight: .heavy)).foregroundStyle(CashStyle.ink)
                Text(bill.orderDate).font(.system(size: 11.5)).foregroundStyle(CashStyle.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PendingBillStatusPill(key: bill.paymentStatus)
            }
            if showShop && !bill.sellerName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(bill.sellerName).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(CashStyle.ink).lineLimit(1)
            }
            Text(metaLine).font(.system(size: 12.5)).foregroundStyle(CashStyle.muted).lineLimit(1)
            amountRow
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(perform: onDetails)
    }

    private var amountRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            if bill.due > 0 {
                Text("Due ").font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                Text(billMoney(bill.due)).font(.system(size: 15, weight: .heavy)).foregroundStyle(BillTone.warn)
                Text("  of \(billMoney(bill.total))").font(.system(size: 12)).foregroundStyle(CashStyle.muted)
            } else {
                Text(billMoney(bill.total)).font(.system(size: 15, weight: .heavy)).foregroundStyle(BillTone.ok)
            }
            Spacer(minLength: 8)
            if !bill.orderId.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: onOpenOrder) {
                    Text("View order").font(.system(size: 12.5, weight: .bold)).foregroundStyle(CashStyle.green)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Bill history sheet

/// A bill's figures and every payment made against it.
private struct PendingBillHistorySheet: View {
    let bill: PendingPaymentBill
    let labels: PendingBillLabels
    let onOpenOrder: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header
                figures
                Text("Payments").font(.system(size: 14, weight: .bold)).foregroundStyle(CashStyle.ink)
                if bill.history.isEmpty {
                    Text("No payment recorded against this bill yet.").font(.system(size: 13)).foregroundStyle(CashStyle.muted)
                } else {
                    ForEach(Array(bill.history.enumerated()), id: \.offset) { _, entry in
                        PendingBillPaymentRow(entry: entry, labels: labels)
                    }
                }
                if !bill.orderId.trimmingCharacters(in: .whitespaces).isEmpty {
                    BillPrimaryButton(title: "View order", icon: "arrow.up.right.square", action: onOpenOrder)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 16)
        }
        .background(Color.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.displayOrderId).font(.system(size: 18, weight: .heavy)).foregroundStyle(CashStyle.ink)
                Text(bill.orderDate).font(.system(size: 12.5)).foregroundStyle(CashStyle.muted)
            }
            Spacer()
            PendingBillStatusPill(key: bill.paymentStatus)
        }
    }

    private var figures: some View {
        VStack(spacing: 6) {
            line("Bill amount", billMoney(bill.total))
            line("Due", billMoney(bill.due), bill.due > 0 ? BillTone.warn : BillTone.ok)
            line("Paid", billMoney(max(bill.total - bill.due, 0)))
            Divider().overlay(CashStyle.border)
            line("Shop", dash(bill.sellerName))
            line("Sales person", dash(bill.staffName))
            line("Order status", labels.orderStatus(bill.orderStatus))
            line("Payment mode", labels.mode(bill.modeKey))
            if !bill.transactionNo.trimmingCharacters(in: .whitespaces).isEmpty {
                line("Transaction", bill.transactionNo)
            }
        }
        .padding(12)
        .background(BillTone.track, in: RoundedRectangle(cornerRadius: 12))
    }

    private func dash(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces).isEmpty ? "—" : s }

    private func line(_ label: String, _ value: String, _ color: Color = CashStyle.ink) -> some View {
        HStack {
            Text(label).font(.system(size: 12.5)).foregroundStyle(CashStyle.muted)
            Spacer(minLength: 12)
            Text(value).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(color).multilineTextAlignment(.trailing)
        }
    }
}

private struct PendingBillPaymentRow: View {
    let entry: PendingPaymentBillHistory
    let labels: PendingBillLabels

    private var title: String {
        var parts: [String] = []
        if !entry.date.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(entry.date) }
        if let mode = entry.paymentMode, !mode.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(labels.mode(mode)) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(CashStyle.ink)
                if !entry.staff.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("By \(entry.staff)").font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                }
            }
            Spacer()
            Text(billMoney(entry.payValue)).font(.system(size: 14, weight: .heavy)).foregroundStyle(BillTone.ok)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.border, lineWidth: 1))
    }
}

// MARK: - Filter sheet

/// Every filter the bills can be narrowed by. Changes stay in the sheet until applied; the button
/// says how many bills they leave, so an empty result is seen before it is chosen.
private struct PendingBillsFilterSheet: View {
    let bills: [PendingPaymentBill]
    let query: String
    let labels: PendingBillLabels
    let onApply: (PendingBillsFilter) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: PendingBillsFilter
    @State private var minText: String
    @State private var maxText: String
    @State private var showRange = false

    init(bills: [PendingPaymentBill], query: String, labels: PendingBillLabels,
         filter: PendingBillsFilter, onApply: @escaping (PendingBillsFilter) -> Void) {
        self.bills = bills
        self.query = query
        self.labels = labels
        self.onApply = onApply
        _draft = State(initialValue: filter)
        _minText = State(initialValue: filter.minDue.map(pendingPlain) ?? "")
        _maxText = State(initialValue: filter.maxDue.map(pendingPlain) ?? "")
    }

    private var withDue: PendingBillsFilter {
        var f = draft
        f.minDue = Double(minText)
        f.maxDue = Double(maxText)
        return f
    }

    var body: some View {
        let applied = withDue
        let count = bills.narrow(query, applied).count
        VStack(spacing: 12) {
            header(applied)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PendingDateSection(draft: $draft, onCustom: { showRange = true })
                    choiceSections
                    PendingDueSection(minText: $minText, maxText: $maxText)
                    PendingFilterSection(title: "Sort by", icon: "arrow.up.arrow.down") {
                        FlowLayout(spacing: 6) {
                            ForEach(PendingBillSort.allCases, id: \.self) { sort in
                                PendingToggleChip(label: sort.label, on: draft.sort == sort) { draft.sort = sort }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            BillPrimaryButton(
                title: count == 0 ? "No bills match" : "Show \(billCount(count))",
                icon: "line.3.horizontal.decrease.circle"
            ) {
                onApply(applied)
                dismiss()
            }
        }
        .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 16)
        .background(Color.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showRange) {
            PendingRangePicker(from: draft.from, to: draft.to) { from, to in
                draft.from = from
                draft.to = to
            }
        }
    }

    private func header(_ applied: PendingBillsFilter) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Filter bills").font(.system(size: 18, weight: .heavy)).foregroundStyle(CashStyle.ink)
                Text(applied.isActive
                     ? "\(applied.activeCount) filter\(applied.activeCount == 1 ? "" : "s") on"
                     : "Showing every bill")
                    .font(.system(size: 12.5)).foregroundStyle(CashStyle.muted)
            }
            Spacer()
            if applied.isActive || draft.sort != .newest {
                Button("Reset") {
                    draft = PendingBillsFilter()
                    minText = ""
                    maxText = ""
                }
                .font(.system(size: 14, weight: .bold)).foregroundStyle(CashStyle.green)
            }
        }
    }

    /// Each list filter only when the bills hold at least two values for it; one value can't narrow.
    @ViewBuilder
    private var choiceSections: some View {
        let people = bills.choices { $0.staffName }
        if people.count > 1 {
            PendingFilterSection(title: "Sales person", icon: "person.fill") {
                PendingMultiChips(options: people, selected: $draft.salesPeople)
            }
        }
        let shops = bills.choices { $0.sellerName }
        if shops.count > 1 {
            PendingFilterSection(title: "Shop", icon: "storefront.fill") {
                PendingMultiChips(options: shops, selected: $draft.shops)
            }
        }
        let modes = Array(Set(bills.map(\.modeKey))).sorted()
        if modes.count > 1 {
            PendingFilterSection(title: "Payment mode", icon: "banknote.fill") {
                PendingMultiChips(options: modes, selected: $draft.modes, label: labels.mode)
            }
        }
        let statuses = bills.choices { $0.orderStatus }
        if statuses.count > 1 {
            PendingFilterSection(title: "Order status", icon: "shippingbox.fill") {
                PendingMultiChips(options: statuses, selected: $draft.orderStatuses, label: labels.orderStatus)
            }
        }
    }
}

/// "1500" rather than "1500.0" when a whole amount goes back into its field.
private func pendingPlain(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int64(value)) : String(value)
}

private let pendingRangeDay: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = PendingBillsFilter.calendar
    formatter.timeZone = PendingBillsFilter.calendar.timeZone
    formatter.dateFormat = "d MMM yyyy"
    return formatter
}()

private struct PendingDateSection: View {
    @Binding var draft: PendingBillsFilter
    let onCustom: () -> Void

    var body: some View {
        let presets = PendingBillsFilter.datePresets()
        let preset = presets.first { $0.from == draft.from && $0.to == draft.to }
        let custom = preset == nil && draft.from != nil
        PendingFilterSection(title: "Order date", icon: "calendar") {
            FlowLayout(spacing: 6) {
                PendingToggleChip(label: "Any date", on: draft.from == nil && draft.to == nil) {
                    draft.from = nil
                    draft.to = nil
                }
                ForEach(presets, id: \.label) { p in
                    PendingToggleChip(label: p.label, on: preset?.label == p.label) {
                        draft.from = p.from
                        draft.to = p.to
                    }
                }
                PendingToggleChip(label: custom ? customLabel : "Custom…", on: custom, action: onCustom)
            }
        }
    }

    private var customLabel: String {
        guard let from = draft.from else { return "Custom…" }
        return "\(pendingRangeDay.string(from: from)) – \(pendingRangeDay.string(from: draft.to ?? from))"
    }
}

private struct PendingDueSection: View {
    @Binding var minText: String
    @Binding var maxText: String

    var body: some View {
        PendingFilterSection(title: "Amount due", icon: "indianrupeesign") {
            HStack(spacing: 8) {
                field("Min ₹", $minText)
                field("Max ₹", $maxText)
            }
        }
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11.5, weight: .bold)).foregroundStyle(CashStyle.muted)
            TextField(label, text: Binding(
                get: { text.wrappedValue },
                // Android keeps digits and the point, up to 10 characters.
                set: { text.wrappedValue = String($0.filter { $0.isNumber || $0 == "." }.prefix(10)) }
            ))
            .keyboardType(.decimalPad)
            .font(.system(size: 15))
            .padding(.horizontal, 12).frame(height: 48)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BillTone.fieldBorder, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PendingFilterSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                BillIconDisc(icon: icon, color: CashStyle.green, size: 24)
                Text(title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(CashStyle.ink)
            }
            content()
        }
    }
}

/// "All" plus one chip per value; picking "All" clears the set.
private struct PendingMultiChips: View {
    let options: [String]
    @Binding var selected: Set<String>
    var label: (String) -> String = { $0 }

    var body: some View {
        FlowLayout(spacing: 6) {
            PendingToggleChip(label: "All", on: selected.isEmpty) { selected = [] }
            ForEach(options, id: \.self) { option in
                let on = selected.contains(option)
                PendingToggleChip(label: label(option), on: on) {
                    if on { selected.remove(option) } else { selected.insert(option) }
                }
            }
        }
    }
}

/// Android `ToggleChip`: outlined until picked, then brand-tinted with a tick.
private struct PendingToggleChip: View {
    let label: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if on { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(CashStyle.green) }
                Text(label).font(.system(size: 12.5, weight: on ? .bold : .medium))
                    .foregroundStyle(on ? CashStyle.deep : CashStyle.ink)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(on ? CashStyle.pale : .white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(on ? CashStyle.green : BillTone.fieldBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Android `RangePickerDialog`: a from–to pair, nothing after today; a reversed pair is swapped.
private struct PendingRangePicker: View {
    let onPick: (Date, Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var from: Date
    @State private var to: Date

    init(from: Date?, to: Date?, onPick: @escaping (Date, Date) -> Void) {
        let today = PendingBillsFilter.startOfDay(Date())
        let weekAgo = PendingBillsFilter.calendar.date(byAdding: .day, value: -6, to: today) ?? today
        self.onPick = onPick
        _from = State(initialValue: from ?? weekAgo)
        _to = State(initialValue: to ?? today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Order date").font(.system(size: 18, weight: .heavy)).foregroundStyle(CashStyle.ink)
            DatePicker("From", selection: $from, in: ...Date(), displayedComponents: .date)
            DatePicker("To", selection: $to, in: ...Date(), displayedComponents: .date)
            Spacer(minLength: 0)
            BillPrimaryButton(title: "Apply", icon: "checkmark") {
                let a = PendingBillsFilter.startOfDay(from)
                let b = PendingBillsFilter.startOfDay(to)
                onPick(min(a, b), max(a, b))
                dismiss()
            }
        }
        .font(.system(size: 15))
        .tint(CashStyle.green)
        .padding(16)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack {
        ViewPendingBillsScreen(sellerId: 1, staffId: 0, sellerName: "Test Shop")
    }
}
