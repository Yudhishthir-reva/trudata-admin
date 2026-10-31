//
//  ViewPendingBillsModels.swift
//  Truedata
//

// Foundation only, so `Tests/PendingBillsChecks.swift` can compile this file on its own with
// swiftc (alongside LenientDecoding.swift) and check the filter without the app.
import Foundation

struct PendingPaymentBillsResponse: Decodable {
    var status: Bool
    var message: String
    var data: PendingPaymentBillsData

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.first ?? ""
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = (try? container.decode(PendingPaymentBillsData.self, forKey: .data)) ?? PendingPaymentBillsData()
    }
}

struct PendingPaymentBillsData: Decodable {
    var currentPage: Int
    var lastPage: Int
    var perPage: Int
    var total: Int
    var response: PendingPaymentBillsResponseBody
    var paymentModeMap: [PaymentLookupItem]
    var paymentStatusMap: [PaymentLookupItem]
    var orderStatusMap: [PaymentLookupItem]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case total, response
        case paymentModeMap = "payment_mode_map"
        case paymentStatusMap = "payment_status_map"
        case orderStatusMap = "order_status_map"
    }

    init(
        currentPage: Int = 0,
        lastPage: Int = 0,
        perPage: Int = 0,
        total: Int = 0,
        response: PendingPaymentBillsResponseBody = PendingPaymentBillsResponseBody(),
        paymentModeMap: [PaymentLookupItem] = [],
        paymentStatusMap: [PaymentLookupItem] = [],
        orderStatusMap: [PaymentLookupItem] = []
    ) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.perPage = perPage
        self.total = total
        self.response = response
        self.paymentModeMap = paymentModeMap
        self.paymentStatusMap = paymentStatusMap
        self.orderStatusMap = orderStatusMap
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        perPage = container.decodeIntLeniently(forKey: .perPage) ?? 0
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        response = (try? container.decode(PendingPaymentBillsResponseBody.self, forKey: .response))
            ?? PendingPaymentBillsResponseBody()
        paymentModeMap = (try? container.decode([PaymentLookupItem].self, forKey: .paymentModeMap)) ?? []
        paymentStatusMap = (try? container.decode([PaymentLookupItem].self, forKey: .paymentStatusMap)) ?? []
        orderStatusMap = (try? container.decode([PaymentLookupItem].self, forKey: .orderStatusMap)) ?? []
    }
}

struct PendingPaymentBillsResponseBody: Decodable {
    var billList: PendingPaymentBillList

    enum CodingKeys: String, CodingKey {
        case billList
    }

    init(billList: PendingPaymentBillList = PendingPaymentBillList()) {
        self.billList = billList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        billList = (try? container.decode(PendingPaymentBillList.self, forKey: .billList))
            ?? PendingPaymentBillList()
    }
}

struct PendingPaymentBillList: Decodable {
    var currentPage: Int
    var lastPage: Int
    /// Bills the server has in all; the loader shows "{loaded} of {total}" while pages arrive.
    var total: Int
    var data: [PendingPaymentBill]

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case total
        case data
    }

    init(currentPage: Int = 0, lastPage: Int = 0, total: Int = 0, data: [PendingPaymentBill] = []) {
        self.currentPage = currentPage
        self.lastPage = lastPage
        self.total = total
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 0
        lastPage = container.decodeIntLeniently(forKey: .lastPage) ?? 0
        total = container.decodeIntLeniently(forKey: .total) ?? 0
        data = (try? container.decode([PendingPaymentBill].self, forKey: .data)) ?? []
    }
}

struct PendingPaymentBill: Decodable, Identifiable, Hashable {
    var id: Int
    var transactionNo: String
    var orderDate: String
    var amount: String
    var remainingAmount: String
    var paymentStatus: String
    var paymentMode: String
    var sellerName: String
    var staffName: String
    var orderId: String
    var orderStatus: String
    var history: [PendingPaymentBillHistory]

    enum CodingKeys: String, CodingKey {
        case id, amount, history
        case transactionNo
        case orderDate
        case remainingAmount
        case paymentStatus
        case paymentMode
        case sellerName
        case staffName
        case orderId
        case orderStatus
    }

