import SwiftUI
import AVFoundation
import Speech
import Combine

private enum CashStyle {
    static let deep = Color(red: 14/255, green: 74/255, blue: 40/255)
    static let green = Color(red: 22/255, green: 116/255, blue: 68/255)
    static let bright = Color(red: 29/255, green: 135/255, blue: 80/255)
    static let pale = Color(red: 232/255, green: 245/255, blue: 238/255)
    static let border = Color(red: 228/255, green: 231/255, blue: 235/255)
    static let muted = Color(red: 107/255, green: 114/255, blue: 128/255)
    static let ink = Color(red: 17/255, green: 24/255, blue: 39/255)
    static let gradient = LinearGradient(colors: [deep, green, bright], startPoint: .leading, endPoint: .trailing)
}

struct CashCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content().padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(CashStyle.border, lineWidth: 1))
    }
}

struct CashDropdownOption: Identifiable, Hashable {
    let id: String
    let title: String
    var detail: String? = nil
    var icon: String? = nil
}

struct CashDropdown: View {
    let title: String
    let placeholder: String
    let options: [CashDropdownOption]
    @Binding var selection: String
    var searchable = true
    @State private var isPresented = false

    private var selectedTitle: String? { options.first { $0.id == selection }?.title }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.textPrimary)
            Button { isPresented = true } label: {
                HStack(spacing: 11) {
                    Image(systemName: options.first { $0.id == selection }?.icon ?? "list.bullet")
                        .foregroundStyle(AppTheme.cerulean).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedTitle ?? placeholder).foregroundStyle(selectedTitle == nil ? AppTheme.slateGray : AppTheme.textPrimary)
                        if let detail = options.first(where: { $0.id == selection })?.detail {
                            Text(detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.slateGray)
                }.padding(.horizontal, 14).padding(.vertical, 13)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.gainsboro, lineWidth: 1))
            }.buttonStyle(.plain)
        }
        .sheet(isPresented: $isPresented) {
            CashDropdownSheet(title: title, options: options, selection: $selection, searchable: searchable)
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    }
}

private struct CashDropdownSheet: View {
    let title: String
    let options: [CashDropdownOption]
    @Binding var selection: String
    let searchable: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [CashDropdownOption] {
        guard !query.isEmpty else { return options }
        return options.filter { $0.title.localizedCaseInsensitiveContains(query) || ($0.detail?.localizedCaseInsensitiveContains(query) ?? false) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.title3.weight(.semibold))
                    Text("Choose one option").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }.foregroundStyle(AppTheme.cerulean)
            }
            if searchable {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search by name", text: $query)
                }.padding(12).background(AppTheme.whiteSmoke, in: RoundedRectangle(cornerRadius: 11))
            }
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(filtered) { option in
                        Button {
                            selection = option.id
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: option.icon ?? "person.crop.circle")
                                    .foregroundStyle(AppTheme.cerulean).frame(width: 22)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(option.title).foregroundStyle(AppTheme.textPrimary)
                                    if let detail = option.detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                if selection == option.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.cerulean) }
                            }.padding(.horizontal, 9).frame(minHeight: 48)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    if filtered.isEmpty { ContentUnavailableView.search(text: query) }
                }
            }
        }.padding(18).background(AppTheme.whiteSmoke)
    }
}

struct CashMultiDropdown: View {
    let title: String
    let placeholder: String
    let options: [CashDropdownOption]
    @Binding var selection: Set<String>
    @State private var isPresented = false

    private var valueTitle: String {
        if selection.isEmpty { return placeholder }
        if selection.count == 1, let id = selection.first, let option = options.first(where: { $0.id == id }) { return option.title }
        return "\(selection.count) selected"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.textPrimary)
            Button { isPresented = true } label: {
                HStack(spacing: 11) {
                    Image(systemName: "map.fill").foregroundStyle(AppTheme.cerulean).frame(width: 20)
                    Text(valueTitle).foregroundStyle(selection.isEmpty ? AppTheme.slateGray : AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.slateGray)
                }.padding(.horizontal, 14).padding(.vertical, 13)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.gainsboro, lineWidth: 1))
            }.buttonStyle(.plain)
        }.sheet(isPresented: $isPresented) {
            CashMultiDropdownSheet(title: title, options: options, selection: $selection)
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    }
}

private struct CashMultiDropdownSheet: View {
    let title: String
    let options: [CashDropdownOption]
    @Binding var selection: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Set<String> = []
    @State private var query = ""

    private var filtered: [CashDropdownOption] {
        query.isEmpty ? options : options.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.title3.weight(.semibold))
                    Text("\(draft.count) selected").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }.foregroundStyle(AppTheme.cerulean)
            }
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search beats", text: $query)
            }.padding(12).background(AppTheme.whiteSmoke, in: RoundedRectangle(cornerRadius: 11))
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(filtered) { option in
                        Button {
                            if draft.contains(option.id) { draft.remove(option.id) }
                            else { draft.insert(option.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: draft.contains(option.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(draft.contains(option.id) ? AppTheme.cerulean : AppTheme.slateGray)
                                Text(option.title).foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                            }.frame(minHeight: 46).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }
            Button("Use selected beats") { selection = draft; dismiss() }
                .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(14)
                .background(AppTheme.ctaGradient, in: RoundedRectangle(cornerRadius: 13))
        }.padding(18).background(AppTheme.whiteSmoke).onAppear { draft = selection }
    }
}

private struct CashTabs: View {
    let titles: [String]
    @Binding var selection: String
    var body: some View {
        HStack(spacing: 4) {
            ForEach(titles, id: \.self) { title in
                Button { selection = title } label: {
                    Text(title).font(.subheadline.weight(selection == title ? .semibold : .regular))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(selection == title ? .white : CashStyle.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background {
                            if selection == title { RoundedRectangle(cornerRadius: 10).fill(CashStyle.gradient) }
                        }
                }.buttonStyle(.plain)
            }
        }.padding(.vertical, 4)
    }
}

struct UtilityScreen: View {
    var onHome: () -> Void
    private var access: CashAccess { CashAccess(role: UserDefaultManager.shared.getUserDefaultsString(key: .userRole)) }

