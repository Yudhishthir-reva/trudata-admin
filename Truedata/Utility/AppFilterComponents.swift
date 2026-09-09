//
//  AppFilterComponents.swift
//  Truedata
//
//  Shared filter-sheet chrome + primitives used across Insights / Payments / etc.
//

import SwiftUI

// MARK: - Sheet chrome

/// Left-rail filter sheet shell: optional banner, sidebar + content, Apply/Reset footer.
struct AppFilterSheetChrome<Banner: View, Content: View>: View {
    let title: String
    let categories: [FilterCategoryItem]
    @Binding var selectedCategoryID: String
    var accent: Color = DashboardTheme.primaryBlue
    var resetTitle: String = "Reset"
    var applyTitle: String = "Apply Filters"
    var showsResetIcon: Bool = true
    var showsApplyIcon: Bool = true
    var usesNavigationChrome: Bool = true
    var onReset: () -> Void
    var onApply: () -> Void
    var onDismiss: (() -> Void)? = nil
    @ViewBuilder var banner: () -> Banner
    @ViewBuilder var content: () -> Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if usesNavigationChrome {
                NavigationStack {
                    sheetBody
                        .navigationTitle(title)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                closeButton
                            }
                        }
                }
            } else {
                VStack(spacing: 0) {
                    plainHeader
                    sheetBody
                }
            }
        }
    }

    private var sheetBody: some View {
        VStack(spacing: 0) {
            banner()

            HStack(spacing: 0) {
                FilterCategorySidebar(
                    categories: categories,
                    selectedCategoryID: $selectedCategoryID,
                    accent: accent
                )
                Divider()
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color.white)
            }
            .frame(maxHeight: .infinity)

            FilterSheetFooter(
                resetTitle: resetTitle,
                applyTitle: applyTitle,
                showsResetIcon: showsResetIcon,
                showsApplyIcon: showsApplyIcon,
                accent: accent,
                onReset: onReset,
                onApply: onApply
            )
        }
        .background(Color(hex: "F3F4F6"))
    }

    private var plainHeader: some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "111827"))
            Spacer()
            closeButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var closeButton: some View {
        Button {
            onDismiss?()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "4B5563"))
                .frame(width: 28, height: 28)
                .background(Color(hex: "E5E7EB"))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

extension AppFilterSheetChrome where Banner == EmptyView {
    init(
        title: String,
        categories: [FilterCategoryItem],
        selectedCategoryID: Binding<String>,
        accent: Color = DashboardTheme.primaryBlue,
        resetTitle: String = "Reset",
        applyTitle: String = "Apply Filters",
        showsResetIcon: Bool = true,
        showsApplyIcon: Bool = true,
        usesNavigationChrome: Bool = true,
        onReset: @escaping () -> Void,
        onApply: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            title: title,
            categories: categories,
            selectedCategoryID: selectedCategoryID,
            accent: accent,
            resetTitle: resetTitle,
            applyTitle: applyTitle,
            showsResetIcon: showsResetIcon,
            showsApplyIcon: showsApplyIcon,
            usesNavigationChrome: usesNavigationChrome,
            onReset: onReset,
            onApply: onApply,
            onDismiss: onDismiss,
            banner: { EmptyView() },
            content: content
        )
    }
}

// MARK: - Category sidebar

struct FilterCategoryItem: Identifiable, Hashable {
    let id: String
    let title: String
}

