import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/conversationsScreen/ConversationsScreen.dart';
import 'package:flutter_social_network/ui/createGroup/CreateGroupScreen.dart';
import 'package:flutter_social_network/ui/createPost/CreatePostScreen.dart';
import 'package:flutter_social_network/ui/discover/DiscoverScreen.dart';
import 'package:flutter_social_network/ui/friends/FriendsScreen.dart';
import 'package:flutter_social_network/ui/home/HomeScreen.dart';
import 'package:flutter_social_network/ui/notifications/NotificationsScreen.dart';
import 'package:flutter_social_network/ui/postStory/PostStoryScreen.dart';
import 'package:flutter_social_network/ui/profile/ProfileScreen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

enum DrawerSelection { Feed, Discover, Conversations, Friends, Profile }

class ContainerScreen extends StatefulWidget {
  final User user;

  ContainerScreen({Key? key, required this.user}) : super(key: key);

  @override
  _ContainerScreen createState() {
    return _ContainerScreen();
  }
}

class _ContainerScreen extends State<ContainerScreen> {
  late User user;
  String _appBarTitle = 'feed'.tr();
  final ImagePicker _imagePicker = ImagePicker();
  final fireStoreUtils = FireStoreUtils();

  int _selectedTapIndex = 0;

  late Widget _currentWidget;
  DrawerSelection _drawerSelection = DrawerSelection.Feed;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    _currentWidget = HomeScreen(
      user: user,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: user,
      child: Consumer<User>(
        builder: (context, user, _) {
          return Scaffold(
            bottomNavigationBar: BottomNavigationBar(
                currentIndex: _selectedTapIndex,
                backgroundColor: Colors.white,
                onTap: (index) {
                  switch (index) {
                    case 0:
                      {
                        setState(() {
                          _selectedTapIndex = 0;
                          _drawerSelection = DrawerSelection.Feed;
                          _appBarTitle = 'feed'.tr();
                          _currentWidget = HomeScreen(user: user);
                        });
                        break;
                      }
                    case 1:
                      {
                        setState(() {
                          _selectedTapIndex = 1;
                          _drawerSelection = DrawerSelection.Discover;
                          _appBarTitle = 'discover'.tr();
                          _currentWidget = DiscoverScreen();
                        });
                        break;
                      }
                    case 2:
                      {
                        setState(() {
                          _selectedTapIndex = 2;
                          _drawerSelection = DrawerSelection.Conversations;
                          _appBarTitle = 'chat'.tr();
                          _currentWidget = ConversationsScreen(
                            user: user,
                          );
                        });
                        break;
                      }
                    case 3:
                      {
                        setState(() {
                          _selectedTapIndex = 3;
                          _drawerSelection = DrawerSelection.Friends;
                          _appBarTitle = 'friends'.tr();
                          _currentWidget = FriendsScreen(user: user);
                        });
                        break;
                      }
                    case 4:
                      {
                        setState(() {
                          _selectedTapIndex = 4;
                          _drawerSelection = DrawerSelection.Profile;
                          _appBarTitle = 'profile'.tr();
                          _currentWidget =
                              ProfileScreen(user: user, fromContainer: true);
                        });
                        break;
                      }
                  }
                },
                unselectedItemColor: Colors.grey,
                selectedItemColor: Color(COLOR_PRIMARY),
                items: [
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.home), label: 'feed'.tr()),
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.search), label: 'discover'.tr()),
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.conversation_bubble),
                      label: 'chat'.tr()),
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.person_2), label: 'friends'.tr()),
                  BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.person), label: 'profile'.tr()),
                ]),
            appBar: AppBar(
              title: Text(
                _appBarTitle,
              ),
              leading: _drawerSelection == DrawerSelection.Feed
                  ? IconButton(
                      tooltip: 'addStory'.tr(),
                      icon: Icon(
                        CupertinoIcons.camera,
                        color: isDarkMode(context)
                            ? Colors.grey.shade200
                            : Colors.black,
                      ),
                      onPressed: () => _showStoryMenu())
                  : null,
              actions: [
                if (_drawerSelection == DrawerSelection.Feed)
                  IconButton(
                    tooltip: 'createPost'.tr(),
                    icon: Image.asset(
                      'assets/images/create_post_img.png',
                      width: 24,
                      height: 24,
                      color:
                          isDarkMode(context) ? Colors.grey.shade200 : Colors.black,
                    ),
                    onPressed: () => push(context, CreatePostScreen()),
                  ),
                if (_drawerSelection == DrawerSelection.Conversations)
                  IconButton(
                    tooltip: 'createGroupChat'.tr(),
                    icon: Image.asset(
                      'assets/images/create_post_img.png',
                      width: 24,
                      height: 24,
                      color:
                          isDarkMode(context) ? Colors.grey.shade200 : Colors.black,
                    ),
                    onPressed: () => push(context, CreateGroupScreen()),
                  ),
                if (_drawerSelection == DrawerSelection.Profile)
                  IconButton(
                    tooltip: 'notifications'.tr(),
                    icon: Icon(
                      CupertinoIcons.bell_solid,
                      color: Color(COLOR_PRIMARY),
                    ),
                    onPressed: () => push(context, NotificationsScreen()),
                  )
              ],
            ),
            body: _currentWidget,
          );
        },
      ),
    );
  }

  _showStoryMenu() {
    final action = CupertinoActionSheet(
      message: Text(
        'addToYourStory',
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
            if (image != null)
              push(
                  context,
                  PostStoryScreen(
                      storyFile: File(image.path), storyType: 'image'));
          },
        ),
        CupertinoActionSheetAction(
          child: Text('takeAPicture').tr(),
          isDestructiveAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? image =
                await _imagePicker.pickImage(source: ImageSource.camera);
            if (image != null)
              push(
                  context,
                  PostStoryScreen(
                      storyFile: File(image.path), storyType: 'image'));
          },
        ),
        CupertinoActionSheetAction(
          child: Text('chooseVideoFromGallery').tr(),
          isDefaultAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? video =
                await _imagePicker.pickVideo(source: ImageSource.gallery);
            if (video != null)
              push(
                  context,
                  PostStoryScreen(
                      storyFile: File(video.path), storyType: 'video'));
          },
        ),
        CupertinoActionSheetAction(
          child: Text('recordVideo').tr(),
          isDestructiveAction: false,
          onPressed: () async {
            Navigator.pop(context);
            XFile? video =
                await _imagePicker.pickVideo(source: ImageSource.camera);
            if (video != null)
              push(
                  context,
                  PostStoryScreen(
                      storyFile: File(video.path), storyType: 'video'));
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
}
