import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reaction_button/flutter_reaction_button.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/main.dart';
import 'package:flutter_social_network/model/MessageData.dart';
import 'package:flutter_social_network/model/PostModel.dart';
import 'package:flutter_social_network/model/SocialCommentModel.dart';
import 'package:flutter_social_network/model/SocialReactionModel.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/fullScreenImageViewer/FullScreenImageViewer.dart';
import 'package:flutter_social_network/ui/fullScreenVideoViewer/FullScreenVideoViewer.dart';
import 'package:flutter_social_network/ui/profile/ProfileScreen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class DetailedPostScreen extends StatefulWidget {
  final PostModel post;
  final Reaction postReaction;
  final List<SocialReactionModel?> reactions;

  const DetailedPostScreen(
      {Key? key,
      required this.post,
      required this.postReaction,
      required this.reactions})
      : super(key: key);

  @override
  _DetailedPostScreenState createState() => _DetailedPostScreenState();
}

class _DetailedPostScreenState extends State<DetailedPostScreen> {
  final fireStoreUtils = FireStoreUtils();
  late Future<List<SocialCommentModel>> _commentsFuture;
  TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fireStoreUtils.getBlocks().listen((shouldRefresh) {
      if (shouldRefresh) {
        if (mounted) setState(() {});
      }
    });
    _commentsFuture = fireStoreUtils.getPostComments(widget.post);
  }

  @override
  void dispose() {
    super.dispose();
    _commentController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'postOwner'.tr(args: ['${widget.post.author.firstName}']),
        ).tr(),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 4, right: 8, top: 4, left: 8),
              child: _buildPostWidget(widget.post),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: isDarkMode(context) ? Colors.grey[850] : Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2.0, right: 2),
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: ShapeDecoration(
                              shape: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(360),
                                  ),
                                  borderSide: BorderSide(
                                      style: BorderStyle.none,
                                      color: Colors.grey.shade400)),
                              color: isDarkMode(context)
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade200,
                            ),
                            child: TextField(
                              onChanged: (s) {
                                setState(() {});
                              },
                              textAlignVertical: TextAlignVertical.center,
                              controller: _commentController,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                hintText: 'addCommentToThisPost'.tr(),
                                hintStyle: TextStyle(color: Colors.grey.shade400),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(360),
                                    ),
                                    borderSide: BorderSide(style: BorderStyle.none)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(360),
                                    ),
                                    borderSide: BorderSide(style: BorderStyle.none)),
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              maxLines: 5,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                          icon: Icon(
                            Icons.send,
                            color: _commentController.text.isEmpty
                                ? Color(COLOR_PRIMARY).withOpacity(.5)
                                : Color(COLOR_PRIMARY),
                          ),
                          onPressed: () async {
                            if (_commentController.text.isNotEmpty) {
                              _postComment(_commentController.text, widget.post);
                              _commentController.clear();
                              setState(() {});
                            }
                          })
                    ],
                  ),
                ),
              ),
            ),
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
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
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
                    child:
                        displayCircleImage(post.author.profilePictureURL, 55, false),
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
                          style:
                              TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
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
                  ),
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
                                    post.postMedia[index].videoThumbnail != null &&
                                            post.postMedia[index].videoThumbnail!
                                                .isNotEmpty
                                        ? DecorationImage(
                                            image: Image.network(post
                                                    .postMedia[index]
                                                    .videoThumbnail!)
                                                .image)
                                        : null,
                              ),
                              child: Center(
                                child: FloatingActionButton(
                                  child: Icon(CupertinoIcons.play_arrow_solid),
                                  backgroundColor: Colors.white54,
                                  heroTag: post.id,
                                  onPressed: () => push(
                                    context,
                                    FullScreenVideoViewer(
                                        videoUrl: postMedia.url, heroTag: post.id),
                                  ),
                                ),
                              ),
                            );
                          } else if (postMedia.mime.contains('image')) {
                            return GestureDetector(
                                onTap: () => push(context,
                                    FullScreenImageViewer(imageUrl: postMedia.url)),
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
                        ),
                    ],
                  ),
                ),
              Row(
                children: [
                  SizedBox(width: 6),
                  FlutterReactionButtonCheck(
                    onReactionChanged: (reaction, index, isChecked) {
                      setState(() {
                        post.myReaction = Reaction(
                            id: reaction!.id,
                            icon: reaction.icon,
                            previewIcon: reaction.previewIcon);
                      });
                      if (isChecked) {
                        bool isNewReaction = false;
                        SocialReactionModel? postReaction = widget.reactions
                            .firstWhere((element) => element?.postID == post.id,
                                orElse: () {
                                  isNewReaction = true;
                          String reactionString = getReactionString(reaction!.id!);
                          SocialReactionModel newReaction = SocialReactionModel(
                              postID: post.id,
                              createdAt: Timestamp.now(),
                              reactionAuthorID: MyAppState.currentUser!.userID,
                              reaction: reactionString);
                          widget.reactions.add(newReaction);
                          return newReaction;
                        });
                        if (isNewReaction) {
                          setState(() {
                            post.reactionsCount++;
                          });
                          fireStoreUtils.postReaction(postReaction!, post);
                        } else {
                          postReaction!.reaction = getReactionString(reaction!.id!);
                          postReaction.createdAt = Timestamp.now();
                          fireStoreUtils.updateReaction(postReaction, post);
                        }
                      } else {
                        widget.reactions
                            .removeWhere((element) => element?.postID == post.id);
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
                          color: isDarkMode(context) ? Colors.grey.shade200 : null,
                        ),
                      ),
                      icon: Container(
                        color: Colors.transparent,
                        child: Image.asset(
                          'assets/images/like.png',
                          height: 20,
                          color: isDarkMode(context) ? Colors.grey.shade200 : null,
                        ),
                      ),
                    ),
                    selectedReaction: post.myReaction.id != 0
                        ? facebookReactions[post.myReaction.id! - 1]
                        : facebookReactions[0],
                  ),
                  SizedBox(width: 8),
                  if (post.reactionsCount.round() != 0)
                    Text('${post.reactionsCount.round()}'),
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 16.0, bottom: 16, left: 8, right: 8),
                    child: Icon(
                      CupertinoIcons.conversation_bubble,
                      size: 20,
                      color: isDarkMode(context) ? Colors.grey.shade200 : null,
                    ),
                  ),
                  if (post.commentCount.round() != 0)
                    Text('${post.commentCount.round()}'),
                ],
              ),
              FutureBuilder<List<SocialCommentModel>>(
                future: _commentsFuture,
                initialData: [],
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    );
                  } else {
                    return ListView.builder(
                      padding: EdgeInsets.only(top: 8, bottom: 60),
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data?.length ?? 0,
                      itemBuilder: (context, index) {
                        SocialCommentModel comment = snapshot.data![index];
                        return _commentWidget(comment);
                      },
                      shrinkWrap: true,
                    );
                  }
                },
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
          ),
        ],
      ),
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
        if (MyAppState.currentUser!.userID == post.authorID)
          CupertinoActionSheetAction(
            child: Text('deletePost').tr(),
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              showProgress(context, 'deletingPost'.tr(), false);
              await fireStoreUtils.deletePost(post);
              hideProgress();
              Navigator.pop(context);
            },
          )
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

  _commentWidget(SocialCommentModel comment) {
    return FutureBuilder<User?>(
      future: FireStoreUtils.getCurrentUser(comment.authorID),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator.adaptive(),
            ),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => push(
                    context,
                    ProfileScreen(
                      user: snapshot.data!,
                      fromContainer: false,
                    ),
                  ),
                  child: displayCircleImage(
                      snapshot.data!.profilePictureURL, 35, false),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(8),
                        color: isDarkMode(context)
                            ? Colors.black26
                            : Colors.grey.shade200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.data!.fullName(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('${comment.commentText} '),
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        }
      },
    );
  }

  _postComment(String comment, PostModel post) async {
    showProgress(context, 'postingComment'.tr(), false);
    await fireStoreUtils.postComment(comment, post);
    _commentsFuture = fireStoreUtils.getPostComments(widget.post);
    FocusScope.of(context).unfocus();
    hideProgress();
    widget.post.commentCount++;
  }
}
