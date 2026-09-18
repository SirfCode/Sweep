"""Convert Kenney Casino Audio 1.1 into Seep's bundled SFX.

Usage: python tool/prepare_sfx.py <extracted-pack-directory>
Requires numpy and soundfile (build tooling only, not app dependencies).
Source: https://kenney.nl/assets/casino-audio (CC0).
"""
import json
import shutil
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

source = Path(sys.argv[1])
output = Path(__file__).resolve().parents[1] / 'assets/audio/sfx'
output.mkdir(parents=True, exist_ok=True)
rate = 44100
manifest = {}


def clip(name, limit=0.6, speed=1.0):
    samples, sr = sf.read(source / 'Audio' / (name + '.ogg'), always_2d=True)
    samples = samples.mean(axis=1)
    active = np.flatnonzero(np.abs(samples) > max(0.001, np.max(np.abs(samples)) * .015))
    if not len(active):
        raise ValueError(f'Silent source: {name}')
    samples = samples[max(0, active[0] - int(sr * .003)):active[-1] + 1]
    samples = np.interp(np.arange(0, len(samples), sr * speed / rate),
                        np.arange(len(samples)), samples)[:int(limit * rate)]
    samples -= samples.mean()
    rms = np.sqrt(np.mean(samples ** 2))
    samples *= min(.11 / max(rms, 1e-6), .65 / max(np.max(np.abs(samples)), 1e-6))
    fade = min(int(rate * .004), len(samples) // 2)
    samples[:fade] *= np.linspace(0, 1, fade)
    samples[-fade:] *= np.linspace(1, 0, fade)
    return samples


def save(name, layers):
    rendered = []
    for original, start, gain, speed, limit in layers:
        rendered.append((int(start * rate), clip(original, limit, speed) * gain))
    samples = np.zeros(max(start + len(data) for start, data in rendered))
    for start, data in rendered:
        samples[start:start + len(data)] += data
    peak = np.max(np.abs(samples))
    if peak > .8:
        samples *= .8 / peak
    sf.write(output / (name + '.wav'), samples, rate, subtype='PCM_16')
    manifest[name + '.wav'] = {
        'sources': [layer[0] + '.ogg' for layer in layers],
        'seconds': round(len(samples) / rate, 3),
        'peak': round(float(np.max(np.abs(samples))), 3),
    }


for i in range(1, 3):
    save(f'button_{i}', [(f'chip-lay-{i}', 0, .7, 1, .09)])
for i in range(1, 4):
    save(f'deal_{i}', [(f'card-slide-{i}', 0, 1, 1, .3)])
    save(f'play_{i}', [(f'card-place-{i}', 0, 1, 1, .3)])
for i in range(1, 3):
    save(f'capture_{i}', [(f'card-shove-{i}', 0, 1, 1, .45)])
save('sweep', [('card-fan-1', 0, .85, 1, .4), ('card-shove-3', .18, .8, 1, .4)])
save('invalid', [('chip-lay-1', 0, .7, .85, .1), ('chip-lay-1', .13, .55, .85, .1)])
save('turn', [('chip-lay-3', 0, .85, .9, .16)])
save('score', [('chip-lay-2', 0, .7, 1, .14)])
save('round_win', [('chip-lay-1', 0, .8, .95, .14), ('chip-lay-2', .19, .85, 1.05, .18)])
save('round_lose', [('chip-lay-3', 0, .8, .7, .28)])
save('game_win', [('chip-lay-1', 0, .8, .9, .15), ('chip-lay-2', .2, .85, 1, .15),
                  ('chip-lay-3', .42, .9, 1.1, .22)])
shutil.copyfile(source / 'License.txt', output / 'LICENSE-Kenney.txt')
(output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print(json.dumps(manifest, indent=2))
print(f'{len(manifest)} WAV files; {sum(p.stat().st_size for p in output.glob("*.wav"))} bytes')
