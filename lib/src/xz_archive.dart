import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Documented in https://tukaani.org/xz/xz-file-format.txt

/// An object used for accessing Xz format archives.
class XzArchive {
  final RandomAccessFile _file;
  final int _offset;
  final int _size;

  /// Creates an object to access an Xz [file].
  XzArchive(RandomAccessFile file, {int offset = 0, int size = -1})
      : _file = file,
        _offset = offset,
        _size = size;

  /// Gets the streams inside this file.
  Future<List<XzStream>> getStreams() async {
    await _readStreamFooter(_size - 12);

    return [await _readStream(0)];
  }

  Future<XzStream> _readStream(int offset) async {
    var flags = await _readStreamHeader(offset);

    var blockOffset = offset + 12;
    var blocks = <XzBlock>[];
    while (true) {
      var value = await _read(blockOffset, 1);
      if (value.isEmpty) {
        throw 'No space for .xz block header';
      }

      if (value[0] == 0) {
        var indexOffset = blockOffset;
        var index = await _readStreamIndex(indexOffset);
        if (index.records.length != blocks.length) {
          throw "Stream index doesn't match block count";
        }
        for (var i = 0; i < blocks.length; i++) {
          if (index.records[i].blockLength != blocks[i].length) {
            throw "Stream index doesn't match length of block $i";
          }
          if (index.records[i].uncompressedSize != blocks[i].uncompressedSize) {
            throw "Stream index doesn't match uncompressed size of block $i";
          }
        }
        var footer = await _readStreamFooter(indexOffset + index.length);
        if (footer.flags != flags) {
          throw "Stream footer flags doesn't match header";
        }
        if (footer.indexOffset != indexOffset) {
          throw 'Stream index size mismatch';
        }
        return XzStream(blocks: blocks);
      }

      var block =
          await _readBlock(blockOffset, (value[0] + 1) * 4, flags & 0xf);
      blocks.add(block);
      blockOffset += block.length;
    }

    throw 'Out of space reading stream';
  }

  Future<int> _readStreamHeader(int offset) async {
    var header = await _read(offset, 12);
    if (header.length != 12) {
      throw 'Invalid .xz stream header length';
    }
    var headerIsValid = header[0] == 253 &&
        header[1] == 55 && // '7'
        header[2] == 122 && // 'z'
        header[3] == 88 && // 'X'
        header[4] == 90 && // 'Z'
        header[5] == 0;
    if (!headerIsValid) {
      throw 'Invalid magic in .xz stream header';
    }

    if (header[6] != 0) {
      throw 'Invalid stream flags';
    }
    var flags = header[7];
    //FIXME: var crc = last 4 bytes of header

    return flags;
  }

  Future<XzBlock> _readBlock(
      int offset, int headerLength, int checkType) async {
    var header = await _read(offset, headerLength);
    if (header.length != headerLength) {
      throw 'Invalid .xz block header length';
    }

    var flags = header[1];
    var nFilters = (flags & 0x03) + 1;
    var hasCompressedLength = flags & 0x40 != 0;
    var hasUncompressedLength = flags & 0x80 != 0;
    //FIXME: var crc = last 4 bytes of header

    var o = offset + 2;
    var compressedLength = 0;
    if (hasCompressedLength) {
      var value = await _readMultibyteInteger(o);
      compressedLength = value.value;
      o += value.length;
    }
    var uncompressedSize = -1;
    if (hasUncompressedLength) {
      var value = await _readMultibyteInteger(o);
      uncompressedSize = value.value;
      o += value.length;
    }
    for (var i = 0; i < nFilters; i++) {
      var value = await _readMultibyteInteger(o);
      var id = value.value;
      o += value.length;
      value = await _readMultibyteInteger(o);
      var propertiesLength = value.value;
      o += value.length;
      o += propertiesLength;
    }

    // Add padding
    var paddingLength = 0;
    while ((compressedLength + paddingLength) % 4 != 0) {
      paddingLength++;
    }

    // Checksum
    int checkLength;
    if (checkType == 0) {
      checkLength = 0;
    } else if (checkType <= 0x03) {
      checkLength = 4;
    } else if (checkType <= 0x06) {
      checkLength = 8;
    } else if (checkType <= 0x09) {
      checkLength = 16;
    } else if (checkType <= 0x0c) {
      checkLength = 32;
    } else {
      checkLength = 64;
    }
    switch (checkType) {
      case 0: // none
        break;
      case 0x1: // CRC32
        // FIXME
        break;
      case 0x4: // CRC64
        // FIXME
        break;
      case 0xa: // SHA-256
        // FIXME
        break;
      default:
        throw 'Unknown block check type $checkType';
    }

    return XzBlock(
        length: headerLength + compressedLength + paddingLength + checkLength,
        dataOffset: offset + headerLength,
        dataLength: compressedLength,
        uncompressedSize: uncompressedSize);
  }

