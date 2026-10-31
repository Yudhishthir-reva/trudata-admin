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

/// Mirrors Android `CashAccess.forRole`. The server enforces the same split (403 on the admin
/// endpoints); this only decides what Utility shows.
struct CashAccess {
    let canReviewAll: Bool
    let canEdit: Bool
    /// Their own bill registers. Everyone has them but Office Staff, who handles no customer bills.
    let canViewOwnBills: Bool
    var canManageAmountTaken: Bool { canReviewAll }
    var canViewLedger: Bool { canReviewAll }
    var canManageAdvance: Bool { canReviewAll }
    var canManageBills: Bool { canReviewAll }
    /// Mark anyone's attendance by hand and read what was marked (Android `canManageAttendance`).
    var canManageAttendance: Bool { ManualAttendanceAccess.allowed(role: role) }

    private let role: String

    init(role: String) {
        let role = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.role = role
        canReviewAll = ["admin", "accountant", "sales manager"].contains(role)
        canEdit = role == "admin"
        canViewOwnBills = !DashboardRole.isOfficeStaff(role)
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

/// Android `ErrorDialog`'s title and message.
struct CashAlert: Equatable {
    static let defaultTitle = "Can't continue"
    /// The Submit tab's own title for a refused count.
    static let countsTitle = "Check the counts"
    var title = CashAlert.defaultTitle
    let message: String
}

/// Android `digitsOnly`: keeps digits, drops leading zeros, caps the length.
func cashDigits(_ text: String, max: Int) -> String {
    let digits = String(text.filter { $0.isASCII && $0.isNumber }.drop { $0 == "0" })
    return String(digits.prefix(max))
}

struct CashCountForm {
    /// Android caps: the total at 9 digits, each count at 6, the remark at 250 characters.
    static let declaredMax = 9
    static let countMax = 6
    static let remarkMax = 250

    var declared = "" { didSet { if declared != oldValue { declaredError = nil } } }
    var remark = ""
    var counts: [String: String] = [:]
    /// Shown under the total box after a refused submit; typing in the total clears it.
    var declaredError: String?

    private var pieces: Int { counts.values.compactMap(Int.init).reduce(0, +) }

    /// Android `askSubmit` / `askSave`: what stops this count being sent, if anything. Submit
    /// marks the total box; edit only explains, as Android does.
    func problem(editing: Bool) -> (field: String?, message: String)? {
        let declared = Int(self.declared) ?? 0
        if declared <= 0 {
            return editing
                ? (nil, "Enter the total cash amount")
                : ("Enter the total cash amount", "Enter the total cash amount you are handing over, then count each note and coin.")
        }
        if !editing && pieces == 0 { return (nil, "Count the notes and coins before submitting.") }
        let counted = total ?? 0
        if counted != declared {
            let base = "The counts add up to \(cashRupeeText(counted)), not \(cashRupeeText(declared))."
            return (nil, editing ? base : base + " Fix the counts or the total.")
        }
        return nil
    }

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
        var body: [String: Any] = ["total_cash_amount": amount,
                                   "remark": String(remark.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.remarkMax))]
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
    var numericValue: Int {
        Int(label.split(separator: ".").first.map(String.init)?.filter(\.isNumber) ?? "") ?? 0
    }
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
    /// Running cash in hand after this line. Ledger rows carry it; other lists do not.
    let balanceAfter: Int?
    /// `collection` or `amount_taken` on ledger rows; empty on the other lists.
    let ledgerType: String
    var isAmountTaken: Bool { ledgerType == "amount_taken" }
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
        ledgerType = json["type"]?.stringValue ?? ""
        denominations = json["denominations"]?.arrayValue.map(CashLine.init) ?? []
        balanceAfter = json["balance_after"]?.cashRupees
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

/// The `summary` block the ledger endpoint returns. Totals here cover the whole filtered period,
/// unlike anything derived from the rows currently paged in.
struct CashLedgerSummary {
    let openingBalance: Int
    let totalCollection: Int
    let totalTaken: Int
    let netAmount: Int
    let closingBalance: Int

    init?(_ json: JSONValue?) {
        guard let summary = json else { return nil }
        openingBalance = summary["opening_balance"]?.cashRupees ?? 0
        totalCollection = summary["total_collection"]?.cashRupees ?? 0
        totalTaken = summary["total_taken"]?.cashRupees ?? 0
        netAmount = summary["net_amount"]?.cashRupees ?? 0
        closingBalance = summary["closing_balance"]?.cashRupees ?? 0
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

    /// Android `periodPhrase`: reads inside a sentence ("No amount was taken in October").
    var periodPhrase: String {
        switch period {
        case .today: return "today"
        case .all: return "yet"
        case .month: return "in \(month.formatted(.dateTime.month(.wide).year()))"
        case .range:
            let start = from.formatted(date: .abbreviated, time: .omitted)
            let end = to.formatted(date: .abbreviated, time: .omitted)
            return Calendar.current.isDate(from, inSameDayAs: to)
                ? "on \(start)"
                : "between \(start) and \(end)"
        }
    }
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

/// "₹1,25,000", as Android's `rupees` writes amounts inside a sentence.
func cashRupeeText(_ amount: Int) -> String {
    amount.formatted(.currency(code: "INR").precision(.fractionLength(0)).locale(Locale(identifier: "en_IN")))
}
