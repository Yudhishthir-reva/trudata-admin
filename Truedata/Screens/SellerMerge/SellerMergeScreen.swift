import SwiftUI

struct SellerMergeScreen: View {
    var onHome: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = SellerMergeViewModel()
    @State private var tab = "New merge"
    @State private var picker: MergePickerSlot?
    @State private var confirming = false
    private var step: Int { model.outcome != nil ? 2 : model.preview != nil ? 1 : 0 }
    private var records: Int { model.preview?["other_records"]?["total_records_to_move"]?.intValue ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            header
            if SellerMergeAccess.allowed {
                CashTabs(titles: ["New merge", "History"], selection: $tab).padding(.horizontal, 16).padding(.top, 10)
                    .disabled(model.busy)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if tab == "History" { historyContent }
                        else {
                            MergeHero(step: step)
                            if let outcome = model.outcome { success(outcome) }
                            else { selectionContent }
                        }
                    }.padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                VStack(spacing: 6) {
                    Text("Seller Merge isn't available").font(.headline)
                    Text("It's open to Admin, Sales Manager and Accountant.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding()
                Spacer()
            }
        }
        .background(Color(red: 0.97, green: 0.98, blue: 0.97))
        .tint(CashStyle.green)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if SellerMergeAccess.allowed && tab == "New merge" { footer }
        }
        .task(id: tab) { if tab == "History" { await model.loadHistory() } }
        .sheet(item: $picker) { slot in
            SellerMergePicker(model: model, keeping: slot == .primary) { picker = nil }
                .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .confirmationDialog("Merge these sellers?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Merge sellers", role: .destructive) { Task { await model.execute() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            // "All records will move" reads wrong when the duplicate has none; Android states the
            // actual count and says plainly when there is nothing to move.
            let from = model.secondary?.title ?? "the duplicate"
            let into = model.primary?.title ?? "the kept seller"
            let moving = records == 0
                ? "\(from) has no records to move."
                : "\(records.formatted()) record\(records == 1 ? "" : "s") of \(from) will move to \(into)."
            Text("\(moving) \(from) will be deactivated. This can't be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: { Image(systemName: "arrow.left") }.accessibilityLabel("Back")
            Text("Seller Merge").font(.title3.bold())
            Spacer()
            if tab == "History" {
                Button { Task { await model.loadHistory() } } label: { Image(systemName: "arrow.clockwise") }
                    .accessibilityLabel("Refresh history").disabled(model.historyLoading)
            }
            Button(action: onHome) { Image(systemName: "house.fill") }.accessibilityLabel("Home")
        }.font(.title3).foregroundStyle(.white).padding(18)
            .background(CashStyle.gradient, in: UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20))
            .background(CashStyle.gradient.ignoresSafeArea(edges: .top))
            .disabled(model.busy)
    }

    @ViewBuilder private var selectionContent: some View {
        sellerSlot(.secondary, seller: model.secondary)
        HStack(spacing: 12) {
            Rectangle().fill(CashStyle.border).frame(height: 1)
            Label("moves into", systemImage: "arrow.down").font(.subheadline).fixedSize()
                .padding(10).background(.white, in: Capsule())
            Rectangle().fill(CashStyle.border).frame(height: 1)
            Button { model.swap() } label: {
                Image(systemName: "arrow.up.arrow.down").font(.title3).padding(12).background(CashStyle.pale, in: Circle())
            }.disabled(model.busy || (model.primary == nil && model.secondary == nil)).accessibilityLabel("Swap sellers")
        }
        sellerSlot(.primary, seller: model.primary)
        if let error = model.error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red).font(.subheadline) }
        if let preview = model.preview {
            MergePanel {
                HStack {
                    Image(systemName: "folder.badge.arrow.forward").font(.title2).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("RECORDS TO MOVE").font(.caption).foregroundStyle(.secondary)
                        Text(records.formatted()).font(.largeTitle.bold())
                    }
                    Spacer()
                    MergeBadge(text: "Preview", color: .blue)
                }
                HStack(alignment: .center, spacing: 8) {
                    if let seller = model.secondary { MergeMiniSeller(seller: seller, color: .orange) }
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    if let seller = model.primary { MergeMiniSeller(seller: seller, color: CashStyle.green) }
                }
            }
            MergeSummary(preview: preview, records: records)
            MergePanel {
                Label("Merge note", systemImage: "square.and.pencil").font(.headline)
                Text("Optional · kept with this merge in History").font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .top) {
                    TextField("e.g. Duplicate entry – same shop", text: $model.notes, axis: .vertical).lineLimit(3...5)
                    SpeechRemarkButton(text: $model.notes)
                }.padding(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border))
                    .onChange(of: model.notes) { _, value in model.notes = String(value.prefix(500)) }
            }.disabled(model.busy)
            Label("This can't be undone. \(model.secondary?.title ?? "The duplicate") will be deactivated and all its records will belong to \(model.primary?.title ?? "the seller you keep").", systemImage: "exclamationmark.triangle")
                .font(.subheadline).foregroundStyle(.red).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.2)))
        } else {
            Label("Choose the duplicate seller and the seller to keep, then review the records before merging.", systemImage: "info.circle")
                .font(.subheadline).foregroundStyle(.blue).padding(16)
                .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func sellerSlot(_ slot: MergePickerSlot, seller: MergeSeller?) -> some View {
        let keeping = slot == .primary
        let color = keeping ? CashStyle.green : Color(red: 0.75, green: 0.31, blue: 0.14)
        return MergePanel(border: color.opacity(0.3)) {
            HStack {
                Text(keeping ? "KEEP THIS SELLER" : "DUPLICATE · MERGE FROM").font(.caption.weight(.medium)).foregroundStyle(color)
                Spacer(minLength: 4)
                MergeBadge(text: keeping ? "Primary" : "Deactivates", color: keeping ? CashStyle.green : .orange)
            }
            HStack(alignment: .top, spacing: 10) {
                Button { model.query = ""; picker = slot } label: {
                    if let seller { MergeSellerRow(seller: seller, color: color) }
                    else {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "storefront.fill").font(.title2).foregroundStyle(color).frame(width: 44, height: 50)
                                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(keeping ? "Choose the seller to keep" : "Choose the duplicate seller").font(.headline)
                                Text(keeping ? "It keeps its seller ID, name and details." : "Its records move to the seller you keep, then it's deactivated.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Text("Choose").font(.subheadline.weight(.semibold)).foregroundStyle(color)
                        }
                    }
                }.buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                if seller != nil {
                    Button {
                        if keeping { model.primary = nil } else { model.secondary = nil }
                        model.preview = nil; model.error = nil
                    } label: { Image(systemName: "xmark").padding(8).foregroundStyle(.secondary) }
                        .accessibilityLabel(keeping ? "Clear kept seller" : "Clear duplicate seller")
                }
            }.disabled(model.busy)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule().fill(CashStyle.border).frame(width: 34, height: 4).frame(maxWidth: .infinity)
            if model.outcome != nil {
                HStack(spacing: 12) {
                    Button { tab = "History" } label: { Label("History", systemImage: "clock.arrow.circlepath").frame(maxWidth: .infinity).padding(.vertical, 16) }
                        .background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 15))
                    Button { model.startOver() } label: {
                        Label("New merge", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(.vertical, 16)
                    }.foregroundStyle(.white).background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 15))
                }.font(.headline).buttonStyle(.plain)
            } else {
                if model.preview != nil {
                    Text("Records to move").font(.subheadline).foregroundStyle(.secondary)
                    Text(records.formatted()).font(.title.bold())
                }
                Button {
                    if model.preview != nil { confirming = true }
                    else { Task { await model.review() } }
                } label: {
                    HStack {
                        if model.busy { ProgressView().tint(.white) }
                        else { Image(systemName: model.preview == nil ? "checklist" : "arrow.triangle.merge") }
                        Text(model.preview == nil ? "Review merge" : "Merge sellers")
                    }.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 18)
                }.buttonStyle(.plain).foregroundStyle(.white)
                    .background(model.preview == nil ? CashStyle.green : .red, in: RoundedRectangle(cornerRadius: 16))
                    .opacity(model.busy || (model.preview == nil && !model.canReview) ? 0.45 : 1)
                    .disabled(model.busy || (model.preview == nil && !model.canReview))
            }
        }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
            .background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
    }

    private func success(_ outcome: SellerMergeOutcome) -> some View {
        MergePanel(border: CashStyle.green.opacity(0.25)) {
            VStack(spacing: 20) {
                Image(systemName: "checkmark").font(.system(size: 34, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 76, height: 76).background(CashStyle.gradient, in: Circle())
                Text("Sellers merged").font(.title2.bold())
                Text("\(outcome.secondary.title) is now inactive, and its records belong to \(outcome.primary.title).")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text(outcome.recordsMoved.formatted()).font(.system(size: 38, weight: .medium)).foregroundStyle(CashStyle.green)
                Text("records moved").font(.subheadline).foregroundStyle(.secondary)
                MergeSellerRow(seller: outcome.secondary, color: .red, badge: "Deactivated", compact: true).padding(12).background(CashStyle.pale.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                Image(systemName: "arrow.down").foregroundStyle(.secondary)
                MergeSellerRow(seller: outcome.primary, color: CashStyle.green, badge: "Kept", compact: true).padding(12).background(CashStyle.pale.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
            }.padding(.vertical, 16).frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var historyContent: some View {
        Text("\(model.historyTotal.formatted()) merges").font(.subheadline).foregroundStyle(.secondary)
        if let error = model.historyError {
            Text(error).foregroundStyle(.red)
            Button("Retry") { Task { await model.loadHistory() } }
        }
        if model.historyLoading { ProgressView().frame(maxWidth: .infinity) }
        if model.history.isEmpty && !model.historyLoading && model.historyError == nil {
            ContentUnavailableView("No merges yet", systemImage: "clock.arrow.circlepath", description: Text("Completed merges will appear here."))
        }
        ForEach(model.history, id: \.mergeHistoryID) { entry in MergeHistoryCard(entry: entry) }
        if model.historyHasMore { Button("Load more") { Task { await model.loadHistory(more: true) } }.disabled(model.historyLoading) }
    }
}

private extension JSONValue {
    var mergeHistoryID: Int { self["id"]?.intValue ?? 0 }
}

private struct MergePanel<Content: View>: View {
    var border: Color = CashStyle.border
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16, content: content).padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(border))
    }
}

private struct MergeBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(color).padding(.horizontal, 11).padding(.vertical, 8)
            .background(color.opacity(0.12), in: Capsule()).fixedSize(horizontal: true, vertical: false)
    }
}

