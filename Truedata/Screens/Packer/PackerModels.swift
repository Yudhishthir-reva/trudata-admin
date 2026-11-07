import Foundation

// Android `packer/PackerModels.kt`, `PackDates.kt`, `PackWeight.kt` and the list states of
// `PackerViewModels.kt`, ported. Rows are read field by field off `JSONValue` (the way the cash and
// bill register models are), because the packer endpoints send the same field as `5`, `"5"` or
// `"5.00"` and rename keys between builds: a renamed key costs a blank field, not the whole screen.

// MARK: - Lenient reads

extension JSONValue {
    /// Android `JsonObject.str`: the first of `keys` holding a non-blank primitive that isn't "null".
    func packStr(_ keys: String...) -> String? { packStr(keys) }

    func packStr(_ keys: [String]) -> String? {
        for key in keys {
            guard let value = self[key] else { continue }
            switch value {
            case .string, .int, .double, .bool:
                let text = value.stringValue
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text != "null" { return text }
            default: continue
            }
        }
        return nil
    }

    /// Numbers arrive as `5`, `"5"` or `"5.00"` depending on the column.
    func packInt(_ keys: String...) -> Int? {
        guard let text = packStr(keys)?.trimmingCharacters(in: .whitespaces) else { return nil }
        if let n = Int(text) { return n }
        if let d = Double(text), d.isFinite { return Int(d) }
        return nil
    }

    func packArray(_ keys: String...) -> [JSONValue] {
        for key in keys { if case .array(let items)? = self[key] { return items } }
        return []
    }

    var isObject: Bool { if case .object = self { return true }; return false }
    var isArray: Bool { if case .array = self { return true }; return false }

    /// Android `messageOf`: a validation error first, then `message` (a string or an array of them).
    var packMessage: String? {
        if case .object(let errors)? = self["errors"] {
            for value in errors.values { if let text = value.packFirstText { return text } }
        }
        return self["message"]?.packFirstText
    }

    private var packFirstText: String? {
        switch self {
        case .string, .int, .double, .bool:
            let text = stringValue
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
        case .array(let items):
            for item in items { if let text = item.packFirstText { return text } }
            return nil
        default: return nil
        }
    }
}

// MARK: - Weights

