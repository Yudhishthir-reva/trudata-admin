import Foundation
import Combine

// Android `PackerViewModels.kt`, ported. Each list keeps its whole UI state in one struct (see
// PackerModels.swift) so the rules for counts, paging and search live where the checks can reach
// them; the view models only fetch and fold answers in. A newer search, filter or tab cancels the
// load in flight, so an old answer never lands on top of a new question.

/// Rows per board page: a screen and a half, so the next page loads before the end shows.
private let boardPageSize = 30
private let myPageSize = 30
private let searchDebounce: Duration = .milliseconds(400)

// MARK: - Packing board: hand orders to a packer, or move them to another one

final class AssignPackerViewModel: ObservableObject {
    @Published var state = AssignPackerUiState()
    private let service: PackerServiceManager
    private var loadTask: Task<Void, Never>?
    private var moreTask: Task<Void, Never>?
    private var sellerTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(service: PackerServiceManager = PackerServiceManager()) {
        self.service = service
        load()
        // A packer started, packed or reopened an order on this phone: its tab and the counts moved.
        NotificationCenter.default.publisher(for: .packingChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.load() }
            .store(in: &cancellables)
        Task { [weak self] in
            guard let self, let packers = try? await self.service.packers() else { return }
            self.state.packers = packers
        }
        Task { [weak self] in
            guard let self, let beats = try? await self.service.beats() else { return }
            self.state.allBeats = beats
        }
    }

    /// Every tab's count and the open tab's first page; while searching, every match.
    func load() { reload(withCounts: true) }

    /// `toFilledTab`: when the open tab comes back empty, move to the first tab that has orders.
    private func reload(withCounts: Bool, debounce: Bool = false, toFilledTab: Bool = false) {
        loadTask?.cancel()
        moreTask?.cancel()
        state.isLoading = true; state.error = nil; state.loadingMore = false; state.moreError = nil
        loadTask = Task { [weak self] in
            if debounce {
                do { try await Task.sleep(for: searchDebounce) } catch { return }
            }
            guard let self else { return }
            let s = self.state
            if s.searching { await self.loadMatches(s) } else { await self.loadTab(s, withCounts: withCounts, toFilledTab: toFilledTab) }
        }
    }

    private func query(_ s: AssignPackerUiState, status: Int?, billNo: String? = nil) -> BoardQuery {
        BoardQuery(status: status, beatId: s.beat?.id, date: s.date, billNo: billNo, seller: s.seller)
    }

    /// No counts field on the server yet: a one-row page per tab reads its total.
    private func tabCounts(_ s: AssignPackerUiState) async -> [BoardTab: Int] {
        let queries = BoardTab.allCases.map { ($0, query(s, status: $0.status)) }
        let service = self.service
        return await withTaskGroup(of: (BoardTab, Int?).self) { group in
            for (tab, q) in queries {
                group.addTask { (tab, try? await service.boardPage(q, page: 1, perPage: 1).total) }
            }
            var totals: [BoardTab: Int] = [:]
            for await (tab, n) in group { if let n { totals[tab] = n } }
            return totals
        }
    }

    private func loadTab(_ first: AssignPackerUiState, withCounts: Bool, toFilledTab: Bool) async {
        var s = first
        var totals: [BoardTab: Int] = [:]
        let page: PackPage<PackOrderDto>
        do {
            if withCounts && toFilledTab {
                totals = await tabCounts(first)
                guard !Task.isCancelled else { return }
                if (totals[s.tab] ?? 0) == 0, let filled = BoardTab.allCases.first(where: { (totals[$0] ?? 0) > 0 }) {
                    s.tab = filled
                    state.tab = filled; state.selected = []
                }
                page = try await service.boardPage(query(s, status: s.tab.status), page: 1, perPage: boardPageSize)
            } else if withCounts {
                async let counted = tabCounts(first)
                let rows = try await service.boardPage(query(s, status: s.tab.status), page: 1, perPage: boardPageSize)
                totals = await counted
                page = rows
            } else {
                page = try await service.boardPage(query(s, status: s.tab.status), page: 1, perPage: boardPageSize)
            }
        } catch {
            guard !Task.isCancelled else { return }
            state.isLoading = false; state.error = packerMessage(error)
            return
        }
        guard !Task.isCancelled else { return }
        let ids = Set(page.items.map(\.id))
        state.isLoading = false
        state.orders = page.items
        state.page = 1
        state.lastPage = page.lastPage
        state.counts.merge(totals) { _, new in new }
        state.counts[s.tab] = page.total
        // An order that moved on (another admin, or the packer) leaves the selection.
        state.selected = state.selected.filter { ids.contains($0) }
    }

