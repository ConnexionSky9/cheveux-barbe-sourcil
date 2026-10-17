// ElyConvert : CodeWalker XML -> binaires GTA V, puis relecture de contrôle de chaque fichier produit.
// Usage : ElyConvert <dossier_xml> <dossier_sortie>
using System;
using System.IO;
using System.Linq;
using System.Xml;
using CodeWalker.GameFiles;

static class Program
{
    static int Main(string[] args)
    {
        if (args.Length < 2) { Console.WriteLine("Usage : ElyConvert <dossier_xml> <dossier_sortie>"); return 2; }
        string inDir = Path.GetFullPath(args[0]), outDir = Path.GetFullPath(args[1]);
        Directory.CreateDirectory(outDir);
        int ok = 0, fail = 0;
        foreach (var path in Directory.GetFiles(inDir, "*.xml").OrderBy(p => p))
        {
            string file = Path.GetFileName(path);
            string name = file.Substring(0, file.Length - 4);           // ex. ely_bebe_porte_peau3.ydr
            string ext = Path.GetExtension(name).ToLowerInvariant();     // .ydr / .ytd / .ytyp
            MetaFormat fmt;
            switch (ext)
            {
                case ".ydr": fmt = MetaFormat.Ydr; break;
                case ".ytd": fmt = MetaFormat.Ytd; break;
                case ".ytyp": fmt = MetaFormat.RSC; break;
                default: continue;
            }
            try
            {
                var doc = new XmlDocument();
                doc.Load(path);
                // textures : dossier portant le nom du fichier (convention Sollumz / CodeWalker), sinon le dossier XML
                string texDir = Path.Combine(inDir, Path.GetFileNameWithoutExtension(name));
                byte[] data = XmlMeta.GetData(doc, fmt, Directory.Exists(texDir) ? texDir : inDir);
                if (data == null || data.Length == 0) throw new Exception("conversion vide");
                string outPath = Path.Combine(outDir, name);
                File.WriteAllBytes(outPath, data);
                string check = Verify(ext, File.ReadAllBytes(outPath), name);
                Console.WriteLine($"OK    {name,-48} {data.Length,9} octets  {check}");
                ok++;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ECHEC {name} : {ex.Message}");
                fail++;
            }
        }
        Console.WriteLine($"Terminé : {ok} fichier(s) converti(s), {fail} échec(s).");
        return fail == 0 ? 0 : 1;
    }

    static string Ver(PackedFile f) => ((f as GameFile)?.RpfFileEntry as RpfResourceFileEntry)?.Version.ToString() ?? "?";

    // Relit le binaire produit avec le lecteur de CodeWalker et renvoie un résumé de son contenu
    static string Verify(string ext, byte[] data, string name)
    {
        if (ext == ".ydr")
        {
            var y = RpfFile.GetResourceFile<YdrFile>(data);
            var models = y.Drawable?.DrawableModels?.High;
            if (models == null || models.Length == 0) throw new Exception("relecture : aucun modèle");
            int verts = 0, tris = 0;
            foreach (var m in models)
                foreach (var g in m.Geometries)
                { verts += (int)g.VerticesCount; tris += (int)g.IndicesCount / 3; }
            var tex = string.Join(",", y.Drawable.ShaderGroup.Shaders.data_items
                .SelectMany(s => s.ParametersList.Parameters).Where(p => p.Data is TextureBase)
                .Select(p => ((TextureBase)p.Data).Name));
            return $"version {Ver(y)}, {verts} sommets, {tris} triangles, textures [{tex}]";
        }
        if (ext == ".ytd")
        {
            var t = RpfFile.GetResourceFile<YtdFile>(data);
            var list = t.TextureDict.Textures.data_items;
            return $"version {Ver(t)}, {list.Length} textures, mips min {list.Min(x => x.Levels)}";
        }
        var yt = RpfFile.GetResourceFile<YtypFile>(data);
        return $"version {Ver(yt)}, {yt.AllArchetypes.Length} archétypes";
    }
}
