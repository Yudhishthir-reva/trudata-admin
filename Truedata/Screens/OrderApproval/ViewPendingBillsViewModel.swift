//
//  ViewPendingBillsViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

/// A seller's bills (`view-pending-payment-bill-list`), ported from Android `PendingBillsViewModel`.
/// The server pages them, so every page is fetched up front and search and filters run on the
/// phone over the whole list.
final class ViewPendingBillsViewModel: ObservableObject {

    let sellerId: Int
    let staffId: Int
    /// The name the caller knew; shown only until the first page says whose bills these are.
    let sellerName: String

    @Published private(set) var bills: [PendingPaymentBill] = [] { didSet { renarrow() } }
    @Published private(set) var labels = PendingBillLabels()
    /// Bills the server has in all, while later pages are still on their way.
    @Published private(set) var serverTotal = 0
    @Published private(set) var isLoading = true
    /// First page shown, the rest still loading; search and filters only see what has arrived.
    @Published private(set) var isLoadingRest = false
    @Published private(set) var errorMessage: String?
    /// A later page failed; what loaded stays, and retrying carries on from there.
    @Published private(set) var restError: String?
    @Published var query = "" { didSet { if query != oldValue { renarrow() } } }
    @Published private(set) var filter = PendingBillsFilter() { didSet { if filter != oldValue { renarrow() } } }
    @Published private(set) var tab = PendingBillStatusKey.pending
    /// Search and filters applied, every status. Kept rather than computed: the list can run to
    /// hundreds of bills and the body reads it several times per pass.
    @Published private(set) var narrowed: [PendingPaymentBill] = []

    private let service = ViewPendingBillsServiceManager()
    private var loadCancellable: AnyCancellable?
    private var nextPage = 1
    private var lastPage = 1
    /// Until the user picks a tab, the screen sits on the first status that has bills.
    private var userPickedTab = false

    /// Asked for; a server that ignores it pages by 10, and every page is still fetched.
    private let perPage = 100
    /// A guard against a server that never reports its last page.
    private let maxPages = 200

    init(sellerId: Int, staffId: Int, sellerName: String) {
        self.sellerId = sellerId
        self.staffId = staffId
        self.sellerName = sellerName
    }

    // MARK: - Derived

    var isComplete: Bool { !isLoading && !isLoadingRest && restError == nil }
    var isNarrowing: Bool { filter.isActive || !query.trimmingCharacters(in: .whitespaces).isEmpty }

    /// What the list shows: `narrowed` in the selected tab.
    var shown: [PendingPaymentBill] { narrowed.filter { $0.statusKey == tab } }

    func count(in status: String) -> Int { narrowed.filter { $0.statusKey == status }.count }

    /// The one shop every bill belongs to, or nil for a mixed list (or none yet).
    var singleSeller: String? {
        let names = bills.choices { $0.sellerName }
        return names.count == 1 ? names[0] : nil
    }

    var title: String {
        if let singleSeller { return "\(singleSeller) · Bills" }
        if bills.isEmpty && isLoading && !sellerName.isEmpty { return "\(sellerName) · Bills" }
        return "Pending Bills"
    }

    private func renarrow() { narrowed = bills.narrow(query, filter) }

    // MARK: - Loading

    /// From the first page; the bills on screen stay until the new first page lands.
    func load() {
        loadCancellable?.cancel()
        nextPage = 1
        isLoading = bills.isEmpty
        errorMessage = nil
        restError = nil
        guard sellerId > 0 else {
            isLoading = false
            errorMessage = "Seller is missing. Cannot load bills."
            return
        }
        fetch(first: true)
    }

    /// After a later page failed: carry on from it.
    func retryRest() {
        guard !isLoadingRest else { return }
        restError = nil
        fetch(first: false)
    }

    private func fetch(first: Bool) {
        let page = nextPage
        isLoadingRest = !first
        loadCancellable = service.getPendingPaymentBills(sellerId: sellerId, staffId: staffId, page: page, perPage: perPage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self, case .failure(let error) = completion else { return }
                let message = (error as? RequestError)?.errorString ?? error.localizedDescription
                self.fail(first: first, message: message.isEmpty ? "Couldn't load the bills" : message)
            } receiveValue: { [weak self] response in
                self?.receive(response, page: page, first: first)
            }
    }

    private func fail(first: Bool, message: String) {
        isLoadingRest = false
        if first {
            isLoading = false
            errorMessage = message
        } else {
            restError = message
        }
    }

    /// Like Android, a reply is taken for what it holds: `status: false` with no bills is a seller
    /// with nothing to show (the "No bills" state), not an error. Only a failed request is one.
    private func receive(_ response: PendingPaymentBillsResponse, page: Int, first: Bool) {
        let list = response.data.response.billList
        lastPage = max(list.lastPage, response.data.lastPage, 1)
        nextPage = page + 1

        if first {
            bills = list.data
        } else {
            var seen = Set(bills.map(\.id))
            bills += list.data.filter { seen.insert($0.id).inserted }
        }
        labels = PendingBillLabels(
            paymentModes: response.data.paymentModeMap.isEmpty ? labels.paymentModes : response.data.paymentModeMap,
            orderStatuses: response.data.orderStatusMap.isEmpty ? labels.orderStatuses : response.data.orderStatusMap
        )
        serverTotal = max(list.total, response.data.total, bills.count)
        isLoading = false
        errorMessage = nil
        settleTab()

        // Stop on the last page, or if a page came back empty (nothing further to find).
        if page >= lastPage || list.data.isEmpty || page >= maxPages {
            isLoadingRest = false
        } else {
            fetch(first: false)
        }
    }

    // MARK: - Search, filters, tab

    func setFilter(_ f: PendingBillsFilter) { filter = f }

    func clearFilters() {
        filter = PendingBillsFilter(sort: filter.sort)
        query = ""
    }

    func setTab(_ key: String) {
        userPickedTab = true
        tab = key
    }

    private func settleTab() {
        guard !userPickedTab, count(in: tab) == 0 else { return }
        if let first = PendingBillStatusKey.all.first(where: { count(in: $0) > 0 }) { tab = first }
    }
}
