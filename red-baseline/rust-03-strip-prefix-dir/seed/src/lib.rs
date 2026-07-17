//! Eval-rust battery seed.
//!
//! Every function below is a `todo!()` stub, so the crate COMPILES at the
//! baseline but its tests are RED. Each eval node implements one function (or,
//! for the two-region nodes, one coordinated pair) and turns its test GREEN.
//! Two-region nodes are the discriminator: a model that edits only the first
//! region leaves the paired stub `todo!()`, so the round-trip test panics.

/// Single-region: return the path unchanged when it has at most `max`
/// '/'-separated components; otherwise keep the first and last components and
/// elide the middle as `…` — e.g. `compact_path("a/b/c/d", 3) == "a/…/d"`.
pub fn compact_path(path: &str, max: usize) -> String {
    let _ = (path, max);
    todo!()
}

/// Single-region (hard): the longest shared parent directory across `paths`.
/// Take each path's parent (all components except the last), then return the
/// longest shared leading run joined by '/'. Empty if none / `paths` empty.
pub fn longest_common_dir(paths: &[&str]) -> String {
    let _ = paths;
    todo!()
}

/// Single-region: strip a leading `prefix/` directory from `path`; return
/// `path` unchanged if it does not start with `prefix/`.
pub fn strip_prefix_dir(path: &str, prefix: &str) -> String {
    let _ = (path, prefix);
    todo!()
}

/// Two-region (pair A): percent-encode every '/' as `%2F`.
pub fn encode_seg(s: &str) -> String {
    let _ = s;
    todo!()
}
/// Two-region (pair A): exact inverse of [`encode_seg`].
pub fn decode_seg(s: &str) -> String {
    let _ = s;
    todo!()
}

/// Two-region (pair B): split a filename into `(stem, ext)` where `ext` is the
/// text after the last '.', without the dot (`""` when there is no '.').
pub fn split_ext(name: &str) -> (String, String) {
    let _ = name;
    todo!()
}
/// Two-region (pair B): exact inverse of [`split_ext`] — rejoin `stem` and
/// `ext` with a '.', or just `stem` when `ext` is empty.
pub fn join_ext(stem: &str, ext: &str) -> String {
    let _ = (stem, ext);
    todo!()
}

/// Two-region (composition): true when `name` is hidden (starts with '.').
pub fn is_hidden(name: &str) -> bool {
    let _ = name;
    todo!()
}
/// Two-region (composition): count non-hidden names. Must use [`is_hidden`].
pub fn visible_count(names: &[&str]) -> usize {
    let _ = names;
    todo!()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_compact_path() {
        assert_eq!(compact_path("a/b/c/d", 3), "a/…/d");
        assert_eq!(compact_path("a/b", 3), "a/b");
        assert_eq!(compact_path("only", 3), "only");
    }

    #[test]
    fn test_longest_common_dir() {
        assert_eq!(
            longest_common_dir(&["src/a/x.rs", "src/a/y.rs", "src/b/z.rs"]),
            "src"
        );
        assert_eq!(longest_common_dir(&["src/a/x.rs"]), "src/a");
        assert_eq!(longest_common_dir(&["a.rs", "b.rs"]), "");
        assert_eq!(longest_common_dir(&[]), "");
    }

    #[test]
    fn test_strip_prefix_dir() {
        assert_eq!(strip_prefix_dir("src/a/x.rs", "src"), "a/x.rs");
        assert_eq!(strip_prefix_dir("src/a/x.rs", "lib"), "src/a/x.rs");
        assert_eq!(strip_prefix_dir("src", "src"), "src");
    }

    #[test]
    fn test_encode_decode_roundtrip() {
        for s in ["a/b/c", "plain", "x/y", "/leading", "trailing/"] {
            assert_eq!(decode_seg(&encode_seg(s)), s);
        }
        assert_eq!(encode_seg("a/b"), "a%2Fb");
        assert!(!encode_seg("a/b").contains('/'));
    }

    #[test]
    fn test_split_join_ext_roundtrip() {
        assert_eq!(split_ext("main.rs"), ("main".to_string(), "rs".to_string()));
        assert_eq!(split_ext("README"), ("README".to_string(), String::new()));
        assert_eq!(join_ext("main", "rs"), "main.rs");
        assert_eq!(join_ext("README", ""), "README");
        let (stem, ext) = split_ext("archive.tar");
        assert_eq!(join_ext(&stem, &ext), "archive.tar");
    }

    #[test]
    fn test_visible_count() {
        assert!(is_hidden(".git"));
        assert!(!is_hidden("src"));
        assert_eq!(visible_count(&[".git", "src", ".env", "main.rs"]), 2);
    }
}
