// Génération et contrôle du fxmanifest.lua d'une ressource de vêtements. Module PUR.
// Seules les déclarations réellement nécessaires sont écrites :
//  - remplacement de vêtements du jeu : fx_version + game (les fichiers de stream/ sont
//    diffusés automatiquement par FiveM) ;
//  - collection additionnelle : en plus, files + data_file 'SHOP_PED_APPAREL_META_FILE'.

const luaString = (s) => `'${String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/[\r\n]+/g, ' ')}'`;

export function generateManifest({ fxVersion = 'cerulean', game = 'gta5', name, description = '', version = '1.0.0', dataFiles = [] }) {
  const lines = [
    `fx_version ${luaString(fxVersion)}`,
    `game ${luaString(game)}`,
    '',
    `name ${luaString(name)}`,
    `description ${luaString(description || 'Pack de vêtements')}`,
    `version ${luaString(version)}`,
    `author ${luaString('Généré par FiveM Clothing Studio')}`,
  ];
  if (dataFiles.length) {
    lines.push('', 'files {');
    for (const d of dataFiles) lines.push(`    ${luaString(d.path)},`);
    lines.push('}', '');
    for (const d of dataFiles) lines.push(`data_file ${luaString(d.type)} ${luaString(d.path)}`);
  }
  lines.push('');
  return lines.join('\n');
}

/**
 * Contrôle structurel d'un manifeste : directives connues, chaînes fermées, aucun chemin
 * absolu, et chaque fichier déclaré présent dans `existing` (chemins relatifs « / »).
 */
export function checkManifest(text, existing = new Set()) {
  const problems = [];
  if (!/^fx_version\s+'[a-z]+'/m.test(text)) problems.push('fx_version manquant.');
  if (!/^game\s+'gta5'/m.test(text)) problems.push('game \'gta5\' manquant.');
  const quotes = (text.replace(/\\'/g, '').match(/'/g) || []).length;
  if (quotes % 2) problems.push('Chaîne non fermée.');
  const strings = [...text.matchAll(/'((?:[^'\\]|\\.)*)'/g)].map((m) => m[1]);
  for (const s of strings) {
    if (/^[a-zA-Z]:[\\/]|^\/|^\\\\|\.\.[\\/]/.test(s)) problems.push(`Chemin absolu ou remontant interdit : ${s}`);
  }
  const declared = [];
  const filesBlock = /files\s*\{([^}]*)\}/m.exec(text);
  if (filesBlock) for (const m of filesBlock[1].matchAll(/'([^']+)'/g)) declared.push(m[1]);
  for (const m of text.matchAll(/^data_file\s+'([A-Z_]+)'\s+'([^']+)'/gm)) {
    if (m[1] !== 'SHOP_PED_APPAREL_META_FILE') problems.push(`Type data_file inattendu : ${m[1]}`);
    if (!declared.includes(m[2])) problems.push(`data_file « ${m[2]} » absent du bloc files.`);
    declared.push(m[2]);
  }
  for (const f of new Set(declared)) if (!existing.has(f)) problems.push(`Fichier déclaré mais absent : ${f}`);
  return problems;
}
