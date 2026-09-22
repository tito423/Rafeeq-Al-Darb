"""Make the Qur'an recogniser loadable on a phone: HF -> OpenAI -> sherpa ONNX.

Why this file exists (2026-09-22, settled by reading the files themselves):
sherpa-onnx's own exporter names the encoder's tensors `mel` ->
`n_layer_cross_k` / `n_layer_cross_v`, while every ready-made ONNX of
`tarteel-ai/whisper-base-ar-quran` on the Hub is an **optimum** export whose
names are `input_features` -> `last_hidden_state`. sherpa cannot load those.
sherpa's exporter, in turn, takes an **OpenAI** checkpoint
(`{"dims": …, "model_state_dict": …}`), and the Tarteel weights are in
HuggingFace layout. This script is the bridge, and it PROVES the bridge
rather than assuming it:

  1. rewrites the HF state dict into OpenAI's names (the mapping below),
  2. loads it with `whisper.load_model` and transcribes a real ayah,
  3. compares that transcript with what `faster-whisper` gets from the SAME
     weights — if the conversion were wrong the words would not match, and
     the script stops.

Only then is it worth running sherpa's exporter on the result.

    py -3 -m pip install torch --index-url https://download.pytorch.org/whl/cpu
    py -3 -m pip install openai-whisper onnx sherpa-onnx faster-whisper
    py -3 scripts/export_quran_asr_onnx.py --work scripts/asr_probe
"""
import argparse
import json
import os
import re
import subprocess
import sys

HF_REPO = "tarteel-ai/whisper-base-ar-quran"
HF_FILES = ("pytorch_model.bin", "config.json")
UA = "RafeeqAlDarb/3.56 (https://github.com/tito423/Rafeeq-Al-Darb) curl/8"
# a real recitation, the same file the app itself downloads
PROBE = ("https://everyayah.com/data/Husary_128kbps/018001.mp3", "018001.mp3")
FFMPEG = r"C:\Program Files\ShareX\ffmpeg.exe"


def hf_to_openai(sd, cfg):
    """HuggingFace Whisper weights under OpenAI's names.

    Mechanical, and every key is accounted for: anything left over at the end
    is printed and the run stops, because a silently dropped tensor is a
    model that loads and then hears nothing.
    """
    out = {}
    left = dict(sd)

    def take(src, dst):
        if src in left:
            out[dst] = left.pop(src)

    take("model.encoder.conv1.weight", "encoder.conv1.weight")
    take("model.encoder.conv1.bias", "encoder.conv1.bias")
    take("model.encoder.conv2.weight", "encoder.conv2.weight")
    take("model.encoder.conv2.bias", "encoder.conv2.bias")
    take("model.encoder.embed_positions.weight", "encoder.positional_embedding")
    take("model.encoder.layer_norm.weight", "encoder.ln_post.weight")
    take("model.encoder.layer_norm.bias", "encoder.ln_post.bias")
    take("model.decoder.embed_tokens.weight", "decoder.token_embedding.weight")
    take("model.decoder.embed_positions.weight", "decoder.positional_embedding")
    take("model.decoder.layer_norm.weight", "decoder.ln.weight")
    take("model.decoder.layer_norm.bias", "decoder.ln.bias")

    attn = {"q_proj": "query", "k_proj": "key", "v_proj": "value",
            "out_proj": "out"}
    for side, n_layers in (("encoder", cfg["encoder_layers"]),
                           ("decoder", cfg["decoder_layers"])):
        for i in range(n_layers):
            h = f"model.{side}.layers.{i}"
            o = f"{side}.blocks.{i}"
            for hf_name, oa_name in attn.items():
                for w in ("weight", "bias"):
                    take(f"{h}.self_attn.{hf_name}.{w}", f"{o}.attn.{oa_name}.{w}")
                    if side == "decoder":
                        take(f"{h}.encoder_attn.{hf_name}.{w}",
                             f"{o}.cross_attn.{oa_name}.{w}")
            for w in ("weight", "bias"):
                take(f"{h}.self_attn_layer_norm.{w}", f"{o}.attn_ln.{w}")
                take(f"{h}.final_layer_norm.{w}", f"{o}.mlp_ln.{w}")
                take(f"{h}.fc1.{w}", f"{o}.mlp.0.{w}")
                take(f"{h}.fc2.{w}", f"{o}.mlp.2.{w}")
                if side == "decoder":
                    take(f"{h}.encoder_attn_layer_norm.{w}", f"{o}.cross_attn_ln.{w}")

    # `proj_out.weight` is tied to the token embedding; whisper does not
    # carry it separately.
    left.pop("proj_out.weight", None)
    if left:
        sys.exit("unmapped HF tensors, refusing to write a half-converted "
                 "model:\n  " + "\n  ".join(sorted(left)[:20]))
    return out