/// Weights, held in kilograms. The server sends them with their unit ("58.8 kg", "750 gm") and works
/// them out the same way this does: quantity × the weight in the variant's name ("500 gms").
nonisolated enum PackWeight {
    private static let amount = try! NSRegularExpression(
        pattern: #"(\d+(?:\.\d+)?)\s*(kilograms?|kilos?|kgs?|grams?|gms?|g)(?![a-z])"#,
        options: .caseInsensitive
    )
    private static let thousands = try! NSRegularExpression(pattern: #"(?<=\d),(?=\d{3})"#)

    /// "58.8 kg", "750 gm", "1,500 g" → kg. A number without a unit is no weight: "100" could be
    /// grams or kilos, and guessing wrong is worse than showing the app's own sum.
    static func parse(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let s = thousands.stringByReplacingMatches(in: raw, range: NSRange(raw.startIndex..., in: raw), withTemplate: "")
        guard let m = amount.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let numberRange = Range(m.range(at: 1), in: s),
              let unitRange = Range(m.range(at: 2), in: s),
              let n = Double(s[numberRange]) else { return nil }
        return s[unitRange].lowercased().hasPrefix("g") ? n / 1000 : n
    }

    /// One unit's weight from its variant name, "500 gms" → 0.5. "100 ml", "1 pc" or "Pack of 6" are no weight.
    static func ofVariant(_ variant: String) -> Double? { parse(variant) }

    /// "2 kg", "1.25 kg", "750 g", "0 kg". Under a kilo it reads in grams, the way the variants are named.
    static func format(_ kg: Double) -> String {
        if kg <= 0 { return "0 kg" }
        if kg < 1 { return "\(trim(kg * 1000, places: 0)) g" }
        return "\(trim(kg, places: 2)) kg"
    }

    /// Android's `BigDecimal.setScale(HALF_UP).stripTrailingZeros()`.
    private static func trim(_ value: Double, places: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.roundingMode = .halfUp
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = places
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

// MARK: - Dates

/// The packer lists' dates. The server has sent `2026-10-07`, now sends `order_date` as `07/10/2026`,
/// the order lists use `03-nov-2026 04:53 pm`, and an empty `assign_date` arrives as `30/11/-0001`
/// (MySQL's zero date run through PHP), which must read as no date rather than a real one.
nonisolated enum PackDates {
    /// Parsed and shown in UTC: these are wall-clock times as the server wrote them, so no zone
    /// shift (or daylight-saving gap) may move them.
    private static let utc = TimeZone(identifier: "UTC")!
    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = utc
        return c
    }

    private static func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = utc
        f.dateFormat = pattern
        return f
    }

    private static let withTime = [
        "dd/MM/yyyy hh:mm a", "dd/MM/yyyy HH:mm:ss", "dd/MM/yyyy HH:mm",
        "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm",
        "dd-MMM-yyyy hh:mm a", "dd MMM yyyy hh:mm a",
    ].map(formatter)
    private static let dateOnly = ["dd/MM/yyyy", "yyyy-MM-dd", "dd-MM-yyyy", "dd-MMM-yyyy", "dd MMM yyyy"].map(formatter)
    private static let dayLabel = formatter("dd MMM yyyy")
    private static let timeLabel = formatter("h:mm a")
    private static let isoPrefix = try! NSRegularExpression(pattern: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}"#)

    /// A date and whether the server said what time; nil for blank, unreadable or zero dates.
    static func parse(_ raw: String?) -> (date: Date, hasTime: Bool)? {
        guard var s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        // ISO with fractions or a zone ("2026-11-04T06:06:38.000000Z"): the first 19 characters are enough.
        if isoPrefix.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil { s = String(s.prefix(19)) }
        // Java parses "nov" and "pm" case-insensitively; ICU wants "Nov" and "PM".
        s = normalizedCase(s)
        var found: (Date, Bool)?
        for f in withTime { if let d = f.date(from: s) { found = (d, true); break } }
        if found == nil { for f in dateOnly { if let d = f.date(from: s) { found = (d, false); break } } }
        guard let (date, hasTime) = found else { return nil }
        let comps = calendar.dateComponents([.era, .year], from: date)
        guard comps.era == 1, (comps.year ?? 0) >= 2000 else { return nil }
        return (date, hasTime)
    }

    /// "07 Oct 2026", or "04 Nov 2026, 11:36 AM" when the server sent a time.
    static func label(_ raw: String?) -> String? {
        guard let (date, hasTime) = parse(raw) else { return nil }
        return hasTime ? "\(dayLabel.string(from: date)), \(timeLabel.string(from: date))" : dayLabel.string(from: date)
    }

    /// Sorts newest first; a date without a time counts as the start of its day.
    static func sortKey(_ raw: String?) -> Date? { parse(raw)?.date }

    private static func normalizedCase(_ s: String) -> String {
        guard s.contains(where: \.isLetter) else { return s }
        return s.split(separator: " ", omittingEmptySubsequences: false).map { word -> String in
            let w = String(word)
            if w.lowercased() == "am" || w.lowercased() == "pm" { return w.uppercased() }
            // "03-nov-2026" → "03-Nov-2026"
            return w.split(separator: "-", omittingEmptySubsequences: false).map { part -> String in
                let p = String(part)
                guard p.count >= 3, p.allSatisfy(\.isLetter) else { return p }
                return p.prefix(1).uppercased() + p.dropFirst().lowercased()
            }.joined(separator: "-")
        }.joined(separator: " ")
    }
}

/// A calendar day the user picked (Android `LocalDate`), sent as `2026-10-07`.
nonisolated struct PackDay: Equatable, Hashable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    /// The day `date` falls on here, as the date picker shows it.
    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    static var today: PackDay { PackDay(date: Date()) }

    var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// Midday of the day, local time, for the date picker.
    var date: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    /// "07 Oct 2026".
    var label: String { PackDates.label(iso) ?? iso }
}

// MARK: - Rows

/// `paker-list` row.
struct PackerDto: Identifiable, Equatable {
    var id = 0
    var name = ""
    var mobile = ""
    var staffId = ""

    init(id: Int = 0, name: String = "", mobile: String = "", staffId: String = "") {
        self.id = id; self.name = name; self.mobile = mobile; self.staffId = staffId
    }

    init(json: JSONValue) {
        id = json.packInt("id") ?? 0
        name = json.packStr("name") ?? ""
        mobile = json.packStr("mobile") ?? ""
        staffId = json.packStr("staff_id") ?? ""
    }
}

/// A row of `paker-orders` (the whole packing board) or `paker/my-orders` (the packer's own).
struct PackOrderDto: Identifiable, Equatable {
    var id = 0
    /// The order number people read, `#2026-27/4066`.
    var orderNo = ""
    /// The bill date; older builds of the server sent it as `date`.
    var orderDate = ""
    var date = ""
    /// When the packer got the order. Not a date yet while the server sends `30/11/-0001`.
    var assignDate = ""
    var totalPrice = "0"
    var status = 0
    var statusLabel = ""
    var sellerName = ""
    /// The seller's mobile; a number on the wire.
    var sellerNo = ""
    var shopName = ""
    var beatName = ""
    var itemsCount: Int?
    var packerId: Int?
    var packerName: String?
    /// "58.8 kg", like `V2/order-list2`'s; nil until the packer lists send it.
    var totalWeight: String?

