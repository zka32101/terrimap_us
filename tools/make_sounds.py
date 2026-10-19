#!/usr/bin/env python3
"""効果音とBGMを合成して assets/sound/ に書く（すべて自作の音。外部素材なし）。"""
import math, struct, wave, os, sys
SR = 16000
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'assets', 'sound')
os.makedirs(out, exist_ok=True)

def tone(freq, dur, vol=0.5, shape='sine', attack=0.01, release=0.08):
    n = int(SR * dur); s = []
    for i in range(n):
        t = i / SR
        ph = 2 * math.pi * freq * t
        v = math.sin(ph) if shape == 'sine' else (1 if math.sin(ph) >= 0 else -1) * 0.5 if shape == 'square' else math.sin(ph) + 0.3 * math.sin(2 * ph)
        env = min(1, t / attack) * min(1, (dur - t) / release)
        s.append(v * env * vol)
    return s

def write(name, samples):
    with wave.open(os.path.join(out, name), 'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 32000)) for x in samples))

N = {'C4': 261.63, 'E4': 329.63, 'G4': 392.0, 'A4': 440.0, 'C5': 523.25, 'E5': 659.25, 'G5': 783.99, 'D4': 293.66, 'F4': 349.23, 'B3': 246.94, 'A3': 220.0}
write('correct.wav', tone(N['E5'], 0.09, 0.45) + tone(N['G5'], 0.16, 0.45))
write('wrong.wav', tone(150, 0.22, 0.4, 'square', release=0.1))
write('tap.wav', tone(660, 0.04, 0.3, release=0.03))
write('clear.wav', sum([tone(f, 0.12, 0.45) for f in (N['C5'], N['E5'], N['G5'])], []) + tone(1046.5, 0.4, 0.45, release=0.25))
write('lose.wav', sum([tone(f, 0.2, 0.4, 'saw') for f in (N['A4'], N['F4'], N['D4'])], []) + tone(N['A3'], 0.4, 0.4, 'saw', release=0.25))
# BGM: 4和音を8拍ずつ、やわらかいアルペジオ（約12秒でループ）
chords = [('C4', 'E4', 'G4'), ('A3', 'C4', 'E4'), ('F4', 'A4', 'C5'), ('G4', 'B3', 'D4')]
bgm = []
for c in chords:
    for _ in range(2):
        for k in (0, 1, 2, 1):
            bgm += tone(N[c[k]], 0.375, 0.22, release=0.12)
write('bgm.wav', bgm)

# ボス戦のBGM: 短調で少し速い（約9.6秒でループ）
boss = []
for c in [('A3', 'C4', 'E4'), ('A3', 'C4', 'E4'), ('F4', 'A4', 'C5'), ('G4', 'B3', 'D4')]:
    for _ in range(2):
        for k in (0, 2, 1, 2):
            boss += tone(N[c[k]], 0.3, 0.24, 'saw', release=0.1)
write('boss.wav', boss)
