import SwiftUI

struct BillRegisterScreen: View {
    var onHome: () -> Void
    @StateObject private var model = BillRegisterViewModel()
    @State private var creating = false
    var body: some View {
        CashPage(title: model.access.canManage ? "Bill Register" : "My Bill Register", onHome: onHome, onRefresh: { Task { await model.load() } }) {
            // Android shows the six sessions as a wrapping chip row, not a dropdown, so the one
            // in use is visible without opening anything.
            VStack(alignment: .leading, spacing: 6) {
                Text("Session").font(.caption).foregroundStyle(CashStyle.muted)
                FlowLayout(spacing: 6) {
                    ForEach((0...5).map { BillOrderSession.startYear() - $0 }, id: \.self) { year in
                        let isSelected = model.orderSessionYear == year
                        Button {
                            model.orderSessionYear = year
                            model.orderID = BillOrderSession.replacingSession(in: model.orderID, with: year)
                        } label: {
                            Text(BillOrderSession.label(year)).font(.caption)
                                .padding(.horizontal, 11).padding(.vertical, 8)
                                .foregroundStyle(isSelected ? CashStyle.green : CashStyle.ink)
                                .background(isSelected ? CashStyle.pale : .white, in: Capsule())
                                .overlay(Capsule().stroke(isSelected ? CashStyle.green : CashStyle.border))
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("e.g. \(BillOrderSession.prefix(model.orderSessionYear))1780", text: $model.orderID)
                    .textInputAutocapitalization(.never)
                    .onSubmit { Task { await model.load() } }
                if !model.orderID.isEmpty {
                    Button { model.orderID = ""; Task { await model.load() } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain).accessibilityLabel("Clear order ID")
                }
            }.padding(13).background(.white, in: RoundedRectangle(cornerRadius: 12))
            Text(BillOrderSession.filter(model.orderID).map { "Showing registers for order \($0)" } ?? "Enter the order number after the session. You can edit or clear the full ID.")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 6)
            HStack(spacing: 8) {
                ForEach([("pending", "Pending"), ("cleared", "Cleared"), ("", "All")], id: \.0) { value, title in
                    Button { model.status = value } label: {
                        Text(title).font(.subheadline.weight(.semibold))
                            .foregroundStyle(model.status == value ? .white : AppTheme.textPrimary)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(model.status == value ? AppTheme.cerulean : .white, in: Capsule())
                            .overlay(Capsule().stroke(model.status == value ? AppTheme.cerulean : AppTheme.gainsboro))
                    }.buttonStyle(.plain)
                }
            }
            if model.access.canManage {
                CashDropdown(title: "Employee", placeholder: "All employees", options: [CashDropdownOption(id: "0", title: "All employees", icon: "person.3.fill")] + model.staff.map { CashDropdownOption(id: "\($0.id)", title: $0.name, icon: "person.fill") }, selection: Binding(get: { "\(model.assignedTo)" }, set: { model.assignedTo = Int($0) ?? 0 }))
                if let error = model.optionsError {
                    Text(error).foregroundStyle(.red)
                    Button("Retry staff") { Task { await model.loadOptions() } }
                }
                if model.assignedTo != 0 {
                    Button("Show all employees") { model.assignedTo = 0 }
                }
            }
            BillRegisterFeedback(model: model)
            let shownEntries = model.entries
            Text("\(shownEntries.count) registers").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
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
                    return "Tap New Bill Register to pick beats and assign their pending bills."
                }()
                ContentUnavailableView("No registers", systemImage: "doc.text", description: Text(emptyMessage))
            }
            ForEach(shownEntries) { entry in
                NavigationLink { BillRegisterDetailScreen(id: entry.id, onHome: onHome) } label: {
                    CashCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Register #\(entry.id)").font(.headline)
                                    Text(entry.name.isEmpty ? "Assigned employee" : "Assigned to \(entry.name)").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(entry.status.capitalized).font(.caption.weight(.semibold)).foregroundStyle(.orange)
                                    .padding(.horizontal, 12).padding(.vertical, 7).background(Color.orange.opacity(0.14), in: Capsule())
                            }
                            if !entry.beatNames.isEmpty { Text(entry.beatNames.joined(separator: ", ")).font(.subheadline).foregroundStyle(.secondary) }
                            ProgressView(value: Double(entry.clearedOrders), total: Double(max(entry.totalOrders, 1))).tint(AppTheme.cerulean)
                            HStack {
                                Text("\(entry.clearedOrders) of \(entry.totalOrders) orders cleared").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("Pending \(billMoney(entry.pendingAmount))").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                            }
                        }
                    }
                }.buttonStyle(.plain)
            }
            if model.hasMore && !model.loading {
                Button("Load more") { Task { await model.load(more: true) } }
                    .tint(AppTheme.cerulean)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.access.canManage {
                Button { creating = true } label: {
                    Label("New Bill Register", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.cerulean)
                .padding(.horizontal, 14).padding(.vertical, 8).background(.regularMaterial)
            }
        }
        .tint(AppTheme.cerulean)
        .task(id: "\(model.status)-\(model.assignedTo)-\(model.orderID)") {
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            await model.load()
        }
        .onChange(of: model.orderID) { _, value in
            if let year = BillOrderSession.year(in: value) { model.orderSessionYear = year }
        }
        .task { await model.loadOptions() }
        .sheet(isPresented: $creating, onDismiss: { Task { await model.load() } }) { BillRegisterCreateScreen() }
    }
}

