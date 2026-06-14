#!/usr/bin/env python3

import os
import utils.build as build
from fddutil_python.src.fddimage import Filesystem

def export(input_files = [], output_fdd = 'bin\\out.fdd', basefdd_path = 'scripts\\basefdd\\os-t34.fdd'):
    
    if not os.path.exists(basefdd_path):
        build.exit_error(f'export_fdd ERROR: cannot find the base fdd image: {basefdd_path}')

    if len(input_files) == 0:
        build.exit_error('export_fdd ERROR: no input files specified')

    try:
        with open(basefdd_path, 'rb') as f:
            basefdd_data = f.read()
    except IOError:
        build.exit_error(f'export_fdd ERROR: cannot read the base fdd image: {basefdd_path}')

    fdd = Filesystem().from_array(basefdd_data)
    build.printc('The base fdd image contains:', build.TextColor.GRAY)
    fdd.list_dir()

    for name in input_files:
        try:
            with open(name, 'rb') as f:
                data = f.read()
        except IOError:
            build.exit_error(f'export_fdd ERROR: cannot read the input file {name}')
        
        basename = os.path.basename(name)
        free_space = fdd.save_file(basename, data)
        build.printc(f'Saved file {basename} to FDD image, size: {len(data)} bytes, free space: {free_space}', build.TextColor.GREEN)

    try:
        with open(output_fdd, 'wb') as f:
            f.write(bytes(fdd.bytes))
        build.printc(f'export_fdd: FDD image saved to: {output_fdd}', build.TextColor.GREEN)
    except IOError:
        build.exit_error(f'export_fdd Error: cannot write FDD image to: {output_fdd}')

    return free_space