import SwiftUI

struct SwipedPhotoModel: Identifiable {
    let id = UUID()
    let sections: [MediaCleanerServiceSection]
    let type: ScanItemType
}