private struct MergeHero: View {
    let step: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SELLER MERGE").font(.caption.weight(.medium)).opacity(0.75)
            Text("Combine duplicate sellers").font(.title2.bold())
            Text("Keep one seller and move a duplicate's records into it.").font(.subheadline).opacity(0.85)
            HStack(spacing: 0) {
                ForEach(0..<3) { index in
                    if index > 0 { Rectangle().fill(.white.opacity(step >= index ? 0.85 : 0.25)).frame(height: 2) }
                    ZStack {
                        Circle().fill(index <= step ? .white : .clear)
                        Circle().stroke(.white.opacity(0.6), lineWidth: 1.5)
                        if index < step || step == 2 { Image(systemName: "checkmark").foregroundStyle(CashStyle.green) }
                        else { Text("\(index + 1)").foregroundStyle(index == step ? CashStyle.green : .white) }
                    }.frame(width: 30, height: 30)
                }
            }.padding(.top, 12)
            HStack {
                Text("Choose sellers"); Spacer(); Text("Review"); Spacer(); Text("Merged")
            }.font(.caption.weight(.medium))
        }.foregroundStyle(.white).padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(CashStyle.gradient, in: RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)
    }
}

private struct MergeSellerRow: View {
    let seller: MergeSeller
    let color: Color
    var badge: String? = nil
    var compact = false
    private var owner: String { seller.json["name"]?.stringValue ?? "" }
    private var place: String { ["beat", "city"].compactMap { seller.json[$0]?.stringValue }.filter { !$0.isEmpty }.joined(separator: ", ") }
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MergeAvatar(seller: seller, color: color)
            VStack(alignment: .leading, spacing: 5) {
                Text(seller.title).font(.subheadline.weight(.semibold)).foregroundStyle(CashStyle.ink).fixedSize(horizontal: false, vertical: true)
                if !owner.isEmpty && owner != seller.title { Label(owner, systemImage: "person.fill").font(.caption).foregroundStyle(.secondary) }
                if !seller.phone.isEmpty { Label(seller.phone, systemImage: "phone.fill").font(.caption).foregroundStyle(.secondary) }
                if !compact && !place.isEmpty { Label(place, systemImage: "mappin.circle.fill").font(.caption).foregroundStyle(.secondary) }
                if !compact && !seller.isActive { MergeBadge(text: "Inactive", color: .gray) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let badge { MergeBadge(text: badge, color: color) }
        }
    }
}

