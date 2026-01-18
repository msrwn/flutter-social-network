import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reaction_button/flutter_reaction_button.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/main.dart';
import 'package:flutter_social_network/model/MessageData.dart';
import 'package:flutter_social_network/model/PostModel.dart';
import 'package:flutter_social_network/model/SocialReactionModel.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/createPost/CreatePostScreen.dart';
import 'package:flutter_social_network/ui/detailedPost/DetailedPostScreen.dart';
import 'package:flutter_social_network/ui/fullScreenImageViewer/FullScreenImageViewer.dart';
import 'package:flutter_social_network/ui/fullScreenVideoViewer/FullScreenVideoViewer.dart';
import 'package:flutter_social_network/ui/profile/ProfileScreen.dart';
import 'package:flutter_social_network/ui/socialComments/SocialCommentsScreen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class DiscoverScreen extends StatefulWidget {
  @override
  _DiscoverScreenState createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final fireStoreUtils = FireStoreUtils();
  late Stream<List<PostModel>> _postsStream;
  late Future<List<SocialReactionModel>> _myReactions;
  List<SocialReactionModel?> _reactionsList = [];

  @override
  void initState() {
    _myReactions = fireStoreUtils.getMyReactions()
      ..then((value) {
        _reactionsList.addAll(value);
      });
    _postsStream = fireStoreUtils.discoverPosts();
    fireStoreUtils.getBlocks().listen((shouldRefresh) {
      if (shouldRefresh) {
        if (mounted) setState(() {});
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    fireStoreUtils.disposeDiscoverStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<PostModel>>(
        stream: _postsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
            );
          } else if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
            return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 150),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 120.0),
                    child: showEmptyState(
                        'noPostsFound'.tr(), 'allDiscoverPostsWillShowUpHere'.tr(),
                        buttonTitle: 'createPost'.tr(),
                        isDarkMode: isDarkMode(context),
                        action: () => push(context, CreatePostScreen())),
                  ),
                ));
          } else {
            return ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 4),
                itemCount: snapshot.data!.length,
                shrinkWrap: true,
                itemBuilder: (context, index) =>
                    _buildPostWidget(snapshot.data![index]));
          }
        },
        initialData: [],
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
                                          child:
                                              Icon(CupertinoIcons.play_arrow_solid),
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
                              }),
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
                            ),
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
                                    fireStoreUtils.postReaction(postReaction!, post);
                                  } else {
                                    postReaction!.reaction =
                                        getReactionString(reaction!.id!);
                                    postReaction.createdAt = Timestamp.now();
                                    fireStoreUtils.updateReaction(
                                        postReaction, post);
                                  }
                                } else {
                                  _reactionsList.removeWhere(
                                      (element) => element!.postID == post.id);
                                  setState(() {
                                    post.reactionsCount--;
                                  });
                                  fireStoreUtils.removeReaction(post);
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
                    onPressed: () => _postSettingsMenu(post)),
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
        if (MyAppState.currentUser!.userID != post.authorID)
          CupertinoActionSheetAction(
            child: Text('block').tr(),
            onPressed: () async {
              Navigator.pop(context);
              showProgress(context, 'blockingUser'.tr(), false);
              bool isSuccessful =
                  await fireStoreUtils.blockUser(post.author, 'block');
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
        if (MyAppState.currentUser!.userID != post.authorID)
          CupertinoActionSheetAction(
            child: Text('reportPost').tr(),
            onPressed: () async {
              Navigator.pop(context);
              showProgress(context, 'reportingPost'.tr(), false);
              bool isSuccessful =
                  await fireStoreUtils.blockUser(post.author, 'report');
              hideProgress();
              if (isSuccessful) {
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
        if (MyAppState.currentUser!.userID == post.authorID)
          CupertinoActionSheetAction(
            child: Text('deletePost').tr(),
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              showProgress(context, 'deletingPost'.tr(), false);
              await fireStoreUtils.deletePost(post);
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
      ),
    );
  }
}
