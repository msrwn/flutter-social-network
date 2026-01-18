import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reaction_button/flutter_reaction_button.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/model/PostModel.dart';
import 'package:intl/intl.dart';
import 'package:progress_dialog/progress_dialog.dart';
import 'package:share/share.dart';

String? validateName(String? value) {
  String pattern = r'(^[a-zA-Z ]*$)';
  RegExp regExp = RegExp(pattern);
  if (value?.length == 0) {
    return 'nameIsRequired'.tr();
  } else if (!regExp.hasMatch(value ?? '')) {
    return 'nameMustBeValid'.tr();
  }
  return null;
}

String? validateMobile(String? value) {
  String pattern = r'(^\+?[0-9]*$)';
  RegExp regExp = RegExp(pattern);
  if (value?.length == 0) {
    return 'mobileIsRequired'.tr();
  } else if (!regExp.hasMatch(value ?? '')) {
    return 'mobileNumberMustBeDigits'.tr();
  }
  return null;
}

String? validatePassword(String? value) {
  if ((value?.length ?? 0) < 6)
    return 'passwordLength'.tr();
  else
    return null;
}

String? validateEmail(String? value) {
  String pattern =
      r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$';
  RegExp regex = RegExp(pattern);
  if (!regex.hasMatch(value ?? ''))
    return 'validEmail'.tr();
  else
    return null;
}

String? validateConfirmPassword(String? password, String? confirmPassword) {
  if (password != confirmPassword) {
    return 'passwordNoMatch'.tr();
  } else if (confirmPassword?.length == 0) {
    return 'confirmPassReq'.tr();
  } else {
    return null;
  }
}

//helper method to show progress
late ProgressDialog progressDialog;

showProgress(BuildContext context, String message, bool isDismissible) async {
  progressDialog = ProgressDialog(context,
      type: ProgressDialogType.Normal, isDismissible: isDismissible);
  progressDialog.style(
      message: message,
      borderRadius: 10.0,
      backgroundColor: Color(COLOR_PRIMARY),
      progressWidget: Container(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator.adaptive(
            backgroundColor: Colors.white,
            valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
          )),
      elevation: 10.0,
      insetAnimCurve: Curves.easeInOut,
      messageTextStyle: TextStyle(
          color: Colors.white, fontSize: 19.0, fontWeight: FontWeight.w600));

  await progressDialog.show();
}

updateProgress(String message) {
  progressDialog.update(message: message);
}

hideProgress() async {
  await progressDialog.hide();
}

//helper method to show alert dialog
showAlertDialog(
    BuildContext context, String title, String content, bool addOkButton) {
  // set up the AlertDialog
  Widget? okButton;
  if (addOkButton) {
    okButton = TextButton(
      child: Text('ok').tr(),
      onPressed: () {
        Navigator.pop(context);
      },
    );
  }
  if (Platform.isIOS) {
    CupertinoAlertDialog alert = CupertinoAlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [if (okButton != null) okButton],
    );

    // show the dialog
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  } else {
    AlertDialog alert = AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [if (okButton != null) okButton],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }
}

pushReplacement(BuildContext context, Widget destination) {
  Navigator.of(context)
      .pushReplacement(MaterialPageRoute(builder: (context) => destination));
}

push(BuildContext context, Widget destination) {
  Navigator.of(context).push(MaterialPageRoute(builder: (context) => destination));
}

pushAndRemoveUntil(BuildContext context, Widget destination, bool predict) {
  Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => destination),
      (Route<dynamic> route) => predict);
}

String formatTimestamp(int timestamp) {
  var format = DateFormat('hh:mm a');
  var date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  return format.format(date);
}

String setLastSeen(int seconds) {
  var format = DateFormat('hh:mm a');
  var date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  var diff = DateTime.now().millisecondsSinceEpoch - (seconds * 1000);
  if (diff < 24 * HOUR_MILLIS) {
    return format.format(date);
  } else if (diff < 48 * HOUR_MILLIS) {
    return 'yesterdayAtTime'.tr(args: ['${format.format(date)}']);
  } else {
    format = DateFormat('MMM d');
    return '${format.format(date)}';
  }
}

Widget displayImage(String picUrl, double size) => CachedNetworkImage(
    imageBuilder: (context, imageProvider) =>
        _getFlatImageProvider(imageProvider, size),
    imageUrl: picUrl,
    placeholder: (context, url) => _getFlatPlaceholderOrErrorImage(size, true),
    errorWidget: (context, url, error) =>
        _getFlatPlaceholderOrErrorImage(size, false));

Widget _getFlatPlaceholderOrErrorImage(double size, bool placeholder) => Container(
      width: placeholder ? 35 : size,
      height: placeholder ? 35 : size,
      child: placeholder
          ? Center(child: CircularProgressIndicator.adaptive())
          : Image.asset(
              'assets/images/error_image.png',
              fit: BoxFit.cover,
              height: size,
              width: size,
            ),
    );

Widget _getFlatImageProvider(ImageProvider provider, double size) {
  return Container(
    width: size - 50,
    height: size - 50,
    child: FadeInImage(
        fit: BoxFit.cover,
        placeholder: Image.asset(
          'assets/images/img_placeholder.png',
          fit: BoxFit.cover,
          height: size,
          width: size,
        ).image,
        image: provider),
  );
}

