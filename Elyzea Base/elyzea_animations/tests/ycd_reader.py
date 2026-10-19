#!/usr/bin/env python3
"""Lecteur minimal de fichiers d'animation GTA V (.ycd), porté de CodeWalker (CodeWalker.Core/GameFiles/Resources/Clip.cs).

Sert à vérifier, hors jeu, l'orientation et la position réelles des personnages dans une animation :
piste « position » (0) et « rotation » (1) de chaque os, piste « mover » (5 et 6) pour le déplacement racine.

Usage : python3 tests/ycd_reader.py fichier.ycd [os ...]
"""
import math
import struct
import sys
import zlib

SKEL_ROOT, SKEL_PELVIS, SKEL_HEAD, SKEL_L_HAND, SKEL_R_HAND, SKEL_SPINE3 = 0, 11816, 31086, 18905, 57005, 24818


class Rsc:
    def __init__(self, raw):
        magic, version, sflags, gflags = struct.unpack_from('<4sIII', raw, 0)
        if magic != b'RSC7':
            raise ValueError('pas un fichier RSC7')
        self.data = zlib.decompress(raw[16:], -15)
        self.system_size = self.size_from_flags(sflags)

    @staticmethod
    def size_from_flags(flags):
        s = (((flags >> 27) & 1) << 0) + (((flags >> 26) & 1) << 1) + (((flags >> 25) & 1) << 2) + (((flags >> 24) & 1) << 3) \
            + (((flags >> 17) & 0x7F) << 4) + (((flags >> 11) & 0x3F) << 5) + (((flags >> 7) & 0xF) << 6) \
            + (((flags >> 5) & 0x3) << 7) + (((flags >> 4) & 1) << 8)
        return (0x200 << (flags & 0xF)) * s

    def off(self, ptr):
        if ptr == 0:
            return None
        if (ptr & 0xF0000000) == 0x50000000:
            return ptr & 0x0FFFFFFF
        if (ptr & 0xF0000000) == 0x60000000:
            return self.system_size + (ptr & 0x0FFFFFFF)
        raise ValueError('pointeur inconnu %x' % ptr)

    def u16(self, o): return struct.unpack_from('<H', self.data, o)[0]
    def u32(self, o): return struct.unpack_from('<I', self.data, o)[0]
    def u64(self, o): return struct.unpack_from('<Q', self.data, o)[0]
    def f32(self, o): return struct.unpack_from('<f', self.data, o)[0]


class ChannelReader:
    def __init__(self, data, num_frames, chunk_size, frame_offset, frame_length):
        self.data, self.num_frames, self.chunk_size = data, num_frames, chunk_size
        self.frame_offset, self.frame_length = frame_offset, frame_length
        self.pos = 0
        self.frame = 0
        self.list_off = frame_offset + frame_length * num_frames
        self.data_off = self.list_off + 18
        self.frame_bit = 0
        self.bit = 0

    def i32(self):
        v = struct.unpack_from('<i', self.data, self.pos)[0]; self.pos += 4; return v

    def f32(self):
        v = struct.unpack_from('<f', self.data, self.pos)[0]; self.pos += 4; return v

    def vec3(self):
        v = struct.unpack_from('<fff', self.data, self.pos); self.pos += 12; return v

    def get_bits(self, start, length):
        if start < 0 or length <= 0:
            return 0
        result, shift, cur, rem = 0, -(start % 8), start // 8, length
        while rem > 0:
            b = self.data[cur] if cur < len(self.data) else 0
            cur += 1
            sb = (b >> -shift) if shift < 0 else (b << shift)
            bm = ((1 << min(rem, 8)) - 1) << max(shift, 0)
            result += sb & bm
            rem -= 8 + min(shift, 0)
            shift += 8
        return result

    def read_bits(self, n):
        v = self.get_bits(self.bit, n); self.bit += n; return v

    def channel_count(self):
        v = struct.unpack_from('<H', self.data, self.list_off)[0]; self.list_off += 2; return v

    def channel_bits(self):
        v = struct.unpack_from('<H', self.data, self.data_off)[0]; self.data_off += 2; return v

    def align(self, count):
        if count % 4:
            self.data_off += (4 - count % 4) * 2

    def begin_frame(self, f):
        self.frame = f
        self.frame_bit = (self.frame_offset + self.frame_length * f) * 8

    def frame_bits(self, n):
        v = self.get_bits(self.frame_bit, n); self.frame_bit += n; return v


