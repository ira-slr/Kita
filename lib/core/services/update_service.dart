import 'package:http/http.dart' as http;

class UpdateCheckResult {
  final bool isUpdateAvailable;
  final String latestVersion;
  final String currentVersion;

  UpdateCheckResult({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.currentVersion,
  });
}

class UpdateService {
  /// Fetches the latest published pubspec.yaml from GitHub main branch
  /// and compares it with the currently installed version.
  static Future<UpdateCheckResult> checkForUpdates(String currentVersion) async {
    try {
      final response = await http
          .get(Uri.parse('https://raw.githubusercontent.com/ira-slr/Kita/main/pubspec.yaml'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final content = response.body;
        final match = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
            .firstMatch(content);

        if (match != null) {
          final latestVersion = match.group(1)!;
          final isNewer = _isVersionNewer(currentVersion, latestVersion);
          return UpdateCheckResult(
            isUpdateAvailable: isNewer,
            latestVersion: latestVersion,
            currentVersion: currentVersion,
          );
        }
      }
    } catch (e) {
      // Graceful fallback on offline/timeout
    }

    return UpdateCheckResult(
      isUpdateAvailable: false,
      latestVersion: currentVersion,
      currentVersion: currentVersion,
    );
  }

  static bool _isVersionNewer(String current, String latest) {
    try {
      final currentParts = current.split('+')[0].split('.').map(int.parse).toList();
      final latestParts = latest.split('+')[0].split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (c > l) return false;
      }
    } catch (_) {}
    return false;
  }
}
