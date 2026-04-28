class HostEntry {
  const HostEntry._();

  static const disabledPrefix = "!";

  static bool isEnabled(String key) => !key.startsWith(disabledPrefix);

  static String displayKey(String key) {
    if (isEnabled(key)) {
      return key;
    }
    return key.substring(disabledPrefix.length);
  }

  static String storageKey(String key, {required bool enabled}) {
    final display = displayKey(key.trim());
    return enabled ? display : "$disabledPrefix$display";
  }
}
