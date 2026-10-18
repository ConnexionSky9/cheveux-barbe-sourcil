// Image RGBA 8 bits non prémultipliée. Module PUR (aucune API Node) : il est utilisé
// à la fois par le processus principal et par l'éditeur de textures (navigateur).

export class RGBAImage {
  constructor(width, height, data) {
    if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0) {
      throw new ImageError(`Dimensions invalides : ${width} × ${height}`);
    }
    if (width * height > 8192 * 8192) throw new ImageError('Image trop grande (maximum 8192 × 8192).');
    this.width = width;
    this.height = height;
    this.data = new Uint8ClampedArray(width * height * 4);
    if (data) {
      if (data.length !== this.data.length) throw new ImageError('Taille des données incohérente.');
      this.data.set(data);
    }
  }

  /** Enveloppe un tableau existant SANS copie (Uint8ClampedArray de la bonne taille). */
  static wrap(width, height, data) {
    const img = Object.create(RGBAImage.prototype);
    if (!(data instanceof Uint8ClampedArray) || data.length !== width * height * 4) throw new ImageError('Données invalides.');
    img.width = width; img.height = height; img.data = data;
    return img;
  }

  static filled(width, height, [r, g, b, a = 255]) {
    const img = new RGBAImage(width, height);
    const d = img.data;
    for (let i = 0; i < d.length; i += 4) { d[i] = r; d[i + 1] = g; d[i + 2] = b; d[i + 3] = a; }
    return img;
  }

  clone() { return new RGBAImage(this.width, this.height, this.data); }

  /** Vrai si au moins un pixel n'est pas totalement opaque. */
  hasAlpha() {
    const d = this.data;
    for (let i = 3; i < d.length; i += 4) if (d[i] !== 255) return true;
    return false;
  }

  get(x, y) { const i = (y * this.width + x) * 4; return [this.data[i], this.data[i + 1], this.data[i + 2], this.data[i + 3]]; }
}

export class ImageError extends Error {
  constructor(msg) { super(msg); this.name = 'ImageError'; this.code = 'E_IMAGE'; }
}

export const isPowerOfTwo = (n) => n > 0 && (n & (n - 1)) === 0;
