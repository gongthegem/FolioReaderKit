import Foundation
import SwiftUI
import Combine

class SpeedReadingViewModel: ObservableObject {
    private let progressManager: ReadingProgressManager?
    private let readingContentVM: ReadingContentViewModel?
    
    @Published var bookId: String?
    @Published var isPlaying: Bool = false
    @Published var wordsPerMinute: Int = 200
    @Published var currentSentenceIndex: Int = 0
    @Published var speedReadingMode: SpeedReaderMode = .sentence
    
    private var playbackTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(progressManager: ReadingProgressManager? = nil, readingContentVM: ReadingContentViewModel? = nil) {
        self.progressManager = progressManager
        self.readingContentVM = readingContentVM
        
        // Load saved WPM from UserDefaults
        self.wordsPerMinute = UserDefaults.standard.integer(forKey: "speedReaderWPM") 
        if self.wordsPerMinute == 0 {
            self.wordsPerMinute = 200 // Default
        }
        
        // Observe reading content view model changes
        self.readingContentVM?.$currentSentenceIndex
            .sink { [weak self] index in
                self?.currentSentenceIndex = index
            }
            .store(in: &cancellables)
    }
    
    func configure(with bookId: String, initialSentenceIndex: Int = 0) {
        self.bookId = bookId
        self.currentSentenceIndex = initialSentenceIndex
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        
        if isPlaying {
            startPlaybackTimer()
        } else {
            stopPlaybackTimer()
        }
    }
    
    func goToNextSentence() {
        guard let readingContentVM = readingContentVM else { return }
        
        if readingContentVM.moveToNextSentence() {
            currentSentenceIndex = readingContentVM.currentSentenceIndex
            saveProgress()
        } else {
            // We've reached the end of the chapter, stop playback
            stopPlaybackTimer()
        }
    }
    
    func goToPreviousSentence() {
        guard let readingContentVM = readingContentVM else { return }
        
        if readingContentVM.moveToPreviousSentence() {
            currentSentenceIndex = readingContentVM.currentSentenceIndex
            saveProgress()
        }
    }
    
    func adjustWPM(by amount: Int) {
        wordsPerMinute += amount
        
        // Keep WPM within reasonable limits
        wordsPerMinute = max(50, min(1000, wordsPerMinute))
        
        // Save to UserDefaults
        UserDefaults.standard.set(wordsPerMinute, forKey: "speedReaderWPM")
        
        // Restart timer if playing to apply new speed
        if isPlaying {
            stopPlaybackTimer()
            startPlaybackTimer()
        }
    }
    
    func saveProgress() {
        guard let bookId = bookId,
              let progressManager = progressManager else { return }
        
        if let readingContentVM = readingContentVM {
            progressManager.updateLastReadDate(bookId: bookId)
        }
    }
    
    private func startPlaybackTimer() {
        guard playbackTimer == nil else { return }
        
        let timeInterval = calculateTimeInterval()
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { [weak self] _ in
            self?.goToNextSentence()
        }
    }
    
    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
    }
    
    private func calculateTimeInterval() -> TimeInterval {
        guard let readingContentVM = readingContentVM,
              let sentence = readingContentVM.sentenceAtIndex(index: currentSentenceIndex) else {
            return 60.0 / Double(wordsPerMinute)
        }
        
        let wordCount = sentence.split(separator: " ").count
        let baseInterval = 60.0 / Double(wordsPerMinute)
        
        // Adjust time based on sentence length
        if speedReadingMode == .sentence {
            // For sentence mode, scale based on word count
            return max(0.5, baseInterval * Double(wordCount))
        } else {
            // For word mode, use fixed interval
            return baseInterval
        }
    }
} 