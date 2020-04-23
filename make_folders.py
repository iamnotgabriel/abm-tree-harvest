#!/usr/bin/python3

import sys
import os
file = sys.argv[1]
for folder in sys.argv[2:]:
    os.mkdir(folder)
    open(folder+"/"+file, "a").close()
