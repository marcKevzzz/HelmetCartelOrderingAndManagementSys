"""Create smaller catalog JPEGs from an exported array of MainImageUrl values.
Usage: python database/setup/Build-CatalogThumbnails.py catalog-images.json
Original files remain unchanged; SHA-256 names match CatalogImageHelper.
"""
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image, ImageOps

root = Path(__file__).resolve().parents[2] / "HelmetCartelOrderingAndManagementSys"
folder = root / "Content/images/catalog"
folder.mkdir(parents=True, exist_ok=True)
before = after = count = 0
for item in json.loads(Path(sys.argv[1]).read_text(encoding="utf-8-sig")):
    url = item.get("MainImageUrl", "").replace("/Content/images/helmets/", "/Content/images/products/helmets/")
    if not url.startswith("/Content/images/"):
        continue
    source = (root / url.lstrip("/")).resolve()
    if not source.is_relative_to(root.resolve()) or not source.is_file():
        continue
    destination = folder / (hashlib.sha256(url.encode()).hexdigest() + ".jpg")
    with Image.open(source) as original:
        image = ImageOps.exif_transpose(original).convert("RGBA")
        image.thumbnail((600, 600), Image.Resampling.LANCZOS)
        background = Image.new("RGB", image.size, "white")
        background.paste(image, mask=image.getchannel("A"))
        background.save(destination, quality=82, optimize=True, progressive=True)
    original_size = source.stat().st_size
    thumbnail_size = destination.stat().st_size
    before += original_size
    if thumbnail_size >= original_size:
        destination.unlink()
        after += original_size
    else:
        after += thumbnail_size
        count += 1
print(f"{count} thumbnails; original bytes {before}; catalog bytes {after}; reduction {(1-after/before)*100:.1f}%")
