// Components/AdaptiveLogo.swift
import SwiftUI

enum LogoVariant: String, CaseIterable {
    case main = "Main"
    case gold = "Gold"
    case orange = "Orange"
    case red = "Red"
    case yellow = "Yellow"
    case neon = "Neon"
    case silver = "Silver"
    case pride = "Pride"
    case altPride = "AltPride"
    case transPride = "TransPride"
    
    var displayName: String {
        switch self {
        case .main: return "Main"
        case .gold: return "Gold"
        case .orange: return "Orange"
        case .red: return "Red"
        case .yellow: return "Yellow"
        case .neon: return "Neon"
        case .silver: return "Silver"
        case .pride: return "Pride"
        case .altPride: return "Alt Pride"
        case .transPride: return "Trans Pride"
        }
    }
    
    var lightImageName: String {
        switch self {
        case .main: return "KunaLogoMainLight"
        case .gold: return "KunaLogoGoldLight"
        case .orange: return "KunaLogoOrangeLight"
        case .red: return "KunaLogoRed"
        case .yellow: return "KunaLogoYellow"
        case .neon: return "KunaLogoNeonLight"
        case .silver: return "KunaLogoSilver"
        case .pride: return "KunaLogoPride"
        case .altPride: return "KunaLogoAltPrideLight"
        case .transPride: return "KunaLogoTransPride"
        }
    }
    
    var darkImageName: String {
        switch self {
        case .main: return "KunaLogoMainDark"
        case .gold: return "KunaLogoGoldDark"
        case .orange: return "KunaLogoOrangeDark"
        case .red: return "KunaLogoRedDark"
        case .yellow: return "KunaLogoYellowDark"
        case .neon: return "KunaLogoNeonDark"
        case .silver: return "KunaLogoSilverDark"
        case .pride: return "KunaLogoPrideDark"
        case .altPride: return "KunaLogoAltPrideDark"
        case .transPride: return "KunaLogoTransPrideDark"
        }
    }
}

struct AdaptiveLogo: View {
    let variant: LogoVariant
    @Environment(\.colorScheme) private var colorScheme
    
    init(_ variant: LogoVariant = .main) {
        self.variant = variant
    }
    
    var body: some View {
        Image(currentImageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
    
    private var currentImageName: String {
        colorScheme == .dark ? variant.darkImageName : variant.lightImageName
    }
}

// Convenience modifiers for common logo usage
extension View {
    func logoSize(_ size: CGFloat) -> some View {
        self.frame(width: size, height: size)
    }

    func logoSize(width: CGFloat, height: CGFloat) -> some View {
        self.frame(width: width, height: height)
    }

    func logoCornerRadius(_ radius: CGFloat) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    func logoShadow() -> some View {
        self.shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// Preview for testing different variants
#Preview("Logo Variants") {
    ScrollView {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            ForEach(LogoVariant.allCases, id: \.self) { variant in
                VStack(spacing: 8) {
                    AdaptiveLogo(variant)
                        .logoSize(60)
                        .logoCornerRadius(12)
                        .logoShadow()
                    
                    Text(variant.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        AdaptiveLogo(.main)
            .logoSize(100)
            .logoCornerRadius(20)
            .logoShadow()
        
        Text("Kuna")
            .font(.largeTitle)
            .fontWeight(.bold)
    }
    .padding()
    .preferredColorScheme(.dark)
}
