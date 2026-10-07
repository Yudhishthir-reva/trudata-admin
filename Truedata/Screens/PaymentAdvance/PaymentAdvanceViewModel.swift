import Foundation
import Combine

struct PaymentAdvanceEndpoint: RouterManagable {
    let path: String
    var endPointUrl: String { "V2/payment-advance/\(path)" }
    var contentType: RequestContentType { .json }
}

final class PaymentAdvanceService {
    private let network: NetworkServiceManagable
    init(network: NetworkServiceManagable = NetworkServiceManager.shared) { self.network = network }

    func request(_ path: String, params: [String: Any], file: MultipartFileUpload? = nil) async throws -> JSONValue {
        let endpoint = PaymentAdvanceEndpoint(path: path)
        let publisher: AnyPublisher<JSONValue, Error>
        if path == "give" || path == "receive" {
            publisher = network.uploadMultipart(endpoint, params: params, file: file, headers: UserDefaultManager.shared.authHeader)
        } else {
            publisher = network.request(endpoint, params: params, headers: UserDefaultManager.shared.authHeader)
        }
        for try await response in publisher.values {
            guard response["status"]?.boolValue == true, response["errors"] == nil else {
                let errors = response["errors"]?.objectValue.values.map { $0.arrayValue.first?.stringValue ?? $0.stringValue }.filter { !$0.isEmpty }.joined(separator: "\n") ?? ""
                let message = response["message"]?.stringValue ?? ""
                throw PaymentAdvanceError.message(!errors.isEmpty ? errors : !message.isEmpty ? message : "Unable to complete the request.")
            }
            return response
        }
        throw PaymentAdvanceError.invalidResponse
    }
}

@MainActor
final class PaymentAdvanceViewModel: ObservableObject {
    let access = PaymentAdvanceAccess(role: UserDefaultManager.shared.getUserDefaultsString(key: .userRole))
    @Published var filter = PaymentAdvanceFilter()
    @Published var records: [PaymentAdvanceRecord] = []
    @Published var summary: [String: Decimal] = [:]
    @Published var detail: PaymentAdvanceRecord?
    @Published var people: [OrderInsightsStaffMember] = []
    @Published var roles: [StaffRoleItem] = []
    @Published var loading = false
    @Published var saving = false
    @Published var error: String?
    @Published var optionsError: String?
    @Published var hasMore = false
    private var page = 0
    private var loadID = UUID()
    private let service = PaymentAdvanceService()

    func load(more: Bool = false) async {
        guard !more || (!loading && hasMore) else { return }
        let id = UUID()
        loadID = id
        guard filter.isValid else {
            records = []; summary = [:]; hasMore = false; loading = false
            error = "Start date must be on or before end date."
            return
        }
        loading = true
        error = nil
        if !more { records = []; summary = [:]; hasMore = false }
        let next = more ? page + 1 : 1
        do {
            let response = try await service.request(access.canManage ? "all-list" : "my-list", params: filter.parameters(page: next, canManage: access.canManage))
            guard loadID == id, !Task.isCancelled else { return }
            guard case .array(let data) = response["data"], let meta = response["meta"] else { throw PaymentAdvanceError.invalidResponse }
            let incoming = try data.map { try PaymentAdvanceRecord($0) }
            let existing = Set(records.map(\.id))
            records = more ? records + incoming.filter { !existing.contains($0.id) } : incoming
            summary = response["summary"]?.objectValue.compactMapValues { PaymentAdvanceRecord.money($0) } ?? [:]
            page = meta["current_page"]?.intValue ?? next
            hasMore = page < (meta["last_page"]?.intValue ?? page)
        } catch { if loadID == id, !Task.isCancelled { self.error = error.localizedDescription } }
        if loadID == id { loading = false }
    }

    func loadOptions() async {
        guard access.canManage else { return }
        optionsError = nil
        do {
            for try await response in HomePrefetchServiceManager().fetchStaffList().values {
                guard response.status else { throw PaymentAdvanceError.invalidResponse }
                people = response.data.filter { $0.id > 0 }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                break
            }
            for try await response in StaffServiceManager().fetchRoles().values {
                guard response.status else { throw PaymentAdvanceError.invalidResponse }
                roles = response.data
                break
            }
        } catch { optionsError = error.localizedDescription }
    }

    func loadDetail(_ id: Int) async {
        loading = true; error = nil; detail = nil
        do {
            let response = try await service.request("detail", params: ["id": id])
            guard let data = response["data"] else { throw PaymentAdvanceError.invalidResponse }
            detail = try PaymentAdvanceRecord(data)
        } catch { self.error = error.localizedDescription }
        loading = false
    }

    func save(form: PaymentAdvanceForm, advance: PaymentAdvanceRecord?, file: MultipartFileUpload?) async -> Bool {
        guard access.canManage, !saving else { return false }
        saving = true; error = nil
        defer { saving = false }
        do {
            let params = try form.parameters(advance: advance)
            _ = try await service.request(advance == nil ? "give" : "receive", params: params, file: file)
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func updateStatus(_ status: AdvanceStatus) async {
        guard access.canManage, !saving, let detail else { return }
        saving = true; error = nil
        defer { saving = false }
        do {
            _ = try await service.request("update-status", params: ["id": detail.recordID, "status": status.rawValue])
            await loadDetail(detail.recordID)
        } catch { self.error = error.localizedDescription }
    }
}
