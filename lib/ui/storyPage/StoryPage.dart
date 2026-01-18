import 'package:flutter/material.dart';
import 'package:flutter_social_network/constants.dart';
import 'package:flutter_social_network/model/StoryModel.dart';
import 'package:story_view/controller/story_controller.dart';
import 'package:story_view/story_view.dart';
import 'package:story_view/widgets/story_view.dart';

class StoryPage extends StatefulWidget {
  final List<StoryModel> stories;

  const StoryPage({Key? key, required this.stories}) : super(key: key);

  @override
  _StoryPageState createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  List<StoryItem> stories = [];
  StoryController controller = StoryController();

  @override
  void initState() {
    super.initState();
    widget.stories.forEach((StoryModel story) {
      if (story.storyType.contains('image')) {
        stories.add(StoryItem.pageImage(
          url: story.storyMediaURL,
          controller: controller,
        ));
      } else if (story.storyType.contains('video')) {
        stories.add(
          StoryItem.pageVideo(
            story.storyMediaURL,
            controller: controller,
          ),
        );
      } else {
        stories.add(StoryItem.text(
            title: story.storyMediaURL, backgroundColor: Color(COLOR_PRIMARY)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StoryView(
          controller: controller,
          storyItems: stories,
          onComplete: () {
            Navigator.of(context).pop();
          },
          onVerticalSwipeComplete: (v) {
            if (v == Direction.down) {
              Navigator.pop(context);
            }
          }),
    );
  }
}
