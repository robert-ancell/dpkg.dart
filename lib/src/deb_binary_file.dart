import 'dart:io';

import 'package:archive/archive.dart';

import 'ar_archive.dart';
import 'deb_control_file.dart';

class DebBinaryFile {
  /// Path to the .deb file.
  final String path;

  // The .deb file.
  RandomAccessFile? _file;

  DebBinaryFile(this.path);

  Future<DebControl> getControl() async {
    var debFile = await _open();
    var archive = ArArchive(debFile);
    var files = await archive.getFiles();

    for (var file in files) {
      if (file.identifier == 'control.tar.gz') {
        var decoder = GZipDecoder();
        var tarData = decoder.decodeBytes(await archive.readFile(file));
        return _parseControlTar(tarData);
      } else if (file.identifier == 'control.tar.xz') {
        var decoder = XZDecoder();
        File('out.xz').writeAsBytesSync(await archive.readFile(file));
        var tarData = decoder.decodeBytes(await archive.readFile(file));
        return _parseControlTar(tarData);
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

  Future<DebControl> _parseControlTar(List<int> tarData) async {
    var decoder = TarDecoder();
    var archive = decoder.decodeBytes(tarData);
    var controlFile = archive.findFile('./control');
    if (controlFile == null) {
      throw 'Missing Debian control file';
    }
    var control = DebControlFile(controlFile.content);
    return DebControl(
        package: control.getField('Package') ?? '',
        version: control.getField('Version') ?? '',
        architecture: control.getField('Architecture') ?? '',
        maintainer: control.getField('Maintainer') ?? '',
        installedSize: int.parse(control.getField('Installed-Size') ?? '0'),
        description: control.getField('Description') ?? '');
  }
}

class DebControl {
  final String package;

  final String version;

  final String architecture;

  final String maintainer;

  final int installedSize;

  final String? section;

  final String description;

  const DebControl(
      {required this.package,
      required this.version,
      required this.architecture,
      required this.maintainer,
      required this.installedSize,
      this.section,
      required this.description});
}
