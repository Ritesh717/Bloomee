import 'package:Bloomee/model/album_onl_model.dart';
import 'package:Bloomee/screens/screen/common_views/album_view.dart';
import 'package:Bloomee/screens/widgets/base/base_list_tile.dart';
import 'package:Bloomee/screens/widgets/base/widget_styles.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:flutter/material.dart';

class AlbumCard extends StatelessWidget {
  final AlbumModel album;

  const AlbumCard({
    super.key,
    required this.album,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: WidgetStyles.cardPadding,
      child: SizedBox(
        width: double.infinity,
        height: WidgetStyles.listTileHeight,
        child: BaseListTile(
          imageUrl: album.imageURL,
          title: album.name,
          subtitle: "Album • ${album.artists}",
          imageShape: ListTileImageShape.rounded,
          imageSize: 70,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AlbumView(album: album),
              ),
            );
          },
          trailing: Icon(
            Icons.more_vert_rounded,
            color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
            size: WidgetStyles.iconSizeSmall,
          ),
        ),
      ),
    );
  }
}
