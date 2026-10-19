import SwiftUI
import AVFoundation
import Speech
import Combine

enum CashStyle {
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

struct CashTabs: View {
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
/// Mirrors Android `UtilityScreen`: one card per tool the signed-in role may use, grouped into
/// DAILY CASH / PAYMENTS / REPORTS / SELLERS with the same copy, ordering and per-tile accents.
struct UtilityScreen: View {
    var onHome: () -> Void

    private var role: String { UserDefaultManager.shared.getUserDefaultsString(key: .userRole) }
    private var access: CashAccess { CashAccess(role: role) }

    private enum Accent {
        static let amountTaken = Color(hex: "B45309")
        static let advance = Color(hex: "1D4ED8")
        static let bills = Color(hex: "7C3AED")
        static let ledger = Color(hex: "475569")
        static let merge = Color(hex: "0F766E")
        static let markAttendance = Color(hex: "0E7490")
        static let attendanceHistory = Color(hex: "BE185D")
    }

    var body: some View {
        CashPage(title: "Utility", onHome: onHome) {
            VStack(alignment: .leading, spacing: 10) {
                header

                section("DAILY CASH")
                NavigationLink { CashCollectionScreen(onHome: onHome) } label: {
                    tile(
                        "Cash Collection",
                        access.canReviewAll ? "Submit cash · Review collections" : "Submit cash · Track approval",
                        icon: "banknote",
                        accent: CashStyle.green,
                        filled: true
                    )
                }
                if access.canManageAmountTaken {
                    NavigationLink { AmountTakenScreen(onHome: onHome) } label: {
                        tile("Amount Taken", "Record cash out for expenses",
                             icon: "wallet.pass", accent: Accent.amountTaken)
                    }
                }

                section("PAYMENTS")
                NavigationLink { PaymentAdvanceScreen(onHome: onHome) } label: {
                    tile(
                        access.canManageAdvance ? "Payment Advance" : "My Payment Advance",
                        access.canManageAdvance ? "Staff advances & repayments" : "Your advances & repayments",
                        icon: "indianrupeesign.circle",
                        accent: Accent.advance
                    )
                }
                if access.canManageBills || access.canViewOwnBills {
                    NavigationLink { BillRegisterScreen(onHome: onHome) } label: {
                        tile(
                            access.canManageBills ? "Bill Register" : "My Bill Register",
                            access.canManageBills ? "Assign & track customer bills" : "Customer bills assigned to you",
                            icon: "doc.text",
                            accent: Accent.bills
                        )
                    }
                }

                if access.canManageAttendance {
                    section("ATTENDANCE")
                    NavigationLink { MarkManualAttendanceScreen(onHome: onHome) } label: {
                        tile("Mark Attendance", "Mark staff present, absent, half day or holiday",
                             icon: "person.badge.clock", accent: Accent.markAttendance)
                    }
                    NavigationLink { ManualAttendanceHistoryScreen(onHome: onHome) } label: {
                        tile("Attendance History", "See who was marked on any day",
                             icon: "calendar.badge.clock", accent: Accent.attendanceHistory)
                    }
                }

                if access.canViewLedger {
                    section("REPORTS")
                    NavigationLink { CashLedgerScreen(onHome: onHome) } label: {
                        tile("Ledger", "View cash history & staff totals",
                             icon: "book.closed", accent: Accent.ledger)
                    }
                }

                if SellerMergeAccess.allowed {
                    section("SELLERS")
                    NavigationLink { SellerMergeScreen(onHome: onHome) } label: {
                        tile("Seller Merge", "Combine duplicate sellers and their records",
                             icon: "arrow.triangle.merge", accent: Accent.merge)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Utility tools")
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(CashStyle.ink)
            Text("Choose the task you need")
                .font(.system(size: 13))
                .foregroundStyle(CashStyle.muted)
        }
        .padding(.bottom, 6)
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(CashStyle.muted)
            .padding(.leading, 2)
            .padding(.top, 6)
    }

    private func tile(
        _ title: String,
        _ body: String,
        icon: String,
        accent: Color,
        filled: Bool = false
    ) -> some View {
        let foreground = filled ? Color.white : accent

        return HStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 42, height: 42)
                .background(
                    filled ? Color.white.opacity(0.16) : accent.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 14)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(filled ? .white : CashStyle.ink)
                Text(body)
                    .font(.system(size: 12))
                    .foregroundStyle(filled ? Color.white.opacity(0.85) : CashStyle.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)

            Image(systemName: "arrow.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(foreground.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, filled ? 17 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if filled {
                RoundedRectangle(cornerRadius: 16).fill(CashStyle.gradient)
            } else {
                RoundedRectangle(cornerRadius: 16).fill(.white)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(filled ? .clear : accent.opacity(0.14), lineWidth: 1)
        )
    }
}

struct CashCollectionScreen: View {
    var onHome: () -> Void
    @StateObject private var model = CashCollectionViewModel()
    @StateObject private var summaryModel = CashCollectionViewModel(initialPeriod: .today)
    @State private var tab = "Submit"
    @State private var form = CashCountForm()
    @State private var confirm = false

    /// Android `listTitle`: a sale person only ever sees their own submissions, so the tab must not
    /// promise "All".
    private var listTitle: String { model.access.canReviewAll ? "All Collection" : "My Collection" }

    /// Android gates Summary behind `SUMMARY_FOR_EVERYONE || access.canReviewAll`, and the flag is
    /// false — a sale person sees only their own submissions, so a company-wide total is not theirs.
    private var tabTitles: [String] {
        model.access.canReviewAll ? ["Submit", listTitle, "Summary"] : ["Submit", listTitle]
    }

    var body: some View {
        CashPage(title: "Cash Collection", onHome: onHome, onRefresh: { refresh() }) {
            CashTabs(titles: tabTitles, selection: $tab)
            CashFeedback(model: model)
            if tab == "Submit" {
                CashDenominationForm(form: $form).disabled(model.isSaving)
            } else {
                if tab == listTitle {
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
        } message: {
            // Android spells out what is being sent and that it is final; submitting can't be
            // undone from the app, so the counts and that warning belong in the prompt.
            let pieces = CashDenomination.all.reduce(0) { $0 + (Int(form.counts[$1.id, default: ""]) ?? 0) }
            Text("\(pieces) notes and coins adding up to \(cashMoney(form.total ?? 0)). It goes to your admin for approval. You can't change it after submitting.")
        }
    }

    private func refresh() {
        Task {
            if tab == "All Collection" { await model.reload() }
            if tab == "Summary" { await summaryModel.loadSummary() }
        }
    }
}

struct CashCollectionDetailScreen: View {
    /// Android titles this by what you can do here: editing, reviewing, or just looking.
    private var detailTitle: String {
        if editing { return "Edit Collection" }
        if model.access.canReviewAll, model.detail?.status == "pending" { return "Review Collection" }
        return "Collection Detail"
    }

    let id: Int
    var onHome: () -> Void
    @StateObject private var model = CashCollectionViewModel()
    @State private var remark = ""
    @State private var editing = false
    @State private var form = CashCountForm()
    @State private var reviewAction: Bool?
    @State private var confirmEdit = false

    var body: some View {
        CashPage(title: detailTitle, onHome: onHome, onRefresh: { Task { await model.loadDetail(id) } }) {
            CashFeedback(model: model)
            if model.isLoading { ProgressView() }
            if let record = model.detail {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("COLLECTION #\(record.id)").font(.caption.weight(.medium))
                        Spacer()
                        CashStatusPill(status: record.status)
                    }
                    Text(cashMoney(record.amount)).font(.largeTitle.bold())
                    Text("Submitted by \(record.name)").font(.headline)
                    Text(record.submittedAt).font(.subheadline)
                }.foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 18))
                if editing {
                    Text("Change the counts or the total. They must still add up. The collection stays pending after saving.")
                        .font(.subheadline).foregroundStyle(CashStyle.muted)
                    CashDenominationForm(form: $form).disabled(model.isSaving)
                    Button("Save changes") { confirmEdit = true }
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
                    if model.access.canReviewAll && record.status == "pending" {
                        CashCard {
                            VStack(alignment: .leading, spacing: 16) {
                                CashSummaryHeading(title: "Review remark", subtitle: "Required when rejecting", icon: "square.and.pencil")
                                HStack(alignment: .top) {
                                    TextField("e.g. Verified with the cash in hand", text: $remark, axis: .vertical)
                                        .lineLimit(3...5)
                                        .onChange(of: remark) { value in remark = String(value.prefix(250)) }
                                    SpeechRemarkButton(text: $remark)
                                }.padding(14).background(CashStyle.pale.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.border))
                            }
                        }.disabled(model.isSaving)
                    }
                }
            } else if !model.isLoading {
                Button("Retry") { Task { await model.loadDetail(id) } }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let record = model.detail, !editing,
               (model.access.canEdit && record.status != "approved") || (model.access.canReviewAll && record.status == "pending") {
                VStack(alignment: .leading, spacing: 12) {
                    Capsule().fill(CashStyle.border).frame(width: 36, height: 4).frame(maxWidth: .infinity)
                    Text("From \(record.name)").font(.caption).foregroundStyle(CashStyle.muted)
                    Text(cashMoney(record.amount)).font(.title2.weight(.semibold))
                    HStack(spacing: 10) {
                        let canReview = model.access.canReviewAll && record.status == "pending"
                        if model.access.canEdit && record.status != "approved" {
                            Button { form = CashCountForm(record: record); editing = true } label: {
                                if canReview {
                                    Image(systemName: "pencil").frame(width: 48, height: 48)
                                        .foregroundStyle(CashStyle.ink).background(CashStyle.border.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Label("Edit collection", systemImage: "pencil")
                                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                                        .foregroundStyle(.white).background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 12))
                                }
                            }.accessibilityLabel("Edit counts")
                        }
                        if model.access.canReviewAll && record.status == "pending" {
                            Button { reviewAction = false } label: {
                                Label("Reject", systemImage: "xmark").frame(maxWidth: .infinity).padding(.vertical, 15)
                                    .foregroundStyle(.red).background(Color.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                            }.disabled(remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Button { reviewAction = true } label: {
                                Label("Approve", systemImage: "checkmark").frame(maxWidth: .infinity).padding(.vertical, 15)
                                    .foregroundStyle(.white).background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }.font(.subheadline.weight(.semibold)).buttonStyle(.plain).disabled(model.isSaving)
                }.padding(14).background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20))
                    .overlay(alignment: .top) { CashStyle.border.frame(height: 1) }
            }
        }
        .task { await model.loadDetail(id) }
        .confirmationDialog(
            "\(reviewAction == true ? "Approve" : "Reject") \(cashMoney(model.detail?.amount ?? 0))?",
            isPresented: Binding(get: { reviewAction != nil }, set: { if !$0 { reviewAction = nil } }),
            titleVisibility: .visible
        ) {
            let approve = reviewAction == true
            Button(approve ? "Approve" : "Reject", role: approve ? nil : .destructive) {
                Task {
                    if await model.review(approve: approve, remark: remark) {
                        remark = ""
                        await model.loadDetail(id)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            // The amount and who handed it over are the whole decision; Android puts both in the
            // prompt and warns that an approval can't be edited afterwards.
            let who = (model.detail?.name).flatMap { $0.isEmpty ? nil : $0 } ?? "this person"
            Text(reviewAction == true
                 ? "This confirms you received \(cashMoney(model.detail?.amount ?? 0)) from \(who). Approved collections can't be edited."
                 : "\(who) will see it as rejected with your remark.")
        }
        .confirmationDialog("Save the updated cash counts?", isPresented: $confirmEdit, titleVisibility: .visible) {
            Button("Save changes") {
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
                CashTabs(titles: ["Add", "All Taken"], selection: $tab)
                CashFeedback(model: model)
                if tab == "Add" {
                    takenForm
                } else {
                    CashFilterView(filter: $model.filter, people: model.people, showsStaff: true)
                    if model.isLoading { ProgressView() }
                    if model.records.isEmpty && !model.isLoading && model.error == nil {
                        VStack(spacing: 12) {
                            Image(systemName: "wallet.pass").font(.largeTitle).foregroundStyle(CashStyle.green)
                            Text("Nothing recorded").font(.headline)
                            // Android names the period being looked at, and says when a staff
                            // filter is what narrowed it, instead of a generic "try again" line.
                            Text("No amount was taken \(model.filter.periodPhrase)\(model.filter.staffIds.isEmpty ? "." : " by the chosen staff.")")
                                .font(.subheadline).foregroundStyle(CashStyle.muted).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(.vertical, 32)
                    }
                    ForEach(model.records) { record in
                        VStack(alignment: .leading, spacing: 10) {
                            Button { detailRecord = record } label: { takenRecordCard(record) }.buttonStyle(.plain)
                            if record.status == "pending" {
                                Button("Review") { selected = record }.buttonStyle(.bordered)
                            }
                        }
                    }
                    CashLoadMore(model: model)
                }
            } else { Text("You don't have access to this.") }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if tab == "Add" && model.access.canManageAmountTaken { takenFooter }
        }
        .task { await model.loadPeople() }
        .onChange(of: tab) { if $0 == "All Taken" { Task { await model.reload() } } }
        .onChange(of: model.filter) { _ in Task { await model.reload() } }
        .task(id: "\(personId)-\(CashFilter.dateString(date))") {
            collectionId = 0
            if model.access.canManageAmountTaken { await model.loadLinkedCollections(personId: personId, date: date) }
        }
        .confirmationDialog("Record \(cashMoney(Int(amount) ?? 0))?", isPresented: $confirmAdd, titleVisibility: .visible) {
            Button("Confirm") {
                Task {
                    if await model.addTaken(personId: personId, amount: amount, reason: reason, remark: remark, date: date, collectionId: collectionId > 0 ? collectionId : nil) {
                        amount = ""; reason = ""; remark = ""; personId = 0; collectionId = 0; tab = "All Taken"
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
            CashTakenDetailSheet(record: record)
        }
    }

    private var canSubmit: Bool {
        personId > 0 && (Int(amount) ?? 0) > 0 && !model.isSaving && !model.isLoadingLinks
    }

    private var takenForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Label("CASH OUT", systemImage: "wallet.pass.fill").font(.caption.weight(.semibold)).opacity(0.8)
                Text("Record amount taken").font(.title2.bold())
                Text("Choose the person and record cash taken for expenses.").font(.subheadline).opacity(0.85)
            }.foregroundStyle(.white).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 20))
            CashCard {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Payment details", systemImage: "banknote").font(.headline).foregroundStyle(CashStyle.green)
                    CashDropdown(title: "Person *", placeholder: "Choose a person", options: model.people.map {
                        CashDropdownOption(id: String($0.id), title: $0.name, icon: "person.fill")
                    }, selection: Binding(get: { String(personId) }, set: { personId = Int($0) ?? 0 }))
                    if let error = model.peopleError { CashRetry(message: error) { Task { await model.loadPeople() } } }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount *").font(.subheadline.weight(.medium))
                        HStack(spacing: 10) {
                            Text("₹").font(.title2.weight(.semibold)).foregroundStyle(CashStyle.green)
                            TextField("Enter amount", text: $amount).keyboardType(.numberPad).font(.title3.weight(.medium))
                                .onChange(of: amount) { _, value in amount = value.filter { $0.isASCII && $0.isNumber } }
                        }.padding(14).background(CashStyle.pale.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.border))
                    }
                    DatePicker(selection: $date, in: ...Date(), displayedComponents: .date) {
                        Label("Date", systemImage: "calendar").font(.subheadline.weight(.medium))
                    }.tint(CashStyle.green)
                }
            }
            CashCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Reason & remark", systemImage: "square.and.pencil").font(.headline).foregroundStyle(CashStyle.green)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason (optional)").font(.subheadline.weight(.medium))
                        // Android `quickReasons`: the same five cover almost every entry, so offer
                        // them as chips instead of making the user type one out each time.
                        CashQuickReasons(selection: $reason)
                        TextField("Or type a reason", text: $reason).padding(14)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.border))
                            .onChange(of: reason) { _, value in reason = String(value.prefix(100)) }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Remark (optional)").font(.subheadline.weight(.medium))
                        HStack(alignment: .top, spacing: 8) {
                            TextField("Add any extra details", text: $remark, axis: .vertical).lineLimit(3...5)
                                .onChange(of: remark) { _, value in remark = String(value.prefix(250)) }
                            SpeechRemarkButton(text: $remark)
                        }.padding(14).overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.border))
                        Text("\(remark.count)/250").font(.caption).foregroundStyle(CashStyle.muted).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            CashCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Collection reference", systemImage: "link").font(.headline).foregroundStyle(CashStyle.green)
                    Text("Optionally link this amount to a cash collection for the selected person and date.").font(.subheadline).foregroundStyle(CashStyle.muted)
                    // Android lays the person's collections out as chips so they can be compared
                    // at a glance, rather than hiding them behind a dropdown.
                    if personId != 0 && !model.isLoadingLinks && !model.linkedCollections.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                let options: [(id: Int, title: String)] =
                                    [(id: 0, title: "None")]
                                    + model.linkedCollections.map { (id: $0.id, title: "\(cashMoney($0.amount)) · \($0.date)") }
                                ForEach(options, id: \.id) { option in
                                    let isSelected = collectionId == option.id
                                    Button { collectionId = option.id } label: {
                                        Text(option.title).font(.caption)
                                            .padding(.horizontal, 11).padding(.vertical, 8)
                                            .foregroundStyle(isSelected ? CashStyle.green : CashStyle.ink)
                                            .background(isSelected ? CashStyle.pale : .white, in: Capsule())
                                            .overlay(Capsule().stroke(isSelected ? CashStyle.green : CashStyle.border))
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.horizontal, 2)
                        }
                    }
                    if model.isLoadingLinks { ProgressView("Loading collections…").font(.caption) }
                    if let error = model.linksError {
                        Text("Collection link unavailable: \(error)").font(.caption).foregroundStyle(CashStyle.muted)
                    } else if personId == 0 {
                        Text("Choose a person first.").font(.caption).foregroundStyle(CashStyle.muted)
                    } else if !model.isLoadingLinks && model.linkedCollections.isEmpty {
                        Text("No collections for this person and date. You can record the amount without a link.").font(.caption).foregroundStyle(CashStyle.muted)
                    }
                }
            }
        }.disabled(model.isSaving)
    }

    private var takenFooter: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Amount taken").font(.caption).foregroundStyle(CashStyle.muted)
                    Text(cashMoney(Int(amount) ?? 0)).font(.title2.bold()).foregroundStyle(CashStyle.ink)
                }
                Spacer()
                if let person = model.people.first(where: { $0.id == personId }) {
                    Text(person.name).font(.subheadline).foregroundStyle(CashStyle.muted).multilineTextAlignment(.trailing)
                }
            }
            Button { confirmAdd = true } label: {
                HStack(spacing: 10) {
                    if model.isSaving { ProgressView().tint(.white) }
                    else { Image(systemName: "checkmark.circle.fill") }
                    Text(model.isSaving ? "Recording…" : "Record Amount").font(.headline)
                }.frame(maxWidth: .infinity).padding(.vertical, 16).foregroundStyle(.white)
                    .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .opacity(canSubmit ? 1 : 0.45)
            }.buttonStyle(.plain).disabled(!canSubmit)
        }.padding(16).background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
    }

    private func takenRecordCard(_ record: CashRecord) -> some View {
        CashCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "wallet.pass.fill").foregroundStyle(CashStyle.green)
                        .padding(10).background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.name.isEmpty ? "Amount taken #\(record.id)" : record.name).font(.headline)
                        Text(record.date).font(.caption).foregroundStyle(CashStyle.muted)
                    }
                    Spacer(minLength: 4)
                    Text("−\(cashMoney(record.amount))").font(.headline).foregroundStyle(.red)
                }
                if !record.reason.isEmpty { Text(record.reason).font(.subheadline).foregroundStyle(CashStyle.ink) }
                if !record.remark.isEmpty { Text(record.remark).font(.subheadline).foregroundStyle(CashStyle.muted).lineLimit(2) }
                HStack {
                    Text(record.status.capitalized).font(.caption.weight(.semibold))
                        .foregroundStyle(record.status == "approved" ? CashStyle.green : record.status == "rejected" ? .red : .orange)
                        .padding(.horizontal, 10).padding(.vertical, 6).background(CashStyle.pale, in: Capsule())
                    Spacer()
                    Text("View details").font(.caption).foregroundStyle(CashStyle.green)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(CashStyle.green)
                }
            }
        }
    }

    private func update(_ record: CashRecord, approve: Bool) {
        Task { if await model.reviewTaken(record, approve: approve) { await model.reload() } }
    }
}

