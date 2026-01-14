import 'package:Bloomee/model/album_onl_model.dart';
import 'package:Bloomee/screens/screen/common_views/album_view.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:Bloomee/utils/imgurl_formator.dart';
import 'package:Bloomee/utils/load_Image.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';

class AlbumCard extends StatelessWidget {
  final AlbumModel album;
  final ValueNotifier<bool> hovering = ValueNotifier(false);
  AlbumCard({
    super.key,
    required this.album,
  });

  void setHovering(bool isHovering) {
    hovering.value = isHovering;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: LayoutBuilder(builder: (context, constraints) {
          return SizedBox(
            width: double.infinity,
            height: 70, // Fixed height for list item
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AlbumView(
                            album: album,
                          )),
                );
              },
              child: MouseRegion(
                onEnter: (event) {
                  setHovering(true);
                },
                onExit: (event) {
                  setHovering(false);
                },
                child: Container(
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      // Album Art
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Stack(
                            children: [
                              LoadImageCached(
                                imageUrl: formatImgURL(
                                    album.imageURL, ImageQuality.medium),
                              ),
                              ValueListenableBuilder(
                                valueListenable: hovering,
                                builder: (context, child, value) {
                                  return Positioned.fill(
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      color: hovering.value
                                          ? Colors.black.withValues(alpha: 0.5)
                                          : Colors.transparent,
                                      child: Center(
                                        child: AnimatedOpacity(
                                          duration:
                                              const Duration(milliseconds: 200),
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
                      ),
                      const SizedBox(width: 15),
                      // Text Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              album.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Default_Theme.secondoryTextStyleMedium
                                  .merge(TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Default_Theme.primaryColor1
                                    .withValues(alpha: 0.9),
                              )),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Album • ${album.artists}",
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
                      // Options Icon (Optional, keeping minimal for now)
                      Icon(
                        Icons.more_vert_rounded,
                        color:
                            Default_Theme.primaryColor1.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }));
  }
}
