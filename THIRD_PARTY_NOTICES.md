# Third-party notices

## Bundled UI font

The generated `achievement_lanapixel` bitmap font uses LanaPixel for its
primary glyphs and Source Han Sans SC only for characters that LanaPixel does
not provide. The source font files are development dependencies and are not
loaded by the game; the mod ships one combined BMFont atlas.

LanaPixel is copyright 2020 eishiya. Source Han Sans SC is copyright
2014-2025 Adobe. Both are available under the SIL Open Font License 1.1; the
license texts are included as `resources/font/LANAPIXEL_OFL.txt` and
`resources/font/OFL.txt`.

## Achievement icons

The bundled achievement icons were retrieved from the English
[The Binding of Isaac: Rebirth Wiki](https://bindingofisaacrebirth.wiki.gg/),
whose wiki content is available under the CC BY-SA 4.0 license. The generated
manifest records the source file page, resolved download URL, DLC revision, and
SHA-256 checksum for each icon.

The Binding of Isaac names, artwork, and related game assets remain the property
of their respective rights holders. Their inclusion here is solely to identify
in-game achievements in this non-commercial game mod.

## Unlock recommendations

The built-in unlock priorities are derived from the `beginner-9.10` profile in
[Momo-Tori/isaac_unlock_planner](https://github.com/Momo-Tori/isaac_unlock_planner)
at commit `fc005d0c608715629e494d93810eedfd05c9fd14`. That project is available under
the MIT License and attributes the underlying beginner recommendations to the
Bilibili sources documented in its own third-party notice. This Mod includes
only the resulting achievement-ID priority mapping; it does not copy the
planner's application code or artwork.
