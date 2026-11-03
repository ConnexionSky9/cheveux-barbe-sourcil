#!/usr/bin/env python3
"""Synthèse des effets sonores du LaserGame (aucun fichier externe, aucun droit d'auteur) → html/sounds/*.ogg

    python3 tools/assets/make_sounds.py      (depuis elyzea_lasergame/, nécessite numpy et ffmpeg)
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'html', 'sounds')
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=0.1, curve=3.0):
    """Enveloppe attaque linéaire + décroissance exponentielle."""
    x = np.ones(n)
    na = max(1, int(SR * a))
    x[:na] = np.linspace(0, 1, na)
    rest = n - na
    if rest > 0:
        x[na:] = np.exp(-curve * np.linspace(0, 1, rest) * (len(x) / SR) / max(r, 1e-3))
    return x


def sweep(f0, f1, d, shape='exp'):
    tt = t(d)
    if shape == 'exp':
        f = f0 * (f1 / f0) ** (tt / d)
    else:
        f = f0 + (f1 - f0) * tt / d
    return np.sin(2 * np.pi * np.cumsum(f) / SR), f


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, k=8):
    return np.convolve(x, np.ones(k) / k, mode='same')


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out.append(p)
        if gap:
            out.append(np.zeros(int(SR * gap)))
    return np.concatenate(out)


def tone(f, d, wave_='sine', a=0.005, r=0.2, curve=3.0):
    tt = t(d)
    if wave_ == 'square':
        x = np.sign(np.sin(2 * np.pi * f * tt)) * 0.6
    elif wave_ == 'saw':
        x = 2 * (tt * f % 1) - 1
    else:
        x = np.sin(2 * np.pi * f * tt)
    return x * env(len(tt), a, r, curve)


def laser(f0, f1, d, harm=0.35, noise_amt=0.15, curve=4.0):
    s, f = sweep(f0, f1, d)
    s2 = np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR) * harm
    s3 = np.sign(s) * 0.18
    n = lowpass(noise(d), 3) * noise_amt
    return (s + s2 + s3 + n) * env(len(s), 0.002, d * 0.6, curve)


def chord(freqs, d, wave_='sine', r=0.6):
    return mix(*[tone(f, d, wave_, 0.01, r) for f in freqs]) / len(freqs)


def write(name, x, gain=0.85):
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) or 1.0
    x = np.clip(x / peak * gain, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
        path = tmp.name
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    out = os.path.join(OUT, name + '.ogg')
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', path, '-c:a', 'libvorbis', '-q:a', '4', out], check=True)
    os.unlink(path)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    S = {}
    # --- armes
    S['pistol'] = laser(2400, 380, 0.16)
    S['smg'] = laser(3000, 700, 0.09, harm=0.25)
    S['rifle'] = mix(laser(2000, 300, 0.14), tone(90, 0.12, 'sine', 0.002, 0.06) * 0.6)
    S['sniper'] = mix(laser(4200, 120, 0.55, harm=0.5, noise_amt=0.3, curve=2.5), tone(60, 0.5, 'sine', 0.002, 0.25) * 0.9)
    S['heavy'] = mix(laser(1400, 90, 0.35, harm=0.6, noise_amt=0.35, curve=3), lowpass(noise(0.3), 20) * env(int(SR * 0.3), 0.002, 0.08) * 0.8)
    S['blade'] = mix(lowpass(noise(0.25), 2) * env(int(SR * 0.25), 0.03, 0.1) * 0.6, laser(600, 1800, 0.22, harm=0.3))
    S['reload'] = seq(tone(900, 0.05, 'square', 0.001, 0.02) * 0.5, tone(500, 0.05, 'square', 0.001, 0.02) * 0.5,
                      laser(300, 1600, 0.25, 0.2, 0.05, 1.5) * 0.7, gap=0.06)
    # --- impacts et résultats de tir
    S['hit'] = mix(tone(1800, 0.07, 'sine', 0.001, 0.03), tone(2700, 0.05, 'sine', 0.001, 0.02) * 0.5)
    S['kill'] = seq(tone(1300, 0.08, 'square', 0.001, 0.05) * 0.6, chord([1760, 2217, 2637], 0.35, 'sine', 0.25))
    S['hurt'] = mix(lowpass(noise(0.18), 6) * env(int(SR * 0.18), 0.002, 0.05), tone(140, 0.18, 'saw', 0.002, 0.06) * 0.5)
    S['eliminated'] = mix(laser(900, 60, 0.9, harm=0.6, noise_amt=0.4, curve=1.8), tone(55, 0.9, 'sine', 0.01, 0.4) * 0.8)
    # --- partie
    S['countdown'] = tone(880, 0.16, 'square', 0.002, 0.08) * 0.6
    S['go'] = mix(chord([880, 1108, 1318, 1760], 0.6, 'square', 0.35) * 0.6, laser(600, 2400, 0.3, 0.2, 0.05, 2) * 0.4)
    S['round_win'] = seq(*[tone(f, 0.12, 'square', 0.002, 0.08) * 0.5 for f in (659, 784, 988)], chord([1318, 1568, 1976], 0.5, 'sine', 0.3))
    S['round_lose'] = seq(*[tone(f, 0.14, 'square', 0.002, 0.09) * 0.5 for f in (523, 440, 349)], chord([262, 311, 392], 0.6, 'sine', 0.35))
    S['draw'] = seq(tone(660, 0.18, 'square', 0.002, 0.1) * 0.5, tone(660, 0.3, 'square', 0.002, 0.15) * 0.5, gap=0.05)
    S['victory'] = seq(*[chord([f, f * 1.25, f * 1.5], 0.16, 'square', 0.12) * 0.6 for f in (392, 523, 659, 784)],
                       chord([1046, 1318, 1568, 2093], 1.4, 'sine', 0.8), gap=0.02)
    S['defeat'] = seq(*[chord([f, f * 1.2, f * 1.5], 0.28, 'saw', 0.2) * 0.4 for f in (392, 349, 311)], chord([196, 233, 293], 1.4, 'sine', 0.9))
    S['rankup'] = seq(laser(400, 3200, 0.5, 0.3, 0.05, 1.2) * 0.5, chord([1046, 1318, 1568, 2093, 2637], 1.2, 'sine', 0.7))
    S['pad'] = laser(200, 1600, 0.35, 0.4, 0.1, 1.5)
    # --- Zombie
    growl = lowpass(noise(0.7), 30) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t(0.7)))
    S['zombie_hit'] = mix(growl[:int(SR * 0.4)] * env(int(SR * 0.4), 0.01, 0.15), lowpass(noise(0.12), 4) * env(int(SR * 0.12), 0.001, 0.03) * 0.8)
    S['zombie_die'] = mix(growl * env(len(growl), 0.01, 0.3, 2), tone(80, 0.7, 'saw', 0.01, 0.3) * 0.35)
    S['spit'] = mix(lowpass(noise(0.3), 10) * env(int(SR * 0.3), 0.01, 0.12), laser(500, 180, 0.3, 0.3, 0.4, 2) * 0.5)
    S['acid'] = lowpass(noise(1.0), 12) * env(int(SR * 1.0), 0.05, 0.5, 1.5) * (0.7 + 0.3 * np.sin(2 * np.pi * 13 * t(1.0)))
    S['acid_burn'] = mix(lowpass(noise(0.2), 5) * env(int(SR * 0.2), 0.002, 0.06), tone(230, 0.2, 'saw', 0.002, 0.07) * 0.4)
    S['round_start'] = seq(tone(110, 0.5, 'saw', 0.02, 0.3) * 0.6, tone(104, 0.5, 'saw', 0.02, 0.3) * 0.6, chord([55, 82, 110], 1.4, 'saw', 0.9) * 0.6)
    S['round_end'] = seq(chord([220, 277, 330], 0.4, 'sine', 0.25), chord([294, 370, 440], 0.9, 'sine', 0.6), gap=0.05)
    S['buy'] = seq(tone(1568, 0.06, 'square', 0.001, 0.04) * 0.5, tone(2093, 0.12, 'square', 0.001, 0.08) * 0.5)
    S['weapon_buy'] = seq(laser(300, 1200, 0.2, 0.3, 0.05, 2) * 0.6, chord([784, 988, 1175], 0.4, 'square', 0.25) * 0.5)
    S['deny'] = seq(tone(220, 0.1, 'square', 0.002, 0.06) * 0.5, tone(180, 0.18, 'square', 0.002, 0.1) * 0.5, gap=0.03)
    S['door'] = mix(lowpass(noise(1.4), 40) * env(int(SR * 1.4), 0.05, 0.7, 1.2), sweep(160, 40, 1.4)[0] * env(int(SR * 1.4), 0.05, 0.6) * 0.6)
    S['perk'] = seq(*[tone(f, 0.09, 'sine', 0.002, 0.07) for f in (523, 659, 784, 1046)], chord([1046, 1318, 1568], 0.7, 'sine', 0.45))
    S['revive'] = seq(laser(300, 900, 0.3, 0.2, 0.02, 1.5) * 0.6, chord([659, 831, 988], 0.6, 'sine', 0.4))
    S['downed'] = mix(sweep(400, 80, 1.2)[0] * env(int(SR * 1.2), 0.01, 0.6, 1.5), lowpass(noise(1.2), 25) * 0.3 * env(int(SR * 1.2), 0.01, 0.5))
    S['game_over'] = seq(*[chord([f, f * 1.19, f * 1.5], 0.45, 'saw', 0.35) * 0.4 for f in (220, 196, 174)], chord([110, 131, 165], 2.0, 'sine', 1.2))
    # --- interface
    S['click'] = tone(1400, 0.04, 'sine', 0.001, 0.015)
    S['hover'] = tone(2600, 0.025, 'sine', 0.001, 0.01) * 0.4
    S['toast'] = seq(tone(1175, 0.05, 'sine', 0.001, 0.03), tone(1568, 0.08, 'sine', 0.001, 0.05))
    S['open'] = mix(laser(200, 1400, 0.4, 0.2, 0.05, 1.4) * 0.4, chord([523, 784, 1046], 0.5, 'sine', 0.35) * 0.5)
    S['invite'] = seq(*[tone(f, 0.1, 'sine', 0.002, 0.07) for f in (988, 1318, 988, 1318)], gap=0.02)
    S['glitch'] = np.concatenate([tone(rng.integers(300, 3000), 0.018, 'square', 0.001, 0.01) * rng.uniform(0.2, 0.6) for _ in range(9)])
    for name, x in S.items():
        write(name, x)
    print(f'{len(S)} sons générés dans {OUT}')


if __name__ == '__main__':
    main()
