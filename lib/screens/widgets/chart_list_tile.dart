// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:developer';
import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/repository/MixedAPI/mixed_api.dart';
import 'package:Bloomee/screens/widgets/base/base_list_tile.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';

class ChartListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imgUrl;
  final bool rectangularImage;
  final VoidCallback? onTap;

  const ChartListTile({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.imgUrl,
    this.onTap,
    this.rectangularImage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BaseListTile(
      imageUrl: imgUrl,
      title: title,
      subtitle: subtitle,
      imageShape: ListTileImageShape.rounded,
      imageSize: 60,
      imageWidth: rectangularImage ? 80 : 60,
      height: 70,
      padding: EdgeInsets.zero,
      onTap: () => _handleTap(context),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    log("imgUrl: $imgUrl", name: "ChartListTile");

    if (onTap != null) {
      onTap!();
      return;
    }

    SnackbarService.showMessage(
      "Loading media...",
      loading: true,
    );

    MediaItemModel? mediaItem;
    try {
      mediaItem = await MixedAPI().getYtTrackByMeta("$title $subtitle".trim());
      if (mediaItem != null && context.mounted) {
        SnackbarService.showMessage(
          "Media loaded.",
          loading: false,
          duration: const Duration(seconds: 1),
        );
        context
            .read<BloomeePlayerCubit>()
            .bloomeePlayer
            .updateQueue([mediaItem], doPlay: true);
        return;
      }
    } catch (e) {
      log(e.toString(), name: "ChartListTile");
    }

    if (context.mounted) {
      context
          .push("/${GlobalStrConsts.searchScreen}?query=$title by $subtitle");
      SnackbarService.showMessage(
        "Can't find media. Searching...",
        loading: false,
        duration: const Duration(seconds: 1),
      );
    }
  }
}
