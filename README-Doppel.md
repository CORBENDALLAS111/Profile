# Doppel Native iPhone (unofficial)

Native SwiftUI iOS 17+ prototype. Uses native Discover, Search, Saved, More, product detail sheets, horizontal categories, LazyVGrid cards, platform filtering, sorting, pull-to-refresh and local favorite persistence.

## Website integration
The embedded offscreen WebKit reader navigates https://doppel.fit/ and https://doppel.fit/?search=<query>, extracting publicly visible product cards to display in native SwiftUI. This is not an official or documented API. Cloudflare verification, anti-bot restrictions or site markup changes can interrupt catalog loading. In that case the interface offers Open website. Full QC galleries, sellers, image search and spreadsheet converter still use the original website via in-app Safari.

No fake catalog inventory and no account credentials are bundled. This is an independent, unofficial iPhone client, not endorsed by the Doppel site.

## Build on a Mac
Install Xcode 16.4+ and XcodeGen: brew install xcodegen
Run xcodegen generate, open DoppelNative.xcodeproj and configure your own Apple Developer Team for signing.

## Build IPA with GitHub Actions
The workflow .github/workflows/build-ipa.yml runs on macos-15, uses Xcode 16.4, generates the project, builds for iphoneos, and uploads DoppelNative-unsigned.ipa as a GitHub artifact.

The artifact is **unsigned**. It is not directly installable on a standard iPhone unless appropriately signed (e.g. with a development or distribution certificate and a provisioning profile, or your compatible sideloading workflow).

## Limitations
Full feature parity and pixel-perfect matching are not claimed. This is a functional native client scaffold, dependent on the live website and pending validation on an actual iPhone. The site blocks automated inspection with HTTP 403; public API endpoints have not been verified.
