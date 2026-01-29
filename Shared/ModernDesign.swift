//
//  ModernDesign.swift
//  Dashboard Screensaver
//
//  Created by Jordan Koch on 2026-01-28.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//
//  Glassmorphic design system adapted from TopGUI
//

import SwiftUI

// MARK: - Color Palette

struct ModernColors {
    // Base gradient colors (dark navy theme)
    static let gradientStart = Color(red: 0.08, green: 0.08, blue: 0.14)
    static let gradientMiddle = Color(red: 0.10, green: 0.10, blue: 0.18)
    static let gradientEnd = Color(red: 0.12, green: 0.12, blue: 0.22)

    // Vibrant accent colors
    static let accentCyan = Color(red: 0.30, green: 0.85, blue: 0.95)
    static let accentTeal = Color(red: 0.20, green: 0.78, blue: 0.76)
    static let accentPurple = Color(red: 0.60, green: 0.40, blue: 0.95)
    static let accentOrange = Color(red: 1.0, green: 0.60, blue: 0.20)
    static let accentYellow = Color(red: 1.0, green: 0.84, blue: 0.30)
    static let accentPink = Color(red: 1.0, green: 0.35, blue: 0.65)

    // Blob colors for animated background
    static let blobCyan = Color(red: 0.30, green: 0.85, blue: 0.95).opacity(0.3)
    static let blobPurple = Color(red: 0.60, green: 0.40, blue: 0.95).opacity(0.25)
    static let blobPink = Color(red: 1.0, green: 0.35, blue: 0.65).opacity(0.2)
    static let blobOrange = Color(red: 1.0, green: 0.60, blue: 0.20).opacity(0.2)

    // Status colors for alerts
    static let statusLow = Color(red: 0.30, green: 0.85, blue: 0.45)
    static let statusMedium = Color(red: 1.0, green: 0.84, blue: 0.30)
    static let statusHigh = Color(red: 1.0, green: 0.60, blue: 0.20)
    static let statusCritical = Color(red: 1.0, green: 0.30, blue: 0.35)

    // Text colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)

    // Glass effect colors
    static let glassBackground = Color.white.opacity(0.05)
    static let glassBorder = Color.white.opacity(0.15)

    // Health status colors
    static func healthColor(_ status: URLHealthStatus) -> Color {
        switch status {
        case .unknown: return .gray
        case .healthy: return statusLow
        case .degraded: return statusMedium
        case .failed: return statusCritical
        }
    }

    // Alert severity colors
    static func alertColor(_ severity: AlertSeverity) -> Color {
        switch severity {
        case .none: return statusLow
        case .low: return statusMedium
        case .medium: return statusHigh
        case .high: return statusCritical
        case .critical: return statusCritical
        }
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(ModernColors.glassBorder, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                    .shadow(color: .white.opacity(0.8), radius: 1, x: -1, y: -1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Modern Button Style

struct ModernButtonStyle: ButtonStyle {
    enum Style {
        case glass, filled, outlined, destructive
    }

    var style: Style = .glass
    var color: Color = ModernColors.accentCyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundFor(configuration.isPressed))
            .foregroundColor(foregroundFor(configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderFor(configuration.isPressed), lineWidth: style == .outlined ? 2 : 0)
            )
            .shadow(color: shadowColor.opacity(configuration.isPressed ? 0.1 : 0.3), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }

    @ViewBuilder
    private func backgroundFor(_ isPressed: Bool) -> some View {
        switch style {
        case .glass:
            Color.white.opacity(isPressed ? 0.15 : 0.1)
                .background(.ultraThinMaterial)
        case .filled:
            color.opacity(isPressed ? 0.8 : 1.0)
        case .outlined:
            Color.clear
        case .destructive:
            Color.red.opacity(isPressed ? 0.8 : 1.0)
        }
    }

    private func foregroundFor(_ isPressed: Bool) -> Color {
        switch style {
        case .glass, .outlined:
            return .white
        case .filled, .destructive:
            return .white
        }
    }

    private func borderFor(_ isPressed: Bool) -> Color {
        switch style {
        case .outlined:
            return color.opacity(isPressed ? 0.6 : 1.0)
        default:
            return .clear
        }
    }

    private var shadowColor: Color {
        switch style {
        case .filled:
            return color
        case .destructive:
            return .red
        default:
            return .black
        }
    }
}

// MARK: - Modern Header

struct ModernHeader: View {
    enum Size {
        case large, medium, small

        var fontSize: CGFloat {
            switch self {
            case .large: return 32
            case .medium: return 22
            case .small: return 18
            }
        }
    }

    let text: String
    var size: Size = .large
    var color: Color = ModernColors.textPrimary

    var body: some View {
        Text(text)
            .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
            .foregroundColor(color)
    }
}

// MARK: - Floating Blob

struct FloatingBlob: View {
    let color: Color
    let size: CGFloat
    var blur: CGFloat = 50

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .blur(radius: blur)
    }
}

// MARK: - Glassmorphic Background

struct GlassmorphicBackground: View {
    @State private var animate1 = false
    @State private var animate2 = false
    @State private var animate3 = false
    @State private var animate4 = false
    @State private var animate5 = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [ModernColors.gradientStart, ModernColors.gradientMiddle, ModernColors.gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Animated blobs
                FloatingBlob(color: ModernColors.blobCyan, size: geo.size.width * 0.6)
                    .offset(
                        x: animate1 ? geo.size.width * 0.3 : -geo.size.width * 0.2,
                        y: animate1 ? -geo.size.height * 0.2 : geo.size.height * 0.3
                    )

                FloatingBlob(color: ModernColors.blobPurple, size: geo.size.width * 0.5)
                    .offset(
                        x: animate2 ? -geo.size.width * 0.3 : geo.size.width * 0.2,
                        y: animate2 ? geo.size.height * 0.3 : -geo.size.height * 0.2
                    )

                FloatingBlob(color: ModernColors.blobPink, size: geo.size.width * 0.4)
                    .offset(
                        x: animate3 ? geo.size.width * 0.2 : -geo.size.width * 0.3,
                        y: animate3 ? geo.size.height * 0.4 : geo.size.height * 0.1
                    )

                FloatingBlob(color: ModernColors.blobOrange, size: geo.size.width * 0.35)
                    .offset(
                        x: animate4 ? -geo.size.width * 0.1 : geo.size.width * 0.3,
                        y: animate4 ? -geo.size.height * 0.3 : geo.size.height * 0.2
                    )

                FloatingBlob(color: ModernColors.blobCyan.opacity(0.5), size: geo.size.width * 0.3)
                    .offset(
                        x: animate5 ? geo.size.width * 0.4 : -geo.size.width * 0.1,
                        y: animate5 ? geo.size.height * 0.2 : -geo.size.height * 0.3
                    )
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    animate1 = true
                }
                withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true).delay(0.5)) {
                    animate2 = true
                }
                withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true).delay(1.0)) {
                    animate3 = true
                }
                withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true).delay(1.5)) {
                    animate4 = true
                }
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true).delay(2.0)) {
                    animate5 = true
                }
            }
        }
    }
}

