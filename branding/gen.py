#!/usr/bin/env python3
"""Minimal Nano Banana Pro (Gemini 3 Pro Image) generator.

Usage: GEMINI_API_KEY=... python3 gen.py "<prompt>" out.png
Compatible with google-genai 1.47 (ImageConfig accepts only aspect_ratio).
"""
import sys
from pathlib import Path
from google import genai
from google.genai import types

prompt, out = sys.argv[1], Path(sys.argv[2])
aspect = sys.argv[3] if len(sys.argv) > 3 else "1:1"
client = genai.Client()
resp = client.models.generate_content(
    model="gemini-3-pro-image-preview",
    contents=[prompt],
    config=types.GenerateContentConfig(
        response_modalities=["TEXT", "IMAGE"],
        image_config=types.ImageConfig(aspect_ratio=aspect),
    ),
)
for part in resp.parts:
    if getattr(part, "text", None):
        print(part.text, file=sys.stderr)
        continue
    img = part.as_image() if hasattr(part, "as_image") else None
    if img is not None:
        img.save(str(out))
        print("saved", out)
        break
    inline = getattr(part, "inline_data", None)
    if inline and getattr(inline, "data", None):
        out.write_bytes(inline.data)
        print("saved", out)
        break
else:
    sys.exit(f"no image returned. feedback={getattr(resp, 'prompt_feedback', None)!r}")