/// Android `quickReasons` chip row on Amount Taken.
struct CashQuickReasons: View {
    @Binding var selection: String

    private static let reasons = ["Petrol", "Office Expense", "Food", "Vehicle Repair", "Advance"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.reasons, id: \.self) { reason in
                    let isSelected = selection.caseInsensitiveCompare(reason) == .orderedSame
                    Button {
                        // Tapping the active chip clears it, so a typed reason stays reachable.
                        selection = isSelected ? "" : reason
                    } label: {
                        Text(reason)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? CashStyle.green : CashStyle.pale,
                                in: Capsule()
                            )
                            .foregroundStyle(isSelected ? .white : CashStyle.ink)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

struct CashLedgerScreen: View {
    var onHome: () -> Void
    @StateObject private var model = CashCollectionViewModel(kind: .ledger)
    @State private var selectedTaken: CashRecord?
    /// `V2/cash-collection/ledger` is one list of both kinds, as on Android. Pulling the
    /// amount-taken list in as well duplicated every taken row.
    private var entries: [LedgerDisplayEntry] {
        model.records
            .filter { $0.status == "approved" || $0.status.isEmpty }
            .map { LedgerDisplayEntry(record: $0, isTaken: $0.isAmountTaken) }
            .sorted { $0.record.date > $1.record.date }
    }
    private func ledgerMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption)
            Text(value).font(.headline).minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        CashPage(title: "Ledger", onHome: onHome, onRefresh: { Task { await model.reload() } }) {
            if model.access.canViewLedger {
                CashFilterView(filter: $model.filter, people: model.people, showsStaff: true)
                CashFeedback(model: model)
                if let error = model.peopleError { CashRetry(message: error) { Task { await model.loadPeople() } } }
                // The ledger endpoint returns period totals of its own. Deriving them from the
                // rows paged in so far understated every figure once a period ran past one page.
                if let ledger = model.ledgerSummary {
                    // Android leads on net cash, not the closing balance: Collected / Taken /
                    // Entries, then an opening → closing strip underneath.
                    VStack(alignment: .leading, spacing: 14) {
                        Text("NET CASH").font(.caption.weight(.semibold))
                        Text(cashMoney(ledger.netAmount)).font(.largeTitle.bold())
                        Text(model.filter.period == .all ? "All time" : model.filter.period.rawValue)
                            .font(.subheadline.weight(.medium))
                        HStack(spacing: 7) {
                            ledgerMetric("Collected", "+" + cashMoney(ledger.totalCollection))
                            ledgerMetric("Taken", ledger.totalTaken > 0 ? "−" + cashMoney(ledger.totalTaken) : cashMoney(0))
                            ledgerMetric("Entries", "\(model.totalRecords)")
                        }.padding(14).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Opening balance").font(.caption2)
                                Text(cashMoney(ledger.openingBalance)).font(.footnote.bold())
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.forward").font(.caption).opacity(0.6)
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Closing balance").font(.caption2)
                                Text(cashMoney(ledger.closingBalance)).font(.footnote.bold())
                            }.frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }.foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 18))
                } else if let summary = model.summary {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("COLLECTED CASH").font(.caption.weight(.semibold))
                        Text(cashMoney(summary.amount)).font(.largeTitle.bold())
                        Text(model.filter.period == .all ? "All time" : model.filter.period.rawValue)
                            .font(.subheadline.weight(.medium))
                        HStack(spacing: 7) {
                            ledgerMetric("Collected", cashMoney(summary.amount))
                            ledgerMetric("Taken shown", cashMoney(entries.filter(\.isTaken).reduce(0) { $0 + $1.record.amount }))
                            ledgerMetric("Entries shown", "\(entries.count)")
                        }.padding(14).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }.foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 18))
                } else if let error = model.summaryError {
                    CashRetry(message: "Totals unavailable: \(error)") { Task { await model.loadSummary() } }
                }
                if model.isLoading { ProgressView() }
                if entries.isEmpty && !model.isLoading {
                    VStack(spacing: 6) {
                        Text("No entries").font(.headline)
                        Text("Nothing was collected or taken \(model.filter.periodPhrase).")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 24)
                }
                ForEach(Array(Set(entries.map { ledgerDayKey($0.record.date) })).sorted(by: >), id: \.self) { day in
                    // Sorting only by day left every collection above every amount taken;
                    // Android keeps a day's entries in time order, which is how they're read.
                    let dayEntries = entries
                        .filter { ledgerDayKey($0.record.date) == day }
                        .sorted { a, b in
                            let left = LedgerTime.date(a.record.submittedAt)
                            let right = LedgerTime.date(b.record.submittedAt)
                            switch (left, right) {
                            case let (l?, r?): return l > r
                            case (nil, _?): return false
                            case (_?, nil): return true
                            default: return a.record.id > b.record.id
                            }
                        }
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
                            Text(model.hasMore ? "Shown net" : "Net").font(.caption).foregroundStyle(CashStyle.muted)
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
            } else { Text("You don't have access to this.") }
        }
        .task { await model.loadPeople(); await model.reload() }
        .onChange(of: model.filter) { value in
            Task { await model.reload() }
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
                Text([LedgerTime.label(record.submittedAt),
                      entry.isTaken ? (record.reason.isEmpty ? "Amount taken" : record.reason) : "Collection #\(record.id)"]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(CashStyle.muted).lineLimit(1)
                if entry.isTaken && !record.takenBy.isEmpty { Text("Taken by \(record.takenBy)").font(.caption).foregroundStyle(CashStyle.muted) }
                if !record.remark.isEmpty { Text("“\(record.remark)”").font(.caption.italic()).foregroundStyle(CashStyle.muted).lineLimit(1) }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.isTaken ? "−" : "+")\(cashMoney(record.amount))")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(entry.isTaken ? .red : CashStyle.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                // Android shows the running cash in hand the server computed for this line.
                if let balance = record.balanceAfter {
                    Text("Bal \(cashMoney(balance))").font(.caption).foregroundStyle(CashStyle.muted)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
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
                if !record.remark.isEmpty { row("Remark", record.remark) }
                row("When", record.date)
                row("Reference", "#\(record.id)")
            }.padding(16).background(Color(red: 0.98, green: 0.99, blue: 0.98), in: RoundedRectangle(cornerRadius: 14))
            Button("Close") { dismiss() }.font(.headline).foregroundStyle(CashStyle.green)
                .frame(maxWidth: .infinity).padding(14).background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 12))
        }.padding(20).presentationDetents([.large]).presentationDragIndicator(.visible)
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

