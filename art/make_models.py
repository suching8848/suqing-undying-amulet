"""Build the amulet's original DirectX meshes and shared texture atlas."""

import argparse
from math import sqrt
from pathlib import Path

from PIL import Image, ImageDraw


MEDIA = Path(__file__).resolve().parents[1] / "Contents/mods/SuQingUndyingAmulet/42/media"
MESH_DIR = MEDIA / "models_X/Static/SuQingUndyingAmulet"
TEXTURE_DIR = MEDIA / "textures/SuQingUndyingAmulet"
# Rearward depth, leftward position, drop, and yaw slope in Backpack bone units.
# The named profiles use both stock character bodies' mesh cross sections.
MOUNT_PROFILES = {
    "AmuletMounted": (0.090, 0.062, 0.023, 0.90),
    "AmuletMountedSmall": (0.079, 0.052, 0.022, 0.48),
    "AmuletMountedSmallFemale": (0.052, 0.053, 0.022, 0.68),
    "AmuletMountedHiking": (0.091, 0.064, 0.023, 1.14),
    "AmuletMountedHikingFemale": (0.069, 0.064, 0.023, 1.14),
    "AmuletMountedBigHiking": (0.088, 0.062, 0.023, 1.21),
    "AmuletMountedBigHikingFemale": (0.067, 0.062, 0.023, 1.21),
    "AmuletMountedMilitary": (0.119, 0.090, 0.023, 0.40),
    "AmuletMountedMilitaryFemale": (0.108, 0.090, 0.023, 0.46),
}
PALETTE = [
    (51, 54, 70), (80, 89, 108), (123, 137, 155), (167, 180, 201),
    (203, 214, 231), (233, 238, 249), (247, 246, 255), (68, 49, 103),
    (116, 83, 165), (144, 113, 196), (177, 151, 221), (204, 182, 241),
    (226, 210, 253), (246, 236, 255), (154, 141, 178), (93, 84, 115),
]

# Counterclockwise outline viewed from the gem side. The shortened points
# make a diamond silhouette with actual beveled edges.
DIAMOND = [
    (0, -1), (0.18, -0.86), (1, -0.11), (1, 0.11), (0.18, 0.86),
    (0, 1), (-0.18, 0.86), (-1, 0.11), (-1, -0.11), (-0.18, -0.86),
]


def ring(outline, width, height, depth):
    return [(x * width, y * height, depth) for x, y in outline]


def face(mesh, polygon, swatch):
    for j in range(1, len(polygon) - 1):
        mesh.append(((polygon[0], polygon[j], polygon[j + 1]), swatch))


def band(mesh, lower, upper, swatches):
    for j, start in enumerate(lower):
        k = (j + 1) % len(lower)
        face(mesh, [start, lower[k], upper[k], upper[j]], swatches[j % len(swatches)])


def box(mesh, x, y, z, width, height, thickness, swatches):
    corners = [(x, y), (x + width, y), (x + width, y + height), (x, y + height)]
    bottom = [(u, v, z) for u, v in corners]
    top = [(u, v, z + thickness) for u, v in corners]
    face(mesh, bottom[::-1], swatches[0])
    band(mesh, bottom, top, swatches)
    face(mesh, top, swatches[-1])


