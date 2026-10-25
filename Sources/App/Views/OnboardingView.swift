import SwiftUI
#if os(iOS)
import UIKit
#endif

struct OnboardingView: View {
    @AppStorage("didOnboard") private var didOnboard = false

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.top, 36)
            Text("ClipBar").font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 18) {
                step("doc.on.doc", "Copy as usual", "Copy text, links, paths or images in any app.")
                step("switch.2", "Open ClipBar in one tap", "Add the ClipBar button to Control Center or a widget. Opening the app saves the clipboard automatically.")
                step("hand.tap", "Tap to copy again", "Tap any item to put it back on the clipboard. Pin or save what you need forever.")
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 10) {
                #if os(iOS)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link(destination: url) {
                        Text("Allow paste without prompts in Settings")
                            .font(.footnote)
                    }
                }
                #endif
                Button {
                    didOnboard = true
                } label: {
                    Text("Get Started").frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 28)
        }
        .interactiveDismissDisabled()
    }

    private func step(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
