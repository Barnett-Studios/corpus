"""Battery seed (Python). Every function is a NotImplementedError stub; each
node implements one (or, for two-region nodes, one coordinated pair) so its
test in test_util.py goes from RED to GREEN."""


def compact_path(path, max_components):
    """Single-region: unchanged if <= max_components '/'-parts, else first and
    last parts with the middle elided as '…' (compact_path('a/b/c/d',3)=='a/…/d')."""
    raise NotImplementedError


def longest_common_dir(paths):
    """Single-region (hard): longest shared parent dir (parts except last)
    joined by '/'; '' if none or paths empty."""
    raise NotImplementedError


def strip_prefix_dir(path, prefix):
    """Single-region: strip a leading 'prefix/' from path; unchanged if absent."""
    raise NotImplementedError


def encode_seg(s):
    """Two-region (pair A): replace every '/' with '%2F'."""
    raise NotImplementedError


def decode_seg(s):
    """Two-region (pair A): exact inverse of encode_seg."""
    raise NotImplementedError


def split_ext(name):
    """Two-region (pair B): (stem, ext) where ext is text after the last '.'
    without the dot ('' when none)."""
    raise NotImplementedError


def join_ext(stem, ext):
    """Two-region (pair B): inverse of split_ext — join with '.', or just stem
    when ext is ''."""
    raise NotImplementedError


def is_hidden(name):
    """Two-region (composition): True when name starts with '.'."""
    raise NotImplementedError


def visible_count(names):
    """Two-region (composition): count names that are not hidden; must use
    is_hidden."""
    raise NotImplementedError