    var body: some View {
        CashPage(title: "Utility", onHome: onHome) {
            VStack(alignment: .leading, spacing: 20) {
                utilityGroup("DAILY CASH") {
                NavigationLink {
                    CashCollectionScreen(onHome: onHome)
                } label: {
                    tile("Cash Collection", description: access.canReviewAll ? "Submit cash by denomination, and review everyone's submissions." : "Hand over the day's cash, counted note by note, and track its approval.", icon: "banknote", filled: true)
                }
                if access.canManageAmountTaken {
                    NavigationLink { AmountTakenScreen(onHome: onHome) } label: {
                        tile("Amount Taken", description: "Record cash out for expenses", icon: "wallet.pass", filled: false)
                    }
                }
                }
                utilityGroup("PAYMENTS") {
                NavigationLink { BillRegisterScreen(onHome: onHome) } label: {
                    tile("Bill Register", description: "View assigned bills and track register clearance.", icon: "doc.text", filled: false)
                }
                NavigationLink { PaymentAdvanceScreen(onHome: onHome) } label: {
                    tile(access.canReviewAll ? "Payment Advance" : "My Payment Advance", description: access.canReviewAll ? "Give advances, receive payments and track outstanding balances." : "View your advances and returned payments.", icon: "indianrupeesign.circle", filled: false)
                }
                }
                if access.canViewLedger {
                    utilityGroup("REPORTS") {
                    NavigationLink { CashLedgerScreen(onHome: onHome) } label: {
                        tile("Ledger", description: "View cash history and staff totals", icon: "book.closed", filled: false)
                    }
                    }
                }
            }.buttonStyle(.plain)
        }
    }

    private func utilityGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(CashStyle.muted)
            content()
        }
    }

    private func tile(_ title: String, description: String, icon: String, filled: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2.weight(.semibold)).frame(width: 52, height: 52)
                .background(filled ? .white.opacity(0.14) : .white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.title3.weight(.semibold))
                Text(description).font(.subheadline).opacity(0.85).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.right").font(.title3.weight(.semibold))
        }
        .foregroundStyle(filled ? .white : CashStyle.ink)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18).fill(filled ? CashStyle.gradient : LinearGradient(colors: [CashStyle.pale, Color(red: 0.94, green: 0.97, blue: 0.95)], startPoint: .leading, endPoint: .trailing))
        }
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(filled ? .clear : CashStyle.green.opacity(0.16)))
    }
}

struct CashCollectionScreen: View {
    var onHome: () -> Void
    @StateObject private var model = CashCollectionViewModel()
    @StateObject private var summaryModel = CashCollectionViewModel(initialPeriod: .today)
    @State private var tab = "Submit"
    @State private var form = CashCountForm()
    @State private var confirm = false

    var body: some View {
        CashPage(title: "Cash Collection", onHome: onHome, onRefresh: { refresh() }) {
            CashTabs(titles: ["Submit", "All Collection", "Summary"], selection: $tab)
            CashFeedback(model: model)
            if tab == "Submit" {
                CashDenominationForm(form: $form).disabled(model.isSaving)
            } else {
                if tab == "All Collection" {
                    CashFilterView(filter: $model.filter, people: model.people, showsStaff: model.access.canReviewAll, showsStatus: model.access.canReviewAll)
                    if let error = model.peopleError { CashRetry(message: error) { Task { await model.loadPeople() } } }
                    Text(model.access.canReviewAll ? "All submissions" : "My submissions").font(.headline)
                    CashRecordList(model: model, onHome: onHome)
                } else {
                    CashFilterView(filter: $summaryModel.filter, people: summaryModel.people, showsStaff: summaryModel.access.canReviewAll)
                    if let error = summaryModel.peopleError { CashRetry(message: error) { Task { await summaryModel.loadPeople() } } }
                    CashSummaryView(model: summaryModel)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if tab == "Submit" {
                CashSubmitFooter(form: form, isSaving: model.isSaving, onClear: { form = CashCountForm() }, onSubmit: { confirm = true })
            }
        }
        .task { await model.loadPeople(); await summaryModel.loadPeople() }
        .onChange(of: summaryModel.filter) { _ in if tab == "Summary" { refresh() } }
        .onChange(of: tab) { _ in refresh() }
        .onChange(of: model.filter) { _ in refresh() }
        .confirmationDialog("Submit \(cashMoney(Int(form.declared) ?? 0))?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Confirm submission") {
                Task {
                    if await model.submit(form) { form = CashCountForm(); tab = "All Collection" }
                }
            }
        } message: { Text("Confirm that the counted notes and coins match the cash you are handing over.") }
    }

    private func refresh() {
        Task {
            if tab == "All Collection" { await model.reload() }
            if tab == "Summary" { await summaryModel.loadSummary() }
        }
    }
}

struct CashCollectionDetailScreen: View {
    let id: Int
    var onHome: () -> Void
    @StateObject private var model = CashCollectionViewModel()
    @State private var remark = ""
    @State private var editing = false
    @State private var form = CashCountForm()
    @State private var reviewAction: Bool?
    @State private var confirmEdit = false

