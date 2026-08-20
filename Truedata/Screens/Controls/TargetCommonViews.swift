//
//  TargetCommonViews.swift
//  Truedata
//

import SwiftUI

struct TargetCreateFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .bold))
                Text("Create Target")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(DashboardTheme.primaryBlue)
            .clipShape(Capsule())
            .shadow(color: DashboardTheme.primaryBlue.opacity(0.35), radius: 8, y: 4)
        }
    }
}

struct SalesTargetCard: View {
    let target: SalesTargetItem
    var onEdit: () -> Void
    var onHistory: () -> Void
    var onDelete: () -> Void

    @State private var showCelebration = false

    var body: some View {
        ZStack {
            cardContent

            if showCelebration {
                BalloonCelebrationView(style: .card, duration: 3.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showCelebration = false
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity)
            }
        }
        .onAppear {
            if target.status == .complete {
                showCelebration = true
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DashboardTheme.primaryBlue.opacity(0.12),
                                        Color(hex: "8B5CF6").opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                        Image(systemName: "flag.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DashboardTheme.primaryBlue)
                    }

                    Text(target.staffName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(target.status.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(target.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(target.status.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TARGET")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        Text(target.targetAmount.priceLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DashboardTheme.neutralDark)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("ACHIEVED")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralMedium)
                        Text(target.achievedAmount.priceLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(DashboardTheme.successGreen)
                    }
                }
                .padding(12)
                .background(Color(hex: "F3F4F6").opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                ProgressView(value: target.progress)
                    .tint(target.status.color)
                    .scaleEffect(x: 1, y: 1.6, anchor: .center)

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                    Text(target.durationText)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)

            Divider()

            HStack(spacing: 0) {
                if target.showTargetEditButton {
                    TargetActionButton(title: "Edit", icon: "pencil", color: DashboardTheme.neutralDark, action: onEdit)
                    TargetVerticalDivider()
                }
                TargetActionButton(title: "History", icon: "clock.arrow.circlepath", color: Color(hex: "3B82F6"), action: onHistory)
                TargetVerticalDivider()
                TargetActionButton(title: "Delete", icon: "trash", color: DashboardTheme.dangerRed, action: onDelete)
            }
            .frame(height: 44)
            .background(Color(hex: "F9FAFB"))
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        }
        .shadow(color: DashboardTheme.primaryBlue.opacity(0.08), radius: 4, y: 2)
    }
}

private struct TargetActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct TargetVerticalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: "E5E7EB"))
            .frame(width: 1)
    }
}

struct TargetFilterSheet: View {
    @Binding var draftFilters: TargetFilters
    let staffMembers: [RegisteredStaffMember]
    var onApply: () -> Void
    var onReset: () -> Void
    var onDismiss: () -> Void

    @State private var showStaffPicker = false
    @State private var showStatusPicker = false