private struct CashStepperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? CashStyle.green.opacity(0.18) : Color.clear)
            .contentShape(Rectangle())
    }
}

struct CashDenominationBadge: View {
    let value: Int
    var label: String? = nil
    var kind: String = "note"

    private var isCoin: Bool {
        kind.lowercased().contains("coin")
    }

    var tint: Color {
        if isCoin {
            return value >= 5 ? Color(red: 0.79, green: 0.64, blue: 0.23) : .gray
        }
        switch value {
        case 500: return Color(red: 0.55, green: 0.54, blue: 0.48)
        case 200: return .orange
        case 100: return .purple
        case 50: return .cyan
        case 20: return .green
        case 10: return .brown
        default: return CashStyle.green
        }
    }

    private var displayText: String {
        if value > 0 {
            return "₹\(value)"
        }
        if let label, !label.isEmpty {
            return label.hasPrefix("₹") ? label : "₹\(label)"
        }
        return "₹0"
    }

    var body: some View {
        Text(displayText)
            .font(.subheadline.weight(.medium))
            .frame(width: 60, height: 35)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: isCoin ? 18 : 6))
            .overlay(RoundedRectangle(cornerRadius: isCoin ? 18 : 6).stroke(tint.opacity(0.55)))
    }
}

private struct CashDenominationRow: View {
    let denomination: CashDenomination
    @Binding var count: String
    var body: some View {
        let lineTotal = denomination.value.multipliedReportingOverflow(by: Int(count) ?? 0)
        HStack(spacing: 8) {
            CashDenominationBadge(value: denomination.value, kind: denomination.kind)
            HStack(spacing: 0) {
                Button {
                    let current = Int(count.filter(\.isNumber)) ?? 0
                    let next = max(0, current - 1)
                    count = next == 0 ? "" : String(next)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 40, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(CashStepperButtonStyle())

                TextField("0", text: $count)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(height: 38)
                    .accessibilityLabel("\(denomination.label) quantity")
                    .onChange(of: count) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        if digits != newValue { count = digits }
                    }

                Button {
                    let current = Int(count.filter(\.isNumber)) ?? 0
                    count = String(current + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 40, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(CashStepperButtonStyle())
            }
            .foregroundStyle(CashStyle.green)
            .background(Color(red: 0.96, green: 0.97, blue: 0.97), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CashStyle.border))
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
    @State private var expandedStaff: Set<Int> = []
    @State private var showsUnusedDenominations = false

    private var periodTitle: String {
        switch model.filter.period {
        case .today: return "Today"
        case .all: return "All time"
        case .month: return model.filter.month.formatted(.dateTime.month(.wide).year())
        case .range: return "\(model.filter.from.formatted(date: .abbreviated, time: .omitted)) – \(model.filter.to.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = model.summaryError {
                CashRetry(message: error) { Task { await model.loadSummary() } }
            } else if let summary = model.summary {
                CashSummaryTotals(summary: summary, period: periodTitle)
                CashNotesChart(lines: summary.denominations)
                CashCard {
                    VStack(alignment: .leading, spacing: 20) {
                        CashSummaryHeading(title: "By denomination", subtitle: "\(summary.denominations.filter { $0.quantity > 0 }.count) of \(summary.denominations.count) used · bar = amount", icon: "banknote")
                        // Android lists only the denominations actually counted and puts the rest
                        // behind a toggle; showing every zero row made "x of y used" read wrong.
                        let used = summary.denominations.filter { $0.quantity > 0 }
                        let unused = summary.denominations.filter { $0.quantity == 0 }
                        ForEach(showsUnusedDenominations ? summary.denominations : used) { line in
                            CashSummaryDenomination(line: line, total: summary.amount)
                        }
                        if !unused.isEmpty {
                            Button {
                                withAnimation(.easeInOut(duration: 0.26)) { showsUnusedDenominations.toggle() }
                            } label: {
                                Text(showsUnusedDenominations
                                     ? "Hide unused"
                                     : "Show \(unused.count) unused (\(unused.map { "₹\($0.numericValue) \($0.kind)" }.joined(separator: ", ")))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.cerulean)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                CashCard {
                    VStack(alignment: .leading, spacing: 12) {
                        CashSummaryHeading(title: "By staff", subtitle: "\(summary.staff.count) people · tap one to see their notes", icon: "person.3.fill")
                        ForEach(summary.staff) { staff in
                            staffCard(staff, total: summary.amount)
                        }
                        if summary.staff.isEmpty { Text("No staff collections for this period.").font(.subheadline).foregroundStyle(CashStyle.muted) }
                    }
                }
                if summary.entries == 0 { Text("No approved collections for this period.").foregroundStyle(.secondary) }
            } else { ProgressView("Loading summary…") }
        }
    }

    private func staffCard(_ staff: CashStaffSummary, total: Int) -> some View {
        let expanded = expandedStaff.contains(staff.id)
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                if expanded { expandedStaff.remove(staff.id) } else { expandedStaff.insert(staff.id) }
            } label: {
                HStack(spacing: 10) {
                    Text(staff.name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined())
                        .font(.subheadline.weight(.medium)).foregroundStyle(CashStyle.green)
                        .frame(width: 40, height: 40).background(CashStyle.pale, in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text(staff.name).font(.headline).foregroundStyle(CashStyle.ink)
                        Text("\(staff.entries) entries · \(cashShare(staff.amount, of: total)) of total")
                            .font(.caption).foregroundStyle(CashStyle.muted)
                    }
                    Spacer(minLength: 0)
                    Text(cashMoney(staff.amount)).font(.subheadline.weight(.semibold)).foregroundStyle(CashStyle.ink)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(CashStyle.muted)
                }
            }.buttonStyle(.plain).accessibilityValue(expanded ? "Expanded" : "Collapsed")
            CashShareBar(amount: staff.amount, total: total, color: .init(red: 0.05, green: 0.48, blue: 0.65))
            if expanded {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)], alignment: .leading, spacing: 8) {
                    ForEach(staff.denominations.filter { $0.quantity > 0 }) { line in
                        HStack(spacing: 5) {
                            Image(systemName: line.kind.lowercased().contains("coin") ? "circle.fill" : "rectangle.fill")
                                .font(.caption2).foregroundStyle(cashLineColor(line))
                            Text("₹\(line.numericValue) × \(line.quantity)").font(.caption)
                        }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background(cashLineColor(line).opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                    }
                }
                if model.access.canReviewAll && staff.id > 0 {
                    Button("Show only this person") { model.filter.staffIds = [staff.id] }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(CashStyle.green).padding(.top, 4)
                }
            }
        }.padding(12).background(expanded ? CashStyle.pale.opacity(0.3) : Color.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(expanded ? CashStyle.green.opacity(0.4) : CashStyle.border))
    }
}

private func cashShare(_ amount: Int, of total: Int) -> String {
    let percent = total > 0 ? Double(amount) / Double(total) * 100 : 0
    return percent > 0 && percent < 0.1 ? "<0.1%" : String(format: "%.1f%%", percent)
}

private func cashLineColor(_ line: CashLine) -> Color {
    CashDenominationBadge(value: line.numericValue, kind: line.kind).tint
}

private struct CashSummaryHeading: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(CashStyle.green).frame(width: 34, height: 34)
                .background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(CashStyle.muted)
            }
        }
    }
}

