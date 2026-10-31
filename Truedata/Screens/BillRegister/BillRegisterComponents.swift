import SwiftUI
import Combine

// The bill register's own pieces, ported from Android `BillUi.kt` and the parts of `CcKit.kt`
// it uses, so the iOS screens draw the same pills, cards, dialogs and buttons.

/// Android `CcColors`: the tones the cash and bill screens share beyond `CashStyle`.
enum BillTone {
    static let page = Color(hex: "F7F9F8")
    static let track = Color(hex: "F3F5F7")
    static let faint = Color(hex: "9CA3AF")
    static let glow = Color(hex: "34D399")
    static let ok = Color(hex: "15803D")
    static let okBg = Color(hex: "DCFCE7")
    static let warn = Color(hex: "B45309")
    static let warnBg = Color(hex: "FEF3C7")
    static let err = Color(hex: "DC2626")
    static let errBg = Color(hex: "FFF1F2")
    static let errInk = Color(hex: "991B1B")
    static let info = Color(hex: "0369A1")
    static let mutedFg = Color(hex: "4B5563")
    static let mutedBg = Color(hex: "F3F4F6")
    static let violet = Color(hex: "6D28D9")
    static let violetBg = Color(hex: "EDE9FE")
    static let fieldBorder = Color(hex: "D1D5DB")
    /// Android `HeroBrand` and its slate twin `HeroMuted`, for a register that was called off.
    static let heroBrand = [CashStyle.deep, CashStyle.green, CashStyle.bright]
    static let heroMuted = [Color(hex: "1F2937"), Color(hex: "374151"), Color(hex: "4B5563")]
}

func billMoney(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "INR"
    formatter.locale = Locale(identifier: "en_IN")
    // Android `rupees`: up to two decimals, none forced, so ₹26,553.5 rather than ₹26,553.50.
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "₹\(amount)"
}

func billCount(_ n: Int) -> String { "\(n) bill" + (n == 1 ? "" : "s") }

/// `removed_at` / `cancelled_at` come raw ("2026-10-26 12:47:57"); this shows them like the
/// server's own formatted dates ("26-Oct-2026 12:47 PM"). Anything else is shown as sent.
func billStamp(_ raw: String?) -> String? {
    guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
    let parse = DateFormatter()
    parse.locale = Locale(identifier: "en_US_POSIX")
    parse.dateFormat = "yyyy-MM-dd HH:mm:ss"
    guard let date = parse.date(from: raw) else { return raw }
    let show = DateFormatter()
    show.locale = Locale(identifier: "en_US_POSIX")
    show.dateFormat = "dd-MMM-yyyy hh:mm a"
    return show.string(from: date)
}

// MARK: - Pills, bars, buttons

struct BillPill: View {
    let text: String
    let fg: Color
    let bg: Color
    var body: some View {
        Text(text).font(.system(size: 10.5, weight: .bold)).foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(bg, in: Capsule())
    }
}

/// A register's or an order's status; a change pops the new pill in.
struct BillStatusPill: View {
    let status: String
    var body: some View {
        Group {
            switch BillRegisterStatus(rawValue: status.lowercased()) {
            case .cleared: BillPill(text: "Cleared", fg: BillTone.ok, bg: BillTone.okBg)
            case .pending: BillPill(text: "Pending", fg: BillTone.warn, bg: BillTone.warnBg)
            case .cancelled: BillPill(text: "Cancelled", fg: BillTone.err, bg: BillTone.errBg)
            case .removed: BillPill(text: "Removed", fg: BillTone.err, bg: BillTone.errBg)
            case nil: BillPill(text: status.isEmpty ? "—" : status.capitalized, fg: BillTone.mutedFg, bg: BillTone.mutedBg)
            }
        }
        .id(status.lowercased())
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .animation(.easeOut(duration: 0.22), value: status.lowercased())
    }
}

/// cleared / total as a thin bar that eases to a new value.
struct BillClearedBar: View {
    let cleared: Int
    let total: Int
    var track: Color = BillTone.track
    var fill: Color = BillTone.ok
    private var fraction: CGFloat { total > 0 ? min(max(CGFloat(cleared) / CGFloat(total), 0), 1) : 0 }
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.6), value: fraction)
    }
}

/// Android `PrimaryButton`: 52pt, the brand gradient, or flat for any other colour (red for a
/// destructive action). `loading` swaps the icon for a spinner.
struct BillPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = CashStyle.green
    var enabled = true
    var loading = false
    let action: () -> Void
    private var active: Bool { enabled && !loading }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(.white).controlSize(.small) }
                else if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(.system(size: 15, weight: .bold)).lineLimit(1)
            }
            .foregroundStyle(.white.opacity(active || loading ? 1 : 0.85))
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(
                color == CashStyle.green
                    ? AnyShapeStyle(CashStyle.gradient) : AnyShapeStyle(color),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .opacity(active || loading ? 1 : 0.4)
            .shadow(color: color.opacity(active ? 0.3 : 0), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(!active)
    }
}

