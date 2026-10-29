import wave
import struct
import math
import random
import os

sample_rate = 44100

def write_wav(filename, samples):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sample_rate)
        packed = b''.join([struct.pack('<h', max(-32767, min(32767, int(s * 32767.0)))) for s in samples])
        w.writeframes(packed)
    print(f"Generated: {filename} ({len(samples)} samples)")

# 1. Flesh Impact (Visceral body hit / bullet impact)
def generate_flesh_impact():
    duration = 0.22
    total_samples = int(duration * sample_rate)
    samples = []
    for i in range(total_samples):
        t = i / sample_rate
        # Low frequency punch
        freq = 150.0 * math.exp(-t * 28.0) + 40.0
        thud = math.sin(2.0 * math.pi * freq * t) * math.exp(-t * 22.0)
        
        # Crunchy flesh/fabric impact noise
        noise = (random.random() * 2.0 - 1.0) * math.exp(-t * 45.0)
        # Wet slap slapback
        slap = math.sin(2.0 * math.pi * 320.0 * t) * math.exp(-t * 60.0) * 0.4
        
        sample = (thud * 0.75 + noise * 0.35 + slap * 0.25)
        # Envelope limiter
        sample = math.tanh(sample * 1.4)
        samples.append(sample)
    return samples

# 2. Soldier Hurt Grunt
def generate_soldier_grunt():
    duration = 0.26
    total_samples = int(duration * sample_rate)
    samples = []
    for i in range(total_samples):
        t = i / sample_rate
        env = math.sin(math.pi * (t / duration)) ** 1.5
        # Pitch drops from 145Hz to 85Hz
        pitch = 145.0 - (t / duration) * 60.0
        # Formants
        vocal = (math.sin(2.0 * math.pi * pitch * t) * 0.6 +
                 math.sin(2.0 * math.pi * (pitch * 2.0) * t) * 0.3 +
                 math.sin(2.0 * math.pi * (pitch * 3.2) * t) * 0.15)
        # Throat breath noise
        breath = (random.random() * 2.0 - 1.0) * 0.2 * math.exp(-t * 8.0)
        sample = (vocal + breath) * env * 0.75
        samples.append(sample)
    return samples

# 3. Heartbeat (Double pulse: Lub-Dub)
def generate_heartbeat():
    duration = 0.85
    total_samples = int(duration * sample_rate)
    samples = []
    for i in range(total_samples):
        t = i / sample_rate
        val = 0.0
        
        # Lub pulse (at 0.04s)
        if 0.02 <= t <= 0.22:
            pt = t - 0.02
            env = math.sin(math.pi * (pt / 0.20))
            f = 58.0 - pt * 60.0
            val += math.sin(2.0 * math.pi * f * pt) * env * 0.85
            
        # Dub pulse (at 0.26s)
        if 0.24 <= t <= 0.42:
            pt = t - 0.24
            env = math.sin(math.pi * (pt / 0.18))
            f = 68.0 - pt * 70.0
            val += math.sin(2.0 * math.pi * f * pt) * env * 0.95
            
        samples.append(math.tanh(val))
    return samples

if __name__ == '__main__':
    write_wav("assets/audio/foley/flesh_impact.wav", generate_flesh_impact())
    write_wav("assets/audio/foley/soldier_grunt.wav", generate_soldier_grunt())
    write_wav("assets/audio/foley/heartbeat.wav", generate_heartbeat())
