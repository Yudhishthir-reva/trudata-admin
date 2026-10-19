import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PaymentAdvanceScreen: View {
    var onHome: () -> Void
    @StateObject private var model = PaymentAdvanceViewModel()
    @State private var giving = false
    @State private var choosingStaff = false
    @State private var receivingRecord: PaymentAdvanceRecord?
    @State private var statusRecord: PaymentAdvanceRecord?
    @State private var rowStatus: AdvanceStatus?

    var body: some View {
        AdvancePage(title: model.access.canManage ? "Payment Advance" : "My Payment Advance", onHome: onHome) {
            CashTabs(titles: recordTabs.map { $0.title }, selection: Binding(
                get: { recordTabs.first { $0.value == model.filter.type }?.title ?? "All" },
                set: { title in
                    if let tab = recordTabs.first(where: { $0.title == title }) {
                        model.filter.type = tab.value
                    }
                }
            ))
            if model.access.canManage {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search by name, purpose, remark", text: $model.filter.search)
                }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12))
                // Android shows role and status as scrolling chip rows, not dropdowns, so the
                // active filter is visible without opening anything.
                advanceChipRow(
                    options: [(id: "0", title: "All roles")] + model.roles.map { (id: "\($0.id)", title: $0.name) },
                    selection: "\(model.filter.roleID)"
                ) { model.filter.roleID = Int($0) ?? 0 }
                // A returned record has no repayment status, so Android hides the row outright
                // instead of leaving a dead control on screen.
                if model.filter.type != "returned" {
                    advanceChipRow(
                        options: [(id: "", title: "Any status")] + AdvanceStatus.allCases.map { (id: $0.rawValue, title: $0.title) },
                        selection: model.filter.status
                    ) { model.filter.status = $0 }
                }
                Button { choosingStaff = true } label: {
                    HStack {
                        Label("Staff: \(model.filter.staffIDs.isEmpty ? "All staff" : "\(model.filter.staffIDs.count) selected")", systemImage: "person.3.fill")
                        Spacer()
                        Text("Choose").foregroundStyle(AppTheme.cerulean)
                    }.font(.subheadline).padding(13)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.gainsboro))
                }.buttonStyle(.plain)
                if let error = model.optionsError {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button("Retry staff and roles") { Task { await model.loadOptions() } }
                }
            }
            AdvanceCard {
                Toggle("Filter by date", isOn: $model.filter.usesDates)
                if model.filter.usesDates {
                    DatePicker("From", selection: $model.filter.from, displayedComponents: .date)
                    DatePicker("To", selection: $model.filter.to, displayedComponents: .date)
                }
            }
            summaryHero
            if let error = model.error {
                Text(error).foregroundStyle(.red)
                Button("Retry") { Task { await model.load() } }
            }
            if model.records.isEmpty && !model.loading && model.error == nil {
                // Android separates "your filters matched nothing" from "there is nothing yet",
                // and only offers the Give Advance hint to someone who can actually give one.
                let periodSuffix = model.filter.usesDates
                    ? " between \(model.filter.from.formatted(date: .abbreviated, time: .omitted)) and \(model.filter.to.formatted(date: .abbreviated, time: .omitted))"
                    : ""
                let hasFilters = !model.filter.search.trimmingCharacters(in: .whitespaces).isEmpty
                    || !model.filter.status.isEmpty
                    || model.filter.roleID != 0
                    || !model.filter.staffIDs.isEmpty
                let emptyMessage: String = {
                    if !model.access.canManage { return "No advance was given to you\(periodSuffix)." }
                    if hasFilters { return "No records match these filters." }
                    return "No advance was given\(periodSuffix). Tap Give Advance to add one."
                }()
                ContentUnavailableView("Nothing here", systemImage: "banknote", description: Text(emptyMessage))
            }
            ForEach(model.records) { record in
                NavigationLink {
                    PaymentAdvanceDetailScreen(id: record.advanceID, onHome: onHome)
                } label: { AdvanceRecordCard(record: record) }
                .buttonStyle(.plain)
                // Android `AdvanceRowMenu`: receive a payment or change a status straight from
                // the row, without opening the record first. Tapping the row still opens it.
                .contextMenu {
                    if model.access.canManage && !record.isReturn {
                        if AdvanceStatus.isOpen(record.status) && record.outstanding > 0 {
                            Button { receivingRecord = record } label: {
                                Label("Receive payment", systemImage: "arrow.down.circle")
                            }
                        }
                        Button { rowStatus = AdvanceStatus(rawValue: record.status) ?? .pending; statusRecord = record } label: {
                            Label("Change status", systemImage: "clock")
                        }
                    }
                }
            }
            if model.loading { ProgressView().frame(maxWidth: .infinity) }
            if model.hasMore && !model.loading {
                Button("Load more") { Task { await model.load(more: true) } }.frame(maxWidth: .infinity)
            }
        }
        .sheet(item: $receivingRecord, onDismiss: { Task { await model.load() } }) { record in
            PaymentAdvanceFormScreen(advance: record)
        }
        .sheet(item: $statusRecord) { record in
            AdvanceStatusSheet(current: record.status, selection: $rowStatus, saving: model.saving) {
                guard let status = rowStatus else { return }
                Task { await model.updateStatus(status, for: record.advanceID); statusRecord = nil }
            }
            .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
        .task(id: model.filter) {
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            await model.load()
        }
        .task { await model.loadOptions() }
        .refreshable { await model.load() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.access.canManage {
                Button { giving = true } label: {
                    Label("Give Advance", systemImage: "plus.circle.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.regularMaterial)
            }
        }
        .sheet(isPresented: $giving, onDismiss: { Task { await model.load() } }) {
            PaymentAdvanceFormScreen(advance: nil)
        }
        .sheet(isPresented: $choosingStaff) {
            AdvanceStaffFilterSheet(people: model.people, selectedIDs: $model.filter.staffIDs)
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
    }

    private func advanceChipRow(
        options: [(id: String, title: String)],
        selection: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options, id: \.id) { option in
                    let isSelected = option.id == selection
                    Button { onSelect(option.id) } label: {
                        Text(option.title).font(.caption)
                            .padding(.horizontal, 11).padding(.vertical, 8)
                            .foregroundStyle(isSelected ? AppTheme.cerulean : AppTheme.textPrimary)
                            .background(isSelected ? AppTheme.cerulean.opacity(0.12) : .white, in: Capsule())
                            .overlay(Capsule().stroke(isSelected ? AppTheme.cerulean : AppTheme.gainsboro))
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 2)
        }
    }

    private var recordTabs: [(value: String, title: String)] {
        [("all", "All"),
         ("advance", model.access.canManage ? "Advance Given" : "Advance"),
         ("returned", model.access.canManage ? "Received" : "Returned")]
    }

    private var summary: some View {
        let items: [(String, String)] = model.access.canManage
            ? [("Advance Given", "advance_given"), ("Payment Received", "payment_received"), ("Pending Return", "pending_return")]
            : [("Advance Received", "advance_received"), ("Returned", "returned")]
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(items, id: \.1) { item in summaryItem(item) }
            }
            VStack(spacing: 8) {
                ForEach(items, id: \.1) { item in summaryItem(item) }
            }
        }
    }

    private func summaryItem(_ item: (String, String)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.0).font(.caption).fixedSize(horizontal: false, vertical: true)
            Text(model.summary[item.1].map(advanceMoney) ?? "—").font(.headline).fixedSize()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .foregroundStyle(AppTheme.darkMidnightBlue)
            .background(AppTheme.brandContainer, in: RoundedRectangle(cornerRadius: 12))
    }

    private var summaryHero: some View {
        let given = model.summary["advance_given"] ?? 0
        let received = model.summary["payment_received"] ?? 0
        let pending = model.summary["pending_return"] ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Text(model.access.canManage ? "PENDING RETURN" : "ADVANCE RECEIVED")
                .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
            Text(advanceMoney(model.access.canManage ? pending : (model.summary["advance_received"] ?? 0)))
                .font(.largeTitle.bold()).foregroundStyle(.white)
            HStack(spacing: 10) {
                heroMetric(model.access.canManage ? "Advance given" : "Returned", model.access.canManage ? given : received)
                if model.access.canManage { heroMetric("Payment received", received) }
            }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.ctaGradient, in: RoundedRectangle(cornerRadius: 20))
    }

    private func heroMetric(_ title: String, _ amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.8))
            Text(advanceMoney(amount)).font(.headline.bold()).foregroundStyle(.white)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct AdvanceStaffFilterSheet: View {
    let people: [OrderInsightsStaffMember]
    @Binding var selectedIDs: Set<Int>
    @Environment(\.dismiss) private var dismiss
    @State private var draftIDs: Set<Int> = []
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Filter by staff").font(.title3.weight(.semibold))
            Text(draftIDs.isEmpty ? "Everyone is included" : "\(draftIDs.count) selected")
                .font(.subheadline).foregroundStyle(.secondary)
            TextField("Search by name", text: $search).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(people.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { person in
                        Button {
                            if draftIDs.contains(person.id) { draftIDs.remove(person.id) }
                            else { draftIDs.insert(person.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: draftIDs.contains(person.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(draftIDs.contains(person.id) ? AppTheme.cerulean : AppTheme.slateGray)
                                Text(person.name).foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain)
                    }
                }
            }
            HStack(spacing: 10) {
                Button("Clear") { draftIDs = [] }.buttonStyle(.bordered)
                Button(draftIDs.isEmpty ? "Show all staff" : "Show selected staff") {
                    selectedIDs = draftIDs
                    dismiss()
                }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }
        }.padding(18)
            .onAppear { draftIDs = selectedIDs }
    }
}

