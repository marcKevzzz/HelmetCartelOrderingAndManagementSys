"""Copy selected Context photos to web assets and write their catalog manifest.

Run from the repository root before deploying the SQL catalog content seed.
Only representative views are selected because ProductGalleryImages allows five
additional images per product. Source files remain untouched.
"""

import csv
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "HelmetCartelOrderingAndManagementSys" / "Content" / "images" / "products" / "helmets"
MANIFEST = Path(__file__).with_name("catalog_image_manifest.csv")
SEED = Path(__file__).with_name("05_catalog_content.sql")
PROJECT = ROOT / "HelmetCartelOrderingAndManagementSys" / "HelmetCartelOrderingAndManagementSys.csproj"

# The image numbers refer to sorted JPEG files in each Context brand folder.
# The first entry is the new product's main image when a main image is needed;
# otherwise all entries are additional gallery views of an existing product.
IMAGES = {
    "agv": {
        "agv-neon-graphic-full-face": (None, [3, 4, 5]),
        "agv-red-blue-graphic-full-face": (None, [6, 17, 18, 19]),
        "agv-monster-graphic-full-face": (None, [8, 9, 11, 32, 33]),
        "agv-matte-black-full-face": (None, [27, 28, 29, 35, 37]),
        "agv-white-modular": (14, [12, 15, 16]),
        "agv-vr46-graphic": (22, [23, 25]),
        "agv-red-bull-graphic": (31, [20, 21]),
    },
    "gille": {
        "gille-ff007-kerena": (None, [4, 21, 23]),
        "gille-a5009-phoenix": (None, [18]),
        "gille-ff005-visage": (None, [24]),
        "gille-dual-visor-open-face": (1, [2, 3, 5, 7, 9]),
        "gille-classic-peak-full-face": (16, [17]),
        "gille-adventure-peak": (19, [20, 26, 27]),
        "gille-pink-aero-full-face": (22, []),
        "gille-black-full-face": (25, []),
    },
    "hnj": {
        "hnj-a4-001-plain": (None, [1, 5, 7, 8, 21]),
        "hnj-a4-008": (None, [2, 3, 13, 20, 33]),
        "hnj-2020": (None, [4, 6, 14, 17, 25]),
        "hnj-937": (None, [12, 16, 22, 27, 34]),
    },
    "shoei": {
        "shoei-neotec-3": (None, [20, 21, 23, 25, 27]),
        "shoei-hornet-adv": (None, [33, 37, 42, 46, 64]),
        "shoei-x-fifteen": (None, [16, 28, 29, 49, 56]),
        "shoei-graphic-open-face": (5, [7, 8, 10, 13, 14]),
    },
    "zebra": {
        "zebra-ym-602-plain": (None, [1, 5, 6, 7, 10]),
        "zebra-ym-902": (None, [3, 4, 8, 9, 14]),
        "zebra-603": (None, [2]),
        "zebra-ff-855": (None, [11, 13]),
        "zebra-hornet-modular": (None, [15, 16, 17, 18, 20]),
    },
}

# Color-specific WEBP assets are useful gallery views and were omitted from the
# numbered JPEG contact sheets. The first listed file gets the next free slot.
EXTRA_IMAGES = {
    "gille": {
        "gille-ff007-kerena": [
            "gille-ff007-kerena-lightblue.webp",
            "gille-ff007-kerena-mpink.webp",
        ],
        "gille-a5009-phoenix": [
            "gille-a5009phoenix-lakegreen.webp",
            "gille-a5009phoenix-pink.webp",
        ],
    },
    "hnj": {
        "hnj-titan-a4001k": [
            "hnj-titan-a4001k-hellokitty-black-400x400.webp",
            "hnj-titan-a4001k-hellokitty-cream-400x400.webp",
            "hnj-titan-a4001k-mario-black-400x400.webp",
            "hnj-titan-a4001k-mario-pink-400x400.webp",
        ],
    },
}


def main():
    rows = []
    for brand, products in IMAGES.items():
        sources = sorted((ROOT / "Context" / brand).glob("*.jpg"), key=lambda p: p.name.lower())
        for slug, (main_index, gallery_indices) in products.items():
            selections = ([] if main_index is None else [(main_index, "main", 0)])
            selections += [(index, "gallery", order) for order, index in enumerate(gallery_indices, 1)]
            for index, role, order in selections:
                source = sources[index - 1]
                filename = f"{slug}-{role}-{order if order else 'primary'}.jpg"
                target = WEB / brand / filename
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
                rows.append({
                    "ProductSlug": slug,
                    "Role": role,
                    "DisplayOrder": order,
                    "ImageUrl": f"/Content/images/products/helmets/{brand}/{filename}",
                    "Source": str(source.relative_to(ROOT)).replace("\\", "/"),
                })
    for brand, products in EXTRA_IMAGES.items():
        for slug, filenames in products.items():
            next_order = 1 + max((row["DisplayOrder"] for row in rows if row["ProductSlug"] == slug and row["Role"] == "gallery"), default=0)
            for offset, filename in enumerate(filenames):
                source = ROOT / "Context" / brand / filename
                target_name = f"{slug}-gallery-{next_order + offset}.webp"
                target = WEB / brand / target_name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
                rows.append({
                    "ProductSlug": slug,
                    "Role": "gallery",
                    "DisplayOrder": next_order + offset,
                    "ImageUrl": f"/Content/images/products/helmets/{brand}/{target_name}",
                    "Source": str(source.relative_to(ROOT)).replace("\\", "/"),
                })
    with MANIFEST.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=["ProductSlug", "Role", "DisplayOrder", "ImageUrl", "Source"])
        writer.writeheader()
        writer.writerows(rows)
    if SEED.exists():
        start = "    -- BEGIN GENERATED GALLERY ROWS"
        end = "    -- END GENERATED GALLERY ROWS"
        sql = SEED.read_text(encoding="utf-8")
        gallery = [row for row in rows if row["Role"] == "gallery"]
        values = ",\n".join(
            "    (N'{slug}',{order},N'{url}')".format(
                slug=row["ProductSlug"], order=row["DisplayOrder"], url=row["ImageUrl"]
            )
            for row in gallery
        )
        generated = f"{start}\n    INSERT @Gallery VALUES\n{values};\n"
        before, rest = sql.split(start, 1)
        _, after = rest.split(end, 1)
        SEED.write_text(before + generated + end + after, encoding="utf-8")
    if PROJECT.exists():
        start = "    <!-- BEGIN GENERATED CATALOG IMAGES -->"
        end = "    <!-- END GENERATED CATALOG IMAGES -->"
        project = PROJECT.read_text(encoding="utf-8-sig")
        includes = "\n".join(
            f'    <Content Include="{row["ImageUrl"].lstrip("/").replace("/", chr(92))}" />'
            for row in rows
        )
        generated = f"{start}\n{includes}\n    {end.strip()}"
        if start in project:
            before, rest = project.split(start, 1)
            _, after = rest.split(end, 1)
            project = before + generated + after
        else:
            anchor = '    <Content Include="Pages\\Auth.aspx" />'
            project = project.replace(anchor, generated + "\n" + anchor, 1)
        PROJECT.write_text(project, encoding="utf-8")
    print(f"Copied {len(rows)} selected product images; manifest: {MANIFEST}")


if __name__ == "__main__":
    main()
