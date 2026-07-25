//! Acceptance tests for the eval-rust battery. Relocated out of the editable src/lib.rs
//! (issue #4) into this non-editable integration test, so a node cannot be scored GREEN
//! by deleting its test. `cargo test <filter>` selects the one test a kata targets.

use eval_rust::*;

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
