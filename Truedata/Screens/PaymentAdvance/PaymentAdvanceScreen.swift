import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PaymentAdvanceScreen: View {
    var onHome: () -> Void
    @StateObject private var model = PaymentAdvanceViewModel()
    @State private var giving = false
    @State private var choosingStaff = false

    var body: some View {
        AdvancePage(title: model.access.canManage ? "Payment Advance" : "My Payment Advance", onHome: onHome) {
            HStack(spacing: 5) {
                ForEach([("all", "All"), ("advance", model.access.canManage ? "Advance Given" : "Received"), ("returned", model.access.canManage ? "Payment Received" : "Returned")], id: \.0) { value, title in
                    Button { model.filter.type = value } label: {
                        Text(title).font(.subheadline.weight(model.filter.type == value ? .semibold : .regular))
                            .lineLimit(1).minimumScaleFactor(0.75)
                            .foregroundStyle(model.filter.type == value ? .white : AppTheme.textSecondary)
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background {
                                if model.filter.type == value { Capsule().fill(AppTheme.ctaGradient) }
                            }
                    }.buttonStyle(.plain)
                }
            }.padding(4).background(.white, in: Capsule())
            if model.access.canManage {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search by name, purpose, remark", text: $model.filter.search)
                }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 12))
                CashDropdown(title: "Role", placeholder: "All roles", options: [CashDropdownOption(id: "0", title: "All roles", icon: "person.3.fill")] + model.roles.map { CashDropdownOption(id: "\($0.id)", title: $0.name, icon: "person.fill") }, selection: Binding(get: { "\(model.filter.roleID)" }, set: { model.filter.roleID = Int($0) ?? 0 }))
                CashDropdown(title: "Status", placeholder: "All statuses", options: [CashDropdownOption(id: "", title: "All statuses", icon: "line.3.horizontal.decrease.circle")] + AdvanceStatus.allCases.map { CashDropdownOption(id: $0.rawValue, title: $0.title, icon: advanceStatusIcon($0)) }, selection: $model.filter.status)
                    .disabled(model.filter.type == "returned")
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
                ContentUnavailableView("No payments found", systemImage: "banknote", description: Text("Records matching your filters will appear here."))
            }
            ForEach(model.records) { record in
                NavigationLink {
                    PaymentAdvanceDetailScreen(id: record.advanceID, onHome: onHome)
                } label: { AdvanceRecordCard(record: record) }.buttonStyle(.plain)
            }
            if model.loading { ProgressView().frame(maxWidth: .infinity) }
            if model.hasMore && !model.loading {
                Button("Load more") { Task { await model.load(more: true) } }.frame(maxWidth: .infinity)
            }
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
                    Label("Give Advance", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(14)
                }.buttonStyle(.borderedProminent).padding(.horizontal, 14).padding(.vertical, 8)
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
        AdvancePage(title: "Advance #\(id)", onHome: onHome) {
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
                        Text(record.status.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.darkMidnightBlue)
                            .padding(.horizontal, 12).padding(.vertical, 7).background(.white.opacity(0.9), in: Capsule())
                    }
                    Text(advanceMoney(record.amount)).font(.largeTitle.bold()).foregroundStyle(.white)
                    Text(record.person).font(.headline).foregroundStyle(.white)
                    Rectangle().fill(.white.opacity(0.25)).frame(height: 1)
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
                    Button { proposedStatus = AdvanceStatus(rawValue: record.status) ?? .pending; showingStatus = true } label: {
                        Label("Status", systemImage: "clock").frame(maxWidth: .infinity).padding(12)
                    }.buttonStyle(.bordered).disabled(model.saving)
                    if record.outstanding > 0 && record.status != "cancelled" {
                        Button { receiving = true } label: {
                            Label("Receive Payment", systemImage: "arrow.down.circle.fill").frame(maxWidth: .infinity).padding(12)
                        }.buttonStyle(.borderedProminent).disabled(model.saving)
                    }
                }.padding(.horizontal, 14).padding(.vertical, 8).background(.regularMaterial)
            }
        }
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

private struct PaymentAdvanceFormScreen: View {
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
                        CashDropdown(title: "Person *", placeholder: "Choose a person", options: model.people.map { CashDropdownOption(id: "\($0.id)", title: $0.name, icon: "person.fill") }, selection: Binding(get: { form.personID == 0 ? "" : "\(form.personID)" }, set: { form.personID = Int($0) ?? 0 }))
                        if let error = model.optionsError {
                            Text(error).foregroundStyle(.red)
                            Button("Retry") { Task { await model.loadOptions() } }
                        }
                    }
                }
                Section(advance == nil ? "Advance details" : "Payment details") {
                    TextField(advance == nil ? "Advance amount (₹)" : "Receive amount (₹)", text: $form.amount).keyboardType(.numberPad)
                    DatePicker("Date", selection: $form.date, in: ...Date(), displayedComponents: .date)
                    HStack(alignment: .bottom) {
                        TextField(advance == nil ? "Purpose / Remark" : "Remark", text: $form.text, axis: .vertical).lineLimit(3...6)
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
                    Button { confirming = true } label: {
                        HStack { Spacer(); if model.saving { ProgressView() } else { Text("Submit").fontWeight(.semibold) }; Spacer() }
                    }.disabled(!valid || model.saving || attachmentLoading)
                }
            }
            .disabled(model.saving)
            .tint(AppTheme.cerulean)
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
                Text(record.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
                    .foregroundStyle(statusColor).background(statusColor.opacity(0.12), in: Capsule())
            }
        }
    }
    private var statusColor: Color {
        switch record.status {
        case "completed", "returned": return AppTheme.cerulean
        case "partial": return .blue
        case "cancelled": return .red
        case "on_hold": return .secondary
        default: return .orange
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
        }.background(AppTheme.whiteSmoke).tint(AppTheme.cerulean)
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