class Channel:
    def __init__(self, ctype): self.type, self.values, self.const = ctype, None, None
    def read(self, r): pass
    def read_frame(self, r): pass
    def frame_bits(self): return 0
    def value(self, f):
        if self.values:
            return self.values[f % len(self.values)]
        return self.const if self.const is not None else 0.0


class StaticQuat(Channel):
    def read(self, r):
        x, y, z = r.vec3()
        self.vec = (x, y, z, math.sqrt(max(1 - (x * x + y * y + z * z), 0)))


class StaticVec3(Channel):
    def read(self, r): self.vec = r.vec3()


class StaticFloat(Channel):
    def read(self, r): self.const = r.f32()


class RawFloat(Channel):
    def read(self, r): self.values = [0.0] * r.num_frames
    def read_frame(self, r): self.values[r.frame] = struct.unpack('<f', struct.pack('<I', r.frame_bits(32)))[0]
    def frame_bits(self): return 32


class QuantizeFloat(Channel):
    def read(self, r):
        self.bits, self.quantum, self.offset = r.i32(), r.f32(), r.f32()
        self.values = [0.0] * r.num_frames
    def read_frame(self, r): self.values[r.frame] = r.frame_bits(self.bits) * self.quantum + self.offset
    def frame_bits(self): return self.bits


