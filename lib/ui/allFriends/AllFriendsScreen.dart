import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';

class AllFriendsScreen extends StatefulWidget {
  final User user;

  const AllFriendsScreen({Key? key, required this.user}) : super(key: key);

  @override
  _AllFriendsScreenState createState() => _AllFriendsScreenState();
}

class _AllFriendsScreenState extends State<AllFriendsScreen> {
  FireStoreUtils _fireStoreUtils = FireStoreUtils();
  late Future<List<User>> _friends;

  @override
  void initState() {
    _friends = _fireStoreUtils.getFriends(widget.user.userID);
    _fireStoreUtils.getBlocks().listen((shouldRefresh) {
      if (shouldRefresh) {
        if (mounted) setState(() {});
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'allFriends',
        ).tr(),
      ),
      body: FutureBuilder<List<User>>(
          future: _friends,
          initialData: [],
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator.adaptive());
            if (!snapshot.hasData || (snapshot.data?.isEmpty ?? true))
              return Center(
                  child: Padding(
                padding: const EdgeInsets.only(bottom: 120.0),
                child: showEmptyState('noFriendsFound'.tr(),
                    'allFriendsWillShowUpHereOnceConfirmed'.tr()),
              ));
            return ListView.separated(
                itemBuilder: (context, index) {
                  return ListTile(
                      leading: displayCircleImage(
                          snapshot.data![index].profilePictureURL, 40, false),
                      title: Text(snapshot.data![index].fullName()));
                },
                separatorBuilder: (context, index) => Divider(),
                shrinkWrap: true,
                itemCount: snapshot.data!.length);
          }),
    );
  }
}
