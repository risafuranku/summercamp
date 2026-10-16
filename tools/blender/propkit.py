"""Low-poly prop kit for the camp interiors, run inside Blender (headless is fine).

Build-engine look: every face is textured with the camp's 128 px palette textures at a
constant texel density (UVs projected from world space per face, like Build's wall
alignment), nearest filtering, no specular. Each prop is built from simple parts, joined
into one mesh with its origin on the floor at the centre of its footprint, the front
facing Blender -Y (Godot +Z, towards the viewer), and exported as one .glb.

    blender --background --factory-startup --python tools/blender/build_props.py

Units: metres. Z up in Blender (Y up in Godot).
"""
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "godot", "assets", "textury", "camp")
OUT = os.path.join(ROOT, "godot", "assets", "models", "interior")

_materials = {}
_manifest = {}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def mat(name, tex=None, tint=(1, 1, 1), texel=1.0):
    """A material: `tex` = camp texture file name (or None for flat `tint`), `texel` =
    metres one texture repeat covers on the model."""
    key = (name, tex, tuple(tint), texel)
    if key in _materials:
        return _materials[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
    path = os.path.join(TEX, tex) if tex else None
    if path and os.path.exists(path):
        img = bpy.data.images.load(path, check_existing=True)
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.interpolation = "Closest"
        if tuple(tint) != (1, 1, 1):
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            nt.links.new(node.outputs["Color"], mix.inputs["A"])
            mix.inputs["B"].default_value = (*tint, 1.0)
            nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
        else:
            nt.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*tint, 1.0)
    m["texel"] = texel
    _materials[key] = m
    _manifest[m.name] = {"tex": tex or "", "tint": [round(c, 3) for c in tint]}
    return m


def _uv_world(obj, texel):
    """Per-face planar UVs from world coordinates: u, v in texture repeats."""
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.verify()
    mw = obj.matrix_world
    for f in bm.faces:
        n = (mw.to_3x3() @ f.normal).normalized()
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            co = mw @ loop.vert.co
            if ax == 2:      # floor / top: x, y
                u, v = co.x, co.y
            elif ax == 1:    # front / back: x, z
                u, v = co.x * (1 if n[1] < 0 else -1), co.z
            else:            # sides: y, z
                u, v = co.y * (-1 if n[0] < 0 else 1), co.z
            loop[uv].uv = (u / texel, v / texel)
    bm.to_mesh(me)
    bm.free()


def _finish(obj, material, rot=(0, 0, 0)):
    obj.rotation_euler = rot
    bpy.context.view_layer.update()
    obj.data.materials.append(material)
    _uv_world(obj, material.get("texel", 1.0))
    return obj


def box(size, loc, material, rot=(0, 0, 0), name="part"):
    """An axis box `size` (x, y, z) centred on `loc`."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    return _finish(obj, material, rot)


def cyl(radius, depth, loc, material, segments=10, rot=(0, 0, 0), radius_top=None, name="part", cap=True):
    """A cylinder standing on Z (`depth` tall) centred on `loc`; `radius_top` tapers it."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segments,
                          radius1=radius, radius2=radius if radius_top is None else radius_top, depth=depth)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    obj.location = loc
    return _finish(obj, material, rot)


def tube(radius, depth, wall, loc, material, segments=12, radius_top=None, bottom=True, name="part"):
    """An open-topped vessel (bucket, bowl, pot): outer wall, inner wall, rim, floor."""
    rt = radius if radius_top is None else radius_top
    parts = [cyl(radius, depth, loc, material, segments, radius_top=rt, cap=False, name=name)]
    inner = cyl(radius - wall, depth - wall, (loc[0], loc[1], loc[2] + wall * 0.5), material, segments,
                radius_top=rt - wall, cap=False, name=name)
    # Flip the inner wall to face inwards.
    bm = bmesh.new()
    bm.from_mesh(inner.data)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(inner.data)
    bm.free()
    parts.append(inner)
    me = bpy.data.meshes.new(name + "_rim")
    bm = bmesh.new()
    z = depth * 0.5
    outer = [bm.verts.new((math.cos(a) * rt, math.sin(a) * rt, z)) for a in [i * math.tau / segments for i in range(segments)]]
    innerv = [bm.verts.new((math.cos(a) * (rt - wall), math.sin(a) * (rt - wall), z)) for a in [i * math.tau / segments for i in range(segments)]]
    for i in range(segments):
        j = (i + 1) % segments
        bm.faces.new((outer[i], outer[j], innerv[j], innerv[i]))
    bm.to_mesh(me)
    bm.free()
    rim = bpy.data.objects.new(name + "_rim", me)
    bpy.context.collection.objects.link(rim)
    rim.location = loc
    parts.append(_finish(rim, material))
    if bottom:
        parts.append(cyl(radius - wall, 0.004, (loc[0], loc[1], loc[2] - depth * 0.5 + wall + 0.002), material, segments, name=name))
    return parts


def join(name, parts):
    """Join `parts` into one object called `name`, origin at the floor centre."""
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # Origin: centre of the footprint at the lowest point.
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    pivot = Vector(((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, min(zs)))
    obj.data.transform(Matrix.Translation(-pivot))
    obj.location = (0, 0, 0)
    return obj


def export(obj, file_name):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(OUT, file_name)
    # No images in the .glb: Godot puts the shared camp textures back by material name
    # (materials.json, scripts/interior_kit.gd), so there is one copy of every texture.
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_image_format="NONE")
    return path


def write_manifest():
    """materials.json next to the .glb files: material name -> {tex, tint}. Merged with
    what is there: a run for a few props must not drop materials only others create."""
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "materials.json")
    merged = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            merged = json.load(f)
    merged.update(_manifest)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(dict(sorted(merged.items())), f, indent=1)
