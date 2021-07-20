import 'ar_archive.dart';

class DebFile {
  // The archive that is the .deb file.
  final ArArchive _archive;

  DebFile(String path) : _archive = ArArchive(path);

  Future<DebControl> getControl() async {
    var files = await _archive.getFiles();

    for (var file in files) {
      if (file.identifier == 'control.tar.gz' || file.identifier == 'control.tar.xz') {
        return DebControl();
      }
    }

    throw 'Missing Debian control information';
  }

  /// Close the deb file.
  Future<void> close() async {
    await _archive.close();
  }
}

class DebControl {}