    var body: some View {
        CashPage(title: "Collection Detail", onHome: onHome, onRefresh: { Task { await model.loadDetail(id) } }) {
            CashFeedback(model: model)
            if model.isLoading { ProgressView() }
            if let record = model.detail {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("COLLECTION #\(record.id)").font(.caption.weight(.medium))
                        Spacer()
                        Text(record.status.capitalized).font(.caption.weight(.medium))
                            .foregroundStyle(CashStyle.green).padding(8).background(CashStyle.pale, in: Capsule())
                    }
                    Text(cashMoney(record.amount)).font(.largeTitle.bold())
                    Text("Submitted by \(record.name)").font(.headline)
                    Text(record.submittedAt).font(.subheadline)
                }.foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 18))
                if editing {
                    CashDenominationForm(form: $form).disabled(model.isSaving)
                    Button("Save Changes") { confirmEdit = true }
                        .buttonStyle(.borderedProminent).disabled(!form.isBalanced || model.isSaving)
                    Button("Cancel Edit") { editing = false }.disabled(model.isSaving)
                } else {
                    CashDenominationLines(lines: record.denominations)
                    if !record.reviewedBy.isEmpty {
                        CashCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Review", systemImage: "info.circle.fill").font(.headline)
                                Text("Reviewed by \(record.reviewedBy)")
                            }
                        }
                    }
                    if model.access.canEdit && record.status != "approved" {
                        Button("Edit Counts") { form = CashCountForm(record: record); editing = true }
                            .buttonStyle(.bordered).disabled(model.isSaving)
                    }
                    if model.access.canReviewAll && record.status == "pending" {
                        HStack(alignment: .bottom) {
                            TextField("Review remark (required to reject)", text: $remark, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: remark) { value in remark = String(value.prefix(250)) }
                            SpeechRemarkButton(text: $remark)
                        }
                        HStack {
                            Button("Approve") { reviewAction = true }.buttonStyle(.borderedProminent)
                            Button("Reject", role: .destructive) { reviewAction = false }
                                .buttonStyle(.bordered).disabled(remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }.disabled(model.isSaving)
                    }
                }
            } else if !model.isLoading {
                Button("Retry") { Task { await model.loadDetail(id) } }
            }
        }
        .task { await model.loadDetail(id) }
        .confirmationDialog(reviewAction == true ? "Approve this collection?" : "Reject this collection?", isPresented: Binding(get: { reviewAction != nil }, set: { if !$0 { reviewAction = nil } }), titleVisibility: .visible) {
            let approve = reviewAction == true
            Button(approve ? "Approve" : "Reject", role: approve ? nil : .destructive) {
                Task {
                    if await model.review(approve: approve, remark: remark) {
                        remark = ""
                        await model.loadDetail(id)
                    }
                }
            }
        }
        .confirmationDialog("Save the updated cash counts?", isPresented: $confirmEdit, titleVisibility: .visible) {
            Button("Save Changes") {
                Task {
                    if await model.submit(form, editing: id) { editing = false; await model.loadDetail(id) }
                }
            }
        }
    }
}

struct AmountTakenScreen: View {
    var onHome: () -> Void
    @StateObject private var model = CashCollectionViewModel(kind: .taken)
    @State private var tab = "Add"
    @State private var personId = 0
    @State private var amount = ""
    @State private var reason = ""
    @State private var remark = ""
    @State private var date = Date()
    @State private var collectionId = 0
    @State private var confirmAdd = false
    @State private var selected: CashRecord?
    @State private var detailRecord: CashRecord?

    var body: some View {
        CashPage(title: "Amount Taken", onHome: onHome, onRefresh: { Task { await model.reload(); await model.loadPeople() } }) {
            if model.access.canManageAmountTaken {
                CashTabs(titles: ["Add", "List"], selection: $tab)
                CashFeedback(model: model)
                if tab == "Add" {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    Text("Person").font(.subheadline.bold())
                    Picker("Person", selection: $personId) {
                        Text("Choose a person").tag(0)
                        ForEach(model.people) { Text($0.name).tag($0.id) }
                    }
                    if let error = model.peopleError { CashRetry(message: error) { Task { await model.loadPeople() } } }
                    TextField("Amount (₹)", text: $amount).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                    TextField("Reason (optional)", text: $reason).textFieldStyle(.roundedBorder)
                        .onChange(of: reason) { reason = String($0.prefix(100)) }
                    HStack(alignment: .bottom) {
                        TextField("Remark (optional)", text: $remark, axis: .vertical).textFieldStyle(.roundedBorder)
                            .onChange(of: remark) { remark = String($0.prefix(250)) }
                        SpeechRemarkButton(text: $remark)
                    }
                    if model.isLoadingLinks { ProgressView("Loading collections…") }
                    if let error = model.linksError { Text("Optional collection link unavailable: \(error)").font(.caption).foregroundStyle(.secondary) }
                    Text("Link collection (optional)").font(.subheadline.bold())
                    Picker("Link collection (optional)", selection: $collectionId) {
                        Text("None").tag(0)
                        ForEach(model.linkedCollections) { record in
                            Text("#\(record.id) · \(cashMoney(record.amount)) · \(record.date)").tag(record.id)
                        }
                    }
                    Button("Record Amount") { confirmAdd = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(personId == 0 || (Int(amount) ?? 0) <= 0 || model.isSaving || model.isLoadingLinks)
                } else {
                    CashFilterView(filter: $model.filter, people: model.people, showsStaff: true)
                    if model.isLoading { ProgressView() }
                    if model.records.isEmpty && !model.isLoading { Text("No amounts taken for this period.").foregroundStyle(.secondary) }
                    ForEach(model.records) { record in
                        VStack(alignment: .leading, spacing: 10) {
                            Button { detailRecord = record } label: { CashRecordCard(record: record) }.buttonStyle(.plain)
                            if record.status == "pending" {
                                Button("Review") { selected = record }.buttonStyle(.bordered)
                            }
                        }
                    }
                    CashLoadMore(model: model)
                }
            } else { Text("You don't have access to this.") }
        }
        .task { await model.loadPeople() }
        .onChange(of: tab) { if $0 == "List" { Task { await model.reload() } } }
        .onChange(of: model.filter) { _ in Task { await model.reload() } }
        .task(id: "\(personId)-\(CashFilter.dateString(date))") {
            collectionId = 0
            if model.access.canManageAmountTaken { await model.loadLinkedCollections(personId: personId, date: date) }
        }
        .confirmationDialog("Record \(cashMoney(Int(amount) ?? 0))?", isPresented: $confirmAdd, titleVisibility: .visible) {
            Button("Confirm") {
                Task {
                    if await model.addTaken(personId: personId, amount: amount, reason: reason, remark: remark, date: date, collectionId: collectionId > 0 ? collectionId : nil) {
                        amount = ""; reason = ""; remark = ""; personId = 0; collectionId = 0; tab = "List"
                    }
                }
            }
        }
        .confirmationDialog("Review amount taken", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }), titleVisibility: .visible) {
            if let record = selected {
                Button("Approve") { update(record, approve: true) }
                Button("Reject", role: .destructive) { update(record, approve: false) }
            }
        }
        .sheet(item: $detailRecord) { record in
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount taken").foregroundStyle(CashStyle.muted)
                        Text("−\(cashMoney(record.amount))").font(.largeTitle.bold()).foregroundStyle(.red)
                    }
                    Spacer()
                    Text(record.status.capitalized).foregroundStyle(CashStyle.green)
                        .padding(8).background(CashStyle.pale, in: Capsule())
                }
                detailLine("From", record.name)
                detailLine("Taken by", record.takenBy)
                detailLine("Reason", record.reason)
                detailLine("When", record.date)
                detailLine("Reference", "#\(record.id)")
                Spacer()
                Button("Close") { detailRecord = nil }
                    .font(.headline).frame(maxWidth: .infinity).padding(16)
                    .foregroundStyle(CashStyle.green).background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 12))
            }.padding(20).presentationDetents([.medium, .large])
        }
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(CashStyle.muted)
            Spacer()
            Text(value.isEmpty ? "—" : value).multilineTextAlignment(.trailing)
        }
    }

    private func update(_ record: CashRecord, approve: Bool) {
        Task { if await model.reviewTaken(record, approve: approve) { await model.reload() } }
    }
}

