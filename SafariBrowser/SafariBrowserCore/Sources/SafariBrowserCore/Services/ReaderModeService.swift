import Foundation

public struct ReaderArticle: Sendable, Equatable, Identifiable {
    public var id: String { title + (sourceURL?.absoluteString ?? "") }
    public let title: String
    public let contentHTML: String
    public let byline: String?
    public let sourceURL: URL?

    public init(title: String, contentHTML: String, byline: String?, sourceURL: URL?) {
        self.title = title
        self.contentHTML = contentHTML
        self.byline = byline
        self.sourceURL = sourceURL
    }
}

public enum ReaderModeService {
    public static let extractionScript = """
    (function() {
        function text(el) { return (el && el.textContent || '').trim(); }
        var title = document.title || '';
        var byline = '';
        var authorMeta = document.querySelector('meta[name="author"]');
        if (authorMeta) byline = authorMeta.content;

        var candidates = document.querySelectorAll('article, main, [role="main"], .post, .article, .entry-content, #content');
        var best = null, bestScore = 0;
        if (candidates.length === 0) candidates = document.querySelectorAll('p').length > 3 ? [document.body] : [];

        candidates.forEach(function(el) {
            var paragraphs = el.querySelectorAll('p').length;
            var score = paragraphs * 10 + text(el).length / 100;
            if (score > bestScore) { bestScore = score; best = el; }
        });

        if (!best) best = document.body;
        return JSON.stringify({
            title: title,
            byline: byline,
            contentHTML: best.innerHTML
        });
    })();
    """

    public static func parse(json: String, sourceURL: URL?) -> ReaderArticle? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let content = dict["contentHTML"], !content.isEmpty else { return nil }
        return ReaderArticle(
            title: dict["title"] ?? "Article",
            contentHTML: sanitizeHTML(content),
            byline: dict["byline"],
            sourceURL: sourceURL
        )
    }

    /// Strip dangerous tags and inline handlers before rendering reader HTML.
    public static func sanitizeHTML(_ html: String) -> String {
        var sanitized = html
        let dangerousPatterns = [
            "<script[^>]*>[\\s\\S]*?</script>",
            "<iframe[^>]*>[\\s\\S]*?</iframe>",
            "<object[^>]*>[\\s\\S]*?</object>",
            "<embed[^>]*>",
            "<form[^>]*>[\\s\\S]*?</form>",
            "on\\w+\\s*=\\s*\"[^\"]*\"",
            "on\\w+\\s*=\\s*'[^']*'",
            "javascript:"
        ]
        for pattern in dangerousPatterns {
            sanitized = sanitized.replacingOccurrences(
                of: pattern,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return sanitized
    }
}
