import SwiftUI
import Combine
import UIKit

struct AIFeatureView: View {
    @StateObject private var viewModel = AIFeatureViewModel()
    @Binding var isPaywallPresented: Bool
    
    @State private var presentedSwipeView: SwipedPhotoModel?
    @State private var presentedResultsView: SwipeResultsData?
    @State private var showSwipeOnboarding = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    headerView()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    swipeModeSection()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    
                    categoriesGrid()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(item: $presentedSwipeView) { swipeData in
            SwipePhotoDetailView(
                sections: swipeData.sections,
                initialIndex: 0,
                viewModel: SimilaritySectionsViewModel(
                    sections: swipeData.sections,
                    type: swipeData.type
                ),
                mode: .swipeMode,
                onFinish: { decisions in
                    viewModel.processSwipeDecisions(decisions)
                },
                onShowResults: {
                    presentedSwipeView = nil
                    let resultsData = viewModel.getSwipeResultsData()
                    presentedResultsView = resultsData
                },
                onSwipeDecisionChanged: {
                    viewModel.updateTotalSwipeDecisionsCount()
                }
            )
        }
        .fullScreenCover(item: $presentedResultsView) { _ in
            SwipeResultsView(
                viewModel: viewModel,
                onFinish: { photosToDelete in
                    viewModel.finalizePhotoDeletion(photosToDelete)
                },
                onSwipeDecisionChanged: {
                    viewModel.updateTotalSwipeDecisionsCount()
                }
            )
        }
        .fullScreenCover(isPresented: $showSwipeOnboarding) {
            SwipeOnboardingView {
                let allSections = [
                    viewModel.getSections(for: .image(.similar)),
                    viewModel.getSections(for: .image(.blurred)),
                    viewModel.getSections(for: .image(.duplicates)),
                    viewModel.getSections(for: .image(.screenshots))
                ].flatMap { $0 }
                
                if !allSections.isEmpty {
                    presentedSwipeView = SwipedPhotoModel(sections: allSections, type: .similar)
                }
            }
        }
    }
    
    // MARK: - Header
    
    @ViewBuilder
    private func headerView() -> some View {
        HStack {
            Text("AI Smart CleanUp")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            // todo PRO
            Button(action: {
                isPaywallPresented = true
            }) { 
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(CMColor.primaryLight)
                    
                    Text("Pro")
                        .fontWeight(.semibold)
                        .foregroundColor(CMColor.primaryLight)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(CMColor.backgroundSecondary)
                .clipShape(Capsule())
            }
        }
        .padding(.top, 12)
    }
        
    @ViewBuilder
    private func swipeModeSection() -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(width: 80, height: 80)
                    
                    Image("smartScan")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 70, maxHeight: 70)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Swipe Mode")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Swipe the photo to decide their fate: right - keep, left - delete.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            Button(action: {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    showSwipeOnboarding = true
                }
            }) {
                HStack {
                    Text("Enable swipe mode")
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if viewModel.hasSwipeResults {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    
                    let resultsData = viewModel.getSwipeResultsData()
                    presentedResultsView = resultsData
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color.orange.opacity(0.2), Color.pink.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 50, height: 50)
                            
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.orange, Color.pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("View Swipe Results")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                            
                            Text("\(viewModel.swipeResultsSummary)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.9),
                                Color.blue.opacity(0.8),
                                Color.pink.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(
                        color: Color.purple.opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                    .shadow(
                        color: Color.pink.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .overlay(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    )
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.hasSwipeResults)
                }
                .buttonStyle(SwipeResultsButtonStyle())
            }
        }
        .padding(20)
        .background(CMColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
        
    @ViewBuilder
    private func categoriesGrid() -> some View {
        let cardSize = UIScreen.main.bounds.width / 2 - 24
        
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2),
            spacing: 16
        ) {
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.similar))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipedPhotoModel(sections: sections, type: .similar)
                    }
                }
            } label: {
                getItem(
                    for: .similar,
                    image: viewModel.similarPreview,
                    count: viewModel.similarCount,
                    sizeStr: formatMegabytes(viewModel.similarMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
            
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.blurred))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipedPhotoModel(sections: sections, type: .blurred)
                    }
                }
            } label: {
                getItem(
                    for: .blurred,
                    image: viewModel.blurredPreview,
                    count: viewModel.blurredCount,
                    sizeStr: formatMegabytes(viewModel.blurredMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
            
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.duplicates))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipedPhotoModel(sections: sections, type: .duplicates)
                    }
                }
            } label: {
                getItem(
                    for: .duplicates,
                    image: viewModel.duplicatesPreview,
                    count: viewModel.duplicatesCount,
                    sizeStr: formatMegabytes(viewModel.duplicatesMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
            
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.screenshots))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipedPhotoModel(sections: sections, type: .screenshots)
                    }
                }
            } label: {
                getItem(
                    for: .screenshots,
                    image: viewModel.screenshotsPreview,
                    count: viewModel.screenshotsCount,
                    sizeStr: formatMegabytes(viewModel.screenshotsMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
        }
    }
        
    private func getItem(
        for type: ScanItemType,
        image: UIImage?,
        count: Int,
        sizeStr: String,
        size: CGFloat
    ) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .frame(width: size, height: size)
                    .scaledToFit()
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            
            VStack {
                HStack {
                    Text(type.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CMColor.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CMColor.border)
                        .cornerRadius(12)
                    
                    Spacer()
                }
                
                Spacer()
                
                HStack {
                    Text(getItemCountText(for: type, count: count, sizeStr: sizeStr))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CMColor.primaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CMColor.background)
                        .cornerRadius(12)
                    
                    Spacer()
                }
            }
            .padding(12)
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .foregroundStyle(CMColor.backgroundSecondary)
        )
        .clipped()
    }
        
    private func getItemCountText(for type: ScanItemType, count: Int, sizeStr: String) -> String {
        if count == 0 {
            return "No items"
        } else {
            return "\(count) items • \(sizeStr)"
        }
    }
    
    private func formatMegabytes(_ megabytes: Double) -> String {
        if megabytes < 1 {
            return String(format: "%.1f KB", megabytes * 1024)
        } else if megabytes < 1024 {
            return String(format: "%.0f MB", megabytes)
        } else {
            return String(format: "%.1f GB", megabytes / 1024)
        }
    }
}
