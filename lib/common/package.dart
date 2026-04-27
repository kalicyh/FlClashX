import 'dart:io';

import 'package:flclashx/common/constant.dart';
import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  String get ua => [
        "$appName/v$version",
        "clash-verge",
        "Platform/${Platform.operatingSystem}",
      ].join(" ");
}
