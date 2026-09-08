//
//  ChequeSettlementModels.swift
//  Truedata
//

import Foundation

// MARK: - Pending settle cheque list

struct PendingSettleChequeListResponse: Decodable {
    var status: Bool
    var message: String
    var currentPage: Int
    var perPage: Int
    var hasMore: Bool
    var data: [PendingSettleChequeSeller]

    enum CodingKeys: String, CodingKey {
        case status, message, data
        case currentPage = "current_page"
        case perPage = "per_page"
        case hasMore = "has_more"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.joined(separator: "\n")
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        currentPage = container.decodeIntLeniently(forKey: .currentPage) ?? 1
        perPage = container.decodeIntLeniently(forKey: .perPage) ?? 15
        hasMore = container.decodeBoolLeniently(forKey: .hasMore) ?? false
        data = (try? container.decode([PendingSettleChequeSeller].self, forKey: .data)) ?? []
    }
}

struct PendingSettleChequeSeller: Identifiable, Decodable, Hashable {
    var id: Int { sellerId }
    var sellerId: Int
    var name: String
    var shopName: String
    var mobile: String
    var sellerCode: String
    var totalChequeAmount: Double
    var cheques: [ChequeItem]

    enum CodingKeys: String, CodingKey {
        case name, mobile, cheques
        case sellerId = "seller_id"
        case shopName = "shop_name"
        case sellerCode = "seller_code"
        case totalChequeAmount = "total_cheque_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sellerId = container.decodeIntLeniently(forKey: .sellerId) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        sellerCode = container.decodeStringLeniently(forKey: .sellerCode) ?? ""
        totalChequeAmount = {
            if let value = try? container.decode(Double.self, forKey: .totalChequeAmount) { return value }
            if let value = try? container.decode(Int.self, forKey: .totalChequeAmount) { return Double(value) }
            if let value = container.decodeStringLeniently(forKey: .totalChequeAmount), let parsed = Double(value) {
                return parsed
            }
            return 0
        }()
        cheques = (try? container.decode([ChequeItem].self, forKey: .cheques)) ?? []
    }

    var displayTitle: String {
        shopName.isEmptyString ? name : shopName
    }

    var chequeCount: Int { cheques.count }
}

struct ChequeItem: Identifiable, Decodable, Hashable {
    var id: Int
    var amount: Double
    /// Nil when the list endpoint omits it on untouched cheques (Android `remainingAmount`).
    var remainingAmount: Double?
    var chequeClearDate: String
    var date: String
    var image: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, date, image
        case remainingAmount = "remaining_amount"
        case chequeClearDate = "cheque_clear_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        amount = Self.decodeAmount(container, key: .amount) ?? 0
        remainingAmount = Self.decodeAmount(container, key: .remainingAmount)
        chequeClearDate = container.decodeStringLeniently(forKey: .chequeClearDate) ?? ""
        date = container.decodeStringLeniently(forKey: .date) ?? ""
        image = container.decodeStringLeniently(forKey: .image)
        if image?.isEmptyString == true { image = nil }
    }

    /// What is actually spendable — face value until first partial settlement.
    var spendable: Double { remainingAmount ?? amount }

    var isPartlySpent: Bool {
        guard let remaining = remainingAmount else { return false }
        return remaining < amount
    }

    private static func decodeAmount(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if !container.contains(key) { return nil }
        if let value = try? container.decode(Double.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? container.decode(String.self, forKey: key), let parsed = Double(value) {
            return parsed
        }
        return nil
    }
}

// MARK: - Settlement plan (Android `chequeSettlementPlan`)

struct ChequeSettlementPlan {
    var billsTotal: Double
    var chequeAvailable: Double
    var discount: Double
    var amount: Double
    var shortfall: Double
    var chequeLeftover: Double

    var coversAllBills: Bool { shortfall <= 0 }
    var isSettleable: Bool { amount > 0 }

    static func make(
        billsTotal: Double,
        chequeAvailable: Double,
        discount: Double = 0
    ) -> ChequeSettlementPlan {
        let bills = max(billsTotal, 0)
        let cheque = max(chequeAvailable, 0)
        let writtenOff = min(max(discount, 0), bills)
        let payable = bills - writtenOff
        let amount = min(payable, cheque)
        return ChequeSettlementPlan(
            billsTotal: bills,
            chequeAvailable: cheque,
            discount: writtenOff,
            amount: amount,
            shortfall: payable - amount,
            chequeLeftover: cheque - amount
        )
    }
}

