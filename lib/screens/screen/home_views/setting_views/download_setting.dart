import 'dart:io';
import 'package:Bloomee/services/db/bloomee_db_service.dart';

import 'package:Bloomee/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:Bloomee/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Bloomee/screens/widgets/setting_tile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DownloadSettings extends StatefulWidget {
  const DownloadSettings({super.key});

  @override
  State<DownloadSettings> createState() => _DownloadSettingsState();
}

Future<bool> storagePermission() async {
  final DeviceInfoPlugin info = DeviceInfoPlugin();
  final AndroidDeviceInfo androidInfo = await info.androidInfo;
  debugPrint('releaseVersion : ${androidInfo.version.release}');
  debugPrint('sdkInt : ${androidInfo.version.sdkInt}');
  final int sdkInt = androidInfo.version.sdkInt;
  bool havePermission = false;

  if (sdkInt >= 30) {
    // Android 11+ (R)
    final status = await Permission.manageExternalStorage.status;
    if (status.isGranted) {
      havePermission = true;
    } else {
      final request = await Permission.manageExternalStorage.request();
      havePermission = request.isGranted;
    }
  } else if (sdkInt >= 29) {
    // Android 10 (Q) - scoped storage, typically just need standard storage or specialized logic
    // allowing standard storage permission flow for now
    final status = await Permission.storage.request();
    havePermission = status.isGranted;
  } else {
    // Android 9 and below
    final status = await Permission.storage.request();
    havePermission = status.isGranted;
  }

  if (!havePermission) {
    // if no permission then open app-setting
    await openAppSettings();
  }

  return havePermission;
}

class _MoveProgressDialog extends StatefulWidget {
  final String newPath;
  final String oldPath;
  const _MoveProgressDialog({required this.newPath, required this.oldPath});

  @override
  State<_MoveProgressDialog> createState() => _MoveProgressDialogState();
}

class _MoveProgressDialogState extends State<_MoveProgressDialog> {
  double progress = 0.0;
  String status = "Preparing...";
  String currentFile = "";
  int currentCount = 0;
  int totalCount = 0;

  @override
  void initState() {
    super.initState();
    // Start the move operation after the first frame to ensure dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMove();
    });
  }

  void _startMove() {
    BloomeeDBService.moveDownloads(widget.newPath, widget.oldPath,
        (current, total, fileName) {
      if (mounted) {
        setState(() {
          currentCount = current;
          totalCount = total;
          progress = total > 0 ? current / total : 0;
          status = "Moving $current of $total";
          currentFile = fileName;
        });
      }
    }).then((_) async {
      // Scan for existing files in the new location
      if (mounted) {
        setState(() {
          status = "Scanning for existing files...";
        });
      }
      await BloomeeDBService.scanAndImportExistingFiles(widget.newPath);

      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("Moving Downloads"),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Default_Theme.primaryColor1.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Default_Theme.primaryColor1,
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${(progress * 100).toInt()}%",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("$currentCount / $totalCount"),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              currentFile,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadSettingsState extends State<DownloadSettings> {
  Future<void> changeDownloadPath() async {
    if (Platform.isAndroid) {
      // Check for storage permission
      final permission = await storagePermission();
      debugPrint('permission : $permission');
      if (!permission) return;
    }
    FilePicker.platform.getDirectoryPath().then((value) {
      if (value != null) {
        if (!mounted) return;
        final currentPath = context.read<SettingsCubit>().state.downPath;
        if (currentPath != value) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Move Downloads"),
              content: const Text(
                  "Do you want to move existing downloads to the new folder?"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.read<SettingsCubit>().setDownPath(value);

                    // Clear DB and scan new location
                    BloomeeDBService.clearAllDownloads().then((_) async {
                      await BloomeeDBService.scanAndImportExistingFiles(value);
                      if (context.mounted) {
                        context
                            .read<DownloaderCubit>()
                            .refreshDownloadedSongs();
                      }
                    });
                  },
                  child: const Text("No"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close confirm dialog
                    // Show progress dialog
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) {
                        return _MoveProgressDialog(
                            newPath: value, oldPath: currentPath);
                      },
                    ).then((_) {
                      // When dialog closes (operation finished)
                      if (context.mounted) {
                        context.read<SettingsCubit>().setDownPath(value);
                      }
                    });
                  },
                  child: const Text("Yes"),
                ),
              ],
            ),
          );
          context.read<SettingsCubit>().setDownPath(value);
        } else {
          // Even if path is same, we might want to ensure it's set
          context.read<SettingsCubit>().setDownPath(value);
        }
      }
    });
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Download Settings',
          style: const TextStyle(
                  color: Default_Theme.primaryColor1,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)
              .merge(Default_Theme.secondoryTextStyle),
        ),
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          debugPrint("DownloadSettings rebuilding. Path: ${state.downPath}");
          return ListView(
            children: [
              SettingTile(
                title: "Download Quality",
                subtitle:
                    "Quality of audio files downloaded from online sources.",
                trailing: DropdownButton(
                  value: state.downQuality,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Default_Theme.primaryColor1,
                    fontSize: 15,
                  ).merge(Default_Theme.secondoryTextStyle),
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      context.read<SettingsCubit>().setDownQuality(newValue);
                    }
                  },
                  items: <String>['96 kbps', '160 kbps', '320 kbps']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                      ),
                    );
                  }).toList(),
                ),
                onTap: () {},
              ),
              SettingTile(
                title: "Youtube Download Quality",
                subtitle:
                    "Quality of Youtube audio files downloaded from Youtube.",
                trailing: DropdownButton(
                  value: state.ytDownQuality,
                  style: const TextStyle(
                    color: Default_Theme.primaryColor1,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ).merge(Default_Theme.secondoryTextStyle),
                  underline: const SizedBox(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      context.read<SettingsCubit>().setYtDownQuality(newValue);
                    }
                  },
                  items: <String>['High', 'Low']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                      ),
                    );
                  }).toList(),
                ),
                onTap: () {},
              ),
              SettingTile(
                title: "Download Folder",
                subtitle: state.downPath,
                trailing: IconButton(
                  icon: const Icon(
                    MingCute.refresh_1_line,
                    color: Default_Theme.primaryColor1,
                  ),
                  onPressed: () async {
                    await changeDownloadPath();
                  },
                ),
                onTap: () async {
                  await changeDownloadPath();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
