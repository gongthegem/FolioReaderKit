import SwiftUI

// Base class with common navigation functionality
struct BaseNavigationControls: View {
    var onPrevious: () -> Void
    var onNext: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .padding()
            }
            
            Spacer()
            
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .padding()
            }
        }
    }
}

// Standard navigation controls for regular reading
struct StandardNavigationControls: View {
    var currentIndex: Int
    var totalCount: Int
    var onPrevious: () -> Void
    var onNext: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .padding()
            }
            .disabled(currentIndex <= 0)
            .opacity(currentIndex > 0 ? 1.0 : 0.3)
            
            Spacer()
            
            // Progress indicator
            Text("Chapter \(currentIndex + 1) of \(totalCount)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .padding()
            }
            .disabled(currentIndex >= totalCount - 1)
            .opacity(currentIndex < totalCount - 1 ? 1.0 : 0.3)
        }
        .padding(.horizontal)
        .background(Color(.systemBackground).opacity(0.9))
    }
}

// Inline highlight controls for sentence navigation
struct InlineHighlightControls: View {
    var currentSentenceIndex: Int
    var totalSentences: Int
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onExitHighlightMode: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .padding()
                }
                .disabled(currentSentenceIndex <= 0)
                .opacity(currentSentenceIndex > 0 ? 1.0 : 0.3)
                
                Spacer()
                
                Text("Sentence \(currentSentenceIndex + 1) of \(totalSentences)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .padding()
                }
                .disabled(currentSentenceIndex >= totalSentences - 1)
                .opacity(currentSentenceIndex < totalSentences - 1 ? 1.0 : 0.3)
            }
            .padding(.horizontal)
            
            Button(action: onExitHighlightMode) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Exit Highlight Mode")
                }
                .padding(10)
                .background(Color(.systemBackground).opacity(0.1))
                .cornerRadius(8)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .frame(width: geometry.size.width, height: 6)
                        .opacity(0.3)
                        .foregroundColor(Color.gray)
                    
                    Rectangle()
                        .frame(width: geometry.size.width * progress, height: 6)
                        .foregroundColor(Color.blue)
                }
                .cornerRadius(3)
            }
            .frame(height: 6)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.9))
    }
    
    private var progress: CGFloat {
        return totalSentences > 0 
            ? CGFloat(min(max(Double(currentSentenceIndex) / Double(totalSentences - 1), 0.0), 1.0)) 
            : 0
    }
}

struct NavigationControls_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            StandardNavigationControls(
                currentIndex: 2,
                totalCount: 5,
                onPrevious: {},
                onNext: {}
            )
            
            InlineHighlightControls(
                currentSentenceIndex: 7,
                totalSentences: 20,
                onPrevious: {},
                onNext: {},
                onExitHighlightMode: {}
            )
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.gray.opacity(0.1))
    }
} 