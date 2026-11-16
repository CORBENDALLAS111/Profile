import SwiftUI

private enum AppTab: Hashable { case discover, search, saved, more }

@main
struct DoppelNativeApp: App {
    var body: some Scene { WindowGroup { DoppelRootView() } }
}

struct DoppelRootView: View {
    @StateObject private var store = DoppelStore()
    @State private var tab: AppTab = .discover
    @State private var selectedItem: DoppelProduct?
    @State private var website: WebsiteDestination?
    @State private var didLoad = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            TabView(selection: $tab) {
                DiscoverScreen(store: store, onSearch: { search in
                    if let search { store.load(search: search) }
                    tab = .search
                }, open: open, selectedItem: $selectedItem)
                .tabItem { Label("Discover", systemImage: "square.grid.2x2") }
                .tag(AppTab.discover)

                SearchScreen(store: store, open: open, selectedItem: $selectedItem)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)

                SavedScreen(store: store, selectedItem: $selectedItem)
                .tabItem { Label("Saved", systemImage: "heart") }
                .tag(AppTab.saved)

                MoreScreen(open: open)
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
                .tag(AppTab.more)
            }
            .tint(DoppelTheme.ink)
            HiddenSiteLoader(webView: store.bridge.webView)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(DoppelTheme.canvas.ignoresSafeArea())
        .sheet(item: $selectedItem) { item in
            ProductScreen(item: item, store: store, open: open)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $website) { item in
            WebsiteSheet(url: item.url).ignoresSafeArea()
        }
        .onAppear { if !didLoad { didLoad = true; store.load() } }
    }

    private func open(_ url: URL) { website = WebsiteDestination(url: url) }
}

