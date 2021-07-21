import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// An object used for accessing Ar format archives.
class ArArchive {
  RandomAccessFile _file;
  final int _offset;
  final int _size;
  List<ArFile>? _headers;
  bool _signatureChecked = false;
  bool _signatureIsValid = false;

  /// Creates an object access an Ar achive in [file]
  ArArchive(RandomAccessFile file, {int offset = 0, int size = -1})
      : _file = file,
        _offset = offset,
        _size = size;

  /// Gets the files present in this archive.
  Future<List<ArFile>> getFiles() async {
    if (_headers == null) {
      _headers = await _readFileHeaders();
    }

    return _headers!;
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

  // Checks if the archive file has the correct signature.
  Future<bool> _checkSignature() async {
    if (_signatureChecked) {
      return _signatureIsValid;
    }
    _signatureChecked = true;

    var data = await _read(0, 8);
    _signatureIsValid = data[0] == 33 && // '!'
        data[1] == 60 && // '<'
        data[2] == 97 && // 'a'
        data[3] == 114 && // 'r'
        data[4] == 99 && // 'c'
        data[5] == 104 && // 'h'
        data[6] == 62 && // '>'
        data[7] == 10; // '\n'

    return _signatureIsValid;
  }

  // Reads all the file headers from the archive.
  Future<List<ArFile>> _readFileHeaders() async {
    if (!await _checkSignature()) {
      throw 'Invalid Ar signature';
    }
    var offset = 8;
    var headers = <ArFile>[];
    while (true) {
      var header = await _readFileHeader(offset);
      if (header == null) {
        return headers;
      }
      headers.add(header);
      offset += 60 + header.size;

      // Align to 2 byte boundaries.
      if (offset % 2 != 0) {
        offset++;
      }
    }
  }

  // Reads a single file header from [offset].
  Future<ArFile?> _readFileHeader(int offset) async {
    var data = await _read(offset, 60);
    if (data.isEmpty) {
      return null;
    }
    if (data.length != 60) {
      throw 'Invalid Ar header length';
    }
    var identifier = _getField(data, 0, 16);
    var modificationTimestamp = int.parse(_getField(data, 16, 12));
    var ownerId = int.parse(_getField(data, 28, 6));
    var groupId = int.parse(_getField(data, 34, 6));
    var mode = int.parse(_getField(data, 40, 8), radix: 8);
    var size = int.parse(_getField(data, 48, 10));

    if (data[58] != 0x60 && data[59] != 0x0a) {
      throw 'Invalid Ar trailer';
    }
    return ArFile(
        identifier: identifier,
        modificationTimestamp: modificationTimestamp,
        ownerId: ownerId,
        groupId: groupId,
        mode: mode,
        offset: offset + 60,
        size: size);
  }

  // Decodes a ascii encoded field.
  String _getField(Uint8List data, int offset, int length) {
    return ascii.decode(data.sublist(offset, offset + length)).trimRight();
  }
}

/// Represents a file in an Ar archive.
class ArFile {
  /// Identifier
  final String identifier;

  /// Unix timestamp file for when file was last modified.
  final int modificationTimestamp;

  /// Owner user ID of this file.
  final int ownerId;

  /// Group ID for this file.
  final int groupId;

  /// Unix file type and permissions.
  final int mode;

  /// Offset inside the archive in bytes.
  final int offset;

  // Size of the file in bytes.
  final int size;

  ArFile(
      {required this.identifier,
      required this.modificationTimestamp,
      required this.ownerId,
      required this.groupId,
      required this.mode,
      required this.offset,
      required this.size});

  @override
  String toString() =>
      "ArFile(identifier: '$identifier', modificationTimestamp: $modificationTimestamp, ownerId: $ownerId, groupId: $groupId, mode: $mode, offset: $offset, size: $size)";
}
