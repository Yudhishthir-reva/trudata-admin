//
//  HomeAppBar.swift
//  Truedata
//

import SwiftUI

struct HomeAppBar: View {
    let title: String
    let role: String
    let profileUrl: String
    var onProfileTap: () -> Void = {}
    var onRefresh: () -> Void
    var onLogout: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            profileAvatar

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome Back!")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title.isEmptyString ? "TruDataa" : title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !role.isEmptyString {
                        Text("(\(role))")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 36, height: 36)
            }

            Button(action: onLogout) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 28)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [AppTheme.darkMidnightBlue, Color(hex: "632BC7")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .ignoresSafeArea(edges: .top)
        }
    }

    private var profileAvatar: some View {
        Button(action: onProfileTap) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.45), lineWidth: 2)
                    .frame(width: 52, height: 52)

                if !profileUrl.isEmptyString {
                    RemoteImage(url: profileUrl)
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(.white.opacity(0.18))
                        .frame(width: 46, height: 46)
                        .overlay {
                            Text(initial)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                        }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var initial: String {
        let source = title.isEmptyString ? "T" : title
        return String(source.prefix(1)).uppercased()
    }
}