private struct DiscoverScreen: View {
    @ObservedObject var store: DoppelStore
    let onSearch: (String?) -> Void
    let open: (URL) -> Void
    @Binding var selectedItem: DoppelProduct?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 29) {
                HStack {
                    DoppelLogo(size: 25)
                    Spacer()
                    Button { open(URL(string: "https://doppel.fit/")!) } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 20))
                            .foregroundStyle(DoppelTheme.ink)
                    }
                    .accessibilityLabel("Open website")
                }
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 18) {
                    Text("Discover more.\nPay less.")
                        .font(.system(size: 43, weight: .bold))
                        .tracking(-2.2)
                        .foregroundStyle(DoppelTheme.ink)
                        .minimumScaleFactor(0.75)
                    PillSearch { onSearch(nil) }
                }
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 16) {
                    SectionTitle(title: "Explore", actionTitle: "Browse all") { onSearch(nil) }
                    ScrollView(.horizontal) {
                        HStack(spacing: 9) {
                            ForEach(quickSearches) { category in
                                SearchChip(item: category) { onSearch(category.query) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollIndicators(.hidden)
                }

                VStack(alignment: .leading, spacing: 17) {
                    SectionTitle(title: store.currentSearch.isEmpty ? "Discover products" : "Results: \(store.currentSearch)", actionTitle: "See all") { onSearch(nil) }
                    if store.isLoading {
                        LoadingProducts()
                    } else if !store.products.isEmpty {
                        ItemGrid(products: Array(store.products.prefix(20)), store: store, selectedItem: $selectedItem)
                    } else {
                        CatalogMessage(status: store.status, refresh: { store.load(search: store.currentSearch) }, openWebsite: { open(store.currentURL) })
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quality check gallery")
                        .font(.system(size: 20, weight: .bold))
                    Text("Inspect warehouse QC photos and seller details on Doppel.")
                        .font(.system(size: 14))
                        .foregroundStyle(DoppelTheme.secondary)
                    Button("Browse photos on Doppel") { open(URL(string: "https://doppel.fit/")!) }
                        .font(.system(size: 14, weight: .semibold))
                        .tint(DoppelTheme.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(DoppelTheme.surface, in: RoundedRectangle(cornerRadius: 19))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(DoppelTheme.canvas)
        .refreshable { store.load(search: store.currentSearch) }
    }
}

private struct SectionTitle: View {
    let title: String
    let actionTitle: String
    let action: () -> Void
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(DoppelTheme.ink)
                .lineLimit(1)
            Spacer()
            Button(action: action) {
                HStack(spacing: 4) {
                    Text(actionTitle)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DoppelTheme.secondary)
            }
        }
    }
}

private enum SortOption: String, CaseIterable, Identifiable {
    case relevant = "Relevant", alphabetical = "Name A–Z", priceLow = "Price: low first"
    var id: String { rawValue }
}

private struct SearchScreen: View {
    @ObservedObject var store: DoppelStore
    let open: (URL) -> Void
    @Binding var selectedItem: DoppelProduct?
    @State private var query = ""
    @State private var marketplace = "All"
    @State private var sort = SortOption.relevant
    @FocusState private var searchFocused: Bool

    private var filtered: [DoppelProduct] {
        let base = marketplace == "All" ? store.products : store.products.filter { $0.market == marketplace }
        switch sort {
        case .relevant: return base
        case .alphabetical: return base.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .priceLow:
            return base.sorted { numericPrice($0.price) < numericPrice($1.price) }
        }
    }
    private func numericPrice(_ text: String?) -> Double {
        guard let text else { return Double.greatestFiniteMagnitude }
        let number = text.filter { "0123456789.,".contains($0) }.replacingOccurrences(of: ",", with: ".")
        return Double(number) ?? Double.greatestFiniteMagnitude
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Search")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-1)
                Spacer()
                Button { open(store.currentURL) } label: {
                    Image(systemName: "safari").font(.system(size: 20))
                }
                .accessibilityLabel("Open search on website")
            }
            .padding(.top, 18)
            .padding(.bottom, 19)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DoppelTheme.secondary)
                TextField("Item, brand or Taobao link", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { submit() }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DoppelTheme.secondary)
                    }
                }
                Button { open(URL(string: "https://doppel.fit/")!) } label: {
                    Image(systemName: "photo.on.rectangle")
                }
                .accessibilityLabel("Image search on website")
            }
            .font(.system(size: 15))
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(.white, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(DoppelTheme.stroke))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScrollView(.horizontal) {
                        HStack(spacing: 7) {
                            ForEach(quickSearches) { category in
                                Button(category.title) {
                                    query = category.query
                                    submit()
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 10)
                                .background(DoppelTheme.surface, in: Capsule())
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    HStack(spacing: 8) {
                        Menu {
                            ForEach(["All", "Taobao", "1688", "Weidian", "Other"], id: \.self) { platform in
                                Button(platform) { marketplace = platform }
                            }
                        } label: {
                            FilterTag(icon: "slider.horizontal.3", text: marketplace == "All" ? "Platform" : marketplace)
                        }
                        Menu {
                            ForEach(SortOption.allCases) { option in
                                Button(option.rawValue) { sort = option }
                            }
                        } label: {
                            FilterTag(icon: "arrow.up.arrow.down", text: sort == .relevant ? "Sort" : sort.rawValue)
                        }
                        Spacer()
                        Text("\(filtered.count) items")
                            .font(.system(size: 12))
                            .foregroundStyle(DoppelTheme.secondary)
                    }

                    if store.isLoading {
                        LoadingProducts()
                    } else if !filtered.isEmpty {
                        ItemGrid(products: filtered, store: store, selectedItem: $selectedItem)
                    } else if !store.products.isEmpty {
                        ContentUnavailableView("No matches for filter", systemImage: "line.3.horizontal.decrease.circle")
                    } else {
                        CatalogMessage(status: store.status, refresh: submit, openWebsite: { open(store.currentURL) })
                    }
                }
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .refreshable { submit() }
        }
        .padding(.horizontal, 20)
        .foregroundStyle(DoppelTheme.ink)
        .background(DoppelTheme.canvas)
        .onAppear { query = store.currentSearch }
        .onChange(of: store.currentSearch) { _, newValue in query = newValue }
    }

    private func submit() {
        searchFocused = false
        marketplace = "All"
        store.load(search: query)
    }
}

private struct FilterTag: View {
    let icon: String
    let text: String
    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(DoppelTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(DoppelTheme.stroke))
    }
}

