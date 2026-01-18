import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/model/ConversationModel.dart';
import 'package:flutter_social_network/model/HomeConversationModel.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/FirebaseHelper.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/auth/AuthScreen.dart';
import 'package:flutter_social_network/ui/chat/ChatScreen.dart';
import 'package:flutter_social_network/ui/container/ContainerScreen.dart';
import 'package:flutter_social_network/ui/onBoarding/OnBoardingScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  /// Wait for Firebase to initialize and set `_initialized` state to true
  await Firebase.initializeApp();
  runApp(
    /**
     * this is required to apply localization strings located at @param path
        parameter and provides RTL support
     */
    EasyLocalization(
        supportedLocales: [Locale('en'), Locale('ar')],
        path: 'assets/translations',
        fallbackLocale: Locale('en'),
        useOnlyLangCode: true,
        child: MyApp()),
  );
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  /// this key is used to navigate to the appropriate screen when the
  /// notification is clicked from the system tray
  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey(debugLabel: 'Main Navigator');

  /// the current user logged in the app, this will be null when not logged in
  static User? currentUser;

  /// a stream to listen for firebase messaging token changes
  late StreamSubscription tokenStream;

  /// true when firebase has been initialized
  bool _initialized = false;

  /// true if firebase had an error during initialization
  bool _error = false;

  /// we attempt to initialize firebase app
  void initializeFlutterFire() async {
    try {
      /// configure the firebase messaging , required for notifications handling
      RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotification(initialMessage.data, navigatorKey);
      }
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? remoteMessage) {
        if (remoteMessage != null) {
          _handleNotification(remoteMessage.data, navigatorKey);
        }
      });
      if (!Platform.isIOS) {
        FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler);
      }

      /// listen to firebase token changes and update the user object in the
      /// database with it's new token
      tokenStream = FireStoreUtils.firebaseMessaging.onTokenRefresh.listen((event) {
        if (currentUser != null) {
          print('token $event');
          currentUser!.fcmToken = event;
          FireStoreUtils.updateCurrentUser(currentUser!);
        }
      });
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      /// Set `_error` state to true if Firebase initialization fails
      setState(() {
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Show error message if initialization failed
    if (_error) {
      return MaterialApp(
        home: Container(
          color: Colors.white,
          child: Center(
              child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 25,
              ),
              SizedBox(height: 16),
              Text(
                'Failed to initialise firebase!',
                style: TextStyle(color: Colors.red, fontSize: 25),
              ),
            ],
          )),
        ),
      );
    }

    /// Show a loader until FlutterFire is initialized
    if (!_initialized) {
      return Container(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    /// our main app
    return MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        title: 'appName'.tr(),
        theme: ThemeData(
            appBarTheme: AppBarTheme(
                centerTitle: true,
                color: Colors.transparent,
                elevation: 0,
                actionsIconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
                iconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
                textTheme: TextTheme(
                    headline6: TextStyle(
                        color: Colors.black,
                        fontSize: 17.0,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w700)),
                brightness: Brightness.light),
            bottomSheetTheme:
                BottomSheetThemeData(backgroundColor: Colors.white.withOpacity(.9)),
            accentColor: Color(COLOR_PRIMARY),
            brightness: Brightness.light),
        darkTheme: ThemeData(
            appBarTheme: AppBarTheme(
                centerTitle: true,
                color: Colors.transparent,
                elevation: 0,
                actionsIconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
                iconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
                textTheme: TextTheme(
                    headline6: TextStyle(
                        color: Colors.grey.shade200,
                        fontSize: 17.0,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w700)),
                brightness: Brightness.dark),
            bottomSheetTheme: BottomSheetThemeData(
                backgroundColor: Colors.black12.withOpacity(.3)),
            accentColor: Color(COLOR_PRIMARY),
            brightness: Brightness.dark),
        debugShowCheckedModeBanner: false,
        color: Color(COLOR_PRIMARY),
        home: OnBoarding());
  }

  @override
  void initState() {
    initializeFlutterFire();
    WidgetsBinding.instance?.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    /// cancel the stream to avoid memory leaks
    tokenStream.cancel();
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    /// if we are logged in, we attempt to update the user online status and
    /// lastSeenTimestamp based on AppLifecycleState state
    if (auth.FirebaseAuth.instance.currentUser != null && currentUser != null) {
      if (state == AppLifecycleState.paused) {
        /// user is offline
        /// pause token stream
        tokenStream.pause();

        /// set active flag to false
        currentUser!.active = false;

        /// update lastOnlineTimestamp field
        currentUser!.lastOnlineTimestamp = Timestamp.now();

        /// update user object in the firestore database to persist changes
        FireStoreUtils.updateCurrentUser(currentUser!);
      } else if (state == AppLifecycleState.resumed) {
        /// user is online
        /// resume token stream
        tokenStream.resume();

        /// set active flag to true
        currentUser!.active = true;

        /// update user object in the firestore database to persist changes
        FireStoreUtils.updateCurrentUser(currentUser!);
      }
    }
  }
}

