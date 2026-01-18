import 'package:cloud_firestore/cloud_firestore.dart';

class SocialCommentModel {
  String authorID;

  String commentID;

  String commentText;

  Timestamp createdAt;

  String id;

  String postID;

  SocialCommentModel(
      {this.authorID = '',
      this.commentID = '',
      this.commentText = '',
      createdAt,
      this.id = '',
      this.postID = ''})
      : this.createdAt = createdAt ?? Timestamp.now();

  factory SocialCommentModel.fromJson(Map<String, dynamic> parsedJson) {
    return SocialCommentModel(
      authorID: parsedJson['authorID'] ?? '',
      commentID: parsedJson['commentID'] ?? '',
      commentText: parsedJson['commentText'] ?? '',
      createdAt: parsedJson['createdAt'] ?? Timestamp.now(),
      id: parsedJson['id'] ?? '',
      postID: parsedJson['postID'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorID': this.authorID,
      'commentID': this.commentID,
      'commentText': this.commentText,
      'createdAt': this.createdAt,
      'id': this.id,
      'postID': this.postID
    };
  }
}
