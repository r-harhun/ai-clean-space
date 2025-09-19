import SwiftUI
import Photos

struct SimilaritySectionsView: View {
    @StateObject private var viewState: SimilaritySectionsViewModel
    @Environment(\.dismiss) private var viewDismiss
    @State private var chosenSection: AICleanServiceSection?
    @State private var chosenImageIndex: Int = 0

    init(viewModel: SimilaritySectionsViewModel) {
        _viewState = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    viewDismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Media")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(viewState.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CMColor.primaryText)
                
                Spacer()
                
                Button {
                    if viewState.hasSelectedItems {
                        viewState.deselectAll()
                    } else {
                        viewState.selectAll()
                    }
                } label: {
                    Text(viewState.hasSelectedItems ? "Deselect All" : "Select All")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(CMColor.backgroundSecondary)

            ZStack {
                ScrollView(.vertical) {
                    VStack(spacing: 32) {
                        ForEach(viewState.sections.indices, id: \.self) { index in
                            createSectionView(for: viewState.sections[index])
                        }
                    }
                    .padding(12)
                    .padding(.bottom, viewState.hasSelectedItems ? 100 : 0)
                }
                .background(CMColor.backgroundSecondary)

                VStack {
                    Spacer()
                    
                    if viewState.hasSelectedItems {
                        Button {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                viewState.deleteSelected()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Delete \(viewState.selectedCount) item\(viewState.selectedCount == 1 ? "" : "s")")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 34)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewState.hasSelectedItems)
            }
        }
        .background(CMColor.backgroundSecondary)
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
        LazyVStack(spacing: 12) {
            HStack(alignment: .center) {
                switch section.kind {
                case .count:
                    Text("\(section.models.count) items")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CMColor.primaryText)

                case .date(let date):
                    Text(date?.formatAsShortDate() ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CMColor.primaryText)

                case .united(let date):
                    Text(date?.formatAsShortDate() ?? "")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CMColor.primaryText)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if viewState.isAllSelectedInSection(section) {
                            viewState.deselectAllInSection(section)
                        } else {
                            viewState.selectAllInSection(section)
                        }
                    }
                } label: {
                    Text(viewState.isAllSelectedInSection(section) ? "Deselect all" : "Select all")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(viewState.isAllSelectedInSection(section) ? Color.red : CMColor.primaryText)
                }
            }

            LazyVStack(alignment: .leading, spacing: 8) {
                if viewState.type == .duplicates || viewState.type == .similar {
                    createPrimaryItemView(for: section)
                }

                let remainingModels = viewState.type == .duplicates || viewState.type == .similar ? Array(section.models.suffix(from: 1)) : section.models
                FlexibleWrappingHStack(remainingModels.indices) { index in
                    let model = remainingModels[index]
                    let actualIndex = viewState.type == .duplicates || viewState.type == .similar ? index + 1 : 0
                    createGalleryItemView(for: model, section: section, index: actualIndex)
                }
            }
        }
    }

    private func createPrimaryItemView(for section: AICleanServiceSection) -> some View {
        VStack {
            if let firstModel = section.models.first {
                Button {
                    chosenImageIndex = 0
                    chosenSection = section
                } label: {
                    ZStack {
                        firstModel.imageView(size: CGSize(width: 176, height: 176))
                        
                        if viewState.type == .videos {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                            
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text(firstModel.formattedDuration)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(8)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Rectangle()
                    .frame(width: 176, height: 176)
                    .foregroundStyle(Color.gray.opacity(0.3))
            }
        }
        .frame(width: 176, height: 176)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .clipped()
        .overlay {
            VStack {
                HStack {
                    Spacer()
                    
                    if let firstModel = section.models.first {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewState.toggleSelection(for: firstModel)
                                if !viewState.isSelectionMode {
                                    viewState.isSelectionMode = true
                                }
                            }
                        } label: {
                            CheckboxView(isSelected: viewState.isSelected(firstModel))
                        }
                    }
                }
                
                Spacer()

                HStack {
                    Text("Best")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CMColor.primaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(CMColor.border)
                        .clipShape(RoundedRectangle(cornerRadius: 15))

                    Spacer()
                }
            }
            .padding(12)
        }
        .scaleEffect(section.models.first.map { viewState.isSelected($0) } ?? false ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: section.models.first.map { viewState.isSelected($0) } ?? false)
    }

    private func createGalleryItemView(for model: AICleanServiceModel, section: AICleanServiceSection, index: Int) -> some View {
        let itemSize = (UIScreen.main.bounds.width - 24 - 24 - 16) / 4

        return Button {
            chosenImageIndex = index
            chosenSection = section
        } label: {
            VStack {
                ZStack {
                    model.imageView(
                        size: CGSize(width: itemSize, height: itemSize)
                    )
                    
                    if viewState.type == .videos {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                        
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(model.formattedDuration)
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        .padding(3)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: itemSize, height: itemSize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .clipped()
        .overlay(
            VStack {
                HStack {
                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewState.toggleSelection(for: model)
                            if !viewState.isSelectionMode {
                                viewState.isSelectionMode = true
                            }
                        }
                    } label: {
                        CheckboxView(isSelected: viewState.isSelected(model))
                            .scaleEffect(0.8)
                    }
                }
                Spacer()
            }
            .padding(4)
        )
        .scaleEffect(viewState.isSelected(model) ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: viewState.isSelected(model))
    }
}

struct CheckboxView: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color.clear)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(isSelected ? 1.0 : 0.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}