struct CashLedgerScreen: View {
    var onHome: () -> Void
    @StateObject private var model = CashCollectionViewModel(kind: .ledger)
    @StateObject private var takenModel = CashCollectionViewModel(kind: .taken)
    @State private var selectedTaken: CashRecord?
    private var entries: [LedgerDisplayEntry] {
        (model.records.filter { $0.status == "approved" || $0.status.isEmpty }.map { LedgerDisplayEntry(record: $0, isTaken: false) }
         + takenModel.records.filter { $0.status == "approved" }.map { LedgerDisplayEntry(record: $0, isTaken: true) })
            .sorted { $0.record.date > $1.record.date }
    }
    var body: some View {
        CashPage(title: "Ledger", onHome: onHome, onRefresh: { Task { await model.reload(); await takenModel.reload() } }) {
            if model.access.canViewLedger {
                CashFilterView(filter: $model.filter, people: model.people, showsStaff: true)
                CashFeedback(model: model)
                if let error = model.peopleError { CashRetry(message: error) { Task { await model.loadPeople() } } }
                if let summary = model.summary {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("COLLECTED CASH").font(.caption.weight(.semibold))
                        Text(cashMoney(summary.amount)).font(.largeTitle.bold())
                        Text(model.filter.period == .all ? "All time" : model.filter.period.rawValue)
                            .font(.subheadline.weight(.medium))
                        HStack(spacing: 7) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Collected").font(.caption)
                                Text(cashMoney(summary.amount)).font(.headline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Taken shown").font(.caption)
                                Text(cashMoney(takenModel.records.filter { $0.status == "approved" }.reduce(0) { $0 + $1.amount })).font(.headline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Entries shown").font(.caption)
                                Text("\(entries.count)").font(.headline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(14).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }.foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 18))
                } else if let error = model.summaryError {
                    CashRetry(message: "Totals unavailable: \(error)") { Task { await model.loadSummary() } }
                }
                if model.isLoading { ProgressView() }
                if entries.isEmpty && !model.isLoading && !takenModel.isLoading { Text("No ledger entries for this period.").foregroundStyle(.secondary) }
                ForEach(Array(Set(entries.map { ledgerDayKey($0.record.date) })).sorted(by: >), id: \.self) { day in
                    let dayEntries = entries.filter { ledgerDayKey($0.record.date) == day }
                    let collected = dayEntries.filter { !$0.isTaken }.reduce(0) { $0 + $1.record.amount }
                    let taken = dayEntries.filter(\.isTaken).reduce(0) { $0 + $1.record.amount }
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ledgerDayTitle(day)).font(.headline)
                            HStack(spacing: 4) {
                                Text("+\(cashMoney(collected))")
                                Text(" · ")
                                Text("−\(cashMoney(taken))")
                            }.font(.subheadline).foregroundStyle(CashStyle.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(model.hasMore || takenModel.hasMore ? "Shown net" : "Net").font(.caption).foregroundStyle(CashStyle.muted)
                            Text(cashMoney(collected - taken)).foregroundStyle(collected >= taken ? CashStyle.green : .red)
                        }
                    }.padding(.top, 12)
                    ForEach(dayEntries) { entry in
                        HStack(spacing: 8) {
                            VStack(spacing: 0) {
                                Rectangle().fill(CashStyle.border).frame(width: 2, height: 20)
                                Circle().fill(entry.isTaken ? Color.red : CashStyle.green).frame(width: 9, height: 9)
                                Rectangle().fill(CashStyle.border).frame(width: 2).frame(maxHeight: .infinity)
                            }.frame(width: 16)
                            if entry.isTaken {
                                Button { selectedTaken = entry.record } label: { LedgerEntryCard(entry: entry) }.buttonStyle(.plain)
                            } else {
                                NavigationLink { CashCollectionDetailScreen(id: entry.record.id, onHome: onHome) } label: { LedgerEntryCard(entry: entry) }.buttonStyle(.plain)
                            }
                        }.frame(minHeight: 82)
                    }
                }
                CashLoadMore(model: model)
                CashLoadMore(model: takenModel)
            } else { Text("You don't have access to this.") }
        }
        .task { await model.loadPeople(); takenModel.filter = model.filter; await model.reload(); await takenModel.reload() }
        .onChange(of: model.filter) { value in
            takenModel.filter = value
            Task { await model.reload(); await takenModel.reload() }
        }
        .sheet(item: $selectedTaken) { record in CashTakenDetailSheet(record: record) }
    }
}