    init(id: Int = 0, orderNo: String = "", status: Int = 0) {
        self.id = id; self.orderNo = orderNo; self.status = status
    }

    init(json: JSONValue) {
        id = json.packInt("id") ?? 0
        orderNo = json.packStr("order_id") ?? ""
        orderDate = json.packStr("order_date") ?? ""
        date = json.packStr("date") ?? ""
        assignDate = json.packStr("assign_date") ?? ""
        totalPrice = json.packStr("total_price") ?? "0"
        status = json.packInt("status") ?? 0
        statusLabel = json.packStr("status_label") ?? ""
        sellerName = json.packStr("seller_name") ?? ""
        sellerNo = json.packStr("seller_no") ?? ""
        shopName = json.packStr("shop_name") ?? ""
        beatName = json.packStr("beat_name") ?? ""
        itemsCount = json.packInt("items_count")
        packerId = json.packInt("paker_id")
        // Present but blank is still "no packer"; Android keeps "" and checks isNullOrBlank.
        packerName = json["paker_name"].flatMap { $0.stringValue.isEmpty && !isText($0) ? nil : $0.stringValue }
        totalWeight = json.packStr("total_weight")
    }

    var total: Double { Double(totalPrice) ?? 0 }
    var weightKg: Double? { PackWeight.parse(totalWeight) }
    var billDate: String? { PackDates.label(orderDate.isEmpty ? date : orderDate) }
    var assignedOn: String? { PackDates.label(assignDate) }
    var stage: PackStage { PackStage.of(status, statusLabel) }
    var board: BoardTab { BoardTab.of(status) }
    var hasPacker: Bool { !(packerName ?? "").trimmingCharacters(in: .whitespaces).isEmpty }

    /// My Packing's search box: bill number, shop, owner's name, mobile, beat. Done here because
    /// `paker/my-orders` ignores the bill, shop and seller filters `paker-orders` takes.
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        return [orderNo, shopName, sellerName, sellerNo, beatName].contains { $0.localizedCaseInsensitiveContains(q) }
    }
}

private func isText(_ value: JSONValue) -> Bool {
    if case .string = value { return true }
    return false
}

/// One page of a list; `total` is the whole query's count, as the server reports it.
struct PackPage<T> {
    let items: [T]
    let lastPage: Int
    let total: Int

    /// Android `decodePage`: `data` as a plain array with `current_page`/`last_page` beside it (the
    /// paker lists), Laravel's paginator (`data: {data: [...], last_page}`), a `meta`/`pagination`
    /// object, or no paging at all.
    static func parse(_ root: JSONValue, row: (JSONValue) -> T?) -> PackPage<T> {
        let d = root["data"]
        let paginator = d?.isObject == true ? d : nil
        let rows: [JSONValue] = d?.isArray == true ? d!.arrayValue : (paginator?["data"]?.arrayValue ?? [])
        var meta: JSONValue? = paginator
        if meta == nil, let m = root["meta"], m.isObject { meta = m }
        if meta == nil, let m = root["pagination"], m.isObject { meta = m }
        if meta == nil, root["last_page"] != nil { meta = root }
        let items = rows.compactMap(row)
        let current = meta?.packInt("current_page") ?? 1
        return PackPage(items: items, lastPage: meta?.packInt("last_page") ?? current, total: meta?.packInt("total") ?? items.count)
    }
}

/// Every beat, for the board's beat filter (`beat-list`).
struct PackBeat: Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
}

/// What the board asks `paker-orders` for; nil filters aren't sent. The search box is a bill
/// number only: a seller is picked from the seller list, never typed.
struct BoardQuery: Equatable {
    var status: Int?
    var beatId: Int?
    /// The bill date.
    var date: PackDay?
    var billNo: String?
    /// A seller picked from the seller list: sent as their id, mobile, shop and name together.
    var seller: PackSeller?

    init(status: Int? = nil, beatId: Int? = nil, date: PackDay? = nil, billNo: String? = nil, seller: PackSeller? = nil) {
        self.status = status; self.beatId = beatId; self.date = date; self.billNo = billNo; self.seller = seller
    }

