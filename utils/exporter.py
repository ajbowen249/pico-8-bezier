bl_info = {
    'name': 'Pico 8 Spline Tools',
    'author': 'ajbowen249',
    'category': 'Import-Export',
    'version': (0, 0, 0),
    'blender': (3, 4, 1),
    'location': 'File > Export',
    'description': 'Curve exporter Pico 8 Spline Tools'
}

import bpy
import bmesh
import os
from bpy.props import *
from bpy_extras.io_utils import ExportHelper

separator = ','

def convert_y(y):
    return 128 - y

class ExportToPico8Spline(bpy.types.Operator, ExportHelper):
    '''Export Pico 8 Spline'''
    bl_idname = 'export.pico8spline'
    bl_label = 'Export Pico 8 Spline'
    filename_ext = '.p8s'

    def execute(self, context):
        filepath = self.filepath
        filepath = bpy.path.ensure_ext(filepath, self.filename_ext)

        # make sure we're in object mode
        bpy.ops.object.mode_set(mode='OBJECT')

        # gather curves
        curves = [obj for obj in bpy.context.scene.objects if obj.type == "CURVE"]
        print("curves")
        for curve in curves:
            name = curve.name
            for spline in curve.data.splines:
                out_values = []
                points = spline.bezier_points
                num_points = len(points)
                if num_points < 2:
                    raise 'Curve not long enough!'

                # writing number of segments
                out_values.append(num_points - 1)
                # -1 because we're doing segment point pairs
                for point_index in range(0, num_points - 1):
                    start = points[point_index]

                    out_values.append(start.co.x)
                    out_values.append(convert_y(start.co.y))
                    out_values.append(start.handle_right.x)
                    out_values.append(convert_y(start.handle_right.y))

                    end = points[point_index + 1]
                    out_values.append(end.handle_left.x)
                    out_values.append(convert_y(end.handle_left.y))
                    out_values.append(end.co.x)
                    out_values.append(convert_y(end.co.y))

                print("{name}: {data}".format(name = name, data = ",".join([str(val) for val in out_values])))

        return {'FINISHED'}

def menu_func(self, context):
    self.layout.operator(ExportToPico8Spline.bl_idname, text='Pico 8 Spline (.p8s)')

def register():
    bpy.utils.register_class(ExportToPico8Spline)
    bpy.types.TOPBAR_MT_file_export.append(menu_func)

def unregister():
    bpy.utils.unregister_class(ExportToPico8Spline)
    bpy.types.TOPBAR_MT_file_export.remove(menu_func)

if __name__ == '__main__':
    register()
