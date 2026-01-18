import 'package:cloud_firestore/cloud_firestore.dart';

class SocialReactionModel {
  String reactionAuthorID;

  Timestamp createdAt;

  String postID;

  String reaction;

  SocialReactionModel(
      {this.reactionAuthorID = '', this.postID = '', this.reaction = '', createdAt})
      : this.createdAt = createdAt ?? Timestamp.now();

  factory SocialReactionModel.fromJson(Map<String, dynamic> parsedJson) {
    return SocialReactionModel(
      reactionAuthorID: parsedJson['reactionAuthorID'] ?? '',
      createdAt: parsedJson['createdAt'] ?? Timestamp.now(),
      reaction: parsedJson['reaction'] ?? '',
      postID: parsedJson['postID'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reactionAuthorID': this.reactionAuthorID,
      'createdAt': this.createdAt,
      'reaction': this.reaction,
      'postID': this.postID
    };
  }
}