Widget displayCircleImage(String picUrl, double size, hasBorder) =>
    CachedNetworkImage(
        height: size,
        width: size,
        imageBuilder: (context, imageProvider) =>
            _getCircularImageProvider(imageProvider, size, false),
        imageUrl: picUrl,
        placeholder: (context, url) => _getPlaceholderOrErrorImage(size, hasBorder),
        errorWidget: (context, url, error) =>
            _getPlaceholderOrErrorImage(size, hasBorder));

Widget _getPlaceholderOrErrorImage(double size, hasBorder) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xff7c94b6),
        borderRadius: BorderRadius.all(Radius.circular(size / 2)),
        border: new Border.all(
          color: Colors.white,
          style: hasBorder ? BorderStyle.solid : BorderStyle.none,
          width: 2.0,
        ),
      ),
      child: ClipOval(
          child: Image.asset(
        'assets/images/placeholder.jpg',
        fit: BoxFit.cover,
        height: size,
        width: size,
      )),
    );

Widget _getCircularImageProvider(
    ImageProvider provider, double size, bool hasBorder) {
  return ClipOval(
      child: Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
        borderRadius: new BorderRadius.all(new Radius.circular(size / 2)),
        border: new Border.all(
          color: Colors.white,
          style: hasBorder ? BorderStyle.solid : BorderStyle.none,
          width: 2.0,
        ),
        image: DecorationImage(
          image: provider,
          fit: BoxFit.cover,
        )),
  ));
}

bool isDarkMode(BuildContext context) {
  if (Theme.of(context).brightness == Brightness.light) {
    return false;
  } else {
    return true;
  }
}

String audioMessageTime(Duration audioDuration) {
  String twoDigits(int n) {
    if (n >= 10) return '$n';
    return '0$n';
  }

  String twoDigitsHours(int n) {
    if (n >= 10) return '$n:';
    if (n == 0) return '';
    return '0$n:';
  }

  String twoDigitMinutes = twoDigits(audioDuration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(audioDuration.inSeconds.remainder(60));
  return '${twoDigitsHours(audioDuration.inHours)}$twoDigitMinutes:$twoDigitSeconds';
}

String updateTime(Timer timer) {
  Duration callDuration = Duration(seconds: timer.tick);
  String twoDigits(int n) {
    if (n >= 10) return '$n';
    return '0$n';
  }

  String twoDigitsHours(int n) {
    if (n >= 10) return '$n:';
    if (n == 0) return '';
    return '0$n:';
  }

  String twoDigitMinutes = twoDigits(callDuration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(callDuration.inSeconds.remainder(60));
  return '${twoDigitsHours(callDuration.inHours)}$twoDigitMinutes:$twoDigitSeconds';
}

Widget buildPreviewIconFacebook(String path) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 5),
      child: Image.asset(path, height: 40),
    );

Widget buildIconFacebook(String path) => Container(
      color: Colors.transparent,
      child: Image.asset(path, height: 20),
    );

final facebookReactions = [
  Reaction(
    id: 1,
    previewIcon: buildPreviewIconFacebook('assets/images/like.gif'),
    icon: buildIconFacebook('assets/images/like_fill.png'),
  ),
  Reaction(
    id: 2,
    previewIcon: buildPreviewIconFacebook('assets/images/love.gif'),
    icon: buildIconFacebook('assets/images/love.png'),
  ),
  Reaction(
    id: 3,
    previewIcon: buildPreviewIconFacebook('assets/images/wow.gif'),
    icon: buildIconFacebook('assets/images/wow.png'),
  ),
  Reaction(
    id: 4,
    previewIcon: buildPreviewIconFacebook('assets/images/haha.gif'),
    icon: buildIconFacebook('assets/images/haha.png'),
  ),
  Reaction(
    id: 5,
    previewIcon: buildPreviewIconFacebook('assets/images/sad.gif'),
    icon: buildIconFacebook('assets/images/sad.png'),
  ),
  Reaction(
    id: 6,
    previewIcon: buildPreviewIconFacebook('assets/images/angry.gif'),
    icon: buildIconFacebook('assets/images/angry.png'),
  ),
];

String getReactionString(int id) {
  String reaction = 'like';
  switch (id) {
    case 1:
      reaction = 'like';
      break;
    case 2:
      reaction = 'love';
      break;
    case 3:
      reaction = 'surprised';
      break;
    case 4:
      reaction = 'laugh';
      break;
    case 5:
      reaction = 'sad';
      break;
    case 6:
      reaction = 'angry';
      break;
  }
  return reaction;
}

sharePost(PostModel post) async {
  String shareMessage = post.postText;
  if (post.postMedia.isNotEmpty) {
    List<String> paths = [];
    for (int i = 0; i < post.postMedia.length; i++) {
      paths.add(post.postMedia[i].url);
    }
    shareMessage += '\nPost Media: ${paths.toString()}';
  }

  await Share.share(shareMessage,
      subject: '${post.author.fullName()}\'s Post on Flutter Social '
          'Network');
}

Widget showEmptyState(String title, String description,
    {String? buttonTitle, bool? isDarkMode, VoidCallback? action}) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(height: 30),
      Text(title, style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
      SizedBox(height: 15),
      Text(
        description,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 17),
      ),
      SizedBox(height: 25),
      if (action != null)
        Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: double.infinity),
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  primary: Color(COLOR_PRIMARY),
                ),
                child: Text(
                  buttonTitle!,
                  style: TextStyle(
                      color: isDarkMode! ? Colors.black : Colors.white,
                      fontSize: 18),
                ),
                onPressed: action),
          ),
        ),
    ],
  );
}
