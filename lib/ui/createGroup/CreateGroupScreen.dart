import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/main.dart';
import 'package:flutter_social_network/model/HomeConversationModel.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/chat/ChatScreen.dart';

class CreateGroupScreen extends StatefulWidget {
  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  List<User> _selectedUsers = [];
  late Future<List<User>> _futureUsers;
  FireStoreUtils _fireStoreUtils = FireStoreUtils();
  TextEditingController _groupNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _futureUsers = _fireStoreUtils.getFriends(MyAppState.currentUser!.userID);
    _fireStoreUtils.getBlocks().listen((shouldRefresh) {
      if (shouldRefresh) {
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'choosePeople',
        ).tr(),
        actions: [
          _selectedUsers.isNotEmpty
              ? InkWell(
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (context) {
                          return Dialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(40)),
                              elevation: 16,
                              child: Container(
                                height: 200,
                                width: 350,
                                child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 40.0, left: 16, right: 16, bottom: 16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        TextField(
                                          textInputAction: TextInputAction.done,
                                          keyboardType: TextInputType.text,
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          controller: _groupNameController,
                                          decoration: InputDecoration(
                                            focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(25.0),
                                                borderSide: BorderSide(
                                                    color: Color(COLOR_ACCENT),
                                                    width: 2.0)),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(25.0)),
                                            labelText: 'groupName'.tr(),
                                          ),
                                        ),
                                        Spacer(),
                                        Row(
                                          children: [
                                            TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                child: Text(
                                                  'cancel',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                  ),
                                                ).tr()),
                                            TextButton(
                                                onPressed: () async {
                                                  if (_groupNameController
                                                      .text.isNotEmpty) {
                                                    showProgress(
                                                        context,
                                                        'creatingGroupPleaseWait'
                                                            .tr(),
                                                        false);
                                                    HomeConversationModel
                                                        groupChatConversationModel =
                                                        await _fireStoreUtils
                                                            .createGroupChat(
                                                                _selectedUsers,
                                                                _groupNameController
                                                                    .text);
                                                    hideProgress();
                                                    Navigator.pop(context);
                                                    pushReplacement(
                                                        context,
                                                        ChatScreen(
                                                            homeConversationModel:
                                                                groupChatConversationModel));
                                                  }
                                                },
                                                child: Text('create',
                                                        style: TextStyle(
                                                            fontSize: 18,
                                                            color:
                                                                Color(COLOR_ACCENT)))
                                                    .tr()),
                                          ],
                                        )
                                      ],
                                    )),
                              ));
                        });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                        child: Text(
                      'create',
                      style: TextStyle(color: Color(COLOR_PRIMARY)),
                    ).tr()),
                  ),
                )
              : Container(
                  width: 0,
                  height: 0,
                )
        ],
      ),
      body: FutureBuilder<List<User>>(
          future: _futureUsers,
          initialData: [],
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator.adaptive());
            } else if ((snapshot.data?.isEmpty ?? true) &&
                snapshot.connectionState == ConnectionState.done) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 120.0),
                  child: showEmptyState(
                      'noUsersFound'.tr(), 'registeredUsersWillShowUpHere.'.tr()),
                )),
              );
            } else {
              snapshot.data!.remove(MyAppState.currentUser);
              return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    User user = snapshot.data![index];
                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: ListTile(
                              onTap: () {
                                if (!user.selected) {
                                  user.selected = true;
                                  _selectedUsers.add(user);
                                } else {
                                  user.selected = false;
                                  _selectedUsers.remove(user);
                                }
                                setState(() {});
                              },
                              leading: displayCircleImage(
                                  user.profilePictureURL, 55, false),
                              title: Text(
                                '${user.fullName()}',
                                style: TextStyle(
                                    color: isDarkMode(context)
                                        ? Colors.white
                                        : Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15),
                              ),
                              trailing: user.selected
                                  ? Icon(
                                      CupertinoIcons.checkmark_alt_circle,
                                      color: isDarkMode(context)
                                          ? Colors.white
                                          : Colors.black,
                                    )
                                  : Container(
                                      width: 0,
                                      height: 0,
                                    )),
                        ),
                        Divider()
                      ],
                    );
                  });
            }
          }),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _groupNameController.dispose();
  }
}
