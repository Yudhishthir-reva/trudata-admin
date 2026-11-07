import SwiftUI

/// Android `PackerOrdersScreen` (home route `order_paker`): the signed-in packer's orders by stage,
/// filtered by bill date and searchable by bill no, shop or mobile. A card opens the order to pack.
struct PackerOrdersScreen: View {
    var onOpen: (Int) -> Void
    var onHome: () -> Void
    @StateObject private var model = PackerOrdersViewModel()
    @State private var pickingDate = false

    var body: some View {
        CashPage(title: "My Packing", onHome: onHome, onRefresh: { model.load() }) {
            PackerOrdersList(model: model, onDate: { pickingDate = true }, onOpen: onOpen)
        }
        .sheet(isPresented: $pickingDate) {
            PackDatePickerSheet(initial: model.state.date) { model.setDate($0) }
        }
    }
}

private struct PackerOrdersList: View {
    @ObservedObject var model: PackerOrdersViewModel
    let onDate: () -> Void
    let onOpen: (Int) -> Void

    var body: some View {
        let s = model.state
        let shown = s.shown
        LazyVStack(alignment: .leading, spacing: 8) {
            PackSearchBox(text: Binding(get: { model.state.query }, set: model.onQuery), hint: "Search bill no, shop or mobile")
            PackFilterPill(label: "Bill date", value: s.date?.label ?? "Any date", icon: "calendar",
                           active: s.date != nil, onClick: onDate, onClear: { model.setDate(nil) })
            PackCountTabs(
                tabs: PackStage.allCases.map { ($0, $0.title, s.count($0)) },
                selected: s.tab,
                loading: s.searching ? s.isLoading && s.orders.isEmpty : s.counts.isEmpty,
                onSelect: model.onTab
            )
            content(s, shown)
            if s.canLoadMore && !s.isLoading {
                PackLoadMoreRow(page: s.page, error: s.moreError, onMore: model.loadMore)
            }
            if s.isLoading && !s.orders.isEmpty {
                ProgressView().tint(CashStyle.green).frame(maxWidth: .infinity).frame(height: 40)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 12)
    }

    @ViewBuilder private func content(_ s: PackerOrdersUiState, _ shown: [PackOrderDto]) -> some View {
        if s.isLoading && s.orders.isEmpty {
            PackSkeletonCards(count: 4)
        } else if let error = s.error, s.orders.isEmpty {
            BillErrorState(message: error) { model.load() }
        } else if shown.isEmpty {
            BillEmptyState(
                title: emptyTitle(s.tab),
                message: s.date != nil || s.searching ? "Try another date or search." : "Orders assigned to you show up here.",
                icon: "shippingbox"
            )
        } else {
            ForEach(shown) { o in
                Button { onOpen(o.id) } label: { PackOrderCard(order: o) }.buttonStyle(.plain)
            }
        }
    }

    private func emptyTitle(_ tab: PackStage) -> String {
        switch tab {
        case .assigned: return "Nothing to pack"
        case .packing: return "Nothing in packing"
        case .packed: return "Nothing packed yet"
        }
    }
}
