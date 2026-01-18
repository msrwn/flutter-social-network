import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_social_network/model/User.dart';

class StoryModel {
  User author;

  Timestamp createdAt;

  String authorID;

  String id;

  String storyMediaURL;

  String storyType;

  StoryModel(
      {author,
      createdAt,
      this.authorID = '',
      this.id = '',
      this.storyMediaURL = '',
      this.storyType = ''})
      : this.author = author ?? User(),
        this.createdAt = createdAt ?? Timestamp.now();

  factory StoryModel.fromJson(Map<String, dynamic> parsedJson) {
    return StoryModel(
        author: User.fromJson(parsedJson['author']),
        createdAt: parsedJson['createdAt'] ?? Timestamp.now(),
        authorID: parsedJson['authorID'] ?? '',
        id: parsedJson['id'] ?? '',
        storyMediaURL: parsedJson['storyMediaURL'] ?? '',
        storyType: parsedJson['storyType'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'author': this.author.toJson(),
      'createdAt': this.createdAt,
      'authorID': this.authorID,
      'id': this.id,
      'storyMediaURL': this.storyMediaURL,
      'storyType': this.storyType
    };
  }
}
