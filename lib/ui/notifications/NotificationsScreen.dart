import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/model/NotificationModel.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationModel>> _notificationsFuture;
  FireStoreUtils _fireStoreUtils = FireStoreUtils();

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _fireStoreUtils.getUserNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('notifications').tr(),
      ),
      body: FutureBuilder<List<NotificationModel>>(
          future: _notificationsFuture,
          initialData: [],
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
                padding: const EdgeInsets.all(8.0),
                child: Container(
                    child: Center(
                        child: Padding(
                  padding: const EdgeInsets.only(bottom: 120.0),
                  child: showEmptyState('noNotificationsFound'.tr(),
                      'youCanFindNotificationsHere'.tr()),
                ))),
              );
            } else {
              return ListView.separated(
                  itemBuilder: (context, index) {
                    String notificationBody = '';
                    late Map? notificationMetaData;
                    try {
                      switch (snapshot.data![index].type) {
                        case 'chat_message':
                          notificationBody = 'justSentYouAPrivateMessage'.tr();
                          notificationMetaData =
                              snapshot.data![index].metadata['channelID'];
                          break;
                        case 'dating_match':
                          notificationBody = 'justMatchedWithYou'.tr();
                          notificationMetaData =
                              snapshot.data![index].metadata['fromUser'];
                          break;
                        case 'accept_friend':
                          notificationBody = 'justAcceptedYourFriendRequest'.tr();
                          notificationMetaData =
                              snapshot.data![index].metadata['fromUser'];
                          break;
                        case 'friend_request':
                          notificationBody = 'justSentYouAFriendRequest'.tr();
                          notificationMetaData =
                              snapshot.data![index].metadata['fromUser'];
                          break;
                        case 'posts':
                          notificationBody = 'sharedYourPost'.tr();
                          notificationMetaData =
                              snapshot.data![index].metadata['fromUser'];
                          break;
                        case 'social_comment':
                          notificationBody = 'commentedOnYourPost'.tr();
                          notificationMetaData =
                              snapshot.data![index].metadata['outBound'];
                          break;
                        case 'social_follow':
                          notificationBody = 'justFollowedYou'.tr();
                          notificationMetaData =
                              snapshot.data![index].metadata['fromUser'];
                          break;
                        case 'social_reaction':
                          notificationBody = 'justReactedToYourPost'.tr();
                          notificationMetaData =
                              snapshot.data![index].metadata['outBound'];
                          break;
                        default:
                          notificationBody = 'sentYouANewNotification'.tr();
                          break;
                      }
                    } catch (e) {}
                    return Container(
                      color: !snapshot.data![index].seen
                          ? Colors.lightBlueAccent.shade100.withOpacity(0.2)
                          : null,
                      child: ListTile(
                        enabled: !snapshot.data![index].seen,
                        onTap: snapshot.data![index].seen
                            ? () => null
                            : () {
                                snapshot.data![index].seen = true;
                                _fireStoreUtils
                                    .updateNotification(snapshot.data![index]);
                                setState(() {});
                              },
                        leading: notificationMetaData != null
                            ? snapshot.data![index].type != 'chat_message'
                                ? displayCircleImage(
                            notificationMetaData['profilePictureURL'] ?? '',
                                    40,
                                    true)
                                : Icon(CupertinoIcons.chat_bubble_fill,
                                    size: 35, color: Color(COLOR_PRIMARY))
                            : Icon(CupertinoIcons.bell_solid,
                                size: 35, color: Color(COLOR_PRIMARY)),
                        title: RichText(
                            text: TextSpan(children: [
                          TextSpan(
                              text: snapshot.data![index].title,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode(context)
                                      ? Colors.grey.shade300
                                      : Colors.black,
                                  fontSize: 17)),
                          TextSpan(
                              text: '  $notificationBody',
                              style: TextStyle(
                                  color: isDarkMode(context)
                                      ? Colors.grey.shade200
                                      : Colors.grey.shade800,
                                  fontSize: 17))
                        ])),
                        subtitle: Text(
                            '${setLastSeen(snapshot.data![index].createdAt.seconds)}'),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) => Divider(),
                  itemCount: snapshot.data!.length);
            }
          }),
    );
  }
}
