import SwiftUI
import SafariServices

struct WebsiteSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor.black
        return controller
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) { }
}

struct WebsiteDestination: Identifiable {
    let id = UUID()
    let url: URL
}

struct DoppelLogo: View {
    var size: CGFloat = 24
    var body: some View {
        Text("doppel")
            .font(.system(size: size, weight: .black, design: .rounded))
            .tracking(-1.9)
            .foregroundStyle(DoppelTheme.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

struct PillSearch: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                Text("Search products or paste a link")
                    .font(.system(size: 14))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 17))
            }
            .foregroundStyle(DoppelTheme.secondary)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(DoppelTheme.stroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }
}

struct SearchChip: View {
    let item: QuickSearch
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(DoppelTheme.surface).frame(width: 67, height: 67)
                    Image(systemName: resolvedIcon)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(DoppelTheme.ink)
                }
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DoppelTheme.ink)
            }
            .frame(width: 75)
        }
        .buttonStyle(.plain)
    }
    private var resolvedIcon: String {
        switch item.icon {
        case "shoe": "figure.walk"
        case "pants": "square.grid.2x2"
        case "jacket": "wind"
        case "sunglasses": "eyeglasses"
        default: item.icon
        }
    }
}

struct ItemCard: View {
    let item: DoppelProduct
    let saved: Bool
    let onTap: () -> Void
    let onSave: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Button(action: onTap) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DoppelTheme.surface)
                    if let url = item.imageURL {
                        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.18))) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .empty:
                                ProgressView().tint(DoppelTheme.secondary)
                            case .failure:
                                Image(systemName: "photo").font(.title).foregroundStyle(DoppelTheme.secondary)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 205)
                        .clipped()
                    } else {
                        Image(systemName: "shippingbox")
                            .font(.title)
                            .foregroundStyle(DoppelTheme.secondary)
                    }
                }
                .frame(height: 205)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if let qc = item.qcCount {
                        Label("\(qc)", systemImage: "photo.on.rectangle")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(7)
                            .background(.black.opacity(0.66), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(9)
                    }
                }
            }
            .buttonStyle(.plain)
            HStack(alignment: .top, spacing: 6) {
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(DoppelTheme.ink)
                        Text(item.price?.isEmpty == false ? item.price! : item.market)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DoppelTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                Button(action: onSave) {
                    Image(systemName: saved ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundStyle(saved ? .red : DoppelTheme.ink)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(saved ? "Remove from saved" : "Save product")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct ItemGrid: View {
    let products: [DoppelProduct]
    @ObservedObject var store: DoppelStore
    @Binding var selectedItem: DoppelProduct?
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 22) {
            ForEach(products) { item in
                ItemCard(item: item, saved: store.isSaved(item), onTap: { selectedItem = item }, onSave: {
                    withAnimation(.easeInOut(duration: 0.18)) { store.toggleSaved(item) }
                })
            }
        }
    }
}

struct LoadingProducts: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 20) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 16).fill(DoppelTheme.surface).frame(height: 205)
                    RoundedRectangle(cornerRadius: 4).fill(DoppelTheme.surface).frame(height: 13)
                    RoundedRectangle(cornerRadius: 4).fill(DoppelTheme.surface).frame(width: 95, height: 11)
                }
            }
        }
        .accessibilityLabel("Loading catalog")
    }
}

struct CatalogMessage: View {
    let status: String?
    let refresh: () -> Void
    let openWebsite: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 26, weight: .light))
            Text("Live catalog unavailable")
                .font(.system(size: 18, weight: .semibold))
            Text(status ?? "The website has not returned product data yet. Try again, or open the original website.")
                .font(.system(size: 13))
                .foregroundStyle(DoppelTheme.secondary)
            HStack(spacing: 10) {
                Button("Retry", action: refresh)
                    .buttonStyle(.borderedProminent)
                    .tint(DoppelTheme.ink)
                Button("Open website", action: openWebsite)
                    .buttonStyle(.bordered)
                    .tint(DoppelTheme.ink)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DoppelTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}