    private var selectedStatusLabel: String {
        guard !draftFilters.targetStatus.isEmpty else { return "Select Status" }
        return SalesTargetStatus.from(id: draftFilters.targetStatus).label
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    pickerField(label: "Sale Person", value: draftFilters.staffName.isEmpty ? "Select Staff" : draftFilters.staffName, isPlaceholder: draftFilters.staffName.isEmpty) {
                        showStaffPicker = true
                    }

                    pickerField(label: "Target Status", value: selectedStatusLabel, isPlaceholder: draftFilters.targetStatus.isEmpty) {
                        showStatusPicker = true
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Month")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        TextField("YYYY-MM", text: $draftFilters.month)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 12) {
                        Button("Reset") {
                            onReset()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(DashboardTheme.primaryBlue, lineWidth: 1)
                        }

                        PrimaryActionButton(title: "Apply") {
                            onApply()
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Filter Sales Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { onDismiss() }
                }
            }
            .sheet(isPresented: $showStaffPicker) {
                TargetPickerSheet(
                    title: "Select Staff",
                    options: staffMembers.map(\.name),
                    onSelect: { name in
                        if let staff = staffMembers.first(where: { $0.name == name }) {
                            draftFilters.staffId = String(staff.id)
                            draftFilters.staffName = staff.name
                        }
                    }
                )
            }
            .sheet(isPresented: $showStatusPicker) {
                TargetPickerSheet(
                    title: "Select Status",
                    options: SalesTargetStatus.allCases.map(\.label),
                    onSelect: { label in
                        if let status = SalesTargetStatus.allCases.first(where: { $0.label == label }) {
                            draftFilters.targetStatus = status.rawValue
                        }
                    }
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func pickerField(
        label: String,
        value: String,
        isPlaceholder: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
            Button(action: action) {
                HStack {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(isPlaceholder ? DashboardTheme.neutralMedium : DashboardTheme.neutralDark)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct TargetFormSheet: View {
    @Binding var form: TargetFormData
    let staffMembers: [RegisteredStaffMember]
    let isLoading: Bool
    var onMonthChange: (String) -> Void
    var onSave: () -> Void
    var onDismiss: () -> Void

    @State private var showStaffPicker = false
    @State private var showStatusPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    pickerField(
                        label: "Sale Person",
                        value: form.staffName.isEmpty ? "Select Staff" : form.staffName,
                        isPlaceholder: form.staffName.isEmpty,
                        isEnabled: !form.isEditMode
                    ) {
                        showStaffPicker = true
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Target Amount")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        HStack {
                            TextField("Enter target amount", text: $form.targetAmount)
                                .keyboardType(.decimalPad)
                            Text("₹")
                                .foregroundStyle(DashboardTheme.neutralMedium)
                        }
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Target Month")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(DashboardTheme.neutralDark)
                        TextField("YYYY-MM", text: $form.month)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: form.month) { _, newValue in
                                onMonthChange(newValue)
                            }
                    }

                    TargetDatePickerField(label: "Start Date", dateString: form.targetStartDate) {
                        form.targetStartDate = $0
                    }

                    TargetDatePickerField(label: "End Date", dateString: form.targetEndDate) {
                        form.targetEndDate = $0
                    }

                    if form.isEditMode {
                        pickerField(
                            label: "Target Status",
                            value: SalesTargetStatus.from(id: form.targetStatus).label,
                            isPlaceholder: false,
                            isEnabled: true
                        ) {
                            showStatusPicker = true
                        }
                    }

                    PrimaryActionButton(
                        title: isLoading
                            ? (form.isEditMode ? "Updating..." : "Creating...")
                            : (form.isEditMode ? "Update Target" : "Create Target"),
                        isEnabled: !isLoading && form.isValid
                    ) {
                        onSave()
                    }
                }
                .padding(16)
            }
            .navigationTitle(form.isEditMode ? "Edit Sales Target" : "Create New Sales Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if !isLoading { onDismiss() }
                    }
                }
            }
            .sheet(isPresented: $showStaffPicker) {
                TargetPickerSheet(
                    title: "Select Staff",
                    options: staffMembers.map(\.name),
                    onSelect: { name in
                        if let staff = staffMembers.first(where: { $0.name == name }) {
                            form.staffId = String(staff.id)
                            form.staffName = staff.name
                        }
                    }
                )
            }
            .sheet(isPresented: $showStatusPicker) {
                TargetPickerSheet(
                    title: "Select Status",
                    options: SalesTargetStatus.allCases.map(\.label),
                    onSelect: { label in
                        if let status = SalesTargetStatus.allCases.first(where: { $0.label == label }) {
                            form.targetStatus = status.rawValue
                        }
                    }
                )
            }
        }
        .presentationDetents([.large])
    }

    private func pickerField(
        label: String,
        value: String,
        isPlaceholder: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)
            Button(action: action) {
                HStack {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundStyle(isPlaceholder ? DashboardTheme.neutralMedium : DashboardTheme.neutralDark)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.6)
        }
    }
}