class IndirectQuantizeFloat(Channel):
    def read(self, r):
        self.fbits, vbits, nints, quantum, offset = r.i32(), r.i32(), r.i32(), r.f32(), r.f32()
        n = min((nints * 32) // vbits, (1 << self.fbits) - 1)
        r.bit = r.pos * 8
        self.table = [r.read_bits(vbits) * quantum + offset for _ in range(n)]
        r.pos += nints * 4
        self.frames = [0] * r.num_frames
        self.const = offset
    def read_frame(self, r): self.frames[r.frame] = r.frame_bits(self.fbits)
    def frame_bits(self): return self.fbits
    def value(self, f): return self.table[self.frames[f % len(self.frames)]] if self.frames else self.const


class LinearFloat(Channel):
    def read(self, r):
        nints, counts, quantum, offset = r.i32(), r.i32(), r.f32(), r.f32()
        bit = r.pos * 8
        c1, c2, c3 = counts & 0xFF, (counts >> 8) & 0xFF, (counts >> 16) & 0xFF
        stream_len = len(r.data) * 8
        nf, cs = r.num_frames, r.chunk_size
        nchunks = (cs + nf - 1) // cs
        delta_off = bit + nchunks * (c1 + c2)
        r.bit = bit
        offs = [r.read_bits(c1) if c1 else 0 for _ in range(nchunks)]
        vals = [r.read_bits(c2) if c2 else 0 for _ in range(nchunks)]
        out = [0.0] * nf
        for i in range(nchunks):
            r.bit = offs[i] + delta_off
            value, inc = vals[i], 0
            for j in range(cs):
                frame = i * cs + j
                if frame >= nf:
                    break
                out[frame] = value * quantum + offset
                if j + 1 >= cs:
                    break
                delta = r.read_bits(c3) if c3 else 0
                so = r.bit
                b = 0
                while b == 0:
                    b = r.read_bits(1)
                    if r.bit >= stream_len:
                        break
                delta |= (r.bit - so - 1) << c3
                if delta != 0 and r.read_bits(1) == 1:
                    delta = -delta
                inc += delta
                value += inc
        self.values = out
        r.pos += nints * 4 - 16 + 16   # même déplacement que CodeWalker (Position -= 16 ; += NumInts*4)
        r.pos -= 16


class CachedQuat(Channel):
    pass


TYPES = [StaticQuat, StaticVec3, StaticFloat, RawFloat, QuantizeFloat, IndirectQuantizeFloat, LinearFloat, CachedQuat, CachedQuat]


def parse_sequence(rsc, off):
    num_frames = rsc.u16(off + 0x16)
    frame_length = rsc.u16(off + 0x18)
    chunk_size = rsc.data[off + 0x1E]
    data_len = rsc.u32(off + 4)
    frame_offset = rsc.u32(off + 0x0C)
    data = rsc.data[off + 32: off + 32 + data_len]
    r = ChannelReader(data, num_frames, chunk_size, frame_offset, frame_length)
    lists, items = [], []
    for t in range(9):
        count = r.channel_count()
        chans = []
        for _ in range(count):
            ch = TYPES[t](t)
            bits = r.channel_bits()
            ch.read(r)
            seq, idx = bits >> 2, bits & 3
            if t in (7, 8):
                ch.quat_index = idx
                idx = 3 if t == 7 else 4
            items.append((seq, idx, ch))
            chans.append(ch)
        r.align(count)
        lists.append(chans)
    for f in range(num_frames):
        r.begin_frame(f)
        for chans in lists:
            for ch in chans:
                ch.read_frame(r)
    nseq = max(s for s, _, _ in items) + 1
    tracks = []
    for s in range(nseq):
        these = [(i, c) for ss, i, c in items if ss == s]
        if not these:
            tracks.append([])
            continue
        arr = [None] * (max(i for i, _ in these) + 1)
        for i, c in these:
            arr[i] = c
        tracks.append(arr)
    return num_frames, tracks


def evaluate(chans, f):
    """Valeur (x, y, z, w) d'une piste à l'image f, comme AnimSequence.EvaluateVector de CodeWalker."""
    if not chans:
        return (0, 0, 0, 0)
    cached = next((c for c in chans if isinstance(c, CachedQuat)), None)
    if cached is not None:
        x, y, z = chans[0].value(f), chans[1].value(f), chans[2].value(f)
        w = math.sqrt(max(1 - (x * x + y * y + z * z), 0))
        q = [x, y, z]
        q.insert(cached.quat_index, w)
        return tuple(q)
    v = []
    for c in chans:
        if c is None:
            v.append(0.0)
        elif isinstance(c, StaticVec3):
            v.extend(c.vec)
        elif isinstance(c, StaticQuat):
            v.extend(c.vec)
        else:
            v.append(c.value(f))
        if len(v) >= 4:
            break
    return tuple((v + [0, 0, 0, 0])[:4])


def read_ycd(path):
    rsc = Rsc(open(path, 'rb').read())
    amap = rsc.off(rsc.u64(0x18))
    arr, cap = rsc.off(rsc.u64(amap + 0x18)), rsc.u16(amap + 0x20)
    anims = []
    for i in range(cap):
        e = rsc.off(rsc.u64(arr + i * 8))
        while e is not None:
            a = rsc.off(rsc.u64(e + 8))
            anims.append((rsc.u32(e), a))
            e = rsc.off(rsc.u64(e + 16))
    result = []
    for h, a in anims:
        frames, limit, duration = rsc.u16(a + 0x14), rsc.u16(a + 0x16), rsc.f32(a + 0x18)
        seq_ptr, seq_count = rsc.off(rsc.u64(a + 0x40)), rsc.u16(a + 0x48)
        bone_ptr, bone_count = rsc.off(rsc.u64(a + 0x50)), rsc.u16(a + 0x58)
        bones = [(rsc.u16(bone_ptr + i * 4), rsc.data[bone_ptr + i * 4 + 3]) for i in range(bone_count)]
        chunks = [parse_sequence(rsc, rsc.off(rsc.u64(seq_ptr + i * 8))) for i in range(seq_count)]
        result.append({'hash': h, 'frames': frames, 'limit': limit, 'duration': duration, 'bones': bones, 'chunks': chunks})
    return result


def track(anim, bone, trk, frame):
    """Valeur d'une piste (os, n° de piste) à une image de l'animation, ou None si absente."""
    try:
        i = anim['bones'].index((bone, trk))
    except ValueError:
        return None
    c = frame // anim['limit']
    nf, tracks = anim['chunks'][min(c, len(anim['chunks']) - 1)]
    chans = tracks[i] if i < len(tracks) else []
    return evaluate(chans, frame % anim['limit'])


def yaw_deg(q):
    """Lacet (rotation autour de Z) d'un quaternion (x, y, z, w), en degrés."""
    x, y, z, w = q
    return math.degrees(math.atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z)))


if __name__ == '__main__':
    for anim in read_ycd(sys.argv[1]):
        print('animation %08x : %d images, %.2f s, %d pistes' % (anim['hash'], anim['frames'], anim['duration'], len(anim['bones'])))
        for bone, name in [(SKEL_ROOT, 'SKEL_ROOT'), (SKEL_PELVIS, 'PELVIS'), (SKEL_HEAD, 'HEAD')]:
            for t in (0, 1, 5, 6):
                v = track(anim, bone, t, 0)
                if v is not None:
                    extra = ('  lacet %.1f°' % yaw_deg(v)) if t in (1, 6) else ''
                    print('  %-9s piste %d image 0 : %s%s' % (name, t, tuple(round(x, 3) for x in v), extra))
