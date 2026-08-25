import 'dart:typed_data';

/// How a document should be presented, derived from its extension.
///
/// Reading mode used to run every document through the same prose renderer
/// — serif face, narrow measure, reader colours — which is right for a fic
/// and wrong for a stylesheet. Splitting the decision here lets the reader
/// pick a presentation instead of pretending everything is prose.
enum DocumentKind {
  /// Markdown and plain text: the prose reader, bookmarks, reading settings.
  prose,

  /// HTML: rendered as a simple preview, with the source one tap away.
  markup,

  /// Source code and structured data: the monospace viewer.
  code,
}

const _proseExtensions = {'md', 'markdown', 'txt', 'text'};
const _markupExtensions = {'html', 'htm'};

DocumentKind documentKindOf(String extension) {
  final normalized = extension.toLowerCase();
  if (_proseExtensions.contains(normalized)) return DocumentKind.prose;
  if (_markupExtensions.contains(normalized)) return DocumentKind.markup;
  return DocumentKind.code;
}

/// Why a file could not be brought into the library.
enum ImportRejection { unsupportedType, tooLarge, binaryContent }

/// Recognisable openings of container formats that are *not* text, even
/// though people reasonably expect a "document" app to take them. `.docx`,
/// `.xlsx`, `.odt` and friends are all ZIP archives; the rest are here
/// because they turn up in the same file picker.
const _binarySignatures = <List<int>>[
  [0x50, 0x4B, 0x03, 0x04], // ZIP: docx, xlsx, pptx, odt, epub
  [0x50, 0x4B, 0x05, 0x06], // empty ZIP
  [0x25, 0x50, 0x44, 0x46], // %PDF
  [0xD0, 0xCF, 0x11, 0xE0], // legacy MS Office (.doc, .xls)
  [0x89, 0x50, 0x4E, 0x47], // PNG
  [0xFF, 0xD8, 0xFF], // JPEG
  [0x47, 0x49, 0x46, 0x38], // GIF8
  [0x7F, 0x45, 0x4C, 0x46], // ELF
  [0x1F, 0x8B], // gzip
];

/// Whether a payload is binary rather than text.
///
/// The extension allowlist alone was not enough: a file picker's extension
/// filter is a hint the user can override, an Android content URI does not
/// always carry a usable filename, and renaming `fic.docx` to `fic.txt`
/// sails straight through. When one of those got in, the decoder replaced
/// every undecodable byte with U+FFFD and the library filled up with a
/// document of garbage that also broke rendering. Checking the bytes
/// themselves catches all of those the same way.
bool isBinaryPayload(Uint8List bytes) {
  if (bytes.isEmpty) return false;
  for (final signature in _binarySignatures) {
    if (bytes.length >= signature.length) {
      var matches = true;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[i] != signature[i]) {
          matches = false;
          break;
        }
      }
      if (matches) return true;
    }
  }
  // A NUL byte never appears in UTF-8 text; a scattering of other control
  // characters can (a stray form feed), so only a real concentration of
  // them counts. Sampling the head is enough to tell the two apart.
  final sample = bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes;
  var control = 0;
  for (final byte in sample) {
    if (byte == 0) return true;
    final isTextControl = byte == 0x09 || byte == 0x0A || byte == 0x0D;
    if (byte < 0x20 && !isTextControl) control++;
  }
  return control / sample.length > 0.05;
}
