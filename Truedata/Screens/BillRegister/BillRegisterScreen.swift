import SwiftUI

struct BillRegisterScreen: View {
    var onHome: () -> Void
    @StateObject private var model = BillRegisterViewModel()
    @State private var creating = false
    @State private var choosingEmployee = false
    @State private var choosingBeats = false
    var body: some View {
        CashPage(title: model.access.canManage ? "Bill Register" : "My Bill Register", onHome: onHome, onRefresh: { Task { await model.reload() } }) {
            // Android: the switch and the beat / employee filters come first, since they narrow both views.
            BillSegmented(options: [(BillListView.registers, "Register wise"), (BillListView.beats, "Beat wise")], selection: $model.view)
            BillPickerField(label: "Beats", value: model.beatFilterLabel ?? "All beats", icon: "map.fill",
                            placeholder: model.beatFilter.isEmpty) {
                choosingBeats = true
                Task { await model.loadBeats() }
            }
            if !model.beatFilter.isEmpty {
                Button("Show all beats") { model.beatFilter = [:] }
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(CashStyle.green)
            }
            employeeFilter
            if model.view == .beats {
                beatWiseContent
            } else {
                registerWiseContent
            }
        }
        // Android's Scaffold snackbar: done-messages float just above the action tray.
        .billSnackbar(message: $model.message)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.access.canManage {
                BillBottomBar {
                    BillPrimaryButton(title: "New Bill Register", icon: "plus.circle.fill") { creating = true }
                }
            }
        }
        .tint(AppTheme.cerulean)
        // Status and order ID only narrow the register list; beats and employee narrow both.
        .task(id: "\(model.view)-\(model.status)-\(model.assignedTo)-\(model.orderID)-\(model.beatFilter.keys.sorted())") {
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            if model.view == .beats { await model.loadBeatWise(keep: false) } else { await model.load() }
        }
        .onChange(of: model.orderID) { _, value in
            if let year = BillOrderSession.year(in: value) { model.orderSessionYear = year }
        }
        .task { await model.loadOptions() }
        // Android pushes create as its own screen with the app bar, so it is a full-screen page
        // here too rather than a card-style sheet.
        .fullScreenCover(isPresented: $creating, onDismiss: { Task { await model.reload() } }) {
            NavigationStack { BillRegisterCreateScreen(onHome: { creating = false; onHome() }) }
        }
        .sheet(isPresented: $choosingEmployee) {
            BillRegisterPersonPicker(
                people: model.staff,
                isLoading: model.staff.isEmpty && model.optionsError == nil,
                error: model.optionsError,
                selectedID: model.assignedTo == 0 ? nil : model.assignedTo,
                onRetry: { Task { await model.loadOptions() } },
                onPick: { picked in choosingEmployee = false; model.assignedTo = picked.id }
            )
        }
        .sheet(isPresented: $choosingBeats) {
            BillBeatPickerSheet(
                beats: model.beats,
                selected: Set(model.beatFilter.keys),
                isLoading: model.beats.isEmpty && model.optionsError == nil,
                onRetry: { Task { await model.loadBeats(force: true) } },
                onApply: model.setBeats,
                applyLabel: { $0 == 1 ? "Show 1 beat" : "Show \($0) beats" }
            )
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder private var employeeFilter: some View {
        if model.access.canManage {
            let employee = model.staff.first { $0.id == model.assignedTo }
            BillPickerField(label: "Employee", value: employee?.name ?? "All employees", icon: "person.fill",
                            placeholder: employee == nil) { choosingEmployee = true }
            if let error = model.optionsError {
                Text(error).font(.system(size: 12)).foregroundStyle(BillTone.err)
                Button("Retry staff") { Task { await model.loadOptions() } }.foregroundStyle(CashStyle.green)
            }
            if model.assignedTo != 0 {
                Button("Show all employees") { model.assignedTo = 0 }
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(CashStyle.green)
            }
        }
    }

    /// Android `beatWiseItems`: what is still to collect in each beat, a tap away from its registers.
    @ViewBuilder private var beatWiseContent: some View {
        if let data = model.beatWise {
            if data.beats.isEmpty {
                BillEmptyState(title: "Nothing pending", message: {
                    if let label = model.beatFilterLabel { return "No pending register has bills in \(label)." }
                    if !model.access.canManage { return "None of your pending registers has a bill left to collect." }
                    return "No pending register has a bill left to collect."
                }(), icon: "map")
            } else {
                BillBeatWiseHero(data: data)
                ForEach(data.beats) { beat in
                    Button { withAnimation { model.openBeat(beat) } } label: { BillBeatPendingCard(beat: beat) }
                        .buttonStyle(.plain)
                }
            }
        } else if let error = model.beatWiseError {
            BillErrorState(message: error) { Task { await model.loadBeatWise() } }
        } else {
            ProgressView().tint(CashStyle.green).controlSize(.large).frame(maxWidth: .infinity).padding(40)
        }
    }

    @ViewBuilder private var registerWiseContent: some View {
            // Android shows the six sessions as a wrapping chip row, not a dropdown, so the one
            // in use is visible without opening anything.
            VStack(alignment: .leading, spacing: 4) {
                Text("Session").font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                FlowLayout(spacing: 6) {
                    ForEach((0...5).map { BillOrderSession.startYear() - $0 }, id: \.self) { year in
                        BillFilterChip(title: BillOrderSession.label(year), selected: model.orderSessionYear == year) {
                            model.orderSessionYear = year
                            model.orderID = BillOrderSession.replacingSession(in: model.orderID, with: year)
                        }
                    }
                }
            }
            BillOrderIDField(
                text: $model.orderID,
                placeholder: "e.g. \(BillOrderSession.prefix(model.orderSessionYear))1780",
                supporting: BillOrderSession.filter(model.orderID).map { "Showing registers for order \($0)" }
                    ?? "Enter the order number after the session. You can edit or clear the full ID.",
                onSearch: { Task { await model.load() } },
                onClear: { model.orderID = ""; Task { await model.load() } }
            )
            BillSegmented(options: [("pending", "Pending"), ("cleared", "Cleared"), ("cancelled", "Cancelled"), ("", "All")],
                          selection: $model.status)
            BillRegisterFeedback(model: model)
            let shownEntries = model.entries
            Text("\(shownEntries.count) registers").font(.system(size: 12)).foregroundStyle(CashStyle.muted).padding(.horizontal, 4)
            if shownEntries.isEmpty && !model.loading && model.error == nil {
                // Android distinguishes "your order id matched nothing" from "you have none
                // yet"; one generic line made a failed order lookup look like an empty account.
                let emptyMessage: String = {
                    if let order = BillOrderSession.filter(model.orderID) {
                        return "No register found for order \(order) with the selected filters."
                    }
                    if !model.access.canManage {
                        return model.status.isEmpty
                            ? "No bills are assigned to you."
                            : "No bills are assigned to you with this status."
                    }
                    if let label = model.beatFilterLabel { return "No register in \(label) with these filters." }
                    if let name = model.staff.first(where: { $0.id == model.assignedTo })?.name {
                        return "\(name) has no registers with this status."
                    }
                    if model.status == BillRegisterStatus.cancelled.rawValue {
                        return "Registers you cancel, or whose bills are all removed, show up here."
                    }
                    return "Tap New Bill Register to pick beats and assign their pending bills."
                }()
                let cancelledFilter = model.status == BillRegisterStatus.cancelled.rawValue
                BillEmptyState(title: cancelledFilter ? "No cancelled registers" : "No registers",
                               message: emptyMessage, icon: cancelledFilter ? "nosign" : "tray")
            }
            ForEach(shownEntries) { entry in
                NavigationLink { BillRegisterDetailScreen(id: entry.id, onHome: onHome) } label: {
                    BillRegisterCard(entry: entry, showAssignee: model.access.canManage)
                }.buttonStyle(.plain)
            }
            if model.hasMore && !model.loading {
                Button("Load more") { Task { await model.load(more: true) } }
                    .tint(AppTheme.cerulean)
            }
    }
}

/// Material 3 `OutlinedTextField` as Android draws the order ID search: a 4pt-cornered outline with
/// its "Order ID" label sitting in the border, and the hint underneath.
private struct BillOrderIDField: View {
    @Binding var text: String
    let placeholder: String
    let supporting: String
    let onSearch: () -> Void
    let onClear: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Button(action: onSearch) { Image(systemName: "magnifyingglass").font(.system(size: 18)).frame(width: 40, height: 40) }
                    .buttonStyle(.plain).foregroundStyle(Color(hex: "49454F")).accessibilityLabel("Search order ID")
                TextField(placeholder, text: $text)
                    .font(.system(size: 16)).foregroundStyle(CashStyle.ink)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.search).focused($focused)
                    .onSubmit(onSearch)
                if !text.isEmpty {
                    Button(action: onClear) { Image(systemName: "xmark").font(.system(size: 16)).frame(width: 40, height: 40) }
                        .buttonStyle(.plain).foregroundStyle(Color(hex: "49454F")).accessibilityLabel("Clear order ID")
                }
            }
            .padding(.horizontal, 4).frame(height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(focused ? CashStyle.green : Color(hex: "79747E"), lineWidth: focused ? 2 : 1)
            )
            .overlay(alignment: .topLeading) {
                Text("Order ID").font(.system(size: 12))
                    .foregroundStyle(focused ? CashStyle.green : Color(hex: "49454F"))
                    .padding(.horizontal, 4).background(BillTone.page)
                    .offset(x: 12, y: -8)
            }
            Text(supporting).font(.system(size: 12)).foregroundStyle(Color(hex: "49454F")).padding(.horizontal, 16)
        }
        .padding(.top, 6)
    }
}

