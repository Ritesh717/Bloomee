// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/screens/widgets/base/base_list_tile.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';

enum LibItemTypes {
  userPlaylist,
  onlPlaylist,
  artist,
  album,
}

class LibItemCard extends StatelessWidget {
  final String title;
  final String coverArt;
  final String subtitle;
  final LibItemTypes type;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onLongPress;

  const LibItemCard({
    Key? key,
    required this.title,
    required this.coverArt,
    required this.subtitle,
    this.type = LibItemTypes.userPlaylist,
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine image shape based on type
    final imageShape = type == LibItemTypes.artist
        ? ListTileImageShape.circular
        : ListTileImageShape.rounded;

    return BaseListTile(
      imageUrl: coverArt,
      title: title,
      subtitle: subtitle,
      imageShape: imageShape,
      imageSize: 70,
      height: 80,
      padding: const EdgeInsets.only(left: 8, right: 8),
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      onLongPress: onLongPress,
      leading: type == LibItemTypes.userPlaylist
          ? StreamBuilder<String>(
              stream:
                  context.watch<BloomeePlayerCubit>().bloomeePlayer.queueTitle,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data == title) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      FontAwesome.chart_simple_solid,
                      color: Default_Theme.primaryColor2.withValues(alpha: 1),
                      size: 15,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            )
          : null,
    );
  }
}
