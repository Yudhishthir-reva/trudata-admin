// Android `PackWeightTest.kt` and `PackerListAndDetailTest.kt`, ported. Run:
// swiftc Truedata/Core/Network/JSONValue.swift Truedata/Screens/Packer/PackerModels.swift Tests/PackerChecks.swift -o /tmp/packer-checks && /tmp/packer-checks
import Foundation

@main
struct PackerChecks {
    static func json(_ text: String) -> JSONValue {
        try! JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    static func rows(_ text: String) -> [PackOrderDto] { json(text).arrayValue.map(PackOrderDto.init(json:)) }

    static func near(_ a: Double?, _ b: Double, _ what: String) {
        guard let a else { fatalError("\(what): nil, wanted \(b)") }
        precondition(abs(a - b) < 1e-9, "\(what): \(a), wanted \(b)")
    }

    static func check(_ ok: Bool, _ what: String) { precondition(ok, what) }

    static func main() {
        weights()
        lists()
        details()
        boardQueries()
        print("PackerChecks: all passed")
    }

    // MARK: PackWeightTest

    static func weights() {
        // parsesTheServersWeightStrings
        near(PackWeight.parse("58.8 kg"), 58.8, "58.8 kg")
        near(PackWeight.parse("40.987 kg"), 40.987, "40.987 kg")
        near(PackWeight.parse("1.5 Kg"), 1.5, "1.5 Kg")
        near(PackWeight.parse("750 gm"), 0.75, "750 gm")
        near(PackWeight.parse("1,500 g"), 1.5, "1,500 g")
        // Grams or kilos? Not guessed.
        check(PackWeight.parse("36.000") == nil, "36.000 has no unit")
        check(PackWeight.parse("") == nil, "blank")
        check(PackWeight.parse("null") == nil, "null")
        check(PackWeight.parse(nil) == nil, "nil")

        // readsAUnitsWeightFromItsVariant
        near(PackWeight.ofVariant("100 gms"), 0.1, "100 gms")
        near(PackWeight.ofVariant("500 gms"), 0.5, "500 gms")
        near(PackWeight.ofVariant("140 gms"), 0.14, "140 gms")
        near(PackWeight.ofVariant("17 gms"), 0.017, "17 gms")
        near(PackWeight.ofVariant("1 KG"), 1.0, "1 KG")
        near(PackWeight.ofVariant("250g"), 0.25, "250g")

        // aVariantWithoutGramsOrKilosIsNoWeight
        check(PackWeight.ofVariant("100 ml") == nil, "100 ml")
        check(PackWeight.ofVariant("1 pc") == nil, "1 pc")
        check(PackWeight.ofVariant("Pack of 6") == nil, "Pack of 6")
        check(PackWeight.ofVariant("") == nil, "empty variant")

        // formatsKilosAndGrams
        check(PackWeight.format(2.0) == "2 kg", "2 kg")
        check(PackWeight.format(1.25) == "1.25 kg", "1.25 kg")
        check(PackWeight.format(36.0) == "36 kg", "36 kg")
        check(PackWeight.format(0.75) == "750 g", "750 g")
        check(PackWeight.format(0.14) == "140 g", "140 g: \(PackWeight.format(0.14))")
        check(PackWeight.format(0.0) == "0 kg", "0 kg")
    }

    // MARK: PackerListAndDetailTest

    /// Rows shaped like staging's `paker/my-orders` and `paker-orders` on 5 Nov 2026 (shops made up).
    static let myOrders = rows("""
        [
        {"id":7541,"order_id":"#2026-27/4072","order_date":"19/10/2026","assign_date":"30/11/-0001","total_price":"18082.50",
         "status":10,"status_label":"Assigned","seller_name":"Ramesh Ji","shop_name":"Ramesh Kirana","beat_name":"Nirman Nagar","items_count":1},
        {"id":7534,"order_id":"#2026-27/4065","order_date":"07/10/2026","assign_date":"03/11/2026","total_price":"2560.00",
         "status":6,"status_label":"Unknown","seller_name":"Dinesh Ji","shop_name":"Balaji Store","beat_name":"Mansarovar","items_count":5},
        {"id":7526,"order_id":"#2026-27/4057","order_date":"06/10/2026","assign_date":"04/11/2026 11:36 AM","total_price":"9000.00",
         "status":11,"status_label":"In Packing","seller_name":"Jagdish","seller_no":9351848341,"shop_name":"New Balaji Kirana",
         "beat_name":"PRN-Laxman Ji","items_count":14,"total_weight":"36 kg"},
        {"id":7529,"order_id":"#2026-27/4060","order_date":"06/10/2026","assign_date":"05/11/2026 09:10 AM","total_price":"100.00",
         "status":11,"status_label":"In Packing","seller_name":"Om Ji","shop_name":"Santosh Kirana","beat_name":"Nirman Nagar","items_count":18}
        ]
        """)

    static func lists() {
        // anOrderGoneToARiderIsNotWaitingToBePacked
        let withRider = myOrders.first { $0.status == 6 }!
        check(withRider.stage == .packed, "status 6 files under Packed")
        check(PackStage.afterPackingTitle(withRider.status) == "With rider", "With rider")
        // A search holds the whole queue, so its tab counts come from the rows themselves.
        check(PackerOrdersUiState(orders: myOrders, isLoading: false, query: "2026").count(.assigned) == 1, "search counts")
        check(PackStage.afterPackingTitle(PackStage.statusPacked) == nil, "12 is still the packer's")

        // readsTheBillDateTheAssignDateAndTheWeight
        let o = myOrders.first { $0.id == 7526 }!
        check(o.billDate == "06 Oct 2026", "bill date: \(o.billDate ?? "nil")")
        check(o.assignedOn == "04 Nov 2026, 11:36 AM", "assigned on: \(o.assignedOn ?? "nil")")
        near(o.weightKg, 36.0, "weight")
        check(o.sellerNo == "9351848341", "seller no: \(o.sellerNo)")

        // theZeroDateIsNoDate
        check(PackDates.label("30/11/-0001") == nil, "zero date")
        check(myOrders.first { $0.id == 7541 }!.assignedOn == nil, "zero assign date")
        check(PackDates.label("2026-10-07") == "07 Oct 2026", "iso day")
        check(PackDates.label("03-nov-2026 04:53 pm") == "03 Nov 2026, 4:53 PM", "order list date: \(PackDates.label("03-nov-2026 04:53 pm") ?? "nil")")
        check(PackDates.label("2026-11-04 06:06:38") == "04 Nov 2026, 6:06 AM", "sql stamp")
        check(PackDates.label("2026-11-04T06:06:38.000000Z") == "04 Nov 2026, 6:06 AM", "iso stamp")

        // theLatestAssignedIsOnTop
        let packing = PackerOrdersUiState(orders: myOrders.filter { $0.status == 11 }, isLoading: false, tab: .packing).shown
        check(packing.map(\.id) == [7529, 7526], "latest assigned first")

        // searchFindsBillNumberShopShopkeeperAndMobile
        func ids(_ q: String) -> [Int] {
            PackerOrdersUiState(orders: myOrders, isLoading: false, tab: .packing, query: q).shown.map(\.id)
        }
        check(ids("4057") == [7526], "bill no")
        check(ids("new balaji") == [7526], "shop")
        check(ids("jagdish") == [7526], "owner")
        check(ids("93518") == [7526], "mobile")

        // myPackingTabsAreServerStatusesWithServerCounts
        check(PackStage.allCases.map(\.status) == [10, 11, 12], "stage statuses")
        var s = PackerOrdersUiState(isLoading: false, counts: [.assigned: 9, .packing: 3], page: 1, lastPage: 2)
        check(s.count(.assigned) == 9, "server count")
        check(s.count(.packed) == 0, "missing count")
        check(s.canLoadMore, "more pages")
        s.query = "x"
        check(!s.canLoadMore, "search doesn't page")

        // aSearchSplitsItsMatchesByTab
        let found = rows(##"[{"id":1,"order_id":"#1","status":0},{"id":2,"order_id":"#2","status":10},{"id":3,"order_id":"#3","status":10}]"##)
        var counts: [BoardTab: Int] = [:]
        for t in BoardTab.allCases { counts[t] = found.filter { $0.board == t }.count }
        let board = AssignPackerUiState(orders: found, isLoading: false, tab: .assigned, query: "balaji", counts: counts)
        check(board.shown.map(\.id).sorted() == [2, 3], "matches in tab")
        check(board.count(.pending) == 1, "pending match count")
        check(!board.canLoadMore, "search holds every match")

        // browsingPagesUntilTheServersLastPage
        var browse = AssignPackerUiState(orders: myOrders, isLoading: false, page: 1, lastPage: 3)
        check(browse.canLoadMore, "page 1 of 3")
        browse.page = 3
        check(!browse.canLoadMore, "page 3 of 3")
        browse.page = 1; browse.query = "x"
        check(!browse.canLoadMore, "search")
    }

    static func details() {
        // weighsEachLineEachBoxAndTheWholeOrder
        let detail = PackOrderDetail.from(json("""
            {"order":{"id":7526,"order_no":"#2026-27/4057","status":11,"total_weight":"9.6 kg"},
            "items":[
              {"order_detail_id":1,"product_name":"MIRCH POWDER","variant_name":"500 gms","qty":10,"qty_packed":5,"qty_remaining":5},
              {"order_detail_id":2,"product_name":"HALDI POWDER","variant_name":"100 gms","qty":20,"qty_packed":20,"qty_remaining":0},
              {"order_detail_id":3,"product_name":"RR Bhelpuri","variant_name":"140 gms","qty":10,"qty_packed":10,"qty_remaining":0}
            ],
            "packages":[
              {"id":18,"package_no":1,"items":[{"id":1,"order_detail_id":1,"qty_packed":5},{"id":2,"order_detail_id":2,"qty_packed":20}]},
              {"id":19,"package_no":2,"items":[{"id":3,"order_detail_id":3,"qty_packed":10}]},
              {"id":20,"package_no":3,"items":[]}
            ]}
            """))
        let mirch = detail.lines.first { $0.id == 1 }!
        near(mirch.totalKg, 5.0, "mirch total")
        near(mirch.packedKg, 2.5, "mirch packed")
        near(mirch.leftKg, 2.5, "mirch left")
        near(detail.boxes[0].kg, 4.5, "box 1")
        near(detail.boxes[1].kg, 1.4, "box 2")
        near(detail.boxes[2].kg, 0.0, "box 3")
        check(detail.boxes[0].name == "Box 1", "box name: \(detail.boxes[0].name)")
        near(detail.totalKg, 8.4, "order total")
        near(detail.packedKg, 5.9, "order packed")
        near(detail.leftKg, 2.5, "order left")
        near(detail.totalKg, detail.packedKg! + detail.leftKg!, "packed + left")

        // withoutEveryLinesWeightTheServersTotalStandsAndPackedIsNotGuessed
        let partial = PackOrderDetail.from(json("""
            {"order":{"id":1,"status":11,"total_weight":"3 kg"},
            "items":[
              {"order_detail_id":1,"product_name":"Oil","variant_name":"1 L","qty":2,"qty_packed":1},
              {"order_detail_id":2,"product_name":"Rai","variant_name":"500 gms","qty":2,"qty_packed":2}
            ],"packages":[]}
            """))
        near(partial.totalKg, 3.0, "server total")
        check(partial.packedKg == nil, "packed not guessed")
        check(partial.leftKg == nil, "left not guessed")
        check(partial.lines.first { $0.id == 2 }!.unitKg != nil, "rai weighs")
        check(partial.lines.first { $0.id == 1 }!.unitKg == nil, "oil doesn't")

        // anOrderWithARiderHasNothingLeftForThePacker
        let gone = PackOrderDetail.from(json(#"{"order":{"id":1,"status":6},"items":[]}"#))
        check(gone.afterPacking == "With rider", "with rider")
    }

    static func boardQueries() {
        // aPickedSellerGoesAsAllItsFields
        let seller = PackSeller(id: 689, name: "Kishan Lal Ji Saini", shopName: "Shree Krishna Store", mobile: "9929110644", beat: "Agra Road")
        let q = BoardQuery(status: 0, billNo: " 3993 ", seller: seller).body(page: 1, perPage: 30)
        check(q["seller_id"] as? Int == 689, "seller_id")
        check(q["seller_no"] as? String == "9929110644", "seller_no")
        check(q["shop_name"] as? String == "Shree Krishna Store", "shop_name")
        check(q["seller_name"] as? String == "Kishan Lal Ji Saini", "seller_name")
        check(q["bill_no"] as? String == "3993", "bill_no trimmed")

        // theBoardSendsOnlyTheFiltersInUse
        let all = BoardQuery().body(page: 1, perPage: 30)
        check(Set(all.keys) == ["per_page", "page"], "only paging")
        let f = BoardQuery(status: 10, beatId: 3, date: PackDay(year: 2026, month: 10, day: 7), billNo: "4057").body(page: 2, perPage: 30)
        check(f["status"] as? Int == 10, "status")
        check(f["beat_id"] as? Int == 3, "beat_id")
        check(f["date"] as? String == "2026-10-07", "date")
        check(f["bill_no"] as? String == "4057", "bill_no")
        check(f["page"] as? Int == 2, "page")
        check(f["shop_name"] == nil, "no shop_name")

        // The paker lists put current_page / last_page beside a plain data array.
        let page = PackPage.parse(json(#"{"status":true,"data":[{"id":1},{"id":2}],"current_page":1,"last_page":4,"total":37}"#), row: PackOrderDto.init(json:))
        check(page.items.count == 2 && page.lastPage == 4 && page.total == 37, "paker page")
        let laravel = PackPage.parse(json(#"{"data":{"data":[{"id":5}],"current_page":2,"last_page":2,"total":31}}"#), row: PackSeller.from)
        check(laravel.items.first?.title == "Seller #5" && laravel.lastPage == 2 && laravel.total == 31, "paginator page")

        // get-all-data without a user_id files the states under "0".
        let areas = PackArea.tree(from: json(#"{"data":{"0":[{"id":2,"name":"Rajasthan","cities":[{"id":9,"name":"Jaipur","beats":[{"id":4,"name":"Mansarovar"}]}]},{"id":1,"name":"Delhi"}]}}"#))
        check(areas.map(\.name) == ["Delhi", "Rajasthan"], "states A-Z")
        check(areas[1].children.first?.children.first?.name == "Mansarovar", "beats under cities")

        // Failure text: a validation error first, then message as a string or an array.
        check(json(#"{"errors":{"order_ids":["Pick an order."]},"message":"Invalid"}"#).packMessage == "Pick an order.", "errors first")
        check(json(#"{"message":["Already packed"]}"#).packMessage == "Already packed", "message array")
    }
}
