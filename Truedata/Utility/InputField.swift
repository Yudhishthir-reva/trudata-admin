//
//  InputField.swift
//  Truedata
//

import SwiftUI

struct InputField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isError: Bool = false
    var errorText: String? = nil
    var isSecure: Bool = false
    var isEnabled: Bool = true
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .next
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    private var colors: (text: Color, background: Color, border: Color, label: Color) {
        if isError {
            return (AppTheme.errorRedText, AppTheme.errorRedBg, AppTheme.errorRed, AppTheme.errorRed)
        }
        if isFocused {
            return (AppTheme.darkMidnightBlue, AppTheme.aliceBlue, AppTheme.blue, AppTheme.cerulean)
        }
        if text.isEmpty {
            return (AppTheme.slateGray, AppTheme.whiteSmoke, AppTheme.gainsboro, AppTheme.silver)
        }
        return (AppTheme.darkMidnightBlue, AppTheme.aliceBlue, AppTheme.blue, AppTheme.cerulean)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(colors.label)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
            .focused($isFocused)
            .disabled(!isEnabled)
            .font(.system(size: 16))
            .foregroundStyle(colors.text)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(colors.border, lineWidth: 2)
            }

            if isError, let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.errorRed)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isFocused)
        .animation(.easeInOut(duration: 0.18), value: isError)
    }
}