private struct TargetPickerSheet: View {
    let title: String
    let options: [String]
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: [String] {
        guard !search.isEmptyString else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { option in
                Button(option) {
                    onSelect(option)
                    dismiss()
                }
                .foregroundStyle(AppTheme.darkMidnightBlue)
            }
            .searchable(text: $search, prompt: "Search")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct TargetDatePickerField: View {
    let label: String
    let dateString: String
    var onDateSelected: (String) -> Void

    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralDark)

            Button {
                showPicker = true
            } label: {
                HStack {
                    Text(dateString.isEmptyString ? "Select date" : dateString)
                        .font(.system(size: 15))
                        .foregroundStyle(dateString.isEmptyString ? DashboardTheme.neutralMedium : DashboardTheme.neutralDark)
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundStyle(DashboardTheme.primaryBlue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: "D1D5DB"), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { TargetAPIDateFormat.parse(dateString) ?? Date() },
                            set: { onDateSelected(TargetAPIDateFormat.string(from: $0)) }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    Spacer()
                }
                .navigationTitle(label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showPicker = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct TargetHistoryHeroSection: View {
    let target: TargetHistoryDetails
    let staffName: String

    var body: some View {
        VStack(spacing: 24) {
            TargetAnimatedCircularProgress(progress: target.progress)

            HStack(spacing: 16) {
                TargetInfoChip(
                    icon: "checkmark.circle.fill",
                    label: "Achieved",
                    amount: target.achievedAmount.priceLabel,
                    color: DashboardTheme.successGreen
                )
                TargetInfoChip(
                    icon: "flag.fill",
                    label: "Target",
                    amount: target.targetAmount.priceLabel,
                    color: DashboardTheme.primaryBlue
                )
            }

            TargetDetailInfoCard(target: target, staffName: staffName)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    DashboardTheme.primaryBlue.opacity(0.08),
                    Color(hex: "F3F4F6")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct TargetAnimatedCircularProgress: View {
    let progress: Double

    @State private var animatedProgress: Double = 0

    private let startAngle: Double = 140
    private let sweepAngle: Double = 260

    var body: some View {
        ZStack {
            TargetArcTrack(startAngle: startAngle, sweepAngle: sweepAngle)
                .stroke(DashboardTheme.surfaceVariant.opacity(0.5), style: StrokeStyle(lineWidth: 18, lineCap: .round))

            TargetArcTrack(startAngle: startAngle, sweepAngle: sweepAngle * animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [DashboardTheme.infoBlue, DashboardTheme.primaryBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )

            VStack(spacing: 4) {
                Text("\(Int((animatedProgress * 100).rounded()))%")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(DashboardTheme.primaryBlue)
                Text("Completed")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
        }
        .frame(width: 180, height: 180)
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 1.5)) {
                animatedProgress = newValue
            }
        }
    }
}

private struct TargetArcTrack: Shape {
    var startAngle: Double
    var sweepAngle: Double

    var animatableData: Double {
        get { sweepAngle }
        set { sweepAngle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(startAngle + sweepAngle),
            clockwise: false
        )
        return path
    }
}

struct TargetInfoChip: View {
    let icon: String
    let label: String
    let amount: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(amount)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DashboardTheme.neutralMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: color.opacity(0.12), radius: 4, y: 2)
    }
}

struct TargetDetailInfoCard: View {
    let target: TargetHistoryDetails
    let staffName: String

    var body: some View {
        VStack(spacing: 12) {
            TargetDetailInfoRow(
                label: "Status",
                value: target.status.label,
                valueColor: target.status.color,
                icon: targetStatusIcon(for: target.status)
            )
            Divider().overlay(Color(hex: "E5E7EB").opacity(0.8))
            TargetDetailInfoRow(
                label: "Month",
                value: target.month,
                icon: "calendar"
            )
            Divider().overlay(Color(hex: "E5E7EB").opacity(0.8))
            TargetDetailInfoRow(
                label: "Sale Person",
                value: staffName,
                icon: "person.fill"
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: "E5E7EB").opacity(0.6), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }

    private func targetStatusIcon(for status: SalesTargetStatus) -> String {
        switch status {
        case .pending: return "clock.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .complete: return "checkmark.shield.fill"
        case .incomplete: return "minus.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .other: return "list.bullet.rectangle"
        }
    }
}

private struct TargetDetailInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = DashboardTheme.neutralDark
    let icon: String

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(DashboardTheme.neutralMedium)
            }
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(valueColor)
        }
    }
}

struct TargetContributingOrdersHeader: View {
    let count: Int

    var body: some View {
        HStack {
            Text("Contributing Orders")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DashboardTheme.neutralDark)
            Spacer()
            Text("\(count) Orders")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DashboardTheme.neutralMedium)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(DashboardTheme.surfaceVariant)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct TargetHistoryOrderRow: View {
    let order: TargetHistoryOrder

    private var orderStatus: TargetOrderDisplayStatus {
        TargetOrderDisplayStatus.from(id: order.status)
    }

    var body: some View {
        HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(orderStatus.color.opacity(0.08))
                        .frame(width: 48, height: 48)
                    Image(systemName: orderStatus.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(orderStatus.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(order.orderId)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)
                    Text(order.date)
                        .font(.system(size: 12))
                        .foregroundStyle(DashboardTheme.neutralMedium)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(order.totalPrice.priceLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DashboardTheme.neutralDark)

                    HStack(spacing: 2) {
                        Text("View")
                            .font(.system(size: 11, weight: .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(DashboardTheme.primaryBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DashboardTheme.primaryBlue.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }
}

private enum TargetOrderDisplayStatus {
    case pending, inProgress, complete, incomplete, cancelled, other

    static func from(id: String) -> TargetOrderDisplayStatus {
        switch id {
        case "0": return .pending
        case "1": return .inProgress
        case "2": return .complete
        case "3": return .incomplete
        case "4": return .cancelled
        default: return .other
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .complete: return "checkmark.seal.fill"
        case .incomplete: return "minus.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .other: return "list.bullet.rectangle"
        }
    }

    var color: Color {
        switch self {
        case .pending: return DashboardTheme.warningYellow
        case .inProgress: return DashboardTheme.infoBlue
        case .complete: return DashboardTheme.successGreen
        case .incomplete: return DashboardTheme.pickupOrange
        case .cancelled: return DashboardTheme.dangerRed
        case .other: return DashboardTheme.neutralMedium
        }
    }
}
