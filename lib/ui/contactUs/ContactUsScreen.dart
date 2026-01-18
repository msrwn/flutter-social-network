import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/services/helper.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          String url = 'tel:12345678';
          launch(url);
        },
        backgroundColor: Color(COLOR_ACCENT),
        child: Icon(
          CupertinoIcons.phone,
          color: isDarkMode(context) ? Colors.black : Colors.white,
        ),
      ),
      appBar: AppBar(
        title: Text(
          'contactUs',
        ).tr(),
      ),
      body: Column(children: [
        Material(
            elevation: 2,
            color: isDarkMode(context) ? Colors.black12 : Colors.white,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0, left: 16, top: 16),
                    child: Text(
                      'ourAddress',
                      style: TextStyle(
                          color: isDarkMode(context) ? Colors.white : Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ).tr(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        right: 16.0, left: 16, top: 16, bottom: 16),
                    child: Text('1412 Steiner Street, San Francisco, CA, 94115'),
                  ),
                  ListTile(
                    onTap: () async {
                      var url =
                          'mailto:support@instamobile.zendesk.com?subject=Instaflutter-contact-ticket';
                      if (await canLaunch(url)) {
                        await launch(url);
                      } else {
                        showAlertDialog(context, 'CouldNotEmail'.tr(),
                            'noMailingAppFound'.tr(), true);
                      }
                    },
                    title: Text(
                      'emailUs',
                      style: TextStyle(
                          color: isDarkMode(context) ? Colors.white : Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ).tr(),
                    subtitle: Text('support@instamobile.zendesk.com'),
                    trailing: Icon(
                      CupertinoIcons.chevron_forward,
                      color: isDarkMode(context) ? Colors.white54 : Colors.black54,
                    ),
                  )
                ]))
      ]),
    );
  }
}
