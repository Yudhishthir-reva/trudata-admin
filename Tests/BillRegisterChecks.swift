import Foundation

@main
struct BillRegisterChecks {
    static func main() throws {
        let decoder = JSONDecoder()
        let calendar = Calendar(identifier: .gregorian)
        let march = calendar.date(from: DateComponents(year: 2026, month: 3, day: 31))!
        let april = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        assert(BillOrderSession.startYear(today: march, calendar: calendar) == 2025)
        assert(BillOrderSession.startYear(today: april, calendar: calendar) == 2026)
        assert(BillOrderSession.filter(" #2026-27/ ") == nil)
        assert(BillOrderSession.filter("2026-27") == nil)
        assert(BillOrderSession.filter("101") == "101")
        assert(BillOrderSession.replacingSession(in: "#2026-27/1780", with: 2024) == "#2024-25/1780")
        assert(BillOrderSession.replacingSession(in: "2026-27", with: 2024) == "#2024-25/")
        assert(BillOrderSession.year(in: "#2025-26/100") == 2025)

        if CommandLine.arguments.count > 1 {
            let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            let response = try decoder.decode(BillRegisterBeatOrdersResponse.self, from: data)
            assert(response.status && response.data?.orders.count == 128)
            let first = response.data!.orders[0]
            assert(first.orderId == 7387 && first.sellerMobile == "9460434554")
            assert(first.totalPrice == 1120 && first.billRegisterId == nil)
            assert(response.data!.orders.last!.pendingAmount == 169.23)
        }
        let empty = Data(#"{"status":true,"message":"OK","current_page":1,"last_page":1,"per_page":10,"total":0,"data":[]}"#.utf8)
        let list = try decoder.decode(BillRegisterListResponse.self, from: empty)
        assert(list.data.isEmpty && list.currentPage == 1)
        let register = BillRegisterEntry(json: .object([
            "id": .int(9), "beat_names": .array([.string("Mansarovar")]),
            "assigned_to_id": .int(7), "assigned_to": .string("Staff"),
            "status": .string("pending"), "total_orders": .int(3),
            "pending_orders": .int(2), "cleared_orders": .int(1),
            "total_amount": .string("1500.00"), "pending_amount": .int(750),
            "orders": .array([.object([
                "register_order_id": .int(22), "order_id": .int(101),
                "order_no": .string("#101"), "order_amount": .string("500.00"),
                "pending_amount": .int(300), "current_pending": .int(250),
                "payment_status": .string("pending")
            ])])
        ]))
        assert(register.id == 9 && register.assignedTo == 7 && register.name == "Staff")
        assert(register.beatNames == ["Mansarovar"] && register.totalOrders == 3)
        assert(register.pendingAmount == 750 && register.orders?.first?.currentPending == 250)
        let admin = BillRegisterAccess(role: "Admin", userId: 1)
        assert(BillRegisterAccess(role: " Accountant ", userId: 2).canManage)
        for role in ["sales manager", "sale person", "rider", "unknown"] {
            let access = BillRegisterAccess(role: role, userId: 7)
            assert(!access.canManage && access.canRead(assignedTo: 7) && !access.canRead(assignedTo: 8))
            let params = try BillRegisterRequest.list(assignedTo: 8).parameters(access: access)
            assert(params["assigned_to"] as? Int == 7)
            for request in [BillRegisterRequest.create(beatIds: [1], orderIds: [101], assignedTo: 7), .assign(id: 1, assignedTo: 7), .clear(id: 1)] {
                assert((try? request.parameters(access: access)) == nil)
            }
        }
        let all = try BillRegisterRequest.clear(id: 1).parameters(access: admin)
        let partial = try BillRegisterRequest.clear(id: 1, orderIds: [101, 102]).parameters(access: admin)
        assert(all["order_ids"] == nil && partial["order_ids"] as? [Int] == [101, 102])
        let numericOrderSearch = try BillRegisterRequest.list(assignedTo: 5, orderID: "101").parameters(access: admin)
        let formattedOrderSearch = try BillRegisterRequest.list(orderID: "#2026-27/1780").parameters(access: admin)
        assert(numericOrderSearch["order_id"] as? Int == 101 && numericOrderSearch["assigned_to"] as? Int == 5)
        assert(formattedOrderSearch["order_id"] as? String == "#2026-27/1780")
        assert((try? BillRegisterRequest.clear(id: 1, orderIds: []).parameters(access: admin)) == nil)
        let signedOut = BillRegisterAccess(role: "rider", userId: 0)
        assert((try? BillRegisterRequest.list().parameters(access: signedOut)) == nil)
        assert(!signedOut.canRead(assignedTo: 0))
        print("Bill Register checks passed: attached response, pagination, roles, assignment scoping and clear payloads.")
    }
}
