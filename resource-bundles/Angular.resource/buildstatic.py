#!/usr/bin/env python
import os
from os.path import join
import zipfile


def zipdir(path, ziph):
    for root, dirs, files in os.walk(path):
        if "DoNotInclude" not in root:
            for file in files:
                full_path = os.path.join(root, file)

                # Store paths relative to the Angular.resource directory
                archive_path = os.path.relpath(full_path, path)

                ziph.write(full_path, archive_path)


if __name__ == '__main__':

    # Directory containing this buildstatic.py
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Repo root:
    # resource-bundles\Angular.resource -> resource-bundles -> repo root
    repo_root = os.path.abspath(join(script_dir, "..", ".."))

    # Salesforce static resource output
    output_dir = join(repo_root, "src", "staticresources")
    out_path = join(output_dir, "Angular.resource")

    os.makedirs(output_dir, exist_ok=True)

    # Build from the Angular.resource directory itself
    with zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        zipdir(script_dir, zipf)

    print("Source directory:", script_dir)
    print("Static resource built:", out_path)
    print("NOTE: This file is a ZIP archive without a .zip extension.")