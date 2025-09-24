# RMUTT Social

A comprehensive Flutter social media application with Firebase integration, designed for the RMUTT community.

## Features

### 🔐 Authentication
- Email/password authentication
- Google Sign-in integration
- Secure user registration and login
- Automatic session management

### 👤 User Profiles
- Customizable profile editing
- Display name and bio management
- Profile picture upload
- Privacy settings (public/private accounts)
- Account information display

### 📝 Post Creation & Management
- Rich text post creation
- Multiple image and video uploads
- Progress indicators during upload
- Media carousel display
- Form validation and error handling

### 📱 Social Feed
- Real-time post streaming from Firestore
- Infinite scroll with pagination
- Pull-to-refresh functionality
- Media carousel for posts with multiple images/videos
- Timestamp formatting (relative and absolute)

### 💬 Post Interactions
- Like/unlike posts with optimistic updates
- Emoji reactions (Love, Laugh, Wow, Sad, Angry)
- Comment system with real-time updates
- Nested comment threading
- User profile display in interactions

### 💬 Chat System
- 1-on-1 messaging with real-time updates
- Image sharing in chats
- Message bubbles with sender identification
- Timestamp display
- User search functionality to start new conversations

### 🎨 UI/UX
- Material 3 design system
- Responsive layout
- Loading states and error handling
- Intuitive navigation with bottom navigation bar
- Clean and modern interface

## Technical Stack

### Frontend
- **Flutter 3.8.1+** - Cross-platform mobile framework
- **Material 3** - Google's latest design system

### Backend & Services
- **Firebase Core** - Firebase SDK initialization
- **Firebase Auth** - User authentication
- **Cloud Firestore** - Real-time NoSQL database
- **Firebase Storage** - File storage for images and videos
- **Google Sign-In** - OAuth authentication

### State Management & Utilities
- **Provider** - State management
- **Cached Network Image** - Efficient image loading and caching
- **Image Picker** - Camera and gallery access
- **Video Player** - Video playback support
- **Intl** - Internationalization and date formatting

## Project Structure

```
lib/
├── main.dart                 # App entry point with Firebase initialization
├── services/
│   └── firebase_service.dart # Firebase operations service
├── screens/
│   ├── login_screen.dart     # Authentication UI
│   ├── home_screen.dart      # Main navigation hub
│   ├── feed_screen.dart      # Social media feed
│   ├── create_post.dart      # Post creation interface
│   ├── profile_edit.dart     # Profile editing
│   ├── comments_screen.dart  # Comments interface
│   ├── chat_screen.dart      # 1-on-1 messaging
│   └── user_search_screen.dart # User search for chat
└── widgets/
    └── post_actions.dart     # Post interaction buttons
```

## Getting Started

### Prerequisites
- Flutter SDK 3.8.1 or higher
- Dart SDK
- Firebase project setup
- Android Studio / VS Code with Flutter extensions

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd rmutt_social
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password and Google Sign-in)
   - Create a Firestore database
   - Set up Firebase Storage
   - Download and add configuration files:
     - `android/app/google-services.json` for Android
     - `ios/Runner/GoogleService-Info.plist` for iOS

4. **Run the application**
   ```bash
   flutter run
   ```

### Firebase Security Rules

#### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Posts are readable by all authenticated users
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == get(/databases/$(database)/documents/posts/$(postId)).data.userId;
      
      // Reactions subcollection
      match /reactions/{reactionId} {
        allow read, write: if request.auth != null;
      }
      
      // Comments subcollection
      match /comments/{commentId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == resource.data.userId;
      }
    }
    
    // Conversations for authenticated users
    match /conversations/{conversationId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
      
      match /messages/{messageId} {
        allow read, write: if request.auth != null && 
          request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participants;
      }
    }
  }
}
```

#### Storage Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_images/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /post_media/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## App Architecture

### Authentication Flow
1. App starts with `AuthGate` checking user authentication state
2. Unauthenticated users see `LoginScreen`
3. Authenticated users navigate to `HomeScreen`
4. Firebase handles session persistence automatically

### Data Models

#### User Document
```dart
{
  'uid': String,
  'email': String,
  'displayName': String,
  'photoURL': String?,
  'bio': String,
  'isPrivate': bool,
  'createdAt': Timestamp,
  'updatedAt': Timestamp,
}
```

#### Post Document
```dart
{
  'userId': String,
  'userDisplayName': String,
  'userPhotoURL': String?,
  'content': String,
  'mediaUrls': List<String>,
  'likesCount': int,
  'commentsCount': int,
  'createdAt': Timestamp,
}
```

#### Comment Document
```dart
{
  'userId': String,
  'userDisplayName': String,
  'userPhotoURL': String?,
  'content': String,
  'createdAt': Timestamp,
}
```

#### Message Document
```dart
{
  'senderId': String,
  'senderName': String,
  'content': String,
  'mediaUrl': String?,
  'createdAt': Timestamp,
}
```

## Development Guidelines

### Code Organization
- Follow Flutter/Dart naming conventions
- Use meaningful variable and function names
- Implement proper error handling
- Add comments for complex logic
- Maintain consistent code formatting

### Performance Considerations
- Implement pagination for large data sets
- Use cached network images for better performance
- Optimize database queries with proper indexing
- Implement lazy loading where appropriate

### Security Best Practices
- Validate all user inputs
- Implement proper Firebase security rules
- Handle authentication state changes
- Sanitize data before storage

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support and questions, please contact the development team or create an issue in the repository.

---

Built with ❤️ for the RMUTT community
