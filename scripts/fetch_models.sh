#!/usr/bin/env bash
# Downloads every AST PRO model from its upstream source, verifies SHA-256 and size,
# writes attribution files. Fails loudly on any mismatch. Output folder: models/
set -euo pipefail
OUT=models
mkdir -p "$OUT"

fetch() {  # name url sha256 size
  local name="$1" url="$2" sha="$3" size="$4"
  echo "==> $name"
  curl -L --fail --retry 4 --retry-delay 5 -o "$OUT/$name" "$url"
  local actual asize
  actual=$(sha256sum "$OUT/$name" | cut -d' ' -f1)
  asize=$(stat -c%s "$OUT/$name")
  if [ "$actual" != "$sha" ]; then echo "SHA256 MISMATCH for $name: expected $sha got $actual"; exit 1; fi
  if [ "$asize" != "$size" ]; then echo "SIZE MISMATCH for $name: expected $size got $asize"; exit 1; fi
  echo "    OK $asize bytes, sha256 verified"
}

# ---- REQUIRED ----
fetch bandit-v2-multi.onnx \
  "https://github.com/marcomorosi06/FFmpegGUI/releases/download/bandit-onnx-2/bandit-v2-multi.onnx" \
  7836f01622021adc2fe2570f263ec365ef7677d598b51d27b015b94d869f2ff2 149293980

fetch tiger.int8.onnx \
  "https://huggingface.co/audiojs/tiger-dnr/resolve/main/tiger.int8.onnx" \
  2189859ac7e89cf4d9d284c6f393e737aaa2b3233ed7ee424ad622012bce7bca 7320735

fetch scnet-large.int8.onnx \
  "https://huggingface.co/audiojs/scnet-large/resolve/main/scnet-large.int8.onnx" \
  b2dc586a1e0e6c0afe4915e9057ea29111397b7bbf589edc3d85de91de79cd72 45082486

# ---- OPTIONAL (set INCLUDE_OPTIONAL=true) ----
if [ "${INCLUDE_OPTIONAL:-true}" = "true" ]; then
  fetch scnet.int8.onnx \
    "https://huggingface.co/audiojs/scnet/resolve/main/scnet.int8.onnx" \
    98228931494151762a1c4ab1ec7899a894b1f81fd4a509921a9d2f9bacc50845 12900277
  fetch spleeter-5stems.onnx \
    "https://github.com/marcomorosi06/FFmpegGUI/releases/download/spleeter-onnx-1/spleeter-5stems.onnx" \
    533f0f260e6bfd14f55027594ba443e9d5c1cd8a1507a67000fa312d5b2374cf 196647290
fi

# Licence texts from upstream (non-fatal: attribution file below is always written)
curl -L --fail -s -o "$OUT/BANDIT_LICENSE_CC-BY-SA-4.0.txt" \
  "https://github.com/marcomorosi06/FFmpegGUI/releases/download/bandit-onnx-2/LICENSE.txt" || echo "warn: bandit LICENSE not fetched"
curl -L --fail -s -o "$OUT/BANDIT_NOTICE.txt" \
  "https://github.com/marcomorosi06/FFmpegGUI/releases/download/bandit-onnx-2/NOTICE.txt" || echo "warn: bandit NOTICE not fetched"

cat > "$OUT/ATTRIBUTION.md" << 'EOT'
# AST PRO - model attributions and licences

- **Bandit v2, multilingual checkpoint** by Karn N. Watcharasupat, Chih-Wei Wu and Iroro Orife
  (Zenodo record 12701995). Weights: CC BY-SA 4.0. Code: Apache-2.0. ONNX conversion (no retraining)
  by marcomorosi06/FFmpegGUI. This ONNX file is an adaptation and is licensed CC BY-SA 4.0.
- **TIGER-DnR** by Mohan Xu, Kai Li, Guo Chen, Xiaolin Hu (Tsinghua University). Apache-2.0 per the
  weights' model card. ONNX export and int8 compaction by audiojs (https://huggingface.co/audiojs/tiger-dnr).
  Training data (DnR) has mixed per-clip licences, some non-commercial.
- **SCNet / SCNet-large** by Weinan Tong et al. (starrytong/SCNet), MIT. Checkpoint via
  ZFTurbo/Music-Source-Separation-Training (MIT). ONNX export and int8 compaction by audiojs.
  Trained on MUSDB18-HQ (educational-use dataset).
- **Spleeter** by Deezer Research, MIT. ONNX conversion by marcomorosi06/FFmpegGUI.

AST PRO is free and non-commercial. This release only redistributes unchanged ONNX files from the sources above.
EOT

cat > "$OUT/RELEASE_NOTES.md" << 'EOT'
AI model files for AST PRO, copied unchanged from their upstream sources after SHA-256 and size verification.
See ATTRIBUTION.md for authors and licences (Bandit v2 is CC BY-SA 4.0: attribution and share-alike apply to the ONNX file).
models_inspect.json lists every model's input/output names, shapes and metadata.
EOT

ls -l "$OUT"
