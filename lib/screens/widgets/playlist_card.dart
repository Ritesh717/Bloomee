import 'package:Bloomee/model/playlist_onl_model.dart';
import 'package:Bloomee/model/source_engines.dart';
import 'package:Bloomee/screens/screen/common_views/playlist_view.dart';
import 'package:Bloomee/screens/widgets/base/base_list_tile.dart';
import 'package:Bloomee/screens/widgets/base/widget_styles.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:flutter/material.dart';

class PlaylistCard extends StatelessWidget {
  final PlaylistOnlModel playlist;
  final SourceEngine sourceEngine;

  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.sourceEngine,
  });

  @override
  Widget build(BuildContext context) {
    return BaseListTile(
      imageUrl: playlist.imageURL,
      title: playlist.name,
      subtitle: "Playlist",
      imageShape: ListTileImageShape.rounded,
      imageSize: 70,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OnlPlaylistView(
              playlist: playlist,
              sourceEngine: sourceEngine,
            ),
          ),
        );
      },
      trailing: Icon(
        Icons.more_vert_rounded,
        color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
        size: WidgetStyles.iconSizeSmall,
      ),
    );
  }
}
