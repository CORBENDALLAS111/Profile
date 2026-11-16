import Foundation
import WebKit
import SwiftUI

// Reads the public website DOM in a browser context. This is deliberately NOT
// presented as an API: markup and bot checks can change at any time.
final class DoppelSiteBridge: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let webView: WKWebView
    var onProducts: (([DoppelProduct], String) -> Void)?
    var onStatus: ((String?) -> Void)?

    override init() {
        let controller = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController = controller
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        controller.add(self, name: "doppelCatalog")
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.customUserAgent = nil
    }

    func load(search: String?) {
        var components = URLComponents(string: "https://doppel.fit/")!
        let term = (search ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !term.isEmpty {
            components.queryItems = [URLQueryItem(name: "search", value: term)]
        }
        guard let url = components.url else { return }
        webView.load(URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript(Self.extractionScript) { _, error in
            if let error = error {
                self.onStatus?("Cannot read the live catalog: \(error.localizedDescription)")
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onStatus?("Website connection failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onStatus?("Website unavailable: \(error.localizedDescription)")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let payload = message.body as? [String: Any] else { return }
        if let status = payload["status"] as? String, status == "blocked" {
            onStatus?("The website requires a human verification. Open the website to continue.")
            return
        }
        guard let records = payload["products"] as? [[String: Any]],
              let page = payload["page"] as? String else { return }
        var unique = Set<String>()
        let parsed: [DoppelProduct] = records.compactMap { item in
            guard let href = item["href"] as? String,
                  let url = URL(string: href),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  let name = item["name"] as? String,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let id = url.absoluteString
            guard unique.insert(id).inserted else { return nil }
            let img = (item["image"] as? String).flatMap(URL.init(string:))
            let price = item["price"] as? String
            let seller = item["seller"] as? String
            let source = item["source"] as? String
            let count = item["qc"] as? Int
            return DoppelProduct(id: id, name: name, imageURL: img, pageURL: url, price: price, seller: seller, source: source, qcCount: count)
        }
        onProducts?(parsed, page)
    }

    private static let extractionScript = #"""
    (() => {
       if (window.__doppelNativeReaderInstalled) { window.__doppelNativeSend?.(); return; }
       window.__doppelNativeReaderInstalled = true;
       const absolute = (value) => { try { return new URL(value, document.baseURI).href; } catch (_) { return ''; } };
       let timer;
       const read = () => {
         const body = (document.body?.innerText || '').slice(0, 500).toLowerCase();
         if (document.title.toLowerCase().includes('just a moment') || body.includes('verify you are human') || body.includes('checking your browser')) {
           window.webkit.messageHandlers.doppelCatalog.postMessage({ status: 'blocked' });
           return;
         }
         const items = [];
         const seen = new Set();
         const anchors = Array.from(document.querySelectorAll('a[href]'));
         for (const anchor of anchors) {
           const img = anchor.querySelector('img') || (anchor.closest('article') || anchor.parentElement)?.querySelector('img');
           if (!img) continue;
           const source = img.currentSrc || img.getAttribute('data-src') || img.getAttribute('src') || '';
           if (!source || source.startsWith('data:') || source.endsWith('.svg')) continue;
           if (img.naturalWidth && img.naturalWidth < 70) continue;
           const href = absolute(anchor.getAttribute('href'));
           if (!href || seen.has(href) || href === location.origin + '/' || href.startsWith('javascript:')) continue;
           const parent = anchor.closest('article, li, [class*=card], [class*=Card], [class*=product], [class*=Product]') || anchor;
           const heading = parent.querySelector('h2, h3, h4, [class*=title], [class*=Title]');
           let name = ((heading?.textContent || img.getAttribute('alt') || anchor.getAttribute('aria-label') || anchor.textContent || '').trim()).replace(/\s+/g, ' ').slice(0, 125);
           if (!name || name.length < 3) continue;
           const description = (parent.innerText || '').replace(/\s+/g, ' ').slice(0, 500);
           const priceMatch = description.match(/(?:€|\$|£|¥)\s*\d+(?:[.,]\d{1,2})?/);
           const qcMatch = description.match(/(\d+)\s*(?:QC|photos?|pics?)/i);
           const image = absolute(source);
           if (!image || !image.startsWith('http')) continue;
           seen.add(href);
           items.push({href, name, image, price:priceMatch?.[0] || '', qc:qcMatch ? Number(qcMatch[1]) : null, seller:'', source:''});
         }
         window.webkit.messageHandlers.doppelCatalog.postMessage({products: items.slice(0, 150), page: location.href});
       };
       window.__doppelNativeSend = read;
       const schedule = () => { clearTimeout(timer); timer = setTimeout(read, 600); };
       new MutationObserver(schedule).observe(document.documentElement, { childList:true, subtree:true });
       [350, 1200, 2500, 5000, 9000].forEach(delay => setTimeout(read, delay));
    })();
    """#
}

struct HiddenSiteLoader: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}
