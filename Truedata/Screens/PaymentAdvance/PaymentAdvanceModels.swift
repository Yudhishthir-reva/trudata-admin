import Foundation

struct PaymentAdvanceAccess {
    let canManage: Bool
    init(role: String) {
        canManage = ["admin", "sales manager", "accountant"].contains(role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

enum AdvanceStatus: String, CaseIterable, Identifiable {
    case pending, partial, completed, onHold = "on_hold", cancelled
    var id: String { rawValue }
    var title: String { rawValue.replacingOccurrences(of: "_", with: " ").capitalized }
    /// Android `AdvanceStatus.isOpen`: completed and cancelled advances take no more payments.
    static func isOpen(_ status: String) -> Bool {
        [AdvanceStatus.pending, .partial, .onHold].map(\.rawValue).contains(status.lowercased())
    }
}

struct PaymentAdvanceRecord: Identifiable {
    let recordID: Int
    let advanceID: Int
    let isReturn: Bool
    var id: String { "\(isReturn ? "returned" : "advance")-\(recordID)" }
    let amount: Decimal
    let outstanding: Decimal
    let text: String
    let status: String
    let date: String
    let person: String
    let personID: Int
    let role: String
    let author: String
    let attachment: URL?
    let createdAt: String
    let returns: [PaymentAdvanceRecord]

    init(_ json: JSONValue, isReturn: Bool = false) throws {
        self.isReturn = isReturn || json["record_type"]?.stringValue == "returned"
        recordID = json["id"]?.intValue ?? 0
        advanceID = self.isReturn ? json["advance_id"]?.intValue ?? 0 : recordID
        guard recordID > 0, advanceID > 0, let value = Self.money(json["amount"]) else {
            throw PaymentAdvanceError.invalidResponse
        }
        amount = value
        if self.isReturn { outstanding = 0 }
        else {
            guard let value = Self.money(json["outstanding"]) else { throw PaymentAdvanceError.invalidResponse }
            outstanding = value
        }
        text = json[self.isReturn ? "remark" : "purpose"]?.stringValue ?? ""
        status = self.isReturn ? "returned" : json["status"]?.stringValue ?? ""
        date = json["date"]?.stringValue ?? ""
        person = json["person"]?["name"]?.stringValue ?? ""
        personID = json["person"]?["id"]?.intValue ?? 0
        role = json["person"]?["role"]?["name"]?.stringValue ?? json["person"]?["role"]?.stringValue ?? ""
        author = json[self.isReturn ? "received_by" : "given_by"]?["name"]?.stringValue ?? ""
        createdAt = json["created_at"]?.stringValue ?? ""
        attachment = json["attachment"].flatMap { URL(string: $0.stringValue) }.flatMap { ["https", "http"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }
        returns = try (json["returns"]?.arrayValue ?? []).map { try Self($0, isReturn: true) }
    }

    static func money(_ value: JSONValue?) -> Decimal? {
        guard let raw = value?.stringValue else { return nil }
        return PaymentAdvanceForm.amount(raw)
    }
}

enum PaymentAdvanceError: LocalizedError {
    case invalidResponse
    case message(String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The server returned invalid payment data. Please retry."
        case .message(let message): return message
        }
    }
}

struct PaymentAdvanceFilter: Equatable {
    var type = "all"
    var status = ""
    var roleID = 0
    var staffIDs: Set<Int> = []
    var search = ""
    var usesDates = false
    var from = Date()
    var to = Date()
    var isValid: Bool { !usesDates || from <= to }
    func parameters(page: Int, canManage: Bool) -> [String: Any] {
        var params: [String: Any] = ["type": type, "per_page": 15, "page": page]
        if usesDates {
            params["date_from"] = Self.date(from)
            params["date_to"] = Self.date(to)
        }
        if canManage {
            if type != "returned", !status.isEmpty { params["status"] = status }
            if roleID > 0 { params["role_id"] = roleID }
            if !staffIDs.isEmpty { params["staff_ids"] = staffIDs.sorted() }
            let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
            if !search.isEmpty { params["search"] = search }
        }
        return params
    }
    static func date(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }
}

struct PaymentAdvanceForm {
    /// Android caps: amount 9 digits, purpose / remark 250 characters, attachment 5 MB.
    static let amountMax = 9
    static let textMax = 250
    static let fileMaxBytes = 5 * 1024 * 1024

    var personID = 0
    var amount = ""
    var date = Date()
    var text = ""

    /// Android `submit()` on the give / receive forms: what is wrong with each field, worded the
    /// same, so the screen can mark the field and list them in "Can't continue".
    func problems(advance: PaymentAdvanceRecord?) -> (person: String?, amount: String?) {
        let value = Int64(amount) ?? 0
        guard let advance else {
            return (personID > 0 ? nil : "Choose who the advance is for",
                    value > 0 ? nil : "Enter an amount above ₹0")
        }
        if !AdvanceStatus.isOpen(advance.status) {
            let label = AdvanceStatus(rawValue: advance.status.lowercased())?.title.lowercased() ?? advance.status.lowercased()
            return (nil, "This advance is \(label); nothing can be received against it")
        }
        if value <= 0 { return (nil, "Enter an amount above ₹0") }
        if Decimal(value) > advance.outstanding { return (nil, "Only \(advanceRupeeText(advance.outstanding)) is outstanding") }
        return (nil, nil)
    }

    static func amount(_ raw: String) -> Decimal? {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard !raw.isEmpty, raw.filter(\.isNumber).drop(while: { $0 == "0" }).count <= 38,
              parts.count <= 2, !parts[0].isEmpty,
              parts[0].allSatisfy({ $0.isASCII && $0.isNumber }),
              parts.count == 1 || (!parts[1].isEmpty && parts[1].count <= 2 && parts[1].allSatisfy { $0.isASCII && $0.isNumber }),
              let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")), !value.isNaN else { return nil }
        return value
    }

    func parameters(advance: PaymentAdvanceRecord?) throws -> [String: Any] {
        guard !amount.isEmpty, amount.allSatisfy({ $0.isASCII && $0.isNumber }),
              let wholeAmount = Int64(amount), wholeAmount > 0 else {
            throw PaymentAdvanceError.message("Enter a whole-rupee amount above ₹0.")
        }
        let amount = Decimal(wholeAmount)
        guard date <= Date() else { throw PaymentAdvanceError.message("Choose today or an earlier date.") }
        var params: [String: Any] = ["date": PaymentAdvanceFilter.date(date)]
        if let advance {
            guard !advance.isReturn, advance.outstanding > 0, advance.status != "cancelled",
                  amount <= advance.outstanding else { throw PaymentAdvanceError.message("Receive amount must not exceed this advance's outstanding balance.") }
            guard PaymentAdvanceFilter.date(date) >= advance.date else { throw PaymentAdvanceError.message("Return date cannot be before the advance date.") }
            params["advance_id"] = advance.recordID
            params["receive_amount"] = NSDecimalNumber(decimal: amount).stringValue
            let remark = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !remark.isEmpty { params["remark"] = String(remark.prefix(Self.textMax)) }
        } else {
            guard personID > 0 else { throw PaymentAdvanceError.message("Select a person.") }
            params["person_id"] = personID
            params["amount"] = NSDecimalNumber(decimal: amount).stringValue
            let purpose = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !purpose.isEmpty { params["purpose"] = String(purpose.prefix(Self.textMax)) }
        }
        return params
    }
}

/// "₹1,25,000.5", as Android's `rupees` writes an amount inside a sentence.
func advanceRupeeText(_ amount: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "INR"
    formatter.locale = Locale(identifier: "en_IN")
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "₹\(amount)"
}