private struct LedgerDisplayEntry: Identifiable {
    let record: CashRecord
    let isTaken: Bool
    var id: String { "\(isTaken ? "taken" : "collection")-\(record.id)" }
}

private struct LedgerEntryCard: View {
    let entry: LedgerDisplayEntry
    private var record: CashRecord { entry.record }
    var body: some View {
        HStack(spacing: 10) {
            Text(entry.isTaken ? "−" : String(record.name.split(separator: " ").prefix(2).compactMap(\.first)).uppercased())
                .font(.caption.weight(.semibold)).foregroundStyle(entry.isTaken ? .red : CashStyle.green)
                .frame(width: 38, height: 38).background(entry.isTaken ? Color.red.opacity(0.1) : CashStyle.pale, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(record.name.isEmpty ? "—" : record.name).font(.subheadline.weight(.medium)).foregroundStyle(CashStyle.ink).lineLimit(1)
                Text("\(record.submittedAt.contains(",") ? String(record.submittedAt.split(separator: ",").last ?? "").trimmingCharacters(in: .whitespaces) + " · " : "")\(entry.isTaken ? record.reason : "Collection #\(record.id)")")
                    .font(.caption).foregroundStyle(CashStyle.muted).lineLimit(1)
                if entry.isTaken && !record.takenBy.isEmpty { Text("Taken by \(record.takenBy)").font(.caption).foregroundStyle(CashStyle.muted) }
                if !record.remark.isEmpty { Text("“\(record.remark)”").font(.caption.italic()).foregroundStyle(CashStyle.muted).lineLimit(1) }
            }
            Spacer(minLength: 4)
            Text("\(entry.isTaken ? "−" : "+")\(cashMoney(record.amount))")
                .font(.subheadline.weight(.semibold)).foregroundStyle(entry.isTaken ? .red : CashStyle.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(CashStyle.muted)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(CashStyle.border))
    }
}

private func ledgerDayTitle(_ day: String) -> String {
    if day == CashFilter.dateString(Date()) { return "Today" }
    if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()), day == CashFilter.dateString(yesterday) { return "Yesterday" }
    return day
}

private func ledgerDayKey(_ raw: String) -> String {
    if raw.count >= 10, raw.dropFirst(4).first == "-" { return String(raw.prefix(10)) }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    for format in ["d MMM yyyy, h:mm a", "dd MMM yyyy, hh:mm a", "d MMM yyyy"] {
        formatter.dateFormat = format
        if let date = formatter.date(from: raw) { return CashFilter.dateString(date) }
    }
    return raw
}

private struct CashTakenDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: CashRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "minus").foregroundStyle(.red)
                    .frame(width: 48, height: 48).background(Color.red.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("Amount taken").font(.subheadline).foregroundStyle(CashStyle.muted)
                    Text("−\(cashMoney(record.amount))").font(.largeTitle.bold()).foregroundStyle(.red)
                }
                Spacer()
                Text(record.status.capitalized).font(.caption).foregroundStyle(CashStyle.green)
                    .padding(8).background(CashStyle.pale, in: Capsule())
            }
            VStack(spacing: 16) {
                row("From", record.name)
                row("Taken by", record.takenBy)
                row("Reason", record.reason)
                row("When", record.date)
                row("Reference", "#\(record.id)")
            }.padding(16).background(Color(red: 0.98, green: 0.99, blue: 0.98), in: RoundedRectangle(cornerRadius: 14))
            Button("Close") { dismiss() }.font(.headline).foregroundStyle(CashStyle.green)
                .frame(maxWidth: .infinity).padding(14).background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 12))
        }.padding(20).presentationDetents([.height(390), .medium])
    }
    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).foregroundStyle(CashStyle.muted)
            Spacer()
            Text(value.isEmpty ? "—" : value).multilineTextAlignment(.trailing)
        }.font(.subheadline)
    }
}

private struct CashRecordList: View {
    @ObservedObject var model: CashCollectionViewModel
    var onHome: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            if model.isLoading { ProgressView() }
            if model.records.isEmpty && !model.isLoading { Text("No collections for this period.").foregroundStyle(.secondary) }
            ForEach(model.records) { record in
                NavigationLink { CashCollectionDetailScreen(id: record.id, onHome: onHome) } label: {
                    CashRecordCard(record: record)
                }.buttonStyle(.plain)
            }
            CashLoadMore(model: model)
        }
        .onAppear { Task { await model.reload() } }
    }
}

private struct CashLoadMore: View {
    @ObservedObject var model: CashCollectionViewModel
    var body: some View {
        if model.hasMore {
            Button("Load More (\(model.records.count) of \(model.totalRecords))") { Task { await model.load(more: true) } }
                .disabled(model.isLoading)
        }
    }
}

