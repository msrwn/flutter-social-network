import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:flutter_social_network/ui/login/LoginScreen.dart';
import 'package:flutter_social_network/ui/signUp/SignUpScreen.dart';

class AuthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// the app logo
          Center(
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue, Colors.purpleAccent],
                ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
              },
              blendMode: BlendMode.srcIn,
              child: Image.asset(
                'assets/images/auth_image.png',
                fit: BoxFit.cover,
                width: 150,
                height: 150,
              ),
            ),
          ),

          /// welcome text big title
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 32, right: 16, bottom: 8),
            child: Text(
              'welcome',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(COLOR_PRIMARY),
                  fontSize: 24.0,
                  fontWeight: FontWeight.bold),
            ).tr(),
          ),

          /// welcome text small subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: Text(
              'welcomeSubtitle',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ).tr(),
          ),

          /// login button navigates to login screen
          Padding(
            padding: const EdgeInsets.only(right: 40.0, left: 40.0, top: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Color(COLOR_PRIMARY),
                  textStyle: TextStyle(color: Colors.white),
                  padding: EdgeInsets.only(top: 12, bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    side: BorderSide(
                      color: Color(COLOR_PRIMARY),
                    ),
                  ),
                ),
                child: Text(
                  'logIn',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ).tr(),
                onPressed: () {
                  push(context, LoginScreen());
                },
              ),
            ),
          ),

          /// sign up button navigates to sign up screen
          Padding(
            padding:
                const EdgeInsets.only(right: 40.0, left: 40.0, top: 20, bottom: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: double.infinity),
              child: TextButton(
                child: Text(
                  'signUp',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(COLOR_PRIMARY)),
                ).tr(),
                onPressed: () {
                  push(context, SignUpScreen());
                },
                style: ButtonStyle(
                  padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                    EdgeInsets.only(top: 12, bottom: 12),
                  ),
                  shape: MaterialStateProperty.all<OutlinedBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25.0),
                      side: BorderSide(
                        color: Color(COLOR_PRIMARY),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
