"""Write the immutable ECR images built by CI to the two GitOps manifests."""

import os
from pathlib import Path
import re


def update_images(root: Path, registry: str, project_name: str, sha: str) -> None:
    for app in ("dog", "cat"):
        manifest = root / "k8s" / "apps" / f"{app}.yaml"
        content = manifest.read_text(encoding="utf-8")
        image = f"{registry}/{project_name}-{app}:{sha}"
        updated, count = re.subn(
            r"(?m)^([ \t]*image: )\S+[ \t]*$",
            lambda match: match.group(1) + image,
            content,
        )
        if count != 1:
            raise ValueError(f"Expected exactly one image in {manifest}, found {count}")
        manifest.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    update_images(
        Path(__file__).resolve().parents[1],
        os.environ["REGISTRY"],
        os.environ["PROJECT_NAME"],
        os.environ["SHA"],
    )