private struct CashRecordCard: View {
    let record: CashRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(cashMoney(record.amount)).font(.title3.bold())
                Spacer()
                Text(record.status.capitalized).font(.caption.bold())
                    .foregroundStyle(record.status == "approved" ? .green : record.status == "rejected" ? .red : .orange)
                    .padding(6).background(.thinMaterial).clipShape(Capsule())
            }
            Text(record.name.isEmpty ? "Collection #\(record.id)" : record.name).font(.headline)
            Text("#\(record.id) · \(record.date)").font(.caption).foregroundStyle(.secondary)
            if !record.reason.isEmpty { Text(record.reason).font(.subheadline) }
            if !record.remark.isEmpty { Text("Remark: \(record.remark)").font(.subheadline) }
            if !record.reviewedBy.isEmpty { Text("Reviewed by \(record.reviewedBy)").font(.caption).foregroundStyle(.secondary) }
            if !record.takenBy.isEmpty { Text("Recorded by \(record.takenBy)").font(.caption).foregroundStyle(.secondary) }
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct CashDenominationForm: View {
    @Binding var form: CashCountForm
    var body: some View {
        VStack(spacing: 12) {
            CashCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Total cash amount", systemImage: "indianrupeesign.circle.fill")
                        .font(.headline).foregroundStyle(CashStyle.ink)
                    Text("The cash you are handing over").font(.subheadline).foregroundStyle(CashStyle.muted)
                    HStack(spacing: 8) {
                        Text("₹").font(.title2.weight(.semibold))
                        TextField("0", text: $form.declared).keyboardType(.numberPad).font(.title2.weight(.semibold))
                            .accessibilityLabel("Total cash amount")
                    }.padding(14).overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.green, lineWidth: 1))
                    if let declared = Int(form.declared), declared > 0 {
                        Text("\(declared) rupees").font(.caption).foregroundStyle(CashStyle.muted)
                    }
                }
            }
            discrepancy
            CashDenominationSection(kind: "note", form: $form)
            CashDenominationSection(kind: "coin", form: $form)
            CashCard {
                HStack(alignment: .bottom) {
                    TextField("Remark (optional)", text: $form.remark, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    SpeechRemarkButton(text: $form.remark)
                }
            }
        }
    }

    @ViewBuilder private var discrepancy: some View {
        let declared = Int(form.declared) ?? 0
        let counted = form.total ?? 0
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: declared == 0 ? "indianrupeesign" : declared == counted ? "checkmark.circle" : "exclamationmark.triangle")
                Text(declared == 0 ? "Enter the total, then count each note and coin" : declared == counted ? "Count matches" : counted < declared ? "Short by \(cashMoney(declared - counted))" : "Over by \(cashMoney(counted - declared))")
                    .fontWeight(.medium)
            }
            HStack {
                Text("Counted \(cashMoney(counted))")
                Spacer()
                Text("\(form.counts.filter { $0.key.hasPrefix("note_") }.values.compactMap(Int.init).reduce(0,+)) notes · \(form.counts.filter { $0.key.hasPrefix("coin_") }.values.compactMap(Int.init).reduce(0,+)) coins")
            }.font(.subheadline)
        }
        .foregroundStyle(declared == 0 ? CashStyle.ink : declared == counted ? CashStyle.green : Color(red: 0.52, green: 0.25, blue: 0.10))
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(declared == 0 ? Color.white : declared == counted ? CashStyle.pale : Color(red: 0.99, green: 0.94, blue: 0.71), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct CashDenominationSection: View {
    let kind: String
    @Binding var form: CashCountForm
    var body: some View {
        CashCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(kind == "note" ? "Notes" : "Coins", systemImage: kind == "note" ? "banknote" : "circle.circle")
                    .font(.headline).foregroundStyle(CashStyle.ink)
                if kind == "note" { Text("Tap a count to type it").font(.caption).foregroundStyle(CashStyle.muted) }
                HStack {
                    Text("Currency"); Spacer(); Text("Quantity"); Spacer(); Text("Total")
                }.font(.caption).foregroundStyle(CashStyle.muted)
                ForEach(CashDenomination.all.filter { $0.kind == kind }) { denomination in
                    CashDenominationRow(denomination: denomination, count: Binding(
                        get: { form.counts[denomination.id, default: ""] },
                        set: { form.counts[denomination.id] = $0 }
                    ))
                }
            }
        }
    }
}

private struct CashDenominationRow: View {
    let denomination: CashDenomination
    @Binding var count: String
    private var tint: Color {
        if denomination.kind == "coin" { return denomination.value >= 5 ? Color(red: 0.79, green: 0.64, blue: 0.23) : .gray }
        switch denomination.value {
        case 500: return Color(red: 0.55, green: 0.54, blue: 0.48)
        case 200: return .orange
        case 100: return .purple
        case 50: return .cyan
        case 20: return .green
        case 10: return .brown
        default: return CashStyle.green
        }
    }
    var body: some View {
        let lineTotal = denomination.value.multipliedReportingOverflow(by: Int(count) ?? 0)
        HStack(spacing: 8) {
            Text("₹\(denomination.value)")
                .font(.subheadline.weight(.medium)).frame(width: 60, height: 35)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: denomination.kind == "coin" ? 18 : 6))
                .overlay(RoundedRectangle(cornerRadius: denomination.kind == "coin" ? 18 : 6).stroke(tint.opacity(0.55)))
            HStack(spacing: 0) {
                Button { count = String(max(0, (Int(count) ?? 0) - 1)) } label: { Image(systemName: "minus").frame(width: 35, height: 38) }
                TextField("0", text: $count).keyboardType(.numberPad).multilineTextAlignment(.center)
                    .accessibilityLabel("\(denomination.label) quantity")
                Button { count = String((Int(count) ?? 0) + 1) } label: { Image(systemName: "plus").frame(width: 35, height: 38) }
            }.foregroundStyle(CashStyle.green)
                .background(Color(red: 0.96, green: 0.97, blue: 0.97), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(CashStyle.border))
            Text(lineTotal.overflow ? "—" : cashMoney(lineTotal.partialValue))
                .font(.subheadline).foregroundStyle(CashStyle.muted)
                .frame(width: 67, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.75)
        }.buttonStyle(.plain)
    }
}

