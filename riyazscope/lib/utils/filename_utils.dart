/// Utility functions for filename manipulation
class FilenameUtils {
  /// Shorten a filename if it's too long
  /// Format: abcdef...uvwxyz.mp3
  /// Only shortens if filename is longer than 20 characters
  static String shortenFilename(String filename) {
    if (filename.length <= 20) {
      return filename;
    }

    // Find the last dot to separate extension
    final lastDotIndex = filename.lastIndexOf('.');
    if (lastDotIndex == -1) {
      // No extension, just shorten the whole name
      return '${filename.substring(0, 6)}...${filename.substring(filename.length - 6)}';
    }

    final nameWithoutExt = filename.substring(0, lastDotIndex);
    final extension = filename.substring(lastDotIndex);

    if (nameWithoutExt.length <= 12) {
      // Name without extension is short enough
      return filename;
    }

    // Take first 6 and last 6 characters of the name (without extension)
    final start = nameWithoutExt.substring(0, 6);
    final end = nameWithoutExt.substring(nameWithoutExt.length - 6);

    return '$start...$end$extension';
  }
}

