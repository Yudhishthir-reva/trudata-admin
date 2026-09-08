//
//  MyProfileViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

final class MyProfileViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var isLoggingOut = false
    @Published var isDeletingAccount = false
    @Published var errorMessage: String?
    @Published var profile: MyProfileData?

    private let service = MyProfileServiceManager()
    private var cancellables = Set<AnyCancellable>()

    func loadProfile() {
        if profile == nil {
            isLoading = true
        }
        errorMessage = nil

        service.getLoggedInUserProfile()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                self.isLoading = false
                if case .failure(let error) = completion {
                    self.errorMessage = (error as? RequestError)?.errorString ?? error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                guard let self else { return }
                self.isLoading = false
                if response.status {
                    self.profile = response.data
                    self.errorMessage = nil
                } else {
                    self.errorMessage = response.message.isEmptyString
                        ? "Failed to load profile."
                        : response.message
                }
            }
            .store(in: &cancellables)
    }

    func logout() {
        isLoggingOut = true
        LocationManager.shared.stopShiftTracking()
        service.logout()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.finishLogout()
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }

    private func finishLogout() {
        isLoggingOut = false
        LocationManager.shared.stopShiftTracking()
        HomePrefetchManager.shared.reset()
        UserDefaultManager.shared.resetUserData()
        AppRootManager.shared.switchToAuth()
    }

    func deleteAccount() {
        isDeletingAccount = true
        LocationManager.shared.stopShiftTracking()
        service.logout()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.finishAccountDeletion()
            } receiveValue: { _ in }
            .store(in: &cancellables)
    }

    private func finishAccountDeletion() {
        isDeletingAccount = false
        LocationManager.shared.stopShiftTracking()
        HomePrefetchManager.shared.reset()
        UserDefaultManager.shared.resetUserData()
        AppRootManager.shared.switchToAuth()
    }
}