    private func loadMatches(_ s: AssignPackerUiState) async {
        let text = s.query.trimmingCharacters(in: .whitespacesAndNewlines)
        // The box searches bill numbers; a picked seller, beat and date still apply.
        do {
            let found = try await service.boardMatches(query(s, status: nil, billNo: text)).distinctById().sorted { $0.id > $1.id }
            guard !Task.isCancelled else { return }
            // Open the first tab that has a match when the current one has none.
            let current = state.tab
            let tab = found.contains { $0.board == current } ? current
                : BoardTab.allCases.first { t in found.contains { $0.board == t } } ?? current
            var counts: [BoardTab: Int] = [:]
            for t in BoardTab.allCases { counts[t] = found.filter { $0.board == t }.count }
            state.isLoading = false
            state.orders = found
            state.tab = tab
            state.page = 1
            state.lastPage = 1
            state.counts = counts
            state.selected = state.selected.filter { id in found.contains { $0.id == id && $0.board == tab } }
        } catch {
            guard !Task.isCancelled else { return }
            state.isLoading = false; state.error = packerMessage(error); state.orders = []
        }
    }

    /// The open tab's next page, when the list nears its end.
    func loadMore() {
        let s = state
        guard s.canLoadMore, !s.loadingMore, !s.isLoading else { return }
        state.loadingMore = true; state.moreError = nil
        moreTask = Task { [weak self] in
            guard let self else { return }
            let next = s.page + 1
            do {
                let r = try await self.service.boardPage(self.query(s, status: s.tab.status), page: next, perPage: boardPageSize)
                guard !Task.isCancelled else { return }
                self.state.loadingMore = false
                self.state.page = next
                self.state.lastPage = r.lastPage
                self.state.orders = (self.state.orders + r.items).distinctById()
                self.state.counts[s.tab] = r.total
            } catch {
                guard !Task.isCancelled else { return }
                self.state.loadingMore = false; self.state.moreError = packerMessage(error)
            }
        }
    }

    func onTab(_ t: BoardTab) {
        guard state.tab != t else { return }
        // Drop the old tab's rows, or they'd sit under the new tab's name until its page lands.
        state.tab = t; state.selected = []
        if !state.searching {
            state.orders = []; state.page = 0; state.lastPage = 0
            // A search already holds every tab's matches; otherwise the new tab's first page.
            reload(withCounts: false)
        }
    }

    func onQuery(_ q: String) {
        let before = state.query
        state.query = q
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != before.trimmingCharacters(in: .whitespacesAndNewlines) {
            reload(withCounts: true, debounce: !trimmed.isEmpty)
        }
    }

    func setBeat(_ beat: PackBeat?) {
        guard state.beat?.id != beat?.id else { return }
        state.beat = beat
        reload(withCounts: true)
    }

    func setDate(_ date: PackDay?) {
        guard state.date != date else { return }
        state.date = date
        reload(withCounts: true)
    }

    func setSeller(_ seller: PackSeller?) {
        sellerTask?.cancel()
        state.sellerPick = nil
        guard state.seller?.id != seller?.id else { return }
        state.seller = seller
        reload(withCounts: true, toFilledTab: seller != nil)
    }

    // MARK: Seller picker