    func body(page: Int, perPage: Int) -> [String: Any] {
        var body: [String: Any] = [:]
        if let status { body["status"] = status }
        if let beatId { body["beat_id"] = beatId }
        if let date { body["date"] = date.iso }
        if let bill = billNo?.trimmingCharacters(in: .whitespacesAndNewlines), !bill.isEmpty { body["bill_no"] = bill }
        if let s = seller {
            body["seller_id"] = s.id
            if !s.mobile.trimmingCharacters(in: .whitespaces).isEmpty { body["seller_no"] = s.mobile }
            if !s.shopName.trimmingCharacters(in: .whitespaces).isEmpty { body["shop_name"] = s.shopName }
            if !s.name.trimmingCharacters(in: .whitespaces).isEmpty { body["seller_name"] = s.name }
        }
        body["per_page"] = perPage
        body["page"] = page
        return body
    }
}

/// A state, city or beat from `get-all-data`; `children` are a state's cities or a city's beats.
struct PackArea: Identifiable, Equatable {
    let id: Int
    let name: String
    var children: [PackArea] = []

    /// Android `PackerApi.areas`: states, their cities and the cities' beats, each level A–Z.
    static func tree(from root: JSONValue) -> [PackArea] {
        let data = (root["data"]?.isObject == true ? root["data"] : nil) ?? root
        func areas(_ o: JSONValue, _ key: String, _ children: (JSONValue) -> [PackArea]) -> [PackArea] {
            o.packArray(key).compactMap { e -> PackArea? in
                guard e.isObject, let id = e.packInt("id") else { return nil }
                return PackArea(id: id, name: (e.packStr("name") ?? "").trimmingCharacters(in: .whitespaces), children: children(e))
            }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        // Without a user_id the server files the states under "0" instead of "states".
        var statesKey = "states"
        if data["states"]?.isArray != true, case .object(let fields) = data,
           let key = fields.first(where: { $0.value.isArray })?.key { statesKey = key }
        return areas(data, statesKey) { s in areas(s, "cities") { c in areas(c, "beats") { _ in [] } } }
    }
}

/// A `seller-list2` row, what the board's seller filter picks.
struct PackSeller: Identifiable, Equatable, Hashable {
    let id: Int
    let name: String
    let shopName: String
    /// The seller's mobile; a number on the wire.
    let mobile: String
    /// The beat's name; seller-list2 sends names, not ids, in its beat field.
    let beat: String
    var active = true

    var title: String {
        if !shopName.trimmingCharacters(in: .whitespaces).isEmpty { return shopName }
        if !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return "Seller #\(id)"
    }

    static func from(_ o: JSONValue) -> PackSeller? {
        guard o.isObject, let id = o.packInt("id") else { return nil }
        var beat = (o.packStr("beat", "beat_name") ?? "")
        if beat.trimmingCharacters(in: .whitespaces).isEmpty {
            let raw = o.packStr("beat_id") ?? ""
            beat = Int(raw) == nil ? raw : ""
        }
        return PackSeller(
            id: id,
            name: (o.packStr("name", "seller_name") ?? "").trimmingCharacters(in: .whitespaces),
            shopName: (o.packStr("shop_name") ?? "").trimmingCharacters(in: .whitespaces),
            mobile: (o.packStr("mobile", "seller_no", "phone") ?? "").trimmingCharacters(in: .whitespaces),
            beat: beat,
            active: (o.packStr("status") ?? "").lowercased() != "inactive"
        )
    }
}

extension Array where Element == PackOrderDto {
    /// Most recently assigned first; orders without an assignment date keep the server's order after them.
    func latestAssignedFirst() -> [PackOrderDto] {
        // Keyed once and tie-broken by position, so equal dates keep the server's order.
        let keyed: [(index: Int, key: Date)] = indices.map { i in
            (i, PackDates.sortKey(self[i].assignDate) ?? Date.distantPast)
        }
        let order = keyed.sorted { a, b in
            if a.key != b.key { return a.key > b.key }
            return a.index < b.index
        }
        return order.map { self[$0.index] }
    }

    func distinctById() -> [PackOrderDto] {
        var seen = Set<Int>()
        return filter { seen.insert($0.id).inserted }
    }
}

/// `paker/order-logs/{id}` row.
struct PackLogDto: Identifiable, Equatable {
    var id = 0
    /// assigned, reassigned, start_packing, reopen_packing, create_package, add_item, remove_item, delete_package, complete_packing
    var action = ""
    var note = ""
    var packerName: String?
    var doneBy: String?
    var createdAt = ""

