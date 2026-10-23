# FORMA native editorial artwork

Created 23 October 2026 (Australia/Sydney) for the offline native prototype.

`../FORMA/Resources/Assets.xcassets/TrainingEditorial.imageset/training-editorial.png`
is an original AI-assisted decorative asset generated with OpenAI Image Gen in
this session. The preserved generation original is
`/workspace/generated_images/exec-9dea972b-2878-4613-821e-1977d0e90bf8.png`.
The bundled copy is byte-identical. It contains no person or instructional anatomy.
It is not a photograph of a real FORMA facility. No exclusive copyright claim is made.
The path above is a historical session locator; the bundled PNG is the durable
source copy retained by this repository. Its SHA-256 is
`c7d72e4f25108d22165c9facf105b6ee3643d372631628f85765eadc87d78d9d`.
The full asset checksums and byte sizes are recorded in `asset-checksums.json`
and checked by the native-resource test suite.

Brief: empty sculptural concrete training studio in morning light; black steel
barbell on charcoal rubber flooring; quiet graphite negative space at left;
desaturated cinematic material detail and a restrained lime reflection. No text,
logos, people, UI or medical imagery. Text and all controls remain native SwiftUI.

The app icon is a deterministic rasterization of the existing original three-facet
FORMA mark from `src/components/BrandMark.jsx`, on the existing brand lime. No
replacement logo is introduced. Its source vector is `app-icon.svg`.

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
receive a new visual review. Neither bundled PNG was changed by this tooling pass.

This asset review does not establish App Store approval, trademark clearance,
exercise safety or native rendering quality. Review the real binary before release.
