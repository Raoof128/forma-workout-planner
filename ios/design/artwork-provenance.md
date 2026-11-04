# FORMA native editorial artwork

Since 30 October 2026, the Today hero shows the website's own hero photo
(`public/images/training-hero.webp`, provenance in
`docs/research/site-visuals/training-hero.json`), bundled by
`scripts/build-ios-media.py`. The editorial artwork described below stays
bundled as the fallback for when the media folder is unavailable.

Created 23 October 2026 (Australia/Sydney) for the offline native prototype.

`training-editorial-source.png` (this folder) is an original AI-assisted decorative
asset generated with OpenAI Image Gen in this session. The preserved generation
original is `/workspace/generated_images/exec-9dea972b-2878-4613-821e-1977d0e90bf8.png`.
`training-editorial-source.png` is byte-identical to it (1536x1024, 2,187,502 bytes) and
is no longer bundled. It contains no person or instructional anatomy.
It is not a photograph of a real FORMA facility. No exclusive copyright claim is made.
The path above is a historical session locator; the PNG in this folder is the durable
source copy retained by this repository. Its SHA-256 is
`c7d72e4f25108d22165c9facf105b6ee3643d372631628f85765eadc87d78d9d`.
The full asset checksums and byte sizes are recorded in `asset-checksums.json`
and checked by the native-resource test suite.

The app bundles two derived JPEGs instead, in
`../FORMA/Resources/Assets.xcassets/TrainingEditorial.imageset/`. Today shows the
image in a 112pt strip, scaled to the card's width and aligned to the bottom, so only
the bottom half of the source is ever visible. The derivatives are exactly that half
(bottom 512 rows, full width), resampled down, never up, to 2x and 3x of the widest
card (430pt):

| File | Pixels | Bytes | SHA-256 |
|---|---|---|---|
| `training-editorial@2x.jpg` | 860x287 | 67,188 | `9ab6cb58acc2719d7a43a091fec65e745e675e024d1a67bea63895303a2603da` |
| `training-editorial@3x.jpg` | 1290x430 | 140,420 | `a75aa456b93d67441ecb0917e6060c9b15226c90858ad8b2f75280e476742ab6` |

Reproduce from this folder (macOS `sips` and ImageMagick):

```sh
magick training-editorial-source.png -crop 1536x512+0+512 +repage /tmp/crop.png
sips -z 287 860 -s format jpeg -s formatOptions 80 /tmp/crop.png --out training-editorial@2x.jpg
sips -z 430 1290 -s format jpeg -s formatOptions 80 /tmp/crop.png --out training-editorial@3x.jpg
```

That takes the decoded size from about 6 MiB to about 2.1 MiB at 3x and the bundle
cost from 2.19 MB to 0.21 MB. Because the checksum test counts three records, the
JPEGs are recorded here and not in `asset-checksums.json`.

Brief: empty sculptural concrete training studio in morning light; black steel
barbell on charcoal rubber flooring; quiet graphite negative space at left;
desaturated cinematic material detail and a restrained lime reflection. No text,
logos, people, UI or medical imagery. Text and all controls remain native SwiftUI.

The app icon is a deterministic rasterization of the existing original three-facet
FORMA mark from `src/components/BrandMark.jsx`, on the existing brand lime. No
replacement logo is introduced. Its source vector is `app-icon.svg`.

The iOS icon also ships the two appearances iOS 18 asks for, drawn from the same three
facets with no change to the geometry: `app-icon-dark.png` swaps the brand colours
(lime facets on ink `#202522`) and `app-icon-tinted.png` is white facets on black, the
grayscale the system maps the user's tint onto. SHA-256
`d0bfed90a66d271c626764ae10da29427767954d33746bcaccbb2fb222c22794` (dark, 17,113 bytes) and
`b14360c860318956cea9f1054394290cd712c002e8d2c3faded55a19ebe11d62` (tinted, 13,490 bytes);
as with the JPEGs above they are not in `asset-checksums.json`, but
`build-icon.py --variant dark|tinted --check` reproduces both. The Watch icon is unchanged:
watchOS has no dark or tinted icon appearance. These are recolours chosen by the
implementer; confirm them on a device in Dark and Tinted Home Screen modes.

Reproduce or check the icon with Python 3 and **Pillow 12.3.0**:

```sh
python3 -m pip install Pillow==12.3.0
python3 ios/design/build-icon.py --check
python3 ios/design/build-icon.py --output /tmp/forma-app-icon.png
```

The script reads the SVG's three facets, rasterizes at four times the target
resolution and downsamples with Lanczos. It reproduces the committed 1024 px RGB
PNG byte-for-byte with that dependency version; `--check` writes nothing and
compares pixels. The independently generated temporary copy was also checked
against the committed SHA-256
`b006d525853e8752c0d1a3688b0658fe37ca01ff2c9799a0efd28d159d13bb55`.
An intentional future vector/asset change must update the checksum record and
receive a new visual review. The icon PNG was not changed by this tooling pass.

This asset review does not establish App Store approval, trademark clearance,
exercise safety or native rendering quality. Review the real binary before release.