def jewel(broken=False):
    mesh = []
    width, height = 0.022, 0.026
    outline = DIAMOND if not broken else [
        (0, -1), (0.16, -0.75), (0.65, -0.49), (0.88, 0.03), (0.18, 0.86),
        (0, 1), (-0.18, 0.86), (-1, 0.11), (-1, -0.11), (-0.18, -0.86),
    ]
    back = ring(outline, width * 0.90, height * 0.90, 0)
    edge = ring(outline, width, height, 0.003)
    lip = ring(outline, width * 0.87, height * 0.87, 0.007)
    socket = ring(outline, width * 0.70, height * 0.71, 0.007)
    recess = ring(outline, width * 0.63, height * 0.65, 0.005)
    face(mesh, back[::-1], 1)
    band(mesh, back, edge, [1, 2, 3, 4, 4, 3, 2, 2, 1, 1])
    band(mesh, edge, lip, [3, 3, 4, 5, 5, 5, 6, 5, 4, 3])
    band(mesh, lip, socket, [2, 4, 4, 5, 6, 6, 5, 4, 3, 3])
    band(mesh, socket, recess, [1, 1, 2, 4, 4, 3, 2, 1, 1, 1])
    face(mesh, recess, 7)

    if broken:
        # Separate stone fragments leave the dark backing visible between them.
        fragments = [
            ([(-0.28, 0.13), (0.11, 0.21), (0.57, 0.08), (0.12, 0.48), (0, 0.61)], [8, 10, 12]),
            ([(-0.60, -0.02), (-0.14, -0.44), (-0.01, -0.56), (-0.11, -0.17), (-0.29, 0.08)], [8, 9, 10]),
        ]
        for contour, shades in fragments:
            low = ring(contour, width, height, 0.0055)
            high = ring(contour, width * 0.97, height * 0.97, 0.010)
            band(mesh, low, high, shades)
            face(mesh, high, shades[-1])
    else:
        girdle = ring(DIAMOND, width * 0.61, height * 0.63, 0.008)
        crown = ring(DIAMOND, width * 0.33, height * 0.42, 0.014)
        band(mesh, recess, girdle, [8, 8, 9, 10, 12, 12, 13, 11, 10, 8])
        band(mesh, girdle, crown, [9, 9, 10, 11, 13, 12, 13, 11, 11, 10])
        ridge = (0.001, 0.001, 0.016)
        for j, shade in enumerate([10, 11, 11, 12, 13, 13, 13, 12, 11, 10]):
            face(mesh, [crown[j], crown[(j + 1) % len(crown)], ridge], shade)
    return mesh


def clip(mesh):
    # The back jaw reaches into the strap, while the front jaw clamps it.
    box(mesh, -0.0060, 0.024, -0.016, 0.0120, 0.016, 0.003, [1, 2, 3, 2])
    box(mesh, -0.0060, 0.037, -0.013, 0.0120, 0.003, 0.019, [3, 4, 5, 5])
    box(mesh, -0.0060, 0.025, 0.003, 0.0120, 0.012, 0.003, [2, 4, 5, 4])
    box(mesh, -0.0037, 0.023, 0.005, 0.0074, 0.004, 0.003, [3, 4, 6, 5])


def normal(triangle):
    a, b, c = triangle
    u = [b[k] - a[k] for k in range(3)]
    v = [c[k] - a[k] for k in range(3)]
    xyz = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
    length = sqrt(sum(t * t for t in xyz))
    if length < 1e-10:
        raise ValueError(f"Degenerate face {triangle}")
    return [t / length for t in xyz]


def directx(mesh, output, transform):
    template = [
        "xof 0303txt 0032",
        f"Mesh {output.stem} {{",
        f"{len(mesh) * 3};",
    ]
    positions, normals, uvs, polygons = [], [], [], []
    for i, (triangle, swatch) in enumerate(mesh):
        # DirectX source is left-handed. Jassimp returns a right-handed mesh.
        raw = [(a, b, -c) for a, b, c in (transform(*point) for point in triangle[::-1])]
        positions.extend(raw)
        normals.extend([normal(raw)] * 3)
        tile_x, tile_y = swatch % 4, swatch // 4
        for u, v in [(0.18, 0.18), (0.82, 0.22), (0.82, 0.82)]:
            uvs.append(((tile_x + u) / 4, (tile_y + v) / 4))
        polygons.append(f"3;{i * 3},{i * 3 + 1},{i * 3 + 2};")

    def serialize(vectors):
        return [(";".join(f"{x:.7f}" for x in v) + ";") for v in vectors]

    def append_array(lines):
        template.extend([*(line + "," for line in lines[:-1]), lines[-1] + ";"])

    append_array(serialize(positions))
    template.append(f"{len(polygons)};")
    append_array(polygons)
    template.extend(["MeshNormals {", f"{len(normals)};"])
    append_array(serialize(normals))
    template.append(f"{len(polygons)};")
    append_array(polygons)
    template.extend(["}", "MeshTextureCoords {", f"{len(uvs)};"])
    append_array(serialize(uvs))
    template.extend(["}", "}"])
    output.write_text("\n".join(template) + "\n", encoding="ascii")


