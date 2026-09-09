//
//  AuthScreen.swift
//  Truedata
//

import SwiftUI

struct AuthScreen: View {

    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        VStack(spacing: 0) {
            AuthHeader()

            VStack(spacing: 16) {
                InputField(
                    label: "Phone Number",
                    text: Binding(
                        get: { viewModel.mobile },
                        set: { viewModel.onMobileChange($0) }
                    ),
                    placeholder: "Enter your phone number",
                    isError: viewModel.mobileError != nil,
                    errorText: viewModel.mobileError,
                    isEnabled: viewModel.isFieldEnabled,
                    keyboardType: .phonePad,
                    textContentType: .telephoneNumber,
                    submitLabel: .next,
                    characterLimit: 10,
                    isDigitsOnly: true
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

                Spacer()

                legalFooter
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .ignoresSafeArea(.keyboard)
        .ignoresSafeArea(edges: .top)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var legalFooter: some View {
        VStack(spacing: 8) {
            Text(legalText)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .tint(Color(hex: "4B5563"))
                .environment(\.openURL, OpenURLAction { url in
                    openURL(url)
                    return .handled
                })

            Button {
                openURL(AppLegalLinks.support)
            } label: {
                Text("Need help? Contact Support")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
            }
            .buttonStyle(.plain)
        }
    }

    private var legalText: AttributedString {
        var lead = AttributedString("By signing in, you agree to our\n")
        lead.foregroundColor = .gray

        var terms = AttributedString("Terms of Service")
        terms.foregroundColor = Color(hex: "4B5563")
        terms.underlineStyle = .single
        terms.font = .system(size: 12, weight: .semibold)
        terms.link = AppLegalLinks.termsOfService

        var mid = AttributedString(" and ")
        mid.foregroundColor = .gray

        var privacy = AttributedString("Privacy Policy")
        privacy.foregroundColor = Color(hex: "4B5563")
        privacy.underlineStyle = .single
        privacy.font = .system(size: 12, weight: .semibold)
        privacy.link = AppLegalLinks.privacyPolicy

        return lead + terms + mid + privacy
    }
}

#Preview {
    AuthScreen()
}
