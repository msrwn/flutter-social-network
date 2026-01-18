import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_social_network/model/ContactModel.dart';
import 'package:flutter_social_network/model/ConversationModel.dart';
import 'package:flutter_social_network/model/HomeConversationModel.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/chat/ChatScreen.dart';
import 'package:flutter_social_network/ui/profile/ProfileScreen.dart';
import 'package:flutter_social_network/ui/searchScreen/SearchScreen.dart';

List<ContactModel> _contacts = [];

class FriendsScreen extends StatefulWidget {
  final User user;

  const FriendsScreen({Key? key, required this.user}) : super(key: key);

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<FriendsScreen> {
  late User user;
  final fireStoreUtils = FireStoreUtils();

  late Future<List<ContactModel>> _future;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    fireStoreUtils.getBlocks().listen((shouldRefresh) {
      if (shouldRefresh) {
        if (mounted) setState(() {});
      }
    });
    _future = fireStoreUtils.getContacts(user.userID, false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 4),
          child: ConstrainedBox(
              constraints:
                  BoxConstraints(minWidth: MediaQuery.of(context).size.width),
              child: TextButton(
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => SearchScreen(user: user)));
                    _future = fireStoreUtils.getContacts(user.userID, false);
                    setState(() {});
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: isDarkMode(context)
                        ? Colors.grey.shade700
                        : Colors.grey.shade200,
                    shape: StadiumBorder(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.search,
                      ),
                      Text('search').tr(),
                    ],
                  ))),
        ),
        FutureBuilder<List<ContactModel>>(
          future: _future,
          initialData: [],
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return Expanded(
                child: Container(
                  child: Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                ),
              );
            if (!snap.hasData || (snap.data?.isEmpty ?? true))
              return Expanded(
                child: Center(
                    child: Padding(
                  padding: const EdgeInsets.only(bottom: 120.0),
                  child: showEmptyState(
                      'noFriendsFound'.tr(), 'startAddingYourFriendsNow'.tr(),
                      isDarkMode: isDarkMode(context),
                      buttonTitle: 'addFriends'.tr(),
                      action: () => push(context, SearchScreen(user: user))),
                )),
              );

            return Expanded(
              child: ListView.separated(
                separatorBuilder: (context, index) => Divider(),
                itemCount: snap.data!.length,
                itemBuilder: (BuildContext context, int index) {
                  _contacts = snap.data!;
                  ContactModel contact = snap.data![index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                    child: ListTile(
                      onTap: () async {
                        String channelID;
                        if (contact.user.userID.compareTo(user.userID) < 0) {
                          channelID = contact.user.userID + user.userID;
                        } else {
                          channelID = user.userID + contact.user.userID;
                        }
                        ConversationModel? conversationModel =
                            await fireStoreUtils.getChannelByIdOrNull(channelID);
                        push(
                          context,
                          ChatScreen(
                            homeConversationModel: HomeConversationModel(
                                isGroupChat: false,
                                members: [contact.user],
                                conversationModel: conversationModel),
                          ),
                        );
                      },
                      leading: GestureDetector(
                        onTap: () => push(
                            context,
                            ProfileScreen(
                              user: contact.user,
                              fromContainer: false,
                            )),
                        child: displayCircleImage(
                            contact.user.profilePictureURL, 55, false),
                      ),
                      title: Text(
                        '${contact.user.fullName()}',
                        style: TextStyle(
                            color: isDarkMode(context) ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      trailing: TextButton(
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          primary: isDarkMode(context)
                              ? Colors.grey.shade700
                              : Colors.grey.shade200,
                        ),
                        onPressed: () async {
                          await _onContactButtonClicked(contact, index, false);
                          hideProgress();
                          setState(() {});
                        },
                        child: Text(
                          getStatusByType(contact.type),
                          style: TextStyle(
                              color:
                                  isDarkMode(context) ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold),
                        ).tr(),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        )
      ],
    );
  }

  String getStatusByType(ContactType type) {
    switch (type) {
      case ContactType.ACCEPT:
        return 'accept';
      case ContactType.PENDING:
        return 'cancel';
      case ContactType.FRIEND:
        return 'unfriend';
      case ContactType.UNKNOWN:
        return 'addFriend';
      case ContactType.BLOCKED:
        return 'unblock';
      default:
        return 'addFriend';
    }
  }

  _onContactButtonClicked(ContactModel contact, int index, bool fromSearch) async {
    switch (contact.type) {
      case ContactType.ACCEPT:
        showProgress(context, 'acceptingFriendship'.tr(), false);
        await fireStoreUtils.onFriendAccept(contact.user, false);
        _contacts[index].type = ContactType.FRIEND;
        break;
      case ContactType.FRIEND:
        showProgress(context, 'removingFriendship'.tr(), false);
        await fireStoreUtils.onUnFriend(contact.user, false);
        _contacts.removeAt(index);
        break;
      case ContactType.PENDING:
        showProgress(context, 'removingFriendshipRequest'.tr(), false);
        await fireStoreUtils.onCancelRequest(contact.user, false);
        _contacts.removeAt(index);
        break;
      case ContactType.BLOCKED:
        break;
      case ContactType.UNKNOWN:
        break;
    }
  }
}
