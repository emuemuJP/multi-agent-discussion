#!/usr/bin/env python3
"""Generate high-quality images using Gemini 3 Pro Image Preview (Nano Banana Pro) API."""

import argparse
import os
import sys
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description="Generate images via gemini-3-pro-image-preview API")
    parser.add_argument("--prompt", required=True, help="Image generation prompt")
    parser.add_argument("--output", required=True, help="Output PNG file path")
    parser.add_argument("--aspect-ratio", default="4:3", choices=["1:1", "4:3", "16:9", "9:16", "3:4"],
                        help="Aspect ratio (default: 4:3)")
    parser.add_argument("--size", default="2K", choices=["1K", "2K", "4K"],
                        help="Image size (default: 2K)")
    args = parser.parse_args()

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable is not set.", file=sys.stderr)
        print("Get your key at: https://aistudio.google.com/apikey", file=sys.stderr)
        sys.exit(1)

    from google import genai
    from google.genai import types

    client = genai.Client(api_key=api_key)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    print(f"Generating image with gemini-3-pro-image-preview...", file=sys.stderr)
    print(f"  Prompt: {args.prompt[:100]}{'...' if len(args.prompt) > 100 else ''}", file=sys.stderr)
    print(f"  Size: {args.size}, Aspect: {args.aspect_ratio}", file=sys.stderr)

    response = client.models.generate_content(
        model="gemini-3-pro-image-preview",
        contents=args.prompt,
        config=types.GenerateContentConfig(
            response_modalities=["TEXT", "IMAGE"],
            image_config=types.ImageConfig(
                aspect_ratio=args.aspect_ratio,
                image_size=args.size,
            ),
        ),
    )

    saved = False
    for part in response.parts:
        if image := part.as_image():
            if output_path.suffix.lower() == ".png":
                pil_img = image._pil_image
                pil_img.save(str(output_path), format="PNG")
            else:
                image.save(str(output_path))
            saved = True
            print(f"Image saved: {output_path}", file=sys.stderr)
            break

    if not saved:
        print("Error: No image was generated in the response.", file=sys.stderr)
        for part in response.parts:
            if part.text:
                print(f"  Model response: {part.text}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
