import 'package:Bloomee/blocs/add_to_playlist/cubit/add_to_playlist_cubit.dart';
import 'package:Bloomee/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Bloomee/blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';
import 'package:Bloomee/screens/widgets/base/base_bottom_sheet.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/screens/widgets/song_tile.dart';
import 'package:Bloomee/services/db/GlobalDB.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:Bloomee/services/db/cubit/bloomee_db_cubit.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:Bloomee/services/import_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void showMoreBottomSheet(
  BuildContext context,
  MediaItemModel song, {
  bool showDelete = false,
  bool showSinglePlay = false,
  bool showAddToQueue = true,
  bool showPlayNext = true,
  VoidCallback? onDelete,
}) {
  bool? isDownloaded;
  BloomeeDBService.getDownloadDB(song).then((value) {
    if (value != null) {
      isDownloaded = true;
    } else {
      isDownloaded = false;
    }
  });

  BaseBottomSheet.show(
    context: context,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8, left: 5, right: 4),
          child: SongCardWidget(
            song: song,
            showOptions: false,
            showCopyBtn: true,
            showInfoBtn: true,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(right: 10, left: 10),
          child: Opacity(
            opacity: 0.5,
            child: Divider(
              thickness: 2,
              color: Default_Theme.primaryColor1,
            ),
          ),
        ),
        if (showSinglePlay)
          BottomSheetListTile(
            icon: MingCute.play_circle_fill,
            title: 'Play with Mix',
            onTap: () {
              Navigator.pop(context);
              context
                  .read<BloomeePlayerCubit>()
                  .bloomeePlayer
                  .updateQueue([song], doPlay: true);
              SnackbarService.showMessage("Playing ${song.title}",
                  duration: const Duration(seconds: 2));
            },
          ),
        if (showPlayNext)
          BottomSheetListTile(
            icon: MingCute.square_arrow_right_line,
            title: 'Play Next',
            onTap: () {
              Navigator.pop(context);
              context
                  .read<BloomeePlayerCubit>()
                  .bloomeePlayer
                  .addPlayNextItem(song);
              SnackbarService.showMessage("Added to Next in Queue",
                  duration: const Duration(seconds: 2));
            },
          ),
        if (showAddToQueue)
          BottomSheetListTile(
            icon: MingCute.playlist_2_line,
            title: 'Add to Queue',
            onTap: () {
              Navigator.pop(context);
              context
                  .read<BloomeePlayerCubit>()
                  .bloomeePlayer
                  .addQueueItem(song);
              SnackbarService.showMessage("Added to Queue",
                  duration: const Duration(seconds: 2));
            },
          ),
        BottomSheetListTile(
          icon: MingCute.heart_fill,
          title: 'Add to Favorites',
          onTap: () {
            Navigator.pop(context);
            context.read<BloomeeDBCubit>().addMediaItemToPlaylist(
                song, MediaPlaylistDB(playlistName: "Liked"));
          },
        ),
        BottomSheetListTile(
          icon: MingCute.add_circle_fill,
          title: 'Add to Playlist',
          onTap: () {
            Navigator.pop(context);
            context.read<AddToPlaylistCubit>().setMediaItemModel(song);
            context.pushNamed(GlobalStrConsts.addToPlaylistScreen);
          },
        ),
        BottomSheetListTile(
          icon: Icons.share,
          title: 'Share',
          onTap: () async {
            Navigator.pop(context);
            SnackbarService.showMessage("Preparing ${song.title} for share.");
            final tmpPath = await ImportExportService.exportMediaItem(
                MediaItem2MediaItemDB(song));
            tmpPath != null ? Share.shareXFiles([XFile(tmpPath)]) : null;
          },
        ),
        if (isDownloaded != null && isDownloaded == true)
          BottomSheetListTile(
            icon: Icons.offline_pin_rounded,
            title: 'Available Offline',
            onTap: () {
              Navigator.pop(context);
            },
          )
        else
          BottomSheetListTile(
            icon: MingCute.download_2_fill,
            title: 'Download',
            onTap: () {
              Navigator.pop(context);
              context.read<DownloaderCubit>().downloadSong(song);
            },
          ),
        BottomSheetListTile(
          icon: MingCute.external_link_line,
          title: 'Open original link',
          onTap: () {
            Navigator.pop(context);
            launchUrl(Uri.parse(song.extras?['perma_url']));
          },
        ),
        if (showDelete)
          BottomSheetListTile(
            icon: MingCute.delete_2_fill,
            title: 'Delete',
            onTap: () {
              Navigator.pop(context);
              if (onDelete != null) onDelete();
            },
          ),
      ],
    ),
  );
}
