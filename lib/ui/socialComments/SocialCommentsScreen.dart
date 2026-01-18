import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/model/PostModel.dart';
import 'package:flutter_social_network/model/SocialCommentModel.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/profile/ProfileScreen.dart';

class SocialCommentsScreen extends StatefulWidget {
  final PostModel post;

  const SocialCommentsScreen({Key? key, required this.post}) : super(key: key);

  @override
  _SocialCommentsScreenState createState() => _SocialCommentsScreenState();
}

class _SocialCommentsScreenState extends State<SocialCommentsScreen> {
  late Future<List<SocialCommentModel>> _commentsFuture;
  final fireStoreUtils = FireStoreUtils();
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      child: DraggableScrollableSheet(
        maxChildSize: 1,
        initialChildSize: 1,
        minChildSize: .5,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: isDarkMode(context) ? Colors.grey[850] : Colors.grey.shade50,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  FutureBuilder<List<SocialCommentModel>>(
                      future: _commentsFuture,
                      initialData: [],
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        } else if (!snapshot.hasData ||
                            (snapshot.data?.isEmpty ?? true)) {
                          return Container(
                              child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Center(
                                child: showEmptyState(
                                    'noCommentsYet'.tr(), 'addANewCommentNow'.tr())),
                          ));
                        } else {
                          return GestureDetector(
                            onTap: () => FocusScope.of(context).unfocus(),
                            child: ListView.builder(
                              padding: EdgeInsets.only(top: 8, bottom: 8),
                              itemCount: snapshot.data!.length,
                              controller: controller,
                              itemBuilder: (context, index) {
                                SocialCommentModel comment = snapshot.data![index];
                                return _commentWidget(comment);
                              },
                              shrinkWrap: true,
                            ),
                          );
                        }
                      }),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: isDarkMode(context)
                          ? Colors.grey[850]
                          : Colors.grey.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Expanded(
                                child: Padding(
                                    padding:
                                        const EdgeInsets.only(left: 2.0, right: 2),
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
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 8),
                                          hintText: 'addCommentToThisPost'.tr(),
                                          hintStyle:
                                              TextStyle(color: Colors.grey.shade400),
                                          focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(360),
                                              ),
                                              borderSide: BorderSide(
                                                  style: BorderStyle.none)),
                                          enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(360),
                                              ),
                                              borderSide: BorderSide(
                                                  style: BorderStyle.none)),
                                        ),
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        maxLines: 5,
                                        minLines: 1,
                                        keyboardType: TextInputType.multiline,
                                      ),
                                    ))),
                            IconButton(
                                icon: Icon(
                                  Icons.send,
                                  color: _commentController.text.isEmpty
                                      ? Color(COLOR_PRIMARY).withOpacity(.5)
                                      : Color(COLOR_PRIMARY),
                                ),
                                onPressed: () async {
                                  if (_commentController.text.isNotEmpty) {
                                    _postComment(
                                        _commentController.text, widget.post);
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
          ),
        ),
      ),
    );
  }

  _commentWidget(SocialCommentModel comment) {
    return FutureBuilder<User?>(
        future: FireStoreUtils.getCurrentUser(comment.authorID),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // while data is loading:
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
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
                        )),
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
        });
  }

  _postComment(String comment, PostModel post) async {
    showProgress(context, 'postingComment'.tr(), false);
    await fireStoreUtils.postComment(comment, post);
    _commentsFuture = fireStoreUtils.getPostComments(widget.post);
    FocusScope.of(context).unfocus();
    hideProgress();
  }
}
