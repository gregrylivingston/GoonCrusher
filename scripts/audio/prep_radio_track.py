#!/usr/bin/env python3
"""Prepare a track for the radio (docs/RADIO.md, "File format"): two-pass loudness
normalisation to -16 LUFS / -1 dBTP, trailing silence trimmed, 48 kHz Ogg Vorbis.

    python scripts/audio/prep_radio_track.py "Crush Hour.mp3" sound/radio/gooncrusher/songs
    python scripts/audio/prep_radio_track.py ident.wav sound/radio/gooncrusher/idents --quality 3

The output keeps the input's name with an .ogg extension (pass --name to change it). Needs ffmpeg
on PATH. Prints the loudness before and after. Open the project in Godot afterwards so it imports
the file, and commit the .ogg with its .import.
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

TARGET_I = -16.0
TARGET_TP = -1.0
TARGET_LRA = 11.0
SILENCE_DB = -50
SILENCE_MIN = 0.3


def ffmpeg(*args):
	return subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", *args], capture_output=True, text=True)


def measure(path, extra=""):
	"""loudnorm's first pass: the input's integrated loudness, true peak, range and threshold"""
	chain = (extra + "," if extra else "") + f"loudnorm=I={TARGET_I}:TP={TARGET_TP}:LRA={TARGET_LRA}:print_format=json"
	err = ffmpeg("-i", str(path), "-af", chain, "-f", "null", "-").stderr
	return json.loads(err[err.rindex("{"):err.rindex("}") + 1])


def duration(path):
	out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
		capture_output=True, text=True).stdout
	return float(out.strip())


def tailSilence(path, length):
	"""start of the silence that runs to the end of the file, or None"""
	err = ffmpeg("-i", str(path), "-af", f"silencedetect=n={SILENCE_DB}dB:d={SILENCE_MIN}", "-f", "null", "-").stderr
	starts = [float(m) for m in re.findall(r"silence_start: ([\d.]+)", err)]
	ends = [float(m) for m in re.findall(r"silence_end: ([\d.]+)", err)]
	if starts and (len(ends) < len(starts) or ends[-1] >= length - 0.05):
		return starts[-1]
	return None


def main():
	parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	parser.add_argument("source", type=Path)
	parser.add_argument("folder", type=Path, help="e.g. sound/radio/gooncrusher/songs")
	parser.add_argument("--name", help="output file stem (default: the source's)")
	parser.add_argument("--quality", type=int, default=5, help="Vorbis quality: 5 songs, 3 talk and idents")
	args = parser.parse_args()

	length = duration(args.source)
	cut = tailSilence(args.source, length)
	end = min(length, cut + 0.1) if cut is not None else length
	before = measure(args.source)
	m = measure(args.source, f"atrim=0:{end}")
	chain = (f"atrim=0:{end},loudnorm=I={TARGET_I}:TP={TARGET_TP}:LRA={TARGET_LRA}"
		f":measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}"
		f":measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true,aresample=48000")
	args.folder.mkdir(parents=True, exist_ok=True)
	out = args.folder / ((args.name or args.source.stem) + ".ogg")
	result = ffmpeg("-y", "-i", str(args.source), "-af", chain, "-c:a", "libvorbis", "-q:a", str(args.quality), str(out))
	if result.returncode != 0:
		sys.exit(result.stderr)
	after = measure(out)
	trimmed = length - end
	print(f"{out}  {duration(out):.1f} s  (trimmed {trimmed:.1f} s of tail silence)")
	print(f"  loudness {float(before['input_i']):.1f} -> {float(after['input_i']):.1f} LUFS, "
		f"true peak {float(before['input_tp']):.1f} -> {float(after['input_tp']):.1f} dBTP")


if __name__ == "__main__":
	main()
