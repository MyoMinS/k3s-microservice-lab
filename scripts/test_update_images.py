import tempfile
import unittest
from pathlib import Path

from update_images import update_images


class UpdateImagesTests(unittest.TestCase):
    def test_replaces_only_container_images(self):
        with tempfile.TemporaryDirectory() as directory:
            apps = Path(directory) / "k8s" / "apps"
            apps.mkdir(parents=True)
            for name in ("dog", "cat"):
                (apps / f"{name}.yaml").write_text(
                    "# comment\n    image: old/image:old\n  imagePullPolicy: IfNotPresent\n",
                    encoding="utf-8",
                )
            update_images(Path(directory), "123.dkr.ecr.us-east-1.amazonaws.com", "demo", "abc123")
            for name in ("dog", "cat"):
                self.assertIn(
                    f"image: 123.dkr.ecr.us-east-1.amazonaws.com/demo-{name}:abc123",
                    (apps / f"{name}.yaml").read_text(encoding="utf-8"),
                )

    def test_rejects_missing_image(self):
        with tempfile.TemporaryDirectory() as directory:
            apps = Path(directory) / "k8s" / "apps"
            apps.mkdir(parents=True)
            (apps / "dog.yaml").write_text("kind: Deployment\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Expected exactly one image"):
                update_images(Path(directory), "registry", "demo", "abc123")


if __name__ == "__main__":
    unittest.main()