private struct MergeAvatar: View {
    let seller: MergeSeller
    let color: Color
    var body: some View {
        Text(seller.title.split(whereSeparator: \.isWhitespace).prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased())
            .font(.subheadline.weight(.semibold)).foregroundStyle(.white).frame(width: 42, height: 46)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 12)).accessibilityHidden(true)
    }
}

private struct MergeMiniSeller: View {
    let seller: MergeSeller
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MergeAvatar(seller: seller, color: color)
            Text(seller.title).font(.caption.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            if !seller.phone.isEmpty { Text(seller.phone).font(.caption2).foregroundStyle(.secondary) }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct MergeSummary: View {
    let preview: JSONValue
    let records: Int
    private let groups = [("order_summary", "Orders"), ("payment_summary", "Payments & bills"), ("cheque_summary", "Cheques"), ("retailer_payment_requests", "Retailer payment requests"), ("bill_settlement", "Bill settlements"), ("other_records", "Other records")]
    var body: some View {
        MergePanel {
            Label(records == 0 ? "Nothing to move" : "What will move", systemImage: records == 0 ? "checkmark.circle" : "tray.and.arrow.down").font(.headline)
            if records == 0 {
                Text("The duplicate has no records here").font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135))], alignment: .leading, spacing: 8) {
                    ForEach(groups, id: \.0) { _, title in
                        Text(title).font(.caption).padding(10).frame(maxWidth: .infinity)
                            .background(CashStyle.pale.opacity(0.5), in: Capsule())
                    }
                }
            } else {
                ForEach(groups, id: \.0) { key, title in
                    if let value = preview[key] {
                        DisclosureGroup(title) { MergeRecordValues(value: value) }.font(.subheadline)
                    }
                }
            }
        }
    }
}

