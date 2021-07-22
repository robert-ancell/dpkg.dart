import 'dart:io';

import 'ar_archive.dart';
import 'xz_archive.dart';

class DebFile {
  /// Path to the .deb file.
  final String path;

  // The .deb file.
  RandomAccessFile? _file;

  DebFile(this.path);

  Future<DebControl> getControl() async {
    var debFile = await _open();
    var archive = ArArchive(debFile);
    var files = await archive.getFiles();

    for (var file in files) {
      if (file.identifier == 'control.tar.gz') {
        return DebControl();
      } else if (file.identifier == 'control.tar.xz') {
        var controlArchive =
            XzArchive(debFile, offset: file.offset, size: file.size);
        print(await controlArchive.getStreams());
        return DebControl();
      }
    }

    throw 'Missing Debian control information';
  }

  /// Close the deb file.
  Future<void> close() async {
    if (_file != null) {
      await _file!.close();
    }
  }

  Future<RandomAccessFile> _open() async {
    if (_file == null) {
      _file = await File(path).open();
    }
    return _file!;
  }
}

class DebControl {}
