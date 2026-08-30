import WidgetKit
import SwiftUI

struct BookmarkEntry: TimelineEntry {
    let date: Date
    let title: String
    let urlString: String
}

struct SafariBrowserWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BookmarkEntry {
        BookmarkEntry(date: .now, title: "SafariBrowser", urlString: "https://apple.com")
    }

    func getSnapshot(in context: Context, completion: @escaping (BookmarkEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BookmarkEntry>) -> Void) {
        let entry = loadEntry()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
    }

    private func loadEntry() -> BookmarkEntry {
        let defaults = UserDefaults(suiteName: "group.com.safaribrowser.app")
        let title = defaults?.string(forKey: "widget.lastTitle") ?? "SafariBrowser"
        let url = defaults?.string(forKey: "widget.lastURL") ?? "https://apple.com"
        return BookmarkEntry(date: .now, title: title, urlString: url)
    }
}

struct SafariBrowserWidgetView: View {
    var entry: BookmarkEntry

    private var deepLinkURL: URL? {
        guard let encoded = entry.urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "safaribrowser://open?url=\(encoded)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "globe")
                Text("SafariBrowser")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)
            Text(entry.title)
                .font(.headline)
                .lineLimit(2)
            Text(entry.urlString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .widgetURL(deepLinkURL)
    }
}

@main
struct SafariBrowserWidget: Widget {
    let kind = "SafariBrowserWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SafariBrowserWidgetProvider()) { entry in
            SafariBrowserWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent Page")
        .description("Shows your most recently visited page.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
