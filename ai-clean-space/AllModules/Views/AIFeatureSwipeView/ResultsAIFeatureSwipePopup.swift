import SwiftUI
import Photos

struct ResultsAIFeatureSwipePopup: View {
    let deleteCount: Int
    @Binding var isPresented: Bool
    let onViewResults: () -> Void
    let onContinueSwiping: () -> Void
    
    @State private var showContent = false
    @State private var backgroundOpacity = 0.0
    
    var body: some View {
        ZStack {
            CMColor.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                .opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [CMColor.primary.opacity(0.2), CMColor.accent.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                            .shadow(color: CMColor.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [CMColor.primary, CMColor.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(spacing: 8) {
                        Text("Ready to see your results?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(CMColor.primaryText)
                            .multilineTextAlignment(.center)
                        
                        Text("You've selected \(deleteCount) photo\(deleteCount == 1 ? "" : "s") for deletion. Would you like to review your selections?")
                            .font(.body)
                            .foregroundColor(CMColor.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                }
                
                VStack(spacing: 12) {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showContent = false
                            backgroundOpacity = 0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onViewResults()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("View Results (\(deleteCount) to delete)")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(CMColor.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [CMColor.primary, CMColor.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: CMColor.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .scaleEffect(showContent ? 1 : 0.8)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: showContent)
                    
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        dismissPopup()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("Close")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(CMColor.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CMColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .scaleEffect(showContent ? 1 : 0.8)
                    .opacity(showContent ? 1 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.15), value: showContent)
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.regularMaterial)
                    .shadow(color: CMColor.black.opacity(0.1), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
            .scaleEffect(showContent ? 1 : 0.7)
            .opacity(showContent ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showContent)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                backgroundOpacity = 0.4
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }
    
    private func dismissPopup() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        onContinueSwiping()
    }
}