private struct CashSummaryTotals: View {
    let summary: CashSummary
    let period: String
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("APPROVED CASH COUNTED").font(.caption.weight(.semibold))
            Text(cashMoney(summary.amount)).font(.largeTitle.bold()).minimumScaleFactor(0.7).lineLimit(1)
            Text(period).font(.subheadline.weight(.medium))
            HStack(spacing: 8) {
                metric("Entries", "\(summary.entries)")
                metric("Notes", "\(summary.denominations.filter { !$0.kind.lowercased().contains("coin") }.reduce(0) { $0 + $1.quantity }) pcs")
                metric("Coins", "\(summary.denominations.filter { $0.kind.lowercased().contains("coin") }.reduce(0) { $0 + $1.quantity }) pcs")
            }
        }.foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 18))
    }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.8))
            Text(value).font(.subheadline.bold())
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CashNotesChart: View {
    let lines: [CashLine]
    private var notes: [CashLine] { lines.filter { !$0.kind.lowercased().contains("coin") } }
    private var coins: [CashLine] { lines.filter { $0.kind.lowercased().contains("coin") } }
    private var noteAmount: Int { notes.reduce(0) { $0 + $1.total } }
    private var coinAmount: Int { coins.reduce(0) { $0 + $1.total } }
    private var fraction: CGFloat { noteAmount + coinAmount > 0 ? CGFloat(noteAmount) / CGFloat(noteAmount + coinAmount) : 0 }
    private let gold = Color(red: 0.79, green: 0.64, blue: 0.23)
    var body: some View {
        CashCard {
            VStack(alignment: .leading, spacing: 20) {
                CashSummaryHeading(title: "Notes vs coins", subtitle: "Share of the amount", icon: "chart.donut")
                HStack(spacing: 20) {
                    ZStack {
                        Circle().stroke(noteAmount + coinAmount > 0 ? gold : CashStyle.border, lineWidth: 16)
                        Circle().trim(from: 0, to: min(1, max(0, fraction))).stroke(CashStyle.green, lineWidth: 16).rotationEffect(.degrees(-90))
                        VStack(spacing: 5) {
                            Text(cashShare(noteAmount, of: noteAmount + coinAmount)).font(.title3.bold())
                            Text("in notes").font(.caption).foregroundStyle(CashStyle.muted)
                        }
                    }.frame(width: 112, height: 112).padding(8).accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(cashShare(noteAmount, of: noteAmount + coinAmount)) in notes")
                    VStack(alignment: .leading, spacing: 18) {
                        legend("Notes", amount: noteAmount, count: notes.reduce(0) { $0 + $1.quantity }, color: CashStyle.green)
                        legend("Coins", amount: coinAmount, count: coins.reduce(0) { $0 + $1.quantity }, color: gold)
                    }
                }
            }
        }
    }
    private func legend(_ title: String, amount: Int, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) { Circle().fill(color).frame(width: 8, height: 8); Text(title).font(.caption).foregroundStyle(CashStyle.muted) }
            Text(cashMoney(amount)).font(.headline)
            Text("\(count) pcs").font(.caption).foregroundStyle(CashStyle.muted)
        }
    }
}