enum ChequeFormatters {
    static func rupees(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let number = formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
            return "₹\(number)"
        }
        return String(format: "₹%.2f", amount)
    }

    static func plainAmount(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(amount))
        }
        return String(format: "%.2f", amount)
    }

    static func chequeDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "-" }
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd"
        guard let date = iso.date(from: trimmed) else { return trimmed }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "dd MMM yyyy"
        return out.string(from: date)
    }

    static func clearingLabel(_ rawClearDate: String) -> String {
        let trimmed = rawClearDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Clearing -" }
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd"
        iso.timeZone = TimeZone.current
        guard let date = iso.date(from: trimmed) else {
            return "Clearing \(trimmed)"
        }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let verb = date > startOfToday ? "Clears on" : "Cleared on"
        return "\(verb) \(chequeDate(trimmed))"
    }
}

// MARK: - Cheque bill list

struct ChequeBillListResponse: Decodable {
    var status: Bool
    var message: String
    var data: ChequeBillListData

    enum CodingKeys: String, CodingKey {
        case status, message, data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = container.decodeBoolLeniently(forKey: .status) ?? false
        if let list = try? container.decode([String].self, forKey: .message) {
            message = list.joined(separator: "\n")
        } else {
            message = container.decodeStringLeniently(forKey: .message) ?? ""
        }
        data = (try? container.decode(ChequeBillListData.self, forKey: .data)) ?? ChequeBillListData()
    }
}

struct ChequeBillListData: Decodable {
    var seller: ChequeSettlementSeller
    var cheques: [ChequeItem]
    var billList: [ChequeBillItem]
    var totalPending: Double

    enum CodingKeys: String, CodingKey {
        case seller, cheques
        case billList = "billList"
        case totalPending = "totalPending"
    }

    init(
        seller: ChequeSettlementSeller = ChequeSettlementSeller(),
        cheques: [ChequeItem] = [],
        billList: [ChequeBillItem] = [],
        totalPending: Double = 0
    ) {
        self.seller = seller
        self.cheques = cheques
        self.billList = billList
        self.totalPending = totalPending
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seller = (try? container.decode(ChequeSettlementSeller.self, forKey: .seller)) ?? ChequeSettlementSeller()
        cheques = (try? container.decode([ChequeItem].self, forKey: .cheques)) ?? []
        billList = (try? container.decode([ChequeBillItem].self, forKey: .billList)) ?? []
        if let value = try? container.decode(Double.self, forKey: .totalPending) {
            totalPending = value
        } else if let value = try? container.decode(Int.self, forKey: .totalPending) {
            totalPending = Double(value)
        } else if let value = try? container.decode(String.self, forKey: .totalPending), let parsed = Double(value) {
            totalPending = parsed
        } else {
            totalPending = 0
        }
    }
}

struct ChequeSettlementSeller: Decodable {
    var id: Int
    var name: String
    var shopName: String
    var mobile: String
    var sellerCode: String
    var address: String
    var state: String
    var city: String

    enum CodingKeys: String, CodingKey {
        case id, name, mobile, address, state, city
        case shopName = "shop_name"
        case sellerCode = "seller_code"
    }

    init(
        id: Int = 0,
        name: String = "",
        shopName: String = "",
        mobile: String = "",
        sellerCode: String = "",
        address: String = "",
        state: String = "",
        city: String = ""
    ) {
        self.id = id
        self.name = name
        self.shopName = shopName
        self.mobile = mobile
        self.sellerCode = sellerCode
        self.address = address
        self.state = state
        self.city = city
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        name = container.decodeStringLeniently(forKey: .name) ?? ""
        shopName = container.decodeStringLeniently(forKey: .shopName) ?? ""
        mobile = container.decodeStringLeniently(forKey: .mobile) ?? ""
        sellerCode = container.decodeStringLeniently(forKey: .sellerCode) ?? ""
        address = container.decodeStringLeniently(forKey: .address) ?? ""
        state = container.decodeStringLeniently(forKey: .state) ?? ""
        city = container.decodeStringLeniently(forKey: .city) ?? ""
    }

    var displayName: String {
        shopName.isEmptyString ? name : shopName
    }
}

struct ChequeBillItem: Identifiable, Decodable, Hashable {
    var id: Int
    var orderId: String
    var amount: Double
    var deductAmount: Double
    var status: Int
    var date: String

    enum CodingKeys: String, CodingKey {
        case id, amount, status, date
        case orderId = "order_id"
        case deductAmount = "deduct_amount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeIntLeniently(forKey: .id) ?? 0
        orderId = container.decodeStringLeniently(forKey: .orderId) ?? ""
        amount = Self.decodeAmount(container, key: .amount)
        deductAmount = Self.decodeAmount(container, key: .deductAmount)
        status = container.decodeIntLeniently(forKey: .status) ?? 0
        date = container.decodeStringLeniently(forKey: .date) ?? ""
    }

    private static func decodeAmount(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double {
        if let value = try? container.decode(Double.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return Double(value) }
        if let value = try? container.decode(String.self, forKey: key), let parsed = Double(value) {
            return parsed
        }
        return 0
    }
}
