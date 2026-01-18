import 'package:flutter_social_network/model/ConversationModel.dart';

import 'User.dart';

class HomeConversationModel {
  bool isGroupChat;

  List<User> members;

  ConversationModel? conversationModel;

  HomeConversationModel(
      {this.isGroupChat = false, this.members = const [], this.conversationModel});
}