private struct CashShareBar: View {
    let amount: Int
    let total: Int
    let color: Color
    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(CashStyle.border)
                .overlay(alignment: .leading) {
                    Capsule().fill(color).frame(width: amount > 0 && total > 0 ? max(3, geometry.size.width * min(1, CGFloat(amount) / CGFloat(total))) : 0)
                }
        }.frame(height: 6).accessibilityHidden(true)
    }
}

private struct CashSummaryDenomination: View {
    let line: CashLine
    let total: Int
    var body: some View {
        HStack(spacing: 12) {
            CashDenominationBadge(value: line.numericValue, label: line.label, kind: line.kind)
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("× \(line.quantity)").font(.subheadline.weight(.medium))
                    Spacer(minLength: 4)
                    Text(cashMoney(line.total)).font(.subheadline.weight(.semibold))
                }
                if !line.kind.lowercased().contains("coin") && line.quantity >= 100 {
                    Text("\(line.quantity / 100) \(line.quantity / 100 == 1 ? "bundle" : "bundles") + \(line.quantity % 100)")
                        .font(.caption2).foregroundStyle(CashStyle.muted)
                }
                HStack(spacing: 8) {
                    CashShareBar(amount: line.total, total: total, color: cashLineColor(line))
                    Text(cashShare(line.total, of: total)).font(.caption2).foregroundStyle(CashStyle.muted).frame(width: 42, alignment: .trailing)
                }
            }
        }
    }
}

