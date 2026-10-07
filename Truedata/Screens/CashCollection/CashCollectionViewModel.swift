import Foundation
import Combine

struct CashEndpoint: RouterManagable {
    let path: String
    var endPointUrl: String { "V2/cash-collection/\(path)" }
    var contentType: RequestContentType { .json }
}

final class CashCollectionService {
    let network: NetworkServiceManagable
    init(network: NetworkServiceManagable = NetworkServiceManager.shared) { self.network = network }

    func request(_ path: String, _ params: [String: Any] = [:]) async throws -> JSONValue {
        let publisher: AnyPublisher<JSONValue, Error> = network.request(
            CashEndpoint(path: path), params: params, headers: UserDefaultManager.shared.authHeader
        )
        for try await response in publisher.values {
            guard case .object = response else { throw RequestError.invalidResponse }
            if response["status"]?.boolValue == false || response["errors"] != nil {
                let errors = response["errors"]?.objectValue.values.compactMap { value in
                    value.arrayValue.first?.stringValue ?? (value.stringValue.isEmpty ? nil : value.stringValue)
                }.joined(separator: "\n") ?? ""
                let message = response["message"]?.arrayValue.first?.stringValue ?? response["message"]?.stringValue ?? ""
                throw RequestError.apiMessage(errors.isEmpty ? (message.isEmpty ? "Unable to complete the request." : message) : errors)
            }
            return response
        }
        throw RequestError.invalidResponse
    }
}

enum CashListKind { case collections, taken, ledger }

@MainActor
final class CashCollectionViewModel: ObservableObject {
    let access: CashAccess
    let kind: CashListKind
    @Published var filter = CashFilter()
    @Published var records: [CashRecord] = []
    @Published var summary: CashSummary?
    @Published var people: [OrderInsightsStaffMember] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?
    @Published var peopleError: String?
    @Published var summaryError: String?
    @Published var message: String?
    @Published var hasMore = false
    @Published var totalRecords = 0
    @Published var detail: CashRecord?
    @Published var linkedCollections: [CashRecord] = []
    @Published var isLoadingLinks = false
    @Published var linksError: String?
    private var page = 0
    private var loadID = UUID()
    private var linksID = UUID()
    private var summaryID = UUID()
    private let service: CashCollectionService

    init(kind: CashListKind = .collections, initialPeriod: CashPeriod = .month, service: CashCollectionService = CashCollectionService()) {
        self.kind = kind
        self.service = service
        access = CashAccess(role: UserDefaultManager.shared.getUserDefaultsString(key: .userRole))
        self.filter.period = initialPeriod
    }

    func loadPeople() async {
        guard access.canReviewAll else { return }
        peopleError = nil
        do {
            for try await response in HomePrefetchServiceManager().fetchStaffList().values {
                guard response.status else { throw RequestError.apiMessage("Couldn't load the staff list.") }
                people = response.data.filter { $0.id > 0 && !$0.name.isEmpty }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                return
            }
        } catch { peopleError = errorText(error) }
    }

    func reload() async { await load(more: false) }

    func load(more: Bool) async {
        guard filter.isValid else {
            loadID = UUID()
            isLoading = false
            records = []
            hasMore = false
            summary = nil
            error = "Start date must be on or before end date."
            return
        }
        guard !more || (!isLoading && hasMore) else { return }
        guard kind == .collections || access.canReviewAll else { error = "You don't have access to this."; return }
        let id = UUID()
        loadID = id
        isLoading = true
        error = nil
        if !more { records = []; hasMore = false; summary = nil; summaryError = nil }
        let nextPage = more ? page + 1 : 1
        var params = filter.parameters()
        if !access.canReviewAll { params.removeValue(forKey: "staff_ids") }
        params["page"] = nextPage
        params["per_page"] = 15
        let path: String
        switch kind {
        case .collections:
            path = access.canReviewAll ? "all-list" : "my-list"
            if access.canReviewAll && !filter.status.isEmpty { params["status"] = filter.status }
        case .taken: path = "amount-taken/list"
        case .ledger: path = "ledger"
        }
        do {
            let response = try await service.request(path, params)
            guard loadID == id, !Task.isCancelled else { return }
            guard case .array(let items) = response["data"] else { throw RequestError.invalidResponse }
            let incoming = try items.map { item in
                guard (item["total_amount"] ?? item["amount"])?.cashRupees != nil else { throw RequestError.invalidResponse }
                return CashRecord(item)
            }
            if more {
                let existing = Set(records.map(\.id))
                records += incoming.filter { !existing.contains($0.id) }
            } else { records = incoming }
            page = response["meta"]?["current_page"]?.intValue ?? nextPage
            hasMore = page < (response["meta"]?["last_page"]?.intValue ?? page)
            totalRecords = response["meta"]?["total"]?.intValue ?? records.count
        } catch {
            if loadID == id, !Task.isCancelled { self.error = errorText(error) }
        }
        guard loadID == id else { return }
        isLoading = false
        if !more && kind == .ledger { await loadSummary() }
    }