    func openSellerPicker() {
        let pick = state.sellerPick ?? SellerPickState()
        state.sellerPick = pick
        if pick.areas.isEmpty {
            Task { [weak self] in
                guard let self, let areas = try? await self.service.areas() else { return }
                self.updatePick { $0.areas = areas }
            }
        }
        if pick.sellers.isEmpty { loadSellers() }
    }

    func closeSellerPicker() {
        sellerTask?.cancel()
        state.sellerPick = nil
    }

    func sellerArea(stateId: Int?, cityId: Int?, beatId: Int?) {
        updatePick { $0.stateId = stateId; $0.cityId = cityId; $0.beatId = beatId }
        loadSellers()
    }

    func sellerQuery(_ q: String) {
        let before = state.sellerPick?.query ?? ""
        updatePick { $0.query = q }
        if q.trimmingCharacters(in: .whitespacesAndNewlines) != before.trimmingCharacters(in: .whitespacesAndNewlines) {
            loadSellers(debounce: true)
        }
    }

    private func updatePick(_ change: (inout SellerPickState) -> Void) {
        guard var pick = state.sellerPick else { return }
        change(&pick)
        state.sellerPick = pick
    }

    private func loadSellers(debounce: Bool = false) {
        sellerTask?.cancel()
        updatePick { $0.loading = true; $0.error = nil; $0.loadingMore = false }
        sellerTask = Task { [weak self] in
            if debounce {
                do { try await Task.sleep(for: searchDebounce) } catch { return }
            }
            guard let self, let p = self.state.sellerPick else { return }
            do {
                let r = try await self.service.sellers(stateId: p.stateId, cityId: p.cityId, beatId: p.beatId, search: p.query, page: 1)
                guard !Task.isCancelled else { return }
                self.updatePick { $0.loading = false; $0.sellers = r.items; $0.page = 1; $0.lastPage = r.lastPage; $0.total = r.total }
            } catch {
                guard !Task.isCancelled else { return }
                self.updatePick { $0.loading = false; $0.error = packerMessage(error); $0.sellers = [] }
            }
        }
    }

    /// The seller list's next page, as it nears its end.
    func moreSellers() {
        guard let p = state.sellerPick, p.canLoadMore, !p.loading, !p.loadingMore else { return }
        updatePick { $0.loadingMore = true }
        sellerTask = Task { [weak self] in
            guard let self else { return }
            let next = p.page + 1
            do {
                let r = try await self.service.sellers(stateId: p.stateId, cityId: p.cityId, beatId: p.beatId, search: p.query, page: next)
                guard !Task.isCancelled else { return }
                self.updatePick { pick in
                    var seen = Set<Int>()
                    pick.loadingMore = false; pick.page = next; pick.lastPage = r.lastPage
                    pick.sellers = (pick.sellers + r.items).filter { seen.insert($0.id).inserted }
                }
            } catch {
                guard !Task.isCancelled else { return }
                // Stop paging rather than retrying in a loop; reopening the picker starts again.
                self.updatePick { $0.loadingMore = false; $0.lastPage = $0.page }
            }
        }
    }

    // MARK: Selection and assigning

    func toggle(_ id: Int) {
        guard state.tab.canAssign else { return }
        if state.selected.contains(id) { state.selected.remove(id) } else { state.selected.insert(id) }
    }

    func toggleAllShown() {
        guard state.tab.canAssign else { return }
        let ids = Set(state.shown.map(\.id))
        if state.allShownSelected { state.selected.subtract(ids) } else { state.selected.formUnion(ids) }
    }

    func clearSelection() { state.selected = [] }

    /// Opens the packer sheet for one order's button, or for the ticked orders.
    func pickPackerFor(_ ids: Set<Int>) {
        guard !ids.isEmpty else { return }
        guard state.packers.isEmpty else { state.pickingFor = ids; return }
        // The first load may have lost the packer list; try once more before giving up.
        Task { [weak self] in
            guard let self else { return }
            do {
                let packers = try await self.service.packers()
                if packers.isEmpty {
                    self.state.dialogError = "There are no active packers. Add a staff member with the Paker role first."
                } else {
                    self.state.packers = packers; self.state.pickingFor = ids
                }
            } catch {
                self.state.dialogError = packerMessage(error)
            }
        }
    }

