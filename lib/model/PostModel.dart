import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_reaction_button/flutter_reaction_button.dart';
import 'package:flutter_social_network/model/MessageData.dart';
import 'package:flutter_social_network/model/User.dart';
import 'package:flutter_social_network/services/helper.dart';

class PostModel {
  User author;

  String authorID;

  num commentCount;

  Timestamp createdAt;

  String id;

  String location;

  List<Url> postMedia;

  String postText;

  num reactionsCount;

  Reactions reactions;

  Reaction myReaction = Reaction(
    id: 0,
    previewIcon: buildPreviewIconFacebook('assets/images/like.png'),
    icon: buildIconFacebook('assets/images/like.png'),
  );

  PostModel(
      {author,
      this.authorID = '',
      this.commentCount = 0,
      createdAt,
      this.id = '',
      this.location = '',
      this.postMedia = const [],
      this.postText = '',
      this.reactionsCount = 0,
      reactions})
      : this.author = author ?? User(),
        this.createdAt = createdAt ?? Timestamp.now(),
        this.reactions = reactions ??
            Reactions(angry: 0, cry: 0, laugh: 0, like: 0, love: 0, sad: 0);

  factory PostModel.fromJson(Map<String, dynamic> parsedJson) {
    List<dynamic> _postMedia = parsedJson['postMedia'] ?? [];
    List<Url> _posts = [];
    for (int i = 0; i < _postMedia.length; i++) {
      _posts.add(Url.fromJson(_postMedia[i]));
    }
    return PostModel(
      author: parsedJson.containsKey('author')
          ? User.fromJson(parsedJson['author'])
          : User(),
      createdAt: parsedJson['createdAt'] ?? Timestamp.now(),
      authorID: parsedJson['authorID'] ?? '',
      id: parsedJson['id'] ?? '',
      commentCount: parsedJson['commentCount'] ?? 0,
      location: parsedJson['location'] ?? '',
      postText: parsedJson['postText'] ?? '',
      reactionsCount: parsedJson['reactionsCount'] ?? 0,
      postMedia: _posts,
      reactions: parsedJson.containsKey('reactions')
          ? Reactions.fromJson(parsedJson['reactions'])
          : Reactions(),
    );
  }

  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> _postMedia = [];
    postMedia.forEach((Url post) {
      _postMedia.add(post.toJson());
    });

    return {
      'author': this.author.toJson(),
      'createdAt': this.createdAt,
      'authorID': this.authorID,
      'id': this.id,
      'commentCount': this.commentCount,
      'location': this.location,
      'postText': this.postText,
      'reactionsCount': this.reactionsCount,
      'postMedia': _postMedia,
      'reactions': this.reactions.toJson(),
    };
  }
}

class Reactions {
  num angry;
  num cry;

  num laugh;

  num like;

  num love;

  num sad;

  Reactions(
      {this.angry = 0,
      this.cry = 0,
      this.laugh = 0,
      this.like = 0,
      this.love = 0,
      this.sad = 0});

  factory Reactions.fromJson(Map<String, dynamic> parsedJson) {
    return Reactions(
        angry: parsedJson['angry'] ?? 0,
        cry: parsedJson['cry'] ?? 0,
        laugh: parsedJson['laugh'] ?? 0,
        like: parsedJson['like'] ?? 0,
        love: parsedJson['love'] ?? 0,
        sad: parsedJson['sad'] ?? 0);
  }

  Map<String, dynamic> toJson() {
    return {
      'angry': this.angry,
      'cry': this.cry,
      'laugh': this.laugh,
      'like': this.like,
      'love': this.love,
      'sad': this.sad,
    };
  }
}