def _samples(wav_path):
    """16 kHz mono PCM as float32 in [-1, 1] — what whisper wants."""
    import wave

    import numpy as np

    with wave.open(wav_path, "rb") as w:
        assert w.getframerate() == 16000 and w.getnchannels() == 1, "16k mono only"
        raw = w.readframes(w.getnframes())
    return np.frombuffer(raw, dtype=np.int16).astype("float32") / 32768.0


def dims_from(cfg):
    return {
        "n_mels": cfg["num_mel_bins"],
        "n_audio_ctx": cfg["max_source_positions"],
        "n_audio_state": cfg["d_model"],
        "n_audio_head": cfg["encoder_attention_heads"],
        "n_audio_layer": cfg["encoder_layers"],
        "n_vocab": cfg["vocab_size"],
        "n_text_ctx": cfg["max_target_positions"],
        "n_text_state": cfg["d_model"],
        "n_text_head": cfg["decoder_attention_heads"],
        "n_text_layer": cfg["decoder_layers"],
    }


def main():
    import torch
    import whisper

    ap = argparse.ArgumentParser()
    ap.add_argument("--work", default=os.path.join("scripts", "asr_probe"))
    args = ap.parse_args()
    work = os.path.abspath(args.work)
    os.makedirs(work, exist_ok=True)

    for name in HF_FILES:
        path = os.path.join(work, name)
        if not os.path.exists(path):
            subprocess.run(["curl", "-sSL", "-A", UA, "-o", path,
                            f"https://huggingface.co/{HF_REPO}/resolve/main/{name}"],
                           check=True)
    cfg = json.load(open(os.path.join(work, "config.json"), encoding="utf-8"))
    sd = torch.load(os.path.join(work, "pytorch_model.bin"), map_location="cpu",
                    weights_only=True)
    ckpt = {"dims": dims_from(cfg), "model_state_dict": hf_to_openai(sd, cfg)}
    out = os.path.join(work, "quran-base.pt")
    torch.save(ckpt, out)
    print(f"wrote {out} ({os.path.getsize(out)} B)")

    # --- prove the conversion on a real recitation ------------------------
    mp3 = os.path.join(work, PROBE[1])
    wav = mp3.replace(".mp3", ".wav")
    if not os.path.exists(mp3):
        subprocess.run(["curl", "-sSL", "-A", UA, "-o", mp3, PROBE[0]], check=True)
    if not os.path.exists(wav):
        subprocess.run([FFMPEG, "-v", "quiet", "-y", "-i", mp3, "-ar", "16000",
                        "-ac", "1", wav], check=True)
    model = whisper.load_model(out)
    # openai-whisper shells out to `ffmpeg` on PATH, and this machine's ffmpeg
    # lives inside ShareX (trap #14). The wav is already 16 kHz mono, so read
    # it here and hand whisper the samples.
    said = model.transcribe(_samples(wav), language="ar", fp16=False)["text"]
    from faster_whisper import WhisperModel
    ref_model = WhisperModel("OdyAsh/faster-whisper-base-ar-quran", device="cpu",
                             compute_type="int8")
    segs, _ = ref_model.transcribe(wav, language="ar", beam_size=5)
    ref = " ".join(s.text for s in segs)

    def words(t):
        t = re.sub(r"[^\u0621-\u064a\s]", " ", t)
        return [w for w in t.split() if w]

    a, b = words(said), words(ref)
    same = sum(1 for x, y in zip(a, b) if x == y)
    print(f"converted model says : {said.strip()}")
    print(f"reference says       : {ref.strip()}")
    print(f"agreement            : {same}/{max(len(a), len(b))} words")
    if not b or same < 0.8 * len(b):
        sys.exit("the converted checkpoint does not agree with the reference — "
                 "the mapping is wrong, stop here")
    print("OK: the conversion reproduces the reference transcript.")
    print("\nNext: run sherpa-onnx's exporter on it, from its repo:\n"
          f"  python3 scripts/whisper/export-onnx.py --model {out}")


if __name__ == "__main__":
    main()
