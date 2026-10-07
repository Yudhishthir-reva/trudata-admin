// Run with JSONValue.swift and PaymentAdvanceModels.swift using swiftc.
import Foundation

@main
struct PaymentAdvanceChecks {
    static func main() throws {
        assert(PaymentAdvanceAccess(role: " Accountant ").canManage)
        assert(PaymentAdvanceAccess(role: "Sales Manager").canManage)
        assert(!PaymentAdvanceAccess(role: "rider").canManage)
        assert(!PaymentAdvanceAccess(role: "sale person").canManage)
        assert(!PaymentAdvanceAccess(role: "unknown").canManage)
        let data = Data(#"{"id":1,"amount":100,"outstanding":59,"purpose":"Travel","attachment":null,"status":"partial","date":"2025-07-10","person":{"id":55,"name":"Staff","role":null},"returns":[{"id":1,"advance_id":1,"amount":41,"remark":null,"date":"2025-07-12"}]}"#.utf8)
        let record = try PaymentAdvanceRecord(JSONDecoder().decode(JSONValue.self, from: data))
        assert(record.amount == 100 && record.outstanding == 59 && record.role.isEmpty)
        assert(record.id != record.returns[0].id && record.returns[0].advanceID == 1)
        assert(record.returns[0].text.isEmpty && record.attachment == nil)
        var form = PaymentAdvanceForm()
        form.personID = 55; form.amount = "50"; form.text = " Travel "
        let give = try form.parameters(advance: nil)
        let receive = try form.parameters(advance: record)
        assert(give["amount"] as? String == "50")
        assert(give["purpose"] as? String == "Travel")
        assert(receive["advance_id"] as? Int == 1)
        assert(receive["receive_amount"] as? String == "50")
        form.amount = "59"
        assert((try? form.parameters(advance: record)) != nil)
        form.amount = "60"
        assert((try? form.parameters(advance: record)) == nil)
        for invalid in ["", "-1", "0", "1.25", "1.234", "NaN", "1e3", "1garbage", "1.", String(repeating: "9", count: 40)] {
            form.amount = invalid
            assert((try? form.parameters(advance: nil)) == nil)
        }
        form.amount = "1"; form.personID = 0
        assert((try? form.parameters(advance: nil)) == nil)
        var filter = PaymentAdvanceFilter()
        filter.roleID = 3; filter.search = "Staff"; filter.status = "pending"; filter.staffIDs = [3, 7]
        let staffFiltered = filter.parameters(page: 1, canManage: true)
        assert(staffFiltered["staff_ids"] as? [Int] == [3, 7])
        let own = filter.parameters(page: 1, canManage: false)
        assert(own["search"] == nil && own["role_id"] == nil && own["status"] == nil && own["staff_ids"] == nil)
        filter.type = "returned"
        assert(filter.parameters(page: 2, canManage: true)["status"] == nil)
        assert(filter.parameters(page: 2, canManage: true)["role_id"] as? Int == 3)
        let blank = PaymentAdvanceFilter().parameters(page: 1, canManage: true)
        assert(blank["date_from"] == nil && blank["role_id"] == nil && blank["search"] == nil)
        form.personID = 55; form.amount = "1"; form.text = " "
        let optional = try form.parameters(advance: nil)
        assert(optional["purpose"] == nil)
        filter.usesDates = true; filter.from = Date(); filter.to = .distantPast
        assert(!filter.isValid)
        print("Payment advance checks passed: access, mixed IDs, decoding, money validation, overpayment and filters.")
    }
}