/// Android `SecondaryButton`: the colour at 10% behind its own text.
struct BillSecondaryButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = CashStyle.green
    var enabled = true
    var loading = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading { ProgressView().tint(color).controlSize(.small) }
                else if let icon { Image(systemName: icon).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(.system(size: 14.5, weight: .bold)).lineLimit(1).minimumScaleFactor(0.85)
            }
            .foregroundStyle(color.opacity(enabled ? 1 : 0.4))
            .frame(maxWidth: .infinity).frame(height: 52)
            .padding(.horizontal, 6)
            .background(color.opacity(enabled ? 0.1 : 0.05), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// Android `BottomActionBar`: white tray with a rounded top, a soft shadow and a grab handle.
struct BillBottomBar<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 10) {
            Capsule().fill(CashStyle.border).frame(width: 36, height: 4)
            content()
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                .fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

/// A row whose children share its width by `.billWeight(_:)`, like Compose `Modifier.weight`.
struct BillWeightedRow: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let weights = subviews.map { $0[BillWeight.self] }
        let total = weights.reduce(0, +)
        let free = bounds.width - spacing * CGFloat(max(subviews.count - 1, 0))
        var x = bounds.minX
        for (view, weight) in zip(subviews, weights) {
            let width = total > 0 ? free * weight / total : 0
            view.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading,
                       proposal: ProposedViewSize(width: width, height: bounds.height))
            x += width + spacing
        }
    }
}

nonisolated private struct BillWeight: LayoutValueKey {
    static let defaultValue: CGFloat = 1
}

extension View {
    func billWeight(_ weight: CGFloat) -> some View { layoutValue(key: BillWeight.self, value: weight) }
}

/// Android `ViewOrderChip`: opens the order's full detail screen.
struct BillViewOrderChip: View {
    let orderNo: String
    var body: some View {
        NavigationLink { OrderDetailScreen(orderId: orderNo) } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.text").font(.system(size: 11, weight: .semibold))
                Text("View order").font(.system(size: 11.5, weight: .bold))
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(CashStyle.green)
            .padding(.leading, 7).padding(.trailing, 5).padding(.vertical, 3)
            .background(CashStyle.pale, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// Android `IconDisc`: an icon on a soft disc of its own colour.
struct BillIconDisc: View {
    let icon: String
    let color: Color
    var size: CGFloat = 28
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12), in: Circle())
    }
}

/// "“reason”", in italics, the way Android quotes what someone typed.
struct BillQuote: View {
    let text: String
    var size: CGFloat = 12
    var color: Color = CashStyle.muted
    var lines: Int? = nil
    var body: some View {
        Text("\u{201C}\(text.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}")
            .font(.system(size: size)).italic().foregroundStyle(color).lineLimit(lines)
    }
}

// MARK: - Form pieces

/// Android `CcSection`: a white bordered card headed by an icon disc and a title.
struct BillSection<Content: View>: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                BillIconDisc(icon: icon, color: CashStyle.green)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(CashStyle.ink)
                    if let subtitle { Text(subtitle).font(.system(size: 11)).foregroundStyle(CashStyle.muted) }
                }
                Spacer(minLength: 0)
            }
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border, lineWidth: 1))
    }
}

/// Android `PickerField`: a small bold label over a tappable white box with an icon, the value
/// (faint while it is only a placeholder) and an up-down chevron.
struct BillPickerField: View {
    let label: String
    let value: String
    let icon: String
    var placeholder = false
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11.5, weight: .bold)).foregroundStyle(CashStyle.muted)
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: icon).font(.system(size: 15)).foregroundStyle(CashStyle.muted).frame(width: 18)
                    Text(value).font(.system(size: 14, weight: .medium))
                        .foregroundStyle(placeholder ? BillTone.faint : CashStyle.ink)
                        .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(BillTone.faint)
                }
                .padding(.horizontal, 12).padding(.vertical, 13)
                .background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(BillTone.fieldBorder, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Android `EmptyState`: a faint icon tile, a title and a centred line.
struct BillEmptyState: View {
    let title: String
    let message: String
    var icon = "tray"
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(BillTone.faint)
                .frame(width: 56, height: 56).background(BillTone.track, in: RoundedRectangle(cornerRadius: 16))
            Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(CashStyle.ink)
            Text(message).font(.system(size: 13)).foregroundStyle(CashStyle.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36).padding(.horizontal, 24)
    }
}

/// Android `ErrorState`: the message and a Retry button, centred.
struct BillErrorState: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle").font(.system(size: 26)).foregroundStyle(BillTone.err)
            Text(message).font(.system(size: 13)).foregroundStyle(CashStyle.muted).multilineTextAlignment(.center)
            Button("Retry", action: onRetry).font(.system(size: 14, weight: .semibold)).foregroundStyle(CashStyle.green)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36).padding(.horizontal, 24)
    }
}

/// Android `CcSegmented`: equal segments on a grey track; the picked one is brand green.
struct BillSegmented<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.0) { value, label in
                let on = value == selection
                Button { selection = value } label: {
                    Text(label).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        .foregroundStyle(on ? .white : CashStyle.muted)
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(on ? CashStyle.green : .clear, in: RoundedRectangle(cornerRadius: 9))
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(BillTone.track, in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.18), value: selection)
    }
}

