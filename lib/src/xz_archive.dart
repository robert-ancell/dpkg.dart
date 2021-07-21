import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Documented in https://tukaani.org/xz/xz-file-format.txt

/// An object used for accessing Xz format archives.
class XzArchive {
  final RandomAccessFile _file;
  final int _offset;
  final int _size;

  /// Creates an object access an Xz achive in [file].
  XzArchive(RandomAccessFile file, {int offset = 0, int size = -1})
      : _file = file,
        _offset = offset,
        _size = size;

  Future<void> decode() async {
    var magic = await _read(0, 6);
    if (magic.length != 6) {
      throw 'Invalid .xz header length';
    }
    var magicIsValid = magic[0] == 253 &&
        magic[1] == 55 && // '7'
        magic[2] == 122 && // 'z'
        magic[3] == 88 && // 'X'
        magic[4] == 90 && // 'Z'
        magic[5] == 0;
    if (!magicIsValid) {
      throw 'Invalid .xz magic: $magic';
    }

    //var flags = await _read(6, 2);
    //var crc = await _read(8, 4);
  }

  /// Gets the files present in this archive.
  Future<List<XzFile>> getFiles() async {
    return [];
  }

  // Reads [length] bytes from [offset].
  Future<Uint8List> _read(int offset, int length) async {
    await _file.setPosition(_offset + offset);
    return _file.read(_clampLength(offset, length));
  }

  // Get the maximum length to read to avoid hitting the size limit.
  int _clampLength(int offset, int length) {
    if (_size >= 0 && offset + length > _size) {
      return _size - offset;
    } else {
      return length;
    }
  }
}

/// Represents a file in an Xz archive.
class XzFile {
  XzFile();

  @override
  String toString() => 'XzFile()';
}