    init(json: JSONValue) {
        id = json.packInt("id") ?? 0
        action = json.packStr("action") ?? ""
        note = json.packStr("note") ?? ""
        packerName = json.packStr("paker_name")
        doneBy = json.packStr("done_by")
        createdAt = json.packStr("created_at") ?? ""
    }

    var title: String {
        switch action {
        case "assigned": return "Packer assigned"
        case "reassigned": return "Packer changed"
        case "start_packing": return "Packing started"
        case "reopen_packing": return "Packing reopened"
        case "create_package": return "Box added"
        case "add_item": return "Item packed"
        case "remove_item": return "Item removed"
        case "delete_package": return "Box deleted"
        case "complete_packing": return "Marked packed"
        default:
            let words = action.replacingOccurrences(of: "_", with: " ")
            return words.prefix(1).uppercased() + words.dropFirst()
        }
    }
}

/// The packing statuses: 10 Assigned (a packer has it), 11 In Packing, 12 Packed. These names are
/// shown everywhere instead of the server's `status_label`, which differs between endpoints
/// ("Paker Assigned" on one list, "Assigned" on another).
///
/// An order that has gone on to a rider (1 to deliver, 2 picked up, 3 delivered, 4 cancelled,
/// 5 returned, 6 assigned) is past packing: it sits with the packed ones, locked, under its own
/// name. `paker/my-orders` keeps sending those with the label "Unknown", and filing them under
/// Assigned put finished orders in front of the packer with a Start packing button.
nonisolated enum PackStage: Int, CaseIterable, Hashable {
    case assigned = 10
    case packing = 11
    case packed = 12

    static let statusPending = 0
    static let statusAssigned = 10
    static let statusPacking = 11
    static let statusPacked = 12

    var status: Int { rawValue }

    var title: String {
        switch self {
        case .assigned: return "Assigned"
        case .packing: return "In Packing"
        case .packed: return "Packed"
        }
    }

    static func of(_ status: Int, _ label: String) -> PackStage {
        let l = label.lowercased()
        if status == statusAssigned { return .assigned }
        if status == statusPacking { return .packing }
        if status == statusPacked { return .packed }
        if afterPackingTitle(status) != nil { return .packed }
        if l.contains("start") || l.contains("in pack") || l.contains("progress") { return .packing }
        if l.contains("packed") || l.contains("done") || l.contains("complete") { return .packed }
        if status > statusPacking { return .packed }
        return .assigned
    }

    /// What happened to an order after packing, by the sales app's own status names; nil while it is still the packer's.
    static func afterPackingTitle(_ status: Int) -> String? {
        switch status {
        case 1: return "To deliver"
        case 2: return "Picked up"
        case 3: return "Delivered"
        case 4: return "Cancelled"
        case 5: return "Returned"
        case 6: return "With rider"
        default: return nil
        }
    }
}

/// The admin board's tabs, one per status. A packer can be given (or changed on) any order but a
/// packed one; the server refuses 12.
nonisolated enum BoardTab: CaseIterable, Hashable {
    case pending, assigned, packing, packed

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .assigned: return PackStage.assigned.title
        case .packing: return PackStage.packing.title
        case .packed: return PackStage.packed.title
        }
    }

    var status: Int {
        switch self {
        case .pending: return PackStage.statusPending
        case .assigned: return PackStage.statusAssigned
        case .packing: return PackStage.statusPacking
        case .packed: return PackStage.statusPacked
        }
    }

    var canAssign: Bool { self != .packed }

    static func of(_ status: Int) -> BoardTab { allCases.first { $0.status == status } ?? .pending }
}

// MARK: - Order detail

/// One product line of an order and how much of it is in boxes already.
struct PackLine: Identifiable, Equatable {
    /// `order_detail_id`, what a box item points at.
    let id: Int
    let name: String
    let variant: String
    let image: String
    let qty: Int
    let packed: Int
    /// The server's `qty_remaining`, else what `packed` leaves.
    let left: Int
    /// One unit's weight in kg: the server's, else read off the variant ("500 gms"); nil when neither says.
    var unitKg: Double?
    /// One unit's price (`per_price`).
    var price: Double?

    init(id: Int, name: String, variant: String, image: String, qty: Int, packed: Int, left: Int? = nil, unitKg: Double? = nil, price: Double? = nil) {
        self.id = id; self.name = name; self.variant = variant; self.image = image
        self.qty = qty; self.packed = packed; self.left = left ?? max(qty - packed, 0)
        self.unitKg = unitKg; self.price = price
    }

    var totalKg: Double? { unitKg.map { $0 * Double(qty) } }
    var packedKg: Double? { unitKg.map { $0 * Double(min(packed, qty)) } }
    var leftKg: Double? { unitKg.map { $0 * Double(left) } }
}