/// Material 3 `FilterChip`, as Android draws the session chips: 32pt, 8pt corners, outlined until
/// picked, then filled.
struct BillFilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? CashStyle.deep : Color(hex: "49454F"))
                .padding(.horizontal, 12).frame(height: 32)
                .background(selected ? CashStyle.pale : .clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? .clear : Color(hex: "79747E"), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - List card

/// Android `BillRegisterCard`. A cancelled register ends with who called it off and why, and its
/// struck-out total, instead of the progress bar.
struct BillRegisterCard: View {
    let entry: BillRegisterEntry
    let showAssignee: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Register #\(entry.id)").font(.system(size: 14, weight: .heavy)).foregroundStyle(CashStyle.ink)
                Text(entry.createdAt ?? "").font(.system(size: 11.5)).foregroundStyle(CashStyle.muted).lineLimit(1)
                Spacer(minLength: 0)
                BillStatusPill(status: entry.status)
            }
            if showAssignee {
                Text("Assigned to \(entry.name.isEmpty ? "—" : entry.name)" + (entry.assignedBy.map { " · by \($0)" } ?? ""))
                    .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(CashStyle.ink)
            }
            if !entry.beatNames.isEmpty {
                Text(entry.beatNames.joined(separator: " · ")).font(.system(size: 12.5)).foregroundStyle(CashStyle.muted)
            }
            if entry.isCancelled {
                cancelledLine
            } else {
                BillClearedBar(cleared: entry.clearedOrders, total: entry.activeOrders)
                HStack(spacing: 0) {
                    Text("\(entry.clearedOrders) of \(entry.activeOrders) orders cleared"
                         + (entry.removedOrders > 0 ? " · \(entry.removedOrders) removed" : ""))
                        .font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                    Spacer(minLength: 6)
                    if !entry.isCleared && entry.pendingAmount > 0 {
                        Text("Pending ").font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                        Text(billMoney(entry.pendingAmount)).font(.system(size: 14, weight: .heavy)).foregroundStyle(BillTone.warn)
                    } else {
                        Text(billMoney(entry.totalAmount)).font(.system(size: 14, weight: .heavy)).foregroundStyle(CashStyle.ink)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border, lineWidth: 1))
    }

    private var cancelledLine: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "nosign").font(.system(size: 13, weight: .semibold)).foregroundStyle(BillTone.err).padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(["Cancelled" + (entry.cancelledBy.map { " by \($0)" } ?? ""), billStamp(entry.cancelledAt)]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(BillTone.err)
                if let reason = entry.cancelReason { BillQuote(text: reason, lines: 1) }
            }
            Spacer(minLength: 8)
            Text(billMoney(entry.totalAmount)).font(.system(size: 14, weight: .heavy))
                .foregroundStyle(BillTone.faint).strikethrough()
        }
    }
}

// MARK: - Beat wise

/// Android `BeatWiseHero`: everything still to collect across the beats shown.
struct BillBeatWiseHero: View {
    let data: BillBeatWise
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PENDING ACROSS BEATS").font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(.white.opacity(0.68))
            Text(billMoney(data.pendingAmount)).font(.system(size: 26, weight: .heavy)).foregroundStyle(.white)
            HStack(spacing: 8) {
                heroStat("Beats", "\(data.totalBeats)")
                heroStat("Pending bills", "\(data.pendingOrders)")
            }.padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(colors: BillTone.heroBrand, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [BillTone.glow.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 220)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func heroStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.72))
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Android `BeatPendingCard`: one beat's pending bills, what is left of what was billed, and
/// across how many registers and sellers.
struct BillBeatPendingCard: View {
    let beat: BillBeatPending
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(beat.name).font(.system(size: 14, weight: .heavy)).foregroundStyle(CashStyle.ink).lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(BillTone.faint)
            }
            Text("\(billCount(beat.pendingOrders)) pending · \(beat.totalRegisters) register\(beat.totalRegisters == 1 ? "" : "s") · \(beat.totalSellers) seller\(beat.totalSellers == 1 ? "" : "s")")
                .font(.system(size: 12.5)).foregroundStyle(CashStyle.muted)
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("Pending ").font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                Text(billMoney(beat.pendingAmount)).font(.system(size: 15, weight: .heavy)).foregroundStyle(BillTone.warn)
                Spacer()
                Text("of \(billMoney(beat.orderAmount))").font(.system(size: 12)).foregroundStyle(CashStyle.muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CashStyle.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Snackbar

/// Material 3 `Snackbar` as Android's `SnackbarHost` shows it: inverse-surface card, 4pt corners,
/// white 14pt text, at the bottom; it slides in and goes after 4 seconds (Android's Short).
private struct BillSnackbar: ViewModifier {
    @Binding var message: String?
    @State private var shown: String?
    @State private var hideTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let shown {
                    Text(shown)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "F4EFF4"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color(hex: "313033"), in: RoundedRectangle(cornerRadius: 4))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .padding(.horizontal, 12).padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture { dismiss() }
                        .accessibilityAddTraits(.isStaticText)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: shown)
            .onChange(of: message) { _, value in
                guard let value, !value.isEmpty else { return }
                // Taken off the model at once, like Android's messageShown(), so it shows once.
                message = nil
                shown = value
                hideTask?.cancel()
                hideTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(4))
                    guard !Task.isCancelled else { return }
                    shown = nil
                }
            }
            .onDisappear { hideTask?.cancel() }
    }

    private func dismiss() {
        hideTask?.cancel()
        shown = nil
    }
}