private struct BillRegisterCreateScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = BillRegisterViewModel()
    @State private var beats: Set<Int> = []
    @State private var orders: Set<Int> = []
    @State private var person = 0
    @State private var search = ""
    @State private var confirm = false
    private var selectedAmount: Double { model.orders.filter { orders.contains($0.id) }.reduce(0) { $0 + $1.pendingAmount } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Choose beats") {
                    if let error = model.optionsError {
                        Text(error).foregroundStyle(.red)
                        Button("Retry") { Task { await model.loadOptions(includeBeats: true) } }
                    }
                    CashMultiDropdown(title: "Beats *", placeholder: "Choose beats", options: model.beats.map { CashDropdownOption(id: "\($0.id)", title: $0.name) }, selection: Binding(get: { Set(beats.map(String.init)) }, set: { beats = Set($0.compactMap(Int.init)); orders = [] }))
                    if model.beats.isEmpty && model.optionsError == nil { Text("Loading beats…").foregroundStyle(.secondary) }
                }
                Section("Assign to") {
                    CashDropdown(title: "Assign to *", placeholder: "Choose an employee", options: model.staff.map { CashDropdownOption(id: "\($0.id)", title: $0.name, icon: "person.fill") }, selection: Binding(get: { person == 0 ? "" : "\(person)" }, set: { person = Int($0) ?? 0 }))
                }
                Section("Orders · \(orders.count) selected") {
                    TextField("Search order or shop", text: $search)
                    if !model.orders.isEmpty {
                        Button("Select all available") { orders = Set(model.orders.filter { !$0.isAssigned }.map(\.id)) }
                        Button("Clear selection") { orders = [] }
                    }
                    BillRegisterFeedback(model: model)
                    if let _ = model.error { Button("Retry orders") { Task { await model.loadOrders(beats) } } }
                    if !beats.isEmpty && model.orders.isEmpty && !model.loading && model.error == nil { Text("No orders found for these beats.") }
                    ForEach(model.orders.filter {
                        search.isEmpty || $0.orderNo.localizedCaseInsensitiveContains(search)
                            || $0.sellerShopName.localizedCaseInsensitiveContains(search)
                            || $0.sellerName.localizedCaseInsensitiveContains(search)
                            || $0.beatName.localizedCaseInsensitiveContains(search)
                    }) { order in
                        Toggle(isOn: Binding(get: { orders.contains(order.id) }, set: { selected in
                            if selected { orders.insert(order.id) } else { orders.remove(order.id) }
                        })) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.orderNo).font(.headline)
                                Text(order.sellerShopName).font(.subheadline)
                                Text("\(order.beatName) · Pending ₹\(order.pendingAmount.formatted())").font(.caption)
                                if order.isAssigned { Text("Already assigned").font(.caption).foregroundStyle(.secondary) }
                            }
                        }.disabled(order.isAssigned)
                    }
                }
            }
            .disabled(model.saving).tint(AppTheme.cerulean)
            .navigationTitle("Create Bill Register").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(model.saving) } }
            .interactiveDismissDisabled(model.saving)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(orders.count) orders selected").font(.caption).foregroundStyle(.secondary)
                    Text(billMoney(selectedAmount)).font(.title3.bold())
                    Button { confirm = true } label: {
                        Label("Create & Assign", systemImage: "checkmark").frame(maxWidth: .infinity).padding(13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.cerulean)
                    .disabled(beats.isEmpty || orders.isEmpty || person == 0 || model.loading || model.saving)
                }.padding(14).background(.regularMaterial)
            }
            .task { await model.loadOptions(includeBeats: true) }
            .task(id: beats) { await model.loadOrders(beats) }
            .confirmationDialog("Create register with \(orders.count) orders?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Confirm Create") {
                    Task { if await model.mutate(.create(beatIds: beats.sorted(), orderIds: orders.sorted(), assignedTo: person)) { dismiss() } }
                }
            }
        }
    }
}

private func billMoney(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "INR"
    formatter.locale = Locale(identifier: "en_IN")
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = amount.rounded() == amount ? 0 : 2
    return formatter.string(from: NSNumber(value: amount)) ?? "₹\(amount)"
}