    func closePackerSheet() { state.pickingFor = nil }

    /// A packer picked in the sheet: ask before sending.
    func onPackerPicked(_ p: PackerDto) {
        guard let ids = state.pickingFor else { return }
        state.pickingFor = nil
        state.confirm = PendingAssign(packer: p, orderIds: ids, reassign: state.orders.contains { ids.contains($0.id) && $0.packerId != nil })
    }

    func cancelAssign() { state.confirm = nil }

    func confirmAssign() {
        guard let c = state.confirm, !state.assigning else { return }
        state.assigning = true
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.service.assign(packerId: c.packer.id, orderIds: c.orderIds)
                let n = "\(c.orderIds.count) \(c.orderIds.count == 1 ? "order" : "orders")"
                self.state.assigning = false
                self.state.confirm = nil
                self.state.selected.subtract(c.orderIds)
                self.state.done = c.reassign ? "\(n) moved to \(c.packer.name)" : "\(n) assigned to \(c.packer.name)"
                self.load()
            } catch {
                self.state.assigning = false; self.state.confirm = nil; self.state.dialogError = packerMessage(error)
            }
        }
    }

    // MARK: History

    func openLogs(_ order: PackOrderDto) {
        state.logsFor = order; state.logs = nil; state.logsError = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let logs = try await self.service.orderLogs(orderId: order.id)
                if self.state.logsFor?.id == order.id { self.state.logs = logs }
            } catch {
                if self.state.logsFor?.id == order.id { self.state.logsError = packerMessage(error) }
            }
        }
    }

    func closeLogs() { state.logsFor = nil; state.logs = nil; state.logsError = nil }

    func dismissError() { state.dialogError = nil }
}

// MARK: - The packer's own orders

final class PackerOrdersViewModel: ObservableObject {
    @Published var state = PackerOrdersUiState()
    private let service: PackerServiceManager
    private var userPickedTab = false
    private var loadTask: Task<Void, Never>?
    private var moreTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(service: PackerServiceManager = PackerServiceManager()) {
        self.service = service
        load()
        // Back from packing an order: reload the tab being looked at and every count, without
        // jumping to another tab under the packer's finger.
        NotificationCenter.default.publisher(for: .packingChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.userPickedTab = true
                self?.load()
            }
            .store(in: &cancellables)
    }

    func load() {
        restart { [weak self] in
            guard let self else { return }
            if self.state.searching { await self.loadAll() } else { await self.loadTab(withCounts: true) }
        }
    }

    private func restart(_ block: @escaping () async -> Void) {
        loadTask?.cancel()
        moreTask?.cancel()
        state.isLoading = true; state.error = nil; state.loadingMore = false; state.moreError = nil
        loadTask = Task { await block() }
    }

    private func loadTab(withCounts: Bool) async {
        if withCounts {
            // No counts field on the server yet: a one-row page per tab reads its total.
            let date = state.date
            let service = self.service
            let totals = await withTaskGroup(of: (PackStage, Int?).self) { group in
                for stage in PackStage.allCases {
                    group.addTask { (stage, try? await service.myPage(status: stage.status, page: 1, perPage: 1, date: date).total) }
                }
                var found: [PackStage: Int] = [:]
                for await (stage, n) in group { if let n { found[stage] = n } }
                return found
            }
            guard !Task.isCancelled else { return }
            state.counts.merge(totals) { _, new in new }
            // Open on work in progress first, then what's waiting.
            if !userPickedTab {
                let counts = state.counts
                state.tab = [PackStage.packing, .assigned, .packed].first { (counts[$0] ?? 0) > 0 } ?? .assigned
            }
        }
        let tab = state.tab
        do {
            let r = try await service.myPage(status: tab.status, page: 1, perPage: myPageSize, date: state.date)
            guard !Task.isCancelled else { return }
            state.isLoading = false; state.orders = r.items; state.page = 1; state.lastPage = r.lastPage
            state.counts[tab] = r.total
        } catch {
            guard !Task.isCancelled else { return }
            state.isLoading = false; state.error = packerMessage(error)
        }
    }