    func loadSummary() async {
        let id = UUID()
        summaryID = id
        guard filter.isValid else {
            summary = nil
            summaryError = "Start date must be on or before end date."
            return
        }
        let snapshot = filter
        summary = nil
        summaryError = nil
        var params = filter.parameters()
        if !access.canReviewAll { params.removeValue(forKey: "staff_ids") }
        do {
            let response = try await service.request("denomination-summary", params)
            guard summaryID == id, filter == snapshot, !Task.isCancelled else { return }
            guard response["summary"]?["grand_total_amount"]?.cashRupees != nil else { throw RequestError.invalidResponse }
            summary = CashSummary(response)
            for staff in summary?.staff ?? [] where !people.contains(where: { $0.id == staff.id }) {
                people.append(OrderInsightsStaffMember(id: staff.id, name: staff.name))
            }
            people.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch { if summaryID == id, filter == snapshot, !Task.isCancelled { summaryError = errorText(error) } }
    }

    func loadDetail(_ id: Int) async {
        isLoading = true
        error = nil
        do {
            let response = try await service.request("detail", ["id": id])
            guard let data = response["data"], case .object = data,
                  (data["total_amount"] ?? data["amount"])?.cashRupees != nil else { throw RequestError.invalidResponse }
            detail = CashRecord(data)
        } catch { self.error = errorText(error) }
        isLoading = false
    }

    func submit(_ form: CashCountForm, editing id: Int? = nil) async -> Bool {
        guard let params = form.parameters(id: id) else { error = "Enter a positive cash total and matching note and coin counts."; return false }
        if id != nil && (!access.canEdit || detail?.status == "approved") { return false }
        return await mutate(id == nil ? "submit" : "edit", params)
    }

    func review(approve: Bool, remark: String) async -> Bool {
        guard access.canReviewAll, let detail, detail.status == "pending" else { return false }
        let remark = remark.trimmingCharacters(in: .whitespacesAndNewlines)
        guard approve || !remark.isEmpty else { error = "Add a remark saying why it's rejected."; return false }
        var params: [String: Any] = ["id": detail.id, "action": approve ? "approved" : "rejected"]
        if !remark.isEmpty { params["remark"] = String(remark.prefix(250)) }
        return await mutate("review", params)
    }

    func loadLinkedCollections(personId: Int, date: Date) async {
        let id = UUID()
        linksID = id
        linkedCollections = []
        linksError = nil
        isLoadingLinks = personId > 0
        guard personId > 0 else { return }
        var filter = CashFilter()
        filter.month = date
        filter.staffIds = [personId]
        var params = filter.parameters()
        params["page"] = 1
        params["per_page"] = 50
        do {
            let response = try await service.request("all-list", params)
            guard linksID == id, !Task.isCancelled else { return }
            linkedCollections = response["data"]?.arrayValue.map(CashRecord.init).filter { $0.status != "rejected" } ?? []
        } catch { if linksID == id, !Task.isCancelled { linksError = errorText(error) } }
        if linksID == id { isLoadingLinks = false }
    }

    func addTaken(personId: Int, amount: String, reason: String, remark: String, date: Date, collectionId: Int?) async -> Bool {
        guard access.canManageAmountTaken else { return false }
        guard date <= Date() else { error = "Choose today or an earlier date."; return false }
        guard personId > 0, let amount = Int(amount), amount > 0 else { error = "Choose a person and enter an amount above ₹0."; return false }
        var params: [String: Any] = ["person_id": personId, "amount": amount, "date": CashFilter.dateString(date)]
        for (key, text) in [("reason", reason), ("remark", remark)] {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { params[key] = String(trimmed.prefix(key == "reason" ? 100 : 250)) }
        }
        if let collectionId { params["collection_id"] = collectionId }
        return await mutate("amount-taken/add", params)
    }

    func reviewTaken(_ record: CashRecord, approve: Bool) async -> Bool {
        guard access.canManageAmountTaken, record.status == "pending" else { return false }
        return await mutate("amount-taken/update-status", ["id": record.id, "status": approve ? "approved" : "rejected"])
    }

    private func mutate(_ path: String, _ params: [String: Any]) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        error = nil
        message = nil
        defer { isSaving = false }
        do {
            let response = try await service.request(path, params)
            guard case .object = response["data"] else { throw RequestError.invalidResponse }
            message = response["message"]?.arrayValue.first?.stringValue ?? response["message"]?.stringValue ?? "Saved successfully."
            return true
        } catch { self.error = errorText(error); return false }
    }

    private func errorText(_ error: Error) -> String { (error as? RequestError)?.errorString ?? error.localizedDescription }
}
