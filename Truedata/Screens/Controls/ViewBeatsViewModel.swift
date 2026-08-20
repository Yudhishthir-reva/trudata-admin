//
//  ViewBeatsViewModel.swift
//  Truedata
//

import Foundation
import Combine

@MainActor
final class ViewBeatsViewModel: ObservableObject {

    @Published var searchText = ""
    @Published var beats: [BeatListItem] = []
    @Published var areas: [OrderInsightsStateArea] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?

    @Published var showBeatForm = false
    @Published var beatForm = BeatFormData()

    private let service = BeatServiceManager()
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 1
    private var hasNextPage = false
    private var fetchTask: AnyCancellable?

    var filteredBeats: [BeatListItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return beats
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return beats.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.cityName.localizedCaseInsensitiveContains(query)
                || $0.stateName.localizedCaseInsensitiveContains(query)
        }
    }

    var availableCities: [OrderInsightsCityArea] {
        guard let stateId = Int(beatForm.stateId) else { return [] }
        return areas.first(where: { $0.id == stateId })?.cities ?? []
    }

    init() {
        $searchText
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.load(reset: true)
            }
            .store(in: &cancellables)
    }

    func load(reset: Bool = true) {
        if reset {
            currentPage = 1
            hasNextPage = false
            isLoading = beats.isEmpty
        } else {
            guard hasNextPage, !isLoadingMore else { return }
            isLoadingMore = true
            currentPage += 1
        }

        errorMessage = nil
        let page = currentPage
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        fetchTask?.cancel()
        fetchTask = service.fetchBeatList(
            search: query.isEmpty ? nil : query,
            page: page
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if case .failure(let error) = completion, self.beats.isEmpty {
                self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
            }
        } receiveValue: { [weak self] response in
            guard let self else { return }
            self.isLoading = false
            self.isLoadingMore = false
            if response.status {
                if reset {
                    self.beats = response.data.beats
                } else {
                    self.beats.append(contentsOf: response.data.beats)
                }
                self.currentPage = response.data.currentPage
                self.hasNextPage = response.data.hasNextPage
                self.errorMessage = nil
            } else {
                self.errorMessage = response.message.isEmptyString
                    ? "Failed to load beats."
                    : response.message
            }
        }
    }

    func loadAreasIfNeeded() {
        guard areas.isEmpty else { return }
        service.fetchAllAreas()
            .receive(on: DispatchQueue.main)
            .sink { _ in } receiveValue: { [weak self] response in
                self?.areas = response.states
            }
            .store(in: &cancellables)
    }

    func loadMoreIfNeeded(currentBeat: BeatListItem) {
        guard let last = filteredBeats.last, last.id == currentBeat.id else { return }
        load(reset: false)
    }

    func prepareAddBeat() {
        beatForm = BeatFormData()
        loadAreasIfNeeded()
        showBeatForm = true
    }

    func prepareEditBeat(_ beat: BeatListItem) {
        let applyForm = { [weak self] in
            guard let self else { return }
            let stateId = self.areas.first {
                $0.name.caseInsensitiveCompare(beat.stateName) == .orderedSame
            }?.id
            let cityId = self.areas.first(where: {
                $0.name.caseInsensitiveCompare(beat.stateName) == .orderedSame
            })?.cities.first(where: {
                $0.name.caseInsensitiveCompare(beat.cityName) == .orderedSame
            })?.id

            self.beatForm = BeatFormData(
                beatId: String(beat.id),
                name: beat.name,
                stateId: stateId.map(String.init) ?? "",
                stateName: beat.stateName,
                cityId: cityId.map(String.init) ?? "",
                cityName: beat.cityName,
                status: beat.status
            )
            self.showBeatForm = true
        }

        if areas.isEmpty {
            service.fetchAllAreas()
                .receive(on: DispatchQueue.main)
                .sink { _ in
                    applyForm()
                } receiveValue: { [weak self] response in
                    self?.areas = response.states
                    applyForm()
                }
                .store(in: &cancellables)
        } else {
            applyForm()
        }
    }

    func selectState(_ state: OrderInsightsStateArea) {
        beatForm.stateId = String(state.id)
        beatForm.stateName = state.name
        beatForm.cityId = ""
        beatForm.cityName = ""
    }

    func selectCity(_ city: OrderInsightsCityArea) {
        beatForm.cityId = String(city.id)
        beatForm.cityName = city.name
    }

    func saveBeat() {
        let trimmedName = beatForm.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            toastMessage = "Beat name is required."
            return
        }
        guard !beatForm.stateId.isEmpty else {
            toastMessage = "State is required."
            return
        }
        guard !beatForm.cityId.isEmpty else {
            toastMessage = "City is required."
            return
        }

        isSaving = true
        errorMessage = nil
        toastMessage = nil

        let publisher: AnyPublisher<BeatStatusMessageResponse, Error>
        if let beatId = beatForm.beatId {
            publisher = service.updateBeat(
                beatId: beatId,
                name: trimmedName,
                stateId: beatForm.stateId,
                cityId: beatForm.cityId,
                status: beatForm.status
            )
        } else {
            publisher = service.createBeat(
                name: trimmedName,
                stateId: beatForm.stateId,
                cityId: beatForm.cityId,
                status: beatForm.status
            )
        }

        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSaving = false
                if case .failure(let error) = completion {
                    self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSaving = false
                if response.status {
                    let wasEditMode = self.beatForm.isEditMode
                    self.showBeatForm = false
                    self.beatForm = BeatFormData()
                    self.toastMessage = response.message.isEmptyString
                        ? (wasEditMode ? "Beat updated successfully." : "Beat created successfully.")
                        : response.message
                    self.load(reset: true)
                } else {
                    self.toastMessage = response.message.isEmptyString
                        ? "Failed to save beat."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func deleteBeat(_ beat: BeatListItem) {
        isSaving = true
        service.deleteBeat(beatId: String(beat.id))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isSaving = false
                if case .failure(let error) = completion {
                    self.toastMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isSaving = false
                if response.status {
                    self.toastMessage = response.message.isEmptyString
                        ? "Beat deleted successfully."
                        : response.message
                    self.load(reset: true)
                } else {
                    self.toastMessage = response.message.isEmptyString
                        ? "Failed to delete beat."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }
}