private struct SavedScreen: View {
    @ObservedObject var store: DoppelStore
    @Binding var selectedItem: DoppelProduct?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Text("Saved items").font(.system(size: 32, weight: .bold)).padding(.top, 20)
                Text("Your shortlist stays on this iPhone.")
                    .font(.system(size: 14))
                    .foregroundStyle(DoppelTheme.secondary)
                if store.saved.isEmpty {
                    ContentUnavailableView("Nothing saved yet", systemImage: "heart", description: Text("Tap the heart on a product to save it here."))
                        .padding(.top, 40)
                } else {
                    ItemGrid(products: store.saved, store: store, selectedItem: $selectedItem)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(DoppelTheme.canvas)
    }
}

private struct MoreScreen: View {
    let open: (URL) -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                DoppelLogo(size: 32).padding(.top, 20)
                Text("Discovery tools")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-1)
                VStack(spacing: 0) {
                    ToolRow(title: "QC finder", subtitle: "Warehouse inspection photos", icon: "photo.stack") {
                        open(URL(string: "https://doppel.fit/")!)
                    }
                    Divider()
                    ToolRow(title: "Spreadsheet converter", subtitle: "Use the original website", icon: "tablecells") {
                        open(URL(string: "https://doppel.fit/")!)
                    }
                    Divider()
                    ToolRow(title: "Sellers and marketplaces", subtitle: "Taobao · 1688 · Weidian", icon: "shippingbox") {
                        open(URL(string: "https://doppel.fit/")!)
                    }
                    Divider()
                    ToolRow(title: "Official usage guide", subtitle: "Learn about QC photos", icon: "text.book.closed") {
                        open(URL(string: "https://blog.doppel.fit/the-complete-guide-to-using-doppel-fit/")!)
                    }
                }
                .padding(.horizontal, 16)
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
                Text("Independent native iPhone client. Not affiliated with Doppel. Product availability, authentication, full QC galleries and spreadsheet tools depend on the original website. Native catalog reading may require human verification.")
                    .font(.system(size: 12))
                    .foregroundStyle(DoppelTheme.secondary)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(DoppelTheme.canvas)
    }
}

private struct ToolRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .light))
                    .frame(width: 38, height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(DoppelTheme.secondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(DoppelTheme.secondary)
            }
            .foregroundStyle(DoppelTheme.ink)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

private struct ProductScreen: View {
    let item: DoppelProduct
    @ObservedObject var store: DoppelStore
    let open: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var website: WebsiteDestination?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15))
                            .frame(width: 36, height: 36)
                            .background(DoppelTheme.surface, in: Circle())
                    }
                    Spacer()
                    DoppelLogo(size: 21)
                    Spacer()
                    Button { store.toggleSaved(item) } label: {
                        Image(systemName: store.isSaved(item) ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .frame(width: 36, height: 36)
                    }
                }
                .foregroundStyle(DoppelTheme.ink)
                .padding(.top, 13)

                ZStack {
                    RoundedRectangle(cornerRadius: 22).fill(DoppelTheme.surface)
                    if let url = item.imageURL {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFit()
                            } else if phase.error != nil {
                                Image(systemName: "photo").font(.largeTitle)
                            } else {
                                ProgressView()
                            }
                        }
                    }
                }
                .frame(height: 325)
                .clipShape(RoundedRectangle(cornerRadius: 22))

                Text(item.name)
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-0.6)
                if let price = item.price, !price.isEmpty {
                    Text(price).font(.system(size: 20, weight: .semibold))
                }
                Label(item.market, systemImage: "shippingbox")
                    .font(.system(size: 13))
                    .foregroundStyle(DoppelTheme.secondary)
                Text("Original listing and QC photos")
                    .font(.system(size: 16, weight: .semibold))
                Text("See the full inspection gallery, product information and seller details on the original website.")
                    .font(.system(size: 13))
                    .foregroundStyle(DoppelTheme.secondary)
                Button { website = WebsiteDestination(url: item.pageURL) } label: {
                    HStack {
                        Label("View on Doppel", systemImage: "photo.stack")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(height: 55)
                    .foregroundStyle(.white)
                    .background(DoppelTheme.ink, in: RoundedRectangle(cornerRadius: 15))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(DoppelTheme.canvas)
        .sheet(item: $website) { item in WebsiteSheet(url: item.url).ignoresSafeArea() }
    }
}