extension View {
    func billSnackbar(message: Binding<String?>) -> some View { modifier(BillSnackbar(message: message)) }
}

// MARK: - Dialog frame

/// Android `BillDialog`: the pop-up the bill register's own dialogs share. It springs in, can't be
/// closed while `busy`, and on a new `error` shakes and shows it above the buttons, so what was
/// typed or picked stays.
struct BillDialog<Content: View, Buttons: View>: View {
    let busy: Bool
    let error: String?
    let onDismiss: () -> Void
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons
    @State private var shown = false
    @State private var shake: CGFloat = 0
    @State private var keyboardUp = false
    /// IQKeyboardManager resigns the keyboard on the same outside tap before this view sees it,
    /// so a tap landing just after the keyboard went down was meant for the keyboard, not us.
    @State private var keyboardDownAt = Date.distantPast
    /// Set by the first outside tap, so a burst of taps closes the dialog once.
    @State private var closing = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(shown ? 0.4 : 0).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 24)
                        card
                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: proxy.size.height)
                    // The whole area around the card is the "outside": tapping it closes.
                    .contentShape(Rectangle())
                    .onTapGesture(perform: outsideTap)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: shown)
        .animation(.easeInOut(duration: 0.2), value: error)
        .transition(.opacity)
        .onAppear { shown = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
            keyboardDownAt = Date()
        }
        .onChange(of: error) { _, value in
            guard value != nil else { return }
            Task { @MainActor in
                for x: CGFloat in [10, -8, 6, -4, 0] {
                    withAnimation(.linear(duration: 0.045)) { shake = x }
                    try? await Task.sleep(for: .milliseconds(45))
                }
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
            if let error {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(BillTone.err)
                    Text(error).font(.system(size: 12.5)).foregroundStyle(BillTone.errInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(BillTone.errBg, in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(spacing: 10) { buttons() }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        // A tap on the card itself only puts the keyboard away; it never closes the dialog.
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture { hideKeyboard() }
        .scaleEffect(shown ? 1 : 0.88)
        .opacity(shown ? 1 : 0)
        .offset(x: shake)
    }

    /// With the keyboard up, the first tap outside only puts it away, so a reason being typed
    /// isn't thrown out by a stray tap. Closing is ignored while the call runs.
    private func outsideTap() {
        if keyboardUp || Date().timeIntervalSince(keyboardDownAt) < 0.6 { hideKeyboard(); return }
        guard !busy, !closing else { return }
        closing = true
        onDismiss()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Runs an action once: the first tap wins and later taps in the same burst are dropped, so a
/// double tap can't dismiss twice or fire Discard / OK twice.
@MainActor
final class BillOnce: ObservableObject {
    private var fired = false
    func run(_ action: () -> Void) {
        guard !fired else { return }
        fired = true
        action()
    }
}

/// Android `ConfirmDialog`: an icon disc, a title, a body and two buttons.
struct BillConfirmDialog: View {
    let icon: String
    let title: String
    let message: String
    let confirmTitle: String
    var confirmColor: Color = CashStyle.green
    var dismissTitle = "Cancel"
    let onConfirm: () -> Void
    let onDismiss: () -> Void
    @StateObject private var once = BillOnce()
    var body: some View {
        BillDialog(busy: false, error: nil, onDismiss: { once.run(onDismiss) }) {
            VStack(spacing: 10) {
                BillIconDisc(icon: icon, color: confirmColor, size: 52)
                Text(title).font(.system(size: 18, weight: .heavy)).foregroundStyle(CashStyle.ink).multilineTextAlignment(.center)
                Text(message).font(.system(size: 14)).foregroundStyle(CashStyle.muted).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity)
        } buttons: {
            BillWeightedRow {
                BillSecondaryButton(title: dismissTitle, color: CashStyle.muted) { once.run(onDismiss) }
                BillPrimaryButton(title: confirmTitle, color: confirmColor) { once.run(onConfirm) }
            }
        }
    }
}

/// Android `ErrorDialog`: a red error disc, "Can't continue", the message and one OK button.
struct BillErrorDialog: View {
    let message: String
    var title = "Can't continue"
    let onDismiss: () -> Void
    @StateObject private var once = BillOnce()
    var body: some View {
        BillDialog(busy: false, error: nil, onDismiss: { once.run(onDismiss) }) {
            VStack(spacing: 10) {
                BillIconDisc(icon: "exclamationmark.circle", color: BillTone.err, size: 60)
                Text(title).font(.system(size: 18, weight: .heavy)).foregroundStyle(CashStyle.ink).multilineTextAlignment(.center)
                Text(message).font(.system(size: 14)).foregroundStyle(CashStyle.muted).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity).padding(.bottom, 4)
        } buttons: {
            BillPrimaryButton(title: "OK") { once.run(onDismiss) }
        }
    }
}

/// A dialog's bills, as shop and amount: the first few, then how many more.
struct BillLinesPreview: View {
    let lines: [(String, Double)]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.prefix(3).enumerated()), id: \.offset) { _, line in
                HStack {
                    Text(line.0).font(.system(size: 12.5)).foregroundStyle(CashStyle.ink).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(billMoney(line.1)).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(CashStyle.ink)
                }
            }
            if lines.count > 3 {
                Text("+\(lines.count - 3) more").font(.system(size: 11.5)).foregroundStyle(CashStyle.muted)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BillTone.track, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Detail pieces

/// Android `RegisterHero`. A cancelled register drains from brand green to slate, its amount
/// struck out.
struct BillRegisterHero: View {
    let entry: BillRegisterEntry
    var body: some View {
        let cancelled = entry.isCancelled
        let all = entry.orders ?? []
        let active = all.filter { !$0.isRemoved }
        let activeCount = all.isEmpty ? entry.activeOrders : active.count
        let clearedCount = all.isEmpty ? entry.clearedOrders : active.filter(\.isCleared).count
        let removedCount = all.isEmpty ? entry.removedOrders : all.count - active.count
        let amount = entry.isPending ? entry.pendingAmount : entry.totalAmount
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(heroLabel)
                    .font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(.white.opacity(0.68))
                Spacer()
                BillStatusPill(status: entry.status)
            }
            Text(billMoney(amount))
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.white.opacity(cancelled ? 0.75 : 1))
                .strikethrough(cancelled, color: .white.opacity(0.75))
                .contentTransition(.numericText(value: amount))
                .animation(.easeOut(duration: 0.3), value: amount)
            Text(assignedLine).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            if !entry.beatNames.isEmpty {
                Text(entry.beatNames.joined(separator: " · ")).font(.system(size: 12.5)).foregroundStyle(.white.opacity(0.8))
            }
            BillClearedBar(cleared: clearedCount, total: activeCount, track: .white.opacity(0.18),
                           fill: cancelled ? .white.opacity(0.45) : BillTone.glow)
                .padding(.top, 4)
            HStack(spacing: 8) {
                stat("Orders cleared", "\(clearedCount) / \(activeCount)")
                stat("Total billed", billMoney(entry.totalAmount))
                if removedCount > 0 { stat("Removed", "\(removedCount)").frame(maxWidth: 80) }
            }.padding(.top, 4)
            if !datesLine.isEmpty {
                Text(datesLine).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.7)).padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                LinearGradient(colors: cancelled ? BillTone.heroMuted : BillTone.heroBrand, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [BillTone.glow.opacity(cancelled ? 0.06 : 0.22), .clear], center: .center, startRadius: 0, endRadius: 220)
            }
            .animation(.easeInOut(duration: 0.7), value: cancelled)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var heroLabel: String {
        let text = entry.isCleared ? "Collected" : entry.isCancelled ? "Cancelled · was to collect" : "Pending to collect"
        return text.uppercased()
    }

    private var assignedLine: String {
        let name = entry.name.isEmpty ? "—" : entry.name
        return "Assigned to \(name)" + (entry.assignedBy.map { " · by \($0)" } ?? "")
    }

    private var datesLine: String {
        var parts: [String] = []
        if let created = entry.createdAt { parts.append("Created \(created)") }
        if let cleared = entry.clearedAt { parts.append("Cleared \(cleared)") }
        if entry.isCancelled, let stamp = billStamp(entry.cancelledAt) { parts.append("Cancelled \(stamp)") }
        return parts.joined(separator: " · ")
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.72))
            Text(value).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 9).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Who called the register off, when, why, and what became of its bills.
struct BillCancelledNote: View {
    let entry: BillRegisterEntry
    var body: some View {
        let freed = (entry.orders ?? []).filter(\.isCancelled).count
        HStack(alignment: .top, spacing: 10) {
            BillIconDisc(icon: "nosign", color: BillTone.err, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("Register cancelled").font(.system(size: 14, weight: .bold)).foregroundStyle(BillTone.errInk)
                let who = [entry.cancelledBy.map { "By \($0)" }, billStamp(entry.cancelledAt)].compactMap { $0 }
                if !who.isEmpty { Text(who.joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(CashStyle.muted) }
                if let reason = entry.cancelReason { BillQuote(text: reason, size: 13, color: CashStyle.ink) }
                Text((freed > 0 ? "Its \(billCount(freed)) went" : "Its bills went") + " back to unassigned and can be put in a new register.")
                    .font(.system(size: 11.5)).foregroundStyle(CashStyle.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(BillTone.errBg, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(BillTone.err.opacity(0.18), lineWidth: 1))
    }
}

/// Opens or folds the removed bills; they are history, so they start folded.
struct BillRemovedHeader: View {
    let count: Int
    let amount: Double
    let open: Bool
    let onToggle: () -> Void
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: "minus.circle").foregroundStyle(BillTone.err)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Removed bills (\(count))").font(.system(size: 15, weight: .bold)).foregroundStyle(CashStyle.ink)
                    Text("\(billMoney(amount)) · not counted in the total").font(.system(size: 11.5)).foregroundStyle(CashStyle.muted)
                }
                Spacer()
                Image(systemName: "chevron.down").foregroundStyle(CashStyle.muted)
                    .rotationEffect(.degrees(open ? 180 : 0))
                    .animation(.easeInOut(duration: 0.25), value: open)
            }
            .padding(.horizontal, 4).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .accessibilityLabel(open ? "Hide removed bills" : "Show removed bills")
    }
}

/// Android `RegisterOrderRow`: a checkbox while it can be picked, otherwise a mark (cleared tick or
/// removed circle). Removed and cancelled bills read muted; a removed one says who, when and why.
struct BillRegisterOrderRow: View {
    let order: BillRegisterOrderEntry
    let selectable: Bool
    let selected: Bool
    let enabled: Bool
    let onToggle: () -> Void
    @Environment(\.openURL) private var openURL

    private var canTick: Bool { selectable && order.isPending }
    private var gone: Bool { order.isRemoved || order.isCancelled }

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            if selectable { mark.frame(width: 40) }
            details
            Spacer(minLength: 6)
            amounts
            callButton
        }
        .padding(.leading, selectable ? 2 : 12).padding(.trailing, 4).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? CashStyle.green.opacity(0.6) : CashStyle.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { if canTick && enabled { onToggle() } }
        .animation(.easeInOut(duration: 0.22), value: selected)
    }

    private var fill: Color { selected ? CashStyle.pale : gone ? BillTone.track : .white }

    /// A bill that can't be picked gets a mark where the checkbox would be.
    @ViewBuilder private var mark: some View {
        if canTick {
            Image(systemName: selected ? "checkmark.square.fill" : "square")
                .font(.system(size: 20)).foregroundStyle(selected ? CashStyle.green : CashStyle.muted)
        } else if order.isCleared {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(BillTone.ok)
        } else if order.isRemoved {
            Image(systemName: "minus.circle").font(.system(size: 20)).foregroundStyle(BillTone.err.opacity(0.7))
        }
    }

    private var subtitle: String {
        let seller: String? = order.shop.isEmpty || order.seller.isEmpty ? nil : order.seller
        let number: String? = order.orderNo.isEmpty ? nil : order.orderNo
        let delivered: String? = order.deliveryDate.map { "Delivered \($0)" }
        return [seller, number, delivered].compactMap { $0 }.joined(separator: " · ")
    }

    private var removedLine: String {
        let who = "Removed" + (order.removedBy.map { " by \($0)" } ?? "")
        return [who, billStamp(order.removedAt)].compactMap { $0 }.joined(separator: " · ")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(order.shop.isEmpty ? (order.seller.isEmpty ? "—" : order.seller) : order.shop)
                .font(.system(size: 14, weight: .bold)).foregroundStyle(gone ? CashStyle.muted : CashStyle.ink)
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 12)).foregroundStyle(CashStyle.muted) }
            // An order freed by the register's cancel is no one's to collect any more.
            HStack(spacing: 6) {
                if order.isCancelled { BillPill(text: "Cancelled", fg: BillTone.mutedFg, bg: BillTone.mutedBg) }
                else { BillStatusPill(status: order.status) }
                if !order.orderNo.isEmpty { BillViewOrderChip(orderNo: order.orderNo) }
            }
            // On its own line so a long beat name wraps instead of being cut.
            if let beat = order.beatName { Text(beat).font(.system(size: 11.5)).foregroundStyle(BillTone.info) }
            if order.isRemoved {
                Text(removedLine).font(.system(size: 11.5, weight: .semibold)).foregroundStyle(BillTone.err)
                if let reason = order.removeReason { BillQuote(text: reason) }
            }
        }
    }

    private var amounts: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(billMoney(order.currentPending))
                .font(.system(size: 14.5, weight: .heavy))
                .foregroundStyle(order.isPending ? CashStyle.ink : CashStyle.muted)
                .strikethrough(order.isRemoved)
            // The order's pending payment has moved since it went in the register.
            if order.currentPending != order.pending {
                Text("was \(billMoney(order.pending))").font(.system(size: 11)).foregroundStyle(BillTone.faint)
            }
        }
    }

    @ViewBuilder private var callButton: some View {
        if let mobile = order.sellerMobile, let url = URL(string: "tel:" + mobile.filter { $0.isNumber || $0 == "+" }) {
            Button { openURL(url) } label: {
                Image(systemName: "phone.fill").font(.system(size: 16)).foregroundStyle(CashStyle.green).frame(width: 36, height: 36)
            }
            .buttonStyle(.plain).accessibilityLabel("Call \(mobile)")
        }
    }
}

