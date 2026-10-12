"""Render all props side by side to one PNG for review.

    blender --background --factory-startup --python tools/blender/preview_props.py -- <out.png> [prop ...]
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_props as B  # noqa: E402
import propkit as K  # noqa: E402

args = sys.argv[sys.argv.index("--") + 1:]
out = args[0]
only = args[1:]
K.reset_scene()
m = B.M()
names = [n for n in B.PROPS if not only or n in only]
cols = min(5, len(names))
for i, name in enumerate(names):
    obj = K.join(name, B.PROPS[name](m))
    obj.location = ((i % cols) * 1.6, (i // cols) * 2.4, 0)

rows = (len(names) + cols - 1) // cols
cx = (cols - 1) * 1.6 * 0.5
cy = (rows - 1) * 2.4 * 0.5
scene = bpy.context.scene
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = max(cols * 1.7, rows * 2.6) + 0.6
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (cx + 7.0, cy - 9.0, 7.0)
target = bpy.data.objects.new("target", None)
target.location = (cx, cy, 0.6)
scene.collection.objects.link(target)
track = cam.constraints.new("TRACK_TO")
track.target = target
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam
sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 3.0
sun_obj = bpy.data.objects.new("sun", sun)
sun_obj.rotation_euler = (0.8, 0.2, 0.6)
scene.collection.objects.link(sun_obj)
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.25, 0.25, 0.28, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
scene.world = world
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1600
scene.render.resolution_y = int(1600 * rows * 2.6 / (cols * 1.7)) if rows > 1 else 700
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("PREVIEW " + out)
