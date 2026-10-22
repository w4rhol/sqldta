# Hex stickers for Stata packages

How the sqldta hex sticker is built, and the rules that give stickers for other Stata packages by the same author one frame, palette and type. The sticker uses the common hex sticker format of R packages; Stata has no equivalent convention.

| File | Holds |
|---|---|
| `images/logo.svg` | The master artwork, with the name converted to outlines so that it renders the same on any machine. Use it for print and wherever a scalable logo is needed. |
| `images/logo.png` | The README image, a 240 × 278 px export of `logo.svg`. The README shows it at 139 px high, so that it stays sharp on high-density screens. |
| `images/hex-sticker-template.svg` | The same artwork with the name as live text and a hidden group of placement guides, as the starting point for another package's sticker. |

`net install` installs only the files that `src/sqldta.pkg` lists, so none of these is installed with the package.

## Frame

The sticker is a hexagon with a point at the top, 50.8 mm (2 in) from point to point and 43.99 mm across the flats, the common size for hex stickers. The SVG unit is the millimetre (`viewBox="0 0 43.994 50.8"`), so every coordinate in the files is a distance on the printed sticker, measured from the top left.

The 1.5 mm border is a hexagon in the border colour with the background hexagon drawn over it, inset 1.5 mm from each edge. It is not a stroke, because an SVG stroke is centred on its path and would extend beyond the cut line. All artwork stays at least 1 mm inside the border, which is 2.5 mm inside the cut line; the template's `keepout` guide marks that line. If a printer asks for bleed, enlarge the `border` hexagon.

## Colours

Every colour is one of Stata's named colours, with the RGB values Stata defines for it, from two graph schemes: s2color, Stata's default from version 8 to 17, and stcolor, its default from version 18. Stata users know these colours from their own graphs. The sticker uses no StataCorp or Microsoft logo, wordmark or product name.

| Element | SVG id | Stata colour | Hex |
|---|---|---|---|
| Border | `border` | stc1 (stblue) | `#1A85FF` |
| Background | `background` | navy | `#1A476F` |
| Name | `name` | white | `#FFFFFF` |
| Prompt | `prompt` | stc4 (styellow) | `#FFD400` |
| Cylinder body and outline | `body`, `outline` | white | `#FFFFFF` |
| Cylinder lid | `lid` | ltbluishgray | `#EAF2F3` |
| Band of column names | `header` | bluishgray | `#D9E6EB` |
| Column names and brackets | `names` | navy | `#1A476F` |
| Grid lines | `grid` | edkbg | `#B2BFCB` |
| Numbers | `numbers` | stc13 | `#08234C` |
| Value labels | `labels` | stc1 (stblue) | `#1A85FF` |
| Strings | `strings` | stc2 (stred) | `#D41159` |

The frame, name and prompt colours are the same on every package's sticker. A motif for another package uses colours from this table.

## Type

The name is the command as a user types it at Stata's prompt: a full stop, which is Stata's prompt, then the package name. It is not set in the lettering of Stata's logo, which belongs to StataCorp, so that the sticker does not suggest that the package is a StataCorp product.

The name is set in IBM Plex Mono Bold (weight 700), a monospaced face under the SIL Open Font Licence, at a font size of 6.0 mm (17.0 pt), with its baseline at y = 40.0. The gap after the prompt is 0.25 em (1.5 mm at 6.0 mm), narrower than a full space so that the prompt and the name read as one command; the template sets it with `word-spacing="-2.1"`, which is -0.35 times the font size. The prompt and the name are centred together on the vertical centre line (x = 21.997) by their advance widths. The outlines in `logo.svg` were made from the `@fontsource/ibm-plex-mono` 5.3.0 font files, shaped with HarfBuzz. Rendered in Chromium with the same font, the template's live text matches them to within 0.05 mm.

A name of up to six characters fits at 6.0 mm; with its prompt, "sqldta" is 25.4 mm wide and comes no closer than 1.3 mm to the border. A longer name keeps the same baseline at a smaller size, so that it stays 1 mm inside the border:

| Characters in the name | Font size (mm) |
|---|---|
| 6 or fewer | 6.0 |
| 7 | 5.4 |
| 8 | 4.8 |
| 9 | 4.3 |
| 10 | 4.0 |