private struct CashDenominationLines: View {
    let lines: [CashLine]
    private var nonZeroLines: [CashLine] {
        lines.filter { $0.quantity > 0 }
    }
    var body: some View {
        CashCard {
            VStack(spacing: 12) {
                Label("Denomination details", systemImage: "banknote").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                if nonZeroLines.isEmpty {
                    Text("No denomination breakup was sent for this collection.")
                        .font(.subheadline)
                        .foregroundStyle(CashStyle.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    HStack {
                        Text("Currency").frame(width: 60, alignment: .leading)
                        Spacer()
                        Text("Quantity")
                        Spacer()
                        Text("Total").frame(width: 75, alignment: .trailing)
                    }
                    .font(.caption).foregroundStyle(CashStyle.muted)
                    ForEach(Array(nonZeroLines.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 8) {
                            CashDenominationBadge(value: line.numericValue, label: line.label, kind: line.kind)
                            Spacer()
                            Text("\(line.quantity)").foregroundStyle(.secondary)
                            Spacer()
                            Text(cashMoney(line.total))
                                .fontWeight(.semibold)
                                .frame(width: 75, alignment: .trailing)
                        }.font(.subheadline)
                    }
                }
                Divider()
                HStack { Text("Total"); Spacer(); Text(cashMoney(lines.reduce(0) { $0 + $1.total })).foregroundStyle(CashStyle.green) }.font(.headline)
            }
        }
    }
}

private struct CashFilterView: View {
    struct QuickRange {
        let title: String
        let range: () -> (from: Date, to: Date)
    }