    init(
        id: Int,
        transactionNo: String = "",
        orderDate: String = "",
        amount: String = "0",
        remainingAmount: String = "0",
        paymentStatus: String = "",
        paymentMode: String = "",
        sellerName: String = "",
        staffName: String = "",
        orderId: String = "",
        orderStatus: String = "",
        history: [PendingPaymentBillHistory] = []
    ) {
        self.id = id
        self.transactionNo = transactionNo
        self.orderDate = orderDate
        self.amount = amount
        self.remainingAmount = remainingAmount
        self.paymentStatus = paymentStatus
        self.paymentMode = paymentMode
        self.sellerName = sellerName
        self.staffName = staffName
        self.orderId = orderId
        self.orderStatus = orderStatus
        self.history = history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        transactionNo = container.decodeStringLeniently(forKey: .transactionNo) ?? ""
        orderDate = container.decodeStringLeniently(forKey: .orderDate) ?? ""
        amount = container.decodeStringLeniently(forKey: .amount) ?? "0"
        remainingAmount = container.decodeStringLeniently(forKey: .remainingAmount) ?? "0"
        paymentStatus = container.decodeStringLeniently(forKey: .paymentStatus) ?? ""
        paymentMode = container.decodeStringLeniently(forKey: .paymentMode) ?? ""
        sellerName = container.decodeStringLeniently(forKey: .sellerName) ?? ""
        staffName = container.decodeStringLeniently(forKey: .staffName) ?? ""
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        orderStatus = container.decodeStringLeniently(forKey: .orderStatus) ?? ""
        history = (try? container.decode([PendingPaymentBillHistory].self, forKey: .history)) ?? []
    }

    var displayOrderId: String {
        orderId.pendingTrimmed.isEmpty ? transactionNo : orderId
    }
}

struct PendingPaymentBillHistory: Decodable, Identifiable, Hashable {
    var id: Int { serialNumber }
    var serialNumber: Int
    var date: String
    var paymentMode: String?
    var payAmount: String
    var staff: String
    var seller: String

    enum CodingKeys: String, CodingKey {
        case serialNumber = "S_No"
        case date = "Date"
        case paymentMode
        case payAmount
        case staff, seller
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        serialNumber = container.decodeIntLeniently(forKey: .serialNumber) ?? 0
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        paymentMode = container.decodeStringLeniently(forKey: .paymentMode)
        payAmount = container.decodeStringLeniently(forKey: .payAmount) ?? "0"
        staff = container.decodeStringLeniently(forKey: .staff) ?? ""
        seller = container.decodeStringLeniently(forKey: .seller) ?? ""
    }

    var payValue: Double { pendingBillMoney(payAmount) }
}

struct PaymentLookupItem: Decodable, Identifiable, Hashable {
    var id: Int { key }
    var key: Int
    var label: String

    init(key: Int, label: String) {
        self.key = key
        self.label = label
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = container.decodeIntLeniently(forKey: .key) ?? 0
        label = container.decodeStringLeniently(forKey: .label) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case key, label
    }
}

/// Order status keys as other screens (Payment Insights, Order Detail) read them. The pending
/// bills screen itself labels order statuses from the server's `order_status_map`.
enum BillOrderStatus: String {
    case pending = "0"
    case toDeliver = "1"
    case pickup = "2"
    case delivered = "3"
    case cancel = "4"
    case assign = "6"
    case deliveryFailed = "7"
    case partialReturn = "8"
    case unknown = "-1"

    init(key: String?) {
        self = BillOrderStatus(rawValue: key ?? "") ?? .unknown
    }