The sizes assume no descender at either end of the name. Check a name that starts or ends with g, j, p, q or y against the `keepout` guide.

## Motif

The motif shows what sqldta does: it is a database cylinder, the common symbol for a database such as SQL Server, whose body is a Stata dataset. The band under the lid holds three column names, each in square brackets, as T-SQL quotes an identifier and as sqldta writes every column name in its queries. Each name is a single solid block, because a Stata variable name cannot contain a space. Below it are four rows of values in the Data Editor's default colours, which show numbers in black, value labels in blue and strings in red. Each value is drawn as a monospaced font would set it, with one block for each character, so that the values read as text rather than as bars. A space is an empty character, and a decimal point is a square dot at the foot of its character's place. The numbers are aligned right and each has one decimal place, so their decimal points line up down the column, as in a column with a fixed format such as `%9.1f`; the labels and strings are aligned left. The blocks do not represent any data.

The cylinder is centred on x = 21.997 with a radius of 9.6 mm. Its lid is an ellipse with a vertical radius of 2.88 mm centred at y = 10.0, and its base is the front half of the same ellipse centred at y = 28.62. The band of column names is 3.46 mm deep and the four rows below it are 3.79 mm each. The three columns are of equal width on the page, 6.4 mm. Each row line and each row of values follows the front half of the ellipse at its own level, which gives the curve of the cylinder, and the column lines are vertical. The character blocks and the column-name blocks are 1.0 mm deep, with square ends. They are filled shapes rather than strokes: their top and bottom edges follow the front half of the ellipse, and their ends are vertical, like the column lines. The character blocks are 0.64 mm wide at a pitch of 0.86 mm, which are the proportions of IBM Plex Mono, the font of the name, when its capitals are as tall as the blocks; a value has at most six characters. The dot of a decimal point is 0.3 mm square, centred in the width of a character's block. Values are aligned to edges 0.6 mm inside the centres of the column lines and the outline. The column-name blocks are 1.8, 2.4 and 1.8 mm long, and each ends 0.45 mm short of its brackets. The brackets are filled shapes too, 2.8 mm tall and 1.1 mm wide, with a stem and serifs 0.5 mm thick: the stem is vertical, the top and bottom edges of the serifs follow the front half of the ellipse, and the inner ends of the serifs are vertical. The outline is 0.7 mm and the grid lines 0.3 mm. The motif comes no closer than 1.4 mm to the border.

## A motif for another package

A motif for another package replaces the contents of the `motif` group. It lies between y = 5.5 and y = 32.5 (the template's `motif-top` and `motif-bottom` guides), centred on the vertical centre line and inside the `keepout` guide. It is drawn flat, with no gradients, shadows or text: light shapes on the navy background, with details in the colours above, lines of 0.3 mm or 0.7 mm, and blocks 1.0 mm deep with square ends. Elements of this motif can be reused, such as the cylinder for another package that reads from a database.

## Making a sticker for another package

Start from a copy of `hex-sticker-template.svg`. Each part is a group or element with an id (`frame`, `motif`, `name`, `prompt` and `guides`), so it can be selected as a unit in Inkscape or Illustrator, or found by its id when the file is edited as text.

Replace the contents of the `motif` group with the new motif. In the `name` element, change the text after the prompt and leave the prompt as it is. With IBM Plex Mono installed (Google Fonts, SIL Open Font Licence), the template shows the name in the sticker's type; without it, the name is drawn in another monospaced font, whose width differs. Set the font size from the table above and `word-spacing` to -0.35 times the font size.

To check placement, show the hidden `guides` group (in Inkscape, Object > Layers and Objects), then delete it. Convert the name to outlines (Inkscape: Path > Object to Path; Illustrator: Type > Create Outlines) and save the result as `images/logo.svg` in the package's repository.

Export `images/logo.png` from it at 240 × 278 px, for example in R with `rsvg::rsvg_png("images/logo.svg", "images/logo.png", width = 240, height = 278)`, and show it on the README's title line at half its height, as this package does:

```markdown
# sqldta <img src="images/logo.png" align="right" height="139" alt="" />
```