  Future<_XzStreamIndex> _readStreamIndex(int offset) async {
    var o = offset + 1;
    var value = await _readMultibyteInteger(o);
    var nRecords = value.value;
    o += value.length;
    var records = <_XzStreamIndexRecord>[];
    for (var i = 0; i < nRecords; i++) {
      var value = await _readMultibyteInteger(o);
      var blockLength = value.value;
      while (blockLength % 4 != 0) {
        blockLength++;
      }
      o += value.length;
      value = await _readMultibyteInteger(o);
      var uncompressedSize = value.value;
      o += value.length;
      records.add(_XzStreamIndexRecord(
          blockLength: blockLength, uncompressedSize: uncompressedSize));
    }
    var length = o - offset;
    while (length % 4 != 0) {
      length++;
    }
    // FIXME CRC
    length += 4;
    return _XzStreamIndex(length: length, records: records);
  }

  Future<_XzStreamFooter> _readStreamFooter(int offset) async {
    var footer = await _read(offset, 12);
    if (footer.length != 12) {
      throw 'Invalid .xz stream footer length';
    }
    if (footer[10] != 89 && // 'Y'
        footer[11] != 90) {
      // 'Z'
      throw 'Invalid magic in .xz stream footer';
    }
    if (footer[8] != 0) {
      throw 'Invalid stream flags';
    }
    var flags = footer[9];
    var indexLength =
        ((footer[7] << 24 | footer[6] << 16 | footer[5] << 8 | footer[4]) + 1) *
            4;
    // FIXME: CRC is footer[0..3]

    return _XzStreamFooter(flags: flags, indexOffset: offset - indexLength);
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

  Future<_XzMultibyteInteger> _readMultibyteInteger(int offset) async {
    var value = 0;
    var length = 1;
    while (true) {
      var data = await _read(offset, length);
      if (data.length != length) {
        throw 'Unterminated multibyte integer';
      }
      value |= (data.last & 0x7f) << ((length - 1) * 7);
      if (data.last & 0x80 == 0) {
        return _XzMultibyteInteger(value, length);
      }
      length++;
    }
  }
}

class XzStream {
  // Blocks that make up this stream.
  final List<XzBlock> blocks;

  const XzStream({required this.blocks});

  @override
  String toString() => 'XzStream(blocks: $blocks)';
}

class XzBlock {
  // Total length of the block in bytes.
  final int length;

  // Offset to the start of the compressed data.
  final int dataOffset;

  // Length of the the compressed data in bytes.
  final int dataLength;

  // Uncompressed size in bytes.
  final int uncompressedSize;

  const XzBlock(
      {required this.length,
      required this.dataOffset,
      required this.dataLength,
      required this.uncompressedSize});

  @override
  String toString() =>
      'XzBlock(length: $length, dataOffset: $dataOffset, dataLength: $dataLength, uncompressedSize: $uncompressedSize)';
}

class _XzMultibyteInteger {
  // Value of this integer.
  final int value;

  // Number of bytes this integer takes.
  final int length;

  const _XzMultibyteInteger(this.value, this.length);
}

class _XzStreamIndex {
  // Total length of the index in bytes.
  final int length;

  // Information about each block in this stream.
  final List<_XzStreamIndexRecord> records;

  const _XzStreamIndex({required this.length, required this.records});
}

class _XzStreamIndexRecord {
  // Block length in bytes.
  final int blockLength;

  // Uncompressed size in bytes.
  final int uncompressedSize;

  const _XzStreamIndexRecord(
      {required this.blockLength, required this.uncompressedSize});
}

class _XzStreamFooter {
  // Stream flags.
  final int flags;

  // Offset to the stream index.
  final int indexOffset;

  const _XzStreamFooter({required this.flags, required this.indexOffset});
}
