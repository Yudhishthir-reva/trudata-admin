//
//  ChooseBrandViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class ChooseBrandViewModel: ObservableObject {

    @Published var isLoadingBrands = false
    @Published var brandsError: String?
    @Published var brands: [BrandListItem] = []

    @Published var isLoadingSuggestions = false
    @Published var suggestions: [TopSellingProductSuggestion] = []

    private let sellerId: String
    private let service: CreateOrderServiceManager
    private var cancellables = Set<AnyCancellable>()

    init(sellerId: Int, service: CreateOrderServiceManager = CreateOrderServiceManager()) {
        self.sellerId = String(sellerId)
        self.service = service
    }

    func loadData() {
        loadBrands()
        loadTopSellingSuggestions()
    }

    func loadBrands() {
        isLoadingBrands = true
        brandsError = nil

        service.getBrandList()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingBrands = false
                if case .failure(let error) = completion {
                    self.brandsError = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingBrands = false
                if response.status {
                    self.brands = response.data
                    if self.brands.isEmpty {
                        self.brandsError = "No brands available for this seller."
                    }
                } else {
                    self.brandsError = response.message.isEmpty ? "Unable to load brands." : response.message
                }
            }
            .store(in: &cancellables)
    }

    private func loadTopSellingSuggestions() {
        isLoadingSuggestions = true

        service.getTopSellingSuggestions(sellerId: sellerId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoadingSuggestions = false
                if case .failure = completion {
                    self.suggestions = []
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoadingSuggestions = false
                self.suggestions = response.status ? response.data : []
            }
            .store(in: &cancellables)
    }
}
