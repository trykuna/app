import SwiftUI

struct ContributorsView: View {
    // Load the data from the model
    let contributors = Contributors.load()
    
    var body: some View {
        List {
            // Thank you message
            Text(String(localized: "settings.about.thankYou.message"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))

            // MARK: Translators
            if let translators = contributors?.translators, !translators.isEmpty {
                Section(String(
                    localized: "settings.about.thankYou.translators",
                    comment: "Translators heading")) {
                    ForEach(translators) { translator in
                        TranslatorRow(translator: translator)
                    }
                }
            }
            
            // MARK: Feature ideas & other contributions
            if let featureContributors = contributors?.featureContributors, !featureContributors.isEmpty {
                Section(String(
                    localized: "settings.about.thankYou.featureContributors",
                    comment: "Feature Contributors heading")) {
                    ForEach(featureContributors) { contributor in
                        FeatureContributorRow(contributor: contributor)
                    }
                }
            }
            Text(String(localized: "settings.about.thankYou.closing"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .font(.title)
                .listRowBackground(Color.clear)
                .frame(maxWidth: .infinity)
        }
        .navigationTitle(String(localized: "settings.about.thankYou.title", comment: "Thank You heading"))
        .navigationBarTitleDisplayMode(.large)
        .listStyle(.insetGrouped)
    }
}

// MARK: - Subviews

struct TranslatorRow: View {
    let translator: Contributors.Translator
    
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(translator.username)
                    .font(.body)
                HStack(spacing: 4) {
                    ForEach(translator.flags, id: \.self) { code in
                        Text(code.flagEmoji ?? "🏳️")
                            .font(.title3)
                            .accessibilityHidden(true)
                    }
                    Text(translator.languages.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct FeatureContributorRow: View {
    let contributor: Contributors.FeatureContributor
    
    var body: some View {
        let iconName = (contributor.type == "feature") ? "lightbulb.fill" : "wrench.and.screwdriver"
        
        if let url = URL(string: "https://github.com/\(contributor.github)") {
            Link(destination: url) {
                HStack(spacing: 10) {
                    Image(systemName: iconName)
                        .imageScale(.medium)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    
                    Text(contributor.github)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .accessibilityLabel(Text(String(
                            localized: "settings.about.contributors.visitGithub", comment: "Visit GitHub")))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .imageScale(.medium)
                    .foregroundStyle(.tint)
                Text(contributor.github)
                    .foregroundColor(.primary)
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ContributorsView()
    }
}
