import Foundation
import Combine

struct BillRegisterEndpoint: RouterManagable {
    let endPointUrl: String
    var contentType: RequestContentType { .json }
}

@MainActor
final class BillRegisterViewModel: ObservableObject {
    let access = BillRegisterAccess(role: UserDefaultManager.shared.getUserDefaultsString(key: .userRole), userId: Int(UserDefaultManager.shared.getUserDefaultsString(key: .userId)) ?? 0)
    @Published var entries: [BillRegisterEntry] = []
    @Published var detail: BillRegisterEntry?
    @Published var orders: [BillRegisterOrder] = []
    @Published var beats: [BeatListItem] = []
    @Published var staff: [OrderInsightsStaffMember] = []
    @Published var status = BillRegisterStatus.pending.rawValue
    @Published var assignedTo = 0
    @Published var orderSessionYear = BillOrderSession.startYear()
    @Published var orderID = BillOrderSession.prefix(BillOrderSession.startYear())
    @Published var loading = false
    @Published var saving = false
    @Published var error: String?
    @Published var optionsError: String?
    @Published var message: String?
    @Published var hasMore = false
    private var page = 0
    private var generation = UUID()

    private func request<T: Decodable>(_ request: BillRegisterRequest, as type: T.Type) async throws -> T {
        let params = try request.parameters(access: access)
        let publisher: AnyPublisher<T, Error> = NetworkServiceManager.shared.request(BillRegisterEndpoint(endPointUrl: request.path), params: params, headers: UserDefaultManager.shared.authHeader)
        for try await response in publisher.values { return response }
        throw RequestError.invalidResponse
    }

    func load(more: Bool = false) async {
        guard !more || (!loading && hasMore) else { return }
        let token = UUID(); generation = token
        loading = true; error = nil
        if !more { entries = []; hasMore = false }
        let next = more ? page + 1 : 1
        do {
            let query = BillOrderSession.filter(orderID)
            let response = try await request(.list(status: BillRegisterStatus(rawValue: status), assignedTo: assignedTo > 0 ? assignedTo : nil, page: next, orderID: query), as: BillRegisterListResponse.self)
            guard generation == token, !Task.isCancelled else { return }
            guard response.status else { throw RequestError.apiMessage(response.message) }
            let rows = response.data.map { BillRegisterEntry(json: $0) }
            guard rows.allSatisfy({ $0.id > 0 }) else { throw RequestError.invalidResponse }
            let permitted = rows.filter { access.canRead(assignedTo: $0.assignedTo) }
            if permitted.count != rows.count { error = "Some registers were hidden because their assignment could not be verified." }
            let existing = Set(entries.map(\.id))
            entries = more ? entries + permitted.filter { !existing.contains($0.id) } : permitted
            page = response.currentPage; hasMore = page < response.lastPage
        } catch { if generation == token, !Task.isCancelled { self.error = error.localizedDescription } }
        if generation == token { loading = false }
    }

    func loadDetail(_ id: Int) async {
        loading = true; detail = nil; error = nil
        defer { loading = false }
        do {
            let response = try await request(.detail(id: id), as: BillRegisterActionResponse.self)
            guard response.status else { throw RequestError.apiMessage(response.message) }
            guard let data = response.data, case .object = data else { throw RequestError.invalidResponse }
            let entry = BillRegisterEntry(json: data)
            guard entry.id == id else { throw RequestError.invalidResponse }
            guard access.canRead(assignedTo: entry.assignedTo) else { throw RequestError.apiMessage("This register is not assigned to you.") }
            detail = entry
        } catch { self.error = error.localizedDescription }
    }

    func loadOptions(includeBeats: Bool = false) async {
        guard access.canManage else { return }
        optionsError = nil
        do {
            for try await response in HomePrefetchServiceManager().fetchStaffList().values {
                guard response.status else { throw RequestError.invalidResponse }
                staff = response.data.filter { $0.id > 0 }; break
            }
            if includeBeats {
                var next = 1
                var result: [BeatListItem] = []
                repeat {
                    var last = next
                    for try await response in BeatServiceManager().fetchBeatList(search: nil, page: next).values {
                        guard response.status else { throw RequestError.apiMessage(response.message) }
                        result += response.data.beats.filter { $0.id > 0 && $0.isActive }
                        last = response.data.lastPage; break
                    }
                    if next >= last { break }
                    next += 1
                } while !Task.isCancelled
                var seen = Set<Int>()
                beats = result.filter { seen.insert($0.id).inserted }
            }
        } catch { optionsError = error.localizedDescription }
    }

    func loadOrders(_ beatIds: Set<Int>) async {
        let token = UUID(); generation = token
        orders = []; error = nil
        guard !beatIds.isEmpty else { loading = false; return }
        loading = true
        do {
            let response = try await request(.beatOrders(beatIds: beatIds.sorted()), as: BillRegisterBeatOrdersResponse.self)
            guard generation == token, !Task.isCancelled else { return }
            guard response.status else { throw RequestError.apiMessage(response.message) }
            guard let data = response.data else { throw RequestError.invalidResponse }
            orders = data.orders
        } catch { if generation == token, !Task.isCancelled { self.error = error.localizedDescription } }
        if generation == token { loading = false }
    }

    func mutate(_ operation: BillRegisterRequest) async -> Bool {
        guard access.canManage, !saving else { return false }
        saving = true; error = nil; message = nil
        defer { saving = false }
        do {
            let response = try await request(operation, as: BillRegisterActionResponse.self)
            guard response.status else { throw RequestError.apiMessage(response.message) }
            message = response.message
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
}