class OnBoarding extends StatefulWidget {
  @override
  State createState() {
    return OnBoardingState();
  }
}

class OnBoardingState extends State<OnBoarding> {
  Future hasFinishedOnBoarding() async {
    /// first we check if the user has seen the onBoarding screen or not
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool finishedOnBoarding = (prefs.getBool(FINISHED_ON_BOARDING) ?? false);

    if (finishedOnBoarding) {
      /// user saw onBoarding, now we check if the user is logged into
      /// firebase or not
      auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        /// we try to retrieve the user object from the database
        User? user = await FireStoreUtils.getCurrentUser(firebaseUser.uid);
        if (user != null) {
          /// user is logged in already
          /// we set the active flag to true
          user.active = true;

          /// update the user object in the database to persist changes
          await FireStoreUtils.updateCurrentUser(user);

          /// set the current user to this newly retrieved user object
          MyAppState.currentUser = user;

          /// we navigate to the ContainerScreen of the app, this screen
          /// has a navigation drawer that can navigate you to various
          /// screens inside the app
          pushReplacement(context, ContainerScreen(user: user));
        } else {
          /// user isn't logged in, authentication is required
          /// We navigate to the authentication screen, we only navigate to
          /// this screen if the user is not logged in so we ask them either
          /// to login or sign up for a new user
          pushReplacement(context, AuthScreen());
        }
      } else {
        /// user isn't logged in, authentication is required
        /// We navigate to the authentication screen, we only navigate to
        /// this screen if the user is not logged in so we ask them either
        /// to login or sign up for a new user
        pushReplacement(context, AuthScreen());
      }
    } else {
      /// user hasn't seen the onBoarding screen yet, we navigate to this
      /// screen one time only at first installation of the app
      pushReplacement(context, new OnBoardingScreen());
    }
  }

  @override
  void initState() {
    super.initState();

    /// check which screen should the user navigate to
    hasFinishedOnBoarding();
  }

  @override
  Widget build(BuildContext context) {
    /// this is a placeholder widget that has a spinning indicator while we
    /// determine which screens should the user navigate to
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator.adaptive(),
      ),
    );
  }
}

/// this faction is called when the notification is clicked from system tray
/// when the app is in the background or completely killed
void _handleNotification(
    Map<String, dynamic> message, GlobalKey<NavigatorState> navigatorKey) {
  /// right now we only handle click actions on chat messages only
  try {
    if (message.containsKey('members') &&
        message.containsKey('isGroup') &&
        message.containsKey('conversationModel')) {
      List<User> members = List<User>.from(
          (jsonDecode(message['members']) as List<dynamic>)
              .map((e) => User.fromPayload(e))).toList();
      bool isGroup = jsonDecode(message['isGroup']);
      ConversationModel conversationModel =
          ConversationModel.fromPayload(jsonDecode(message['conversationModel']));
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            homeConversationModel: HomeConversationModel(
                members: members,
                isGroupChat: isGroup,
                conversationModel: conversationModel),
          ),
        ),
      );
    }
  } catch (e, s) {
    print('MyAppState._handleNotification $e $s');
  }
}

/// this faction is called when the user receives a notification while the
/// app is in the background or completely killed
Future<dynamic> backgroundMessageHandler(RemoteMessage remoteMessage) async {
  await Firebase.initializeApp();
  Map<dynamic, dynamic> message = remoteMessage.data;
  if (message.containsKey('data')) {
    // Handle data message
    print('backgroundMessageHandler message.containsKey(data)');
    final dynamic data = message['data'];
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    final dynamic notification = message['notification'];
    print('backgroundMessageHandler message.containsKey(notification)');
  }

  // Or do other work.
}
