import SwiftUI

struct SpeedReaderView: View {
    @ObservedObject var speedReadingVM: SpeedReadingViewModel
    @ObservedObject var readingContentVM: ReadingContentViewModel
    
    var onShowSettings: () -> Void
    var onExit: () -> Void
    
    @State private var animateSentence = false
    
    var body: some View {
        ZStack {
            Color(readingContentVM.displayOptions.darkMode ? .black : .white)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onExit) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .padding()
                    }
                    
                    Spacer()
                    
                    Text("Speed Reading Mode")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: onShowSettings) {
                        Image(systemName: "gear")
                            .font(.title3)
                            .padding()
                    }
                }
                .padding(.horizontal)
                .background(Color(.systemBackground).opacity(0.9))
                
                Spacer()
                
                // Current sentence display
                VStack(spacing: 20) {
                    Text(getCurrentSentence())
                        .font(.system(size: readingContentVM.displayOptions.fontSize))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: .infinity)
                        .background(animateSentence ? Color.yellow.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                        .animation(.easeInOut(duration: 0.3), value: animateSentence)
                        .onAppear {
                            // Animate sentence on appear
                            withAnimation {
                                animateSentence = true
                            }
                            
                            // Reset after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation {
                                    animateSentence = false
                                }
                            }
                        }
                        .onChange(of: speedReadingVM.currentSentenceIndex) { _ in
                            // Animate sentence on change
                            withAnimation {
                                animateSentence = true
                            }
                            
                            // Reset after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation {
                                    animateSentence = false
                                }
                            }
                        }
                }
                .frame(height: 200)
                .background(Color(.systemBackground).opacity(0.05))
                
                Spacer()
                
                // Controls
                VStack(spacing: 20) {
                    // Speed control
                    HStack {
                        Button(action: { speedReadingVM.adjustWPM(by: -10) }) {
                            Image(systemName: "minus.circle")
                                .font(.title2)
                        }
                        
                        Spacer()
                        
                        Text("\(speedReadingVM.wordsPerMinute) WPM")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { speedReadingVM.adjustWPM(by: 10) }) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Playback controls
                    HStack(spacing: 30) {
                        Button(action: { speedReadingVM.goToPreviousSentence() }) {
                            Image(systemName: "backward.fill")
                                .font(.title2)
                        }
                        
                        Button(action: { speedReadingVM.togglePlayback() }) {
                            Image(systemName: speedReadingVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 60))
                        }
                        
                        Button(action: { speedReadingVM.goToNextSentence() }) {
                            Image(systemName: "forward.fill")
                                .font(.title2)
                        }
                    }
                    
                    // Progress indicator
                    ProgressBar(
                        value: Double(speedReadingVM.currentSentenceIndex),
                        total: Double(readingContentVM.totalSentences),
                        height: 6
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                .padding(.bottom, 20)
                .padding(.top, 10)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            // Set initial sentence from last position
            if let sentence = readingContentVM.sentenceAtIndex(index: speedReadingVM.currentSentenceIndex) {
                // Ready for speed reading
            }
        }
        .onDisappear {
            // Stop playback when view disappears
            if speedReadingVM.isPlaying {
                speedReadingVM.togglePlayback()
            }
        }
    }
    
    private func getCurrentSentence() -> String {
        return readingContentVM.sentenceAtIndex(index: speedReadingVM.currentSentenceIndex) ?? "No text available"
    }
}

struct ProgressBar: View {
    var value: Double
    var total: Double
    var height: CGFloat
    
    var progress: Double {
        return total > 0 ? min(max(value / total, 0.0), 1.0) : 0
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: height)
                    .opacity(0.3)
                    .foregroundColor(Color.gray)
                
                Rectangle()
                    .frame(width: geometry.size.width * CGFloat(progress), height: height)
                    .foregroundColor(Color.blue)
                    .animation(.linear, value: progress)
            }
            .cornerRadius(height / 2)
        }
        .frame(height: height)
    }
} 