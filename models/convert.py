import sys
import bpy
argv = sys.argv
model = argv[argv.index("--") + 1:][0]

for bpy_data_iter in (
        bpy.data.objects,
        bpy.data.meshes,
        bpy.data.lamps,
        bpy.data.cameras
        ):
    for id_data in bpy_data_iter:
        bpy_data_iter.remove(id_data, do_unlink=True)

bpy.ops.import_scene.obj(filepath="/Users/bjorn/Documents/dev/ssw_layout/models/" + model)
bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
bpy.ops.export_scene.obj(filepath="/Users/bjorn/output/" + model)
