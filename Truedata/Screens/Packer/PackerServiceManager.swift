import Foundation
import Combine

/// The packer endpoints sit at the API root (`paker-list`, `paker/my-orders`, …), not under
/// `APIRouter`. The lists and writes are JSON POSTs; the server refuses query strings, so filters
/// and paging go in the body. The three reads by id are GETs with the id in the path, and carry no
/// body (a GET with one is dropped by URLSession).
struct PackerEndpoint: RouterManagable {
    let endPointUrl: String
    var method: RequestMethodType = .post
    var requestType: RequestMethodType { method }
    var contentType: RequestContentType { method == .get ? .urlEncoded : .json }
}

/// Android `PackerApi`: one method per endpoint, typed arguments in, rows out. A failure throws
/// `RequestError.apiMessage` with Android's wording; `packerMessage(_:)` reads any other error.
final class PackerServiceManager {
    private let network: NetworkServiceManagable

    init(network: NetworkServiceManagable = NetworkServiceManager.shared) { self.network = network }

    static let pageSize = 100
    /// 5,000 orders; a server that kept answering would otherwise never stop.
    static let maxPages = 50
    /// 500 matches per search.
    static let searchMaxPages = 5

    func packers() async throws -> [PackerDto] {
        try await send("paker-list", method: .get).packArray("data").filter(\.isObject).map(PackerDto.init(json:))
    }

    /// One page of the packing board for `query`: pending (0), with a packer (10), being packed (11)
    /// and packed (12); a nil status asks for all four. `PackPage.total` counts the whole query, so
    /// a page of one row is how a tab gets its count.
    func boardPage(_ query: BoardQuery, page: Int, perPage: Int) async throws -> PackPage<PackOrderDto> {
        let root = try await send("paker-orders", body: query.body(page: page, perPage: perPage))
        return PackPage.parse(root) { $0.isObject ? PackOrderDto(json: $0) : nil }
    }

    /// Every order matching a search, across its pages. Matches are few, so this stays a request or
    /// two; `searchMaxPages` stops a search too loose to be useful.
    func boardMatches(_ query: BoardQuery) async throws -> [PackOrderDto] {
        var all: [PackOrderDto] = []
        var page = 1
        while true {
            let r = try await boardPage(query, page: page, perPage: Self.pageSize)
            all += r.items
            if r.lastPage <= page || r.items.isEmpty || page >= Self.searchMaxPages { return all.distinctById() }
            page += 1
        }
    }

    /// Pending or packing orders to one packer. The server moves 0/10 to 10, keeps 11 as 11 (a
    /// reassign during packing) and refuses 12.
    func assign(packerId: Int, orderIds: Set<Int>) async throws -> String? {
        try await send("assign-paker", body: ["paker_id": packerId, "order_ids": orderIds.sorted()]).packMessage
    }

    /// Who did what to an order and when, oldest first.
    func orderLogs(orderId: Int) async throws -> [PackLogDto] {
        try await send("paker/order-logs/\(orderId)", method: .get).packArray("data").filter(\.isObject).map(PackLogDto.init(json:))
    }

    /// One page of the signed-in packer's orders at `status`; `PackPage.total` counts all of them.
    func myPage(status: Int?, page: Int, perPage: Int, date: PackDay? = nil) async throws -> PackPage<PackOrderDto> {
        var body: [String: Any] = ["per_page": perPage, "page": page]
        if let status { body["status"] = status }
        if let date { body["date"] = date.iso }
        let root = try await send("paker/my-orders", body: body)
        return PackPage.parse(root) { $0.isObject ? PackOrderDto(json: $0) : nil }
    }

    /// The signed-in packer's orders, every page and status: what My Packing searches through.
    func myOrders(status: Int? = nil, date: PackDay? = nil) async throws -> [PackOrderDto] {
        var all: [PackOrderDto] = []
        var page = 1
        while true {
            let r = try await myPage(status: status, page: page, perPage: Self.pageSize, date: date)
            let known = Set(all.map(\.id))
            let fresh = r.items.filter { !known.contains($0.id) }
            all += fresh
            // A server that ignores `page` sends the same rows again; stop on that too.
            if r.lastPage <= page || fresh.isEmpty || page >= Self.maxPages { return all }
            page += 1
        }
    }

    func orderDetail(orderId: Int) async throws -> PackOrderDetail {
        let root = try await send("paker/order-detail/\(orderId)", method: .get)
        let data = (root["data"]?.isObject == true ? root["data"] : nil) ?? root
        return PackOrderDetail.from(data)
    }

    /// 10 → 11; on a packed order (12) the same call reopens it to 11.
    func startPacking(orderId: Int) async throws -> String? {
        try await send("paker/start-packing", body: ["order_id": orderId]).packMessage
    }

    /// A new, empty box on the order.
    func createPackage(orderId: Int) async throws -> String? {
        try await send("paker/create-package", body: ["order_id": orderId]).packMessage
    }

