// Android `AssignOrderSearchTest.kt`, ported. Run:
// swiftc Truedata/Core/Network/LenientDecoding.swift Truedata/Screens/AssignOrder/AssignOrderModels.swift Tests/AssignOrderSearchChecks.swift -o /tmp/assign-order-checks && /tmp/assign-order-checks
import Foundation

// `VehicleItem` uses this app extension; `String+Extension.swift` drags in SwiftUI colours,
// so the checks carry the one helper they need.
extension String {
    var isEmptyString: Bool { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// The Assign Order search: the client searched by bill number and party name and found nothing.
@main
struct AssignOrderSearchChecks {
    static func main() throws {
        let order = AssignOrderItem(
            id: "7533", invoiceId: "#2026-27/4064", sellerShopName: "Jagdamba Department Store", staffName: "Laxman SP",
            totalAmount: "2560.00", sellerAddress: "", orderStatus: "Unknown", orderNotDelivered: false, date: "2026-10-07",
            beatId: "", beatName: "", sellerName: "Kalu Ji"
        )

        // Finds by bill number, shop or shopkeeper; a blank query keeps everything.
        assert(order.matches("4064"))
        assert(order.matches("2026-27/4064"))
        assert(order.matches("jagdamba"))
        assert(order.matches("kalu"))
        assert(order.matches("  "))
        assert(!order.matches("4065"))

        // `seller_name` decodes leniently and reaches the model the screen searches.
        let page = Data(##"{"status":true,"message":"","data":[{"order_id":"7533","order_no":"#2026-27/4064","seller_shop_name":"Jagdamba Department Store","seller_name":"Kalu Ji"}]}"##.utf8)
        let response = try JSONDecoder().decode(AssignOrderListResponse.self, from: page)
        assert(response.data.first?.asModel.sellerName == "Kalu Ji")
        assert(response.data.first?.asModel.matches("kalu") == true)

        print("AssignOrderSearchChecks passed")
    }
}
