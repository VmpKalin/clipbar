import Contacts
import Foundation
import Observation

/// A contact flattened into copyable fields.
struct ContactCard: Identifiable, Sendable, Hashable {
    struct Field: Identifiable, Sendable, Hashable {
        enum Kind: String, Sendable { case phone, email, address, url, organization, birthday }
        let id: String
        let kind: Kind
        let label: String
        let value: String

        var systemImage: String {
            switch kind {
            case .phone: "phone"
            case .email: "envelope"
            case .address: "map"
            case .url: "link"
            case .organization: "building.2"
            case .birthday: "gift"
            }
        }
    }

    let id: String
    let name: String
    let organization: String
    let thumbnail: Data?
    let fields: [Field]

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.compactMap(\.first).map(String.init).joined()
        return s.isEmpty ? "?" : s.uppercased()
    }
}

/// Searches the system Contacts database.
@MainActor
@Observable
final class ContactsProvider {
    enum Access { case unknown, granted, denied }

    private(set) var access: Access = ContactsProvider.currentAccess()
    private(set) var cards: [ContactCard] = []
    private(set) var isLoading = false
    private var loadTask: Task<Void, Never>?
    private var cachedAll: [ContactCard]?

    static func currentAccess() -> Access {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized, .limited: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .unknown
        @unknown default: .unknown
        }
    }

    func requestAccess() async {
        let granted = (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
        access = granted ? .granted : .denied
        if granted { reload() }
    }

    func refreshAccess() { access = Self.currentAccess() }

    /// Loads all contacts once (cached), then filters locally.
    func reload() {
        guard access == .granted else { return }
        loadTask?.cancel()
        isLoading = true
        loadTask = Task {
            let all = await Task.detached(priority: .userInitiated) { Self.fetchAll() }.value
            guard !Task.isCancelled else { return }
            cachedAll = all
            cards = all
            isLoading = false
        }
    }

    func search(_ query: String, limit: Int = 200) -> [ContactCard] {
        guard access == .granted else { return [] }
        if cachedAll == nil && !isLoading { reload() }
        let all = cachedAll ?? []
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Array(all.prefix(limit)) }
        return all
            .compactMap { card -> (ContactCard, Int)? in
                let fields = [card.name, card.organization] + card.fields.map(\.value)
                return SearchMatcher.score(q, fields: fields).map { (card, $0) }
            }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    /// The user's own card ("Me" in Contacts), if any.
    func meCard() async -> ContactCard? {
        guard access == .granted else { return nil }
        return await Task.detached(priority: .userInitiated) {
            guard let contact = try? CNContactStore().unifiedMeContactWithKeys(toFetch: Self.keys) else { return nil }
            return Self.card(from: contact)
        }.value
    }

    // MARK: Fetching

    nonisolated static var keys: [CNKeyDescriptor] { [
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor,
        CNContactBirthdayKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor,
    ] }

    nonisolated static func fetchAll() -> [ContactCard] {
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .userDefault
        var result: [ContactCard] = []
        try? CNContactStore().enumerateContacts(with: request) { contact, _ in
            let card = card(from: contact)
            if !card.fields.isEmpty || !card.name.isEmpty { result.append(card) }
        }
        return result
    }

    nonisolated static func card(from contact: CNContact) -> ContactCard {
        var fields: [ContactCard.Field] = []
        func label(_ raw: String?) -> String {
            guard let raw else { return "" }
            return CNLabeledValue<NSString>.localizedString(forLabel: raw)
        }
        for (i, p) in contact.phoneNumbers.enumerated() {
            fields.append(.init(id: "\(contact.identifier)-p\(i)", kind: .phone, label: label(p.label), value: p.value.stringValue))
        }
        for (i, e) in contact.emailAddresses.enumerated() {
            fields.append(.init(id: "\(contact.identifier)-e\(i)", kind: .email, label: label(e.label), value: e.value as String))
        }
        let formatter = CNPostalAddressFormatter()
        for (i, a) in contact.postalAddresses.enumerated() {
            let value = formatter.string(from: a.value)
            fields.append(.init(id: "\(contact.identifier)-a\(i)", kind: .address, label: label(a.label), value: value))
        }
        for (i, u) in contact.urlAddresses.enumerated() {
            fields.append(.init(id: "\(contact.identifier)-u\(i)", kind: .url, label: label(u.label), value: u.value as String))
        }
        if let b = contact.birthday, let date = Calendar.current.date(from: b) {
            let f = DateFormatter()
            f.dateStyle = .long
            f.timeStyle = .none
            fields.append(.init(id: "\(contact.identifier)-b", kind: .birthday, label: "birthday", value: f.string(from: date)))
        }
        let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        return ContactCard(id: contact.identifier,
                           name: name.isEmpty ? contact.organizationName : name,
                           organization: contact.organizationName,
                           thumbnail: contact.thumbnailImageData,
                           fields: fields)
    }
}
