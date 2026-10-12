import Foundation
import Combine

@MainActor
final class SellerMergeViewModel: ObservableObject {
    @Published var primary: MergeSeller?
    @Published var secondary: MergeSeller?
    @Published var preview: JSONValue?
    @Published var notes = ""
    @Published var busy = false
    @Published var error: String?
    @Published var outcome: SellerMergeOutcome?
    @Published var sellers: [MergeSeller] = []
    @Published var searching = false
    @Published var searchError: String?
    @Published var query = ""
    @Published var stateID = ""
    @Published var cityID = ""
    @Published var beatID = ""
    @Published var states: [OrderInsightsStateArea] = []
    @Published var sellerHasMore = false
    @Published var sellerTotal = 0
    @Published var history: [JSONValue] = []
    @Published var historyLoading = false
    @Published var historyError: String?
    @Published var historyHasMore = false
    @Published var historyTotal = 0

    /// Android `SellerMergeIntent.StartOver`. A finished merge must not leave the merged-away
    /// seller selected — clearing only the outcome banner left both picks (one of which no longer
    /// exists) in place for the next merge.
    func startOver() {
        outcome = nil
        error = nil
        primary = nil
        secondary = nil
        preview = nil
        notes = ""
    }
    private var sellerPage = 0
    private var historyPage = 0
    private var searchGeneration = UUID()
    private var beatCache: [String: [MergeSeller]] = [:]
    private var areasLoaded = false

    var cities: [OrderInsightsCityArea] { states.first { String($0.id) == stateID }?.cities ?? [] }
    var beats: [OrderInsightsBeatArea] { cities.first { String($0.id) == cityID }?.beats ?? [] }
    var searchKey: String { [query, stateID, cityID, beatID].joined(separator: "|") }
    var canReview: Bool { primary?.isActive == true && secondary != nil && primary?.id != secondary?.id && !busy }

    private func request(_ path: String, _ params: [String: Any]) async throws -> SellerMergeResponse {
        guard SellerMergeAccess.allowed else { throw RequestError.apiMessage("Seller Merge is available to authorized staff on staging only.") }
        let publisher: AnyPublisher<SellerMergeResponse, Error> = NetworkServiceManager.shared.request(
            BillRegisterEndpoint(endPointUrl: path), params: params, headers: UserDefaultManager.shared.authHeader)
        for try await response in publisher.values {
            guard response.status else { throw RequestError.apiMessage(response.message ?? "Request failed.") }
            return response
        }
        throw RequestError.invalidResponse
    }

    func loadAreas() async {
        guard SellerMergeAccess.allowed, !areasLoaded else { return }
        do {
            for try await response in AddSellerServiceManager().fetchAllAreas().values {
                guard response.status else { throw RequestError.invalidResponse }
                states = response.states
                if stateID.isEmpty && cityID.isEmpty && beatID.isEmpty,
                   let preferredState = response.preference?.selectedState,
                   let preferredCity = response.preference?.selectedCity,
                   states.first(where: { String($0.id) == preferredState })?.cities.contains(where: { String($0.id) == preferredCity }) == true {
                    stateID = preferredState; cityID = preferredCity
                }
                areasLoaded = true
                break
            }
        } catch { searchError = "Area filters couldn't load. You can still search all sellers. \(error.localizedDescription)" }
    }

    func search(more: Bool = false) async {
        guard !more || (!searching && sellerHasMore) else { return }
        let generation = UUID(); searchGeneration = generation
        let key = searchKey, beat = beatID, text = query
        let next = more ? sellerPage + 1 : 1
        searching = true; searchError = nil
        if !more { sellers = []; sellerHasMore = false; sellerTotal = 0 }
        defer { if searchGeneration == generation { searching = false } }
        do {
            let found: [MergeSeller]
            let last: Int
            let total: Int
            if !beat.isEmpty {
                let all: [MergeSeller]
                if let cached = beatCache[beat] { all = cached }
                else {
                    let response = try await request("seller-list-beat-wise2", ["beat_id": Int(beat) ?? 0])
                    guard let data = response.data, case .array = data else { throw RequestError.invalidResponse }
                    all = data.arrayValue.map { MergeSeller(json: $0) }.filter { $0.id > 0 }
                    beatCache[beat] = all
                }
                found = all.filter { $0.matches(text) }.map(withPlace); last = 1; total = found.count
            } else {
                var params: [String: Any] = ["page": next]
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { params["shop_name"] = text.trimmingCharacters(in: .whitespacesAndNewlines) }
                if let id = Int(stateID) { params["state_id"] = id }
                if let id = Int(cityID) { params["city_id"] = id }
                let response = try await request("seller-list2", params)
                guard let data = response.data, let rows = data["data"], case .array = rows else { throw RequestError.invalidResponse }
                found = rows.arrayValue.map { MergeSeller(json: $0) }.filter { $0.id > 0 }.map(withPlace)
                last = data["last_page"]?.intValue ?? 1
                total = data["total"]?.intValue ?? found.count
            }
            guard searchGeneration == generation, key == searchKey, !Task.isCancelled else { return }
            let existing = Set(sellers.map(\.id))
            sellers = more ? sellers + found.filter { !existing.contains($0.id) } : found
            sellerTotal = total
            sellerPage = next; sellerHasMore = next < last
        } catch { if searchGeneration == generation && !Task.isCancelled { searchError = error.localizedDescription } }
    }

