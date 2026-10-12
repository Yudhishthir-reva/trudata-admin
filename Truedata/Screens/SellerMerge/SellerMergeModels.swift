import Foundation

struct MergeSeller: Identifiable {
    let json: JSONValue
    var id: Int { json["id"]?.intValue ?? 0 }
    var title: String {
        let shop = json["shop_name"]?.stringValue ?? ""
        let name = json["name"]?.stringValue ?? ""
        return !shop.isEmpty ? shop : !name.isEmpty ? name : "Seller #\(id)"
    }
    var isActive: Bool { json["status"]?.stringValue.lowercased() == "active" }
    var phone: String { json["mobile"]?.stringValue ?? "" }
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty || [title, json["name"]?.stringValue ?? "", phone].contains { $0.localizedCaseInsensitiveContains(q) }
    }
}

struct SellerMergeResponse: Decodable {
    let status: Bool
    let message: String?
    let data: JSONValue?
}

enum SellerMergeAccess {
    static var allowed: Bool {
        let role = DashboardRole.normalized(UserDefaultManager.shared.getUserDefaultsString(key: .userRole))
        return BASE_URL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "https://spicemonk.in/staging/api"
            && ["admin", "accountant", "sales manager", "sale manager"].contains(role)
    }
}

struct SellerMergeOutcome {
    let primary: MergeSeller
    let secondary: MergeSeller
    let recordsMoved: Int
    let message: String
}