/// Android `BeatOrderRow`: a bill to pick for a new register. One already in another register is
/// greyed out and says which.
struct BillBeatOrderRow: View {
    let order: BillRegisterOrder
    let selected: Bool
    let showBeat: Bool
    let onToggle: () -> Void

    private var locked: Bool { order.isAssigned }
    private var subtitle: String {
        [order.orderNo, order.deliveryDate.isEmpty ? "" : "Delivered \(order.deliveryDate)", order.staffName]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: selected ? "checkmark.square.fill" : "square")
                .font(.system(size: 20))
                .foregroundStyle(locked ? BillTone.faint.opacity(0.6) : selected ? CashStyle.green : CashStyle.muted)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(order.sellerShopName.isEmpty ? (order.sellerName.isEmpty ? "—" : order.sellerName) : order.sellerShopName)
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(locked ? CashStyle.muted : CashStyle.ink)
                if !subtitle.isEmpty { Text(subtitle).font(.system(size: 12)).foregroundStyle(CashStyle.muted) }
                if showBeat && !order.beatName.isEmpty {
                    Text(order.beatName).font(.system(size: 11.5)).foregroundStyle(BillTone.info)
                }
                if locked {
                    BillPill(text: "In register #\(order.billRegisterId.map(String.init) ?? "?") · \(order.billRegisterAssignedToName ?? "assigned")",
                             fg: BillTone.violet, bg: BillTone.violetBg)
                }
                if !order.orderNo.isEmpty { BillViewOrderChip(orderNo: order.orderNo) }
            }
            Spacer(minLength: 8)
            Text(billMoney(order.pendingAmount)).font(.system(size: 14.5, weight: .heavy))
                .foregroundStyle(locked ? BillTone.faint : CashStyle.ink)
        }
        .padding(.leading, 2).padding(.trailing, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(locked ? BillTone.track : selected ? CashStyle.pale : .white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? CashStyle.green.opacity(0.6) : CashStyle.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { if !locked { onToggle() } }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }
}

