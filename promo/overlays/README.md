# Overlays

Guides and cards that sit over an edit. They are generated, not stored: film them into your output folder.

- Safe-zone guide for tall video: `python promo/tools/capture.py shot elements safezone` (a still for the top track of a vertical timeline; delete it before export). The boxes are approximate.
- End card: `python promo/tools/capture.py shot elements endcard` (wide, vertical and square, transparent).
- Logo: `python promo/tools/capture.py stage title --set text=GOONCRUSHER --seconds 0 --profile wide4k` (a transparent PNG).
- The Steam and Discord marks are the official files in `texture/icon/steam.png` and `discord.png`. Don't redraw them.
