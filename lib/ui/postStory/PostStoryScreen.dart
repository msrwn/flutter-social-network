import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

class PostStoryScreen extends StatefulWidget {
  final File storyFile;
  final String storyType;

  const PostStoryScreen({Key? key, required this.storyFile, required this.storyType})
      : super(key: key);

  @override
  _PostStoryScreenState createState() => _PostStoryScreenState();
}

class _PostStoryScreenState extends State<PostStoryScreen> {
  late VideoPlayerController _controller;
  FireStoreUtils _fireStoreUtils = FireStoreUtils();

  @override
  void initState() {
    super.initState();
    if (widget.storyType == 'video') {
      _controller = VideoPlayerController.file(widget.storyFile)
        ..initialize().then((_) {
          // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
          setState(() {});
        });
      _controller.setLooping(true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(
              CupertinoIcons.clear,
              color: Colors.grey.shade300,
            ),
            onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: widget.storyType == 'video'
          ? FloatingActionButton(
              heroTag: 'videoStory',
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying
                    ? CupertinoIcons.pause
                    : CupertinoIcons.play_arrow_solid,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Stack(
        children: [
          widget.storyType == 'image'
              ? PhotoView(
                  imageProvider: Image.file(widget.storyFile).image,
                )
              : Container(
                  color: Colors.black,
                  child: Center(
                    child: _controller.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: VideoPlayer(_controller),
                          )
                        : Container(),
                  ),
                ),
          Positioned.directional(
              textDirection: Directionality.of(context),
              bottom: 16,
              end: 16,
              child: TextButton(
                  style: TextButton.styleFrom(
                    shape: StadiumBorder(),
                    primary: isDarkMode(context)
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
                  onPressed: () => _postStory(widget.storyFile, widget.storyType),
                  child: Text('post').tr()))
        ],
      ),
    );
  }

  _postStory(File storyFile, String storyType) async {
    showProgress(context, 'uploadingYourStory'.tr(), false);
    await _fireStoreUtils.postStory(storyFile, storyType);
    hideProgress();
    Navigator.pop(context);
  }
}
