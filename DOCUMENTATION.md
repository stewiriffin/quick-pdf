# QuickPDF Application Documentation

## Overview
QuickPDF is a lightweight, offline-first Android/iOS utility app for PDF management designed for students, freelancers, and office workers. The app provides comprehensive PDF manipulation capabilities while maintaining user privacy through 100% offline processing.

## Data Flow Diagram
```
User Input → Isolate Processor → Storage/Database → UI Update
```

### Detailed Flow:
1. **User Input**: User interacts with UI (selects files, triggers actions)
2. **Isolate Processor**: Heavy PDF operations run in background isolates to prevent UI blocking
3. **Storage/Database**: 
   - Files stored in app's documents directory
   - Metadata stored in SQLite database (filename, size, dates, OCR text)
   - Temporary files managed and cleaned up
4. **UI Update**: Results displayed to user with appropriate feedback

## Required Permissions

### Camera Permission
- **Purpose**: Enable document scanning functionality
- **Usage**: Access device camera to capture images for PDF conversion
- **Privacy Note**: All image processing happens locally; no images are transmitted or stored externally

### Storage Permission
- **Purpose**: Read and write files to device storage
- **Usage**: 
  - Access existing PDFs and images for processing
  - Save generated PDFs to device
  - Store temporary files during processing
- **Privacy Note**: All file operations are local; no data leaves the device

## Core Components

### PDFManager (lib/core/pdf_manager.dart)
- Central service for all PDF operations
- Uses Flutter isolates for heavy processing to maintain UI responsiveness
- Handles:
  - Image-to-PDF conversion with A4 scaling
  - PDF merging
  - PDF compression
  - Password protection (basic encryption)
  - Metadata editing

### DocumentDatabase (lib/services/document_database.dart)
- SQLite-based local storage for document metadata
- Stores: filename, path, size, dates, OCR-extracted text
- Supports search by filename and OCR content
- Includes upgrade handling for schema changes

### OcrService (lib/services/ocr_service.dart)
- Uses google_mlkit_text_recognition for offline OCR
- Extracts text from images and PDF pages
- 100% offline processing - no data leaves device

### UI Components
- **HomeScreen**: Recent files list with search and file addition
- **ToolsScreen**: 3x2 grid for Scan, Convert, Merge, Compress, Extract Text, Security
- **PDFViewerScreen**: Full-featured PDF viewer with sharing
- **OnboardingScreen**: 3-slide introduction for first-time users
- **SettingsScreen**: Configuration, privacy policy, storage metrics, cache clearing

## Key Features

### Privacy & Security
- 100% offline processing - no data transmission
- Local storage only - no cloud dependencies
- Clear temporary cache function
- Comprehensive privacy policy

### Performance Optimization
- Isolate-based processing for heavy operations
- Memory safety checks (>50 files warning)
- Error boundaries to prevent crashes
- Haptic feedback for user interactions
- Loading overlays for long operations

### Search Functionality
- Global search across filename and OCR text
- Term highlighting in results
- Powered by SQLite FTS-like capabilities

### File Operations
- Scan: Camera integration with image enhancement
- Convert: Images to PDF with A4 scaling
- Merge: Combine multiple PDFs
- Compress: Reduce file size with quality slider
- Extract Text: OCR with editable results
- Security: Password protection and metadata editing

## Technical Specifications

### Dependencies
- flutter: SDK
- pdf: ^3.10.0 (PDF generation)
- printing: ^5.11.0 (PDF printing/preview)
- pdfx: ^2.0.0 (PDF viewing)
- pdf_render: ^1.1.5 (PDF thumbnails)
- google_mlkit_text_recognition: ^0.9.0 (offline OCR)
- file_picker: ^5.5.0 (file selection)
- path_provider: ^2.1.1 (file system access)
- sqflite: ^2.3.0 (local SQLite database)
- image: ^4.1.3 (image processing)
- camera: ^0.10.5+5 (camera access)
- share_plus: ^8.0.0 (sharing functionality)
- haptic_feedback: ^0.0.1 (haptic feedback)
- flutter_markdown: ^0.6.0 (privacy policy display)
- shared_preferences: ^2.2.0 (settings persistence)

### Android Configuration
- Minification enabled for release builds
- ProGuard rules for code shrinking and obfuscation
- Optimized for smallest possible APK size
- Targets modern Android APIs

## Security Considerations

### Data Protection
- All processing occurs locally on user device
- No data collection, transmission, or storage externally
- Temporary files automatically managed and cleaned
- Password protection uses basic encryption (suitable for light security)

### Permissions Justification
- **Camera**: Required for document scanning feature
- **Storage**: Required for file access and saving
- Both permissions are essential for core functionality and clearly explained in privacy policy

## Build & Release

### Versioning
- Current Version: 1.0.0+1
- Follows semantic versioning with build number

### Release Assets
- App icon generated via flutter_launcher_icons
- Android App Bundle (AAB) signed for distribution
- Optimized release build with minification

### Testing
- Unit tests for core PDFManager functionality
- Test coverage for:
  - Image-to-PDF conversion
  - PDF merging
  - Search functionality

## Maintenance

### Cache Management
- Temporary files automatically identified and cleaned
- User-initiated cache clearing in Settings
- Storage metrics display current usage

### Updates
- Backward compatible database schema changes
- Graceful handling of missing or corrupted files
- Comprehensive error boundaries throughout

## Contact & Support
For questions about this documentation or the QuickPDF application, please refer to the in-app support channels or contact the development team.

---
*Documentation generated as part of QuickPDF development process*
*Last updated: May 2026*