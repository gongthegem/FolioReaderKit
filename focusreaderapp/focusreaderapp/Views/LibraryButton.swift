import SwiftUI

struct LibraryButton: View {
    var onExitToLibrary: () -> Void
    
    var body: some View {
        Button(action: onExitToLibrary) {
            HStack(spacing: 4) {
                Image(systemName: "books.vertical")
                    .font(.body)
                
                Text("Library")
                    .font(.body)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground).opacity(0.8))
            .cornerRadius(8)
            .shadow(radius: 2)
        }
        .foregroundColor(.primary)
    }
}

struct LibraryButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3).edgesIgnoringSafeArea(.all)
            LibraryButton(onExitToLibrary: {})
        }
    }
} 