    var label: String {
        switch self {
        case .pending: return "Pending"
        case .toDeliver: return "To Deliver"
        case .pickup: return "Pickup"
        case .delivered: return "Delivered"
        case .cancel: return "Cancel"
        case .assign: return "Assign"
        case .deliveryFailed: return "Delivery Failed"
        case .partialReturn: return "Partial Return"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Search and filters (Android `PendingBillsFilter.kt`)

/// A bill's payment status as the server keys it (`payment_status_map`).
enum PendingBillStatusKey {
    static let pending = "0"
    static let remaining = "1"
    static let complete = "2"
    /// The three tabs, in the order the screen shows them.
    static let all = [pending, remaining, complete]
}

/// `paymentMode` 0: nothing collected yet.
let pendingBillNoMode = "0"

enum PendingBillSort: CaseIterable {
    case newest, oldest, remainingHigh, remainingLow

    var label: String {
        switch self {
        case .newest: return "Newest first"
        case .oldest: return "Oldest first"
        case .remainingHigh: return "Highest due"
        case .remainingLow: return "Lowest due"
        }
    }
}

/// Everything the filter sheet narrows the bills by; the search box and the status tab sit on top
/// of it. Empty sets and nil bounds mean no limit. Applied on the phone to the full list.
struct PendingBillsFilter: Equatable {
    /// Order date, inclusive, as start-of-day in `PendingBillsFilter.calendar`. One end alone is
    /// open on the other side.
    var from: Date?
    var to: Date?
    var salesPeople: Set<String> = []
    var shops: Set<String> = []
    /// `paymentMode` keys; `pendingBillNoMode` for bills with nothing collected.
    var modes: Set<String> = []
    var orderStatuses: Set<String> = []
    var minDue: Double?
    var maxDue: Double?
    var sort: PendingBillSort = .newest

    /// How many filters narrow the list; the sort isn't one.
    var activeCount: Int {
        [
            from != nil || to != nil,
            !salesPeople.isEmpty,
            !shops.isEmpty,
            !modes.isEmpty,
            !orderStatuses.isEmpty,
            minDue != nil || maxDue != nil
        ].filter { $0 }.count
    }

    var isActive: Bool { activeCount > 0 }

    /// Bill dates are calendar days with no time zone; reading and comparing them in one fixed
    /// Gregorian calendar keeps "27-Oct-2026" on the 27th wherever the phone is.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    /// Start of the given day, the shape `from` / `to` hold.
    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    static func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    /// One-tap order-date ranges; anything else goes through the calendar.
    static func datePresets(today: Date = Date()) -> [(label: String, from: Date, to: Date)] {
        let today = startOfDay(today)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
        let lastMonthEnd = calendar.date(byAdding: .day, value: -1, to: monthStart) ?? monthStart
        func back(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: today) ?? today }
        return [
            ("Today", today, today),
            ("Last 7 days", back(6), today),
            ("Last 30 days", back(29), today),
            ("This month", monthStart, today),
            ("Last month", lastMonthStart, lastMonthEnd)
        ]
    }
}

private let pendingBillDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = PendingBillsFilter.calendar
    formatter.timeZone = PendingBillsFilter.calendar.timeZone
    formatter.dateFormat = "dd-MMM-yyyy"
    return formatter
}()

/// Amounts come as "2,000" or "1050.00"; anything unreadable counts as nothing.
func pendingBillMoney(_ raw: String) -> Double {
    Double(raw.replacingOccurrences(of: ",", with: "").pendingTrimmed) ?? 0
}

extension String {
    fileprivate var pendingTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension PendingPaymentBill {
    /// `orderDate` comes as "27-Oct-2026"; nil when it can't be read.
    var date: Date? { pendingBillDateFormatter.date(from: orderDate.pendingTrimmed) }
    var due: Double { pendingBillMoney(remainingAmount) }
    var total: Double { pendingBillMoney(amount) }
    var modeKey: String { paymentMode.pendingTrimmed.isEmpty ? pendingBillNoMode : paymentMode.pendingTrimmed }
    var statusKey: String { paymentStatus.pendingTrimmed }

    /// The search box: order number (with or without "#" and the session, so "4456" finds
    /// "#2026-27/4456"), transaction number, shop and sales person, ignoring case. Every word
    /// typed has to match somewhere.
    func matches(_ query: String) -> Bool {
        let words = query.lowercased().replacingOccurrences(of: "#", with: " ")
            .split(separator: " ").map(String.init).filter { !$0.pendingTrimmed.isEmpty }
        if words.isEmpty { return true }
        let haystack = [orderId, transactionNo, sellerName, staffName]
            .map { $0.lowercased().replacingOccurrences(of: "#", with: "") }
            .joined(separator: " ")
        return words.allSatisfy { haystack.contains($0) }
    }

    func passes(_ f: PendingBillsFilter) -> Bool {
        if f.from != nil || f.to != nil {
            guard let d = date else { return false }
            if let from = f.from, d < from { return false }
            if let to = f.to, d > to { return false }
        }
        if !f.salesPeople.isEmpty && !f.salesPeople.contains(staffName.pendingTrimmed) { return false }
        if !f.shops.isEmpty && !f.shops.contains(sellerName.pendingTrimmed) { return false }
        if !f.modes.isEmpty && !f.modes.contains(modeKey) { return false }
        if !f.orderStatuses.isEmpty && !f.orderStatuses.contains(orderStatus.pendingTrimmed) { return false }
        if let min = f.minDue, due < min { return false }
        if let max = f.maxDue, due > max { return false }
        return true
    }
}

extension Array where Element == PendingPaymentBill {
    /// Search and filter, then sort; the status tab is applied by the caller on top.
    func narrow(_ query: String, _ f: PendingBillsFilter) -> [PendingPaymentBill] {
        // Kotlin's sorts are stable, so equal keys keep the server's order; the index does that here.
        let kept = filter { $0.matches(query) && $0.passes(f) }.enumerated().map { ($0.offset, $0.element) }
        let sorted: [(Int, PendingPaymentBill)]
        switch f.sort {
        // Same-day bills keep the server's order (newest first), so ids break ties. An unreadable
        // date sorts as the oldest, as Kotlin's nulls-first `compareBy` does.
        case .newest:
            sorted = kept.sorted { a, b in
                let da = a.1.date ?? .distantPast, db = b.1.date ?? .distantPast
                if da != db { return da > db }
                if a.1.id != b.1.id { return a.1.id > b.1.id }
                return a.0 < b.0
            }
        case .oldest:
            sorted = kept.sorted { a, b in
                let da = a.1.date ?? .distantPast, db = b.1.date ?? .distantPast
                if da != db { return da < db }
                if a.1.id != b.1.id { return a.1.id < b.1.id }
                return a.0 < b.0
            }
        case .remainingHigh:
            sorted = kept.sorted { $0.1.due != $1.1.due ? $0.1.due > $1.1.due : $0.0 < $1.0 }
        case .remainingLow:
            sorted = kept.sorted { $0.1.due != $1.1.due ? $0.1.due < $1.1.due : $0.0 < $1.0 }
        }
        return sorted.map { $0.1 }
    }