private struct PaymentAdvanceDetailScreen: View {
    let id: Int
    var onHome: () -> Void
    @StateObject private var model = PaymentAdvanceViewModel()
    @State private var receiving = false
    @State private var proposedStatus: AdvanceStatus?
    @State private var showingStatus = false

    var body: some View {
        AdvancePage(title: "Advance Details", onHome: onHome) {
            if model.loading { ProgressView().frame(maxWidth: .infinity) }
            if let error = model.error {
                Text(error).foregroundStyle(.red)
                Button("Retry") { Task { await model.loadDetail(id) } }
            }
            if let record = model.detail {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("ADVANCE #\(record.recordID)").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        AdvanceStatusPill(status: record.status)
                    }
                    Text(advanceMoney(record.amount)).font(.largeTitle.bold()).foregroundStyle(.white)
                    Text([record.person, record.role].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.headline).foregroundStyle(.white)
                    // Android shows how much has come back as a bar, not a plain divider.
                    ProgressView(
                        value: NSDecimalNumber(decimal: record.amount - record.outstanding).doubleValue,
                        total: max(NSDecimalNumber(decimal: record.amount).doubleValue, 1)
                    ).tint(.white)
                    HStack {
                        heroMetric("Returned", record.amount - record.outstanding)
                        heroMetric("Outstanding", record.outstanding)
                    }
                }.padding(18).background(AppTheme.ctaGradient, in: RoundedRectangle(cornerRadius: 20))
                AdvanceCard {
                    Label("Details", systemImage: "doc.text").font(.headline)
                    detailLine("Given on", record.date)
                    detailLine("Purpose", record.text.isEmpty ? "—" : record.text)
                    detailLine("Given by", record.author.isEmpty ? "—" : record.author)
                    detailLine("Entered", record.createdAt.isEmpty ? "—" : record.createdAt)
                    if let attachment = record.attachment { Link("View attachment", destination: attachment) }
                }
                AdvanceCard {
                    Label("Payments returned", systemImage: "clock.arrow.circlepath").font(.headline)
                    if record.returns.isEmpty { Text("Nothing returned yet.").foregroundStyle(.secondary) }
                    ForEach(record.returns) { payment in
                        AdvanceRecordCard(record: payment)
                    }
                }
            }
            if model.saving { ProgressView("Saving…") }
        }
        .task { await model.loadDetail(id) }
        .refreshable { await model.loadDetail(id) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let record = model.detail, model.access.canManage {
                HStack(spacing: 10) {
                    // Android's buttons are 52dp tall with a 14dp radius; iOS's bordered styles
                    // default to a taller, much rounder shape, so they are drawn explicitly.
                    let canReceive = record.outstanding > 0 && AdvanceStatus.isOpen(record.status)
                    Button { proposedStatus = AdvanceStatus(rawValue: record.status) ?? .pending; showingStatus = true } label: {
                        Label("Status", systemImage: "clock")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .foregroundStyle(CashStyle.green)
                            .background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.saving)

                    Button { receiving = true } label: {
                        Label("Receive Payment", systemImage: "arrow.down.left")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .foregroundStyle(.white)
                            .background(CashStyle.green, in: RoundedRectangle(cornerRadius: 14))
                            .opacity(canReceive && !model.saving ? 1 : 0.45)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.saving || !canReceive)
                }.padding(.horizontal, 14).padding(.vertical, 8).background(.regularMaterial)
            }
        }
        // AdvancePage tints its own content, but a safeAreaInset is attached outside that scope,
        // so Status and Receive Payment were falling back to the system blue accent.
        .tint(CashStyle.green)
        .sheet(isPresented: $receiving, onDismiss: { Task { await model.loadDetail(id) } }) {
            if let detail = model.detail { PaymentAdvanceFormScreen(advance: detail) }
        }
        .sheet(isPresented: $showingStatus) {
            if let record = model.detail {
                AdvanceStatusSheet(current: record.status, selection: $proposedStatus, saving: model.saving) {
                    guard let status = proposedStatus else { return }
                    Task { await model.updateStatus(status); showingStatus = false }
                }
                .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
        }
    }

    private func heroMetric(_ title: String, _ amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.8))
            Text(advanceMoney(amount)).font(.headline.bold()).foregroundStyle(.white)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).multilineTextAlignment(.trailing) }
            .font(.subheadline)
    }
}

