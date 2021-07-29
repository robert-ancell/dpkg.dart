import 'package:dpkg/dpkg.dart';

void main(List<String> args) async {
  var f = DebBinaryFile(args.first);
  var control = await f.getControl();
  print('${control.package} ${control.version}');
  await f.close();
}
