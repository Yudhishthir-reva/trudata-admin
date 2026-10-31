import Foundation

struct BillRegisterBeatOrdersResponse: Decodable {
    let status: Bool
    let message: String
    let data: BillRegisterBeatOrdersData?
}

struct BillRegisterBeatOrdersData: Decodable {
    let total: Int
    let orders: [BillRegisterOrder]
}

struct BillRegisterOrder: Decodable, Identifiable {
    var id: Int { orderId }
    let orderId: Int
    let orderNo: String
    let orderSource: String
    let sellerId: Int
    let sellerName: String
    let sellerShopName: String
    let sellerMobile: String
    let sellerProfilePic: String
    let beatId: Int
    let beatName: String
    let staffName: String
    let totalPrice: Double
    let pendingAmount: Double
    let deliveryDate: String
    let orderDate: String
    let isAssigned: Bool
    let billRegisterId: Int?
    let billRegisterAssignedToId: Int?
    let billRegisterAssignedToName: String?
    let billRegisterStatus: String?

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderNo = "order_no"
        case orderSource = "order_source"
        case sellerId = "seller_id"
        case sellerName = "seller_name"
        case sellerShopName = "seller_shop_name"
        case sellerMobile = "seller_mobile"
        case sellerProfilePic = "seller_profile_pic"
        case beatId = "beat_id"
        case beatName = "beat_name"
        case staffName = "staff_name"
        case totalPrice = "total_price"
        case pendingAmount = "pending_amount"
        case deliveryDate = "delivery_date"
        case orderDate = "order_date"
        case isAssigned = "is_assigned"
        case billRegisterId = "bill_register_id"
        case billRegisterAssignedToId = "bill_register_assigned_to_id"
        case billRegisterAssignedToName = "bill_register_assigned_to_name"
        case billRegisterStatus = "bill_register_status"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = container.decodeIntLeniently(forKey: .orderId) ?? 0
        orderNo = container.decodeStringLeniently(forKey: .orderNo) ?? ""
        orderSource = container.decodeStringLeniently(forKey: .orderSource) ?? ""
        sellerId = container.decodeIntLeniently(forKey: .sellerId) ?? 0
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        sellerShopName = container.decodeStringLeniently(forKey: .sellerShopName) ?? ""
        sellerMobile = container.decodeStringLeniently(forKey: .sellerMobile) ?? ""
        sellerProfilePic = container.decodeStringLeniently(forKey: .sellerProfilePic) ?? ""
        beatId = container.decodeIntLeniently(forKey: .beatId) ?? 0
        beatName = container.decodeStringLeniently(forKey: .beatName) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        totalPrice = container.decodeDoubleLeniently(forKey: .totalPrice) ?? 0
        pendingAmount = container.decodeDoubleLeniently(forKey: .pendingAmount) ?? 0
        deliveryDate = container.decodeStringLeniently(forKey: .deliveryDate) ?? ""
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        isAssigned = container.decodeBoolLeniently(forKey: .isAssigned) ?? false
        billRegisterId = container.decodeIntLeniently(forKey: .billRegisterId)
        billRegisterAssignedToId = container.decodeIntLeniently(forKey: .billRegisterAssignedToId)
        billRegisterAssignedToName = container.decodeStringLeniently(forKey: .billRegisterAssignedToName)
        billRegisterStatus = container.decodeStringLeniently(forKey: .billRegisterStatus)
    }
}

// Mirrors the Android register DTO. List entries include counts and totals;
// detail responses add order rows.
struct BillRegisterListResponse: Decodable {
    let status: Bool
    let message: String
    let currentPage: Int
    let lastPage: Int
    let perPage: Int
    let total: Int
    let data: [JSONValue]
    /// Android `BeatWisePendingDto`, beside the rows: pending bills of pending registers per beat,
    /// narrowed by `beat_ids` and `assigned_to` but never by `status` or `order_id`.
    let beatWisePending: JSONValue?

    enum CodingKeys: String, CodingKey {
        case status, message, total, data
        case beatWisePending = "beat_wise_pending"
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
    }
}

struct BillRegisterActionResponse: Decodable {
    let status: Bool
    let message: String
    let data: JSONValue?
}

enum BillRegisterStatus: String, CaseIterable {
    case pending, cleared
    /// A register a manager called off; its orders went back to unassigned.
    case cancelled
    /// An order taken out of its register; kept as history, out of the totals.
    case removed
}