    /// Sets how many of a line are in a box: the server updates an existing row for the same box
    /// and line rather than adding to it, so `qty` is the box's new total, not an increment.
    func setPackageItem(packageId: Int, orderDetailId: Int, qty: Int) async throws -> String? {
        try await send("paker/add-package-item", body: ["package_id": packageId, "order_detail_id": orderDetailId, "qty_packed": qty]).packMessage
    }

    /// `packageItemId` is the row id order-detail sends as `packages[].items[].id`.
    func removePackageItem(packageItemId: Int) async throws -> String? {
        try await send("paker/remove-package-item", body: ["package_item_id": packageItemId]).packMessage
    }

    /// Only an empty box; the server refuses one with items.
    func deletePackage(packageId: Int) async throws -> String? {
        try await send("paker/delete-package", body: ["package_id": packageId]).packMessage
    }

    func completePacking(orderId: Int) async throws -> String? {
        try await send("paker/complete-packing", body: ["order_id": orderId]).packMessage
    }

    /// States, their cities and the cities' beats (`get-all-data`), to narrow the seller picker.
    func areas() async throws -> [PackArea] {
        PackArea.tree(from: try await send("get-all-data", body: [:]))
    }

    /// One page of sellers (`seller-list2`, the list the order filters use), narrowed by area and
    /// by `search`, which the server matches against the shop name, the owner's name and the mobile.
    func sellers(stateId: Int?, cityId: Int?, beatId: Int?, search: String, page: Int) async throws -> PackPage<PackSeller> {
        var body: [String: Any] = ["page": page]
        if let stateId { body["state_id"] = stateId }
        if let cityId { body["city_id"] = cityId }
        if let beatId { body["beat_id"] = beatId }
        let text = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { body["shop_name"] = text }
        let root = try await send("seller-list2", body: body)
        // seller-list2 always pages; with no paging fields the page asked for is the last.
        let parsed = PackPage.parse(root, row: PackSeller.from)
        let meta = root["data"]?.isObject == true ? root["data"]! : root
        let current = meta.packInt("current_page") ?? page
        return PackPage(items: parsed.items, lastPage: meta.packInt("last_page") ?? current, total: meta.packInt("total") ?? parsed.items.count)
    }

    /// Every active beat, A–Z. `beat-list` pages by 50, so this walks all pages.
    func beats() async throws -> [PackBeat] {
        var all: [JSONValue] = []
        var page = 1
        while true {
            let root = try await send("beat-list", body: ["page": page])
            guard let body = root["data"], body.isObject else { break }
            let rows = body.packArray("data")
            all += rows
            let last = body.packInt("last_page") ?? page
            if page >= last || rows.isEmpty || page >= 20 { break }
            page += 1
        }
        return all.compactMap { row -> PackBeat? in
            guard row.isObject, let id = row.packInt("id"),
                  row.packInt("status") == 1, (row.packInt("is_delete") ?? 0) == 0 else { return nil }
            return PackBeat(id: id, name: row.packStr("name") ?? "")
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // MARK: Transport

    /// Same reading of failures as the cash collection calls: one human message, never a raw code.
    /// A reply flagged `status: false` is a failure even with a 200.
    private func send(_ path: String, method: RequestMethodType = .post, body: [String: Any] = [:]) async throws -> JSONValue {
        let publisher: AnyPublisher<JSONValue, Error> = network.request(
            PackerEndpoint(endPointUrl: path, method: method),
            params: method == .get ? [String: Any]() : body,
            headers: UserDefaultManager.shared.authHeader
        )
        for try await root in publisher.values {
            guard root.isObject else { throw RequestError.apiMessage("Something went wrong (error 200). Try again.") }
            if case .bool(false)? = root["status"] {
                throw RequestError.apiMessage(root.packMessage ?? "Something went wrong (error 200). Try again.")
            }
            return root
        }
        throw RequestError.invalidResponse
    }
}

/// Android `PackerApi.send`'s wording for a failure, whatever shape it arrived in.
func packerMessage(_ error: Error) -> String {
    if let request = error as? RequestError {
        switch request {
        case .noInternet: return "No internet connection. Check your network and try again."
        case .apiMessage(let text): return text
        case .invalidResponse, .invalidData: return "The server's reply couldn't be read. Update the app or try again."
        default: return "Something went wrong. Try again."
        }
    }
    if error is DecodingError { return "The server's reply couldn't be read. Update the app or try again." }
    if error is URLError { return "No internet connection. Check your network and try again." }
    return error.localizedDescription.isEmpty ? "Something went wrong. Try again." : error.localizedDescription
}

extension Notification.Name {
    /// Android `CashCollectionBus.Change.Packing`: an order was started, packed, reopened or had its
    /// boxes changed on this phone, so My Packing, the board and the home cards reload themselves.
    static let packingChanged = Notification.Name("packingChanged")
}
