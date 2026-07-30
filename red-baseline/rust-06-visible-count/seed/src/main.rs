//! Fixed harness — nodes never edit this file (only `src/lib.rs` is in `files:`).
//!
//! This is the only caller of the model-edited library. It computes observations and
//! prints them, one per line; it asserts NOTHING. All judgement lives in
//! `tests/katas.rs`, which runs this binary as a SUBPROCESS.
//!
//! That split is the point (issue #7). An integration test links the library into its own
//! process, so `std::process::exit(0)` in a library function — which type-checks anywhere,
//! since it returns `!` — kills the test binary with a success status before any assertion
//! runs. Out-of-process it kills only this child, which then prints no observations, and
//! the parent requires *positive evidence* rather than merely a zero exit.

use eval_rust::*;

fn main() {
    let case = std::env::args().nth(1).unwrap_or_default();
    let lines: Vec<String> = match case.as_str() {
        "compact_path" => vec![
            compact_path("a/b/c/d", 3),
            compact_path("a/b", 3),
            compact_path("only", 3),
        ],
        "longest_common_dir" => vec![
            longest_common_dir(&["src/a/x.rs", "src/a/y.rs", "src/b/z.rs"]),
            longest_common_dir(&["src/a/x.rs"]),
            longest_common_dir(&["a.rs", "b.rs"]),
            longest_common_dir(&[]),
        ],
        "strip_prefix_dir" => vec![
            strip_prefix_dir("src/a/x.rs", "src"),
            strip_prefix_dir("src/a/x.rs", "lib"),
            strip_prefix_dir("src", "src"),
        ],
        "encode_decode_roundtrip" => {
            let mut v: Vec<String> = ["a/b/c", "plain", "x/y", "/leading", "trailing/"]
                .iter()
                .map(|s| decode_seg(&encode_seg(s)))
                .collect();
            v.push(encode_seg("a/b"));
            v.push(encode_seg("a/b").contains('/').to_string());
            v
        }
        "split_join_ext_roundtrip" => {
            let (s1, e1) = split_ext("main.rs");
            let (s2, e2) = split_ext("README");
            let (stem, ext) = split_ext("archive.tar");
            vec![
                s1,
                e1,
                s2,
                e2,
                join_ext("main", "rs"),
                join_ext("README", ""),
                join_ext(&stem, &ext),
            ]
        }
        "visible_count" => vec![
            is_hidden(".git").to_string(),
            is_hidden("src").to_string(),
            visible_count(&[".git", "src", ".env", "main.rs"]).to_string(),
        ],
        other => {
            eprintln!("unknown case: {other}");
            std::process::exit(2);
        }
    };
    for line in lines {
        println!("{line}");
    }
}
