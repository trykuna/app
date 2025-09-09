import Foundation

// Setup the Contiributors model which is read from the resource file contributors.json
struct Contributors: Codable {
    // We have two types of contributor to thank, translators and feature contributors
    let translators: [Translator]
    let featureContributors: [FeatureContributor]
    
    // Translators will have their username (which they used on Crowdin) and the languages they did
    struct Translator: Codable, Identifiable {
        let username: String
        let languages: [String]
        let flags: [String]
        
        var id: String { username }
    }
    
    // Feature Contributors will only have their github username.
    struct FeatureContributor: Codable, Identifiable {
        let github: String
        let type: String
        
        var id: String { github }
    }
    
    // Load the file and then decode the data
    static func load() -> Contributors? {
        guard let url = Bundle.main.url(forResource: "contributors", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let contributors = try? JSONDecoder().decode(Contributors.self, from: data) else {
            return nil
        }
        return contributors
    }
}
