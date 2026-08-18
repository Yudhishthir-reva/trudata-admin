//
//  AuthViewModel.swift
//  Truedata
//

import SwiftUI
import Combine

class AuthViewModel: ObservableObject {

    @Published var mobile = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var isFieldEnabled = true
    @Published var mobileError: String?
    @Published var passwordError: String?

    private var cancellables = Set<AnyCancellable>()
    private let service = LoginServiceManager()
    private let deviceInfo = DeviceInfo.current()

    func onMobileChange(_ value: String) {
        let digits = String(value.filter(\.isNumber).prefix(10))
        mobile = digits
        mobileError = nil
    }

    func onPasswordChange(_ value: String) {
        password = value
        passwordError = nil
    }

    func login() {
        guard validate() else { return }

        if !NetworkMonitor.shared.isConnected {
            let message = RequestError.noInternet.errorString
            mobileError = message
            passwordError = message
            return
        }

        isLoading = true
        isFieldEnabled = false

        let params: [String: Any] = [
            "mobile": mobile.trim,
            "password": password,
            "deviceInfo": deviceInfo.jsonString
        ]

        service.login(params: params)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                guard let self else { return }
                if case .failure(let error) = completion {
                    self.isLoading = false
                    self.isFieldEnabled = true
                    let message = (error as? RequestError)?.errorString ?? error.localizedDescription
                    self.mobileError = message
                    self.passwordError = message
                }
            } receiveValue: { [weak self] model in
                guard let self else { return }
                self.isLoading = false
                self.isFieldEnabled = true

                if model.status == true, let token = model.token, !token.isEmpty, !model.userId.isEmpty {
                    let defaults = UserDefaultManager.shared
                    defaults.setUserDefaultsString(value: token, key: .authToken)
                    defaults.setUserDefaultsString(value: model.userId, key: .userId)
                    defaults.setUserDefaultsString(value: model.name ?? "", key: .userName)
                    defaults.setUserDefaultsString(value: model.role ?? "", key: .userRole)
                    defaults.setUserDefaultsString(value: self.mobile, key: .userMobile)
                    AppRootManager.shared.setRootView(view: HomeScreen())
                } else {
                    let message = model.message.first ?? "Unable to log in."
                    self.mobileError = message
                    self.passwordError = message
                }
            }
            .store(in: &cancellables)
    }

    private func validate() -> Bool {
        if mobile.isEmpty || mobile.count < 10 {
            mobileError = "Mobile number is invalid or empty"
            return false
        }
        if password.isEmpty || password.count < 6 {
            passwordError = "Password is invalid"
            return false
        }
        return true
    }
}