    private func withPlace(_ seller: MergeSeller) -> MergeSeller {
        var fields = seller.json.objectValue
        for state in states {
            for city in state.cities {
                if let beat = city.beats.first(where: { $0.id == seller.json["beat_id"]?.intValue }) {
                    if fields["beat"]?.stringValue.isEmpty != false { fields["beat"] = .string(beat.name) }
                    if fields["city"]?.stringValue.isEmpty != false { fields["city"] = .string(city.name) }
                    if fields["state"]?.stringValue.isEmpty != false { fields["state"] = .string(state.name) }
                    return MergeSeller(json: .object(fields))
                }
            }
        }
        for (name, key) in [("beat", "beat_id"), ("city", "city_id")] {
            if fields[name]?.stringValue.isEmpty != false, let text = fields[key]?.stringValue, Int(text) == nil {
                fields[name] = .string(text)
            }
        }
        return MergeSeller(json: .object(fields))
    }

    func pick(_ seller: MergeSeller, keeping: Bool) {
        guard !busy, seller.id > 0, seller.id != (keeping ? secondary?.id : primary?.id), !keeping || seller.isActive else { return }
        if keeping { primary = seller } else { secondary = seller }
        preview = nil; outcome = nil; error = nil
    }

    func swap() {
        guard !busy else { return }
        guard secondary?.isActive != false else { error = "An inactive seller cannot be the seller you keep."; return }
        let old = primary; primary = secondary; secondary = old; preview = nil
    }

    func review() async {
        guard canReview, let p = primary, let s = secondary else { return }
        busy = true; error = nil; preview = nil
        defer { busy = false }
        do {
            let response = try await request("seller-merge-preview", ["primary_seller_id": p.id, "secondary_seller_id": s.id])
            guard let data = response.data,
                  data["primary_seller"]?["id"]?.intValue == p.id,
                  data["secondary_seller"]?["id"]?.intValue == s.id,
                  primary?.id == p.id, secondary?.id == s.id else {
                throw RequestError.apiMessage("Preview does not match the selected sellers. Please review again.")
            }
            if let kept = data["primary_seller"], let duplicate = data["secondary_seller"] {
                guard MergeSeller(json: kept).isActive else {
                    throw RequestError.apiMessage("The seller to keep is inactive. Choose an active seller.")
                }
                primary = MergeSeller(json: kept); secondary = MergeSeller(json: duplicate)
            }
            preview = data
        } catch { self.error = error.localizedDescription }
    }

    func execute() async {
        guard !busy, let reviewed = preview, let p = primary, let s = secondary,
              reviewed["primary_seller"]?["id"]?.intValue == p.id,
              reviewed["secondary_seller"]?["id"]?.intValue == s.id else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let response = try await request("seller-merge-execute", ["primary_seller_id": p.id, "secondary_seller_id": s.id, "notes": String(notes.prefix(500))])
            let count = response.data?["total_records_moved"]?.intValue ?? reviewed["other_records"]?["total_records_to_move"]?.intValue ?? 0
            outcome = SellerMergeOutcome(primary: p, secondary: s, recordsMoved: count, message: response.message ?? "Sellers merged successfully.")
            primary = nil; secondary = nil; preview = nil; notes = ""; beatCache.removeAll()
        } catch {
            preview = nil
            self.error = "\(error.localizedDescription) Check History and fetch a new preview before trying again."
        }
    }

    func loadHistory(more: Bool = false) async {
        guard !historyLoading, !more || historyHasMore else { return }
        historyLoading = true; historyError = nil
        defer { historyLoading = false }
        let next = more ? historyPage + 1 : 1
        do {
            let response = try await request("seller-merge-history", ["page": next, "per_page": 15])
            guard let data = response.data, let rows = data["history"], case .array = rows else { throw RequestError.invalidResponse }
            let existing = Set(history.compactMap { $0["id"]?.intValue })
            history = more ? history + rows.arrayValue.filter { !existing.contains($0["id"]?.intValue ?? 0) } : rows.arrayValue
            historyTotal = data["total"]?.intValue ?? history.count
            historyPage = next; historyHasMore = next < (data["last_page"]?.intValue ?? 1)
        } catch { historyError = error.localizedDescription }
    }
}