private struct MergeHistoryCard: View {
    let entry: JSONValue
    @State private var expanded = false
    var body: some View {
        MergePanel {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrow.triangle.merge").foregroundStyle(CashStyle.green).padding(11).background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry["merged_at"]?.stringValue ?? "").font(.subheadline.weight(.semibold))
                    Text("Merged by \(entry["merged_by"]?["name"]?.stringValue ?? "—")").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                MergeBadge(text: "\(entry["total_records_moved"]?.intValue ?? 0) records", color: .blue)
            }
            if let value = entry["secondary_seller"], case .object = value {
                MergeSellerRow(seller: MergeSeller(json: value), color: .red, badge: "Merged", compact: true)
                    .padding(10).background(CashStyle.pale.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
            }
            Image(systemName: "arrow.down").foregroundStyle(.secondary).frame(maxWidth: .infinity)
            if let value = entry["primary_seller"], case .object = value {
                MergeSellerRow(seller: MergeSeller(json: value), color: CashStyle.green, badge: "Kept", compact: true)
                    .padding(10).background(CashStyle.pale.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
            }
            if let notes = entry["notes"]?.stringValue, !notes.isEmpty { Text(notes).font(.subheadline).foregroundStyle(.secondary) }
            DisclosureGroup(expanded ? "Hide details" : "What moved", isExpanded: $expanded) {
                if let moved = entry["records_moved"], moved.objectValue.values.contains(where: { $0.intValue > 0 }) {
                    MergeRecordValues(value: moved, nonzeroOnly: true)
                } else { Text("No records moved.").font(.subheadline).foregroundStyle(.secondary).padding(.top, 8) }
            }.font(.subheadline.weight(.medium))
        }
    }
}

private enum MergePickerSlot: String, Identifiable {
    case primary, secondary
    var id: String { rawValue }
}

private struct SellerMergePicker: View {
    @ObservedObject var model: SellerMergeViewModel
    let keeping: Bool
    let close: () -> Void
    private var accent: Color { keeping ? CashStyle.green : .orange }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "storefront.fill").foregroundStyle(accent).padding(12).background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 6) {
                    Text(keeping ? "Choose the seller to keep" : "Choose the duplicate seller").font(.headline)
                    Text(keeping ? "It keeps its seller ID, name and details." : "Its records move to the seller you keep, then it's deactivated.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button(action: close) { Image(systemName: "xmark").padding(8) }.foregroundStyle(.secondary).accessibilityLabel("Close seller picker")
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Shop, seller or mobile", text: $model.query).autocorrectionDisabled()
                if !model.query.isEmpty { Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
            }.padding(14).overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border))
            HStack(alignment: .top, spacing: 8) {
                MergeAreaDropdown(title: "STATE", fallback: "All states", options: model.states.map { CashDropdownOption(id: String($0.id), title: $0.name) }, selection: Binding(get: { model.stateID }, set: { model.stateID = $0; model.cityID = ""; model.beatID = "" }))
                MergeAreaDropdown(title: "CITY", fallback: "All cities", options: model.cities.map { CashDropdownOption(id: String($0.id), title: $0.name) }, selection: Binding(get: { model.cityID }, set: { model.cityID = $0; model.beatID = "" }))
                MergeAreaDropdown(title: "BEAT", fallback: "All beats", options: model.beats.map { CashDropdownOption(id: String($0.id), title: $0.name) }, selection: $model.beatID)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("\(model.sellerTotal.formatted()) sellers").font(.subheadline).foregroundStyle(.secondary)
                    if let error = model.searchError {
                        Text(error).font(.subheadline).foregroundStyle(.red)
                        Button("Retry") { Task { await model.loadAreas(); await model.search() } }
                    }
                    if model.searching { ProgressView().frame(maxWidth: .infinity) }
                    if !model.searching && model.sellers.isEmpty && model.searchError == nil { Text("No sellers found.").foregroundStyle(.secondary) }
                    ForEach(model.sellers) { seller in
                        let alreadyChosen = seller.id == (keeping ? model.secondary?.id : model.primary?.id)
                        let inactive = keeping && !seller.isActive
                        Button {
                            model.pick(seller, keeping: keeping); close()
                        } label: {
                            MergePanel {
                                MergeSellerRow(seller: seller, color: accent)
                                if alreadyChosen {
                                    Text(keeping ? "Already chosen as the duplicate" : "Already chosen as the seller to keep").font(.caption).foregroundStyle(.orange)
                                } else if inactive { Text("Inactive sellers can't be kept").font(.caption).foregroundStyle(.orange) }
                            }.opacity(alreadyChosen || inactive ? 0.6 : 1)
                        }.buttonStyle(.plain).disabled(alreadyChosen || inactive || model.searching)
                    }
                    if model.sellerHasMore { Button("Load more sellers") { Task { await model.search(more: true) } }.disabled(model.searching) }
                }.padding(.bottom, 12)
            }.scrollDismissesKeyboard(.interactively)
        }.padding(.horizontal, 16).padding(.top, 24).background(Color.white).tint(CashStyle.green)
            .task { await model.loadAreas() }
            .task(id: model.searchKey) {
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                await model.search()
            }
    }
}