private struct BillRegisterCreateScreen: View {
    var onHome: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = BillRegisterViewModel()
    @State private var beats: Set<Int> = []
    @State private var orders: Set<Int> = []
    @State private var person = 0
    @State private var search = ""
    @State private var showBeats = false
    @State private var showEmployee = false
    /// The create summary is up; it stays up while saving, so a failure can be read and retried.
    @State private var confirming = false
    @State private var confirmError: String?
    /// Beats waiting on a yes, because switching to them would untick bills already picked.
    @State private var pendingBeats: Set<Int>?
    /// Where back or home was headed when picks would be lost; asked about before going.
    @State private var leaving: (() -> Void)?

    private var picked: [BillRegisterOrder] { model.orders.filter { orders.contains($0.id) } }
    private var selectedAmount: Double { picked.reduce(0) { $0 + $1.pendingAmount } }
    private var hasPicks: Bool { !orders.isEmpty }
    private var employee: OrderInsightsStaffMember? { model.staff.first { $0.id == person } }
    private var open: [BillRegisterOrder] { model.orders.filter { !$0.isAssigned } }
    private var shown: [BillRegisterOrder] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return model.orders }
        return model.orders.filter {
            [$0.orderNo, $0.sellerShopName, $0.sellerName, $0.beatName].contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    /// Picked bills that switching to beats [ids] would untick.
    private func dropped(by ids: Set<Int>) -> [BillRegisterOrder] { picked.filter { !ids.contains($0.beatId) } }

    var body: some View {
        CashPage(title: "New Bill Register", onHome: { leave(onHome) }, onBack: { leave { dismiss() } }) {
            BillSection(title: "Beats and collector", icon: "map.fill") {
                BillPickerField(label: "Beats *", value: beatsValue, icon: "map.fill", placeholder: beats.isEmpty) { showBeats = true }
                if let error = model.optionsError {
                    Text(error).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(BillTone.err)
                    Button("Retry") { Task { await model.loadOptions(includeBeats: true) } }.foregroundStyle(CashStyle.green)
                }
                BillPickerField(label: "Assign to *",
                                value: employee.map { $0.name + ($0.role.isEmpty ? "" : " (\($0.role))") } ?? "Choose an employee",
                                icon: "person.fill", placeholder: employee == nil) { showEmployee = true }
            }
            ordersContent
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BillBottomBar {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(orders.count) order\(orders.count == 1 ? "" : "s") selected" + (employee.map { " · for \($0.name)" } ?? ""))
                            .font(.system(size: 11.5)).foregroundStyle(CashStyle.muted)
                        Text(billMoney(selectedAmount)).font(.system(size: 18, weight: .heavy)).foregroundStyle(CashStyle.ink)
                    }
                    Spacer()
                }
                BillPrimaryButton(title: "Create & Assign", icon: "checkmark", enabled: !orders.isEmpty, loading: model.saving) { askCreate() }
            }
        }
        .task { await model.loadOptions(includeBeats: true) }
        .task(id: beats) { await model.loadOrders(beats) }
        .sheet(isPresented: $showBeats) {
            BillBeatPickerSheet(
                beats: model.beats,
                selected: beats,
                isLoading: model.beats.isEmpty && model.optionsError == nil,
                onRetry: { Task { await model.loadOptions(includeBeats: true) } },
                onApply: setBeats
            )
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEmployee) {
            BillRegisterPersonPicker(
                people: model.staff,
                isLoading: model.staff.isEmpty && model.optionsError == nil,
                error: model.optionsError,
                selectedID: person == 0 ? nil : person,
                onRetry: { Task { await model.loadOptions(includeBeats: true) } },
                onPick: { picked in person = picked.id; showEmployee = false }
            )
        }
        .overlay { dialogs.animation(.easeOut(duration: 0.18), value: dialogKey) }
    }

    /// Which dialog is up, so its coming and going fades instead of popping.
    private var dialogKey: String {
        confirming ? "confirm" : pendingBeats != nil ? "beats" : leaving != nil ? "leave" : ""
    }

    private var beatsValue: String {
        let names = model.beats.filter { beats.contains($0.id) }.map(\.name)
        switch names.count {
        case 0: return "Choose beats"
        case 1: return names[0]
        default: return "\(names.count) beats · " + names.joined(separator: ", ")
        }
    }

    @ViewBuilder private var ordersContent: some View {
        if beats.isEmpty {
            BillEmptyState(title: "Pick beats first",
                           message: "Delivered orders with payment still pending in those beats will show here.", icon: "map")
        } else if model.loading && model.orders.isEmpty {
            ProgressView().tint(CashStyle.green).controlSize(.large).frame(maxWidth: .infinity).padding(40)
        } else if let error = model.error, model.orders.isEmpty {
            BillErrorState(message: error) { Task { await model.loadOrders(beats) } }
        } else if model.orders.isEmpty {
            BillEmptyState(title: "No pending bills", message: "Every delivered order in these beats is paid.", icon: "doc.text")
        } else {
            ordersHeader
            ForEach(shown) { order in
                BillBeatOrderRow(order: order, selected: orders.contains(order.id), showBeat: beats.count > 1) {
                    if orders.contains(order.id) { orders.remove(order.id) } else { orders.insert(order.id) }
                }
            }
            if shown.isEmpty {
                Text("No order matches \u{201C}\(search)\u{201D}.").font(.system(size: 14)).foregroundStyle(CashStyle.muted).padding(8)
            }
        }
    }

    private var ordersHeader: some View {
        let assigned = model.orders.count - open.count
        let openShown = shown.filter { !$0.isAssigned }
        let all = !openShown.isEmpty && orders.isSuperset(of: openShown.map(\.id))
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(open.count) pending bill\(open.count == 1 ? "" : "s") · \(billMoney(open.reduce(0) { $0 + $1.pendingAmount }))"
                 + (assigned > 0 ? " · \(assigned) already in a register" : ""))
                .font(.system(size: 12.5)).foregroundStyle(CashStyle.muted).padding(.horizontal, 4)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(CashStyle.muted)
                TextField("Search shop, seller or order no.", text: $search).textInputAutocapitalization(.never)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark").foregroundStyle(CashStyle.muted) }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12).frame(height: 52)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BillTone.fieldBorder, lineWidth: 1))
            if !openShown.isEmpty {
                Button {
                    let ids = openShown.map(\.id)
                    if all { orders.subtract(ids) } else { orders.formUnion(ids) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: all ? "checkmark.square.fill" : "square").font(.system(size: 20))
                            .foregroundStyle(all ? CashStyle.green : CashStyle.muted)
                        Text(all ? "Unselect all" : "Select all \(openShown.count)" + (search.isEmpty ? "" : " shown"))
                            .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(CashStyle.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func leave(_ go: @escaping () -> Void) {
        if hasPicks && !model.saving { leaving = go } else { go() }
    }

    /// Checks the form, then shows what is about to be created; nothing is sent until that's confirmed.
    private func askCreate() {
        guard !model.saving, !beats.isEmpty, !orders.isEmpty else { return }
        // No collector yet: open the picker rather than an error, since that is the next step.
        if person == 0 { showEmployee = true; return }
        confirmError = nil
        confirming = true
    }

    @ViewBuilder private var dialogs: some View {
        if confirming {
            createConfirm
        } else if let ids = pendingBeats {
            let lost = dropped(by: ids)
            let gone = model.beats.filter { beats.contains($0.id) && !ids.contains($0.id) }.map(\.name)
            BillConfirmDialog(
                icon: "map",
                title: "Change beats?",
                message: "\(billCount(lost.count)) you picked (\(billMoney(lost.reduce(0) { $0 + $1.pendingAmount }))) "
                    + (gone.isEmpty ? "" : "from \(gone.joined(separator: ", ")) ") + "will be unticked.",
                confirmTitle: "Change beats",
                dismissTitle: "Keep beats",
                onConfirm: { pendingBeats = nil; applyBeats(ids) },
                onDismiss: { pendingBeats = nil }
            )
        } else if let go = leaving {
            BillConfirmDialog(
                icon: "trash",
                title: "Discard this register?",
                message: "You've picked \(billCount(orders.count)) (\(billMoney(selectedAmount)))"
                    + (employee.map { " for \($0.name)" } ?? "") + ". Leaving now throws the picks away.",
                confirmTitle: "Discard",
                confirmColor: BillTone.err,
                dismissTitle: "Keep editing",
                onConfirm: { leaving = nil; go() },
                onDismiss: { leaving = nil }
            )
        }
    }

    /// The last look before a register is made: who collects, from which beats, how many bills and
    /// how much. It stays up while saving, and a server refusal shows here with the picks intact.
    private var createConfirm: some View {
        let beatNames: [String] = {
            let pickedBeats = Set(picked.map(\.beatId))
            let names = model.beats.filter { pickedBeats.contains($0.id) }.map(\.name)
            if !names.isEmpty { return names }
            var seen = Set<String>()
            return picked.map(\.beatName).filter { !$0.isEmpty && seen.insert($0).inserted }
        }()
        return BillDialog(busy: model.saving, error: confirmError, onDismiss: { if !model.saving { confirming = false; confirmError = nil } }) {
            HStack(spacing: 12) {
                BillIconDisc(icon: "person.text.rectangle", color: CashStyle.green, size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Create this register?").font(.system(size: 17, weight: .heavy)).foregroundStyle(CashStyle.ink)
                    Text("Check it before it's assigned").font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                summaryLine("person.fill", "Assign to", employee.map { $0.name + ($0.role.isEmpty ? "" : " (\($0.role))") } ?? "—")
                summaryLine("map.fill", beatNames.count == 1 ? "Beat" : "Beats", beatNames.isEmpty ? "—" : beatNames.joined(separator: ", "))
                summaryLine("doc.text.fill", "Bills", billCount(picked.count))
                HStack {
                    Text("To collect").font(.system(size: 13)).foregroundStyle(CashStyle.muted)
                    Spacer()
                    Text(billMoney(selectedAmount)).font(.system(size: 19, weight: .heavy)).foregroundStyle(CashStyle.green)
                        .contentTransition(.numericText(value: selectedAmount))
                        .animation(.easeOut, value: selectedAmount)
                }.padding(.top, 2)
            }
            .padding(12)
            .background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 14))
            BillLinesPreview(lines: picked.map { ($0.sellerShopName.isEmpty ? ($0.sellerName.isEmpty ? $0.orderNo : $0.sellerName) : $0.sellerShopName, $0.pendingAmount) })
            Text("\(employee?.name ?? "They") will find it in their Bill Register and collect these bills. You can still reassign it, remove bills or cancel it later.")
                .font(.system(size: 12.5)).foregroundStyle(CashStyle.muted).fixedSize(horizontal: false, vertical: true)
        } buttons: {
            BillWeightedRow {
                BillSecondaryButton(title: "Back", color: CashStyle.muted, enabled: !model.saving) { confirming = false; confirmError = nil }
                BillPrimaryButton(title: "Create & assign", icon: "checkmark", enabled: !picked.isEmpty && employee != nil, loading: model.saving) {
                    Task { await create() }
                }
                .billWeight(1.4)
            }
        }
    }

    private func summaryLine(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(CashStyle.green).frame(width: 16).padding(.top, 1)
            Text(label).font(.system(size: 12.5)).foregroundStyle(CashStyle.muted).frame(width: 78, alignment: .leading)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(CashStyle.ink).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Switching beats unticks the picks from beats left out, so that waits for a yes.
    private func setBeats(_ ids: Set<Int>) {
        guard ids != beats else { return }
        if dropped(by: ids).isEmpty { applyBeats(ids) } else { pendingBeats = ids }
    }

    private func applyBeats(_ ids: Set<Int>) {
        orders.subtract(dropped(by: ids).map(\.id))
        beats = ids
    }

    private func create() async {
        let bills = picked.filter { !$0.isAssigned }
        // A second tap while the first create is in flight must not send (or fail) again.
        guard confirming, !model.saving, person != 0, !bills.isEmpty else { return }
        confirmError = nil
        let operation = BillRegisterRequest.create(beatIds: Set(bills.map(\.beatId)).sorted(), orderIds: bills.map(\.id).sorted(), assignedTo: person)
        guard let failure = await model.perform(operation) else {
            confirming = false
            orders = []
            dismiss()
            return
        }
        confirmError = failure.message
        // The server answered, so the list may be stale (say, a bill went in another register
        // meanwhile): reload it, and the summary drops whatever is taken.
        if failure.serverAnswered {
            await model.loadOrders(beats)
            orders = orders.intersection(model.orders.filter { !$0.isAssigned }.map(\.id))
        }
    }
}

private struct SharedBillFile: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct BillRegisterDetailScreen: View {
    let id: Int
    var onHome: () -> Void
    @StateObject private var model = BillRegisterViewModel()
    @State private var person = 0
    /// Register order ids (by `order_id`) ticked for clearing or removing.
    @State private var selected: Set<Int> = []
    @State private var action: BillRegisterRequest?
    @State private var choosingAssignee = false
    @State private var query = ""
    /// Whether the removed bills are listed; a remove opens it so the moved rows can be seen.
    @State private var showRemoved = false
    @State private var prompt: BillReasonPrompt?
    @State private var sharing: SharedBillFile?

    /// Managers act on a register while it is pending; a cleared or cancelled one is history.
    private var canAct: Bool { model.access.canManage && model.detail?.isPending == true }
    /// The server cancels only a register none of whose bills is cleared yet.
    private var canCancel: Bool {
        guard canAct, let entry = model.detail else { return false }
        return entry.clearedOrders == 0 && !(entry.orders ?? []).contains(where: \.isCleared)
    }
    private var isBusy: Bool { model.saving || prompt?.isWorking == true }

    var body: some View {
        CashPage(title: "Register #\(id)", onHome: onHome, onRefresh: { Task { await reload() } },
                 menu: canAct ? { AnyView(cancelMenuItem) } : nil) {
            BillRegisterFeedback(model: model)
            if model.error != nil && model.detail == nil { Button("Retry") { Task { await reload() } } }
            if let entry = model.detail {
                content(entry)
            }
        }
        // Android's Scaffold snackbar: done-messages float just above the action tray.
        .billSnackbar(message: $model.message)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if canAct, let entry = model.detail {
                bottomBar(entry).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: canAct)
        .tint(AppTheme.cerulean)
        .task { await reload(); await model.loadOptions() }
        .sheet(isPresented: $choosingAssignee) {
            BillRegisterPersonPicker(
                people: model.staff,
                isLoading: model.loading && model.staff.isEmpty,
                error: model.optionsError,
                selectedID: model.detail?.assignedTo,
                onRetry: { Task { await model.loadOptions() } },
                onPick: { picked in
                    choosingAssignee = false
                    person = picked.id
                    // Reassigning to who already holds it would be a no-op round trip.
                    guard picked.id != model.detail?.assignedTo else { return }
                    action = .assign(id: id, assignedTo: picked.id)
                }
            )
        }
        .sheet(item: $sharing) { file in ActivityShareSheet(items: [file.url]).presentationDetents([.medium, .large]) }
        .overlay { dialogs.animation(.easeOut(duration: 0.18), value: dialogKey) }
    }

    @ViewBuilder private func content(_ entry: BillRegisterEntry) -> some View {
        let all = entry.orders ?? []
        let active = all.filter { !$0.isRemoved }
        let removed = all.filter(\.isRemoved)
        // Pending first, so what is left to collect is on top.
        let activeShown = active.filter { $0.matches(query) }.enumerated()
            .sorted { ($0.element.isPending ? 0 : 1, $0.offset) < ($1.element.isPending ? 0 : 1, $1.offset) }.map(\.element)
        let removedShown = removed.filter { $0.matches(query) }
        let removedOpen = showRemoved || !query.trimmingCharacters(in: .whitespaces).isEmpty
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)

        BillRegisterHero(entry: entry)
        if entry.isCancelled { BillCancelledNote(entry: entry) }
        BillExportRow(exporting: model.exporting) { format in
            Task { if let url = await model.export(id: id, format: format) { sharing = SharedBillFile(url: url) } }
        }
        HStack {
            Text("Orders (\(active.count))").font(.system(size: 15, weight: .bold)).foregroundStyle(CashStyle.ink)
            Spacer()
            if canAct && active.contains(where: \.isPending) {
                let all = selected.count == active.filter(\.isPending).count
                Button(all ? "Unselect all" : "Select all pending") { toggleAll(active) }
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(CashStyle.green).disabled(isBusy)
            }
        }.padding(.leading, 4)
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(CashStyle.muted)
            TextField("Search order no, shop, seller, beat", text: $query).textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark").foregroundStyle(CashStyle.muted) }
                    .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.border, lineWidth: 1))
        if activeShown.isEmpty {
            Text(term.isEmpty && !removed.isEmpty ? "Every bill in this register was removed."
                 : term.isEmpty ? "No orders in this register."
                 : !removedShown.isEmpty ? "Only removed bills match \"\(term)\""
                 : "No orders match \"\(term)\"")
                .font(.system(size: 13)).foregroundStyle(CashStyle.muted)
                .frame(maxWidth: .infinity).padding(.vertical, 24).multilineTextAlignment(.center)
        }
        ForEach(activeShown) { order in
            BillRegisterOrderRow(order: order, selectable: canAct, selected: selected.contains(order.orderID), enabled: !isBusy) {
                toggle(order)
            }
        }
        if !removed.isEmpty {
            BillRemovedHeader(count: removed.count, amount: removed.reduce(0) { $0 + $1.currentPending }, open: removedOpen) {
                withAnimation(.easeInOut(duration: 0.25)) { showRemoved.toggle() }
            }
            if removedOpen {
                ForEach(removedShown) { order in
                    BillRegisterOrderRow(order: order, selectable: canAct, selected: false, enabled: false) {}
                }
            }
        }
    }

    /// The ⋮ menu's one item: cancel the register, or, greyed out, why it can't be.
    @ViewBuilder private var cancelMenuItem: some View {
        let entry = model.detail
        let all = entry?.orders ?? []
        let cleared = max(entry?.clearedOrders ?? 0, all.filter(\.isCleared).count)
        let pending = all.filter(\.isPending).count
        // iOS drops a disabled item's subtitle, so the why goes in the section header instead.
        Section(canCancel ? "Frees all \(billCount(pending)) to put in a new register"
                : "\(billCount(cleared)) already cleared, so it can't be cancelled. Remove the pending ones instead.") {
            Button(role: .destructive) { askCancel() } label: {
                Label("Cancel register", systemImage: "nosign")
            }
            .disabled(!canCancel || isBusy)
        }
    }

    /// Ticking a bill swaps register-wide actions for ones on the ticked bills.
    private func bottomBar(_ entry: BillRegisterEntry) -> some View {
        BillBottomBar {
            if selected.isEmpty {
                BillWeightedRow {
                    BillSecondaryButton(title: "Reassign", icon: "arrow.left.arrow.right", enabled: !isBusy) { choosingAssignee = true }
                        .billWeight(0.9)
                    BillPrimaryButton(title: "Clear All", icon: "checkmark.circle", enabled: !isBusy, loading: model.saving && prompt == nil) {
                        action = .clear(id: id, orderIds: nil)
                    }
                    .billWeight(1.3)
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            } else {
                VStack(spacing: 8) {
                    HStack {
                        let sum = (entry.orders ?? []).filter { selected.contains($0.orderID) }.reduce(0) { $0 + $1.currentPending }
                        Text("\(selected.count) selected · \(billMoney(sum))").font(.system(size: 13, weight: .semibold)).foregroundStyle(CashStyle.ink)
                        Spacer()
                        Button("Unselect") { selected = [] }
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(CashStyle.green).disabled(isBusy)
                    }
                    BillWeightedRow {
                        BillSecondaryButton(title: "Remove \(selected.count)", icon: "minus.circle", color: BillTone.err, enabled: !isBusy) { askRemove() }
                            .billWeight(1)
                        BillPrimaryButton(title: "Clear \(selected.count)", icon: "checkmark.circle", enabled: !isBusy, loading: model.saving && prompt == nil) {
                            action = .clear(id: id, orderIds: selected.sorted())
                        }
                        .billWeight(1.3)
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: selected.isEmpty)
    }

    /// Which dialog is up, so its coming and going fades instead of popping.
    private var dialogKey: String {
        model.alert != nil ? "alert" : prompt != nil ? "prompt" : action != nil ? "action" : ""
    }

    @ViewBuilder private var dialogs: some View {
        if let message = model.alert {
            BillErrorDialog(message: message) { model.alert = nil }
        } else if let current = prompt, let entry = model.detail {
            BillReasonDialog(
                prompt: Binding(get: { prompt ?? current }, set: { prompt = $0 }),
                entry: entry,
                onConfirm: { Task { await submitPrompt() } },
                onDismiss: { if prompt?.isWorking != true { prompt = nil } }
            )
        } else if let operation = action {
            BillConfirmDialog(
                icon: { if case .assign = operation { return "arrow.left.arrow.right" }; return "checkmark.circle" }(),
                title: confirmTitle,
                message: confirmMessage,
                confirmTitle: confirmButtonTitle,
                onConfirm: {
                    action = nil
                    Task { if await model.mutate(operation) { await reload() } }
                },
                onDismiss: { action = nil }
            )
        }
    }

    // Android names the consequence in each confirm instead of one generic sentence; clearing a
    // register can't be undone from here, so the count and amount belong in the prompt.
    private var pendingOrders: [BillRegisterOrderEntry] {
        (model.detail?.orders ?? []).filter { $0.isPending && $0.orderID > 0 }
    }

    private var reassignTargetName: String {
        model.staff.first { $0.id == person }?.name ?? "this employee"
    }

    private var confirmTitle: String {
        switch action {
        case .assign:
            return "Reassign to \(reassignTargetName)?"
        case .clear(_, let orderIds):
            guard let orderIds, !orderIds.isEmpty else { return "Clear the whole register?" }
            return "Clear \(orderIds.count) order\(orderIds.count == 1 ? "" : "s")?"
        default:
            return "Confirm register update?"
        }
    }

    private var confirmMessage: String {
        switch action {
        case .assign:
            let assigned = model.detail?.name ?? ""
            let current = assigned.isEmpty ? "The current employee" : assigned
            return "\(current) will no longer see this register."
        case .clear(_, let orderIds):
            if let orderIds, !orderIds.isEmpty {
                return "They'll be marked cleared. Once every order is cleared the register closes."
            }
            let total = pendingOrders.reduce(0) { $0 + $1.currentPending }
            return "All \(pendingOrders.count) pending orders (\(billMoney(total))) will be marked cleared, and the register closes."
        default:
            return "This will update the bill register on the server."
        }
    }

    private var confirmButtonTitle: String {
        if case .assign = action { return "Reassign" }
        return "Clear"
    }

    private func toggle(_ order: BillRegisterOrderEntry) {
        guard order.isPending, canAct, !isBusy, order.orderID > 0 else { return }
        if selected.contains(order.orderID) { selected.remove(order.orderID) } else { selected.insert(order.orderID) }
    }

    private func toggleAll(_ active: [BillRegisterOrderEntry]) {
        guard !isBusy else { return }
        let pending = Set(active.filter { $0.isPending && $0.orderID > 0 }.map(\.orderID))
        selected = selected.isSuperset(of: pending) ? [] : pending
    }

    private func askCancel() {
        if canCancel && !isBusy { prompt = BillReasonPrompt(action: .cancel) }
    }

    private func askRemove() {
        if canAct && !selected.isEmpty && !isBusy { prompt = BillReasonPrompt(action: .remove(selected)) }
    }

    private func submitPrompt() async {
        guard var current = prompt, !current.isWorking, let before = model.detail else { return }
        current.isWorking = true; current.error = nil
        prompt = current
        let reason = current.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let operation: BillRegisterRequest
        switch current.action {
        case .cancel: operation = .cancel(id: id, reason: reason.isEmpty ? nil : reason)
        case .remove(let ids): operation = .removeOrders(id: id, orderIds: ids.sorted(), reason: reason.isEmpty ? nil : reason)
        }
        if let failure = await model.perform(operation) {
            prompt?.isWorking = false
            prompt?.error = failure.message
            return
        }
        prompt = nil
        if case .remove(let ids) = current.action {
            selected.subtract(ids)
            showRemoved = true
        } else {
            selected = []
        }
        await reload()
        model.message = doneMessage(current.action, before: before)
    }

    /// What happened, read from the register as it was: a remove can also close it.
    private func doneMessage(_ action: BillReasonAction, before: BillRegisterEntry) -> String {
        let orders = before.orders ?? []
        switch action {
        case .cancel:
            return "Register #\(before.id) cancelled. Its \(billCount(orders.filter(\.isPending).count)) can go in a new register."
        case .remove(let ids):
            let n = billCount(ids.count)
            let left = orders.filter { $0.isPending && !ids.contains($0.orderID) }.count
            if left > 0 { return "\(n) removed and free for another register." }
            if orders.contains(where: \.isCleared) { return "\(n) removed. Nothing left to collect, so the register is cleared." }
            return "\(n) removed. No bills left, so the register is cancelled."
        }
    }

    private func reload() async {
        await model.loadDetail(id)
        person = model.detail?.assignedTo ?? 0
        // Keep only picks that can still be acted on.
        let pending = Set((model.detail?.orders ?? []).filter(\.isPending).map(\.orderID))
        selected = selected.intersection(pending)
    }
}

private struct BillRegisterFeedback: View {
    @ObservedObject var model: BillRegisterViewModel
    var body: some View {
        if model.loading || model.saving { ProgressView(model.saving ? "Saving…" : "Loading…").tint(AppTheme.cerulean) }
        if let error = model.error { Text(error).foregroundStyle(.red).font(.subheadline) }
    }
}

/// Android `PersonPickerDialog`: tapping Reassign picks the person straight away, so the detail
/// page doesn't have to carry an always-open dropdown card.
private struct BillRegisterPersonPicker: View {
    let people: [OrderInsightsStaffMember]
    let isLoading: Bool
    let error: String?
    let selectedID: Int?
    var onRetry: () -> Void
    var onPick: (OrderInsightsStaffMember) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var shown: [OrderInsightsStaffMember] {
        guard !term.isEmpty else { return people }
        return people.filter {
            $0.name.localizedCaseInsensitiveContains(term) || $0.role.localizedCaseInsensitiveContains(term)
        }
    }

    private var emptyMessage: String {
        term.isEmpty ? "No staff available." : "Nobody matches \u{201C}\(term)\u{201D}."
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                searchField
                content
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(AppTheme.whiteSmoke)
            .navigationTitle("Choose a person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search by name or role", text: $query)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
        } else if let error {
            VStack(spacing: 10) {
                Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
                Button("Retry") { onRetry() }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else if shown.isEmpty {
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(shown) { member in
                        row(for: member)
                    }
                }
            }
        }
    }

    private func row(for member: OrderInsightsStaffMember) -> some View {
        let isCurrent = member.id == selectedID
        return Button { onPick(member) } label: {
            HStack(spacing: 11) {
                Image(systemName: "person.fill").foregroundStyle(AppTheme.cerulean)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    if !member.role.isEmpty {
                        Text(member.role).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isCurrent {
                    Text("Current").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isCurrent ? CashStyle.pale : Color.white, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
