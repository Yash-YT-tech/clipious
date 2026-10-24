import 'package:clipious/comments/models/comment_replies.dart';
import 'package:clipious/comments/models/creator_heart.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../utils/models/image_object.dart';

part 'comment.g.dart';

@JsonSerializable()
class Comment {
  String author;
  List<ImageObject> authorThumbnails = [];
  String authorId;
  String authorUrl;
  bool isEdited;
  String content;
  String publishedText;
  int likeCount;
  String commentId;
  bool authorIsChannelOwner = false;
  CreatorHeart? creatorHeart;
  CommentReplies? replies;

  Comment(
      this.author,
      this.authorThumbnails,
      this.authorId,
      this.authorUrl,
      this.isEdited,
      this.content,
      this.publishedText,
      this.likeCount,
      this.commentId,
      this.authorIsChannelOwner,
      this.creatorHeart,
      this.replies);

  factory Comment.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    final singleThumbnail = normalized['authorThumbnail'];
    final thumbnails = normalized['authorThumbnails'];
    if ((thumbnails == null || (thumbnails is List && thumbnails.isEmpty)) &&
        singleThumbnail is String &&
        singleThumbnail.isNotEmpty) {
      normalized['authorThumbnails'] = [
        {'url': singleThumbnail, 'width': 0, 'height': 0}
      ];
    } else {
      normalized['authorThumbnails'] ??= <dynamic>[];
    }
    return _$CommentFromJson(normalized);
  }

  Map<String, dynamic> toJson() => _$CommentToJson(this);
}