/// Android `BeatPickerSheet`: tick beats (A–Z, searchable), then apply them all at once. Nothing
/// changes on the page until the button is tapped.
struct BillBeatPickerSheet: View {
    let beats: [BeatListItem]
    let selected: Set<Int>
    let isLoading: Bool
    let onRetry: () -> Void
    let onApply: (Set<Int>) -> Void
    /// Android `applyLabel`: the create screen shows orders, the list filter shows beats.
    var applyLabel: (Int) -> String = { "Show orders from \($0) beat\($0 == 1 ? "" : "s")" }
    @Environment(\.dismiss) private var dismiss
    @State private var picked: Set<Int> = []
    @State private var query = ""

    private var shown: [BeatListItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return beats.filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Choose beats").font(.system(size: 18, weight: .heavy)).foregroundStyle(CashStyle.ink)
                    Text(picked.isEmpty ? "None selected" : "\(picked.count) selected")
                        .font(.system(size: 12.5)).foregroundStyle(CashStyle.muted)
                }
                Spacer()
                if !picked.isEmpty {
                    Button("Clear") { picked = [] }.font(.system(size: 14, weight: .bold)).foregroundStyle(CashStyle.green)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(CashStyle.muted)
                TextField("Search beats", text: $query).textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 12).frame(height: 52)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BillTone.fieldBorder, lineWidth: 1))
            if isLoading {
                ProgressView().tint(CashStyle.green).controlSize(.large).frame(maxWidth: .infinity).padding(40)
            } else if beats.isEmpty {
                BillErrorState(message: "Couldn't load the beats.", onRetry: onRetry)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(shown) { beat in
                            let on = picked.contains(beat.id)
                            Button {
                                if on { picked.remove(beat.id) } else { picked.insert(beat.id) }
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: on ? "checkmark.square.fill" : "square").font(.system(size: 20))
                                        .foregroundStyle(on ? CashStyle.green : CashStyle.muted)
                                    Text(beat.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(CashStyle.ink)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12).frame(minHeight: 52)
                                .background(on ? CashStyle.pale : .clear, in: RoundedRectangle(cornerRadius: 10))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        if shown.isEmpty {
                            Text("No beat matches \u{201C}\(query)\u{201D}.").font(.system(size: 14)).foregroundStyle(CashStyle.muted)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        }
                    }
                }
            }
            BillPrimaryButton(title: picked.isEmpty ? "Done" : applyLabel(picked.count),
                              icon: "checkmark") {
                onApply(picked)
                dismiss()
            }
        }
        .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 16)
        .background(Color.white.ignoresSafeArea())
        .onAppear { picked = selected }
    }
}

