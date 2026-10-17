"""
Écriture de textures DDS compressées (DXT1 / DXT5) AVEC mipmaps, à partir d'un PNG.
Pillow sait encoder un niveau DXT ; on assemble ici tous les niveaux dans un seul fichier
(le jeu a besoin des mipmaps pour un affichage net et sans scintillement à distance).
"""
import io
import struct

from PIL import Image

DDSD_CAPS, DDSD_HEIGHT, DDSD_WIDTH, DDSD_PIXELFORMAT = 0x1, 0x2, 0x4, 0x1000
DDSD_MIPMAPCOUNT, DDSD_LINEARSIZE = 0x20000, 0x80000
DDSCAPS_COMPLEX, DDSCAPS_TEXTURE, DDSCAPS_MIPMAP = 0x8, 0x1000, 0x400000
DDPF_FOURCC = 0x4


def _level_payload(img, fmt):
    buf = io.BytesIO()
    img.save(buf, format='DDS', pixel_format=fmt)
    return buf.getvalue()[128:]   # en-tête DDS standard de 128 octets (pas d'en-tête DX10 pour DXT1/5)


def write_dds(src, dst, fmt='DXT1', min_size=4):
    """src : chemin PNG ou image PIL · fmt : 'DXT1' (opaque) ou 'DXT5' (avec alpha). Renvoie le nombre de mips."""
    img = Image.open(src) if isinstance(src, str) else src
    img = img.convert('RGBA')
    w, h = img.size
    assert w & (w - 1) == 0 and h & (h - 1) == 0, 'dimensions en puissance de 2 requises'
    levels = []
    cur = img
    while True:
        levels.append(_level_payload(cur, fmt))
        if cur.width <= min_size or cur.height <= min_size:
            break
        cur = cur.resize((max(1, cur.width // 2), max(1, cur.height // 2)), Image.LANCZOS)
    flags = DDSD_CAPS | DDSD_HEIGHT | DDSD_WIDTH | DDSD_PIXELFORMAT | DDSD_MIPMAPCOUNT | DDSD_LINEARSIZE
    caps = DDSCAPS_TEXTURE | DDSCAPS_COMPLEX | DDSCAPS_MIPMAP
    header = struct.pack('<4s7I44x', b'DDS ', 124, flags, h, w, len(levels[0]), 0, len(levels))
    pf = struct.pack('<2I4s5I', 32, DDPF_FOURCC, fmt.encode(), 0, 0, 0, 0, 0)
    header += pf + struct.pack('<5I', caps, 0, 0, 0, 0)
    assert len(header) == 128
    with open(dst, 'wb') as fh:
        fh.write(header)
        for lv in levels:
            fh.write(lv)
    return len(levels)


if __name__ == '__main__':
    import sys
    n = write_dds(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else 'DXT1')
    print(f'{sys.argv[2]} : {n} niveaux')
