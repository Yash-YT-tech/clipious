import 'package:cached_network_image/cached_network_image.dart';
import 'package:clipious/app/states/app.dart';
import 'package:clipious/globals.dart';
import 'package:clipious/settings/models/db/server.dart';
import 'package:clipious/utils/states/thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class Thumbnail extends StatelessWidget {
  final Widget? child;
  final double? height;
  final double? width;

  final List<String>? thumbnails;
  final BoxDecoration decoration;

  const Thumbnail(
      {super.key,
      this.child,
      this.thumbnails,
      required this.decoration,
      this.width,
      this.height});

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
    final Server? server =
        context.select((AppCubit cubit) => cubit.state.server);

    if (server == null) {
      return Container(
          decoration: decoration, width: width, height: height, child: child);
    }

    return BlocProvider(
      create: (context) =>
          ThumbnailCubit(ThumbnailState(urls: thumbnails ?? [])),
      child: BlocBuilder<ThumbnailCubit, ThumbnailState>(
          builder: (context, state) {
        if (state.selected == null) {
          return _ErrorWidget(
              decoration: decoration, width: width, height: height);
        }
        final cubit = context.read<ThumbnailCubit>();
        final url = state.selected!.startsWith('/')
            ? server.url + state.selected!
            : state.selected!;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = width != null ? (width! * dpr).round() : null;

        return RepaintBoundary(
          child: CachedNetworkImage(
            key: ValueKey(url),
            cacheKey: url,
            httpHeaders: server.customHeaders,
            memCacheWidth: cacheWidth,
            maxWidthDiskCache: cacheWidth,
            errorListener: (value) => cubit.onThumbnailFailed(),
            imageBuilder: (context, imageProvider) => Container(
              height: height,
              width: width,
              decoration: decoration.copyWith(
                  image:
                      DecorationImage(image: imageProvider, fit: BoxFit.cover)),
              child: child,
            ),
            imageUrl: url,
            placeholderFadeInDuration: motionShort,
            fadeInDuration: motionShort,
            fadeOutDuration: motionFast,
            errorWidget: (context, url, error) => _ErrorWidget(
              decoration: decoration,
              width: width,
              height: height,
            ),
            progressIndicatorBuilder: (context, url, progress) => Container(
              height: height,
              width: width,
              alignment: Alignment.center,
              decoration: decoration.copyWith(color: colors.secondaryContainer),
              child: const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 1,
                  )),
            ),
          ),
        );
      }),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final double? height;
  final double? width;
  final BoxDecoration decoration;

  const _ErrorWidget({this.height, this.width, required this.decoration});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: width,
      alignment: Alignment.center,
      decoration: decoration.copyWith(color: colors.secondaryContainer),
      // duration: animationDuration,
      child: SizedBox(
          height: 20,
          width: 20,
          child: Icon(
            Icons.error_outline,
            color: colors.onSecondaryContainer.withValues(alpha: 0.5),
          )),
    );
  }
}