    static let quickRanges: [QuickRange] = [
        QuickRange(title: "Yesterday") {
            let day = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            return (day, day)
        },
        QuickRange(title: "Last 7 days") {
            (Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(), Date())
        },
        QuickRange(title: "Last 30 days") {
            (Calendar.current.date(byAdding: .day, value: -29, to: Date()) ?? Date(), Date())
        },
    ]

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
                // Android `QuickRanges`: the three ranges people ask for most, so the calendar is
                // only needed for anything else.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(CashFilterView.quickRanges, id: \.title) { preset in
                            let range = preset.range()
                            let isSelected = Calendar.current.isDate(filter.from, inSameDayAs: range.from)
                                && Calendar.current.isDate(filter.to, inSameDayAs: range.to)
                            Button {
                                filter.from = range.from
                                filter.to = range.to
                            } label: {
                                Text(preset.title).font(.caption)
                                    .padding(.horizontal, 11).padding(.vertical, 8)
                                    .foregroundStyle(isSelected ? CashStyle.green : CashStyle.ink)
                                    .background(isSelected ? CashStyle.pale : .white, in: Capsule())
                                    .overlay(Capsule().stroke(isSelected ? CashStyle.green : CashStyle.border))
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 2)
                }
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

/// Android `StatusPill`: approved is green, rejected red, pending amber, anything else grey.
/// The old badge only told pending from "everything else", so a rejected collection read green.
struct CashStatusPill: View {
    let status: String