/// Android `BillStatus`: the server has sent both "Cleared" and "cleared", so compare lowercased.
private func billStatus(_ raw: String) -> BillRegisterStatus? {
    BillRegisterStatus(rawValue: raw.lowercased())
}

private extension JSONValue {
    /// A string field that is absent, null or blank reads as nil; numbers come back as text.
    func text(_ key: String) -> String? {
        guard let value = self[key] else { return nil }
        if case .null = value { return nil }
        let text = value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

struct BillRegisterAccess {
    let userId: Int
    let canManage: Bool

    init(role: String, userId: Int) {
        self.userId = userId
        canManage = ["admin", "accountant"].contains(role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    func canRead(assignedTo: Int?) -> Bool {
        canManage || (userId > 0 && assignedTo == userId)
    }
}

/// Android `BillRegisterDto`. [totalOrders] counts removed orders too, while [totalAmount]
/// leaves them out. [cancelledAt] comes raw (`yyyy-MM-dd HH:mm:ss`), unlike the dates beside it.
struct BillRegisterEntry: Identifiable {
    let json: JSONValue
    var id: Int { json["id"]?.intValue ?? 0 }
    var beatNames: [String] { json["beat_names"]?.arrayValue.map(\.stringValue) ?? [] }
    var beatIds: [Int] { json["beat_ids"]?.arrayValue.map(\.intValue) ?? [] }
    var assignedTo: Int? { json["assigned_to_id"]?.intValue }
    var name: String { json["assigned_to"]?.stringValue ?? "" }
    var assignedBy: String? { json.text("assigned_by") }
    var status: String { json["status"]?.stringValue ?? BillRegisterStatus.pending.rawValue }
    var totalOrders: Int { json["total_orders"]?.intValue ?? 0 }
    var pendingOrders: Int { json["pending_orders"]?.intValue ?? 0 }
    var clearedOrders: Int { json["cleared_orders"]?.intValue ?? 0 }
    var removedOrders: Int { json["removed_orders"]?.intValue ?? 0 }
    /// Orders still pending when the register was cancelled.
    var cancelledOrders: Int { json["cancelled_orders"]?.intValue ?? 0 }
    var totalAmount: Double { json["total_amount"]?.doubleValue ?? 0 }
    var pendingAmount: Double { json["pending_amount"]?.doubleValue ?? 0 }
    var createdAt: String? { json.text("created_at") }
    var clearedAt: String? { json.text("cleared_at") }
    var cancelledBy: String? { json.text("cancelled_by") }
    var cancelledAt: String? { json.text("cancelled_at") }
    var cancelReason: String? { json.text("cancel_reason") }
    /// The backend has returned "Cleared" as well as "cleared"; comparing the raw string let a
    /// cleared register keep its Reassign and Clear controls.
    var isCleared: Bool { billStatus(status) == .cleared }
    var isCancelled: Bool { billStatus(status) == .cancelled }
    var isPending: Bool { billStatus(status) == .pending }
    /// The orders still counted in the register: everything but the removed ones.
    var activeOrders: Int { max(totalOrders - removedOrders, 0) }
    var orders: [BillRegisterOrderEntry]? {
        guard case .array(let values) = json["orders"] else { return nil }
        return values.map(BillRegisterOrderEntry.init)
    }
}

/// Android `RegisterOrderDto`. [status] is pending or cleared; removed once taken out of the
/// register; cancelled when the register was cancelled with it still pending.
struct BillRegisterOrderEntry: Identifiable {
    let json: JSONValue
    var id: Int { json["register_order_id"]?.intValue ?? json["order_id"]?.intValue ?? 0 }
    var orderID: Int { json["order_id"]?.intValue ?? 0 }
    var orderNo: String { json["order_no"]?.stringValue ?? "" }
    var shop: String { json["seller_shop_name"]?.stringValue ?? "" }
    var seller: String { json["seller_name"]?.stringValue ?? "" }
    var sellerMobile: String? { json.text("seller_mobile") }
    var beatName: String? { json.text("beat_name") }
    var staffName: String? { json.text("staff_name") }
    var deliveryDate: String? { json.text("delivery_date") }
    var amount: Double { json["order_amount"]?.doubleValue ?? 0 }
    var pending: Double { json["pending_amount"]?.doubleValue ?? 0 }
    var currentPending: Double { json["current_pending"]?.doubleValue ?? pending }
    var status: String { json["payment_status"]?.stringValue ?? BillRegisterStatus.pending.rawValue }
    var removedBy: String? { json.text("removed_by") }
    var removedAt: String? { json.text("removed_at") }
    var removeReason: String? { json.text("remove_reason") }
    var isCleared: Bool { billStatus(status) == .cleared }
    var isRemoved: Bool { billStatus(status) == .removed }
    var isCancelled: Bool { billStatus(status) == .cancelled }
    /// Still to collect: the only orders that can be cleared or removed.
    var isPending: Bool { billStatus(status) == .pending }
    /// Shop first, then seller, then the order number: what a bill is called in a summary.
    var title: String { [shop, seller, orderNo].first { !$0.isEmpty } ?? "Order #\(orderID)" }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return [orderNo, shop, seller, sellerMobile, beatName, staffName]
            .contains { $0?.localizedCaseInsensitiveContains(q) == true }
    }
}

/// The list as registers, or as each beat's bills still to collect.
enum BillListView: Hashable { case registers, beats }

/// Android `BeatPendingDto`: one beat's still-to-collect bills across pending registers.
struct BillBeatPending: Identifiable {
    let json: JSONValue
    var id: Int { beatId }
    var beatId: Int { json["beat_id"]?.intValue ?? 0 }
    var name: String { json.text("beat_name") ?? "Beat \(beatId)" }
    var pendingOrders: Int { json["pending_orders"]?.intValue ?? 0 }
    var totalRegisters: Int { json["total_registers"]?.intValue ?? 0 }
    var totalSellers: Int { json["total_sellers"]?.intValue ?? 0 }
    var orderAmount: Double { json["order_amount"]?.doubleValue ?? 0 }
    var pendingAmount: Double { json["pending_amount"]?.doubleValue ?? 0 }
}

/// Android `BeatWisePendingDto`.
struct BillBeatWise {
    let json: JSONValue
    var totalBeats: Int { json["total_beats"]?.intValue ?? 0 }
    var pendingOrders: Int { json["pending_orders"]?.intValue ?? 0 }
    var pendingAmount: Double { json["pending_amount"]?.doubleValue ?? 0 }
    var beats: [BillBeatPending] { json["beats"]?.arrayValue.map(BillBeatPending.init) ?? [] }
    static let empty = BillBeatWise(json: .object([:]))
}

/// Android `ExportFormat`: the register with its orders as a file (`bill-register/detail-pdf|csv`).
enum BillExportFormat: String, CaseIterable, Identifiable {
    case pdf, csv
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var path: String { "bill-register/detail-\(rawValue)" }

    /// A PDF must start `%PDF`; a CSV must be text, which a stray HTML error page is not.
    func looksValid(_ data: Data) -> Bool {
        switch self {
        case .pdf:
            return data.prefix(4).elementsEqual("%PDF".utf8)
        case .csv:
            let head = String(decoding: data.prefix(64), as: UTF8.self)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}").union(.whitespacesAndNewlines))
            return !head.hasPrefix("<")
        }
    }
}

enum BillRegisterRequestError: LocalizedError {
    case forbidden, invalidSelection, missingUser
    var errorDescription: String? {
        switch self {
        case .forbidden: return "Only Admin and Accountant can manage bill registers."
        case .invalidSelection: return "Choose valid beats, orders and staff."
        case .missingUser: return "Sign in again to view your assigned bill registers."
        }
    }
}

enum BillRegisterRequest {
    case beatOrders(beatIds: [Int])
    case create(beatIds: [Int], orderIds: [Int], assignedTo: Int)
    case list(status: BillRegisterStatus? = nil, assignedTo: Int? = nil, page: Int = 1, orderID: String? = nil, beatIds: [Int] = [])
    case detail(id: Int)
    case assign(id: Int, assignedTo: Int)
    // nil clears the entire register; a nonempty array clears selected orders.
    case clear(id: Int, orderIds: [Int]? = nil)
    /// Calls off a pending register none of whose bills is cleared; its orders go back to unassigned.
    case cancel(id: Int, reason: String?)
    /// Takes pending orders out of a pending register. They stay in its detail as removed, drop out
    /// of its total and are free for another register.
    case removeOrders(id: Int, orderIds: [Int], reason: String?)

    /// The server's limit on a cancel or remove reason.
    static let reasonMax = 500

    var path: String {
        switch self {
        case .beatOrders: return "bill-register/beat-orders"
        case .create: return "bill-register/create"
        case .list: return "bill-register/list"
        case .detail: return "bill-register/detail"
        case .assign: return "bill-register/assign"
        case .clear: return "bill-register/clear"
        case .cancel: return "bill-register/cancel"
        case .removeOrders: return "bill-register/remove-order"
        }
    }

    func parameters(access: BillRegisterAccess) throws -> [String: Any] {
        switch self {
        case .list(let status, let assignedTo, let page, let orderID, let beatIds):
            guard page > 0 else { throw BillRegisterRequestError.invalidSelection }
            var params: [String: Any] = ["page": page]
            if !beatIds.isEmpty { params["beat_ids"] = beatIds.filter { $0 > 0 }.sorted() }
            if let status { params["status"] = status.rawValue }
            if let orderID {
                let value = orderID.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { params["order_id"] = Int(value).map { $0 as Any } ?? value }
            }
            if access.canManage {
                if let assignedTo {
                    guard assignedTo > 0 else { throw BillRegisterRequestError.invalidSelection }
                    params["assigned_to"] = assignedTo
                }
            } else {
                guard access.userId > 0 else { throw BillRegisterRequestError.missingUser }
                params["assigned_to"] = access.userId
            }
            return params
        case .detail(let id):
            guard id > 0 else { throw BillRegisterRequestError.invalidSelection }
            guard access.canManage || access.userId > 0 else { throw BillRegisterRequestError.missingUser }
            // The server must enforce ownership for this ID; a client filter
            // cannot authorize access to another employee's register.
            return ["bill_register_id": id]
        default:
            guard access.canManage else { throw BillRegisterRequestError.forbidden }
        }
        switch self {
        case .beatOrders(let beatIds):
            return ["beat_ids": try validIds(beatIds)]
        case .create(let beatIds, let orderIds, let assignedTo):
            guard assignedTo > 0 else { throw BillRegisterRequestError.invalidSelection }
            return ["beat_ids": try validIds(beatIds), "order_ids": try validIds(orderIds), "assigned_to": assignedTo]
        case .assign(let id, let assignedTo):
            guard id > 0, assignedTo > 0 else { throw BillRegisterRequestError.invalidSelection }
            return ["bill_register_id": id, "assigned_to": assignedTo]
        case .clear(let id, let orderIds):
            guard id > 0 else { throw BillRegisterRequestError.invalidSelection }
            var params: [String: Any] = ["bill_register_id": id]
            if let orderIds { params["order_ids"] = try validIds(orderIds) }
            return params
        case .cancel(let id, let reason):
            guard id > 0 else { throw BillRegisterRequestError.invalidSelection }
            return withReason(["bill_register_id": id], reason)
        case .removeOrders(let id, let orderIds, let reason):
            guard id > 0 else { throw BillRegisterRequestError.invalidSelection }
            return withReason(["bill_register_id": id, "order_ids": try validIds(orderIds.sorted())], reason)
        case .list, .detail:
            preconditionFailure("Read requests return above")
        }
    }

    private func withReason(_ params: [String: Any], _ reason: String?) -> [String: Any] {
        var params = params
        let text = reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !text.isEmpty { params["reason"] = String(text.prefix(Self.reasonMax)) }
        return params
    }

    private func validIds(_ ids: [Int]) throws -> [Int] {
        guard !ids.isEmpty, ids.allSatisfy({ $0 > 0 }) else { throw BillRegisterRequestError.invalidSelection }
        return ids
    }
}

// April–March financial year used in printed order references.
enum BillOrderSession {
    static func startYear(today: Date = Date(), calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: today)
        return calendar.component(.month, from: today) >= 4 ? year : year - 1
    }
    static func label(_ year: Int) -> String { "\(year)-" + String(format: "%02d", (year + 1) % 100) }
    static func prefix(_ year: Int) -> String { "#\(label(year))/" }
    static func filter(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || value.range(of: "^#?[0-9]{4}-[0-9]{2}/?$", options: .regularExpression) != nil ? nil : value
    }
    static func year(in input: String) -> Int? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = value.range(of: "^#?[0-9]{4}-[0-9]{2}/", options: .regularExpression) else { return nil }
        return Int(value[range].replacingOccurrences(of: "#", with: "").prefix(4))
    }
    static func replacingSession(in input: String, with year: Int) -> String {
        let value = filter(input) ?? ""
        return prefix(year) + value.replacingOccurrences(of: "^#?[0-9]{4}-[0-9]{2}/", with: "", options: .regularExpression)
    }
}