/// The outstanding balance rendered the way the amount field expects it (plain digits, no symbol
/// or grouping), so tapping the chip produces a value that passes validation.
private func advanceOutstandingText(_ amount: Decimal) -> String {
    NSDecimalNumber(decimal: amount).stringValue
}

private struct PaymentAdvanceFormScreen: View {
    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func day(_ raw: String) -> Date? {
        dayParser.date(from: String(raw.prefix(10)))
    }

    private var summaryLabel: String {
        guard let advance else {
            let name = model.people.first { $0.id == form.personID }?.name
            return name.map { "Advance to \($0)" } ?? "Choose a person"
        }
        let entered = PaymentAdvanceForm.amount(form.amount) ?? 0
        let after = max(advance.outstanding - entered, 0)
        return "Outstanding after this: \(advanceMoney(after))"
    }

    let advance: PaymentAdvanceRecord?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PaymentAdvanceViewModel()
    @State private var form = PaymentAdvanceForm()
    @State private var file: MultipartFileUpload?
    @State private var photo: PhotosPickerItem?
    @State private var importing = false
    @State private var attachmentLoading = false
    @State private var attachmentError: String?
    @State private var confirming = false

    var body: some View {
        NavigationStack {
            Form {
                if let advance {
                    Section("Advance #\(advance.recordID)") {
                        LabeledContent("Person", value: advance.person)
                        LabeledContent("Outstanding", value: advanceMoney(advance.outstanding))
                    }
                } else {
                    Section("Select person") {
                        CashDropdown(title: "Person *", placeholder: "Choose a person", options: model.people.map { CashDropdownOption(id: "\($0.id)", title: $0.role.isEmpty ? $0.name : "\($0.name) (\($0.role))", icon: "person.fill") }, selection: Binding(get: { form.personID == 0 ? "" : "\(form.personID)" }, set: { form.personID = Int($0) ?? 0 }))
                        if let error = model.optionsError {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.loadOptions() } }
                        }
                    }
                }
                Section(advance == nil ? "Advance details" : "Payment details") {
                    TextField(advance == nil ? "Advance amount (₹)" : "Receive amount (₹)", text: $form.amount).keyboardType(.numberPad)
                    // Android `FillOutstanding`: settling the whole balance is the common case, so
                    // offer it as one tap instead of retyping the figure shown above.
                    if let advance, advance.outstanding > 0 {
                        let full = advanceOutstandingText(advance.outstanding)
                        Button {
                            form.amount = form.amount == full ? "" : full
                        } label: {
                            Label(
                                "Full \(advanceMoney(advance.outstanding))",
                                systemImage: form.amount == full ? "checkmark.circle.fill" : "circle"
                            )
                            .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                    // Android bounds the receive form at the advance's own date, so a repayment
                    // can't be dated before the money was handed over.
                    if let earliest = advance.flatMap({ Self.day($0.date) }) {
                        DatePicker("Date", selection: $form.date, in: earliest...Date(), displayedComponents: .date)
                    } else {
                        DatePicker("Date", selection: $form.date, in: ...Date(), displayedComponents: .date)
                    }
                    HStack(alignment: .bottom) {
                        TextField(advance == nil ? "e.g. For market visit and expenses" : "e.g. Partial return", text: $form.text, axis: .vertical).lineLimit(3...6)
                        SpeechRemarkButton(text: $form.text).padding(.bottom, 8)
                    }
                    if !form.amount.isEmpty, let validationError {
                        Text(validationError).font(.caption).foregroundStyle(.red)
                    }
                }
                Section("Attachment (optional)") {
                    PhotosPicker(selection: $photo, matching: .images) { Label("Choose photo", systemImage: "photo") }
                    Button { importing = true } label: { Label("Choose bill / document", systemImage: "doc") }
                    if let file {
                        Text(file.fileName).font(.subheadline)
                        Button("Remove attachment", role: .destructive) { self.file = nil; photo = nil }
                    }
                    if attachmentLoading { ProgressView("Loading attachment…") }
                    if let attachmentError { Text(attachmentError).foregroundStyle(.red) }
                }.disabled(attachmentLoading)
                if let error = model.error { Section { Text(error).foregroundStyle(.red) } }
                Section {
                    // Android keeps a running summary above the actions: who it is for, or what
                    // will still be outstanding once this payment lands.
                    HStack {
                        Text(summaryLabel).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(advanceMoney(PaymentAdvanceForm.amount(form.amount) ?? 0))
                            .font(.subheadline.weight(.semibold))
                    }
                    Button { confirming = true } label: {
                        HStack {
                            Spacer()
                            if model.saving { ProgressView() }
                            else { Text(advance == nil ? "Give Advance" : "Receive").fontWeight(.semibold) }
                            Spacer()
                        }
                    }.disabled(!valid || model.saving || attachmentLoading)
                }
            }
            .disabled(model.saving)
            .tint(CashStyle.green)
            .navigationTitle(advance == nil ? "Give Advance" : "Receive Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(model.saving) } }
            .interactiveDismissDisabled(model.saving)
            .task { if advance == nil { await model.loadOptions() } }
            .task(id: photo) {
                guard let selected = photo else { return }
                attachmentLoading = true; attachmentError = nil
                defer { attachmentLoading = false }
                do {
                    guard let data = try await selected.loadTransferable(type: Data.self) else { throw PaymentAdvanceError.message("Couldn't read the photo.") }
                    try Task.checkCancellation()
                    let type = selected.supportedContentTypes.first ?? .jpeg
                    file = MultipartFileUpload(fieldName: "attachment", fileName: "attachment.\(type.preferredFilenameExtension ?? "jpg")", mimeType: type.preferredMIMEType ?? "image/jpeg", data: data)
                } catch { if !Task.isCancelled { attachmentError = error.localizedDescription } }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.image, .pdf]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    let type = UTType(filenameExtension: url.pathExtension)
                    file = MultipartFileUpload(fieldName: "attachment", fileName: url.lastPathComponent, mimeType: type?.preferredMIMEType ?? "application/octet-stream", data: data)
                    attachmentError = nil
                } catch { attachmentError = error.localizedDescription }
            }
            .confirmationDialog(advance == nil ? "Give this advance?" : "Record this returned payment?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Confirm submission") {
                    Task { if await model.save(form: form, advance: advance, file: file) { dismiss() } }
                }
            }
        }
    }
    private var valid: Bool { validationError == nil }
    private var validationError: String? {
        do { _ = try form.parameters(advance: advance); return nil }
        catch { return error.localizedDescription }
    }
}

