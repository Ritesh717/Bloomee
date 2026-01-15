import 'package:Bloomee/model/playlist_onl_model.dart';
import 'package:Bloomee/model/source_engines.dart';
import 'package:Bloomee/screens/screen/common_views/playlist_view.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:Bloomee/utils/load_Image.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class PlaylistCard extends StatelessWidget {
  final PlaylistOnlModel playlist;
  final SourceEngine sourceEngine;
  final ValueNotifier<bool> hovering = ValueNotifier(false);
  PlaylistCard({
    super.key,
    required this.playlist,
    required this.sourceEngine,
  });

  void setHovering(bool isHovering) {
    hovering.value = isHovering;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: SizedBox(
          width: double.infinity,
          height: 70, // Fixed height for list item
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => OnlPlaylistView(
                          playlist: playlist,
                          sourceEngine: sourceEngine,
                        )),
              );
            },
            child: Container(
              color: Colors.transparent,
              child: Row(
                children: [
                  Hero(
                    tag: playlist.sourceId,
                    child: MouseRegion(
                      onEnter: (event) {
                        setHovering(true);
                      },
                      onExit: (event) {
                        setHovering(false);
                      },
                      child: LayoutBuilder(builder: (context, constraints2) {
                        return AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Stack(
                              children: [
                                SizedBox.square(
                                  dimension: constraints2.maxHeight,
                                  child: LoadImageCached(
                                    imageUrl: formatImgURL(
                                        playlist.imageURL, ImageQuality.medium),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: hovering,
                                  builder: (context, child, value) {
                                    return Positioned.fill(
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        color: hovering.value
                                            ? Colors.black
                                                .withValues(alpha: 0.5)
                                            : Colors.transparent,
                                        child: Center(
                                          child: AnimatedOpacity(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            opacity: hovering.value ? 1 : 0,
                                            child: const Icon(
                                              MingCute.play_circle_line,
                                              color: Colors.white,
                                              size: 30,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Default_Theme.secondoryTextStyleMedium
                              .merge(const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Default_Theme.primaryColor1,
                          )),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Playlist",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Default_Theme.secondoryTextStyleMedium
                              .merge(TextStyle(
                            fontSize: 13,
                            color: Default_Theme.primaryColor1
                                .withValues(alpha: 0.7),
                          )),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.more_vert_rounded,
                    color: Default_Theme.primaryColor1.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
