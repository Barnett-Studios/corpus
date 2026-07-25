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
