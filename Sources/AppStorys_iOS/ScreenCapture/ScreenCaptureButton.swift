//
//  ScreenCaptureButton.swift
//  AppStorys_iOS
//
//  Enhanced with better positioning and styling
//

import SwiftUI

public struct ScreenCaptureButton: View {
    let onCapture: () async throws -> Void
    
    @State private var isCapturing = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    // Positioning
    private let position: Position
    
    public enum Position {
        case bottomCenter
        case bottomTrailing
        case bottomLeading
        
        var alignment: Alignment {
            switch self {
            case .bottomCenter: return .bottom
            case .bottomTrailing: return .bottomTrailing
            case .bottomLeading: return .bottomLeading
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .bottomCenter:
                return EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0)
            case .bottomTrailing:
                return EdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 20)
            case .bottomLeading:
                return EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 0)
            }
        }
    }
    
    public init(
        position: Position = .bottomCenter,
        onCapture: @escaping () async throws -> Void
    ) {
        self.position = position
        self.onCapture = onCapture
    }
    
    public var body: some View {
        Button(action: {
            Task { await capture() }
        }) {
            HStack(spacing: 8) {
                icon
                Text(buttonTitle)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(buttonColor)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            )
        }
        .disabled(isCapturing)
        .opacity(isCapturing ? 0.6 : 1.0)
        .alert("Capture Failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
            Button("Retry") {
                errorMessage = nil
                Task { await capture() }
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    @ViewBuilder
    private var icon: some View {
        if isCapturing {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
        } else if showSuccess {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
        } else {
            Image(systemName: "camera.fill")
                .foregroundStyle(.white)
        }
    }
    
    private var buttonTitle: String {
        if isCapturing { return "Capturing..." }
        if showSuccess { return "Captured!" }
        return "Capture Screen"
    }
    
    private var buttonColor: Color {
        if showSuccess { return .green }
        return .blue
    }
    
    private func capture() async {
        isCapturing = true
        errorMessage = nil
        
        do {
            try await onCapture()
            
            await MainActor.run {
                showSuccess = true
            }
            
            try await Task.sleep(nanoseconds: 1_500_000_000)
            
            await MainActor.run {
                showSuccess = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                Logger.error("❌ Capture failed", error: error)
            }
        }
        
        await MainActor.run {
            isCapturing = false
        }
    }
}
