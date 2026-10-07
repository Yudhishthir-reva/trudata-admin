// Run: swiftc Truedata/Core/Network/JSONValue.swift Truedata/Screens/CashCollection/CashCollectionModels.swift Tests/CashCollectionChecks.swift -o /tmp/cash-checks && /tmp/cash-checks
import Foundation

@main
struct CashCollectionChecks {
    static func main() throws {
        assert(CashAccess(role: " Admin ").canEdit)
        assert(CashAccess(role: "sales manager").canReviewAll)
        assert(CashAccess(role: "accountant").canManageAmountTaken)
        assert(!CashAccess(role: "accountant").canEdit)
        assert(!CashAccess(role: "sale person").canViewLedger)
        assert(!CashAccess(role: "rider").canReviewAll)
        assert(!CashAccess(role: "unknown").canReviewAll)
        var form = CashCountForm()
        assert(!form.isBalanced && form.parameters() == nil)
        form.declared = "526"
        form.counts = ["note_500": "1", "note_5": "1", "coin_20": "1", "coin_1": "1"]
        assert(form.total == 526 && form.isBalanced)
        assert(form.parameters()?["remark"] as? String == "")
        form.remark = "Cash collected from morning route"
        let body = form.parameters(id: 42)!
        assert(body.count == 15 && body["note_200"] as? Int == 0)
        assert(body["remark"] as? String == form.remark)
        assert(form.parameters()?["remark"] as? String == form.remark)
        assert(body["id"] as? Int == 42 && body["total_cash_amount"] as? Int == 526)
        form.declared = "525"
        assert(!form.isBalanced && form.parameters() == nil)
        for invalid in ["-1", "1.5", "garbage", String(Int.max), "99999999999999999999999"] {
            form.counts["note_500"] = invalid
            assert(form.total == nil && !form.isBalanced)
        }
        let payload = Data(#"{"data":{"id":7,"total_amount":"1,005.00","status":"pending","submitted_by":{"id":2,"name":"Test Staff"},"denominations":[{"label":"₹500","type":"note","qty":2,"total":"1000.00"},{"label":"5","type":"coin","qty":1,"total":5}]},"summary":{"total_entries":2,"grand_total_amount":"1,005.00","denominations":[]},"staff_wise":[{"staff_id":2,"staff_name":"Test Staff","entries":2,"total_amount":1005}]}"#.utf8)
        let json = try JSONDecoder().decode(JSONValue.self, from: payload)
        let record = CashRecord(json["data"]!)
        assert(record.amount == 1005 && record.name == "Test Staff")
        let edit = CashCountForm(record: record)
        assert(edit.isBalanced && edit.counts["note_500"] == "2" && edit.counts["coin_5"] == "1")
        let remarkedRecord = CashRecord(.object(["total_amount": .int(500), "remark": .string("Morning route")]))
        assert(CashCountForm(record: remarkedRecord).remark == "Morning route")
        let summary = CashSummary(json)
        assert(summary.amount == 1005 && summary.entries == 2 && summary.staff.first?.amount == 1005)
        assert(JSONValue.string("1,005.00").cashRupees == 1005)
        assert(JSONValue.double(1005.0).cashRupees == 1005)
        assert(JSONValue.string("1005.50").cashRupees == nil)
        assert(JSONValue.double(1005.5).cashRupees == nil)
        var filter = CashFilter()
        filter.period = .all
        assert(filter.parameters().isEmpty)
        filter.staffIds = [9, 2]
        assert(filter.parameters()["staff_ids"] as? [Int] == [2, 9])
        filter.period = .today
        let params = filter.parameters()
        assert(params["date_from"] as? String == params["date_to"] as? String)
        filter.period = .range
        filter.from = Date(timeIntervalSince1970: 100)
        filter.to = Date(timeIntervalSince1970: 0)
        assert(!filter.isValid)
        print("Cash collection checks passed: roles, balancing, overflow, required payload fields, decoding and filters.")
    }
}
