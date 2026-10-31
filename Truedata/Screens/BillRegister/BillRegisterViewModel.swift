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
    @Published var view = BillListView.registers
    /// Beats both views are narrowed to, id to name; empty = every beat.
    @Published var beatFilter: [Int: String] = [:]
    @Published var beatWise: BillBeatWise?
    @Published var beatWiseLoading = false
    @Published var beatWiseError: String?
    @Published var beatsLoading = false
    private var beatWiseGeneration = UUID()

    var beatFilterLabel: String? {
        let names = beatFilter.values.sorted()
        switch names.count {
        case 0: return nil
        case 1: return names[0]
        default: return "\(names.count) beats · " + names.joined(separator: ", ")
        }
    }
    /// The export being downloaded, if any; one at a time.
    @Published var exporting: BillExportFormat?
    /// A failed download or register action, shown as Android's "Can't continue" dialog rather
    /// than a line of red text.
    @Published var alert: String?
    private var page = 0
    private var generation = UUID()

    private func request<T: Decodable>(_ request: BillRegisterRequest, as type: T.Type) async throws -> T {
        guard !DashboardRole.isOfficeStaff(UserDefaultManager.shared.getUserDefaultsString(key: .userRole)) else {
            throw RequestError.apiMessage("Bill Register is not available for your role.")
        }
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
            let response = try await request(.list(status: BillRegisterStatus(rawValue: status), assignedTo: assignedTo > 0 ? assignedTo : nil, page: next, orderID: query, beatIds: Array(beatFilter.keys)), as: BillRegisterListResponse.self)
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

    /// Android `loadBeatWise`: the summary ignores status and order id, so only the beat and
    /// employee filters go. [keep] leaves the last figures up while reloading.
    func loadBeatWise(keep: Bool = true) async {
        let token = UUID(); beatWiseGeneration = token
        beatWiseLoading = true; beatWiseError = nil
        if !keep { beatWise = nil }
        do {
            let response = try await request(.list(assignedTo: assignedTo > 0 ? assignedTo : nil, page: 1, beatIds: Array(beatFilter.keys)), as: BillRegisterListResponse.self)
            guard beatWiseGeneration == token, !Task.isCancelled else { return }
            guard response.status else { throw RequestError.apiMessage(response.message) }
            beatWise = response.beatWisePending.map(BillBeatWise.init) ?? .empty
        } catch { if beatWiseGeneration == token, !Task.isCancelled { beatWiseError = error.localizedDescription } }
        if beatWiseGeneration == token { beatWiseLoading = false }
    }

    /// Reloads whichever view is on screen.
    func reload() async {
        if view == .beats { await loadBeatWise() } else { await load() }
    }

    func setBeats(_ ids: Set<Int>) {
        guard ids != Set(beatFilter.keys) else { return }
        let names = Dictionary(beats.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a }).merging(beatFilter) { a, _ in a }
        beatFilter = Dictionary(uniqueKeysWithValues: ids.map { ($0, names[$0] ?? "Beat \($0)") })
    }

    /// Android `openBeat`: a beat card opens that beat's pending registers, the ones its figures come from.
    func openBeat(_ beat: BillBeatPending) {
        beatFilter = [beat.beatId: beat.name]
        status = BillRegisterStatus.pending.rawValue
        orderID = ""
        view = .registers
    }

    /// The beat list for the filter, fetched the first time it is opened.
    func loadBeats(force: Bool = false) async {
        guard !beatsLoading, beats.isEmpty || force else { return }
        beatsLoading = true
        defer { beatsLoading = false }
        await loadOptions(includeBeats: true)
    }

    func loadDetail(_ id: Int) async {
        // A refresh keeps the register on screen, so its rows can animate to the new state.
        loading = true; error = nil
        if detail?.id != id { detail = nil }
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
                staff = response.data.filter { $0.id > 0 && !DashboardRole.isOfficeStaff($0.role) }; break
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
        guard let failure = await perform(operation) else { return true }
        alert = failure.message
        return false
    }

    /// Runs [operation] and returns why it failed, or nil on success. Unlike [mutate] it leaves
    /// `error` alone, so a dialog can show the failure in place and keep what was typed or picked.
    /// `serverAnswered` tells a refusal (worth reloading for) from a dropped connection.
    func perform(_ operation: BillRegisterRequest) async -> (message: String, serverAnswered: Bool)? {
        guard access.canManage, !saving else { return ("Only Admin and Accountant can manage bill registers.", false) }
        saving = true; error = nil; message = nil
        defer { saving = false }
        do {
            let response = try await request(operation, as: BillRegisterActionResponse.self)
            guard response.status else {
                return (response.message.isEmpty ? "Something went wrong. Try again." : response.message, true)
            }
            message = response.message
            return nil
        } catch RequestError.apiMessage(let text) {
            return (text, true)
        } catch {
            return (error.localizedDescription, false)
        }
    }

    /// Downloads the register as a PDF or CSV into a temporary file, ready to share or save.
    /// Failures still come back as JSON, so anything JSON-typed, non-2xx, empty, or not starting
    /// with the format's magic bytes is read as an error rather than saved as a broken file.
    func export(id: Int, format: BillExportFormat) async -> URL? {
        guard exporting == nil else { return nil }
        guard NetworkMonitor.shared.isConnected else {
            alert = "No internet connection. Check your network and try again."; return nil
        }
        guard let url = URL(string: BillRegisterEndpoint(endPointUrl: format.path).urlString) else {
            alert = RequestError.invalidURL.localizedDescription; return nil
        }
        exporting = format; alert = nil
        defer { exporting = nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        UserDefaultManager.shared.authHeader.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["bill_register_id": id])
        let data: Data, response: HTTPURLResponse
        do {
            let (body, raw) = try await URLSession.shared.data(for: request)
            guard let http = raw as? HTTPURLResponse else { throw RequestError.invalidResponse }
            data = body; response = http
        } catch {
            self.alert = "The download was interrupted. Check your network and try again."; return nil
        }
        let code = response.statusCode
        // Laravel's 404 is a route-not-found message and a 5xx is a PHP exception: neither is
        // something to show a user.
        if code == 404 { alert = "\(format.label) download isn't available on the server yet."; return nil }
        if code >= 500 { alert = "The server couldn't make the \(format.label) right now. Try again later."; return nil }
        let isJSON = (response.value(forHTTPHeaderField: "Content-Type") ?? "").contains("json")
        if !(200...299).contains(code) || isJSON {
            let decoded = try? JSONDecoder().decode(BillRegisterActionResponse.self, from: data)
            switch code {
            case 401: alert = "Your session has expired. Log in again."
            case 403: alert = decoded.map(\.message).flatMap { $0.isEmpty || $0 == "Unauthorized." ? nil : $0 } ?? "You don't have access to this."
            default:
                let text = decoded?.message ?? ""
                alert = text.isEmpty ? "The server didn't send a \(format.label) file. Try again." : text
            }
            return nil
        }
        guard !data.isEmpty else { alert = "The server sent an empty \(format.label). Try again."; return nil }
        guard format.looksValid(data) else { alert = "The server sent a damaged \(format.label). Try again."; return nil }

        let name = Self.fileName(from: response, fallback: "bill_register_\(id)", format: format)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("BillRegister", isDirectory: true)
        let target = folder.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
            return target
        } catch {
            self.alert = "Downloaded the \(format.label), but couldn't save it on this phone. Free up some space and try again."
            return nil
        }
    }

    /// The server's `Content-Disposition` filename, stripped of path and unsafe characters.
    private static func fileName(from response: HTTPURLResponse, fallback: String, format: BillExportFormat) -> String {
        var name = fallback
        let pattern = try? NSRegularExpression(pattern: #"filename\*?=(?:UTF-8'')?"?([^";]+)"?"#, options: .caseInsensitive)
        if let header = response.value(forHTTPHeaderField: "Content-Disposition"),
           let match = pattern?.firstMatch(in: header, range: NSRange(header.startIndex..., in: header)),
           let range = Range(match.range(at: 1), in: header) {
            let raw = String(header[range])
            let cleaned = (raw.removingPercentEncoding ?? raw)
                .components(separatedBy: "/").last?
                .replacingOccurrences(of: #"[\\:*?"<>|]"#, with: "_", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces) ?? ""
            if !cleaned.isEmpty { name = cleaned }
        }
        return name.lowercased().hasSuffix(".\(format.rawValue)") ? name : "\(name).\(format.rawValue)"
    }
}
