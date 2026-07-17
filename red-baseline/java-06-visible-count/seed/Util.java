// Battery seed (Java). Every method throws UnsupportedOperationException; each
// node implements one (or, for two-region nodes, one coordinated pair) so the
// matching check in TestRunner goes from RED to GREEN. Only this file is edited;
// TestRunner.java is the fixed harness.
//
// java.util is pre-imported so collection-based solutions (e.g. longestCommonDir
// with a List) stay single-region body edits — javac only warns on unused
// imports, so this is harmless when a node needs no collection. Mirrors an
// editor auto-managing imports; the eval measures logic, not import bookkeeping.
import java.util.*;

public class Util {

    // Single-region (easy): unchanged if <= max "/"-parts, else first and last
    // parts with the middle elided as "…" (compactPath("a/b/c/d",3)=="a/…/d").
    public static String compactPath(String path, int max) {
        throw new UnsupportedOperationException("todo");
    }

    // Single-region (hard): longest shared parent dir (parts except last) joined
    // by "/"; "" if none or paths empty.
    public static String longestCommonDir(String[] paths) {
        throw new UnsupportedOperationException("todo");
    }

    // Single-region: strip a leading "prefix/" from path; unchanged if absent.
    public static String stripPrefixDir(String path, String prefix) {
        throw new UnsupportedOperationException("todo");
    }

    // Two-region pair A: replace every "/" with "%2F".
    public static String encodeSeg(String s) {
        throw new UnsupportedOperationException("todo");
    }

    // Two-region pair A: exact inverse of encodeSeg.
    public static String decodeSeg(String s) {
        throw new UnsupportedOperationException("todo");
    }

    // Two-region pair B: {stem, ext} where ext is text after the last "."
    // without the dot ("" when none).
    public static String[] splitExt(String name) {
        throw new UnsupportedOperationException("todo");
    }

    // Two-region pair B: inverse of splitExt — join with ".", or just stem when
    // ext is "".
    public static String joinExt(String stem, String ext) {
        throw new UnsupportedOperationException("todo");
    }

    // Two-region composition: true when name starts with ".".
    public static boolean isHidden(String name) {
        throw new UnsupportedOperationException("todo");
    }

    // Two-region composition: count names that are not hidden; must use isHidden.
    public static int visibleCount(String[] names) {
        throw new UnsupportedOperationException("todo");
    }
}