struct PackBoxItem: Identifiable, Equatable {
    /// The box row's own id (`packages[].items[].id`), which remove-package-item takes.
    let id: Int
    let orderDetailId: Int
    let name: String
    let variant: String
    let qty: Int
    var unitKg: Double?
    var image = ""
    /// The server's `item_weight` for this row.
    var serverKg: Double?

    var kg: Double? { serverKg ?? unitKg.map { $0 * Double(qty) } }
}

struct PackBox: Identifiable, Equatable {
    let id: Int
    let name: String
    let items: [PackBoxItem]
    /// How many product lines the server says are in the box, even when it doesn't list them.
    let itemsCount: Int
    /// The box's weight as the server sends it; `kg` falls back to adding up the items.
    var serverKg: Double?

    var units: Int { items.reduce(0) { $0 + $1.qty } }
    var isEmpty: Bool { items.isEmpty && itemsCount == 0 }

    /// Nil when a listed item's weight is unknown, rather than a total that quietly leaves it out.
    var kg: Double? {
        if let serverKg { return serverKg }
        if isEmpty { return 0 }
        if items.count < itemsCount || items.contains(where: { $0.kg == nil }) { return nil }
        return items.reduce(0) { $0 + ($1.kg ?? 0) }
    }

    func qtyOf(_ orderDetailId: Int) -> Int {
        items.filter { $0.orderDetailId == orderDetailId }.reduce(0) { $0 + $1.qty }
    }

    /// A box from order-detail's `packages` (items inline) or from package-detail. `unitKgOf` gives
    /// an item the weight of its order line when the box row doesn't carry its own.
    static func from(_ o: JSONValue, unitKgOf: (Int) -> Double? = { _ in nil }) -> PackBox {
        let box = (o["package"]?.isObject == true ? o["package"] : nil) ?? o
        var rawItems = o.packArray("items", "package_items")
        if rawItems.isEmpty { rawItems = box.packArray("items", "package_items") }
        let items = rawItems.compactMap { i -> PackBoxItem? in
            guard i.isObject else { return nil }
            let orderDetailId = i.packInt("order_detail_id") ?? 0
            let variant = i.packStr("variant_name") ?? ""
            return PackBoxItem(
                id: i.packInt("id", "package_item_id") ?? 0,
                orderDetailId: orderDetailId,
                name: i.packStr("product_name", "name") ?? "",
                variant: variant,
                qty: i.packInt("qty_packed", "qty") ?? 0,
                unitKg: unitKgOf(orderDetailId) ?? PackWeight.ofVariant(variant),
                image: i.packStr("product_image", "image") ?? "",
                serverKg: PackWeight.parse(i.packStr("item_weight"))
            )
        }
        let id = box.packInt("package_id", "id") ?? 0
        let name = box.packStr("package_name", "name", "label") ?? "Box \(box.packStr("package_no") ?? String(id))"
        return PackBox(id: id, name: name, items: items, itemsCount: box.packInt("items_count") ?? items.count,
                       serverKg: PackWeight.parse(box.packStr(boxWeightKeys)))
    }
}

/// Where the server puts weights; settled against staging's `paker/order-detail`.
private let lineUnitWeightKeys = ["weight_per_unit", "unit_weight", "per_unit_weight", "product_weight"]
private let boxWeightKeys = ["package_weight", "total_weight", "weight"]

/// `paker/order-detail/{id}`: the order's lines with `qty_packed`/`qty_remaining`, and its boxes
/// with their items inline.
struct PackOrderDetail: Equatable {
    let id: Int
    let orderNo: String
    let shopName: String
    let sellerName: String
    let beatName: String
    let date: String
    /// When the order was handed to its packer (`assign_date`), as the server sends it.
    let assignDate: String
    let totalPrice: Double?
    let status: Int
    let statusLabel: String
    /// The order's `total_weight` in kg; `totalKg` prefers adding up the lines when every line's weight is known.
    let serverTotalKg: Double?
    let lines: [PackLine]
    let boxes: [PackBox]
    /// Whether `PackLine.packed` is real: the server sent `qty_packed`, or listed every box's
    /// items. When neither, the server alone knows what is packed and decides.
    let packedKnown: Bool

    var stage: PackStage { PackStage.of(status, statusLabel) }
    /// Set once the order has gone on to a rider: nothing on it is the packer's to change.
    var afterPacking: String? { PackStage.afterPackingTitle(status) }
    var totalUnits: Int { lines.reduce(0) { $0 + $1.qty } }
    var packedUnits: Int { lines.reduce(0) { $0 + min($1.packed, $1.qty) } }
    var allPacked: Bool { !lines.isEmpty && lines.allSatisfy { $0.left == 0 } }
    var unitsLeft: Int { lines.reduce(0) { $0 + $1.left } }

