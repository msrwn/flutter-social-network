import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_reaction_button/flutter_reaction_button.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/main.dart';
import 'package:flutter_social_network/model/MessageData.dart';
import 'package:flutter_social_network/model/PostModel.dart';
import 'package:flutter_social_network/model/SocialReactionModel.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/allFriends/AllFriendsScreen.dart';
import 'package:flutter_social_network/ui/createPost/CreatePostScreen.dart';
import 'package:flutter_social_network/ui/detailedPost/DetailedPostScreen.dart';
import 'package:flutter_social_network/ui/fullScreenImageViewer/FullScreenImageViewer.dart';
import 'package:flutter_social_network/ui/fullScreenVideoViewer/FullScreenVideoViewer.dart';
import 'package:flutter_social_network/ui/notifications/NotificationsScreen.dart';
import 'package:flutter_social_network/ui/profileSettings/ProfileSettingsScreen.dart';
import 'package:flutter_social_network/ui/socialComments/SocialCommentsScreen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final bool fromContainer;

  ProfileScreen({Key? key, required this.user, required this.fromContainer})
      : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  late User user;
  FireStoreUtils _fireStoreUtils = FireStoreUtils();
  late Future<List<User>> _friendsFuture;
  late Stream<List<PostModel>> _userPosts;
  late Future<List<SocialReactionModel>> _myReactions;
  List<SocialReactionModel?> _reactionsList = [];
  Future<String>? _profileRelationFuture;
  String? _profileRelation;
  List<User> _friends = [];

  @override
  void initState() {
    user = widget.user;
    _friendsFuture = _fireStoreUtils.getUserFriendsForProfile(user.userID);
    _myReactions = _fireStoreUtils.getMyReactions()
      ..then((value) {
        _reactionsList.addAll(value);
      });
    _userPosts = _fireStoreUtils.getProfilePosts(user.userID);
    if (user.userID != MyAppState.currentUser!.userID)
      _profileRelationFuture = _fireStoreUtils.getUserSocialRelation(user.userID);
    _fireStoreUtils.getBlocks().listen((shouldRefresh) {
      if (shouldRefresh) {
        if (mounted) setState(() {});
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _fireStoreUtils.disposeProfilePostsStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.fromContainer
          ? null
          : AppBar(
        title: Text('profile').tr(),
              actions: [
                if (user.userID == MyAppState.currentUser!.userID)
                  IconButton(
                    tooltip: 'notifications'.tr(),
                    icon: Icon(
                      CupertinoIcons.bell_fill,
                      color: Color(COLOR_PRIMARY),
                    ),
                    onPressed: () => push(context, NotificationsScreen()),
                  ),
              ],
            ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16.0, left: 32, right: 32),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Center(
                      child: displayCircleImage(user.profilePictureURL, 130, false)),
                  Visibility(
                    visible: user.userID == MyAppState.currentUser!.userID,
                    child: Positioned.directional(
                      textDirection: Directionality.of(context),
                      start: 80,
                      end: 0,
                      child: FloatingActionButton(
                          backgroundColor: Color(COLOR_ACCENT),
                          child: Icon(
                            CupertinoIcons.camera,
                            color: isDarkMode(context) ? Colors.black : Colors.white,
                          ),
                          mini: true,
                          onPressed: _onCameraClick),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0, right: 32, left: 32),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  user.fullName(),
                  style: TextStyle(
                      color:
                          isDarkMode(context) ? Colors.grey.shade200 : Colors.black,
                      fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0, left: 16, right: 16),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                child: TextButton(
                  onPressed: () async {
                    if (user.userID == MyAppState.currentUser!.userID) {
                      push(context, ProfileSettingsScreen());
                    } else {
                      if (_profileRelation != null) {
                        showProgress(context, 'loading'.tr(), false);
                        await _fireStoreUtils.profileRelationButtonClick(
                            _profileRelation!, user);
                        hideProgress();
                        _profileRelationFuture =
                            _fireStoreUtils.getUserSocialRelation(user.userID);
                        setState(() {});
                      }
                    }
                  },
                  child: user.userID == MyAppState.currentUser!.userID
                      ? Text('profileSettings').tr()
                      : FutureBuilder<String>(
                          future: _profileRelationFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting)
                              return CircularProgressIndicator.adaptive();
                            _profileRelation = snapshot.data;
                            return Text(snapshot.data!);
                          },
                        ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    primary: Color(COLOR_PRIMARY),
                    backgroundColor: Color(COLOR_PRIMARY).withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'friends',
                style: TextStyle(
                    color: isDarkMode(context) ? Colors.grey.shade200 : Colors.black,
                    fontSize: 20),
              ).tr(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: FutureBuilder<List<User>>(
                future: _friendsFuture,
                initialData: [],
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return Center(child: CircularProgressIndicator.adaptive());
                  if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true))
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Center(
                          child: showEmptyState(
                              'noFriendsFound'.tr(), 'feelsLonely'.tr())),
                    );
                  _friends = snapshot.data!;
                  Future.delayed(Duration(milliseconds: 300), () {
                    if (mounted) setState(() {});
                  });
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: .8,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10),
                    itemBuilder: (context, index) =>
                        _buildFriendCard(snapshot.data![index]),
                    itemCount: snapshot.data!.length,
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                  );
                },
              ),
            ),
            Visibility(
              visible: _friends.isNotEmpty,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                  child: TextButton(
                    onPressed: () => push(
                        context,
                        AllFriendsScreen(
                          user: user,
                        )),
                    child: Text('seeAllFriends').tr(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      primary:
                          isDarkMode(context) ? Colors.grey.shade200 : Colors.black,
                      backgroundColor: isDarkMode(context)
                          ? Colors.grey.shade200.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            StreamBuilder<List<PostModel>>(
              stream: _userPosts,
              initialData: [],
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  );
                if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true))
                  return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 32.0, vertical: 30),
                      child: Center(
                        child: showEmptyState(
                            'noPostsFound'.tr(),
                            widget.user.userID == MyAppState.currentUser!.userID
                                ? 'allYourPostsWillShowUpHere'.tr()
                                : 'haveNotPublishedAnyPosts'
                                    .tr(args: ['${widget.user.firstName}']),
                            buttonTitle: 'createPost'.tr(),
                            isDarkMode: isDarkMode(context),
                            action:
                                widget.user.userID == MyAppState.currentUser!.userID
                                    ? () => push(context, CreatePostScreen())
                                    : null),
                      ));

                return ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(vertical: 4),
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) =>
                        _buildPostWidget(snapshot.data![index]));
              },
            ),
          ],
        ),
      ),
    );
  }

  _onCameraClick() {
    final action = CupertinoActionSheet(
      message: Text(
        'addProfilePicture',
        style: TextStyle(fontSize: 15.0),
      ).tr(),
      actions: [
        CupertinoActionSheetAction(
          child: Text('removePicture').tr(),
          isDestructiveAction: true,
          onPressed: () async {
            Navigator.pop(context);
            showProgress(context, 'removingPicture'.tr(), false);
            if (user.profilePictureURL.isNotEmpty)
              await _fireStoreUtils.deleteImage(user.profilePictureURL);
            user.profilePictureURL = '';
            await FireStoreUtils.updateCurrentUser(user);
            MyAppState.currentUser = user;
            hideProgress();
            setState(() {});
          },
        ),
        CupertinoActionSheetAction(
          child: Text('chooseFromGallery').tr(),
          onPressed: () async {
            Navigator.pop(context);
            XFile? image =
                await _imagePicker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              await _imagePicked(File(image.path));
            }
            setState(() {});
          },
        ),
        CupertinoActionSheetAction(
          child: Text('takeAPicture').tr(),
          onPressed: () async {
            Navigator.pop(context);
            XFile? image =
                await _imagePicker.pickImage(source: ImageSource.camera);
            if (image != null) {
              await _imagePicked(File(image.path));
            }
            setState(() {});
          },
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('cancel').tr(),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  Future<void> _imagePicked(File image) async {
    showProgress(context, 'uploadingImage'.tr(), false);
    user.profilePictureURL =
        await FireStoreUtils.uploadUserImageToFireStorage(image, user.userID);
    await FireStoreUtils.updateCurrentUser(user);
    MyAppState.currentUser = user;
    hideProgress();
  }

  Widget _buildFriendCard(User friend) {
    return GestureDetector(
      onTap: () => push(context, ProfileScreen(user: friend, fromContainer: false)),
      child: Card(
        shape: RoundedRectangleBorder(
          side: BorderSide.none,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                    topRight: Radius.circular(6), topLeft: Radius.circular(6)),
                child: CachedNetworkImage(
                  imageUrl: friend.profilePictureURL,
                  fit: BoxFit.cover,
                  placeholder: (context, imageUrl) {
                    return Icon(
                      CupertinoIcons.hourglass,
                      size: 75,
                      color: Color(COLOR_PRIMARY),
                    );
                  },
                  errorWidget: (context, imageUrl, error) {
                    return Icon(
                      Icons.error_outline,
                      size: 75,
                      color: Color(COLOR_PRIMARY),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4.0, 4, 4, 16),
              child: Text(friend.firstName),
            )
          ],
        ),
      ),
    );
  }

  _buildPostWidget(PostModel post) {
    PageController _controller = PageController(
      initialPage: 0,
    );
    return GestureDetector(
      onTap: () {
        _showDetailedPost(post, post.myReaction);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => push(context,
                            ProfileScreen(user: post.author, fromContainer: false)),
                        child: displayCircleImage(
                            post.author.profilePictureURL, 55, false),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.author.fullName(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17),
                            ),
                            SizedBox(
                              height: 2,
                            ),
                            Text(
                              setLastSeen(post.createdAt.seconds),
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            if (post.location.isNotEmpty ||
                                post.location != 'Unknown Location')
                              Text(post.location),
                          ],
                        ),
                      )
                    ],
                  ),
                  post.postText.isEmpty
                      ? SizedBox(height: 8)
                      : Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            post.postText,
                            style: TextStyle(
                                color: isDarkMode(context)
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade900),
                          ),
                        ),
                  if (post.postMedia.isNotEmpty)
                    Container(
                      height: 250,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _controller,
                            itemCount: post.postMedia.length,
                            itemBuilder: (context, index) {
                              Url postMedia = post.postMedia[index];
                              if (postMedia.mime.contains('video')) {
                                return Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                        color: Colors.black,
                                        image:
                                            post.postMedia[index].videoThumbnail !=
                                                        null &&
                                                    post.postMedia[index]
                                                        .videoThumbnail!.isNotEmpty
                                                ? DecorationImage(
                                                    image: Image.network(post
                                                            .postMedia[index]
                                                            .videoThumbnail!)
                                                        .image)
                                                : null),
                                    child: Center(
                                      child: FloatingActionButton(
                                        child: Icon(CupertinoIcons.play_arrow_solid),
                                        backgroundColor: Colors.white54,
                                        heroTag: post.id,
                                        onPressed: () => push(
                                            context,
                                            FullScreenVideoViewer(
                                                videoUrl: postMedia.url,
                                                heroTag: post.id)),
                                      ),
                                    ));
                              } else if (postMedia.mime.contains('image')) {
                                return GestureDetector(
                                    onTap: () => push(
                                        context,
                                        FullScreenImageViewer(
                                            imageUrl: postMedia.url)),
                                    child: displayImage(postMedia.url, 150));
                              } else {
                                return Container();
                              }
                            },
                          ),
                          if (post.postMedia.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 30.0),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: SmoothPageIndicator(
                                  controller: _controller,
                                  count: post.postMedia.length,
                                  effect: ScrollingDotsEffect(
                                      dotWidth: 6,
                                      dotHeight: 6,
                                      dotColor: isDarkMode(context)
                                          ? Colors.white54
                                          : Colors.black54,
                                      activeDotColor: Color(COLOR_PRIMARY)),
                                ),
                              ),
                            )
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      SizedBox(width: 6),
                      FutureBuilder<List<SocialReactionModel>>(
                        future: _myReactions,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            SocialReactionModel? _postReaction;

                            if (snapshot.data!.isNotEmpty) {
                              _postReaction = _reactionsList.firstWhereOrNull(
                                  (element) => element?.postID == post.id);
                              if (_postReaction != null) {
                                switch (_postReaction.reaction) {
                                  case 'like':
                                    post.myReaction = Reaction(
                                      id: 1,
                                      previewIcon: buildPreviewIconFacebook(
                                          'assets/images/like.gif'),
                                      icon: buildIconFacebook(
                                          'assets/images/like_fill.png'),
                                    );
                                    break;
                                  case 'love':
                                    post.myReaction = Reaction(
                                      id: 2,
                                      previewIcon: buildPreviewIconFacebook(
                                          'assets/images/love.gif'),
                                      icon: buildIconFacebook(
                                          'assets/images/love.png'),
                                    );
                                    break;
                                  case 'surprised':
                                    post.myReaction = Reaction(
                                      id: 3,
                                      previewIcon: buildPreviewIconFacebook(
                                          'assets/images/wow.gif'),
                                      icon:
                                          buildIconFacebook('assets/images/wow.png'),
                                    );
                                    break;
                                  case 'laugh':
                                    post.myReaction = Reaction(
                                      id: 4,
                                      previewIcon: buildPreviewIconFacebook(
                                          'assets/images/haha.gif'),
                                      icon: buildIconFacebook(
                                          'assets/images/haha.png'),
                                    );
                                    break;
                                  case 'sad':
                                    post.myReaction = Reaction(
                                      id: 5,
                                      previewIcon: buildPreviewIconFacebook(
                                          'assets/images/sad.gif'),
                                      icon:
                                          buildIconFacebook('assets/images/sad.png'),
                                    );
                                    break;
                                  case 'angry':
                                    post.myReaction = Reaction(
                                      id: 6,
                                      previewIcon: buildPreviewIconFacebook(
                                          'assets/images/angry.gif'),
                                      icon: buildIconFacebook(
                                          'assets/images/angry.png'),
                                    );
                                    break;
                                  default:
                                    post.myReaction = Reaction(
                                      id: 0,
                                      previewIcon: buildPreviewIconFacebook(
                                          'assets/images/like.png'),
                                      icon: buildIconFacebook(
                                          'assets/images/like.png'),
                                    );
                                    break;
                                }
                              }
                            }
                            return FlutterReactionButtonCheck(
                              onReactionChanged: (reaction, index, isChecked) {
                                setState(() {
                                  post.myReaction = Reaction(
                                      id: reaction!.id,
                                      icon: reaction.icon,
                                      previewIcon: reaction.previewIcon);
                                });
                                if (isChecked) {
                                  bool isNewReaction = false;
                                  SocialReactionModel? postReaction = _reactionsList
                                      .firstWhere(
                                          (element) => element?.postID == post.id,
                                          orElse: () {
                                    isNewReaction = true;
                                    String reactionString =
                                        getReactionString(reaction!.id!);
                                    SocialReactionModel newReaction =
                                        SocialReactionModel(
                                            postID: post.id,
                                            createdAt: Timestamp.now(),
                                            reactionAuthorID:
                                                MyAppState.currentUser!.userID,
                                            reaction: reactionString);
                                    _reactionsList.add(newReaction);
                                    return newReaction;
                                  });
                                  if (isNewReaction) {
                                    setState(() {
                                      post.reactionsCount++;
                                    });
                                    _fireStoreUtils.postReaction(
                                        postReaction!, post);
                                  } else {
                                    postReaction!.reaction =
                                        getReactionString(reaction!.id!);
                                    postReaction.createdAt = Timestamp.now();
                                    _fireStoreUtils.updateReaction(
                                        postReaction, post);
                                  }
                                } else {
                                  _reactionsList.removeWhere(
                                      (element) => element!.postID == post.id);
                                  setState(() {
                                    post.reactionsCount--;
                                  });
                                  _fireStoreUtils.removeReaction(post);
                                }
                              },
                              isChecked: post.myReaction.id != 0,
                              reactions: facebookReactions,
                              initialReaction: Reaction(
                                  id: 0,
                                  previewIcon: Container(
                                    color: Colors.transparent,
                                    child: Image.asset(
                                      'assets/images/like.png',
                                      height: 20,
                                      color: isDarkMode(context)
                                          ? Colors.grey.shade200
                                          : null,
                                    ),
                                  ),
                                  icon: Container(
                                    color: Colors.transparent,
                                    child: Image.asset(
                                      'assets/images/like.png',
                                      height: 20,
                                      color: isDarkMode(context)
                                          ? Colors.grey.shade200
                                          : null,
                                    ),
                                  )),
                              selectedReaction: post.myReaction.id != 0
                                  ? facebookReactions[post.myReaction.id! - 1]
                                  : facebookReactions[0],
                            );
                          } else {
                            return Container();
                          }
                        },
                      ),
                      SizedBox(width: 6),
                      if (post.reactionsCount.round() != 0)
                        Text('${post.reactionsCount.round()}'),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: InkWell(
                            child: Icon(
                              CupertinoIcons.conversation_bubble,
                              size: 20,
                              color:
                                  isDarkMode(context) ? Colors.grey.shade200 : null,
                            ),
                            onTap: () => _showCommentsSheet(post)),
                      ),
                      if (post.commentCount.round() != 0)
                        Text('${post.commentCount.round()}'),
                    ],
                  ),
                ],
              ),
              Positioned.directional(
                textDirection: Directionality.of(context),
                top: 0,
                end: 0,
                child: IconButton(
                  icon: Icon(
                    CupertinoIcons.ellipsis,
                    color: Colors.grey,
                  ),
                  onPressed: () => _postSettingsMenu(post),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  _showCommentsSheet(PostModel post) {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SocialCommentsScreen(post: post);
      },
    );
  }

  _postSettingsMenu(PostModel post) {
    final action = CupertinoActionSheet(
      message: Text(
        'postSettings',
        style: TextStyle(fontSize: 15.0),
      ).tr(),
      actions: [
        if (user.userID != MyAppState.currentUser!.userID)
          CupertinoActionSheetAction(
            child: Text('block').tr(),
            onPressed: () async {
              Navigator.pop(context);
              showProgress(context, 'blockingUser'.tr(), false);
              bool isSuccessful =
                  await _fireStoreUtils.blockUser(post.author, 'block');
              hideProgress();
              if (isSuccessful) {
                Navigator.pop(context);
                showAlertDialog(context, 'block'.tr(),
                    'hasBeenBlocked'.tr(args: ['${post.author.fullName()}']), false);
              } else {
                showAlertDialog(context, 'block'.tr(),
                    'couldNotBlock'.tr(args: ['${post.author.fullName()}']), false);
              }
            },
          ),
        if (user.userID != MyAppState.currentUser!.userID)
          CupertinoActionSheetAction(
            child: Text('reportPost').tr(),
            onPressed: () async {
              Navigator.pop(context);
              showProgress(context, 'reportingPost'.tr(), false);
              bool isSuccessful =
                  await _fireStoreUtils.blockUser(post.author, 'report');
              hideProgress();
              if (isSuccessful) {
                Navigator.pop(context);
                showAlertDialog(
                    context,
                    'report'.tr(),
                    'postHasBeenReported'.tr(args: ['${post.author.fullName()}']),
                    false);
              } else {
                showAlertDialog(
                    context,
                    'report'.tr(),
                    'couldnNotReportPost'.tr(args: ['${post.author.fullName()}']),
                    false);
              }
            },
          ),
        CupertinoActionSheetAction(
          child: Text('sharePost').tr(),
          onPressed: () async {
            Navigator.pop(context);
            sharePost(post);
          },
        ),
        if (user.userID == MyAppState.currentUser!.userID)
          CupertinoActionSheetAction(
            child: Text('deletePost').tr(),
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              showProgress(context, 'deletingPost'.tr(), false);
              await _fireStoreUtils.deletePost(post);
              hideProgress();
            },
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        child: Text('cancel').tr(),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
    showCupertinoModalPopup(context: context, builder: (context) => action);
  }

  void _showDetailedPost(PostModel post, Reaction defaultInitialReaction) {
    push(
        context,
        DetailedPostScreen(
          post: post,
          postReaction: defaultInitialReaction,
          reactions: _reactionsList,
        ));
  }
}