    private func loadAll() async {
        do {
            let all = try await service.myOrders(date: state.date)
            guard !Task.isCancelled else { return }
            state.isLoading = false; state.orders = all; state.page = 1; state.lastPage = 1
        } catch {
            guard !Task.isCancelled else { return }
            state.isLoading = false; state.error = packerMessage(error)
        }
    }

    /// The open tab's next page, when the list nears its end.
    func loadMore() {
        let s = state
        guard s.canLoadMore, !s.loadingMore, !s.isLoading else { return }
        state.loadingMore = true; state.moreError = nil
        moreTask = Task { [weak self] in
            guard let self else { return }
            let next = s.page + 1
            do {
                let r = try await self.service.myPage(status: s.tab.status, page: next, perPage: myPageSize, date: s.date)
                guard !Task.isCancelled else { return }
                self.state.loadingMore = false; self.state.page = next; self.state.lastPage = r.lastPage
                self.state.orders = (self.state.orders + r.items).distinctById()
                self.state.counts[s.tab] = r.total
            } catch {
                guard !Task.isCancelled else { return }
                self.state.loadingMore = false; self.state.moreError = packerMessage(error)
            }
        }
    }

    func onQuery(_ q: String) {
        let wasSearching = state.searching
        state.query = q
        let searching = state.searching
        // Only starting or ending a search needs the server; letters in between filter what's loaded.
        if searching && !wasSearching {
            restart { [weak self] in await self?.loadAll() }
        } else if !searching && wasSearching {
            restart { [weak self] in await self?.loadTab(withCounts: false) }
        }
    }

    func setDate(_ date: PackDay?) {
        guard state.date != date else { return }
        state.date = date; state.orders = []; state.counts = [:]
        load()
    }

    func onTab(_ tab: PackStage) {
        userPickedTab = true
        guard state.tab != tab else { return }
        state.tab = tab
        // Drop the old tab's rows, or they'd sit under the new tab's name until its page lands.
        if !state.searching {
            state.orders = []; state.page = 0; state.lastPage = 0
            restart { [weak self] in await self?.loadTab(withCounts: false) }
        }
    }
}

// MARK: - Packing one order

/// Which action is running.
enum PackBusy: Equatable { case start, box, item, complete, remove, delete, reopen }

final class PackOrderViewModel: ObservableObject {
    let orderId: Int
    @Published var detail: PackOrderDetail?
    @Published var isLoading = true
    @Published var error: String?
    @Published var busy: PackBusy?
    @Published var dialogError: String?
    @Published var message: String?
    private let service: PackerServiceManager

    init(orderId: Int, service: PackerServiceManager = PackerServiceManager()) {
        self.orderId = orderId
        self.service = service
        load()
    }

