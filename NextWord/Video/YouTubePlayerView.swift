import SwiftUI
import WebKit

// Play the curated YouTube video using the same embedded player tested earlier.
struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    @Binding var status: VideoPlayerStatus
    @Binding var currentTime: Double
    @Binding var syncStatus: String

    func makeCoordinator() -> Coordinator {
        Coordinator(status: $status, currentTime: $currentTime, syncStatus: $syncStatus)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        configuration.userContentController.add(context.coordinator, name: "playbackTime")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        // Prevent iOS safe-area insets from shifting the web content down or sideways.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.isOpaque = false
        webView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedVideoID != videoID else { return }
        var components = URLComponents(string: "https://www.youtube.com/embed/\(videoID)")!
        guard let bundleIdentifier = Bundle.main.bundleIdentifier?.lowercased(),
              let baseURL = URL(string: "https://\(bundleIdentifier)/") else {
            status = .failed("Could not form the player request.")
            return
        }
        // YouTube's origin parameter is an origin, not a URL path with a trailing slash.
        let origin = "https://\(bundleIdentifier)"
        components.queryItems = [
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "origin", value: origin)
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
        <body>
          <iframe id="player" src="\(url.absoluteString)" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen referrerpolicy="origin"></iframe>
          <script>
            function report(value) {
              window.webkit.messageHandlers.playbackTime.postMessage(value);
            }
            report('Web bridge ready');
            var player;
            function onYouTubeIframeAPIReady() {
              report('YouTube API loaded');
              player = new YT.Player('player', {
                events: {
                  onReady: function() { report('YouTube player ready'); },
                  onError: function(event) { report('YouTube error ' + event.data); }
                }
              });
            }
            function sendPlaybackTime() {
              if (!player || typeof player.getCurrentTime !== 'function') return;
              var seconds = player.getCurrentTime();
              if (Number.isFinite(seconds)) {
                report(seconds);
              }
            }
            setInterval(sendPlaybackTime, 250);
            var script = document.createElement('script');
            script.src = 'https://www.youtube.com/iframe_api';
            script.onerror = function() { report('YouTube API script failed'); };
            document.head.appendChild(script);
          </script>
        </body>
        </html>
        """
        context.coordinator.loadedVideoID = videoID
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var loadedVideoID: String?
        private let status: Binding<VideoPlayerStatus>
        private let currentTime: Binding<Double>
        private let syncStatus: Binding<String>

        init(status: Binding<VideoPlayerStatus>, currentTime: Binding<Double>, syncStatus: Binding<String>) {
            self.status = status
            self.currentTime = currentTime
            self.syncStatus = syncStatus
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "playbackTime", message.frameInfo.isMainFrame else { return }
            if let phase = message.body as? String {
                syncStatus.wrappedValue = phase
                return
            }
            guard let seconds = message.body as? NSNumber else { return }
            currentTime.wrappedValue = seconds.doubleValue
            syncStatus.wrappedValue = "Clock connected"
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
