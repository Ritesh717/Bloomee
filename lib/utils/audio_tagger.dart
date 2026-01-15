// lib/audio_tagger.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:metadata_god/metadata_god.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// A simple data class to hold audio metadata.
class AudioMetadata {
  final String title;
  final String artist;
  final String album;
  final String artworkUrl;
  Duration? duration; // Optional duration field

  AudioMetadata({
    required this.title,
    required this.artist,
    required this.album,
    required this.artworkUrl,
    this.duration,
  });
}

/// A dedicated module for writing metadata to audio files.
class AudioTagger {
  /// Writes the provided metadata to the audio file at [filePath].
  /// This is a non-critical operation; it will log errors but not throw them,
  /// ensuring a download is still considered successful even if tagging fails.
  static Future<void> writeTags(String filePath, AudioMetadata metadata) async {
    File? tempArtworkFile;
    try {
      // 1. Download the artwork to a temporary file.
      final response = await http.get(Uri.parse(metadata.artworkUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
            "Failed to download artwork: Status code ${response.statusCode}");
      }

      final tempDir = await getTemporaryDirectory();
      final artworkName =
          'artwork_${DateTime.now().millisecondsSinceEpoch}.jpg';
      tempArtworkFile = File(path.join(tempDir.path, artworkName));
      await tempArtworkFile.writeAsBytes(response.bodyBytes);

      // 2. Prepare the metadata object for the library.
      final coverArt = Picture(
        data: await tempArtworkFile.readAsBytes(),
        mimeType: lookupMimeType(tempArtworkFile.path) ?? 'image/jpeg',
      );

      // 3. Write the metadata to the audio file.
      await MetadataGod.writeMetadata(
        file: filePath,
        metadata: Metadata(
          title: metadata.title,
          artist: metadata.artist,
          album: metadata.album,
          albumArtist: metadata.artist,
          picture: coverArt,
          durationMs: metadata.duration?.inMilliseconds.toDouble(),
        ),
      );
      print("Successfully wrote metadata to $filePath");
    } catch (e) {
      print(
          "Failed to write metadata for $filePath. This is a non-fatal error. Error: $e");
      // Don't rethrow; tagging is an optional enhancement.
    } finally {
      // 4. Clean up the temporary artwork file.
      try {
        if (tempArtworkFile != null && await tempArtworkFile.exists()) {
          await tempArtworkFile.delete();
        }
      } catch (e) {
        print("Error deleting temporary artwork file: $e");
      }
    }
  }

  /// Reads metadata from the audio file at [filePath].
  /// Returns [AudioMetadata] if successful, or null if reading fails.
  /// If artwork is found, it saves it to the application documents directory and returns the path.
  static Future<AudioMetadata?> readTags(String filePath) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: filePath);
      // if (metadata == null) return null; // Removed as per lint

      String artworkUrl = "";
      // Save artwork to file if present
      if (metadata.picture != null) {
        try {
          final appDir = await getApplicationDocumentsDirectory();
          final artworkDir = Directory(path.join(appDir.path, 'artworks'));
          if (!await artworkDir.exists()) {
            await artworkDir.create(recursive: true);
          }

          final fileName = path.basenameWithoutExtension(filePath);
          // Use a safe filename for the artwork
          final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s\.-]'), '');
          final artworkFile =
              File(path.join(artworkDir.path, '$safeFileName.jpg'));

          await artworkFile.writeAsBytes(metadata.picture!.data);
          artworkUrl = artworkFile.path;
        } catch (e) {
          print("Failed to save extracted artwork: $e");
        }
      }

      return AudioMetadata(
        title: metadata.title ?? path.basenameWithoutExtension(filePath),
        artist: metadata.artist ?? "Unknown Artist",
        album: metadata.album ?? "Unknown Album",
        artworkUrl: artworkUrl,
        duration: metadata.durationMs != null
            ? Duration(milliseconds: metadata.durationMs!.toInt())
            : null,
      );
    } catch (e) {
      print("Failed to read metadata from $filePath: $e");
      return null;
    }
  }
}
