#!/usr/bin/env python
import os
from os.path import join
import zipfile

def zipdir(path, ziph):
    # ziph is zipfile handle
    for root, dirs, files in os.walk(path):
        if "DoNotInclude" not in root:
            for file in files:
                ziph.write(os.path.join(root, file))

if __name__ == '__main__':

    # --------------------------------------------------------------------
    # This script builds the Angular static resource bundle.
    #
    # NOTE:
    # The output file is named "Angular.resource" because Salesforce
    # source format expects:
    #
    #   src/staticresources/Angular.resource
    #   src/staticresources/Angular.resource-meta.xml
    #
    # Even though it has no .zip extension, it *is* a ZIP file.
    #
    # If you want to inspect the contents, simply make a copy and
    # rename it to Angular.zip, then open it with any zip tool.
    # --------------------------------------------------------------------

    zipFilename = 'Angular.resource'
    outPath = join("..", "..", "src", "staticresources", zipFilename)

    # Ensure output directory exists
    os.makedirs(os.path.dirname(outPath), exist_ok=True)

    with zipfile.ZipFile(outPath, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipdir(".", zipf)

    print("Static resource built:", outPath)
    print("NOTE: This file is a ZIP archive without a .zip extension.")
    print("To inspect contents, copy it and rename the copy to Angular.zip.")