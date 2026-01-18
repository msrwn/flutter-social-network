import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/main.dart';
import 'package:flutter_social_network/model/MessageData.dart';
import 'package:flutter_social_network/model/PostModel.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/fullScreenImageViewer/FullScreenImageViewer.dart';
import 'package:flutter_social_network/ui/fullScreenVideoViewer/FullScreenVideoViewer.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: GOOGLE_API_KEY);

class CreatePostScreen extends StatefulWidget {
  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  String _userLocation = '';
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, File?> _mediaFiles = Map.fromEntries([MapEntry('null', null)]);
  bool _hasPhotos = false;
  TextEditingController _postController = TextEditingController();
  FireStoreUtils _fireStoreUtils = FireStoreUtils();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('createPost').tr(),
        actions: [
          if (_postController.text.isNotEmpty || _mediaFiles.length >= 2)
            GestureDetector(
              onTap: () => _publishPost(),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    'post',
                    style: TextStyle(
                        color: Color(COLOR_PRIMARY), fontWeight: FontWeight.bold),
                  ).tr(),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(COLOR_PRIMARY), width: 2)),
                  child: displayCircleImage(
                      MyAppState.currentUser!.profilePictureURL, 65, false),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(
                          text: MyAppState.currentUser!.firstName,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode(context)
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade900)),
                      TextSpan(
                          text: '\n$_userLocation',
                          style: TextStyle(
                              color: isDarkMode(context)
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade900))
                    ]),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: TextField(
              keyboardType: TextInputType.multiline,
              maxLines: 50,
              controller: _postController,
              onChanged: (string) {
                setState(() {});
              },
              decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide.none),
                  hintText: 'whatIsOnYourMind'
                      .tr(args: ['${MyAppState.currentUser!.firstName}'])),
            ),
          ),
          Container(
            padding: Platform.isIOS ? EdgeInsets.only(bottom: 40) : EdgeInsets.zero,
            color: isDarkMode(context) ? Colors.black54 : Colors.grey.shade200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Visibility(
                  visible: _hasPhotos,
                  child: SizedBox(
                    height: 100,
                    child: ListView.builder(
                      itemCount: _mediaFiles.length,
                      itemBuilder: (context, index) =>
                          _imageBuilder(_mediaFiles.entries.elementAt(index)),
                      shrinkWrap: true,
                      scrollDirection: Axis.horizontal,
                    ),
                  ),
                ),
                SizedBox(height: 24),
                ListTile(
                  title: Text('addToYourPost').tr(),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                          child: Icon(
                            CupertinoIcons.photo_camera,
                            color: _hasPhotos ? Color(COLOR_PRIMARY) : null,
                          ),
                          onTap: () {
                            setState(() {
                              _hasPhotos = !_hasPhotos;
                            });
                          }),
                      SizedBox(width: 16),
                      GestureDetector(
                          child: Icon(
                            CupertinoIcons.location,
                          ),
                          onTap: () async {
                            Prediction? p = await PlacesAutocomplete.show(
                              context: context,
                              apiKey: GOOGLE_API_KEY,
                              mode: Mode.fullscreen,
                              language:
                                  EasyLocalization.of(context)?.locale.languageCode,
                            );
                            if (p != null) {
                              PlacesDetailsResponse placeData =
                                  await _places.getDetailsByPlaceId(p.placeId ?? '');
                              _userLocation =
                                  placeData.result.formattedAddress ?? '';
                              setState(() {});
                            }
                          }),
                    ],
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _imageBuilder(MapEntry<String, File?> mediaEntry) {
    bool isLastItem = mediaEntry.value == null;
    File? imageFile;
    if (!isLastItem) {
      if (!mediaEntry.key.startsWith('image')) {
        imageFile = File(mediaEntry.key);
      } else {
        imageFile = mediaEntry.value!;
      }
    }

    return GestureDetector(
      onTap: () {
        isLastItem
            ? _pickImage()
            : _viewOrDeleteImage(mediaEntry as MapEntry<String, File>);
      },
      child: Container(
        width: 100,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
          color: isLastItem ? Color(COLOR_PRIMARY) : Colors.transparent,
          child: isLastItem
              ? Icon(
                  CupertinoIcons.camera,
                  size: 40,
                  color: isDarkMode(context) ? Colors.black : Colors.white,
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        imageFile!,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (!mediaEntry.key.startsWith('image'))
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(
                          CupertinoIcons.play_circle,
                          color: Color(COLOR_PRIMARY),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  _viewOrDeleteImage(MapEntry<String, File> mediaEntry) {
    final action = CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () async {
            Navigator.pop(context);
            _mediaFiles.entries.toList().removeLast();
            _mediaFiles.removeWhere((key, value) => value == mediaEntry.value);
            _mediaFiles['null'] = null;
            setState(() {});
          },
          child: Text('removeMedia').tr(),
          isDestructiveAction: true,
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(context);
            mediaEntry.key.startsWith('image')
                ? push(
                    context,
                    FullScreenImageViewer(
                        imageUrl: 'preview', imageFile: mediaEntry.value))
                : push(
                    context,
                    FullScreenVideoViewer(
                      videoUrl: mediaEntry.key,
                      heroTag: 'videoPreview',
                      videoFile: mediaEntry.value,
                    ));
          },
          isDefaultAction: true,
          child: Text('viewMedia').tr(),
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

  _pickImage() {
    final action = CupertinoActionSheet(
      message: Text(
        'addMedia',
        style: TextStyle(fontSize: 15.0),
      ).tr(),
      actions: [
        CupertinoActionSheetAction(
          child: Text('chooseImageFromGallery').tr(),
          isDefaultAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? image =
                await _imagePicker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              _mediaFiles.remove('null');
              _mediaFiles['image ${image.path}'] = File(image.path);
              _mediaFiles['null'] = null;
              setState(() {});
            }
          },
        ),
        CupertinoActionSheetAction(
          child: Text('takeAPicture').tr(),
          isDestructiveAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? image =
                await _imagePicker.pickImage(source: ImageSource.camera);
            if (image != null) {
              _mediaFiles.remove('null');
              _mediaFiles['image ${image.path}'] = File(image.path);
              _mediaFiles['null'] = null;
              setState(() {});
            }
          },
        ),
        CupertinoActionSheetAction(
          child: Text('chooseVideoFromGallery').tr(),
          isDefaultAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? video =
                await _imagePicker.pickVideo(source: ImageSource.gallery);
            if (video != null) {
              String? videoThumbnail = await VideoThumbnail.thumbnailFile(
                  video: video.path,
                  thumbnailPath: (await getTemporaryDirectory()).path,
                  imageFormat: ImageFormat.PNG);
              _mediaFiles.remove('null');
              _mediaFiles[videoThumbnail!] = File(video.path);
              _mediaFiles['null'] = null;
              setState(() {});
            }
          },
        ),
        CupertinoActionSheetAction(
          child: Text('recordVideo').tr(),
          isDestructiveAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? video =
                await _imagePicker.pickVideo(source: ImageSource.camera);
            if (video != null) {
              String? videoThumbnail = await VideoThumbnail.thumbnailFile(
                  video: video.path,
                  thumbnailPath: (await getTemporaryDirectory()).path,
                  imageFormat: ImageFormat.PNG);
              _mediaFiles.remove('null');
              _mediaFiles[videoThumbnail!] = File(video.path);
              _mediaFiles['null'] = null;
              setState(() {});
            }
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

  _publishPost() async {
    List<Url> mediaFilesURLs = [];
    showProgress(context, 'Publishing post...', false);
    if (_mediaFiles.length > 1) {
      updateProgress(
          'uploadingPostMedia'.tr(args: ['1', '${_mediaFiles.length - 1}']));
      for (int i = 0; i < _mediaFiles.length - 1; i++) {
        if (i != 0)
          updateProgress('uploadingPostMedia'
              .tr(args: ['${i + 1}', '${_mediaFiles.length - 1}']));
        if (_mediaFiles.entries.elementAt(i).key.startsWith('image')) {
          Url image = await _fireStoreUtils.uploadPostImage(
              _mediaFiles.entries.elementAt(i).value!,
              'uploadMediaProgress'
                  .tr(args: ['${i + 1}', '${_mediaFiles.length - 1}']));
          mediaFilesURLs.add(image);
        } else {
          //upload post video
          Url videoUrl = await _fireStoreUtils.uploadPostVideo(
              _mediaFiles.entries.elementAt(i).value!,
              context,
              File(_mediaFiles.entries.elementAt(i).key),
              'uploadMediaProgress'
                  .tr(args: ['${i + 1}', '${_mediaFiles.length - 1}']));
          mediaFilesURLs.add(videoUrl);
        }
      }
    }
    updateProgress('publishingPostAlmostDone'.tr());
    PostModel post = PostModel(
        createdAt: Timestamp.now(),
        authorID: MyAppState.currentUser!.userID,
        reactions: Reactions(),
        commentCount: 0,
        author: MyAppState.currentUser,
        location: _userLocation,
        postMedia: mediaFilesURLs,
        postText: _postController.text.trim(),
        reactionsCount: 0);
    await _fireStoreUtils.publishPost(post);
    hideProgress();
    _postController.clear();
    _mediaFiles.clear();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('postPublishedSuccessfully').tr()));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }
}
