import unittest

import util


class TestUtil(unittest.TestCase):
    def test_compact_path(self):
        self.assertEqual(util.compact_path("a/b/c/d", 3), "a/…/d")
        self.assertEqual(util.compact_path("a/b", 3), "a/b")
        self.assertEqual(util.compact_path("only", 3), "only")

    def test_longest_common_dir(self):
        self.assertEqual(
            util.longest_common_dir(["src/a/x.py", "src/a/y.py", "src/b/z.py"]), "src"
        )
        self.assertEqual(util.longest_common_dir(["src/a/x.py"]), "src/a")
        self.assertEqual(util.longest_common_dir(["a.py", "b.py"]), "")
        self.assertEqual(util.longest_common_dir([]), "")

    def test_strip_prefix_dir(self):
        self.assertEqual(util.strip_prefix_dir("src/a/x.py", "src"), "a/x.py")
        self.assertEqual(util.strip_prefix_dir("src/a/x.py", "lib"), "src/a/x.py")
        self.assertEqual(util.strip_prefix_dir("src", "src"), "src")

    def test_encode_decode_roundtrip(self):
        for s in ["a/b/c", "plain", "x/y", "/leading", "trailing/"]:
            self.assertEqual(util.decode_seg(util.encode_seg(s)), s)
        self.assertEqual(util.encode_seg("a/b"), "a%2Fb")
        self.assertNotIn("/", util.encode_seg("a/b"))

    def test_split_join_ext_roundtrip(self):
        self.assertEqual(util.split_ext("main.py"), ("main", "py"))
        self.assertEqual(util.split_ext("README"), ("README", ""))
        self.assertEqual(util.join_ext("main", "py"), "main.py")
        self.assertEqual(util.join_ext("README", ""), "README")
        stem, ext = util.split_ext("archive.tar")
        self.assertEqual(util.join_ext(stem, ext), "archive.tar")

    def test_visible_count(self):
        self.assertTrue(util.is_hidden(".git"))
        self.assertFalse(util.is_hidden("src"))
        self.assertEqual(util.visible_count([".git", "src", ".env", "main.py"]), 2)


if __name__ == "__main__":
    unittest.main()
