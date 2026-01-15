import 'package:Bloomee/model/artist_onl_model.dart';
import 'package:Bloomee/screens/screen/common_views/artist_view.dart';
import 'package:Bloomee/screens/widgets/base/base_card.dart';
import 'package:flutter/material.dart';

class ArtistCard extends StatelessWidget {
  final ArtistModel artist;

  const ArtistCard({
    super.key,
    required this.artist,
  });

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      imageUrl: artist.imageUrl,
      title: artist.name,
      imageShape: CardImageShape.circular,
      imageSize: 160,
      width: 180,
      heroTag: artist.sourceId,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistView(artist: artist),
          ),
        );
      },
    );
  }
}
