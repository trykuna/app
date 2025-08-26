// Features/Settings/AboutView.swift
import SwiftUI

struct AboutView: View {
    // Pull version/build from Info.plist
    private var versionText: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (Build \(b))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Header card
                VStack(spacing: 12) {
                    AdaptiveLogo(.main)
                        .logoSize(88)
                        .logoCornerRadius(20)
                        .logoShadow()

                    Text("Kuna")
                        .font(.largeTitle).bold()

                    Text(versionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)

                // Vikunja thanks
                CardSection(title: "Vikunja") {
                    // Text("Big shout‑out to the open‑source legends behind Vikunja for building the rock‑solid task platform this app is powered by. Without you, this would just be a very pretty, very empty checklist.")
                    Text(String(localized: "settings.about.vikunja.text", comment: "Text for about view"))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    // Link styled as a row (no custom LinkRow)
                    Link(destination: URL(string: "https://vikunja.io")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .imageScale(.medium)
                                .foregroundStyle(.secondary)
                                .frame(width: 22)

                            // Text("Learn more")
                            Text(String(localized: "settings.about.vikunja.link", comment: "Link for about view"))
                                .foregroundStyle(.primary)

                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.footnote)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Libraries & Tools
                CardSection(title: "Libraries & Tools") {
                    VStack(alignment: .leading, spacing: 10) {
                        // SwiftUI.Label("SwiftUI — Apple's native UI framework", systemImage: "square.stack.3d.up")
                        SwiftUI.Label(String(localized: "about.framework.swiftui", comment: "SwiftUI framework description"), systemImage: "square.stack.3d.up")
                        // SwiftUI.Label("Foundation — Core system services", systemImage: "shippingbox")
                        SwiftUI.Label(String(localized: "about.framework.foundation", comment: "Foundation framework description"), systemImage: "shippingbox")
                        // SwiftUI.Label("Keychain Services — Secure credential storage", systemImage: "lock.circle")
                        SwiftUI.Label(String(localized: "about.framework.keychain", comment: "Keychain services description"), systemImage: "lock.circle")
                    }
                    .labelStyle(.aboutBullet)
                }

                // Special Thanks
                CardSection(title: String(localized: "about.specialThanks.title", comment: "Special Thanks")) {
                    Text(String(localized: "about.specialThanks.message", comment: "Special thanks message from the developer"))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                }

                // Useful links / actions — replace URLs as needed
                CardSection(title: "Links") {
                    VStack(spacing: 0) {
                        LinkRowPrimitive(title: "Website", systemImage: "globe", url: URL(string: "https://vikunja.io")!)
                        Divider()
                        // LinkRowPrimitive(title: "Privacy Policy", systemImage: "hand.raised", url: URL(string: "https://example.com/privacy")!)
                        LinkRowPrimitive(title: String(localized: "about.privacyPolicy", comment: "Privacy policy link"), systemImage: "hand.raised", url: URL(string: "https://example.com/privacy")!)
                        Divider()
                        LinkRowPrimitive(title: "Licenses", systemImage: "doc.text.magnifyingglass", url: URL(string: "https://example.com/licenses")!)
                    }
                }

                Spacer(minLength: 12)
            }
            .padding(.bottom, 24)
        }
        // .navigationTitle("About")
        .navigationTitle(String(localized: "settings.about.title", comment: "Title for about view"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Components

private struct CardSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption).bold()
                .foregroundStyle(.secondary)

            content
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: 680) // keeps readable width on iPad
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }
}

// “Link row” built only with SwiftUI primitives
private struct LinkRowPrimitive: View {
    let title: String
    let systemImage: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .imageScale(.medium)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                    .font(.footnote)
            }
            .padding(.vertical, 8)
        }
    }
}

// Subtle bullet style for Label lists
private struct AboutBulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            configuration.title
        }
    }
}

extension SwiftUI.LabelStyle where Self == AboutBulletLabelStyle {
    static var aboutBullet: AboutBulletLabelStyle { .init() }
}

// MARK: - Preview
#Preview {
    NavigationStack { AboutView() }
}