private func advanceStatusIcon(_ status: AdvanceStatus) -> String {
    switch status {
    case .pending: "hourglass"
    case .partial: "chart.pie.fill"
    case .completed: "checkmark.circle.fill"
    case .onHold: "pause.circle.fill"
    case .cancelled: "nosign"
    }
}

private struct AdvanceRecordCard: View {
    let record: PaymentAdvanceRecord
    var body: some View {
        AdvanceCard {
            HStack {
                Text(record.isReturn ? "Returned" : "Advance").font(.caption.weight(.semibold)).foregroundStyle(AppTheme.cerulean)
                Spacer()
                Text(advanceMoney(record.amount)).font(.title3.bold())
            }
            if !record.person.isEmpty { Text(record.person).font(.headline) }
            if !record.role.isEmpty { Text(record.role).font(.caption).foregroundStyle(.secondary) }
            if !record.text.isEmpty { Text(record.text).font(.subheadline) }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.date)
                    if !record.author.isEmpty { Text("\(record.isReturn ? "Received" : "Given") by \(record.author)") }
                }.font(.caption).foregroundStyle(.secondary)
                Spacer()
                AdvanceStatusPill(status: record.status)
            }
        }
    }
}

private struct AdvanceStatusSheet: View {
    let current: String
    @Binding var selection: AdvanceStatus?
    let saving: Bool
    let submit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(AppTheme.silver).frame(width: 48, height: 5).padding(.top, 10)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Change status").font(.title3.weight(.semibold))
                    Text("Choose the current repayment status").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(AdvanceStatus.allCases) { status in
                        let active = status.rawValue == (selection?.rawValue ?? current)
                        Button { selection = status } label: {
                            HStack(spacing: 12) {
                                Image(systemName: statusIcon(status)).font(.title3).foregroundStyle(statusColor(status)).frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(status.title).font(.body.weight(.semibold)).foregroundStyle(AppTheme.textPrimary)
                                    Text(statusDescription(status)).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if active { Text("Current").font(.caption.weight(.medium)).foregroundStyle(.secondary) }
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(active ? AppTheme.brandContainer : .white, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(active ? AppTheme.cerulean.opacity(0.6) : AppTheme.gainsboro.opacity(0.7)))
                        }.buttonStyle(.plain)
                    }
                }
            }
            Button(action: submit) {
                Text("Set to \((selection ?? AdvanceStatus(rawValue: current) ?? .pending).title)")
                    .font(.body.weight(.semibold)).frame(maxWidth: .infinity).padding(14)
            }.buttonStyle(.borderedProminent).disabled(saving || (selection?.rawValue ?? current) == current)
        }.padding(.horizontal, 16).padding(.bottom, 12).background(AppTheme.whiteSmoke)
    }

    private func statusDescription(_ status: AdvanceStatus) -> String {
        switch status {
        case .pending: "Given, nothing returned yet"
        case .partial: "Some returned, some still due"
        case .completed: "Fully returned"
        case .onHold: "Processing paused for now"
        case .cancelled: "Entered by mistake; not owed"
        }
    }

    private func statusIcon(_ status: AdvanceStatus) -> String {
        switch status {
        case .pending: "hourglass"
        case .partial: "chart.pie.fill"
        case .completed: "checkmark.circle.fill"
        case .onHold: "pause.circle.fill"
        case .cancelled: "nosign"
        }
    }

    private func statusColor(_ status: AdvanceStatus) -> Color {
        switch status {
        case .pending: .orange
        case .partial: .blue
        case .completed: AppTheme.cerulean
        case .onHold: .secondary
        case .cancelled: .red
        }
    }
}

