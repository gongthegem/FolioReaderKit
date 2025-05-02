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

# Focus Reader App - Architecture Diagrams

This directory contains architecture diagrams showing different parts of the Focus Reader App, including the proposed persistence enhancements for book storage.

## Overview

The app is designed around a clean architecture with well-defined layers and responsibilities. The key enhancement is a persistent storage mechanism for extracted EPUB files, which eliminates the need to re-extract and re-parse books on each app launch.

## Diagrams

1. **Architecture Overview** - [architecture-overview.md](architecture-overview.md)
   * High-level overview of the major components and their relationships

2. **Core Services** - [core-services.md](core-services.md)
   * EPUB parsing and extraction services

3. **Storage Services** - [storage-services.md](storage-services.md)
   * Persistent storage for books and reading progress

4. **Data Models** - [data-models.md](data-models.md)
   * Core data structures for books, chapters, and content

5. **Content Processing** - [content-processing.md](content-processing.md)
   * Services for transforming and rendering book content

6. **ViewModels** - [view-models.md](view-models.md)
   * Business logic and state management

7. **Views** - [views.md](views.md)
   * UI components and their relationships

8. **Book Loading Flow** - [book-loading-flow.md](book-loading-flow.md)
   * Sequence diagram showing how books are loaded with persistence

## Key Changes for Persistence

The main enhancement is adding a `BookStorageService` that:

1. Stores extracted EPUB files in a persistent location
2. Maintains book metadata separately for quick access
3. Checks if a book is already extracted before processing it again
4. Provides a clean API for saving and retrieving books

This significantly improves performance by:
- Eliminating repeated extraction of EPUB files
- Reducing parsing time on subsequent app launches
- Maintaining a consistent location for book assets

## Implementation Note

To implement these changes, you'll need to:

1. Create the new storage service classes
2. Update the EPUB service to use the storage
3. Modify the BookViewModel to integrate with the storage service
4. Update the app initialization to connect all the components

The diagrams and code provide a blueprint for these changes while maintaining the existing app architecture. 
