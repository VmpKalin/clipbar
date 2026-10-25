import SwiftData
import SwiftUI

struct SideMenuView: View {
    @Binding var selection: ClipSection
    @Binding var showSettings: Bool
    /// Non-nil on iPhone where the menu is a drawer.
    var dismissMenu: (() -> Void)?

    @Query private var items: [ClipItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(ClipSection.allCases) { section in
                        row(section)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
            }
            Divider().padding(.horizontal, 14)
            Button {
                showSettings = true
                dismissMenu?()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
        .modifier(DrawerChrome(isDrawer: dismissMenu != nil))
    }

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("ClipBar").font(.title2.bold())
            Spacer()
            if dismissMenu != nil {
                Button { dismissMenu?() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .padding(8)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private func row(_ section: ClipSection) -> some View {
        let count = items.count(where: { section.includes($0) })
        let selected = section == selection
        return Button {
            selection = section
            dismissMenu?()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: section.systemImage)
                    .frame(width: 22)
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                Text(section.title)
                Spacer()
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(selected ? Color.accentColor.opacity(0.14) : .clear, in: .rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Glass panel on iPhone; plain sidebar background elsewhere.
private struct DrawerChrome: ViewModifier {
    let isDrawer: Bool
    func body(content: Content) -> some View {
        if isDrawer {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 6)
        } else {
            content
        }
    }
}
