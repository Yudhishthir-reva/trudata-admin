import SwiftUI

struct BillRegisterScreen: View {
    var onHome: () -> Void
    @StateObject private var model = BillRegisterViewModel()
    @State private var creating = false
    var body: some View {
        CashPage(title: model.access.canManage ? "Bill Register" : "My Bill Registers", onHome: onHome, onRefresh: { Task { await model.load() } }) {
            CashDropdown(title: "Session", placeholder: "Choose session", options: (0...5).map {
                let year = BillOrderSession.startYear() - $0
                return CashDropdownOption(id: String(year), title: BillOrderSession.label(year), icon: "calendar")
            }, selection: Binding(get: { String(model.orderSessionYear) }, set: {
                guard let year = Int($0) else { return }
                model.orderSessionYear = year
                model.orderID = BillOrderSession.replacingSession(in: model.orderID, with: year)
            }), searchable: false)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("\(BillOrderSession.prefix(model.orderSessionYear))1780", text: $model.orderID)
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
                ContentUnavailableView("No bill registers", systemImage: "doc.text", description: Text(model.access.canManage ? "Create a register from beat orders to get started." : "Registers assigned to you will appear here."))
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
            if model.hasMore && !model.loading { Button("Load more") { Task { await model.load(more: true) } } }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.access.canManage {
                Button { creating = true } label: {
                    Label("New Bill Register", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(14)
                }.buttonStyle(.borderedProminent).padding(.horizontal, 14).padding(.vertical, 8).background(.regularMaterial)
            }
        }
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
                    }.buttonStyle(.borderedProminent)
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
    var body: some View {
        CashPage(title: "Register #\(id)", onHome: onHome, onRefresh: { Task { await reload() } }) {
            BillRegisterFeedback(model: model)
            if let _ = model.error { Button("Retry") { Task { await reload() } } }
            if let entry = model.detail {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("PENDING TO COLLECT").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(entry.status.capitalized).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.darkMidnightBlue)
                            .padding(.horizontal, 12).padding(.vertical, 7).background(.white.opacity(0.9), in: Capsule())
                    }
                    Text(billMoney(entry.pendingAmount)).font(.largeTitle.bold()).foregroundStyle(.white)
                    Text("Assigned to \(entry.name.isEmpty ? "Staff #\(entry.assignedTo ?? 0)" : entry.name)")
                        .font(.headline).foregroundStyle(.white)
                    if !entry.beatNames.isEmpty { Text(entry.beatNames.joined(separator: ", ")).font(.subheadline).foregroundStyle(.white.opacity(0.86)) }
                    ProgressView(value: Double(entry.clearedOrders), total: Double(max(entry.totalOrders, 1))).tint(.white)
                    HStack {
                        registerMetric("Orders cleared", "\(entry.clearedOrders) / \(entry.totalOrders)")
                        registerMetric("Total billed", billMoney(entry.totalAmount))
                    }
                }.padding(18).background(AppTheme.ctaGradient, in: RoundedRectangle(cornerRadius: 20))
                if model.access.canManage && entry.status != "cleared" {
                    CashCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Reassign register", systemImage: "person.crop.circle.badge.arrow.forward").font(.headline)
                            CashDropdown(title: "Assign to", placeholder: "Choose staff", options: model.staff.map { CashDropdownOption(id: "\($0.id)", title: $0.name, icon: "person.fill") }, selection: Binding(get: { person == 0 ? "" : "\(person)" }, set: { person = Int($0) ?? 0 }))
                            if let error = model.optionsError {
                                Text(error).foregroundStyle(.red)
                                Button("Retry staff") { Task { await model.loadOptions() } }
                            }
                        }
                    }.disabled(model.saving || model.loading)
                }
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
                                if model.access.canManage && entry.status != "cleared" && orderID > 0 && !order.isCleared {
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
            if let entry = model.detail, model.access.canManage, entry.status != "cleared" {
                HStack(spacing: 10) {
                    Button { action = .assign(id: id, assignedTo: person) } label: {
                        Label("Reassign", systemImage: "arrow.left.arrow.right").frame(maxWidth: .infinity).padding(12)
                    }.buttonStyle(.bordered).disabled(person == 0 || model.saving)
                    Button { action = .clear(id: id, orderIds: selected.isEmpty ? nil : selected.sorted()) } label: {
                        Label(selected.isEmpty ? "Clear All" : "Clear (\(selected.count))", systemImage: "checkmark.double")
                            .frame(maxWidth: .infinity).padding(12)
                    }.buttonStyle(.borderedProminent).disabled(model.saving || (entry.orders ?? []).allSatisfy(\.isCleared))
                }.padding(.horizontal, 14).padding(.vertical, 8).background(.regularMaterial)
            }
        }
        .task { await reload(); await model.loadOptions() }
        .confirmationDialog("Confirm register update?", isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } }), titleVisibility: .visible) {
            if let operation = action {
                Button("Confirm") { Task { if await model.mutate(operation) { await reload() } } }
            }
        } message: { Text("This will update the bill register on the server.") }
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
        if model.loading || model.saving { ProgressView(model.saving ? "Saving…" : "Loading…") }
        if let error = model.error { Text(error).foregroundStyle(.red).font(.subheadline) }
        if let message = model.message { Text(message).foregroundStyle(AppTheme.cerulean).font(.subheadline) }
    }
}
