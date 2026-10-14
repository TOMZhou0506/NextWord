import SwiftUI
import WebKit

// Play the curated YouTube video using the same embedded player tested earlier.
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @Binding var status: VideoPlayerStatus

    func makeCoordinator() -> Coordinator {
        Coordinator(status: $status)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedVideoID != videoID else { return }
        var components = URLComponents(string: "https://www.youtube.com/embed/\(videoID)")!
        guard let bundleIdentifier = Bundle.main.bundleIdentifier?.lowercased(),
              let origin = URL(string: "https://\(bundleIdentifier)/") else {
            status = .failed("Could not form the player request.")
            return
        }
        components.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "origin", value: origin.absoluteString)
        ]
        guard let url = components.url else {
            status = .failed("Could not form the player request.")
            return
        }

        // Give the iframe a responsive viewport instead of loading the embed page directly.
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <style>
            html, body { margin: 0; width: 100%; height: 100%; overflow: hidden; background: black; }
            iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; }
          </style>
        </head>
        <body><iframe src="\(url.absoluteString)" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen referrerpolicy="origin"></iframe></body>
        </html>
        """
        context.coordinator.loadedVideoID = videoID
        webView.loadHTMLString(html, baseURL: origin)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedVideoID: String?
        private let status: Binding<VideoPlayerStatus>

        init(status: Binding<VideoPlayerStatus>) {
            self.status = status
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            status.wrappedValue = .pageLoaded
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            status.wrappedValue = .failed(error.localizedDescription)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            status.wrappedValue = .failed(error.localizedDescription)
        }
    }
}

enum VideoPlayerStatus {
    case loading
    case pageLoaded
    case failed(String)

    var message: String {
        switch self {
        case .loading: "Loading the YouTube player…"
        case .pageLoaded: "Player loaded. Tap Play to confirm playback."
        case .failed(let reason): "Player error: \(reason)"
        }
    }

    var colour: Color {
        switch self {
        case .loading: .secondary
        case .pageLoaded: .green
        case .failed: .red
        }
    }
}