def backpack(rear, left, down, slope):
    cosine = 1 / sqrt(1 + slope * slope)
    sine = slope * cosine

    def transform(u, v, d):
        # Include the inverse of the stock backpack_left translation.
        return rear + sine * u + cosine * d + 0.001, left - cosine * u + sine * d - 0.129, down - v + 0.001

    return transform


def dropped(u, v, d):
    return u, d + 0.018, -v


def paint_atlas():
    atlas = Image.new("RGB", (64, 64))
    brush = ImageDraw.Draw(atlas)
    for index, color in enumerate(PALETTE):
        x, y = (index % 4) * 16, (index // 4) * 16
        brush.rectangle((x, y, x + 15, y + 15), fill=color)
    atlas.save(TEXTURE_DIR / "Amulet_Material.png")


def write_model_scripts():
    model_names = [*MOUNT_PROFILES, "AmuletWorld", "AmuletBrokenWorld"]
    blocks = [
        f"""    model {name}
    {{
        mesh = Static/SuQingUndyingAmulet/{name},
        texture = SuQingUndyingAmulet/Amulet_Material,
        static = true,
        scale = 1.0,
    }}""" for name in model_names
    ]
    script = "module SuQingUndyingAmulet\n{\n" + "\n\n".join(blocks) + "\n}\n"
    (MEDIA / "scripts/SuQingUndyingAmulet_Models.txt").write_text(script, encoding="ascii")


def preview(meshes, output):
    image = Image.new("RGB", (380 * len(meshes), 510), (19, 21, 33))
    brush = ImageDraw.Draw(image)
    for col, (label, mesh) in enumerate(meshes):
        cx = col * 380 + 190
        scale, cy = 4600, 275
        brush.rounded_rectangle((col * 380 + 16, 16, col * 380 + 364, 494), 18,
                                fill=(29, 32, 47))
        brush.text((cx, 455), label, fill=(231, 227, 249), anchor="mm", font_size=23)
        sorted_faces = sorted(mesh, key=lambda face: sum(0.32 * u + 0.11 * v + d
                                                       for u, v, d in face[0]))
        for triangle, shade in sorted_faces:
            nx, ny, nz = normal(triangle)
            if 0.32 * nx + 0.11 * ny + nz < 0:
                continue
            polygon = [(cx + (u - 0.32 * d) * scale, cy - (v - 0.11 * d) * scale)
                       for u, v, d in triangle]
            light = 0.83 + 0.17 * max(0, -0.34 * nx + 0.25 * ny + 0.88 * nz)
            brush.polygon(polygon, fill=tuple(round(light * c) for c in PALETTE[shade]))
    output.parent.mkdir(parents=True, exist_ok=True)
    image.save(output)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    MESH_DIR.mkdir(parents=True, exist_ok=True)
    TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
    mounted, broken = jewel(), jewel(broken=True)
    for mesh in (mounted, broken):
        clip(mesh)
    for name, dimensions in MOUNT_PROFILES.items():
        directx(mounted, MESH_DIR / f"{name}.x", backpack(*dimensions))
    directx(mounted, MESH_DIR / "AmuletWorld.x", dropped)
    directx(broken, MESH_DIR / "AmuletBrokenWorld.x", dropped)
    paint_atlas()
    write_model_scripts()
    if args.preview:
        preview([("Backpack clip", mounted), ("Broken amulet", broken)], args.preview)


if __name__ == "__main__":
    main()
