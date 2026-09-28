"""Exercise broken-link detection and heading behavior used by the documentation gate."""

import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("doclinks", Path(__file__).with_name("Documentation-Links-Validation.py"))
doclinks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(doclinks)


class LinkValidationTests(unittest.TestCase):
    def check_docs(self, files):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name, text in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            return doclinks.validate(root)[0]

    def test_valid_links_and_duplicate_headings(self):
        self.assertEqual([], self.check_docs({
            "README.md": "[Guide](docs/guide.md#second-heading-1)\n[Image](docs/picture.png)\n[Self](#home)\n# Home\n",
            "docs/guide.md": "# Second `heading`\n# Second heading\n[Back](../README.md#home)\n",
            "docs/picture.png": "placeholder",
        }))

    def test_missing_file_and_anchor_are_failures(self):
        errors = self.check_docs({"README.md": "# Home\n[Bad](absent.md)\n[Bad anchor](#absent)\n"})
        self.assertEqual(2, len(errors))
        self.assertTrue(any("missing target" in e for e in errors))
        self.assertTrue(any("missing heading anchor" in e for e in errors))

    def test_code_examples_and_external_links_are_not_fetched(self):
        text = "```markdown\n[Example](missing.md)\n# Fake\n```\n[Site](https://example.invalid/no-page)\n"
        self.assertEqual([], self.check_docs({"README.md": text}))
        self.assertNotIn("fake", doclinks.heading_ids(text))

    def test_reference_links_and_percent_encoded_paths(self):
        self.assertEqual([], self.check_docs({
            "README.md": "[Guide][g]\n[g]: docs/a%20b.md#hello\n",
            "docs/a b.md": "# Hello\n",
        }))
        self.assertEqual(1, len(self.check_docs({"README.md": "[Guide][missing]\n"})))

    def test_reference_target_and_repository_escape_fail(self):
        errors = self.check_docs({"README.md": "[g]: missing.md\n[Escape](../outside.md)\n"})
        self.assertEqual(2, len(errors))


if __name__ == "__main__":
    unittest.main()