private struct AdvanceCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.gainsboro.opacity(0.6)))
    }
}

private struct AdvancePage<Content: View>: View {
    let title: String
    var onHome: () -> Void
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: { Image(systemName: "arrow.left") }.accessibilityLabel("Back")
                Text(title).font(.title3.weight(.semibold))
                Spacer()
                Button(action: onHome) { Image(systemName: "house.fill") }.accessibilityLabel("Home")
            }.foregroundStyle(.white).padding(18)
                .background(AppTheme.ctaGradient.ignoresSafeArea(edges: .top))
            ScrollView { VStack(alignment: .leading, spacing: 14, content: content).padding(12) }
        }.background(AppTheme.whiteSmoke).tint(CashStyle.green)
            .toolbar(.hidden, for: .navigationBar)
    }
}

private func advanceMoney(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "INR"
    formatter.locale = Locale(identifier: "en_IN")
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₹\(amount)"
}

/// Android `AdvanceStatusPill`: pending amber, partial blue, completed green, cancelled red,
/// anything else grey. The detail hero used one colour for every status.
struct AdvanceStatusPill: View {
    let status: String

    private var look: (label: String, fg: Color, bg: Color) {
        switch status.lowercased() {
        case "pending":
            return ("Pending", Color(hex: "B45309"), Color(hex: "FEF3C7"))
        case "partial":
            return ("Partial", Color(hex: "0369A1"), Color(hex: "E0F2FE"))
        case "completed":
            return ("Completed", Color(hex: "15803D"), Color(hex: "DCFCE7"))
        case "cancelled":
            return ("Cancelled", Color(hex: "DC2626"), Color(hex: "FFF1F2"))
        default:
            let text = status.replacingOccurrences(of: "_", with: " ").capitalized
            return (text.isEmpty ? "—" : text, Color(hex: "4B5563"), Color(hex: "F3F4F6"))
        }
    }

    var body: some View {
        Text(look.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(look.fg)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(look.bg, in: Capsule())
    }
}