/// Download PDF / Download CSV, side by side; one download at a time.
struct BillExportRow: View {
    let exporting: BillExportFormat?
    let onExport: (BillExportFormat) -> Void
    var body: some View {
        HStack(spacing: 10) {
            ForEach(BillExportFormat.allCases) { format in
                BillSecondaryButton(
                    title: exporting == format ? "Downloading…" : "Download \(format.label)",
                    icon: format == .pdf ? "doc.richtext" : "tablecells",
                    enabled: exporting == nil,
                    loading: exporting == format
                ) { onExport(format) }
            }
        }
    }
}

// MARK: - Cancel / remove reason

enum BillReasonAction: Equatable {
    case cancel
    case remove(Set<Int>)
}

/// The cancel / remove dialog. It stays open while the call runs, so a failure keeps the reason.
struct BillReasonPrompt: Equatable {
    let action: BillReasonAction
    var reason = ""
    var isWorking = false
    var error: String?
}

/// Asks for the reason behind a cancel or a remove and says what will happen.
struct BillReasonDialog: View {
    @Binding var prompt: BillReasonPrompt
    let entry: BillRegisterEntry
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    private static let cancelReasons = ["Wrong orders assigned", "Wrong employee", "Made by mistake"]
    private static let removeReasons = ["Paid at office", "Order returned", "Wrong order added"]

