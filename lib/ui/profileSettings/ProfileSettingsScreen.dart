import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/main.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/accountDetails/AccountDetailsScreen.dart';
import 'package:flutter_social_network/ui/auth/AuthScreen.dart';
import 'package:flutter_social_network/ui/contactUs/ContactUsScreen.dart';
import 'package:flutter_social_network/ui/reauthScreen/reauth_user_screen.dart';
import 'package:flutter_social_network/ui/settings/SettingsScreen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  @override
  _ProfileSettingsScreenState createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'profileSettings',
        ).tr(),
      ),
      body: SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'general',
              style: TextStyle(
                  color: isDarkMode(context) ? Colors.white54 : Colors.black54,
                  fontSize: 17),
            ).tr(),
          ),
          CupertinoButton(
              borderRadius: BorderRadius.circular(0),
              child: Text(
                'accountDetails'.tr(),
                style: TextStyle(fontSize: 16, color: Color(COLOR_PRIMARY)),
              ),
              color: isDarkMode(context) ? Colors.black38 : Colors.white,
              onPressed: () => push(context,
                  AccountDetailsScreen(user: MyAppState.currentUser!))),
          Divider(
            height: 0,
          ),
          CupertinoButton(
            borderRadius: BorderRadius.circular(0),
            onPressed: () {
              push(context, SettingsScreen(user: MyAppState.currentUser!));
            },
            child: Text(
              'settings',
              style: TextStyle(fontSize: 16, color: Color(COLOR_PRIMARY)),
            ).tr(),
            color: isDarkMode(context) ? Colors.black38 : Colors.white,
          ),
          Divider(
            height: 0,
          ),
          CupertinoButton(
            borderRadius: BorderRadius.circular(0),
            child: Text(
              'Delete Account'.tr(),
              style: TextStyle(fontSize: 16, color: Color(COLOR_PRIMARY)),
            ),
            color: isDarkMode(context) ? Colors.black38 : Colors.white,
            onPressed: () async {
              AuthProviders? authProvider;
              List<auth.UserInfo> userInfoList =
                  auth.FirebaseAuth.instance.currentUser?.providerData ?? [];
              await Future.forEach(userInfoList, (auth.UserInfo info) {
                switch (info.providerId) {
                  case 'password':
                    authProvider = AuthProviders.PASSWORD;
                    break;
                  case 'phone':
                    authProvider = AuthProviders.PHONE;
                    break;
                  case 'facebook.com':
                    authProvider = AuthProviders.FACEBOOK;
                    break;
                  case 'apple.com':
                    authProvider = AuthProviders.APPLE;
                    break;
                }
              });
              bool? result = await showDialog(
                context: context,
                builder: (context) => ReAuthUserScreen(
                  provider: authProvider!,
                  email: auth.FirebaseAuth.instance.currentUser!.email,
                  phoneNumber:
                      auth.FirebaseAuth.instance.currentUser!.phoneNumber,
                  deleteUser: true,
                ),
              );
              if (result != null && result) {
                await showProgress(context, 'Deleting account...'.tr(), false);
                await FireStoreUtils.deleteUser();
                await hideProgress();
                MyAppState.currentUser = null;
                pushAndRemoveUntil(context, AuthScreen(), false);
              }
            },
          ),
          Divider(
            height: 0,
          ),
          CupertinoButton(
            borderRadius: BorderRadius.circular(0),
            onPressed: () {
              push(context, ContactUsScreen());
            },
            child: Text(
              'contactUs',
              style: TextStyle(fontSize: 16, color: Color(COLOR_PRIMARY)),
            ).tr(),
            color: isDarkMode(context) ? Colors.black38 : Colors.white,
          ),
          Divider(
            height: 0,
          ),
          CupertinoButton(
            borderRadius: BorderRadius.circular(0),
            color: isDarkMode(context) ? Colors.black38 : Colors.white,
            child: Text(
              'logout',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ).tr(),
            onPressed: () async {
              MyAppState.currentUser!.active = false;
              MyAppState.currentUser!.lastOnlineTimestamp = Timestamp.now();
              await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
              await FirebaseAuth.instance.signOut();
              MyAppState.currentUser = null;
              pushAndRemoveUntil(context, AuthScreen(), false);
            },
            padding: EdgeInsets.only(top: 12, bottom: 12),
          ),
        ],
      )),
    );
  }
}