    private var lineWeightsKnown: Bool { !lines.isEmpty && lines.allSatisfy { $0.unitKg != nil } }

    /// Lines first, so packed + left always add up to the total shown beside them.
    var totalKg: Double? { lineWeightsKnown ? lines.reduce(0) { $0 + ($1.totalKg ?? 0) } : serverTotalKg }
    var packedKg: Double? { lineWeightsKnown && packedKnown ? lines.reduce(0) { $0 + ($1.packedKg ?? 0) } : nil }
    var leftKg: Double? { lineWeightsKnown && packedKnown ? lines.reduce(0) { $0 + ($1.leftKg ?? 0) } : nil }

    static func from(_ data: JSONValue) -> PackOrderDetail {
        let order = (data["order"]?.isObject == true ? data["order"] : nil) ?? data
        var rawLines = data.packArray("items", "order_details")
        if rawLines.isEmpty { rawLines = order.packArray("items", "order_details") }
        rawLines = rawLines.filter(\.isObject)
        var unitKgByLine: [Int: Double] = [:]
        for l in rawLines {
            if let id = l.packInt("order_detail_id", "id"), let kg = unitKg(of: l) { unitKgByLine[id] = kg }
        }
        var rawBoxes = data.packArray("packages")
        if rawBoxes.isEmpty { rawBoxes = order.packArray("packages") }
        let boxes = rawBoxes.filter(\.isObject).map { PackBox.from($0) { unitKgByLine[$0] } }
        let boxesListed = boxes.allSatisfy { $0.items.count >= $0.itemsCount }
        var packedByLine: [Int: Int] = [:]
        for item in boxes.flatMap(\.items) { packedByLine[item.orderDetailId, default: 0] += item.qty }
        var serverCounts = false
        let lines = rawLines.compactMap { l -> PackLine? in
            guard let id = l.packInt("order_detail_id", "id") else { return nil }
            let qty = l.packInt("qty", "quantity") ?? 0
            let fromServer = l.packInt("qty_packed")
            if fromServer != nil { serverCounts = true }
            let packed = fromServer ?? packedByLine[id] ?? 0
            return PackLine(
                id: id,
                name: l.packStr("product_name", "name") ?? "Item \(id)",
                variant: l.packStr("variant_name", "variant") ?? "",
                image: l.packStr("product_image", "image") ?? "",
                qty: qty,
                packed: packed,
                left: l.packInt("qty_remaining") ?? max(qty - packed, 0),
                unitKg: unitKgByLine[id],
                price: l.packStr("per_price", "price").flatMap(Double.init)
            )
        }
        return PackOrderDetail(
            id: order.packInt("id") ?? 0,
            orderNo: order.packStr("order_no", "order_id", "order_number") ?? "",
            shopName: order.packStr("shop_name", "seller_shop_name") ?? "",
            sellerName: order.packStr("seller_name") ?? "",
            beatName: order.packStr("beat_name") ?? "",
            date: order.packStr("order_date", "date") ?? "",
            assignDate: order.packStr("assign_date") ?? "",
            totalPrice: order.packStr("total_price").flatMap(Double.init),
            status: order.packInt("status") ?? 0,
            statusLabel: order.packStr("status_label") ?? "",
            serverTotalKg: PackWeight.parse(order.packStr("total_items_weight", "total_weight") ?? data.packStr("total_items_weight", "total_weight")),
            lines: lines,
            boxes: boxes,
            packedKnown: serverCounts || boxesListed
        )
    }

    /// A line's unit weight: the server's own field when it sends one, else the variant's name.
    private static func unitKg(of line: JSONValue) -> Double? {
        PackWeight.parse(line.packStr(lineUnitWeightKeys)) ?? PackWeight.ofVariant(line.packStr("variant_name", "variant") ?? "")
    }
}

// MARK: - List states

/// The seller picker's own list: `seller-list2` narrowed by state, city and beat (the order filters'
/// way of finding a seller) and by a search the server matches to shop, owner and mobile, a page at a time.
struct SellerPickState: Equatable {
    var areas: [PackArea] = []
    var stateId: Int?
    var cityId: Int?
    var beatId: Int?
    var query = ""
    var sellers: [PackSeller] = []
    var loading = false
    var error: String?
    var page = 0
    var lastPage = 0
    var total = 0
    var loadingMore = false

