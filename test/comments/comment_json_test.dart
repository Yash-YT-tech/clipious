import 'package:clipious/comments/models/comment.dart';
import 'package:clipious/comments/models/video_comments.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> commentJson({
  String? authorThumbnail,
  List<dynamic>? authorThumbnails,
}) {
  return {
    'author': 'Test Author',
    'authorId': 'UCtest',
    'authorUrl': '/channel/UCtest',
    'isEdited': false,
    'content': 'A comment',
    'publishedText': '1 day ago',
    'likeCount': 3,
    'commentId': 'comment-1',
    'authorIsChannelOwner': false,
    'creatorHeart': null,
    'replies': null,
    if (authorThumbnail != null) 'authorThumbnail': authorThumbnail,
    if (authorThumbnails != null) 'authorThumbnails': authorThumbnails,
  };
}

void main() {
  group('Comment.fromJson', () {
    test('maps the single authorThumbnail returned by Invidious', () {
      final comment = Comment.fromJson(
          commentJson(authorThumbnail: 'https://yt3.ggpht.com/avatar=s88'));

      expect(comment.authorThumbnails, hasLength(1));
      expect(comment.authorThumbnails.first.url,
          'https://yt3.ggpht.com/avatar=s88');
      expect(comment.author, 'Test Author');
    });

    test('keeps a legacy authorThumbnails list', () {
      final comment = Comment.fromJson(commentJson(authorThumbnails: [
        {'url': 'https://example.com/a.jpg', 'width': 48, 'height': 48}
      ]));

      expect(comment.authorThumbnails, hasLength(1));
      expect(comment.authorThumbnails.first.url, 'https://example.com/a.jpg');
    });

    test('does not fail when both thumbnail fields are missing', () {
      final comment = Comment.fromJson(commentJson());

      expect(comment.authorThumbnails, isEmpty);
      expect(comment.creatorHeart, isNull);
      expect(comment.replies, isNull);
    });
  });

  group('VideoComments.fromJson', () {
    test('parses a comment list', () {
      final comments = VideoComments.fromJson({
        'commentCount': 1,
        'videoId': 'abc',
        'continuation': null,
        'comments': [commentJson(authorThumbnail: '/ggpht/avatar')],
      });

      expect(comments.comments, hasLength(1));
      expect(
          comments.comments.first.authorThumbnails.first.url, '/ggpht/avatar');
    });

    test('treats a null comments list as empty', () {
      final comments = VideoComments.fromJson({
        'commentCount': 0,
        'videoId': 'abc',
        'continuation': null,
        'comments': null,
      });

      expect(comments.comments, isEmpty);
    });
  });
}
