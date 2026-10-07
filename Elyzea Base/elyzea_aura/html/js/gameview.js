'use strict';
/* =========================================================
   GAMEVIEW — image du jeu en direct dans un <canvas>
   Technique officielle CitizenFX (utilisée par screenshot-basic) :
   une texture WebGL « accrochée » au rendu du jeu.
   ========================================================= */
const GameView = (() => {
  const VS = `attribute vec2 a_position; attribute vec2 a_texcoord; varying vec2 v_tex;
    void main() { gl_Position = vec4(a_position, 0.0, 1.0); v_tex = a_texcoord; }`;
  const FS = `varying highp vec2 v_tex; uniform sampler2D external_texture; uniform bool u_flip;
    void main() { highp vec2 c = u_flip ? vec2(v_tex.x, 1.0 - v_tex.y) : v_tex; gl_FragColor = texture2D(external_texture, c); }`;

  let canvas, gl, raf, running = false, fallbackT = 0;

  function shader(type, src) {
    const s = gl.createShader(type);
    gl.shaderSource(s, src); gl.compileShader(s);
    return s;
  }
  function hookTexture() {
    const tex = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 255]));
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    // Séquence « magique » qui relie la texture au rendu du jeu dans FiveM
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.MIRRORED_REPEAT);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
    gl.texParameterf(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    return tex;
  }
  function init(flipY) {
    canvas = document.createElement('canvas');
    canvas.width = window.innerWidth || 1920;
    canvas.height = window.innerHeight || 1080;
    if (IS_BROWSER) return canvas; // aperçu navigateur : image de démonstration
    gl = canvas.getContext('webgl', { antialias: false, depth: false, stencil: false, alpha: false, preserveDrawingBuffer: true, desynchronized: true });
    hookTexture();
    const prog = gl.createProgram();
    gl.attachShader(prog, shader(gl.VERTEX_SHADER, VS));
    gl.attachShader(prog, shader(gl.FRAGMENT_SHADER, FS));
    gl.linkProgram(prog); gl.useProgram(prog);
    gl.uniform1i(gl.getUniformLocation(prog, 'u_flip'), flipY ? 1 : 0);
    const vb = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, vb);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
    const vl = gl.getAttribLocation(prog, 'a_position');
    gl.vertexAttribPointer(vl, 2, gl.FLOAT, false, 0, 0); gl.enableVertexAttribArray(vl);
    const tb = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, tb);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([0, 0, 1, 0, 0, 1, 1, 1]), gl.STATIC_DRAW);
    const tl = gl.getAttribLocation(prog, 'a_texcoord');
    gl.vertexAttribPointer(tl, 2, gl.FLOAT, false, 0, 0); gl.enableVertexAttribArray(tl);
    gl.viewport(0, 0, canvas.width, canvas.height);
    return canvas;
  }
  function drawFallback() {
    const c = canvas.getContext('2d'), w = canvas.width, h = canvas.height;
    fallbackT += 0.008;
    const g = c.createLinearGradient(0, 0, w, h);
    g.addColorStop(0, `hsl(${(fallbackT * 40) % 360}, 55%, 42%)`);
    g.addColorStop(1, `hsl(${(fallbackT * 40 + 120) % 360}, 60%, 22%)`);
    c.fillStyle = g; c.fillRect(0, 0, w, h);
    c.fillStyle = 'rgba(255,255,255,.12)';
    for (let i = 0; i < 6; i++) { c.beginPath(); c.arc(w * (0.2 + i * 0.13), h * (0.5 + Math.sin(fallbackT * 2 + i) * 0.2), h * 0.08, 0, Math.PI * 2); c.fill(); }
  }
  function loop() {
    if (!running) return;
    if (gl) { gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4); } else drawFallback();
    raf = requestAnimationFrame(loop);
  }
  return {
    start(flipY) { if (!canvas) init(flipY); running = true; loop(); return canvas; },
    stop() { running = false; cancelAnimationFrame(raf); },
    get canvas() { return canvas; },
  };
})();

// Recadre l'image du jeu au format du viseur (portrait)
function cropRect(src, aspect) {
  const h = src.height, w = Math.min(src.width, Math.round(h * aspect));
  return { sx: Math.round((src.width - w) / 2), sy: 0, w, h };
}
