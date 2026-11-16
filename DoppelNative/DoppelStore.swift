import Foundation
import SwiftUI

@MainActor
final class DoppelStore: ObservableObject {
    @Published private(set) var products: [DoppelProduct] = []
    @Published private(set) var saved: [DoppelProduct] = []
    @Published var isLoading = false
    @Published var status: String?
    @Published var currentSearch = ""

    let bridge = DoppelSiteBridge()
    private let savedKey = "doppelNative.savedProducts.v1"
    private var activeURL = "https://doppel.fit/"

    init() {
        if let raw = UserDefaults.standard.data(forKey: savedKey),
           let decoded = try? JSONDecoder().decode([DoppelProduct].self, from: raw) {
            saved = decoded
        }
        bridge.onProducts = { [weak self] products, url in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.matchesCurrentSearch(url) else { return }
                self.products = products
                self.isLoading = false
                if !products.isEmpty { self.status = nil }
                else if self.status == nil { self.status = "No product cards were detected. The website may have changed its layout." }
            }
        }
        bridge.onStatus = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.status = message
                self?.isLoading = false
            }
        }
    }

    func load(search: String = "") {
        currentSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents(string: "https://doppel.fit/")!
        if !currentSearch.isEmpty { components.queryItems = [URLQueryItem(name: "search", value: currentSearch)] }
        activeURL = components.url?.absoluteString ?? "https://doppel.fit/"
        products = []
        status = nil
        isLoading = true
        bridge.load(search: currentSearch)
    }

    private func matchesCurrentSearch(_ urlString: String) -> Bool {
        guard let received = URLComponents(string: urlString),
              let current = URLComponents(string: activeURL) else { return false }
        let receivedTerm = received.queryItems?.first(where: { $0.name == "search" })?.value ?? ""
        let currentTerm = current.queryItems?.first(where: { $0.name == "search" })?.value ?? ""
        return received.host == current.host && receivedTerm == currentTerm
    }

    var currentURL: URL { URL(string: activeURL)! }

    func isSaved(_ item: DoppelProduct) -> Bool { saved.contains(where: { $0.id == item.id }) }

    func toggleSaved(_ item: DoppelProduct) {
        if let index = saved.firstIndex(where: { $0.id == item.id }) { saved.remove(at: index) }
        else { saved.insert(item, at: 0) }
        if let value = try? JSONEncoder().encode(saved) { UserDefaults.standard.set(value, forKey: savedKey) }
    }
}