private struct CashSubmitFooter: View {
    let form: CashCountForm
    let isSaving: Bool
    let onClear: () -> Void
    let onSubmit: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Capsule().fill(CashStyle.border).frame(width: 34, height: 4)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Counted\(form.declared.isEmpty ? "" : " of \(cashMoney(Int(form.declared) ?? 0))")")
                        .font(.caption).foregroundStyle(CashStyle.muted)
                    Text(cashMoney(form.total ?? 0)).font(.title3.weight(.semibold))
                }
                Spacer()
                if let total = form.total, let declared = Int(form.declared), declared != total {
                    Text(total < declared ? "Short \(cashMoney(declared - total))" : "Over \(cashMoney(total - declared))")
                        .font(.caption.weight(.medium)).foregroundStyle(.brown)
                        .padding(8).background(Color(red: 0.99, green: 0.94, blue: 0.71), in: Capsule())
                }
            }
            HStack(spacing: 10) {
                Button(action: onClear) { Label("Clear", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity).frame(height: 50) }
                    .foregroundStyle(CashStyle.green).background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 14))
                Button(action: onSubmit) { Label("Submit", systemImage: "paperplane.fill").frame(maxWidth: .infinity).frame(height: 50) }
                    .foregroundStyle(.white).background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .disabled(!form.isBalanced || isSaving).opacity(form.isBalanced && !isSaving ? 1 : 0.55)
            }.font(.headline).buttonStyle(.plain)
        }.padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 8)
            .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
            .overlay(alignment: .top) { CashStyle.border.frame(height: 1) }
    }
}

private struct CashSummaryView: View {
    @ObservedObject var model: CashCollectionViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = model.summaryError {
                CashRetry(message: error) { Task { await model.loadSummary() } }
            } else if let summary = model.summary {
                CashTotals(summary: summary)
                CashDenominationLines(lines: summary.denominations)
                ForEach(summary.staff) { staff in
                    DisclosureGroup {
                        CashDenominationLines(lines: staff.denominations)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(staff.name).font(.headline)
                            Text("\(staff.entries) entries · \(cashMoney(staff.amount))").font(.subheadline)
                        }
                    }.padding(14).background(.white).clipShape(RoundedRectangle(cornerRadius: 14))
                }
                if summary.entries == 0 { Text("No approved collections for this period.").foregroundStyle(.secondary) }
            } else { ProgressView("Loading summary…") }
        }
    }
}

private struct CashTotals: View {
    let summary: CashSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Approved cash").font(.subheadline)
            Text(cashMoney(summary.amount)).font(.largeTitle.bold())
            Text("\(summary.entries) entries · \(summary.staff.count) staff").font(.subheadline)
        }.foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.ctaGradient).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct CashDenominationLines: View {
    let lines: [CashLine]
    var body: some View {
        CashCard {
        VStack(spacing: 12) {
            Label("Denomination details", systemImage: "banknote").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            HStack { Text("Currency"); Spacer(); Text("Quantity"); Spacer(); Text("Total") }
                .font(.caption).foregroundStyle(CashStyle.muted)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack {
                    Text(line.label)
                    Spacer()
                    Text("\(line.quantity)").foregroundStyle(.secondary)
                    Text(cashMoney(line.total)).fontWeight(.semibold)
                }.font(.subheadline)
            }
            Divider()
            HStack { Text("Total"); Spacer(); Text(cashMoney(lines.reduce(0) { $0 + $1.total })).foregroundStyle(CashStyle.green) }.font(.headline)
        }
        }
    }
}

private struct CashFilterView: View {
    @Binding var filter: CashFilter
    let people: [OrderInsightsStaffMember]
    var showsStaff = false
    var showsStatus = false
    @State private var search = ""
    @State private var showingStaff = false
    @State private var showingRange = false
    @State private var draftStaffIds: Set<Int> = []
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(CashPeriod.allCases, id: \.self) { period in
                    Button {
                        filter.period = period
                        if period == .range { showingRange = true }
                    } label: {
                        Text(period.rawValue).font(.subheadline.weight(filter.period == period ? .semibold : .regular))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(filter.period == period ? .white : CashStyle.muted)
                            .background { if filter.period == period { RoundedRectangle(cornerRadius: 10).fill(CashStyle.gradient) } }
                    }.buttonStyle(.plain)
                }
            }
            if filter.period == .range {
                Button { showingRange = true } label: {
                    Label("\(filter.from.formatted(date: .abbreviated, time: .omitted))  →  \(filter.to.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
                        .frame(maxWidth: .infinity).padding(12)
                }.buttonStyle(.plain).background(.white, in: RoundedRectangle(cornerRadius: 12))
                if !filter.isValid { Text("Start date must be on or before end date.").font(.caption).foregroundStyle(.red) }
            }
            if filter.period == .month {
                HStack {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous month")
                    Spacer()
                    Label(filter.month.formatted(.dateTime.month(.wide).year()), systemImage: "calendar")
                    Spacer()
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next month")
                }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.border))
            }
            if showsStaff {
                Button {
                    draftStaffIds = filter.staffIds
                    showingStaff = true
                } label: {
                    HStack {
                        Label("Staff: \(filter.staffIds.isEmpty ? "All staff" : "\(filter.staffIds.count) selected")", systemImage: "person.3.fill")
                        Spacer()
                        Text("Choose").foregroundStyle(CashStyle.green)
                    }.font(.subheadline).padding(14)
                }.buttonStyle(.plain).background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.border))
            }
            if showsStatus {
                HStack(spacing: 6) {
                    ForEach(["", "pending", "approved", "rejected"], id: \.self) { status in
                        Button { filter.status = status } label: {
                            Text(status.isEmpty ? "All" : status.capitalized).font(.caption)
                                .padding(.horizontal, 11).padding(.vertical, 8)
                                .foregroundStyle(filter.status == status ? CashStyle.green : CashStyle.ink)
                                .background(filter.status == status ? CashStyle.pale : .white, in: Capsule())
                                .overlay(Capsule().stroke(filter.status == status ? CashStyle.green : CashStyle.border))
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showingStaff) {
            VStack(alignment: .leading, spacing: 14) {
                Capsule().fill(CashStyle.border).frame(width: 36, height: 4).frame(maxWidth: .infinity).padding(.top, 8)
                Text("Filter by staff").font(.title3.weight(.semibold))
                Text(draftStaffIds.isEmpty ? "Everyone is included" : "\(draftStaffIds.count) selected")
                    .font(.subheadline).foregroundStyle(CashStyle.muted)
                TextField("Search by name or role", text: $search).textFieldStyle(.roundedBorder)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(people.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { person in
                            Button {
                                if draftStaffIds.contains(person.id) { draftStaffIds.remove(person.id) }
                                else { draftStaffIds.insert(person.id) }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: draftStaffIds.contains(person.id) ? "checkmark.square.fill" : "square")
                                        .font(.title3).foregroundStyle(draftStaffIds.contains(person.id) ? CashStyle.green : CashStyle.muted)
                                    Text(person.name).foregroundStyle(CashStyle.ink)
                                    Spacer()
                                }.frame(maxWidth: .infinity, minHeight: 44)
                            }.buttonStyle(.plain)
                                .accessibilityLabel(person.name)
                                .accessibilityAddTraits(draftStaffIds.contains(person.id) ? [.isSelected] : [])
                        }
                    }
                }
                Button(draftStaffIds.isEmpty ? "Show all staff" : "Show selected staff") {
                    filter.staffIds = draftStaffIds
                    showingStaff = false
                }.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(16)
                    .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 13))
            }.padding(18).presentationDetents([.large])
        }
        .sheet(isPresented: $showingRange) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose a date range").font(.headline)
                DatePicker("From", selection: $filter.from, displayedComponents: .date)
                DatePicker("To", selection: $filter.to, displayedComponents: .date)
                Spacer()
                Button("Show") { showingRange = false }.disabled(!filter.isValid)
                    .frame(maxWidth: .infinity).padding(14)
                    .foregroundStyle(.white).background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 12))
            }.padding(18).presentationDetents([.medium])
        }
    }
    private func moveMonth(_ offset: Int) {
        filter.month = Calendar.current.date(byAdding: .month, value: offset, to: filter.month) ?? filter.month
    }
}