// MARK: - Circular Gauge

struct CircularGauge: View {
    let value: Double
    var maxValue: Double = 100
    var size: CGFloat = 100
    var lineWidth: CGFloat = 8
    var showLabel: Bool = true
    var color: Color = ModernColors.accentCyan

    @State private var animatedValue: Double = 0

    private var progress: Double {
        min(max(animatedValue / maxValue, 0), 1)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.5), color],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Label
            if showLabel {
                Text("\(Int(animatedValue))")
                    .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                animatedValue = newValue
            }
        }
    }
}

// MARK: - Mini Gauge

struct MiniGauge: View {
    let value: Double
    var maxValue: Double = 100
    var color: Color = ModernColors.accentCyan

    private var progress: Double {
        min(max(value / maxValue, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.7), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Alert Badge

struct AlertBadge: View {
    let severity: AlertSeverity
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ModernColors.alertColor(severity))
                .frame(width: 8, height: 8)

            Text(severity.displayName)
                .font(.system(size: 12, weight: .medium, design: .rounded))

            if count > 0 {
                Text("(\(count))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(ModernColors.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(ModernColors.alertColor(severity).opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(ModernColors.alertColor(severity).opacity(0.5), lineWidth: 1)
                )
        )
        .foregroundColor(ModernColors.alertColor(severity))
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let isActive: Bool
    var activeColor: Color = ModernColors.statusLow
    var inactiveColor: Color = .gray

    var body: some View {
        Circle()
            .fill(isActive ? activeColor : inactiveColor)
            .frame(width: 10, height: 10)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isActive ? activeColor.opacity(0.5) : .clear, radius: 4)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = ModernColors.textPrimary

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(ModernColors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        GlassmorphicBackground()

        VStack(spacing: 20) {
            ModernHeader(text: "Dashboard Screensaver", size: .large)

            HStack(spacing: 20) {
                CircularGauge(value: 75, color: ModernColors.accentCyan)
                CircularGauge(value: 45, color: ModernColors.accentPurple)
                CircularGauge(value: 90, color: ModernColors.statusCritical)
            }

            VStack(spacing: 10) {
                AlertBadge(severity: .critical, count: 3)
                AlertBadge(severity: .high, count: 7)
                AlertBadge(severity: .medium, count: 12)
            }
            .glassCard()

            HStack {
                Button("Glass Button") {}
                    .buttonStyle(ModernButtonStyle(style: .glass))

                Button("Filled Button") {}
                    .buttonStyle(ModernButtonStyle(style: .filled, color: ModernColors.accentPurple))
            }
        }
        .padding()
    }
}
