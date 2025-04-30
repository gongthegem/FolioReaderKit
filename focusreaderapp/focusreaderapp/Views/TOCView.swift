import SwiftUI

struct TOCView: View {
    var tocItems: [TocItem]
    var currentChapterIndex: Int
    var onChapterSelected: (Int) -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Text("Table of Contents")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                }
            }
            .padding()
            
            List {
                ForEach(tocItems) { item in
                    TOCItemRow(
                        item: item,
                        isCurrentChapter: item.chapterIndex == currentChapterIndex,
                        onTap: {
                            if let chapterIndex = item.chapterIndex {
                                onChapterSelected(chapterIndex)
                            }
                        }
                    )
                }
            }
        }
    }
}

struct TOCItemRow: View {
    var item: TocItem
    var isCurrentChapter: Bool
    var onTap: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(isCurrentChapter ? .headline : .body)
                    .foregroundColor(isCurrentChapter ? .blue : .primary)
                
                if item.level > 0 {
                    Text("Section")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isCurrentChapter {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

struct NavigationControls: View {
    var showPrevious: Bool
    var showNext: Bool
    var onPrevious: () -> Void
    var onNext: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .padding()
            }
            .disabled(!showPrevious)
            .opacity(showPrevious ? 1.0 : 0.3)
            
            Spacer()
            
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .padding()
            }
            .disabled(!showNext)
            .opacity(showNext ? 1.0 : 0.3)
        }
    }
} 