private struct MergeAreaDropdown: View {
    let title: String
    let fallback: String
    let options: [CashDropdownOption]
    @Binding var selection: String
    @State private var presented = false
    @State private var query = ""
    private var allOptions: [CashDropdownOption] { [CashDropdownOption(id: "", title: fallback)] + options }
    var body: some View {
        Button { query = ""; presented = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.caption2.weight(.medium))
                HStack(spacing: 4) {
                    Text(allOptions.first { $0.id == selection }?.title ?? fallback).font(.subheadline).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.caption2)
                }
            }.foregroundStyle(selection.isEmpty ? CashStyle.muted : CashStyle.green).padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(selection.isEmpty ? Color.white : CashStyle.pale, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(selection.isEmpty ? CashStyle.border : CashStyle.green.opacity(0.4)))
        }.buttonStyle(.plain)
            .accessibilityLabel("\(title): \(allOptions.first { $0.id == selection }?.title ?? fallback)")
            .sheet(isPresented: $presented) {
                NavigationStack {
                    List(allOptions.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { option in
                        Button { selection = option.id; presented = false } label: {
                            HStack {
                                Text(option.title).foregroundStyle(CashStyle.ink)
                                Spacer()
                                if selection == option.id { Image(systemName: "checkmark").foregroundStyle(CashStyle.green) }
                            }.padding(.vertical, 6)
                        }
                    }.searchable(text: $query, prompt: "Search \(title.lowercased())")
                        .navigationTitle("Choose \(title.lowercased())").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { presented = false } } }
                }.tint(CashStyle.green)
            }
    }
}

private struct MergeRecordValues: View {
    let value: JSONValue
    var nonzeroOnly = false
    var body: some View {
        VStack(spacing: 8) {
            ForEach(value.objectValue.keys.sorted(), id: \.self) { key in
                if let item = value[key], key != "total_records_to_move" {
                    if !item.objectValue.isEmpty {
                        Text(mergeLabel(key)).font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(item.objectValue.keys.sorted(), id: \.self) { child in
                            LabeledContent(mergeLabel(child), value: item[child]?.stringValue ?? "0")
                        }
                    } else if !item.stringValue.isEmpty && (!nonzeroOnly || item.intValue > 0) {
                        LabeledContent(mergeLabel(key), value: display(item, key: key))
                            .padding(12).background(CashStyle.pale.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }.font(.subheadline).foregroundStyle(CashStyle.ink).padding(.top, 10)
    }
    private func display(_ item: JSONValue, key: String) -> String {
        if key.contains("amount") || key == "total_order_value" || key == "total_collected" {
            return item.doubleValue.formatted(.currency(code: "INR").locale(Locale(identifier: "en_IN")))
        }
        return item.stringValue
    }
}

private func mergeLabel(_ key: String) -> String {
    key.replacingOccurrences(of: "tbl_", with: "").replacingOccurrences(of: "_", with: " ").capitalized
}
