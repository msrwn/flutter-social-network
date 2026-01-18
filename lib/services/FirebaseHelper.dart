import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/main.dart';
import 'package:flutter_social_network/model/BlockUserModel.dart';
import 'package:flutter_social_network/model/ChannelParticipation.dart';
import 'package:flutter_social_network/model/ChatModel.dart';
import 'package:flutter_social_network/model/ChatVideoContainer.dart';
import 'package:flutter_social_network/model/ContactModel.dart';
import 'package:flutter_social_network/model/ConversationModel.dart';
import 'package:flutter_social_network/model/HomeConversationModel.dart';
import 'package:flutter_social_network/model/MessageData.dart';
import 'package:flutter_social_network/model/NotificationModel.dart';
import 'package:flutter_social_network/model/PostModel.dart';
import 'package:flutter_social_network/model/SocialCommentModel.dart';
import 'package:flutter_social_network/model/SocialReactionModel.dart';
import 'package:flutter_social_network/model/StoryModel.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/reauthScreen/reauth_user_screen.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as Path;
import 'package:path_provider/path_provider.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart' as apple;
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class FireStoreUtils {
  static FirebaseMessaging firebaseMessaging = FirebaseMessaging.instance;
  static FirebaseFirestore firestore = FirebaseFirestore.instance;
  static Reference storage = FirebaseStorage.instance.ref();
  List<ContactModel> contactsList = [];
  List<User?> friends = [];
  List<User?> pendingList = [];
  List<User?> receivedRequests = [];
  StreamController<List<HomeConversationModel>>? conversationsStream;
  List<HomeConversationModel> homeConversations = [];
  List<BlockUserModel> blockedList = [];
  StreamController<List<PostModel>>? _discoverPostsStream;
  StreamSubscription<QuerySnapshot>? _postsStreamSubscription;
  StreamSubscription<QuerySnapshot>? _discoverPostsStreamSubscription;
  StreamController<List<PostModel>>? _postsStream;
  StreamSubscription<QuerySnapshot>? _storiesStreamSubscription;
  StreamController<List<StoryModel>>? _storiesStream;
  StreamController<List<PostModel>>? _profilePostsStream;
  StreamSubscription<QuerySnapshot>? _profilePostsStreamSubscription;

  /// get user object from database where userID == uid
  static Future<User?> getCurrentUser(String uid) async {
    DocumentSnapshot<Map<String, dynamic>> userDocument =
        await firestore.collection(USERS).doc(uid).get();
    if (userDocument.data() != null && userDocument.exists) {
      return User.fromJson(userDocument.data()!);
    } else {
      return null;
    }
  }

  /// update the user object in the database
  static Future<User?> updateCurrentUser(User user) async {
    return await firestore
        .collection(USERS)
        .doc(user.userID)
        .set(user.toJson())
        .then((document) {
      return user;
    });
  }

  /// this method is used to upload the user image to firestore
  /// @param image file to be uploaded to firestore
  /// @param userID the userID used as part of the image name on firestore
  /// @return the full download url used to view the image
  static Future<String> uploadUserImageToFireStorage(
      File image, String userID) async {
    File compressedImage = await _compressImage(image);
    Reference upload = storage.child('images/$userID.png');
    UploadTask uploadTask = upload.putFile(compressedImage);
    var downloadUrl =
        await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  /// this method uploads the chat image to the firestore
  /// @param image file to be uploaded to firestore
  /// @param context is required to show progress
  /// @return a Url object containing mime type of the file and download url
  Future<Url> uploadChatImageToFireStorage(File image, BuildContext context) async {
    showProgress(context, 'Uploading image...', false);
    var uniqueID = Uuid().v4();
    File compressedImage = await _compressImage(image);
    Reference upload = storage.child('images/$uniqueID.png');
    UploadTask uploadTask = upload.putFile(compressedImage);
    uploadTask.snapshotEvents.listen((event) {
      updateProgress(
          'Uploading image ${(event.bytesTransferred.toDouble() / 1000).toStringAsFixed(2)} /'
          '${(event.totalBytes.toDouble() / 1000).toStringAsFixed(2)} '
          'KB');
    });
    uploadTask.whenComplete(() {}).catchError((onError) {
      print((onError as PlatformException).message);
    });
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();

    hideProgress();
    return Url(mime: 'image', url: downloadUrl.toString());
  }

  /// this method uploads the chat video to the firestore
  /// @param video file to be uploaded to firestore
  /// @param context is required to show progress
  /// @return a Url object containing mime type of the file and download url
  /// and thumbnail url
  Future<ChatVideoContainer> uploadChatVideoToFireStorage(
      File video, BuildContext context) async {
    showProgress(context, 'Uploading video...', false);
    var uniqueID = Uuid().v4();
    File compressedVideo = await _compressVideo(video);
    Reference upload = storage.child('videos/$uniqueID.mp4');
    SettableMetadata metadata = SettableMetadata(contentType: 'video');
    UploadTask uploadTask = upload.putFile(compressedVideo, metadata);
    uploadTask.snapshotEvents.listen((event) {
      updateProgress(
          'Uploading video ${(event.bytesTransferred.toDouble() / 1000).toStringAsFixed(2)} /'
          '${(event.totalBytes.toDouble() / 1000).toStringAsFixed(2)} '
          'KB');
    });
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();

    print('FireStoreUtils.uploadChatVideoToFireStorage $downloadUrl');
    String thumbnailDownloadUrl;
    try {
      final uint8list = await VideoThumbnail.thumbnailFile(
          video: downloadUrl,
          thumbnailPath: (await getTemporaryDirectory()).path,
          imageFormat: ImageFormat.PNG);
      final file = File(uint8list!);
      thumbnailDownloadUrl = await uploadVideoThumbnailToFireStorage(file);
    } catch (e, s) {
      print('FireStoreUtils.uploadChatVideoToFireStorage $e $s');
      thumbnailDownloadUrl = 'no_thumbnail';
    }
    hideProgress();
    return ChatVideoContainer(
        videoUrl: Url(url: downloadUrl.toString(), mime: 'video'),
        thumbnailUrl: thumbnailDownloadUrl);
  }

  /// upload the video thumbnail image to firestore
  /// @param file is the thumbnail file of the video
  /// @return downloadURL of the thumbnail image
  Future<String> uploadVideoThumbnailToFireStorage(File file) async {
    var uniqueID = Uuid().v4();
    File compressedImage = await _compressImage(file);
    Reference upload = storage.child('thumbnails/$uniqueID.png');
    UploadTask uploadTask = upload.putFile(compressedImage);
    var downloadUrl =
        await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  /// query the database to get user contacts
  /// user contactsList may contain:
  /// * users that sent you friend/follow request
  /// * users that you send them a friend/follow request
  /// * users that are already your friends
  /// * if @param searchScreen is true then we include users that you didn't
  /// send friend/follow requests and neither did they.
  Future<List<ContactModel>> getContacts(String userID, bool searchScreen) async {
    /// get users that you both friend/follow each other
    friends = await getFriends(MyAppState.currentUser!.userID);

    /// get users that you sent them friend/follow requests
    pendingList = await getPendingRequests();

    /// get users that sent you friend/follow requests
    receivedRequests = await getReceivedRequests();
    contactsList = [];
    for (final friend in friends) {
      /// looping over the friends list
      /// we set contactModel.type to be FRIEND and add the contactModel to
      /// the contacts list
      contactsList.add(ContactModel(type: ContactType.FRIEND, user: friend));
    }
    for (final pendingUser in pendingList) {
      /// looping over the pendingList list
      /// we set contactModel.type to be PENDING and add the contactModel to
      /// the contacts list
      contactsList.add(ContactModel(type: ContactType.PENDING, user: pendingUser));
    }
    for (final newFriendRequest in receivedRequests) {
      /// looping over the receivedRequests list
      /// we set contactModel.type to be ACCEPT and add the contactModel to
      /// the contacts list
      contactsList
          .add(ContactModel(type: ContactType.ACCEPT, user: newFriendRequest));
    }

    if (searchScreen) {
      /// if this is true, this means we want to include strangers in our
      /// final contacts list, good when you want to search for new users
      await firestore.collection(USERS).get().then((onValue) {
        /// we loop over the list of users
        onValue.docs.asMap().forEach((index, user) {
          try {
            User contact = User.fromJson(user.data());

            /// check if the contact is already in our friends list
            User? friend =
                friends.firstWhereOrNull((user) => user?.userID == contact.userID);

            /// check if the contact is already in our pending list
            User? pending = pendingList
                .firstWhereOrNull((user) => user?.userID == contact.userID);

            /// check if the contact is already in our receivedRequests list
            User? sent = receivedRequests
                .firstWhereOrNull((user) => user?.userID == contact.userID);

            /// if the contact is not our friend and didn't send us a
            /// friend/follow request and we didn't send him a friend/follow
            /// request then he is an unknown user to us
            bool isUnknown = friend == null && pending == null && sent == null;
            if (user.id != userID) {
              if (isUnknown) {
                if (contact.userID.isEmpty) contact.userID = user.id;

                /// we set contactModel.type to be UNKNOWN and add the contactModel to
                /// the contacts list
                contactsList
                    .add(ContactModel(type: ContactType.UNKNOWN, user: contact));
              }
            }
          } catch (e) {
            print('FireStoreUtils.getContacts Users table invalid json '
                'structure exception, doc id is => ${user.id}');
          }
        });
      }, onError: (e) {
        print('error $e');
      });
    }

    /// lastly we remove blocked users from the list
    contactsList
        .removeWhere((element) => validateIfUserBlocked(element.user.userID));

    /// we remove duplicated users and then return the list of contacts
    return contactsList.toSet().toList();
  }

  /// query with userID to get this user's friends
  /// @param userID the id of the user
  /// @return list of this user friends
  Future<List<User>> getFriends(String userID) async {
    List<User?> receivedFriends = [];
    List<User> actualFriends = [];

    /// query the users that sent you friend/follow requests
    QuerySnapshot<Map<String, dynamic>> receivedFriendsResult = await firestore
        .collection(SOCIAL_GRAPH)
        .doc(userID)
        .collection(RECEIVED_FRIEND_REQUESTS)
        .get();

    /// query the users that you sent them friend/follow requests
    QuerySnapshot<Map<String, dynamic>> sentFriendsResult = await firestore
        .collection(SOCIAL_GRAPH)
        .doc(userID)
        .collection(SENT_FRIEND_REQUESTS)
        .get();

    await Future.forEach(receivedFriendsResult.docs,
        (DocumentSnapshot<Map<String, dynamic>> receivedFriend) {
      receivedFriends.add(User.fromJson(receivedFriend.data() ?? {}));
    });

    await Future.forEach(sentFriendsResult.docs,
        (DocumentSnapshot<Map<String, dynamic>> receivedFriend) {
      User pendingUser = User.fromJson(receivedFriend.data() ?? {});
      User? friendOrNull = receivedFriends
          .firstWhereOrNull((element) => element?.userID == pendingUser.userID);
      if (friendOrNull != null) actualFriends.add(pendingUser);
    });

    actualFriends.removeWhere((element) => validateIfUserBlocked(element.userID));

    return actualFriends.toSet().toList();
  }

  /// query this user's pending friends
  /// @return list of this user pending friends
  Future<List<User>> getPendingRequests() async {
    List<User> pendingList = [];
    List<User?> receivedList = [];

    /// query the users that you sent them friend/follow requests
    QuerySnapshot<Map<String, dynamic>> sentRequestsResult = await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(SENT_FRIEND_REQUESTS)
        .get();

    /// query the users that sent you friend/follow requests
    QuerySnapshot<Map<String, dynamic>> receivedRequestsResult = await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(RECEIVED_FRIEND_REQUESTS)
        .get();

    await Future.forEach(receivedRequestsResult.docs,
        (DocumentSnapshot<Map<String, dynamic>> user) {
      receivedList.add(User.fromJson(user.data() ?? {}));
    });

    await Future.forEach(sentRequestsResult.docs,
        (DocumentSnapshot<Map<String, dynamic>> document) {
          User user = User.fromJson(document.data() ?? {});
      User? pendingOrNull =
          receivedList.firstWhereOrNull((element) => element?.userID == user.userID);
      if (pendingOrNull == null) pendingList.add(user);
    });
    return pendingList.toSet().toList();
  }

  /// query this user's received friend requests
  /// @return list of users who sent you friend/follow requests
  Future<List<User>> getReceivedRequests() async {
    List<User> receivedList = [];
    List<User?> pendingList = [];

    /// query the users that sent you friend/follow requests
    QuerySnapshot<Map<String, dynamic>> receivedRequestsResult = await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(RECEIVED_FRIEND_REQUESTS)
        .get();

    /// query the users that you sent them friend/follow requests
    QuerySnapshot<Map<String, dynamic>> sentRequestsResult = await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(SENT_FRIEND_REQUESTS)
        .get();

    await Future.forEach(sentRequestsResult.docs,
        (DocumentSnapshot<Map<String, dynamic>> user) {
      pendingList.add(User.fromJson(user.data() ?? {}));
    });

    await Future.forEach(receivedRequestsResult.docs,
        (DocumentSnapshot<Map<String, dynamic>> document) {
          User sentFriend = User.fromJson(document.data() ?? {});
      User? sentOrNull = pendingList
          .firstWhereOrNull((element) => element?.userID == sentFriend.userID);
      if (sentOrNull == null) receivedList.add(sentFriend);
    });

    return receivedList.toSet().toList();
  }

  /// we accept the friend request sent by @param pendingUser
  /// @param pendingUser the user who sent us the friend/follow request
  /// @param fromProfile is a flag used to manipulate lists, true if you are
  /// calling this from profile
  onFriendAccept(User pendingUser, bool fromProfile) async {
    await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(SENT_FRIEND_REQUESTS)
        .doc(pendingUser.userID)
        .set(pendingUser.toJson());

    await firestore
        .collection(SOCIAL_GRAPH)
        .doc(pendingUser.userID)
        .collection(RECEIVED_FRIEND_REQUESTS)
        .doc(MyAppState.currentUser!.userID)
        .set(MyAppState.currentUser!.toJson());

    if (!fromProfile) {
      pendingList.remove(pendingUser);
      friends.add(pendingUser);
    }

    /// share new user's posts with current user
    QuerySnapshot<Map<String, dynamic>> pendingUserPostsQuery = await firestore
        .collection(SOCIAL_DISCOVER)
        .where('authorID', isEqualTo: pendingUser.userID)
        .get();

    await Future.forEach(pendingUserPostsQuery.docs,
        (QueryDocumentSnapshot<Map<String, dynamic>> document) async {
      PostModel post = PostModel.fromJson(document.data());
      await firestore
          .collection(FEED)
          .doc(MyAppState.currentUser!.userID)
          .collection(MAIN_FEED)
          .doc(post.id)
          .set(post.toJson());
    });

    /// share new user's stories with current user
    QuerySnapshot<Map<String, dynamic>> pendingUserStoriesQuery = await firestore
        .collection(STORIES)
        .where('authorID', isEqualTo: pendingUser.userID)
        .get();

    await Future.forEach(pendingUserStoriesQuery.docs,
        (QueryDocumentSnapshot<Map<String, dynamic>> document) async {
      StoryModel post = StoryModel.fromJson(document.data());
      await firestore
          .collection(FEED)
          .doc(MyAppState.currentUser!.userID)
          .collection(STORIES_FEED)
          .doc(post.id)
          .set(post.toJson());
    });

    /// share current user's posts with new friend
    QuerySnapshot<Map<String, dynamic>> currentUserPostsQuery = await firestore
        .collection(SOCIAL_DISCOVER)
        .where('authorID', isEqualTo: MyAppState.currentUser!.userID)
        .get();

    await Future.forEach(currentUserPostsQuery.docs,
        (QueryDocumentSnapshot<Map<String, dynamic>> document) async {
      PostModel post = PostModel.fromJson(document.data());
      await firestore
          .collection(FEED)
          .doc(pendingUser.userID)
          .collection(MAIN_FEED)
          .doc(post.id)
          .set(post.toJson());
    });

    /// share current user's stories with new friend
    QuerySnapshot<Map<String, dynamic>> currentUserStoriesQuery = await firestore
        .collection(STORIES)
        .where('authorID', isEqualTo: MyAppState.currentUser!.userID)
        .get();

    await Future.forEach(currentUserStoriesQuery.docs,
        (QueryDocumentSnapshot<Map<String, dynamic>> document) async {
      StoryModel post = StoryModel.fromJson(document.data());
      await firestore
          .collection(FEED)
          .doc(pendingUser.userID)
          .collection(STORIES_FEED)
          .doc(post.id)
          .set(post.toJson());
    });

    /// save notification in the database in the notifications table
    _saveNotification(
        'accept_friend',
        'Accepted your friend request.',
        pendingUser,
        MyAppState.currentUser!.fullName(),
        {'fromUser': MyAppState.currentUser!.toJson()});

    if (pendingUser.settings.pushNewMessages) {
      await sendNotification(pendingUser.fcmToken,
          MyAppState.currentUser!.fullName(), 'Accepted your friend request.', null);
    }
  }

  /// delete friendship between two users
  /// @param friend the friend that we are going to unfriend
  /// @param fromProfile this flag is used to manipulate lists, true if you
  /// are calling this from profile screen
  onUnFriend(User friend, bool fromProfile) async {
    await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(SENT_FRIEND_REQUESTS)
        .doc(friend.userID)
        .delete();

    await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(RECEIVED_FRIEND_REQUESTS)
        .doc(friend.userID)
        .delete();
    await firestore
        .collection(SOCIAL_GRAPH)
        .doc(friend.userID)
        .collection(SENT_FRIEND_REQUESTS)
        .doc(MyAppState.currentUser!.userID)
        .delete();
    await firestore
        .collection(SOCIAL_GRAPH)
        .doc(friend.userID)
        .collection(RECEIVED_FRIEND_REQUESTS)
        .doc(MyAppState.currentUser!.userID)
        .delete();

    if (!fromProfile) {
      friends.remove(friend);
      ContactModel unknownContact =
          contactsList.firstWhere((contact) => contact.user == friend);
      contactsList.remove(unknownContact);
      unknownContact.type = ContactType.UNKNOWN;
      contactsList.add(unknownContact);
    }

    ///remove deleted user's posts from current user feed
    QuerySnapshot pendingUserPostsQuery = await firestore
        .collection(SOCIAL_DISCOVER)
        .where('authorID', isEqualTo: friend.userID)
        .get();

    await Future.forEach(pendingUserPostsQuery.docs,
        (QueryDocumentSnapshot document) async {
      await firestore
          .collection(FEED)
          .doc(MyAppState.currentUser!.userID)
          .collection(MAIN_FEED)
          .doc(document.id)
          .delete();
    });

    ///remove deleted user's stories from current user feed
    QuerySnapshot pendingUserStoriesQuery = await firestore
        .collection(STORIES)
        .where('authorID', isEqualTo: friend.userID)
        .get();

    await Future.forEach(pendingUserStoriesQuery.docs,
        (QueryDocumentSnapshot document) async {
      await firestore
          .collection(FEED)
          .doc(MyAppState.currentUser!.userID)
          .collection(STORIES_FEED)
          .doc(document.id)
          .delete();
    });

    ///remove current user's posts from new friend feed
    QuerySnapshot currentUserPostsQuery = await firestore
        .collection(SOCIAL_DISCOVER)
        .where('authorID', isEqualTo: MyAppState.currentUser!.userID)
        .get();

    await Future.forEach(currentUserPostsQuery.docs,
        (QueryDocumentSnapshot document) async {
      await firestore
          .collection(FEED)
          .doc(friend.userID)
          .collection(MAIN_FEED)
          .doc(document.id)
          .delete();
    });

    ///remove current user's stories from new friend feed
    QuerySnapshot currentUserStoriesQuery = await firestore
        .collection(STORIES)
        .where('authorID', isEqualTo: MyAppState.currentUser!.userID)
        .get();

    await Future.forEach(currentUserStoriesQuery.docs,
        (QueryDocumentSnapshot document) async {
      await firestore
          .collection(FEED)
          .doc(friend.userID)
          .collection(STORIES_FEED)
          .doc(document.id)
          .delete();
    });
  }

  /// cancel the request between these two users
  /// @param user the other user
  /// @param fromProfile this flag is used to manipulate lists, true if you
  /// are calling this from profile screen
  onCancelRequest(User user, bool fromProfile) async {
    await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(SENT_FRIEND_REQUESTS)
        .doc(user.userID)
        .delete();
    await firestore
        .collection(SOCIAL_GRAPH)
        .doc(user.userID)
        .collection(RECEIVED_FRIEND_REQUESTS)
        .doc(MyAppState.currentUser!.userID)
        .delete();

    if (!fromProfile) {
      pendingList.remove(user);
      ContactModel unknownContact =
          contactsList.firstWhere((contact) => contact.user == user);
      contactsList.remove(unknownContact);
      unknownContact.type = ContactType.UNKNOWN;
      contactsList.add(unknownContact);
    }
  }

  /// sends a friend to other user
  /// @param user the other user
  /// @param fromProfile this flag is used to manipulate lists, true if you
  /// are calling this from profile screen
  sendFriendRequest(User user, bool fromProfile) async {
    await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(SENT_FRIEND_REQUESTS)
        .doc(user.userID)
        .set(user.toJson());
    await firestore
        .collection(SOCIAL_GRAPH)
        .doc(user.userID)
        .collection(RECEIVED_FRIEND_REQUESTS)
        .doc(MyAppState.currentUser!.userID)
        .set(MyAppState.currentUser!.toJson());
    if (!fromProfile) {
      pendingList.add(user);
      ContactModel pendingContact =
          contactsList.firstWhere((contact) => contact.user == user);
      contactsList.remove(pendingContact);
      pendingContact.type = ContactType.PENDING;
      contactsList.add(pendingContact);
    }
    _saveNotification(
        'friend_request',
        'Sent you a friend request.',
        user,
        MyAppState.currentUser!.fullName(),
        {'fromUser': MyAppState.currentUser!.toJson()});

    if (user.settings.pushNewMessages) {
      await sendNotification(user.fcmToken, MyAppState.currentUser!.fullName(),
          'Sent you a friend request.', null);
    }
  }

  /// get a stream of user conversations
  /// @param userID the id used to query the conversations
  /// @return yields list of HomeConversationModel every time a new message
  /// is added/updated to the database
  Stream<List<HomeConversationModel>> getConversations(String userID) async* {
    conversationsStream = StreamController<List<HomeConversationModel>>();
    HomeConversationModel newHomeConversation;
    firestore
        .collection(CHANNEL_PARTICIPATION)
        .where('user', isEqualTo: userID)
        .snapshots()
        .listen((querySnapshot) {
      if (querySnapshot.docs.isEmpty) {
        conversationsStream!.sink.add(homeConversations);
      } else {
        homeConversations.clear();
        Future.forEach(querySnapshot.docs,
            (DocumentSnapshot<Map<String, dynamic>> document) {
          if (document.exists) {
            ChannelParticipation participation =
                ChannelParticipation.fromJson(document.data() ?? {});
            firestore
                .collection(CHANNELS)
                .doc(participation.channel)
                .snapshots()
                .listen((channel) async {
              if (channel.exists) {
                bool isGroupChat = !channel.id.contains(userID);
                List<User> users = [];
                if (isGroupChat) {
                  getGroupMembers(channel.id).listen((listOfUsers) {
                    if (listOfUsers.isNotEmpty) {
                      users = listOfUsers;
                      newHomeConversation = HomeConversationModel(
                          conversationModel:
                              ConversationModel.fromJson(channel.data() ?? {}),
                          isGroupChat: isGroupChat,
                          members: users);

                      if (newHomeConversation.conversationModel!.id.isEmpty)
                        newHomeConversation.conversationModel!.id = channel.id;

                      homeConversations.removeWhere((conversationModelToDelete) {
                        return newHomeConversation.conversationModel!.id ==
                            conversationModelToDelete.conversationModel!.id;
                      });
                      homeConversations.add(newHomeConversation);
                      homeConversations.sort((a, b) => a
                          .conversationModel!.lastMessageDate
                          .compareTo(b.conversationModel!.lastMessageDate));
                      conversationsStream!.sink
                          .add(homeConversations.reversed.toList());
                    }
                  });
                } else {
                  getUserByID(channel.id.replaceAll(userID, '')).listen((user) {
                    if (!validateIfUserBlocked(user.userID)) {
                      users.clear();
                      users.add(user);
                      newHomeConversation = HomeConversationModel(
                          conversationModel:
                              ConversationModel.fromJson(channel.data() ?? {}),
                          isGroupChat: isGroupChat,
                          members: users);

                      if (newHomeConversation.conversationModel!.id.isEmpty)
                        newHomeConversation.conversationModel!.id = channel.id;

                      homeConversations.removeWhere((conversationModelToDelete) {
                        return newHomeConversation.conversationModel!.id ==
                            conversationModelToDelete.conversationModel!.id;
                      });

                      homeConversations.add(newHomeConversation);
                      homeConversations.sort((a, b) => a
                          .conversationModel!.lastMessageDate
                          .compareTo(b.conversationModel!.lastMessageDate));
                      conversationsStream!.sink
                          .add(homeConversations.reversed.toList());
                    }
                  });
                }
              }
            });
          }
        });
      }
    });
    yield* conversationsStream!.stream;
  }

  /// stream the group members or a certain channel id
  /// @param channelID the channelID of the group
  /// @return yields a list of User object
  Stream<List<User>> getGroupMembers(String channelID) async* {
    StreamController<List<User>> membersStreamController = StreamController();
    getGroupMembersIDs(channelID).listen((memberIDs) {
      if (memberIDs.isNotEmpty) {
        List<User> groupMembers = [];
        for (String id in memberIDs) {
          getUserByID(id).listen((user) {
            groupMembers.add(user);
            membersStreamController.sink.add(groupMembers);
          });
        }
      } else {
        membersStreamController.sink.add([]);
      }
    });
    yield* membersStreamController.stream;
  }

  /// stream the list of user ids that are in the same group chat together
  /// @param channelID id of the channel
  /// @return yields a list of string containing the IDs of the group members
  Stream<List<String>> getGroupMembersIDs(String channelID) async* {
    StreamController<List<String>> membersIDsStreamController = StreamController();
    firestore
        .collection(CHANNEL_PARTICIPATION)
        .where('channel', isEqualTo: channelID)
        .snapshots()
        .listen((participations) {
      List<String> uids = [];
      for (DocumentSnapshot<Map<String, dynamic>> document in participations.docs) {
        uids.add(document.data()!['user'] ?? '');
      }
      if (uids.contains(MyAppState.currentUser!.userID)) {
        membersIDsStreamController.sink.add(uids);
      } else {
        membersIDsStreamController.sink.add([]);
      }
    });
    yield* membersIDsStreamController.stream;
  }

  /// this query uses the id to return the corresponding user object from the
  /// database
  /// @param id the id used for look up the user object
  /// @return yields the user object
  Stream<User> getUserByID(String id) async* {
    StreamController<User> userStreamController = StreamController();
    firestore.collection(USERS).doc(id).snapshots().listen((user) {
      try {
        User userModel = User.fromJson(user.data() ?? {});
        userStreamController.sink.add(userModel);
      } catch (e) {
        print('FireStoreUtils.getUserByID failed to parse user object ${user.id}');
      }
    });
    yield* userStreamController.stream;
  }

  /// we lookup the database for a conversationModel with the same channelID
  /// or return null if it's not created yet
  /// @param channelID the id of the channel in the database
  /// @return a nullable ConversationModel, null is the channel is not
  /// created yet
  Future<ConversationModel?> getChannelByIdOrNull(String channelID) async {
    ConversationModel? conversationModel;
    await firestore.collection(CHANNELS).doc(channelID).get().then((channel) {
      if (channel.exists) {
        conversationModel = ConversationModel.fromJson(channel.data() ?? {});
      }
    }, onError: (e) {
      print((e as PlatformException).message);
    });
    return conversationModel;
  }

  /// get chat messages from the database by the conversationModel.channelID
  /// @param homeConversationModel this object contains all nassesray data
  /// required to to fetch the chat messages
  /// @return a stream of ChatModel object containing a list of messages and
  /// a list of the current group members
  Stream<ChatModel> getChatMessages(
      HomeConversationModel homeConversationModel) async* {
    StreamController<ChatModel> chatModelStreamController = StreamController();
    ChatModel chatModel = ChatModel();
    List<MessageData> listOfMessages = [];
    List<User> listOfMembers = homeConversationModel.members;
    if (homeConversationModel.isGroupChat) {
      homeConversationModel.members.forEach((groupMember) {
        if (groupMember.userID != MyAppState.currentUser!.userID) {
          getUserByID(groupMember.userID).listen((updatedUser) {
            for (int i = 0; i < listOfMembers.length; i++) {
              if (listOfMembers[i].userID == updatedUser.userID) {
                listOfMembers[i] = updatedUser;
              }
            }
            chatModel.message = listOfMessages;
            chatModel.members = listOfMembers;
            chatModelStreamController.sink.add(chatModel);
          });
        }
      });
    } else {
      User friend = homeConversationModel.members.first;
      getUserByID(friend.userID).listen((user) {
        listOfMembers.clear();
        listOfMembers.add(user);
        chatModel.message = listOfMessages;
        chatModel.members = listOfMembers;
        chatModelStreamController.sink.add(chatModel);
      });
    }
    if (homeConversationModel.conversationModel != null) {
      firestore
          .collection(CHANNELS)
          .doc(homeConversationModel.conversationModel!.id)
          .collection(THREAD)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((onData) {
        listOfMessages.clear();
        onData.docs.forEach((document) {
          listOfMessages.add(MessageData.fromJson(document.data()));
        });
        chatModel.message = listOfMessages;
        chatModel.members = listOfMembers;
        chatModelStreamController.sink.add(chatModel);
      });
    }
    yield* chatModelStreamController.stream;
  }

  /// sends a message to a channel
  /// @param members list of participants users in this channel
  /// @param isGroup true if it's a group chat
  /// @param message the actually messageData object that holds the data of the
  /// message
  /// @param conversationModel an objects which contains data related to the
  /// channel
  Future<void> sendMessage(List<User> members, bool isGroup, MessageData message,
      ConversationModel conversationModel) async {
    var ref = firestore
        .collection(CHANNELS)
        .doc(conversationModel.id)
        .collection(THREAD)
        .doc();
    message.messageID = ref.id;
    ref.set(message.toJson());
    List<User> payloadFriends;
    if (isGroup) {
      payloadFriends = [];
      payloadFriends.addAll(members);
    } else {
      payloadFriends = [MyAppState.currentUser!];
    }
    await Future.forEach(members, (User element) async {
      if (element.settings.pushNewMessages) {
        User? friend;
        if (isGroup) {
          friend =
              payloadFriends.firstWhere((user) => user.fcmToken == element.fcmToken);
          payloadFriends.remove(friend);
          payloadFriends.add(MyAppState.currentUser!);
        }
        Map<String, dynamic> payload = <String, dynamic>{
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'id': '1',
          'status': 'done',
          'conversationModel': conversationModel.toPayload(),
          'isGroup': isGroup,
          'members': payloadFriends.map((e) => e.toPayload()).toList()
        };
        await sendNotification(
            element.fcmToken,
            isGroup ? conversationModel.name : MyAppState.currentUser!.fullName(),
            message.content,
            payload);
        if (isGroup) {
          payloadFriends.remove(MyAppState.currentUser);
          payloadFriends.add(friend!);
        }
      }
    });
  }

  /// create a new channel / start a new conversation
  /// @param conversation the newly created conversation data
  /// @return true if the channel is created successfully
  Future<bool> createConversation(ConversationModel conversation) async {
    bool isSuccessful = false;
    await firestore
        .collection(CHANNELS)
        .doc(conversation.id)
        .set(conversation.toJson())
        .then((onValue) async {
      ChannelParticipation myChannelParticipation = ChannelParticipation(
          user: MyAppState.currentUser!.userID, channel: conversation.id);
      ChannelParticipation myFriendParticipation = ChannelParticipation(
          user: conversation.id.replaceAll(MyAppState.currentUser!.userID, ''),
          channel: conversation.id);
      await createChannelParticipation(myChannelParticipation);
      await createChannelParticipation(myFriendParticipation);
      isSuccessful = true;
    }, onError: (e) {
      print((e as PlatformException).message);
      isSuccessful = false;
    });
    return isSuccessful;
  }

  /// update the channel object saved in the database
  /// @param conversationModel the updated object of the channel
  Future<void> updateChannel(ConversationModel conversationModel) async {
    await firestore
        .collection(CHANNELS)
        .doc(conversationModel.id)
        .update(conversationModel.toJson());
  }

  /// Create a new ChannelParticipation in the database, the
  /// ChannelParticipation object contains the user id and the channelID
  Future<void> createChannelParticipation(
      ChannelParticipation channelParticipation) async {
    await firestore
        .collection(CHANNEL_PARTICIPATION)
        .add(channelParticipation.toJson());
  }

  /// Create a new group chat in the database
  /// @param List<User> list of selected users to be in the group
  /// @param String name of the new group
  /// @return HomeConversationModel containing all the nessasry data for the
  /// chat
  Future<HomeConversationModel> createGroupChat(
      List<User> selectedUsers, String groupName) async {
    late HomeConversationModel groupConversationModel;
    DocumentReference channelDoc = firestore.collection(CHANNELS).doc();
    ConversationModel conversationModel = ConversationModel();
    conversationModel.id = channelDoc.id;
    conversationModel.creatorId = MyAppState.currentUser!.userID;
    conversationModel.name = groupName;
    conversationModel.lastMessage =
        '${MyAppState.currentUser!.fullName()} created this group';
    conversationModel.lastMessageDate = Timestamp.now();
    await channelDoc.set(conversationModel.toJson()).then((onValue) async {
      selectedUsers.add(MyAppState.currentUser!);
      for (User user in selectedUsers) {
        ChannelParticipation channelParticipation =
            ChannelParticipation(channel: conversationModel.id, user: user.userID);
        await createChannelParticipation(channelParticipation);
      }
      groupConversationModel = HomeConversationModel(
          isGroupChat: true,
          members: selectedUsers,
          conversationModel: conversationModel);
    });
    return groupConversationModel;
  }

  /// leave the group chat
  /// @param ConversationModel
  /// @return true if we left the group successfully
  Future<bool> leaveGroup(ConversationModel conversationModel) async {
    bool isSuccessful = false;
    conversationModel.lastMessage = '${MyAppState.currentUser!.fullName()} '
        'left';
    conversationModel.lastMessageDate = Timestamp.now();
    await updateChannel(conversationModel).then((_) async {
      await firestore
          .collection(CHANNEL_PARTICIPATION)
          .where('channel', isEqualTo: conversationModel.id)
          .where('user', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((onValue) async {
        await firestore
            .collection(CHANNEL_PARTICIPATION)
            .doc(onValue.docs.first.id)
            .delete()
            .then((onValue) {
          isSuccessful = true;
        });
      });
    });
    return isSuccessful;
  }

  /// block/report user
  /// @param blockedUser the block target user
  /// @param type a String of the type weather 'block' or 'report'
  /// @return true if successful
  Future<bool> blockUser(User blockedUser, String type) async {
    bool isSuccessful = false;
    BlockUserModel blockUserModel = BlockUserModel(
        type: type,
        source: MyAppState.currentUser!.userID,
        dest: blockedUser.userID,
        createdAt: Timestamp.now());
    await firestore.collection(REPORTS).add(blockUserModel.toJson()).then((onValue) {
      isSuccessful = true;
    });
    return isSuccessful;
  }

  /// query blocked/reported users
  /// yields a stream whenever blocked users documents are updated to refresh
  /// the ui
  Stream<bool> getBlocks() async* {
    StreamController<bool> refreshStreamController = StreamController();
    firestore
        .collection(REPORTS)
        .where('source', isEqualTo: MyAppState.currentUser!.userID)
        .snapshots()
        .listen((onData) {
      List<BlockUserModel> list = [];
      for (DocumentSnapshot<Map<String, dynamic>> block in onData.docs) {
        list.add(BlockUserModel.fromJson(block.data() ?? {}));
      }
      blockedList = list;
      refreshStreamController.sink.add(true);
    });
    yield* refreshStreamController.stream;
  }

  /// validate if the user with that userID is blocked
  /// @param userID the tested userID
  /// @return true if this userID is blocked
  bool validateIfUserBlocked(String userID) {
    for (BlockUserModel blockedUser in blockedList) {
      if (userID == blockedUser.dest) {
        return true;
      }
    }
    return false;
  }

  /// delete an image from firestore storage
  Future<void> deleteImage(String imageFileUrl) async {
    var fileUrl = Uri.decodeFull(Path.basename(imageFileUrl))
        .replaceAll(new RegExp(r'(\?alt).*'), '');

    final Reference firebaseStorageRef =
        FirebaseStorage.instance.ref().child(fileUrl);
    await firebaseStorageRef.delete();
  }

  /// upload an audio file to firestore storage
  /// @param file the audio file to be uploaded
  /// @param context the build context required to show progress
  /// @return Url object which contains the mime type of the file and a
  /// download url for it
  Future<Url> uploadAudioFile(File file, BuildContext context) async {
    showProgress(context, 'Uploading Audio...', false);
    var uniqueID = Uuid().v4();
    Reference upload = storage.child('audio/$uniqueID.mp3');
    SettableMetadata metadata = SettableMetadata(contentType: 'audio');
    UploadTask uploadTask = upload.putFile(file, metadata);
    uploadTask.snapshotEvents.listen((event) {
      updateProgress(
          'Uploading Audio ${(event.bytesTransferred.toDouble() / 1000).toStringAsFixed(2)} /'
          '${(event.totalBytes.toDouble() / 1000).toStringAsFixed(2)} '
          'KB');
    });
    uploadTask.whenComplete(() {}).catchError((onError) {
      print((onError as PlatformException).message);
    });
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();

    hideProgress();
    return Url(mime: 'audio', url: downloadUrl.toString());
  }

  /// query user stories feed as a stream which updates whenever a new story is
  /// added or expires (24h)
  /// @param userID the id of the user related to the story
  /// @return Stream<List<StoryModel>> yields a list of stories
  Stream<List<StoryModel>> getUserStories(String userID) async* {
    List<StoryModel> _storiesList = [];
    _storiesStream = StreamController();
    int tsToMillis = Timestamp.now().millisecondsSinceEpoch;
    DateTime compareDate =
        DateTime.fromMillisecondsSinceEpoch(tsToMillis - (24 * 60 * 60 * 1000));
    Stream<QuerySnapshot<Map<String, dynamic>>> result = firestore
        .collection(FEED)
        .doc(userID)
        .collection(STORIES_FEED)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromMillisecondsSinceEpoch(
                compareDate.millisecondsSinceEpoch))
        .snapshots();
    _storiesStreamSubscription = result.listen((story) async {
      _storiesList.clear();
      await Future.forEach(story.docs,
          (DocumentSnapshot<Map<String, dynamic>> story) {
        StoryModel storyModel = StoryModel.fromJson(story.data() ?? {});
        if (!validateIfUserBlocked(storyModel.authorID)) if (storyModel.authorID ==
            MyAppState.currentUser!.userID) {
          _storiesList.insert(0, storyModel);
        } else {
          _storiesList.add(storyModel);
        }
      });
      _storiesStream!.sink.add(_storiesList);
    });
    yield* _storiesStream!.stream;
  }

  /// dispose stories stream controller to avoid memory leaks
  void disposeUserStoriesStream() {
    if (_storiesStream != null) _storiesStream!.close();
    if (_storiesStreamSubscription != null) _storiesStreamSubscription!.cancel();
  }

  /// query user posts feed as a stream which updates whenever required
  /// @param userID the id of the user related to the post
  /// @return Stream<List<PostModel>> yields a list of posts
  Stream<List<PostModel>> getUserPosts(String userID) async* {
    List<PostModel> _postsList = [];
    _postsStream = StreamController();
    Stream<QuerySnapshot<Map<String, dynamic>>> result = firestore
        .collection(FEED)
        .doc(userID)
        .collection(MAIN_FEED)
        .orderBy('createdAt', descending: true)
        .snapshots();

    _postsStreamSubscription =
        result.listen((QuerySnapshot<Map<String, dynamic>> querySnapshot) async {
      _postsList.clear();
      await Future.forEach(querySnapshot.docs,
          (DocumentSnapshot<Map<String, dynamic>> post) {
        PostModel postModel = PostModel.fromJson(post.data() ?? {});
        if (!validateIfUserBlocked(postModel.authorID)) _postsList.add(postModel);
      });
      _postsStream!.sink.add(_postsList);
    });
    yield* _postsStream!.stream;
  }

  /// dispose posts stream controller to avoid memory leaks
  void disposeUserPostsStream() {
    if (_postsStream != null) _postsStream!.close();
    if (_postsStreamSubscription != null) _postsStreamSubscription!.cancel();
  }

  /// get the comments on a specific post
  /// @param post the original post
  /// @return list of SocialCommentModel object which holds data about the
  /// comment
  Future<List<SocialCommentModel>> getPostComments(PostModel post) async {
    List<SocialCommentModel> _commentsList = [];
    QuerySnapshot<Map<String, dynamic>> result = await firestore
        .collection(SOCIAL_COMMENTS)
        .where('postID', isEqualTo: post.id)
        .orderBy('createdAt')
        .get();
    await Future.forEach(result.docs, (DocumentSnapshot<Map<String, dynamic>> post) {
      print('FireStoreUtils.getPostComments ${post.id}');
      try {
        SocialCommentModel socialCommentModel =
            SocialCommentModel.fromJson(post.data() ?? {});
        if (!validateIfUserBlocked(socialCommentModel.authorID))
          _commentsList.add(socialCommentModel);
      } catch (e) {
        print('FireStoreUtils.getPostComments SOCIAL_COMMENTS table invalid json '
            'structure exception, doc id is => ${post.id}');
      }
    });
    return _commentsList;
  }

  /// post a new comment to this post
  /// @param comment the content of the comment
  /// @param post is the related posted
  postComment(String comment, PostModel post) async {
    DocumentReference commentDocument = firestore.collection(SOCIAL_COMMENTS).doc();
    SocialCommentModel newComment = SocialCommentModel(
        authorID: MyAppState.currentUser!.userID,
        createdAt: Timestamp.now(),
        commentText: comment,
        postID: post.id,
        id: commentDocument.id,
        commentID: commentDocument.id);
    await commentDocument.set(newComment.toJson());
    QuerySnapshot<Map<String, dynamic>> outDatedPosts = await firestore
        .collectionGroup(MAIN_FEED)
        .where('id', isEqualTo: post.id)
        .get();

    /// update the post comment count field
    await Future.forEach(outDatedPosts.docs,
        (DocumentSnapshot<Map<String, dynamic>> post) async {
          num newCount = post.data()!['commentCount'] ?? 0;
      newCount++;
      await firestore.doc(post.reference.path).update({'commentCount': newCount});
    });

    QuerySnapshot<Map<String, dynamic>> mainPost = await firestore
        .collection(SOCIAL_DISCOVER)
        .where('id', isEqualTo: post.id)
        .get();
    num newCount = mainPost.docs.first.data()['commentCount'] ?? 0;
    newCount++;
    await firestore
        .doc(mainPost.docs.first.reference.path)
        .update({'commentCount': newCount});

    await _saveNotification(
        'social_comment',
        'Commented on your post.',
        post.author,
        MyAppState.currentUser!.fullName(),
        {'outBound': MyAppState.currentUser!.toJson()});

    if (post.author.settings.pushNewMessages) {
      await sendNotification(post.author.fcmToken,
          MyAppState.currentUser!.fullName(), 'Commented on your post.', null);
    }
  }

  /// add new reaction to the post
  /// @param SocialReactionModel is the new reaction to be added to the post
  /// @param PostModel is the post that holds the new reaction
  postReaction(SocialReactionModel newReaction, PostModel post) async {
    await firestore.collection(SOCIAL_REACTIONS).doc().set(newReaction.toJson());
    QuerySnapshot<Map<String, dynamic>> outDatedPosts = await firestore
        .collectionGroup(MAIN_FEED)
        .where('id', isEqualTo: post.id)
        .get();

    /// update the post reactions count field
    await Future.forEach(outDatedPosts.docs,
        (DocumentSnapshot<Map<String, dynamic>> post) async {
      num newCount = post.data()!['reactionsCount'] ?? 0;
      newCount++;
      await firestore.doc(post.reference.path).update({'reactionsCount': newCount});
    });

    QuerySnapshot<Map<String, dynamic>> mainPost = await firestore
        .collection(SOCIAL_DISCOVER)
        .where('id', isEqualTo: post.id)
        .get();
    num newCount = mainPost.docs.first.data()['reactionsCount'] ?? 0;
    newCount++;
    await firestore
        .doc(mainPost.docs.first.reference.path)
        .update({'reactionsCount': newCount});

    await _saveNotification(
        'social_reaction',
        'Just reacted to your post.',
        post.author,
        MyAppState.currentUser!.fullName(),
        {'outBound': MyAppState.currentUser!.toJson()});

    if (post.author.settings.pushNewMessages) {
      await sendNotification(post.author.fcmToken,
          MyAppState.currentUser!.fullName(), 'Reacted to your post.', null);
    }
  }

  /// remove reaction from the post
  /// @param PostModel is the post that holds the deleted reaction
  removeReaction(PostModel post) async {
    QuerySnapshot querySnapshot = await firestore
        .collection(SOCIAL_REACTIONS)
        .where('postID', isEqualTo: post.id)
        .where('reactionAuthorID', isEqualTo: MyAppState.currentUser!.userID)
        .get();
    if (querySnapshot.docs.first.exists) {
      await firestore
          .collection(SOCIAL_REACTIONS)
          .doc(querySnapshot.docs.first.id)
          .delete();

      QuerySnapshot<Map<String, dynamic>> outDatedPosts = await firestore
          .collectionGroup(MAIN_FEED)
          .where('id', isEqualTo: post.id)
          .get();

      /// update the post reactions count field
      await Future.forEach(outDatedPosts.docs,
          (DocumentSnapshot<Map<String, dynamic>> post) async {
        num newCount = post.data()!['reactionsCount'] ?? 0;
        newCount--;
        await firestore
            .doc(post.reference.path)
            .update({'reactionsCount': newCount});
      });

      QuerySnapshot<Map<String, dynamic>> mainPost = await firestore
          .collection(SOCIAL_DISCOVER)
          .where('id', isEqualTo: post.id)
          .get();
      num newCount = mainPost.docs.first.data()['reactionsCount'] ?? 0;
      newCount--;
      await firestore
          .doc(mainPost.docs.first.reference.path)
          .update({'reactionsCount': newCount});
    }
  }

  /// returns current user reactions on all posts
  /// @return List of SocialReactionModel associated to this user
  Future<List<SocialReactionModel>> getMyReactions() async {
    List<SocialReactionModel> myReactions = [];
    QuerySnapshot<Map<String, dynamic>> result = await firestore
        .collection(SOCIAL_REACTIONS)
        .where('reactionAuthorID', isEqualTo: MyAppState.currentUser!.userID)
        .get();

    await Future.forEach(
        result.docs,
        (DocumentSnapshot<Map<String, dynamic>> reaction) =>
            myReactions.add(SocialReactionModel.fromJson(reaction.data() ?? {})));
    return myReactions;
  }

  /// update reaction on a post
  /// @param SocialReactionModel the updated reaction
  /// @param PostModel the post that whill hold the newly updated reaction
  void updateReaction(SocialReactionModel postReaction, PostModel post) async {
    QuerySnapshot result = await firestore
        .collection(SOCIAL_REACTIONS)
        .where('reactionAuthorID', isEqualTo: MyAppState.currentUser!.userID)
        .where('postID', isEqualTo: post.id)
        .get();
    if (result.docs.isNotEmpty) {
      await firestore
          .collection(SOCIAL_REACTIONS)
          .doc(result.docs.first.id)
          .update(postReaction.toJson());
    }
  }

  /// discover posts from unknown users
  /// @return a stream of List of PostModel objects
  Stream<List<PostModel>> discoverPosts() async* {
    List<PostModel> _postsList = [];
    _discoverPostsStream = StreamController();
    Stream<QuerySnapshot<Map<String, dynamic>>> result = firestore
        .collection(SOCIAL_DISCOVER)
        .orderBy('createdAt', descending: true)
        .snapshots();

    List<User> knownUsers = await getFriends(MyAppState.currentUser!.userID);
    knownUsers.add(MyAppState.currentUser!);

    _discoverPostsStreamSubscription =
        result.listen((QuerySnapshot<Map<String, dynamic>> querySnapshot) async {
      _postsList.clear();
      await Future.forEach(querySnapshot.docs,
          (DocumentSnapshot<Map<String, dynamic>> post) {
        try {
          PostModel postModel = PostModel.fromJson(post.data() ?? {});
          if (knownUsers
              .where((element) => element.userID == postModel.authorID)
              .isEmpty) {
            if (!validateIfUserBlocked(postModel.authorID))
              _postsList.add(postModel);
          }
        } catch (e) {
          print('FireStoreUtils.discoverPosts: $SOCIAL_DISCOVER table '
              'invalid json structure exception, doc id is => ${post.id} $e');
        }
      });
      _discoverPostsStream!.sink.add(_postsList);
    }, cancelOnError: true);
    yield* _discoverPostsStream!.stream;
  }

  /// dispose discover stream controller to avoid memory leaks
  void disposeDiscoverStream() {
    if (_discoverPostsStream != null) _discoverPostsStream!.close();
    if (_discoverPostsStreamSubscription != null)
      _discoverPostsStreamSubscription!.cancel();
  }

  /// get profile posts of a specific user
  /// @param userID the id of the profile owner
  /// @return a stream of List of PostModel that contains all profile owner
  /// posts
  Stream<List<PostModel>> getProfilePosts(String userID) async* {
    List<PostModel> _profilePosts = [];
    _profilePostsStream = StreamController();
    Stream<QuerySnapshot<Map<String, dynamic>>> result = firestore
        .collection(SOCIAL_DISCOVER)
        .where('authorID', isEqualTo: userID)
        .orderBy('createdAt', descending: true)
        .snapshots();

    _profilePostsStreamSubscription =
        result.listen((QuerySnapshot<Map<String, dynamic>> querySnapshot) async {
      _profilePosts.clear();
      await Future.forEach(querySnapshot.docs,
          (DocumentSnapshot<Map<String, dynamic>> post) {
        try {
          _profilePosts.add(PostModel.fromJson(post.data() ?? {}));
        } catch (e) {
          print('FireStoreUtils.getProfilePosts: $SOCIAL_DISCOVER table '
              'invalid json structure exception, doc id is => ${post.id} $e');
        }
      });
      _profilePostsStream!.sink.add(_profilePosts);
    }, cancelOnError: true);
    yield* _profilePostsStream!.stream;
  }

  /// dispose profile posts stream controller to avoid memory leaks
  void disposeProfilePostsStream() {
    if (_profilePostsStream != null) _profilePostsStream!.close();
    if (_profilePostsStreamSubscription != null)
      _profilePostsStreamSubscription!.cancel();
  }

  /// query profile 6 friends or less to be displayed in the profile screen
  /// @param userID the id of the user whose the profile owner
  /// @return List of User objects that are friends with this user
  Future<List<User>> getUserFriendsForProfile(String userID) async {
    List<User> friends = await getFriends(userID);
    if (friends.length > 6) {
      friends.removeRange(6, friends.length);
    }
    return friends;
  }

  /// query current user notifications
  /// @return list of NotificationModel
  Future<List<NotificationModel>> getUserNotifications() async {
    List<NotificationModel> _userNotifications = [];
    QuerySnapshot<Map<String, dynamic>> result = await firestore
        .collection(NOTIFICATIONS)
        .where('toUserID', isEqualTo: MyAppState.currentUser!.userID)
        .orderBy('createdAt', descending: true)
        .get();

    Future.forEach(result.docs, (DocumentSnapshot<Map<String, dynamic>> document) {
      try {
        _userNotifications.add(NotificationModel.fromJson(document.data() ?? {}));
      } catch (e) {
        print('FireStoreUtils.getUserNotifications: notifications table '
            'invalid json structure exception, doc id is => ${document.id}');
      }
    });
    return _userNotifications;
  }

  /// update the NotificationModel to be seen
  /// @param NotificationModel the clicked notification to be updated
  updateNotification(NotificationModel notification) async {
    notification.seen = true;
    await firestore
        .collection(NOTIFICATIONS)
        .doc(notification.id)
        .update(notification.toJson());
  }

  /// uploads the post image to firestore storage
  /// @param File the image file that is being uploaded
  /// @param progress is a string of how many files are being uploaded and
  /// our current position for ex (uploading media 2 of 5 files)
  /// @return Url object contains the mime type of the file and a download url
  Future<Url> uploadPostImage(File image, String progress) async {
    var uniqueID = Uuid().v4();
    File compressedImage = await _compressImage(image);
    Reference upload = storage.child('flutter/social_network/images/$uniqueID'
        '.png');
    UploadTask uploadTask = upload.putFile(compressedImage);
    uploadTask.snapshotEvents.listen((event) {
      updateProgress('uploadingPostImageProgress'.tr(args: [
        progress,
        '${(event.bytesTransferred.toDouble() / 1000).toStringAsFixed(2)}',
        '${(event.totalBytes.toDouble() / 1000).toStringAsFixed(2)} '
      ]));
    });
    uploadTask.whenComplete(() {}).catchError((onError) {
      print((onError as PlatformException).message);
    });
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();

    return Url(mime: 'image', url: downloadUrl.toString());
  }

  /// uploads the post video to firestore storage
  /// @param File the video file that is being uploaded
  /// @param progress is a string of how many files are being uploaded and
  /// our current position for ex (uploading media 3 of 5 files)
  /// @return Url object contains the mime type of the file and a download url
  Future<Url> uploadPostVideo(
      File video, BuildContext context, File thumbnail, String progress) async {
    var uniqueID = Uuid().v4();
    File compressedVideo = await _compressVideo(video);
    Reference upload = storage.child('flutter/social_network/videos/$uniqueID.mp4');
    SettableMetadata metadata = new SettableMetadata(contentType: 'video');
    UploadTask uploadTask = upload.putFile(compressedVideo, metadata);
    uploadTask.snapshotEvents.listen((event) {
      updateProgress('uploadingPostVideoProgress'.tr(args: [
        progress,
        '${(event.bytesTransferred.toDouble() / 1000).toStringAsFixed(2)}',
        '${(event.totalBytes.toDouble() / 1000).toStringAsFixed(2)} '
      ]));
    });
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();

    String thumbnailDownloadUrl = await uploadPostVideoThumbnail(thumbnail);
    return Url(
        url: downloadUrl.toString(),
        mime: 'video',
        videoThumbnail: thumbnailDownloadUrl);
  }

  /// uploads a thumbnail for the video file to firestore storage
  /// @param file the image file of the thumbnail
  /// @return a string of the download url
  Future<String> uploadPostVideoThumbnail(File file) async {
    try {
      var uniqueID = Uuid().v4();
      File compressedImage = await _compressImage(file);
      Reference upload =
          storage.child('flutter/social_network/video_thumbnails/$uniqueID.png');
      UploadTask uploadTask = upload.putFile(compressedImage);
      var downloadUrl =
          await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
      return downloadUrl.toString();
    } catch (e, s) {
      print('FireStoreUtils.uploadPostVideoThumbnail $e $s');
      return 'no_thumbnail';
    }
  }

  /// publish the post to the audience
  /// @param postModel is the post that will be published
  publishPost(PostModel post) async {
    DocumentReference documentReference =
        firestore.collection(SOCIAL_DISCOVER).doc();
    post.id = documentReference.id;
    await documentReference.set(post.toJson());
    List<User> followers = await getFriends(MyAppState.currentUser!.userID);
    followers.add(MyAppState.currentUser!);
    await Future.forEach(followers, (User follower) async {
      await firestore
          .collection(FEED)
          .doc(follower.userID)
          .collection(MAIN_FEED)
          .doc(post.id)
          .set(post.toJson());
    });
  }

  /// publish the story to the audience
  /// @param storyFile is the story file that will be published
  /// @param storyType the type of the file (image or video), text is not
  /// supported yet
  postStory(File storyFile, String storyType) async {
    String storyUrl = await _uploadStory(storyFile, storyType);
    DocumentReference storyDocumentRef = firestore.collection(STORIES).doc();
    StoryModel story = StoryModel(
        author: MyAppState.currentUser,
        authorID: MyAppState.currentUser!.userID,
        createdAt: Timestamp.now(),
        storyType: storyType,
        id: storyDocumentRef.id,
        storyMediaURL: storyUrl);

    await storyDocumentRef.set(story.toJson());
    List<User> followers = await getFriends(MyAppState.currentUser!.userID);
    followers.add(MyAppState.currentUser!);
    await Future.forEach(followers, (User follower) async {
      await firestore
          .collection(FEED)
          .doc(follower.userID)
          .collection(STORIES_FEED)
          .doc(story.id)
          .set(story.toJson());
    });
  }

  /// uploads story file to firestore storage
  /// @param storyFile the file that needs to be uploaded
  /// @param storyType the type of the file (image or video), text is not
  /// supported yet
  _uploadStory(File storyFile, String storyType) async {
    var uniqueID = Uuid().v4();
    String ref =
        'flutter/social_network/stories/$uniqueID.${storyType == 'image' ? 'png' : 'mp4'}';
    if (storyType == 'image') {
      File compressedImage = await _compressImage(storyFile);
      storyFile = compressedImage;
    } else if (storyType == 'video') {
      File compressedVideo = await _compressVideo(storyFile);
      storyFile = compressedVideo;
    }
    Reference upload = storage.child(ref);
    UploadTask uploadTask = upload.putFile(storyFile);
    var downloadUrl =
        await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  /// delete the post from the firestore database
  /// @param postModel the post that will be deleted
  deletePost(PostModel post) async {
    await firestore.collection(SOCIAL_DISCOVER).doc(post.id).delete();
    QuerySnapshot result = await firestore
        .collectionGroup(MAIN_FEED)
        .where('id', isEqualTo: post.id)
        .get();

    await Future.forEach(result.docs, (DocumentSnapshot postDocument) async {
      await firestore.doc(postDocument.reference.path).delete();
    });
  }

  /// returns a string of the a social relation between the current user and
  /// another user
  /// @param userID the id of the other user
  /// @return string representation of the social relation between these two
  /// users for ex (Add friend / unfriend / accept request / cancel request)
  Future<String> getUserSocialRelation(String userID) async {
    String relation = 'Add Friend';
    DocumentSnapshot receivedRequestsTableResult = await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(RECEIVED_FRIEND_REQUESTS)
        .doc(userID)
        .get();

    DocumentSnapshot sentRequestsTableResult = await firestore
        .collection(SOCIAL_GRAPH)
        .doc(MyAppState.currentUser!.userID)
        .collection(SENT_FRIEND_REQUESTS)
        .doc(userID)
        .get();

    if (receivedRequestsTableResult.exists && sentRequestsTableResult.exists) {
      relation = 'Unfriend';
    } else if (receivedRequestsTableResult.exists) {
      relation = 'Accept';
    } else if (sentRequestsTableResult.exists) {
      relation = 'Cancel';
    }
    return relation;
  }

  /// do action based on the relation between the current user and the
  /// profile owner
  /// @param profileOwner is a User object of another user
  profileRelationButtonClick(String profileRelation, User profileOwner) async {
    if (profileRelation == 'Add Friend') {
      await sendFriendRequest(profileOwner, true);
    } else if (profileRelation == 'Unfriend') {
      await onUnFriend(profileOwner, true);
    } else if (profileRelation == 'Accept') {
      await onFriendAccept(profileOwner, true);
    } else if (profileRelation == 'Cancel') {
      await onCancelRequest(profileOwner, true);
    }
  }

  /// save notification to the firestore database
  /// @param type string of the notification type
  /// @param body string of the notification body
  /// @param toUser the target user that should recieve this notification
  /// @param title string of the notification title
  _saveNotification(String type, String body, User toUser, String title,
      Map<String, dynamic> metaData) async {
    DocumentReference notificationDocument =
        firestore.collection(NOTIFICATIONS).doc();
    NotificationModel notificationModel = NotificationModel(
        type: type,
        body: body,
        toUser: toUser,
        title: title,
        metadata: metaData,
        seen: false,
        createdAt: Timestamp.now(),
        id: notificationDocument.id,
        toUserID: toUser.userID);
    await notificationDocument.set(notificationModel.toJson());
  }

  /// compress image file to make it load faster but with lower quality,
  /// change the quality parameter to control the quality of the image after
  /// being compressed(100 = max quality - 0 = low quality)
  /// @param file the image file that will be compressed
  /// @return File a new compressed file with smaller size
  static Future<File> _compressImage(File file) async {
    File compressedImage = await FlutterNativeImage.compressImage(
      file.path,
      quality: 25,
    );
    return compressedImage;
  }

  static loginWithFacebook() async {
    /// creates a user for this facebook login when this user first time login
    /// and save the new user object to firebase and firebase auth
    FacebookAuth facebookAuth = FacebookAuth.instance;
    bool isLogged = await facebookAuth.accessToken != null;
    if (!isLogged) {
      LoginResult result = await facebookAuth
          .login(); // by default we request the email and the public profile
      if (result.status == LoginStatus.success) {
        // you are logged
        AccessToken? token = await facebookAuth.accessToken;
        return await handleFacebookLogin(await facebookAuth.getUserData(), token!);
      }
    } else {
      AccessToken? token = await facebookAuth.accessToken;
      return await handleFacebookLogin(await facebookAuth.getUserData(), token!);
    }
  }

  static handleFacebookLogin(
      Map<String, dynamic> userData, AccessToken token) async {
    auth.UserCredential authResult = await auth.FirebaseAuth.instance
        .signInWithCredential(auth.FacebookAuthProvider.credential(token.token));
    User? user = await getCurrentUser(authResult.user?.uid ?? '');
    List<String> fullName = (userData['name'] as String).split(' ');
    String firstName = '';
    String lastName = '';
    if (fullName.isNotEmpty) {
      firstName = fullName.first;
      lastName = fullName.skip(1).join(' ');
    }
    if (user != null) {
      user.profilePictureURL = userData['picture']['data']['url'];
      user.firstName = firstName;
      user.lastName = lastName;
      user.email = userData['email'];
      user.active = true;
      user.fcmToken = await firebaseMessaging.getToken() ?? '';
      dynamic result = await updateCurrentUser(user);
      return result;
    } else {
      user = User(
          email: userData['email'] ?? '',
          firstName: firstName,
          profilePictureURL: userData['picture']['data']['url'] ?? '',
          userID: authResult.user?.uid ?? '',
          lastOnlineTimestamp: Timestamp.now(),
          lastName: lastName,
          active: true,
          fcmToken: await firebaseMessaging.getToken() ?? '',
          phoneNumber: '',
          photos: [],
          settings: UserSettings());
      String? errorMessage = await firebaseCreateNewUser(user);
      if (errorMessage == null) {
        return user;
      } else {
        return errorMessage;
      }
    }
  }

  static loginWithApple() async {
    final appleCredential = await apple.TheAppleSignIn.performRequests([
      apple.AppleIdRequest(
          requestedScopes: [apple.Scope.email, apple.Scope.fullName])
    ]);
    if (appleCredential.error != null) {
      return 'Couldn\'t login with apple.';
    }

    if (appleCredential.status == apple.AuthorizationStatus.authorized) {
      final auth.AuthCredential credential =
          auth.OAuthProvider('apple.com').credential(
            accessToken: String.fromCharCodes(
            appleCredential.credential?.authorizationCode ?? []),
        idToken:
            String.fromCharCodes(appleCredential.credential?.identityToken ?? []),
      );
      return await handleAppleLogin(credential, appleCredential.credential!);
    } else {
      return 'Couldn\'t login with apple.';
    }
  }

  static handleAppleLogin(
    auth.AuthCredential credential,
    apple.AppleIdCredential appleIdCredential,
  ) async {
    auth.UserCredential authResult =
        await auth.FirebaseAuth.instance.signInWithCredential(credential);
    User? user = await getCurrentUser(authResult.user?.uid ?? '');
    if (user != null) {
      user.active = true;
      user.fcmToken = await firebaseMessaging.getToken() ?? '';
      dynamic result = await updateCurrentUser(user);
      return result;
    } else {
      user = User(
          email: appleIdCredential.email ?? '',
          firstName: appleIdCredential.fullName?.givenName ?? '',
          profilePictureURL: '',
          userID: authResult.user?.uid ?? '',
          lastOnlineTimestamp: Timestamp.now(),
          lastName: appleIdCredential.fullName?.familyName ?? '',
          active: true,
          fcmToken: await firebaseMessaging.getToken() ?? '',
          phoneNumber: '',
          photos: [],
          settings: UserSettings());
      String? errorMessage = await firebaseCreateNewUser(user);
      if (errorMessage == null) {
        return user;
      } else {
        return errorMessage;
      }
    }
  }

  /// save a new user document in the USERS table in firebase firestore
  /// returns an error message on failure or null on success
  static Future<String?> firebaseCreateNewUser(User user) async {
    try {
      await firestore.collection(USERS).doc(user.userID).set(user.toJson());
    } catch (e, s) {
      print('FireStoreUtils.firebaseCreateNewUser $e $s');
      return 'Couldn\'t sign up'.tr();
    }
  }

  /// login with email and password with firebase
  /// @param email user email
  /// @param password user password
  static Future<dynamic> loginWithEmailAndPassword(
      String email, String password) async {
    try {
      auth.UserCredential result = await auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      DocumentSnapshot<Map<String, dynamic>> documentSnapshot =
          await firestore.collection(USERS).doc(result.user?.uid ?? '').get();
      User? user;
      if (documentSnapshot.exists) {
        user = User.fromJson(documentSnapshot.data() ?? {});
        user.active = true;
        user.fcmToken = await firebaseMessaging.getToken() ?? '';
        await updateCurrentUser(user);
      }
      return user;
    } on auth.FirebaseAuthException catch (exception, s) {
      print(exception.toString() + '$s');
      switch ((exception).code) {
        case 'invalid-email':
          return 'Email address is malformed.';
        case 'wrong-password':
          return 'Wrong password.';
        case 'user-not-found':
          return 'No user corresponding to the given email address.';
        case 'user-disabled':
          return 'This user has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts to sign in as this user.';
      }
      return 'Unexpected firebase error, Please try again.';
    } catch (e, s) {
      print(e.toString() + '$s');
      return 'Login failed, Please try again.';
    }
  }

  ///submit a phone number to firebase to receive a code verification, will
  ///be used later to login
  static firebaseSubmitPhoneNumber(
    String phoneNumber,
    auth.PhoneCodeAutoRetrievalTimeout? phoneCodeAutoRetrievalTimeout,
    auth.PhoneCodeSent? phoneCodeSent,
    auth.PhoneVerificationFailed? phoneVerificationFailed,
    auth.PhoneVerificationCompleted? phoneVerificationCompleted,
  ) {
    auth.FirebaseAuth.instance.verifyPhoneNumber(
      timeout: Duration(minutes: 2),
      phoneNumber: phoneNumber,
      verificationCompleted: phoneVerificationCompleted!,
      verificationFailed: phoneVerificationFailed!,
      codeSent: phoneCodeSent!,
      codeAutoRetrievalTimeout: phoneCodeAutoRetrievalTimeout!,
    );
  }

  /// submit the received code to firebase to complete the phone number
  /// verification process
  static Future<dynamic> firebaseSubmitPhoneNumberCode(
      String verificationID, String code, String phoneNumber,
      {String firstName = 'Anonymous',
      String lastName = 'User',
      File? image}) async {
    auth.AuthCredential authCredential = auth.PhoneAuthProvider.credential(
        verificationId: verificationID, smsCode: code);
    auth.UserCredential userCredential =
        await auth.FirebaseAuth.instance.signInWithCredential(authCredential);
    User? user = await getCurrentUser(userCredential.user?.uid ?? '');
    if (user != null) {
      user.active = true;
      user.fcmToken = await firebaseMessaging.getToken() ?? '';
      await updateCurrentUser(user);
      return user;
    } else {
      /// create a new user from phone login
      String profileImageUrl = '';
      if (image != null) {
        profileImageUrl = await uploadUserImageToFireStorage(
            image, userCredential.user?.uid ?? '');
      }
      User user = User(
        firstName: firstName,
        lastName: lastName,
        fcmToken: await firebaseMessaging.getToken() ?? '',
        phoneNumber: phoneNumber,
        profilePictureURL: profileImageUrl,
        userID: userCredential.user?.uid ?? '',
        active: true,
        lastOnlineTimestamp: Timestamp.now(),
        photos: [],
        settings: UserSettings(),
        email: '',
      );
      String? errorMessage = await firebaseCreateNewUser(user);
      if (errorMessage == null) {
        return user;
      } else {
        return 'Couldn\'t create new user with phone number.';
      }
    }
  }

  /// compress video file to make it load faster but with lower quality,
  /// change the quality parameter to control the quality of the video after
  /// being compressed
  /// @param file the video file that will be compressed
  /// @return File a new compressed file with smaller size
  Future<File> _compressVideo(File file) async {
    MediaInfo? info = await VideoCompress.compressVideo(file.path,
        quality: VideoQuality.DefaultQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 24);
    if (info != null) {
      File compressedVideo = File(info.path!);
      return compressedVideo;
    } else {
      return file;
    }
  }

  static firebaseSignUpWithEmailAndPassword(String emailAddress, String password,
      File? image, String firstName, String lastName, String mobile) async {
    try {
      auth.UserCredential result = await auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: emailAddress, password: password);
      String profilePicUrl = '';
      if (image != null) {
        updateProgress('Uploading image, Please wait...'.tr());
        profilePicUrl =
            await uploadUserImageToFireStorage(image, result.user?.uid ?? '');
      }
      User user = User(
          email: emailAddress,
          settings: UserSettings(),
          photos: [],
          lastOnlineTimestamp: Timestamp.now(),
          active: true,
          phoneNumber: mobile,
          firstName: firstName,
          userID: result.user?.uid ?? '',
          lastName: lastName,
          fcmToken: await firebaseMessaging.getToken() ?? '',
          profilePictureURL: profilePicUrl);
      String? errorMessage = await firebaseCreateNewUser(user);
      if (errorMessage == null) {
        return user;
      } else {
        return 'Couldn\'t sign up for firebase, Please try again.';
      }
    } on auth.FirebaseAuthException catch (error) {
      print(error.toString() + '${error.stackTrace}');
      String message = 'Couldn\'t sign up';
      switch (error.code) {
        case 'email-already-in-use':
          message = 'Email already in use, Please pick another email!';
          break;
        case 'invalid-email':
          message = 'Enter valid e-mail';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled';
          break;
        case 'weak-password':
          message = 'Password must be more than 5 characters';
          break;
        case 'too-many-requests':
          message = 'Too many requests, Please try again later.';
          break;
      }
      return message;
    } catch (e, s) {
      print('FireStoreUtils.firebaseSignUpWithEmailAndPassword $e $s');
      return 'Couldn\'t sign up';
    }
  }

  static Future<auth.UserCredential?> reAuthUser(AuthProviders provider,
      {String? email,
      String? password,
      String? smsCode,
      String? verificationId,
      AccessToken? accessToken,
      apple.AuthorizationResult? appleCredential}) async {
    late auth.AuthCredential credential;
    switch (provider) {
      case AuthProviders.PASSWORD:
        credential = auth.EmailAuthProvider.credential(
            email: email!, password: password!);
        break;
      case AuthProviders.PHONE:
        credential = auth.PhoneAuthProvider.credential(
            smsCode: smsCode!, verificationId: verificationId!);
        break;
      case AuthProviders.FACEBOOK:
        credential = auth.FacebookAuthProvider.credential(accessToken!.token);
        break;
      case AuthProviders.APPLE:
        credential = auth.OAuthProvider('apple.com').credential(
          accessToken: String.fromCharCodes(
              appleCredential!.credential?.authorizationCode ?? []),
          idToken: String.fromCharCodes(
              appleCredential.credential?.identityToken ?? []),
        );
        break;
    }
    return await auth.FirebaseAuth.instance.currentUser!
        .reauthenticateWithCredential(credential);
  }

  static resetPassword(String emailAddress) async =>
      await auth.FirebaseAuth.instance
          .sendPasswordResetEmail(email: emailAddress);

  static deleteUser() async {
    try {
      //delete user posts from SOCIAL_DISCOVER table
      await firestore
          .collection(SOCIAL_DISCOVER)
          .where('authorID', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      //delete user posts from NOTIFICATIONS table
      await firestore
          .collection(NOTIFICATIONS)
          .where('toUserID', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      //delete user posts from SOCIAL_REACTIONS table
      await firestore
          .collection(SOCIAL_REACTIONS)
          .where('reactionAuthorID', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      //delete user posts from SOCIAL_COMMENTS table
      await firestore
          .collection(SOCIAL_COMMENTS)
          .where('authorID', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      //delete user posts from MAIN_FEED collection group
      await firestore
          .collectionGroup(MAIN_FEED)
          .where('authorID', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      //delete user posts from STORIES table
      await firestore
          .collection(STORIES)
          .where('authorID', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      //delete user stories from STORIES_FEED collection group
      await firestore
          .collectionGroup(STORIES_FEED)
          .where('authorID', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      //delete user stories from RECEIVED_FRIEND_REQUESTS collection group
      await firestore
          .collectionGroup(RECEIVED_FRIEND_REQUESTS)
          .where('id', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      //delete user stories from SENT_FRIEND_REQUESTS collection group
      await firestore
          .collectionGroup(SENT_FRIEND_REQUESTS)
          .where('id', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      //delete user stories from SOCIAL_GRAPH collection group
      await firestore
          .collection(SOCIAL_GRAPH)
          .doc(MyAppState.currentUser!.userID)
          .delete();

      // delete user records from CHANNEL_PARTICIPATION table
      await firestore
          .collection(CHANNEL_PARTICIPATION)
          .where('user', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      // delete user records from REPORTS table
      await firestore
          .collection(REPORTS)
          .where('source', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      // delete user records from REPORTS table
      await firestore
          .collection(REPORTS)
          .where('dest', isEqualTo: MyAppState.currentUser!.userID)
          .get()
          .then((value) async {
        for (var doc in value.docs) {
          await firestore.doc(doc.reference.path).delete();
        }
      });

      // delete user records from users table
      await firestore
          .collection(USERS)
          .doc(auth.FirebaseAuth.instance.currentUser!.uid)
          .delete();

      // delete user  from firebase auth
      await auth.FirebaseAuth.instance.currentUser!.delete();
    } catch (e, s) {
      print('FireStoreUtils.deleteUser $e $s');
    }
  }
}

/// send back/fore ground notification to the user related to this token
/// @param token the firebase token associated to the user
/// @param title the notification title
/// @param body the notification body
/// @param payload this is a map of data required if you want to handle click
/// events on the notification from system tray when the app is in the
/// background or killed
sendNotification(
    String token, String title, String body, Map<String, dynamic>? payload) async {
  await http.post(
    Uri.parse('https://fcm.googleapis.com/fcm/send'),
    headers: <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'key=$SERVER_KEY',
    },
    body: jsonEncode(
      <String, dynamic>{
        'notification': <String, dynamic>{'body': body, 'title': title},
        'priority': 'high',
        'data': payload ?? <String, dynamic>{},
        'to': token
      },
    ),
  );
}
