# focusreaderapp

focusreaderapp is a powerful EPUB reader app with a focus on providing both standard reading and speed reading experiences. It's built using SwiftUI and follows a clean architecture pattern for maintainability and extensibility.

## Features

- **EPUB Support**: Easily import and read EPUB files.
- **Library Management**: Organize and manage your book collection.
- **Standard Reading Mode**: Traditional reading experience with customizable display settings.
- **Speed Reading Mode**: Enhance your reading speed with a focused, sentence-by-sentence reading experience.
- **Customizable Settings**: Adjust font size, line spacing, margins, and theme.
- **Reading Progress Tracking**: Remember your position in each book.
- **Table of Contents**: Navigate books easily using their built-in structure.

## Architecture

FocusReader uses a modular architecture following SOLID principles:

- **Core Services Layer**: Handles EPUB file parsing, extraction, and processing.
- **Models Layer**: Defines the domain models for books, chapters, and reading positions.
- **Content Processing Layer**: Manages the transformation of EPUB content for display.
- **ViewModels Layer**: Connects the services layer with the UI, managing application state.
- **Views Layer**: Provides the user interface using SwiftUI.

## Getting Started

### Requirements

- Xcode 13 or later
- Swift 5.5 or later
- iOS 15 or later (for deployment)

### Building the Project

1. Clone the repository
2. Open the project in Xcode
3. Build and run the app on a simulator or device

## Usage

1. Launch FocusReader
2. Tap the "+" button to import an EPUB file
3. Select a book from your library to start reading
4. Use the controls at the bottom to navigate through chapters
5. Tap the speed gauge icon to switch to Speed Reading mode
6. Adjust settings using the gear icon

## Dependencies

- **SwiftSoup**: HTML parsing and manipulation
- **ZIPFoundation**: ZIP file handling for EPUB extraction

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
