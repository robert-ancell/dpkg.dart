import 'dart:io';

import 'package:dpkg/dpkg.dart';
import 'package:test/test.dart';

String getTestPackagePath(String packageName) {
  return Directory.current.path + '/test/test-packages/' + packageName;
}

void main() {
  test('empty', () async {
    var deb = DebBinaryFile(getTestPackagePath('empty_1.0_all.deb'));
    var control = await deb.getControl();
    expect(control.package, equals('empty'));
    expect(control.version, equals('1.0'));
    await deb.close();
  });
}
