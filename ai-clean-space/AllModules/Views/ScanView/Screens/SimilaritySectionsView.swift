import SwiftUI
import Photos

struct SimilaritySectionsView: View {
    @StateObject private var viewState: SimilaritySectionsViewModel
    @Environment(\.dismiss) private var viewDismiss
    @State private var chosenSection: AICleanServiceSection?
    @State private var chosenImageIndex: Int = 0
    
    // Grid layout for gallery items, using a fixed size for stable layout
    private let galleryColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 80), spacing: 8)
    ]

    init(viewModel: SimilaritySectionsViewModel) {
        _viewState = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            // MARK: - Navigation Bar
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Button {
                        viewDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(CMColor.secondaryText)
                            .opacity(viewState.hasSelectedItems ? 0 : 1)
                            .animation(.easeInOut, value: viewState.hasSelectedItems)
                    }

                    Spacer()

                    Text(viewState.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(CMColor.white)
                    
                    Spacer()

                    Button {
                        if viewState.hasSelectedItems {
                            viewState.deselectAll()
                        } else {
                            viewState.selectAll()
                        }
                    } label: {
                        Image(systemName: viewState.hasSelectedItems ? "square.dashed.inset.fill" : "square.dashed")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundColor(CMColor.primary)
                            .animation(.spring(), value: viewState.hasSelectedItems)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(CMColor.backgroundSecondary)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            
                // MARK: - Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        ForEach(viewState.sections.indices, id: \.self) { index in
                            createSectionView(for: viewState.sections[index])
                        }
                    }
                    .padding(12)
                    .padding(.bottom, viewState.hasSelectedItems ? 120 : 0)
                }
                .background(CMColor.background)
            }
            .background(CMColor.background)
            .ignoresSafeArea(.all, edges: .bottom)

            // MARK: - Floating Delete Button
            VStack {
                Spacer()
                if viewState.hasSelectedItems {
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            viewState.deleteSelected()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 20, weight: .semibold))
                            
                            Text("Delete \(viewState.selectedCount) item\(viewState.selectedCount == 1 ? "" : "s")")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(CMColor.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [CMColor.error.opacity(0.8), CMColor.error]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: CMColor.error.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewState.hasSelectedItems)
        }
        .fullScreenCover(item: $chosenSection) { section in
            if viewState.type == .videos {
                SectionVideosItemPreview(
                    section: section,
                    initialIndex: chosenImageIndex,
                    viewModel: viewState
                )
            } else {
                SectionImagesItemPreview(
                    section: section,
                    initialIndex: chosenImageIndex,
                    viewModel: viewState
                )
            }
        }
    }

    private func createSectionView(for section: AICleanServiceSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                switch section.kind {
                case .count:
                    Text("\(section.models.count) items")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                case .date(let date):
                    Text(date?.formatAsShortDate() ?? "")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                case .united(let date):
                    Text(date?.formatAsShortDate() ?? "")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut) {
                        if viewState.isAllSelectedInSection(section) {
                            viewState.deselectAllInSection(section)
                        } else {
                            viewState.selectAllInSection(section)
                        }
                    }
                } label: {
                    Text(viewState.isAllSelectedInSection(section) ? "Deselect all" : "Select all")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(viewState.isAllSelectedInSection(section) ? CMColor.error : CMColor.primary)
                }
            }
            
            // Grid layout
            VStack(alignment: .leading, spacing: 8) {
                if viewState.type == .duplicates || viewState.type == .similar {
                    if let firstModel = section.models.first {
                        createPrimaryItemView(for: firstModel, section: section, index: 0)
                            .padding(.top, 24)
                    }
                }

                let remainingModels = viewState.type == .duplicates || viewState.type == .similar ? Array(section.models.suffix(from: 1)) : section.models
                
                LazyVGrid(columns: galleryColumns, spacing: 8) {
                    ForEach(remainingModels.indices, id: \.self) { index in
                        let model = remainingModels[index]
                        let actualIndex = (viewState.type == .duplicates || viewState.type == .similar) ? index + 1 : index
                        createGalleryItemView(for: model, section: section, index: actualIndex)
                    }
                }
            }
        }
        .padding(16)
        .background(CMColor.surface)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    private func createPrimaryItemView(for model: AICleanServiceModel, section: AICleanServiceSection, index: Int) -> some View {
        let isSelected = viewState.isSelected(model)
        let cornerRadius: CGFloat = 16
        let itemSize: CGFloat = 176
        
        return ZStack(alignment: .topLeading) {
            model.imageView(size: CGSize(width: itemSize, height: itemSize))
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(CMColor.primary, lineWidth: isSelected ? 3 : 0)
                )
            
            // "Best" icon
            Image(systemName: "star.circle.fill")
                .foregroundColor(CMColor.primary)
                .font(.system(size: 24))
                .shadow(radius: 2)
                .padding(8)

            if viewState.type == .videos {
                VStack {
                    Spacer()
                    HStack {
                        Text(model.formattedDuration)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(CMColor.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(CMColor.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                    }
                }
                .padding(8)
            }
            
            // Selection overlay and Checkbox
            Group {
                if isSelected {
                    Color.black.opacity(0.6)
                        .cornerRadius(cornerRadius)
                }
                
                CheckboxView(isSelected: isSelected)
                    .padding(8)
            }
            .frame(width: itemSize, height: itemSize, alignment: .topTrailing)
            .opacity(isSelected || viewState.isSelectionMode ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .animation(.easeInOut(duration: 0.2), value: viewState.isSelectionMode)
        }
        .frame(width: itemSize, height: itemSize)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onTapGesture {
            if viewState.isSelectionMode {
                viewState.toggleSelection(for: model)
            } else {
                chosenImageIndex = index
                chosenSection = section
            }
        }
        .onLongPressGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewState.isSelectionMode = true
                viewState.toggleSelection(for: model)
            }
        }
    }

    private func createGalleryItemView(for model: AICleanServiceModel, section: AICleanServiceSection, index: Int) -> some View {
        let isSelected = viewState.isSelected(model)
        let cornerRadius: CGFloat = 8
        let itemSize: CGFloat = 80
        
        return ZStack {
            model.imageView(size: CGSize(width: itemSize, height: itemSize))
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(CMColor.primary, lineWidth: isSelected ? 3 : 0)
                )
            
            if viewState.type == .videos {
                VStack {
                    Spacer()
                    HStack {
                        Text(model.formattedDuration)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(CMColor.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(CMColor.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Spacer()
                    }
                }
                .padding(4)
            }
            
            // Selection overlay and Checkbox
            Group {
                if isSelected {
                    Color.black.opacity(0.6)
                        .cornerRadius(cornerRadius)
                }
                
                CheckboxView(isSelected: isSelected)
                    .padding(4)
            }
            .frame(width: itemSize, height: itemSize, alignment: .topTrailing)
            .opacity(isSelected || viewState.isSelectionMode ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .animation(.easeInOut(duration: 0.2), value: viewState.isSelectionMode)
        }
        .frame(width: itemSize, height: itemSize)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .clipped()
        .onTapGesture {
            if viewState.isSelectionMode {
                viewState.toggleSelection(for: model)
            } else {
                chosenImageIndex = index
                chosenSection = section
            }
        }
        .onLongPressGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewState.isSelectionMode = true
                viewState.toggleSelection(for: model)
            }
        }
    }
}

// MARK: - Checkbox View
struct CheckboxView: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? CMColor.primary : CMColor.clear)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isSelected ? CMColor.primary : CMColor.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(CMColor.white)
                    .scaleEffect(isSelected ? 1.0 : 0.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}