struct FilterCategorySidebar: View {
    let categories: [FilterCategoryItem]
    @Binding var selectedCategoryID: String
    var accent: Color = DashboardTheme.primaryBlue
    var width: CGFloat = 122

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(categories) { category in
                    let isSelected = selectedCategoryID == category.id
                    Button {
                        selectedCategoryID = category.id
                    } label: {
                        Text(category.title)
                            .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .white : DashboardTheme.neutralDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 12)
                            .background(isSelected ? accent : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
        .frame(width: width)
        .background(DashboardTheme.surfaceVariant.opacity(0.5))
    }
}

// MARK: - Footer

struct FilterSheetFooter: View {
    var resetTitle: String = "Reset"
    var applyTitle: String = "Apply Filters"
    var showsResetIcon: Bool = true
    var showsApplyIcon: Bool = true
    var accent: Color = DashboardTheme.primaryBlue
    var onReset: () -> Void
    var onApply: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onReset) {
                HStack(spacing: 6) {
                    if showsResetIcon {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Text(resetTitle)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(accent.opacity(0.4), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            Button(action: onApply) {
                HStack(spacing: 6) {
                    if showsApplyIcon {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    Text(applyTitle)
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(accent)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white)
    }
}

// MARK: - Primitives

struct FilterSectionTitle: View {
    let title: String
    var accent: Color = DashboardTheme.primaryBlue

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(accent)
            .padding(.bottom, 4)
    }
}

struct FilterRadioRow: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var accent: Color = DashboardTheme.primaryBlue
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? accent : DashboardTheme.neutralMedium)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? accent : DashboardTheme.neutralDark)
                        .multilineTextAlignment(.leading)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct FilterSearchField: View {
    let placeholder: String
    @Binding var text: String
    var filledBackground: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DashboardTheme.neutralMedium)
            TextField(placeholder, text: $text)
                .font(.system(size: 14))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(filledBackground ? Color(hex: "F3F4F6") : Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DashboardTheme.neutralMedium.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct FilterLastUsedBanner: View {
    let label: String
    var onApply: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                    Text("Last Used Filter")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .padding(.leading, 20)
            }
            Spacer()
            Button(action: onApply) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Apply")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(DashboardTheme.primaryBlue)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(AppTheme.brandContainer)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(DashboardTheme.primaryBlue.opacity(0.2), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}

/// Empty-state floating card prompting reuse of the previous filter selection.
struct FilterLastUsedPrompt: View {
    let summaryLabel: String
    var iconSystemName: String = "slider.horizontal.3"
    var onDismiss: () -> Void
    var onUseDefault: () -> Void
    var onApply: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.brandContainer)
                        .frame(width: 38, height: 38)

                    Image(systemName: iconSystemName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apply Last Used Filter?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "111827"))

                    Text("Use your previous filter settings")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "6B7280"))
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "6B7280"))
                        .frame(width: 26, height: 26)
                        .background(Color(hex: "F3F4F6"))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Text(summaryLabel)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DashboardTheme.primaryBlueDark)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(AppTheme.brandContainer)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 12) {
                Button(action: onUseDefault) {
                    Text("Use Default")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "374151"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onApply) {
                    Text("Apply Filter")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(DashboardTheme.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: -4)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - List search + filter button

struct SearchAndFilterBar<SearchTrailing: View>: View {
    let placeholder: String
    @Binding var searchText: String
    var isFilterActive: Bool = false
    var accent: Color = DashboardTheme.primaryBlue
    var filterButtonStyle: SearchAndFilterButtonStyle = .filledIcon
    var onFilterTap: () -> Void
    @ViewBuilder var searchTrailing: () -> SearchTrailing

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DashboardTheme.neutralMedium)
                TextField(placeholder, text: $searchText)
                    .font(.system(size: 15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DashboardTheme.neutralMedium)
                    }
                    .buttonStyle(.plain)
                }

                searchTrailing()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(DashboardTheme.neutralMedium.opacity(0.35), lineWidth: 1)
            }

            Button(action: onFilterTap) {
                ZStack(alignment: .topTrailing) {
                    switch filterButtonStyle {
                    case .filledIcon:
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    case .outlineCapsule:
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Filter")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(accent)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .overlay {
                            Capsule()
                                .stroke(accent.opacity(0.55), lineWidth: 1)
                        }
                    }

                    if isFilterActive {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(Color(hex: "F3F4F6"))
    }
}

enum SearchAndFilterButtonStyle {
    case filledIcon
    case outlineCapsule
}

extension SearchAndFilterBar where SearchTrailing == EmptyView {
    init(
        placeholder: String,
        searchText: Binding<String>,
        isFilterActive: Bool = false,
        accent: Color = DashboardTheme.primaryBlue,
        filterButtonStyle: SearchAndFilterButtonStyle = .filledIcon,
        onFilterTap: @escaping () -> Void
    ) {
        self.init(
            placeholder: placeholder,
            searchText: searchText,
            isFilterActive: isFilterActive,
            accent: accent,
            filterButtonStyle: filterButtonStyle,
            onFilterTap: onFilterTap,
            searchTrailing: { EmptyView() }
        )
    }
}
