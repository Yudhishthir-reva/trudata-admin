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

    enum CodingKeys: String, CodingKey {
        case status, message, total, data
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

struct BillRegisterEntry: Identifiable {
    let json: JSONValue
    var id: Int { json["id"]?.intValue ?? 0 }
    var beatNames: [String] { json["beat_names"]?.arrayValue.map(\.stringValue) ?? [] }
    var assignedTo: Int? { json["assigned_to_id"]?.intValue }
    var name: String { json["assigned_to"]?.stringValue ?? "" }
    var status: String { json["status"]?.stringValue ?? BillRegisterStatus.pending.rawValue }
    var totalOrders: Int { json["total_orders"]?.intValue ?? 0 }
    var pendingOrders: Int { json["pending_orders"]?.intValue ?? 0 }
    var clearedOrders: Int { json["cleared_orders"]?.intValue ?? 0 }
    var totalAmount: Double { json["total_amount"]?.doubleValue ?? 0 }
    var pendingAmount: Double { json["pending_amount"]?.doubleValue ?? 0 }
    var orders: [BillRegisterOrderEntry]? {
        guard case .array(let values) = json["orders"] else { return nil }
        return values.map(BillRegisterOrderEntry.init)
    }
}

struct BillRegisterOrderEntry: Identifiable {
    let json: JSONValue
    var id: Int { json["register_order_id"]?.intValue ?? json["order_id"]?.intValue ?? 0 }
    var orderID: Int { json["order_id"]?.intValue ?? 0 }
    var orderNo: String { json["order_no"]?.stringValue ?? "" }
    var shop: String { json["seller_shop_name"]?.stringValue ?? "" }
    var seller: String { json["seller_name"]?.stringValue ?? "" }
    var amount: Double { json["order_amount"]?.doubleValue ?? 0 }
    var pending: Double { json["pending_amount"]?.doubleValue ?? 0 }
    var currentPending: Double { json["current_pending"]?.doubleValue ?? pending }
    var status: String { json["payment_status"]?.stringValue ?? BillRegisterStatus.pending.rawValue }
    var isCleared: Bool { status.lowercased() == BillRegisterStatus.cleared.rawValue }
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
    case list(status: BillRegisterStatus? = nil, assignedTo: Int? = nil, page: Int = 1, orderID: String? = nil)
    case detail(id: Int)
    case assign(id: Int, assignedTo: Int)
    // nil clears the entire register; a nonempty array clears selected orders.
    case clear(id: Int, orderIds: [Int]? = nil)

    var path: String {
        switch self {
        case .beatOrders: return "bill-register/beat-orders"
        case .create: return "bill-register/create"
        case .list: return "bill-register/list"
        case .detail: return "bill-register/detail"
        case .assign: return "bill-register/assign"
        case .clear: return "bill-register/clear"
        }
    }

    func parameters(access: BillRegisterAccess) throws -> [String: Any] {
        switch self {
        case .list(let status, let assignedTo, let page, let orderID):
            guard page > 0 else { throw BillRegisterRequestError.invalidSelection }
            var params: [String: Any] = ["page": page]
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
        case .list, .detail:
            preconditionFailure("Read requests return above")
        }
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
