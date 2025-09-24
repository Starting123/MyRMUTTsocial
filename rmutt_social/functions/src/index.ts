import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Notification trigger when a post is liked
export const onPostLiked = functions.firestore
  .document("likes/{likeId}")
  .onCreate(async (snap, context) => {
    const likeData = snap.data();
    const postId = likeData.postId;
    const likerId = likeData.userId;

    try {
      // Get post data
      const postDoc = await db.collection("posts").doc(postId).get();
      if (!postDoc.exists) return;

      const postData = postDoc.data()!;
      const postOwnerId = postData.userId;

      // Don't notify if user liked their own post
      if (likerId === postOwnerId) return;

      // Get post owner data for notification
      const ownerDoc = await db.collection("users").doc(postOwnerId).get();
      if (!ownerDoc.exists) return;

      const ownerData = ownerDoc.data()!;

      // Get liker data
      const likerDoc = await db.collection("users").doc(likerId).get();
      if (!likerDoc.exists) return;

      const likerData = likerDoc.data()!;

      // Create notification
      await db
        .collection("notifications")
        .doc(postOwnerId)
        .collection("userNotifications")
        .add({
          type: "like",
          message: `${likerData.displayName} liked your post`,
          postId: postId,
          fromUserId: likerId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Send push notification if user has FCM token
      if (ownerData.fcmToken) {
        await messaging.send({
          token: ownerData.fcmToken,
          notification: {
            title: "New Like",
            body: `${likerData.displayName} liked your post`,
          },
          data: {
            type: "like",
            postId: postId,
            fromUserId: likerId,
          },
        });
      }

      console.log(`Notification sent for post like: ${postId}`);
    } catch (error) {
      console.error("Error sending like notification:", error);
    }
  });

// Notification trigger when a comment is created
export const onCommentCreated = functions.firestore
  .document("comments/{commentId}")
  .onCreate(async (snap, context) => {
    const commentData = snap.data();
    const postId = commentData.postId;
    const commenterId = commentData.userId;

    try {
      // Get post data
      const postDoc = await db.collection("posts").doc(postId).get();
      if (!postDoc.exists) return;

      const postData = postDoc.data()!;
      const postOwnerId = postData.userId;

      // Don't notify if user commented on their own post
      if (commenterId === postOwnerId) return;

      // Get post owner data
      const ownerDoc = await db.collection("users").doc(postOwnerId).get();
      if (!ownerDoc.exists) return;

      const ownerData = ownerDoc.data()!;

      // Get commenter data
      const commenterDoc = await db.collection("users").doc(commenterId).get();
      if (!commenterDoc.exists) return;

      const commenterData = commenterDoc.data()!;

      // Create notification
      await db
        .collection("notifications")
        .doc(postOwnerId)
        .collection("userNotifications")
        .add({
          type: "comment",
          message: `${commenterData.displayName} commented on your post`,
          postId: postId,
          commentId: context.params.commentId,
          fromUserId: commenterId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Send push notification
      if (ownerData.fcmToken) {
        await messaging.send({
          token: ownerData.fcmToken,
          notification: {
            title: "New Comment",
            body: `${commenterData.displayName} commented: ${commentData.content.substring(0, 50)}${commentData.content.length > 50 ? "..." : ""}`,
          },
          data: {
            type: "comment",
            postId: postId,
            commentId: context.params.commentId,
            fromUserId: commenterId,
          },
        });
      }

      // Update post comment count
      await postDoc.ref.update({
        commentsCount: admin.firestore.FieldValue.increment(1),
      });

      console.log(`Notification sent for comment: ${context.params.commentId}`);
    } catch (error) {
      console.error("Error sending comment notification:", error);
    }
  });

// Notification trigger when a follow request is created
export const onFollowRequestCreated = functions.firestore
  .document("followRequests/{requestId}")
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const fromUserId = requestData.fromUserId;
    const toUserId = requestData.toUserId;

    try {
      // Get requester data
      const requesterDoc = await db.collection("users").doc(fromUserId).get();
      if (!requesterDoc.exists) return;

      const requesterData = requesterDoc.data()!;

      // Get target user data
      const targetDoc = await db.collection("users").doc(toUserId).get();
      if (!targetDoc.exists) return;

      const targetData = targetDoc.data()!;

      // Create notification
      await db
        .collection("notifications")
        .doc(toUserId)
        .collection("userNotifications")
        .add({
          type: "follow_request",
          message: `${requesterData.displayName} wants to follow you`,
          fromUserId: fromUserId,
          requestId: context.params.requestId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      // Send push notification
      if (targetData.fcmToken) {
        await messaging.send({
          token: targetData.fcmToken,
          notification: {
            title: "New Follow Request",
            body: `${requesterData.displayName} wants to follow you`,
          },
          data: {
            type: "follow_request",
            fromUserId: fromUserId,
            requestId: context.params.requestId,
          },
        });
      }

      console.log(`Follow request notification sent: ${context.params.requestId}`);
    } catch (error) {
      console.error("Error sending follow request notification:", error);
    }
  });

// Notification trigger when a user is added to a group
export const onGroupMemberAdded = functions.firestore
  .document("groups/{groupId}")
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if members array was updated
    const beforeMembers = beforeData.members || [];
    const afterMembers = afterData.members || [];

    const newMembers = afterMembers.filter((member: string) => !beforeMembers.includes(member));

    if (newMembers.length === 0) return;

    const groupId = context.params.groupId;

    try {
      // Send notification to each new member
      for (const memberId of newMembers) {
        // Get member data
        const memberDoc = await db.collection("users").doc(memberId).get();
        if (!memberDoc.exists) continue;

        const memberData = memberDoc.data()!;

        // Create notification
        await db
          .collection("notifications")
          .doc(memberId)
          .collection("userNotifications")
          .add({
            type: "group_invite",
            message: `You were added to the group "${afterData.name}"`,
            groupId: groupId,
            read: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

        // Send push notification
        if (memberData.fcmToken) {
          await messaging.send({
            token: memberData.fcmToken,
            notification: {
              title: "Added to Group",
              body: `You were added to "${afterData.name}"`,
            },
            data: {
              type: "group_invite",
              groupId: groupId,
            },
          });
        }
      }

      console.log(`Group member notifications sent for: ${groupId}`);
    } catch (error) {
      console.error("Error sending group member notifications:", error);
    }
  });

// Clean up likes when a post is deleted
export const onPostDeleted = functions.firestore
  .document("posts/{postId}")
  .onDelete(async (snap, context) => {
    const postId = context.params.postId;

    try {
      // Delete all likes for this post
      const likesQuery = await db.collection("likes").where("postId", "==", postId).get();
      const batch = db.batch();

      likesQuery.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      // Delete all comments for this post
      const commentsQuery = await db.collection("comments").where("postId", "==", postId).get();
      const commentsBatch = db.batch();

      commentsQuery.docs.forEach((doc) => {
        commentsBatch.delete(doc.ref);
      });

      await commentsBatch.commit();

      console.log(`Cleaned up data for deleted post: ${postId}`);
    } catch (error) {
      console.error("Error cleaning up deleted post:", error);
    }
  });

// Moderate content based on report count
export const moderateContent = functions.firestore
  .document("reports/{reportId}")
  .onCreate(async (snap, context) => {
    const reportData = snap.data();
    const reportType = reportData.reportType;
    const reportedId = reportData.reportedId;

    try {
      let contentRef;
      let collection: string;

      switch (reportType) {
        case "post":
          collection = "posts";
          contentRef = db.collection("posts").doc(reportedId);
          break;
        case "comment":
          collection = "comments";
          contentRef = db.collection("comments").doc(reportedId);
          break;
        case "user":
          collection = "users";
          contentRef = db.collection("users").doc(reportedId);
          break;
        default:
          return;
      }

      const contentDoc = await contentRef.get();
      if (!contentDoc.exists) return;

      const contentData = contentDoc.data()!;
      const reportCount = contentData.reportCount || 0;

      // Auto-hide content if it gets 5 or more reports
      if (reportCount >= 5 && !contentData.isHidden) {
        await contentRef.update({
          isHidden: true,
          hiddenAt: admin.firestore.FieldValue.serverTimestamp(),
          hiddenReason: "Multiple reports - auto-moderated",
        });

        // Create notification for admins
        const adminsQuery = await db.collection("users").where("role", "==", "admin").get();
        
        for (const adminDoc of adminsQuery.docs) {
          await db
            .collection("notifications")
            .doc(adminDoc.id)
            .collection("userNotifications")
            .add({
              type: "moderation",
              message: `Content auto-hidden due to multiple reports (${reportType}: ${reportedId})`,
              reportType: reportType,
              reportedId: reportedId,
              read: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }

        console.log(`Auto-moderated ${reportType}: ${reportedId} (${reportCount} reports)`);
      }
    } catch (error) {
      console.error("Error in content moderation:", error);
    }
  });

// Update user stats when posts are created/deleted
export const updateUserStats = functions.firestore
  .document("posts/{postId}")
  .onCreate(async (snap, context) => {
    const postData = snap.data();
    const userId = postData.userId;

    try {
      await db.collection("users").doc(userId).update({
        postsCount: admin.firestore.FieldValue.increment(1),
      });

      console.log(`Updated post count for user: ${userId}`);
    } catch (error) {
      console.error("Error updating user stats:", error);
    }
  });

// Update tag popularity when posts are created
export const updateTagStats = functions.firestore
  .document("posts/{postId}")
  .onCreate(async (snap, context) => {
    const postData = snap.data();
    const tags = postData.tags || [];

    if (tags.length === 0) return;

    try {
      const batch = db.batch();

      for (const tag of tags) {
        const tagRef = db.collection("tags").doc(tag.toLowerCase());
        
        // Use set with merge to create the document if it doesn't exist
        batch.set(tagRef, {
          name: tag.toLowerCase(),
          postCount: admin.firestore.FieldValue.increment(1),
          lastUsed: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      await batch.commit();
      console.log(`Updated tag stats for: ${tags.join(", ")}`);
    } catch (error) {
      console.error("Error updating tag stats:", error);
    }
  });

// Scheduled function to clean up old notifications (runs daily)
export const cleanupOldNotifications = functions.pubsub
  .schedule("0 2 * * *") // Run at 2 AM daily
  .timeZone("Asia/Bangkok")
  .onRun(async (context) => {
    try {
      // Delete notifications older than 30 days
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const usersQuery = await db.collection("users").get();
      let deletedCount = 0;

      for (const userDoc of usersQuery.docs) {
        const notificationsQuery = await db
          .collection("notifications")
          .doc(userDoc.id)
          .collection("userNotifications")
          .where("createdAt", "<", thirtyDaysAgo)
          .get();

        const batch = db.batch();
        notificationsQuery.docs.forEach((doc) => {
          batch.delete(doc.ref);
          deletedCount++;
        });

        if (notificationsQuery.docs.length > 0) {
          await batch.commit();
        }
      }

      console.log(`Cleaned up ${deletedCount} old notifications`);
    } catch (error) {
      console.error("Error cleaning up notifications:", error);
    }
  });

// HTTP function to get user analytics (for admins)
export const getUserAnalytics = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated and is an admin
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
  }

  try {
    const userDoc = await db.collection("users").doc(context.auth.uid).get();
    if (!userDoc.exists || userDoc.data()!.role !== "admin") {
      throw new functions.https.HttpsError("permission-denied", "User must be an admin");
    }

    // Get user statistics
    const usersQuery = await db.collection("users").get();
    const postsQuery = await db.collection("posts").get();
    const commentsQuery = await db.collection("comments").get();
    const groupsQuery = await db.collection("groups").get();
    const reportsQuery = await db.collection("reports").get();

    // Calculate active users (users who posted in the last 7 days)
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const recentPostsQuery = await db
      .collection("posts")
      .where("createdAt", ">=", sevenDaysAgo)
      .get();

    const activeUserIds = new Set(recentPostsQuery.docs.map(doc => doc.data().userId));

    // Calculate pending reports
    const pendingReportsQuery = await db
      .collection("reports")
      .where("status", "==", "pending")
      .get();

    return {
      totalUsers: usersQuery.size,
      totalPosts: postsQuery.size,
      totalComments: commentsQuery.size,
      totalGroups: groupsQuery.size,
      totalReports: reportsQuery.size,
      activeUsers: activeUserIds.size,
      pendingReports: pendingReportsQuery.size,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
  } catch (error) {
    console.error("Error getting user analytics:", error);
    throw new functions.https.HttpsError("internal", "Error retrieving analytics");
  }
});