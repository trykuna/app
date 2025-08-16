// Features/Settings/AppIconPreviewGenerator.swift
import SwiftUI

// This view can be used to generate app icon previews programmatically
// You can screenshot these views to create the actual preview images
struct AppIconPreviewGenerator: View {
    let icon: AppIcon
    
    var body: some View {
        ZStack {
            // Background with subtle gradient
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.clear, icon.accentColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)

            // Actual logo
            AdaptiveLogo(icon.logoVariant)
                .logoSize(100)
                .logoCornerRadius(18)
        }
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private var gradientColors: [Color] {
        switch icon {
        case .default:
            return [Color.blue.opacity(0.8), Color.blue]
        case .gold:
            return [Color.yellow.opacity(0.7), Color.yellow]
        case .orange:
            return [Color.orange.opacity(0.7), Color.orange]
        case .red:
            return [Color.red.opacity(0.7), Color.red]
        case .yellow:
            return [Color.yellow.opacity(0.7), Color.yellow]
        case .neon:
            return [Color.cyan.opacity(0.7), Color.cyan]
        case .silver:
            return [Color.gray.opacity(0.7), Color.gray]
        case .pride:
            return [Color.pink.opacity(0.7), Color.pink]
        case .altPride:
            return [Color.purple.opacity(0.7), Color.purple]
        case .transPride:
            return [Color.cyan.opacity(0.7), Color.cyan]
        }
    }
    
    private var foregroundColor: Color {
        switch icon {
        case .silver:
            return .black
        default:
            return .white
        }
    }
    
    private var iconSymbol: String {
        switch icon {
        case .default:
            return "checkmark.circle.fill"
        case .gold:
            return "star.fill"
        case .orange:
            return "flame.fill"
        case .red:
            return "heart.fill"
        case .yellow:
            return "sun.max.fill"
        case .neon:
            return "bolt.fill"
        case .silver:
            return "circle.fill"
        case .pride:
            return "heart.fill"
        case .altPride:
            return "rainbow"
        case .transPride:
            return "flag.fill"
        }
    }
}

// Fallback view for when preview images don't exist
struct AppIconFallbackView: View {
    let icon: AppIcon

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(icon.accentColor.opacity(0.2))
                .frame(width: 60, height: 60)

            AdaptiveLogo(icon.logoVariant)
                .logoSize(40)
                .logoCornerRadius(8)
        }
    }
}

#Preview("All Icons") {
    ScrollView {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 20) {
            ForEach(AppIcon.allCases) { icon in
                VStack {
                    AppIconPreviewGenerator(icon: icon)
                    Text(icon.displayName)
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}