    var body: some View {
        let cancel = prompt.action == .cancel
        let ids: Set<Int> = { if case .remove(let ids) = prompt.action { return ids }; return [] }()
        let all = entry.orders ?? []
        let bills = all.filter { $0.isPending && (cancel || ids.contains($0.orderID)) }
        let sum = bills.reduce(0) { $0 + $1.currentPending }
        let left = all.filter(\.isPending).count - bills.count
        let message: String = {
            if cancel {
                return "All \(billCount(bills.count)) go back to unassigned so they can be put in a new register. "
                    + "\(entry.name.isEmpty ? "The employee" : entry.name) won't collect them in this one. This can't be undone."
            }
            if left > 0 {
                return "\(billMoney(sum)) comes out of this register's total and "
                    + (bills.count == 1 ? "the bill is" : "the bills are") + " free for another register. Removed bills stay listed here."
            }
            if all.contains(where: \.isCleared) { return "That leaves nothing to collect, so the register will be marked cleared." }
            return "That leaves no bills, so the register will be cancelled."
        }()
        let icon = cancel ? "nosign" : "minus.circle"

        BillDialog(busy: prompt.isWorking, error: prompt.error, onDismiss: onDismiss) {
            HStack(spacing: 12) {
                BillIconDisc(icon: icon, color: BillTone.err, size: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(cancel ? "Cancel Register #\(entry.id)?" : "Remove \(billCount(bills.count))?")
                        .font(.system(size: 17, weight: .heavy)).foregroundStyle(CashStyle.ink)
                    Text(cancel ? "\(entry.name.isEmpty ? "—" : entry.name) · \(billMoney(sum)) pending" : "\(billMoney(sum)) from Register #\(entry.id)")
                        .font(.system(size: 12)).foregroundStyle(CashStyle.muted)
                }
            }
            Text(message).font(.system(size: 13.5)).foregroundStyle(CashStyle.muted).fixedSize(horizontal: false, vertical: true)
            if !cancel { BillLinesPreview(lines: bills.map { ($0.title, $0.currentPending) }) }
            HStack(spacing: 6) {
                Text("Reason").font(.system(size: 13, weight: .bold)).foregroundStyle(CashStyle.ink)
                Text("Optional").font(.system(size: 11.5)).foregroundStyle(BillTone.faint)
            }
            FlowLayout(spacing: 6) {
                ForEach(cancel ? Self.cancelReasons : Self.removeReasons, id: \.self) { quick in
                    let picked = prompt.reason == quick
                    Button { setReason(picked ? "" : quick) } label: {
                        Text(quick).font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(picked ? BillTone.err : Color(hex: "374151"))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(picked ? BillTone.errBg : .white, in: Capsule())
                            .overlay(Capsule().stroke(picked ? BillTone.err : Color(hex: "D1D5DB"), lineWidth: 1))
                    }
                    .buttonStyle(.plain).disabled(prompt.isWorking)
                }
            }
            VStack(alignment: .trailing, spacing: 4) {
                HStack(alignment: .top) {
                    TextField(cancel ? "Why is it being cancelled?" : "Why are these bills being removed?",
                              text: Binding(get: { prompt.reason }, set: setReason), axis: .vertical)
                        .lineLimit(2...4).font(.system(size: 15))
                    SpeechRemarkButton(text: Binding(get: { prompt.reason }, set: setReason))
                }
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(CashStyle.border, lineWidth: 1))
                .disabled(prompt.isWorking)
                Text("\(prompt.reason.count) / \(BillRegisterRequest.reasonMax)").font(.system(size: 11)).foregroundStyle(CashStyle.muted)
            }
        } buttons: {
            BillWeightedRow {
                BillSecondaryButton(title: cancel ? "Keep it" : "Back", color: CashStyle.muted, enabled: !prompt.isWorking, action: onDismiss)
                BillPrimaryButton(title: cancel ? "Cancel register" : "Remove \(bills.count)", icon: icon, color: BillTone.err,
                                  enabled: !bills.isEmpty, loading: prompt.isWorking, action: onConfirm)
                    .billWeight(1.4)
            }
        }
    }

    private func setReason(_ text: String) {
        guard !prompt.isWorking else { return }
        prompt.reason = String(text.prefix(BillRegisterRequest.reasonMax))
        prompt.error = nil
    }
}
