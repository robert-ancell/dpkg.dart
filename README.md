[![Pub Package](https://img.shields.io/pub/v/dpkg.svg)](https://pub.dev/packages/dpkg)

Provides classes to extract Debian packages.

```dart
import 'package:dpkg/dpkg.dart';

void main(List<String> args) async {
  var f = DebBinaryFile(args.first);
  var control = await f.getControl();
  print('${control.package} ${control.version}');
  await f.close();
}
```

## Contributing to dpkg.dart

We welcome contributions! See the [contribution guide](CONTRIBUTING.md) for more details.