    var state: PackArea? { areas.first { $0.id == stateId } }
    var city: PackArea? { state?.children.first { $0.id == cityId } }
    var beat: PackArea? { city?.children.first { $0.id == beatId } }
    var canLoadMore: Bool { page >= 1 && page < lastPage }
}

/// Orders waiting for the yes in "Assign N orders to X?".
struct PendingAssign: Equatable {
    let packer: PackerDto
    let orderIds: Set<Int>
    let reassign: Bool
}

/// The board is filtered and paged by the server: the open tab's rows a page at a time, each tab's
/// count from the server's total. A bill number search instead asks for every match across the tabs
/// and splits them by tab here. Sellers are filtered only through the seller picker.
struct AssignPackerUiState {
    /// The open tab's rows loaded so far; while searching, every match in every tab.
    var orders: [PackOrderDto] = []
    var packers: [PackerDto] = []
    /// Every beat, for the beat filter.
    var allBeats: [PackBeat] = []
    var isLoading = true
    var error: String?
    var tab = BoardTab.pending
    var query = ""
    /// Nil shows every beat; the server filters one beat at a time.
    var beat: PackBeat?
    /// The bill date; nil shows every date.
    var date: PackDay?
    /// A seller picked from the seller list; nil shows every seller.
    var seller: PackSeller?
    /// Set while the seller picker is open.
    var sellerPick: SellerPickState?
    /// Each tab's count for the current beat, date and search, from the server.
    var counts: [BoardTab: Int] = [:]
    /// The open tab's pages loaded so far and the server's last one.
    var page = 0
    var lastPage = 0
    var loadingMore = false
    var moreError: String?
    var selected: Set<Int> = []
    /// The orders the packer sheet is open for.
    var pickingFor: Set<Int>?
    var confirm: PendingAssign?
    var assigning = false
    var dialogError: String?
    /// Shown once after an assignment goes through.
    var done: String?
    /// The order whose history sheet is open, and what was loaded for it.
    var logsFor: PackOrderDto?
    var logs: [PackLogDto]?
    var logsError: String?

    var searching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var filtered: Bool { searching || beat != nil || date != nil || seller != nil }
    var canLoadMore: Bool { !searching && page >= 1 && page < lastPage }

    func count(_ t: BoardTab) -> Int { counts[t] ?? 0 }

    var shown: [PackOrderDto] {
        let inTab = searching ? orders.filter { $0.board == tab } : orders
        // Waiting orders keep the server's order; once a packer has one, the latest handed over is on top.
        return tab == .pending ? inTab : inTab.latestAssignedFirst()
    }

    var selectedOrders: [PackOrderDto] { orders.filter { selected.contains($0.id) } }
    var allShownSelected: Bool {
        let rows = shown
        return !rows.isEmpty && rows.allSatisfy { selected.contains($0.id) }
    }

    /// The packer every order in `ids` already has, if they share one.
    func currentPacker(_ ids: Set<Int>) -> Int? {
        let packers = orders.filter { ids.contains($0.id) }.map(\.packerId)
        let distinct = packers.reduce(into: [Int?]()) { if !$0.contains($1) { $0.append($1) } }
        return distinct.count == 1 ? distinct[0] : nil
    }
}

/// The packer's queue, a tab at a time: each tab is a server `status` with its own pages and its
/// count from the server's total. Search is the exception. `paker/my-orders` only searches bill
/// numbers, so the first search loads the whole queue once and every letter after filters it here.
struct PackerOrdersUiState {
    /// The open tab's rows loaded so far; while searching, the packer's whole queue.
    var orders: [PackOrderDto] = []
    var isLoading = true
    var error: String?
    var tab = PackStage.assigned
    var query = ""
    /// The bill date, filtered by the server; nil shows every date.
    var date: PackDay?
    /// Each tab's count from the server.
    var counts: [PackStage: Int] = [:]
    var page = 0
    var lastPage = 0
    var loadingMore = false
    var moreError: String?

    var searching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canLoadMore: Bool { !searching && page >= 1 && page < lastPage }

    private var matching: [PackOrderDto] { orders.filter { $0.matches(query) } }

    func count(_ stage: PackStage) -> Int {
        searching ? matching.filter { $0.stage == stage }.count : counts[stage] ?? 0
    }

    var shown: [PackOrderDto] {
        (searching ? matching.filter { $0.stage == tab } : orders).latestAssignedFirst()
    }
}

/// Counts for the home cards: the packer's own queue, and pending orders still without a packer.
struct PackerWidgetState: Equatable {
    var loading = true
    var failed = false
    var toPack = 0
    var packing = 0
    var packed = 0
    var pending = 0
}