    /// The distinct, non-blank values of `pick` across the bills, A–Z: the choices a filter offers.
    func choices(_ pick: (PendingPaymentBill) -> String) -> [String] {
        var seen = Set<String>()
        let values = map { pick($0).pendingTrimmed }.filter { !$0.isEmpty && seen.insert($0).inserted }
        return values.enumerated()
            .sorted { $0.element.lowercased() != $1.element.lowercased()
                ? $0.element.lowercased() < $1.element.lowercased() : $0.offset < $1.offset }
            .map { $0.element }
    }
}

// MARK: - Labels

/// Labels come from the server's maps (`payment_mode_map`, `order_status_map`) so a new mode or
/// status shows by its own name; a key the map doesn't know shows as sent.
struct PendingBillLabels {
    var paymentModes: [PaymentLookupItem] = []
    var orderStatuses: [PaymentLookupItem] = []

    func mode(_ key: String) -> String {
        let key = key.pendingTrimmed
        if key == pendingBillNoMode || key.isEmpty { return "Not paid yet" }
        guard let label = paymentModes.first(where: { String($0.key) == key })?.label, !label.isEmpty else { return key }
        return label.prefix(1).uppercased() + label.dropFirst()
    }

    func orderStatus(_ key: String) -> String {
        let key = key.pendingTrimmed
        guard let label = orderStatuses.first(where: { String($0.key) == key })?.label, !label.isEmpty else { return key }
        return label
    }
}