private struct BillRegisterDetailScreen: View {
    let id: Int
    var onHome: () -> Void
    @StateObject private var model = BillRegisterViewModel()
    @State private var person = 0
    @State private var selected: Set<Int> = []
    @State private var action: BillRegisterRequest?
    @State private var choosingAssignee = false
    var body: some View {
        CashPage(title: "Register #\(id)", onHome: onHome, onRefresh: { Task { await reload() } }) {
            BillRegisterFeedback(model: model)
            if let _ = model.error { Button("Retry") { Task { await reload() } } }
            if let entry = model.detail {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(entry.isCleared ? "COLLECTED" : "PENDING TO COLLECT")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(entry.status.capitalized).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.darkMidnightBlue)
                            .padding(.horizontal, 12).padding(.vertical, 7).background(.white.opacity(0.9), in: Capsule())
                    }
                    Text(billMoney(entry.isCleared ? entry.totalAmount : entry.pendingAmount))
                        .font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("Assigned to \(entry.name.isEmpty ? "Staff #\(entry.assignedTo ?? 0)" : entry.name)")
                        .font(.headline).foregroundStyle(.white)
                    if !entry.beatNames.isEmpty { Text(entry.beatNames.joined(separator: ", ")).font(.subheadline).foregroundStyle(.white.opacity(0.86)) }
                    ProgressView(value: Double(entry.clearedOrders), total: Double(max(entry.totalOrders, 1))).tint(.white)
                    HStack {
                        registerMetric("Orders cleared", "\(entry.clearedOrders) / \(entry.totalOrders)")
                        registerMetric("Total billed", billMoney(entry.totalAmount))
                    }
                }.padding(18).background(AppTheme.ctaGradient, in: RoundedRectangle(cornerRadius: 20))
                HStack {
                    Text("Orders (\(entry.orders?.count ?? 0))").font(.headline)
                    Spacer()
                    if model.access.canManage, let orders = entry.orders {
                        Button(selected.count == orders.filter({ !$0.isCleared }).count ? "Deselect pending" : "Select all pending") {
                            let pending = Set(orders.filter { !$0.isCleared && $0.orderID > 0 }.map(\.orderID))
                            selected = selected == pending ? [] : pending
                        }.font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.cerulean)
                    }
                }
                if let orders = entry.orders {
                    if orders.isEmpty { Text("No orders in this register.").foregroundStyle(.secondary) }
                    ForEach(Array(orders.enumerated()), id: \.offset) { _, order in
                        let orderID = order.orderID
                        CashCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(order.orderNo.isEmpty ? "Order #\(orderID)" : order.orderNo).font(.headline)
                                if !order.shop.isEmpty { Text(order.shop) }
                                if !order.seller.isEmpty { Text(order.seller).font(.caption) }
                                Text("Pending ₹\(order.currentPending.formatted()) · Order ₹\(order.amount.formatted())")
                                    .font(.subheadline)
                                Text(order.status.capitalized).font(.caption)
                                if model.access.canManage && !entry.isCleared && orderID > 0 && !order.isCleared {
                                    Toggle("Select to clear", isOn: Binding(get: { selected.contains(orderID) }, set: { value in
                                        if value { selected.insert(orderID) } else { selected.remove(orderID) }
                                    })).disabled(model.saving)
                                }
                            }
                        }
                    }
                } else { Text("Order details are not available in this response.").foregroundStyle(.secondary) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let entry = model.detail, model.access.canManage, !entry.isCleared {
                HStack(spacing: 10) {
                    // Same 52pt / 14pt radius as Android, instead of iOS's taller, rounder
                    // bordered defaults.
                    let nothingToClear = (entry.orders ?? []).allSatisfy(\.isCleared)
                    Button { choosingAssignee = true } label: {
                        Label("Reassign", systemImage: "arrow.left.arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .foregroundStyle(AppTheme.cerulean)
                            .background(AppTheme.cerulean.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                            .opacity(model.saving ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.saving)

                    Button { action = .clear(id: id, orderIds: selected.isEmpty ? nil : selected.sorted()) } label: {
                        Label(selected.isEmpty ? "Clear All" : "Clear \(selected.count)", systemImage: "checkmark.double")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .foregroundStyle(.white)
                            .background(AppTheme.cerulean, in: RoundedRectangle(cornerRadius: 14))
                            .opacity(model.saving || nothingToClear ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.saving || nothingToClear)
                }.padding(.horizontal, 14).padding(.vertical, 8).background(.regularMaterial)
            }
        }
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
        .confirmationDialog(confirmTitle, isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } }), titleVisibility: .visible) {
            if let operation = action {
                Button(confirmButtonTitle, role: .destructive) {
                    Task { if await model.mutate(operation) { await reload() } }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text(confirmMessage) }
    }
    // Android names the consequence in each confirm instead of one generic sentence; clearing a
    // register can't be undone from here, so the count and amount belong in the prompt.
    private var pendingOrders: [BillRegisterOrderEntry] {
        (model.detail?.orders ?? []).filter { !$0.isCleared && $0.orderID > 0 }
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

    private func reload() async {
        selected = []
        await model.loadDetail(id)
        person = model.detail?.assignedTo ?? 0
    }

    private func registerMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.8))
            Text(value).font(.headline.bold()).foregroundStyle(.white)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct BillRegisterFeedback: View {
    @ObservedObject var model: BillRegisterViewModel
    var body: some View {
        if model.loading || model.saving { ProgressView(model.saving ? "Saving…" : "Loading…").tint(AppTheme.cerulean) }
        if let error = model.error { Text(error).foregroundStyle(.red).font(.subheadline) }
        if let message = model.message { Text(message).foregroundStyle(AppTheme.cerulean).font(.subheadline) }
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
