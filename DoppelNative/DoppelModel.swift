import Foundation
import SwiftUI

struct DoppelProduct: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let imageURL: URL?
    let pageURL: URL
    let price: String?
    let seller: String?
    let source: String?
    let qcCount: Int?

    var market: String {
        let text = "\(pageURL.absoluteString) \(source ?? "")".lowercased()
        if text.contains("weidian") || text.contains("weidian.com") { return "Weidian" }
        if text.contains("1688") { return "1688" }
        if text.contains("taobao") || text.contains("tmall") { return "Taobao" }
        return "Other"
    }
}

enum DoppelTheme {
    static let ink = Color(red: 0.08, green: 0.09, blue: 0.11)
    static let secondary = Color(red: 0.45, green: 0.47, blue: 0.50)
    static let canvas = Color(red: 0.985, green: 0.986, blue: 0.988)
    static let surface = Color(red: 0.944, green: 0.95, blue: 0.954)
    static let stroke = Color(red: 0.89, green: 0.90, blue: 0.92)
}

struct QuickSearch: Identifiable {
    var id: String { query }
    let title: String
    let query: String
    let icon: String
}

let quickSearches: [QuickSearch] = [
    .init(title: "Popular", query: "popular", icon: "flame"),
    .init(title: "Shoes", query: "shoes", icon: "shoe"),
    .init(title: "Tops", query: "tops", icon: "tshirt"),
    .init(title: "Bottoms", query: "pants", icon: "square.split.2x2"),
    .init(title: "Outerwear", query: "jacket", icon: "wind"),
    .init(title: "Bags", query: "bags", icon: "bag"),
    .init(title: "Watches", query: "watches", icon: "clock"),
    .init(title: "Accessories", query: "accessories", icon: "sunglasses")
]
