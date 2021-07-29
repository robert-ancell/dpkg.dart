import 'dart:convert';

// https://www.debian.org/doc/debian-policy/ch-controlfields.html#syntax-of-control-files

class DebControlFile {
  final _fields = <String, String>{};

  DebControlFile(List<int> data) {
    var lines = utf8.decode(data).split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      // Comment line
      if (line.startsWith('#')) {
        continue;
      }

      if (_isEmptyLine(line)) {
        continue;
      }

      var offset = line.indexOf(':');
      if (offset < 0) {
        throw 'Invalid line "$line"';
      }
      var name = line.substring(0, offset);
      var value = line.substring(offset + 1).trim();
      for (var j = i + 1; j < lines.length && _isContinueLine(lines[j]); j++) {
        value += '\n' + lines[j].substring(1);
        i++;
      }

      _fields[name] = value;
    }
  }

  String? getField(String name) {
    return _fields[name];
  }

  bool _isEmptyLine(String line) {
    for (var i = 0; i < line.length; i++) {
      if (line[i] != ' ' && line[i] != '\t') {
        return false;
      }
    }
    return true;
  }

  bool _isContinueLine(String line) {
    return line.startsWith(' ') || line.startsWith('\t');
  }
}