    private var look: (label: String, fg: Color, bg: Color) {
        switch status.lowercased() {
        case "approved":
            return ("Approved", Color(hex: "15803D"), Color(hex: "DCFCE7"))
        case "rejected":
            return ("Rejected", Color(hex: "DC2626"), Color(hex: "FFF1F2"))
        case "pending":
            return ("Pending", Color(hex: "B45309"), Color(hex: "FEF3C7"))
        default:
            let text = status.isEmpty ? "—" : status.capitalized
            return (text, Color(hex: "4B5563"), Color(hex: "F3F4F6"))
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

/// Android `timeOf`: the server sends "2026-09-30 14:30:00", and older rows "30 Sep 2026, 02:30 PM".
/// iOS only handled the comma form, so a modern row showed no time at all.
enum LedgerTime {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private static let server = formatter("yyyy-MM-dd HH:mm:ss")
    private static let legacy = formatter("d MMM yyyy, hh:mm a")
    private static let display = formatter("h:mm a")

    static func date(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return server.date(from: text) ?? legacy.date(from: text)
    }

    /// The time alone, or nil when the value carries only a date.
    static func label(_ raw: String) -> String? {
        if let parsed = date(raw) { return display.string(from: parsed) }
        let tail = raw.components(separatedBy: ", ").dropFirst().joined(separator: ", ")
        return tail.trimmingCharacters(in: .whitespaces).isEmpty ? nil : tail
    }
}
