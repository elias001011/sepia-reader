const supportedDocumentExtensions = <String>{
  'md',
  'markdown',
  'txt',
  'text',
  'htm',
  'dart',
  'js',
  'ts',
  'json',
  'yaml',
  'yml',
  'html',
  'css',
  'py',
  'java',
  'kt',
  'swift',
  'sh',
  'sql',
  'xml',
};

const maxImportedFileBytes = 5 * 1024 * 1024;

bool isSupportedDocumentPath(String path) {
  final filename = path.replaceAll('\\', '/').split('/').last;
  final dot = filename.lastIndexOf('.');
  if (dot <= 0 || dot == filename.length - 1) return false;
  return supportedDocumentExtensions.contains(
    filename.substring(dot + 1).toLowerCase(),
  );
}
