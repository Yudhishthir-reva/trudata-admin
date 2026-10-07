import Foundation

extension JSONValue {
    // The API may serialize whole rupees as "1,005.00". Fractional rupees are invalid here.
    var cashRupees: Int? {
        switch self {
        case .int(let value): return value
        case .double(let value):
            guard value.isFinite, value.rounded(.towardZero) == value,
                  value >= Double(Int.min), value < Double(Int.max) else { return nil }
            return Int(value)
        case .string(let raw):
            let value = raw.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = value.split(separator: ".", omittingEmptySubsequences: false)
            guard (parts.count == 1 || parts.count == 2 && !parts[1].isEmpty && parts[1].allSatisfy { $0 == "0" }),
                  let whole = parts.first, !whole.isEmpty else { return nil }
            return Int(whole)
        default: return nil
        }
    }
}

struct CashAccess {
    let canReviewAll: Bool
    let canEdit: Bool
    var canManageAmountTaken: Bool { canReviewAll }
    var canViewLedger: Bool { canReviewAll }

    init(role: String) {
        let role = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        canReviewAll = ["admin", "accountant", "sales manager"].contains(role)
        canEdit = role == "admin"
    }
}

struct CashDenomination: Identifiable {
    let value: Int
    let kind: String
    var id: String { "\(kind)_\(value)" }
    var label: String { "₹\(value) \(kind)" }
    static let all = [500, 200, 100, 50, 20, 10, 5].map { Self(value: $0, kind: "note") }
        + [20, 10, 5, 2, 1].map { Self(value: $0, kind: "coin") }
}

struct CashCountForm {
    var declared = ""
    var remark = ""
    var counts: [String: String] = [:]

    // Reject invalid/overflowing input instead of silently clamping a money entry.
    var total: Int? {
        var total = 0
        for denomination in CashDenomination.all {
            let text = counts[denomination.id, default: ""]
            guard text.isEmpty || text.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let count = text.isEmpty ? 0 : Int(text), count <= Int(Int32.max) else { return nil }
            let (amount, overflow) = count.multipliedReportingOverflow(by: denomination.value)
            let (sum, sumOverflow) = total.addingReportingOverflow(amount)
            guard !overflow, !sumOverflow else { return nil }
            total = sum
        }
        return total
    }

    var isBalanced: Bool { Int(declared).map { $0 > 0 && $0 == total } ?? false }

    func parameters(id: Int? = nil) -> [String: Any]? {
        guard isBalanced, let amount = Int(declared) else { return nil }
        var body: [String: Any] = ["total_cash_amount": amount, "remark": remark]
        for denomination in CashDenomination.all {
            body[denomination.id] = Int(counts[denomination.id, default: ""]) ?? 0
        }
        if let id { body["id"] = id }
        return body
    }

    init() {}
    init(record: CashRecord) {
        declared = String(record.amount)
        remark = record.remark
        for line in record.denominations {
            let value = Int(line.label.split(separator: ".").first.map(String.init)?.filter(\.isNumber) ?? "")
            if let denomination = CashDenomination.all.first(where: { $0.value == value && $0.kind == line.kind.lowercased().trimmingCharacters(in: .whitespaces) }) {
                counts[denomination.id] = String(line.quantity)
            }
        }
    }
}

struct CashLine: Identifiable {
    let field: String
    let label: String
    let kind: String
    let quantity: Int
    let total: Int
    var id: String { field.isEmpty ? "\(kind)-\(label)" : field }
    init(_ json: JSONValue) {
        field = json["field"]?.stringValue ?? ""
        label = json["label"]?.stringValue ?? ""
        kind = json["type"]?.stringValue ?? ""
        quantity = json["qty"]?.intValue ?? 0
        total = json["total"]?.cashRupees ?? 0
    }
}

struct CashRecord: Identifiable {
    let id: Int
    let amount: Int
    let status: String
    let name: String
    let date: String
    let submittedAt: String
    let remark: String
    let reason: String
    let reviewedBy: String
    let takenBy: String
    let denominations: [CashLine]
    init(_ json: JSONValue) {
        id = json["id"]?.intValue ?? 0
        amount = (json["total_amount"] ?? json["amount"])?.cashRupees ?? 0
        status = json["status"]?.stringValue.lowercased() ?? ""
        name = (json["submitted_by"] ?? json["person"] ?? json["staff"])?["name"]?.stringValue ?? ""
        date = (json["date"] ?? json["submitted_at"])?.stringValue ?? ""
        submittedAt = (json["submitted_at"] ?? json["date"])?.stringValue ?? ""
        remark = json["remark"]?.stringValue ?? ""
        reason = json["reason"]?.stringValue ?? ""
        reviewedBy = json["reviewed_by"]?["name"]?.stringValue ?? ""
        takenBy = json["taken_by"]?["name"]?.stringValue ?? ""
        denominations = json["denominations"]?.arrayValue.map(CashLine.init) ?? []
    }
}

struct CashStaffSummary: Identifiable {
    let id: Int
    let name: String
    let entries: Int
    let amount: Int
    let denominations: [CashLine]
    init(_ json: JSONValue) {
        id = json["staff_id"]?.intValue ?? 0
        name = json["staff_name"]?.stringValue ?? ""
        entries = json["entries"]?.intValue ?? 0
        amount = json["total_amount"]?.cashRupees ?? 0
        denominations = json["denominations"]?.arrayValue.map(CashLine.init) ?? []
    }
}

struct CashSummary {
    let entries: Int
    let amount: Int
    let denominations: [CashLine]
    let staff: [CashStaffSummary]
    init(_ json: JSONValue) {
        entries = json["summary"]?["total_entries"]?.intValue ?? 0
        amount = json["summary"]?["grand_total_amount"]?.cashRupees ?? 0
        denominations = json["summary"]?["denominations"]?.arrayValue.map(CashLine.init) ?? []
        staff = json["staff_wise"]?.arrayValue.map(CashStaffSummary.init) ?? []
    }
}

enum CashPeriod: String, CaseIterable { case today = "Today", range = "Range", month = "Month", all = "All" }

struct CashFilter: Equatable {
    var period: CashPeriod = .month
    var from = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    var to = Date()
    var month = Date()
    var staffIds: Set<Int> = []
    var status = ""
    var isValid: Bool { period != .range || from <= to }

    func parameters(now: Date = Date(), calendar: Calendar = .current) -> [String: Any] {
        var params: [String: Any] = [:]
        switch period {
        case .today:
            params["date_from"] = Self.dateString(now)
            params["date_to"] = Self.dateString(now)
        case .range:
            params["date_from"] = Self.dateString(from)
            params["date_to"] = Self.dateString(to)
        case .month:
            if let interval = calendar.dateInterval(of: .month, for: month),
               let end = calendar.date(byAdding: .day, value: -1, to: interval.end) {
                params["date_from"] = Self.dateString(interval.start)
                params["date_to"] = Self.dateString(end)
            }
        case .all: break
        }
        if !staffIds.isEmpty { params["staff_ids"] = staffIds.sorted() }
        return params
    }

    static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
