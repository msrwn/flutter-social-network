import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_network/model/ContactModel.dart';
import 'package:flutter_social_network/model/ConversationModel.dart';
import 'package:flutter_social_network/model/HomeConversationModel.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/chat/ChatScreen.dart';
import 'package:flutter_social_network/ui/profile/ProfileScreen.dart';

List<ContactModel> _searchResult = [];

List<ContactModel> _contacts = [];

class SearchScreen extends StatefulWidget {
  final User user;

  const SearchScreen({Key? key, required this.user}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late User user;
  bool _isSearching = true;
  TextEditingController controller = TextEditingController();
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
    _future = fireStoreUtils.getContacts(user.userID, true);
  }

  Widget _buildSearchField() => TextField(
        controller: controller,
        onChanged: _onSearchTextChanged,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(10),
          isDense: true,
          fillColor:
              isDarkMode(context) ? Colors.grey.shade700 : Colors.grey.shade200,
          filled: true,
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
          hintText: tr('searchInstaSocial'),
        ),
      );

  List<Widget> _buildActions() {
    if (_isSearching) {
      return [
        IconButton(
          icon: const Icon(CupertinoIcons.clear),
          onPressed: () {
            if (controller.text.isEmpty) {
              Navigator.pop(context);
              return;
            }
            _clearSearchQuery();
          },
        ),
      ];
    }

    return [
      IconButton(
        icon: const Icon(CupertinoIcons.search),
        onPressed: _startSearch,
      ),
    ];
  }

  void _startSearch() {
    ModalRoute.of(context)
        ?.addLocalHistoryEntry(LocalHistoryEntry(onRemove: _stopSearching));
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearching() {
    _clearSearchQuery();

    setState(() {
      _isSearching = false;
    });
  }

  void _clearSearchQuery() {
    setState(() {
      controller.clear();
      _onSearchTextChanged('');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isSearching ? const BackButton() : null,
        title: _isSearching ? _buildSearchField() : _buildTitle(),
        actions: _buildActions(),
      ),
      body: Column(
        children: [
          FutureBuilder<List<ContactModel>>(
            future: _future,
            initialData: [],
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Expanded(
                  child: Container(
                    child: Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                );
              } else if (!snap.hasData || (snap.data?.isEmpty ?? true)) {
                return Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 120.0),
                      child: showEmptyState('noUsersFound'.tr(),
                          'allUsersWillShowHereOnceRegistered'.tr()),
                    ),
                  ),
                );
              } else {
                return Expanded(
                  child: _searchResult.length != 0 || controller.text.isNotEmpty
                      ? ListView.builder(
                          itemCount: _searchResult.length,
                          itemBuilder: (context, index) {
                            ContactModel contact = _searchResult[index];
                            return Column(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4.0, bottom: 4.0),
                                  child: ListTile(
                                    onTap: () async {
                                      String channelID;
                                      if (contact.user.userID
                                              .compareTo(user.userID) <
                                          0) {
                                        channelID =
                                            contact.user.userID + user.userID;
                                      } else {
                                        channelID =
                                            user.userID + contact.user.userID;
                                      }
                                      ConversationModel? conversationModel =
                                          await fireStoreUtils
                                              .getChannelByIdOrNull(channelID);
                                      push(
                                          context,
                                          ChatScreen(
                                              homeConversationModel:
                                                  HomeConversationModel(
                                                      isGroupChat: false,
                                                      members: [contact.user],
                                                      conversationModel:
                                                          conversationModel)));
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
                                          color: isDarkMode(context)
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    trailing: TextButton(
                                        style: TextButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                          backgroundColor: isDarkMode(context)
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade200,
                                        ),
                                        onPressed: () async {
                                          await _onContactButtonClicked(
                                              contact, index, true);
                                          hideProgress();
                                          setState(() {});
                                        },
                                        child: Text(
                                          getStatusByType(contact.type),
                                          style: TextStyle(
                                              color: isDarkMode(context)
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.bold),
                                        ).tr()),
                                  ),
                                ),
                                Divider()
                              ],
                            );
                          })
                      : ListView.builder(
                          itemCount: snap.data?.length ?? 0,
                          // ignore: missing_return
                          itemBuilder: (BuildContext context, int index) {
                            _contacts = snap.data!;
                            ContactModel contact = snap.data![index];
                            return Column(
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4.0, bottom: 4.0),
                                  child: ListTile(
                                    onTap: () async {
                                      String channelID;
                                      if (contact.user.userID
                                              .compareTo(user.userID) <
                                          0) {
                                        channelID =
                                            contact.user.userID + user.userID;
                                      } else {
                                        channelID =
                                            user.userID + contact.user.userID;
                                      }
                                      ConversationModel? conversationModel =
                                          await fireStoreUtils
                                              .getChannelByIdOrNull(channelID);
                                      push(
                                        context,
                                        ChatScreen(
                                          homeConversationModel:
                                              HomeConversationModel(
                                                  isGroupChat: false,
                                                  members: [contact.user],
                                                  conversationModel:
                                                      conversationModel),
                                        ),
                                      );
                                    },
                                    leading: displayCircleImage(
                                        contact.user.profilePictureURL, 55, false),
                                    title: Text(
                                      '${contact.user.fullName()}',
                                      style: TextStyle(
                                          color: isDarkMode(context)
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    trailing: TextButton(
                                        style: TextButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20)),
                                          backgroundColor: isDarkMode(context)
                                              ? Colors.grey.shade700
                                              : Colors.grey.shade200,
                                        ),
                                        onPressed: () async {
                                          await _onContactButtonClicked(
                                              contact, index, false);
                                          hideProgress();
                                          setState(() {});
                                        },
                                        child: Text(
                                          getStatusByType(contact.type),
                                          style: TextStyle(
                                              color: isDarkMode(context)
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: FontWeight.bold),
                                        ).tr()),
                                  ),
                                ),
                                Divider()
                              ],
                            );
                          },
                        ),
                );
              }
            },
          )
        ],
      ),
    );
  }

  _onSearchTextChanged(String text) async {
    _searchResult.clear();
    if (text.isEmpty) {
      setState(() {});
      return;
    }
    _contacts.forEach((contact) {
      if (contact.user.fullName().toLowerCase().contains(text.toLowerCase())) {
        _searchResult.add(contact);
      }
    });
    setState(() {});
  }

  @override
  void dispose() {
    controller.dispose();
    _searchResult.clear();
    super.dispose();
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

        if (fromSearch) {
          _searchResult[index].type = ContactType.FRIEND;
          _contacts
              .where((user) => user.user.userID == contact.user.userID)
              .first
              .type = ContactType.FRIEND;
        } else {
          _contacts[index].type = ContactType.FRIEND;
        }

        break;
      case ContactType.FRIEND:
        showProgress(context, 'removingFriendship'.tr(), false);
        await fireStoreUtils.onUnFriend(contact.user, false);
        if (fromSearch) {
          _searchResult[index].type = ContactType.UNKNOWN;
          _contacts
              .where((user) => user.user.userID == contact.user.userID)
              .first
              .type = ContactType.UNKNOWN;
        } else {
          _contacts[index].type = ContactType.UNKNOWN;
        }
        break;
      case ContactType.PENDING:
        showProgress(context, 'removingFriendshipRequest'.tr(), false);
        await fireStoreUtils.onCancelRequest(contact.user, false);
        if (fromSearch) {
          _searchResult[index].type = ContactType.UNKNOWN;
          _contacts
              .where((user) => user.user.userID == contact.user.userID)
              .first
              .type = ContactType.UNKNOWN;
        } else {
          _contacts[index].type = ContactType.UNKNOWN;
        }

        break;
      case ContactType.BLOCKED:
        break;
      case ContactType.UNKNOWN:
        showProgress(context, 'sendingFriendshipRequest'.tr(), false);
        await fireStoreUtils.sendFriendRequest(contact.user, false);
        if (fromSearch) {
          _searchResult[index].type = ContactType.PENDING;
          _contacts
              .where((user) => user.user.userID == contact.user.userID)
              .first
              .type = ContactType.PENDING;
        }
        break;
    }
  }

  Widget _buildTitle() => Text('search').tr();
}
