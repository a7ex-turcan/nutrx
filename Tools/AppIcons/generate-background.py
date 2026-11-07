# python3 -I Tools/AppIcons/generate-background.py <midnight|botanical|sunrise> <out.png>
# One 1024x1024 background for an alternate app icon (#139) from gpt-image-2 (gpt-image-1 if that's refused), from
# the prompt of that name. The results used are in Tools/AppIcons/backgrounds/; compose-icon.swift puts the app icon's
# mark on them. Reads the key from ~/.config/openai/api_key itself; it's never printed or passed on a command line.
import base64, json, os, sys, urllib.request, urllib.error

COMMON = ("A square app icon background, full bleed edge to edge, perfectly flat front-on view. "
          "Absolutely no text, letters, numbers, logos, symbols, icons, frames, borders or rounded corners. ")
PROMPTS = {
    "midnight": COMMON + ("Deep midnight forest green fading to near-black at the edges, with a soft, subtle glow of "
                          "green light rising from the lower left, and very fine film grain. Calm, minimal, premium. "
                          "The centre and the lower half stay plain and uncluttered."),
    "botanical": COMMON + ("Dark forest green, colour #1B3B2D, with soft, out-of-focus silhouettes of leaves in "
                           "slightly lighter greens only along the top edge and the top corners, as if seen through "
                           "frosted glass. Gentle depth, minimal, calm. The lower two thirds are plain dark forest green."),
    "sunrise": COMMON + ("A warm sunrise gradient: soft peach and apricot at the top blending into warm amber and a hint "
                         "of rose at the bottom, with a faint soft glow near the top. Smooth and minimal, no noise, "
                         "no texture, no sun disc."),
}

def main():
    name, out = sys.argv[1], sys.argv[2]
    key = open(os.path.expanduser("~/.config/openai/api_key")).read().strip()
    for model in ("gpt-image-2", "gpt-image-1"):
        body = json.dumps({"model": model, "prompt": PROMPTS[name], "size": "1024x1024", "quality": "high",
                           "n": 1}).encode()
        req = urllib.request.Request("https://api.openai.com/v1/images/generations", data=body, method="POST",
                                     headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=300) as resp:
                data = json.load(resp)
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:300]
            print(f"{model}: HTTP {error.code} {detail}")
            continue
        open(out, "wb").write(base64.b64decode(data["data"][0]["b64_json"]))
        print(f"{name}: {model} -> {out}")
        return
    sys.exit(1)

main()
