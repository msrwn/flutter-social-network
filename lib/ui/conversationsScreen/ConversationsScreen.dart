import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/main.dart';
import 'package:flutter_social_network/model/ConversationModel.dart';
import 'package:flutter_social_network/model/HomeConversationModel.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/chat/ChatScreen.dart';

class ConversationsScreen extends StatefulWidget {
  final User user;

  const ConversationsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State createState() {
    return _ConversationsState();
  }
}

class _ConversationsState extends State<ConversationsScreen> {
  late User user;
  final fireStoreUtils = FireStoreUtils();
  late Future<List<User>> _friendsFuture;
  late Stream<List<HomeConversationModel>> _conversationsStream;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    fireStoreUtils.getBlocks().listen((shouldRefresh) {
      if (shouldRefresh) {
        if (mounted) setState(() {});
      }
    });
    _friendsFuture = fireStoreUtils.getFriends(MyAppState.currentUser!.userID);
    _conversationsStream = fireStoreUtils.getConversations(user.userID);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: ListView(
        children: [
          FutureBuilder<List<User>>(
            future: _friendsFuture,
            initialData: [],
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Container(
                  child: Center(
                    child: CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(COLOR_ACCENT)),
                    ),
                  ),
                );
              } else {
                return SizedBox(
                  height: snap.hasData && snap.data!.isNotEmpty ? 100 : 0,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: snap.data?.length ?? 0,
                    // ignore: missing_return
                    itemBuilder: (BuildContext context, int index) {
                      User friend = snap.data![index];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 4, right: 4),
                        child: InkWell(
                          onTap: () async {
                            String channelID;
                            if (friend.userID.compareTo(user.userID) < 0) {
                              channelID = friend.userID + user.userID;
                            } else {
                              channelID = user.userID + friend.userID;
                            }
                            ConversationModel? conversationModel =
                                await fireStoreUtils.getChannelByIdOrNull(channelID);
                            push(
                                context,
                                ChatScreen(
                                    homeConversationModel: HomeConversationModel(
                                        isGroupChat: false,
                                        members: [friend],
                                        conversationModel: conversationModel)));
                          },
                          child: Column(
                            children: [
                              displayCircleImage(
                                  friend.profilePictureURL, 50, false),
                              Expanded(
                                child: Container(
                                  width: 75,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8.0, left: 8, right: 8),
                                    child: Text(
                                      '${friend.firstName}',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
            },
          ),
          StreamBuilder<List<HomeConversationModel>>(
            stream: _conversationsStream,
            initialData: [],
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  child: Center(
                    child: CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(COLOR_ACCENT)),
                    ),
                  ),
                );
              } else if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true)) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 150),
                  child: Center(
                      child: showEmptyState('noConversationsFound'.tr(),
                          'allYourConversationsWillShowUpHere'.tr())),
                );
              } else {
                return ListView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final homeConversationModel = snapshot.data![index];
                      if (homeConversationModel.isGroupChat) {
                        return Padding(
                          padding: const EdgeInsets.only(
                              left: 16.0, right: 16, top: 8, bottom: 8),
                          child: _buildConversationRow(homeConversationModel),
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.only(
                              left: 16.0, right: 16, top: 8, bottom: 8),
                          child: _buildConversationRow(homeConversationModel),
                        );
                      }
                    });
              }
            },
          )
        ],
      ),
    );
  }

  Widget _buildConversationRow(HomeConversationModel homeConversationModel) {
    String user1Image = '';
    String user2Image = '';
    if (homeConversationModel.members.length >= 2) {
      user1Image = homeConversationModel.members.first.profilePictureURL;
      user2Image = homeConversationModel.members.elementAt(1).profilePictureURL;
    }
    return homeConversationModel.isGroupChat
        ? Padding(
      padding: const EdgeInsetsDirectional.only(start: 16.0, bottom: 12.8),
            child: InkWell(
              onTap: () {
                push(context,
                    ChatScreen(homeConversationModel: homeConversationModel));
              },
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      displayCircleImage(user1Image, 44, false),
                      Positioned.directional(
                          textDirection: Directionality.of(context),
                          start: -16,
                          bottom: -12.8,
                          child: displayCircleImage(user2Image, 44, true))
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                          top: 8, end: 8, start: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            '${homeConversationModel.conversationModel!.name}',
                            style: TextStyle(
                              fontSize: 17,
                              color:
                                  isDarkMode(context) ? Colors.white : Colors.black,
                              fontFamily: Platform.isIOS ? 'sanFran' : 'Roboto',
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${homeConversationModel.conversationModel!.lastMessage} • ${formatTimestamp(homeConversationModel.conversationModel!.lastMessageDate.seconds)}',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xffACACAC),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          )
        : InkWell(
            onTap: () {
              push(
                context,
                ChatScreen(homeConversationModel: homeConversationModel),
              );
            },
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    displayCircleImage(
                        homeConversationModel.members.first.profilePictureURL,
                        60,
                        false),
                    Positioned.directional(
                        textDirection: Directionality.of(context),
                        end: 2.4,
                        bottom: 2.4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: homeConversationModel.members.first.active
                                ? Colors.green
                                : Colors.grey,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: isDarkMode(context)
                                    ? Color(0xFF303030)
                                    : Colors.white,
                                width: 1.6),
                          ),
                        ))
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsetsDirectional.only(top: 8, end: 8, start: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          '${homeConversationModel.members.first.fullName()}',
                          style: TextStyle(
                              fontSize: 17,
                              color:
                                  isDarkMode(context) ? Colors.white : Colors.black,
                              fontFamily: Platform.isIOS ? 'sanFran' : 'Roboto'),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${homeConversationModel.conversationModel!.lastMessage} • ${formatTimestamp(homeConversationModel.conversationModel!.lastMessageDate.seconds)}',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xffACACAC),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
  }
}
