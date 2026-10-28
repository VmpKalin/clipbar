import Foundation

/// Expands `{token}` placeholders in Library snippets at paste time.
///
/// Tokens: {date} {time} {datetime} {iso} {timestamp} {weekday} {year} {uuid}
/// {clipboard} {user} {fullname} {hostname} {home} and {date:<ICU format>}, e.g. {date:dd.MM.yyyy}.
public struct TemplateExpander: Sendable {
    public struct Context: Sendable {
        public var now: Date
        public var clipboard: String
        public var userName: String
        public var fullName: String
        public var hostName: String
        public var homePath: String
        public var locale: Locale
        public var timeZone: TimeZone

        public init(now: Date = .now, clipboard: String = "", userName: String = NSUserName(),
                    fullName: String = NSFullUserName(), hostName: String = ProcessInfo.processInfo.hostName,
                    homePath: String = NSHomeDirectory(), locale: Locale = .current, timeZone: TimeZone = .current) {
            self.now = now
            self.clipboard = clipboard
            self.userName = userName
            self.fullName = fullName
            self.hostName = hostName
            self.homePath = homePath
            self.locale = locale
            self.timeZone = timeZone
        }
    }

    public static let knownTokens = ["date", "time", "datetime", "iso", "timestamp", "weekday", "year", "uuid",
                                     "clipboard", "user", "fullname", "hostname", "home"]

    public init() {}

    public static func containsTokens(_ text: String) -> Bool {
        text.firstMatch(of: /\{([a-z]+)(?::[^}]*)?\}/) != nil
    }

    public func expand(_ template: String, context: Context = Context()) -> String {
        template.replacing(/\{([a-z]+)(?::([^}]*))?\}/) { match in
            let token = String(match.1)
            let argument = match.2.map(String.init)
            return value(for: token, argument: argument, context: context) ?? String(match.0)
        }
    }

    private func value(for token: String, argument: String?, context: Context) -> String? {
        func format(_ pattern: String) -> String {
            let f = DateFormatter()
            f.locale = context.locale
            f.timeZone = context.timeZone
            f.dateFormat = pattern
            return f.string(from: context.now)
        }
        func styled(date: DateFormatter.Style, time: DateFormatter.Style) -> String {
            let f = DateFormatter()
            f.locale = context.locale
            f.timeZone = context.timeZone
            f.dateStyle = date
            f.timeStyle = time
            return f.string(from: context.now)
        }
        switch token {
        case "date": return argument.map(format) ?? styled(date: .medium, time: .none)
        case "time": return argument.map(format) ?? styled(date: .none, time: .short)
        case "datetime": return styled(date: .medium, time: .short)
        case "iso":
            let f = ISO8601DateFormatter()
            f.timeZone = context.timeZone
            return f.string(from: context.now)
        case "timestamp": return String(Int(context.now.timeIntervalSince1970))
        case "weekday": return format("EEEE")
        case "year": return format("yyyy")
        case "uuid": return UUID().uuidString
        case "clipboard": return context.clipboard
        case "user": return context.userName
        case "fullname": return context.fullName
        case "hostname": return context.hostName
        case "home": return context.homePath
        default: return nil
        }
    }
}
