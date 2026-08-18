//
//  AuthScreen.swift
//  Truedata
//

import SwiftUI

struct AuthScreen: View {

    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        VStack(spacing: 0) {
            AuthHeader()

            ScrollView {
                VStack(spacing: 16) {
                    InputField(
                        label: "Phone Number",
                        text: Binding(
                            get: { viewModel.mobile },
                            set: { viewModel.onMobileChange($0) }
                        ),
                        placeholder: "Enter your phone number",
                        isError: viewModel.mobileError != nil,
                        isEnabled: viewModel.isFieldEnabled,
                        keyboardType: .numberPad,
                        textContentType: .telephoneNumber,
                        submitLabel: .next
                    )

                    InputField(
                        label: "Password",
                        text: Binding(
                            get: { viewModel.password },
                            set: { viewModel.onPasswordChange($0) }
                        ),
                        placeholder: "Enter your password",
                        isError: viewModel.passwordError != nil,
                        errorText: viewModel.passwordError,
                        isSecure: true,
                        isEnabled: viewModel.isFieldEnabled,
                        textContentType: .password,
                        submitLabel: .done,
                        onSubmit: { viewModel.login() }
                    )

                    PrimaryActionButton(
                        title: "Log in",
                        isLoading: viewModel.isLoading,
                        isEnabled: viewModel.isFieldEnabled
                    ) {
                        viewModel.login()
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }

            legalFooter
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .background(Color.white.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var legalFooter: some View {
        Text(legalText)
            .font(.system(size: 12))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var legalText: AttributedString {
        var lead = AttributedString("By signing in, you agree to our\n")
        lead.foregroundColor = .gray

        var terms = AttributedString("Terms of Service")
        terms.foregroundColor = Color(hex: "4B5563")
        terms.underlineStyle = .single
        terms.font = .system(size: 12, weight: .semibold)

        var mid = AttributedString(" and ")
        mid.foregroundColor = .gray

        var privacy = AttributedString("Privacy Policy")
        privacy.foregroundColor = Color(hex: "4B5563")
        privacy.underlineStyle = .single
        privacy.font = .system(size: 12, weight: .semibold)

        return lead + terms + mid + privacy
    }
}

#Preview {
    AuthScreen()
}
