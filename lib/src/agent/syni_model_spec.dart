/// Identifies a downloadable inference model.
///
/// V1 ships a small curated catalog ([SyniModels]). Production builds should
/// validate [sha256] against a release manifest signed by Synheart's release
/// key — and ultimately fetch the whole catalog from `synheart-cloud` rather
/// than hard-coding it here.
library;

class SyniModelSpec {
  const SyniModelSpec({
    required this.id,
    required this.filename,
    required this.downloadUrl,
    required this.tokenizerUrl,
    required this.sha256,
    required this.approxBytes,
  });

  /// Stable identifier (e.g. `qwen2.5-1.5b-instruct-q4_k_m`). Used as the
  /// local filename root inside the syni cache directory.
  final String id;

  /// Filename used on disk (typically `<id>.gguf`).
  final String filename;

  /// HTTPS URL the GGUF model downloads from. MUST be https.
  final String downloadUrl;

  /// HTTPS URL for the matching `tokenizer.json`. The candle backend loads
  /// the tokenizer from a `tokenizer.json` sibling of the GGUF file, so the
  /// installer places it there. MUST be https.
  final String tokenizerUrl;

  /// Lowercase hex SHA-256 of the downloaded GGUF. Verification fails the
  /// install if mismatched. Empty string skips verification (V1 only).
  final String sha256;

  /// Approximate file size in bytes — for UI progress + capability gating.
  final int approxBytes;

  /// Parse the `local` block of a `/v1/models` manifest entry. The model
  /// `id` lives at the parent entry level, so it is passed in separately.
  factory SyniModelSpec.fromManifest(String id, Map<String, dynamic> local) {
    return SyniModelSpec(
      id: id,
      filename: local['filename'] as String,
      downloadUrl: local['download_url'] as String,
      tokenizerUrl: local['tokenizer_url'] as String,
      sha256: (local['sha256'] as String?) ?? '',
      approxBytes: (local['approx_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// V1 model catalog. Replace with a server-signed manifest fetched from
/// `synheart-cloud` once that exists. Pinned SHA-256 values come from the
/// HuggingFace LFS `x-linked-etag` header, which is the underlying file's
/// SHA-256 for LFS-stored objects.
class SyniModels {
  SyniModels._();

  /// Qwen2.5 1.5B Instruct, Q4_K_M quantization. ~1.1 GB. Non-gated on
  /// Hugging Face (anonymous download works).
  ///
  /// 1.5B is the V1 sweet spot: large enough to follow instructions and
  /// produce reliable structured output (a 0.5B model loops and ignores the
  /// schema), small enough for acceptable on-device CPU inference. Qwen2.5
  /// reports `general.architecture = qwen2` so the candle quantized-qwen2
  /// loader handles it unchanged.
  static const SyniModelSpec qwen25_15bInstructQ4 = SyniModelSpec(
    id: 'qwen2.5-1.5b-instruct-q4_k_m',
    filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    downloadUrl:
        'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
    // tokenizer.json from the (non-gated) base repo — the GGUF repo does not
    // ship one, and the candle backend needs it next to the model.
    tokenizerUrl:
        'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct/resolve/main/tokenizer.json',
    sha256: '6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e',
    approxBytes: 1117320736, // ~1.1 GB
  );

  /// Gemma 3 1B Instruct, Q4_K_M quantization. ~770 MB. Hosted in the
  /// Synheart-owned, non-gated mirror so a single org-controlled source
  /// covers both GGUF and tokenizer.
  ///
  /// Smaller than [qwen25_15bInstructQ4] — useful when the platform is
  /// memory-constrained or first-install latency matters more than
  /// peak instruction quality.
  static const SyniModelSpec gemma3_1bInstructQ4 = SyniModelSpec(
    id: 'gemma-3-1b-it-q4_k_m',
    filename: 'gemma-3-1b-it-q4_k_m.gguf',
    downloadUrl:
        'https://huggingface.co/Synheart/syni-life-gguf-gemma-3-1b/resolve/main/google_gemma-3-1b-it-Q4_K_M.gguf',
    // Tokenizer is hosted in the same Synheart repo — `tokenizer.json`
    // must be uploaded alongside the GGUF for installs to succeed.
    tokenizerUrl:
        'https://huggingface.co/Synheart/syni-life-gguf-gemma-3-1b/resolve/main/tokenizer.json',
    sha256: '12bf0fff8815d5f73a3c9b586bd8fee8e7b248c935de70dec367679873d0f29d',
    approxBytes: 806058496, // ~770 MB
  );
}