private struct CashFeedback: View {
    @ObservedObject var model: CashCollectionViewModel
    var body: some View {
        if model.isSaving { ProgressView("Saving…") }
        if let error = model.error { Text(error).foregroundStyle(.red).font(.subheadline) }
        if let message = model.message, !message.isEmpty { Text(message).foregroundStyle(.green).font(.subheadline) }
    }
}

private struct CashRetry: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message).font(.subheadline).foregroundStyle(.red)
            Button("Retry", action: retry)
        }
    }
}

struct CashPage<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var onHome: () -> Void
    var onRefresh: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: { Image(systemName: "arrow.left") }.accessibilityLabel("Back")
                Text(title).font(.title3.weight(.semibold))
                Spacer()
                if let onRefresh { Button(action: onRefresh) { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh") }
                Button(action: onHome) { Image(systemName: "house.fill") }.accessibilityLabel("Home")
            }
            .font(.title3).foregroundStyle(.white).padding(.horizontal, 16).padding(.vertical, 18)
            .background(CashStyle.gradient, in: UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18))
            .background(CashStyle.gradient.ignoresSafeArea(edges: .top))
            ScrollView {
                VStack(alignment: .leading, spacing: 14, content: content)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
        }
        .background(Color(red: 247/255, green: 249/255, blue: 248/255))
        .tint(CashStyle.green)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private func cashMoney(_ amount: Int) -> String {
    amount.formatted(.currency(code: "INR").precision(.fractionLength(0)).locale(Locale(identifier: "en_IN")))
}

struct SpeechRemarkButton: View {
    @Binding var text: String
    @StateObject private var recognizer = RemarkSpeechRecognizer()
    @State private var showingError = false

    var body: some View {
        Button {
            if recognizer.isRecording { recognizer.stop() }
            else { recognizer.start(existingText: text) { text = $0 } }
        } label: {
            Image(systemName: recognizer.isRecording ? "stop.circle.fill" : "mic.fill")
                .foregroundStyle(recognizer.isRecording ? .red : CashStyle.green)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recognizer.isRecording ? "Stop voice input" : "Dictate remark")
        .onChange(of: recognizer.error) { _, value in showingError = value != nil }
        .onDisappear { recognizer.stop() }
        .alert("Voice input", isPresented: $showingError) {
            Button("OK") { recognizer.error = nil }
        } message: {
            Text(recognizer.error ?? "Speech recognition is unavailable.")
        }
    }
}

@MainActor
private final class RemarkSpeechRecognizer: ObservableObject {
    @Published var isRecording = false
    @Published var error: String?
    private var engine: AVAudioEngine?
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognizer: SFSpeechRecognizer?

    func start(existingText: String, onText: @escaping (String) -> Void) {
        guard !isRecording else { return }
        error = nil
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                Task { @MainActor in self?.error = "Allow Speech Recognition in Settings to dictate a remark." }
                return
            }
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else {
                    Task { @MainActor in self?.error = "Allow microphone access in Settings to dictate a remark." }
                    return
                }
                Task { @MainActor in self?.begin(existingText: existingText, onText: onText) }
            }
        }
    }

    private func begin(existingText: String, onText: @escaping (String) -> Void) {
        guard let speech = SFSpeechRecognizer(locale: Locale.current), speech.isAvailable else {
            error = "Speech recognition is unavailable right now."
            return
        }
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            let audioEngine = AVAudioEngine()
            let speechRequest = SFSpeechAudioBufferRecognitionRequest()
            speechRequest.shouldReportPartialResults = true
            let input = audioEngine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                speechRequest.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            recognizer = speech
            request = speechRequest
            engine = audioEngine
            isRecording = true
            let prefix = existingText.trimmingCharacters(in: .whitespacesAndNewlines)
            task = speech.recognitionTask(with: speechRequest) { [weak self] result, failure in
                guard let transcript = result?.bestTranscription.formattedString else { return }
                let value = prefix.isEmpty ? transcript : "\(prefix) \(transcript)"
                Task { @MainActor in
                    onText(value)
                    if result?.isFinal == true || failure != nil { self?.stop() }
                }
            }
        } catch {
            stop()
            self.error = "Could not start voice input: \(error.localizedDescription)"
        }
    }

    func stop() {
        if engine?.isRunning == true { engine?.stop() }
        engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        engine = nil
        request = nil
    }
}
