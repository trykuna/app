import Foundation

extension String {
    /// Converts a valid 2-letter ISO country code into a flag emoji.
    /// Returns nil if the string is not a valid code.
    var flagEmoji: String? {
        let uppercasedCode = self.uppercased()

        // Must be exactly 2 letters A–Z
        guard uppercasedCode.count == 2,
                uppercasedCode.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }) else {
            return nil
        }

        let base: UInt32 = 127397
        var flagString = ""

        for scalar in uppercasedCode.unicodeScalars {
            guard let flagScalar = UnicodeScalar(base + scalar.value) else {
                return nil
            }
            flagString.append(String(flagScalar))
        }

        return flagString
    }
}
