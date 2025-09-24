# RMUTT Social - Deployment Guide

This guide will help you deploy the complete RMUTT Social app to production.

## 📋 Prerequisites

Before starting deployment, ensure you have:

1. **Flutter SDK 3.8.1+** installed
2. **Firebase CLI** installed (`npm install -g firebase-tools`)
3. **Firebase project** created with:
   - Authentication enabled (Email/Password, Google)
   - Firestore database created
   - Storage bucket configured
   - Cloud Functions enabled (Blaze plan required)
4. **Google Services files** for Android and iOS
5. **Admin access** to your Firebase project

## 🚀 Step-by-Step Deployment

### 1. Firebase Project Setup

#### Create Firebase Project
```bash
firebase login
firebase projects:list
firebase use your-project-id
```

#### Initialize Firebase Services
```bash
firebase init
# Select: Firestore, Functions, Storage, Hosting (optional)
```

### 2. Configure Authentication

1. Go to Firebase Console → Authentication → Sign-in method
2. Enable **Email/Password** provider
3. Enable **Google** provider:
   - Add your app's SHA-1 fingerprint for Android
   - Configure OAuth consent screen

### 3. Deploy Security Rules

#### Firestore Rules
```bash
firebase deploy --only firestore:rules
```

#### Storage Rules
```bash
firebase deploy --only storage
```

### 4. Deploy Cloud Functions

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

#### Key Functions Deployed:
- `onPostLiked` - Notification when posts are liked
- `onCommentCreated` - Notification for new comments
- `onFollowRequestCreated` - Follow request notifications
- `onGroupMemberAdded` - Group invitation notifications
- `moderateContent` - Auto-hide reported content
- `cleanupOldNotifications` - Scheduled cleanup task
- `getUserAnalytics` - Admin analytics

### 5. Configure App for Production

#### Update Firebase Configuration
1. **Android**: Place `google-services.json` in `android/app/`
2. **iOS**: Place `GoogleService-Info.plist` in `ios/Runner/`

#### Update App Configuration
In `lib/main.dart`, ensure Firebase is properly initialized:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### 6. Build and Deploy Mobile App

#### Android APK/AAB
```bash
# Build APK for testing
flutter build apk --release

# Build AAB for Play Store
flutter build appbundle --release
```

#### iOS IPA
```bash
# Build for iOS
flutter build ios --release

# Create archive in Xcode for App Store
```

### 7. Initial Data Setup

#### Create Admin Users
After deployment, manually add admin users in Firestore:

```javascript
// In Firebase Console → Firestore
users/{adminUserId} {
  displayName: "Admin Name",
  email: "admin@example.com",
  role: "admin",
  createdAt: timestamp,
  // ... other user fields
}
```

#### Initialize Collections
The app will automatically create necessary collections, but you can pre-populate:

1. **Tags Collection** - For popular hashtags
2. **System Notifications** - Welcome messages
3. **Default Groups** - Community groups

### 8. Configure Push Notifications

#### Firebase Cloud Messaging Setup
1. Go to Firebase Console → Cloud Messaging
2. Generate server key for backend integration
3. Configure APNs certificates for iOS

#### Test Notifications
```bash
# Test using Firebase Functions
firebase functions:shell
> onPostLiked({postId: "test", userId: "testUser"})
```

### 9. Performance Optimization

#### Firestore Indexes
Deploy custom indexes for complex queries:
```bash
firebase deploy --only firestore:indexes
```

Key indexes needed:
- `posts` by `createdAt` (descending)
- `comments` by `postId` and `createdAt`
- `reports` by `status` and `createdAt`
- `notifications` by `userId` and `createdAt`

#### Storage Optimization
Configure storage rules for file size limits and allowed file types.

### 10. Monitoring and Analytics

#### Set up Firebase Performance Monitoring
```dart
// In main.dart
await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
```

#### Configure Crashlytics
```dart
// In main.dart
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
```

## 🔧 Production Configuration

### Environment Variables
Set these in your Firebase project:

```javascript
// Firebase Functions environment
functions.config().set({
  app: {
    admin_email: "admin@yourapp.com",
    moderator_emails: "mod1@app.com,mod2@app.com"
  },
  fcm: {
    server_key: "your-fcm-server-key"
  }
});
```

### App Store Configuration

#### Android (Google Play)
1. **App Bundle**: Upload the `.aab` file
2. **App Signing**: Let Google manage app signing
3. **Privacy Policy**: Required for social apps
4. **Content Rating**: Set appropriate rating
5. **Permissions**: Review and justify all permissions

#### iOS (App Store)
1. **Privacy Manifest**: Configure data collection disclosure
2. **App Transport Security**: Ensure HTTPS only
3. **Background Modes**: Configure for notifications
4. **In-App Purchases**: If implementing premium features

## 📊 Production Monitoring

### Key Metrics to Monitor
- Daily/Monthly Active Users
- Post engagement rates
- Chat message volume
- Report submission rates
- Function execution times
- Database read/write operations

### Alerts Setup
Configure alerts for:
- High error rates in Cloud Functions
- Excessive database usage
- Storage quota approaching limits
- Unusual report activity
- Authentication failures

## 🔒 Security Checklist

- [ ] **Security Rules Deployed** - Firestore and Storage rules active
- [ ] **Admin Users Created** - At least one admin account set up
- [ ] **Rate Limiting** - Implement client-side rate limiting for posts/comments
- [ ] **Content Validation** - Server-side validation in Cloud Functions
- [ ] **Backup Strategy** - Configure Firestore exports
- [ ] **SSL Certificates** - Ensure all connections use HTTPS
- [ ] **API Keys** - Restrict API keys to necessary services only

## 🆘 Troubleshooting

### Common Issues

#### Authentication Issues
```bash
# Check if Google Sign-In is properly configured
flutter clean
flutter pub get
```

#### Cloud Functions Deployment Fails
```bash
# Check Node.js version (should be 18)
node --version

# Clear functions cache
firebase functions:delete --force
firebase deploy --only functions
```

#### Firestore Permission Denied
- Verify security rules are deployed
- Check user authentication status
- Ensure proper role-based access

#### Push Notifications Not Working
- Verify FCM token generation
- Check Cloud Functions logs
- Ensure proper APNs configuration for iOS

### Performance Issues

#### Slow Query Performance
- Add composite indexes for complex queries
- Implement pagination for large result sets
- Use subcollections for hierarchical data

#### Storage Costs
- Implement image compression
- Set up lifecycle policies for old files
- Monitor storage usage regularly

## 📱 Post-Deployment Tasks

1. **User Testing**: Conduct thorough testing with real users
2. **Content Moderation**: Set up moderation workflows
3. **Community Guidelines**: Publish clear community rules
4. **Support System**: Set up user support channels
5. **Analytics Review**: Monitor app performance and user behavior
6. **Regular Updates**: Plan for feature updates and bug fixes

## 🎯 Success Metrics

Track these KPIs after deployment:
- User registration and retention rates
- Daily active users (DAU)
- Post and comment engagement
- Chat message volume
- Report resolution time
- App store ratings and reviews

---

**Deployment Complete! 🎉**

Your RMUTT Social app is now ready for production use with all advanced features enabled.