    func load() {
        isLoading = detail == nil; error = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let d = try await self.service.orderDetail(orderId: self.orderId)
                self.isLoading = false; self.detail = d
            } catch {
                self.isLoading = false; self.error = packerMessage(error)
            }
        }
    }

    func startPacking() { run(.start, "Packing started") { [service, orderId] in try await service.startPacking(orderId: orderId) } }

    func newBox() { run(.box, "Box added") { [service, orderId] in try await service.createPackage(orderId: orderId) } }

    /// Sets `line`'s quantity in `box` to `qty`: the server replaces the box's row for that line,
    /// so this is the box's new total. Zero takes the line out of the box.
    func setItem(box: PackBox, line: PackLine, qty: Int) {
        let inBox = box.qtyOf(line.id)
        guard qty != inBox else { return }
        let max = inBox + line.left
        if detail?.packedKnown != false && qty > max {
            dialogError = "Only \(max) of \(line.name) can go in \(box.name)."
            return
        }
        if qty <= 0 {
            if let item = box.items.first(where: { $0.orderDetailId == line.id }) { removeItem(box: box, item: item) }
            return
        }
        run(.item, "\(box.name): \(qty) × \(line.name)") { [service] in
            try await service.setPackageItem(packageId: box.id, orderDetailId: line.id, qty: qty)
        }
    }

    func completePacking() {
        if let d = detail, d.packedKnown, !d.lines.isEmpty, !d.allPacked {
            dialogError = "Pack every item first: \(d.unitsLeft) still left."
            return
        }
        run(.complete, "Order packed") { [service, orderId] in try await service.completePacking(orderId: orderId) }
    }

    func removeItem(box: PackBox, item: PackBoxItem) {
        let name = item.name.isEmpty ? "item" : item.name
        run(.remove, "Removed \(name) from \(box.name)") { [service] in try await service.removePackageItem(packageItemId: item.id) }
    }

    func deleteBox(_ box: PackBox) {
        guard box.isEmpty else {
            dialogError = "Take the items out of \(box.name) first."
            return
        }
        run(.delete, "\(box.name) deleted") { [service] in try await service.deletePackage(packageId: box.id) }
    }

    /// start-packing on a packed order reopens it.
    func reopen() { run(.reopen, "Packing reopened") { [service, orderId] in try await service.startPacking(orderId: orderId) } }

    private func run(_ key: PackBusy, _ okMessage: String, _ call: @escaping () async throws -> String?) {
        guard busy == nil else { return }
        busy = key
        Task { [weak self] in
            do {
                let said = try await call()
                guard let self else { return }
                self.busy = nil
                self.message = said ?? okMessage
                self.load()
                // Lists and counts elsewhere show this order's status and weights.
                NotificationCenter.default.post(name: .packingChanged, object: nil)
            } catch {
                self?.busy = nil
                self?.dialogError = packerMessage(error)
            }
        }
    }
}

// MARK: - Home cards

/// Counts for the home cards: the packer's own queue, and pending orders still without a packer.
final class PackerWidgetViewModel: ObservableObject {
    @Published var state = PackerWidgetState()
    private let service: PackerServiceManager
    private var showsMine = false
    private var showsPending = false
    private var cancellables = Set<AnyCancellable>()

    init(service: PackerServiceManager = PackerServiceManager()) {
        self.service = service
        NotificationCenter.default.publisher(for: .packingChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.showsMine { Task { await self.loadMine() } }
                if self.showsPending { Task { await self.loadPending() } }
            }
            .store(in: &cancellables)
    }

    /// A one-row page per stage: the server's totals are the counts, the same ones My Packing's tabs show.
    func loadMine() async {
        showsMine = true
        let service = self.service
        let totals = await withTaskGroup(of: (PackStage, Int?).self) { group in
            for stage in PackStage.allCases {
                group.addTask { (stage, try? await service.myPage(status: stage.status, page: 1, perPage: 1).total) }
            }
            var found: [PackStage: Int?] = [:]
            for await (stage, n) in group { found[stage] = n }
            return found
        }
        if totals.values.contains(where: { $0 == nil }) {
            state.loading = false; state.failed = true
        } else {
            state.loading = false; state.failed = false
            state.toPack = (totals[.assigned] ?? 0) ?? 0
            state.packing = (totals[.packing] ?? 0) ?? 0
            state.packed = (totals[.packed] ?? 0) ?? 0
        }
    }

    /// A one-row page: the server's total is the count, without fetching the orders.
    func loadPending() async {
        showsPending = true
        do {
            let r = try await service.boardPage(BoardQuery(status: PackStage.statusPending), page: 1, perPage: 1)
            state.loading = false; state.failed = false; state.pending = r.total
        } catch {
            state.loading = false; state.failed = true
        }
    }
}
