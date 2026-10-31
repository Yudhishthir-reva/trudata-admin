// Android `PendingBillsFilterTest.kt`, ported. Run:
// swiftc Truedata/Core/Network/LenientDecoding.swift Truedata/Screens/OrderApproval/ViewPendingBillsModels.swift Tests/PendingBillsChecks.swift -o /tmp/pending-checks && /tmp/pending-checks
import Foundation

@main
struct PendingBillsChecks {
    /// Bills shaped like `view-pending-payment-bill-list` rows (shops and people made up).
    static func bill(
        _ id: Int, _ order: String, _ date: String, _ due: String, total: String? = nil,
        shop: String = "Shree Dayal Bhojnalaya", staff: String = "Abdul SP",
        status: String = "0", mode: String = "0", orderStatus: String = "3"
    ) -> PendingPaymentBill {
        PendingPaymentBill(
            id: id, transactionNo: "#44\(id)91", orderDate: date, amount: total ?? due, remainingAmount: due,
            paymentStatus: status, paymentMode: mode, sellerName: shop, staffName: staff,
            orderId: "#2026-27/\(order)", orderStatus: orderStatus
        )
    }

    static func ids(_ bills: [PendingPaymentBill]) -> [Int] { bills.map(\.id) }

    static func main() throws {
        let bills = [
            bill(1, "4456", "27-Oct-2026", "1050"),
            bill(2, "4310", "12-Oct-2026", "500", total: "2,000", staff: "Laxman SP", status: "1", mode: "1"),
            bill(3, "3990", "28-Sep-2026", "0", total: "750", shop: "Gupta Kirana", status: "2", mode: "3", orderStatus: "4")
        ]
        let none = PendingBillsFilter()

        // Search finds the order number with or without its prefix.
        assert(ids(bills.narrow("4456", none)) == [1])
        assert(ids(bills.narrow("#2026-27/4456", none)) == [1])
        assert(ids(bills.narrow("gupta", none)) == [3])
        assert(ids(bills.narrow("laxman", none)) == [2])
        assert(ids(bills.narrow("dayal laxman", none)) == [2], "every word has to match")
        assert(bills.narrow("nobody", none).isEmpty)

        // The date range is inclusive; one end alone is open on the other.
        let oct = PendingBillsFilter(from: PendingBillsFilter.day(2026, 10, 12), to: PendingBillsFilter.day(2026, 10, 27))
        assert(ids(bills.narrow("", oct)) == [1, 2])
        let openEnded = PendingBillsFilter(to: PendingBillsFilter.day(2026, 9, 30))
        assert(ids(bills.narrow("", openEnded)) == [3])

        // Sets and due bounds.
        assert(ids(bills.narrow("", PendingBillsFilter(salesPeople: ["Laxman SP"]))) == [2])
        assert(ids(bills.narrow("", PendingBillsFilter(shops: ["Gupta Kirana"]))) == [3])
        assert(ids(bills.narrow("", PendingBillsFilter(modes: [pendingBillNoMode]))) == [1], "mode 0 = not paid yet")
        assert(ids(bills.narrow("", PendingBillsFilter(orderStatuses: ["4"]))) == [3])
        assert(ids(bills.narrow("", PendingBillsFilter(minDue: 100, sort: .remainingLow))) == [2, 1])
        assert(bills[1].total == 2000)

        // Sorts, and counting active filters.
        assert(ids(bills.narrow("", none)) == [1, 2, 3])
        assert(ids(bills.narrow("", PendingBillsFilter(sort: .oldest))) == [3, 2, 1])
        assert(ids(bills.narrow("", PendingBillsFilter(sort: .remainingHigh))) == [1, 2, 3])
        assert(!PendingBillsFilter(sort: .oldest).isActive, "sort alone isn't a filter")
        assert(PendingBillsFilter(from: PendingBillsFilter.startOfDay(Date()), minDue: 1).activeCount == 2)

        // Filter choices are distinct and A–Z; labels come from the server maps.
        assert(bills.choices { $0.sellerName } == ["Gupta Kirana", "Shree Dayal Bhojnalaya"])
        let labels = PendingBillLabels(
            paymentModes: [PaymentLookupItem(key: 1, label: "cash")],
            orderStatuses: [PaymentLookupItem(key: 3, label: "Delivered")]
        )
        assert(labels.mode("0") == "Not paid yet" && labels.mode("1") == "Cash" && labels.mode("9") == "9")
        assert(labels.orderStatus("3") == "Delivered" && labels.orderStatus("4") == "4")

        // The list carries the server's total for "{loaded} of {total}".
        let page = Data(#"{"status":true,"message":"","data":{"last_page":"3","total":25,"response":{"billList":{"current_page":1,"last_page":3,"total":"25","data":[{"id":"7","amount":"2,000","remainingAmount":500,"paymentStatus":1}]}}}}"#.utf8)
        let response = try JSONDecoder().decode(PendingPaymentBillsResponse.self, from: page)
        let list = response.data.response.billList
        assert(list.total == 25 && list.lastPage == 3 && response.data.lastPage == 3)
        assert(list.data.first?.total == 2000 && list.data.first?.due == 500 && list.data.first?.statusKey == "1")

        print("PendingBillsChecks passed")
    }
}
