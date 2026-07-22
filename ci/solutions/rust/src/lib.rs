//! Reference solution for the rust katas (validation only — NEVER shipped into
//! red-baseline/). One solved file covers all six rust katas; ci/prove-solvable.sh
//! overlays it onto each kata's (relocated) seed and asserts the fixed accept
//! exits 0. The acceptance test lives in the seed's non-editable tests/katas.rs.

pub fn compact_path(path: &str, max: usize) -> String {
    let parts: Vec<&str> = path.split('/').collect();
    if parts.len() <= max {
        return path.to_string();
    }
    format!("{}/…/{}", parts[0], parts[parts.len() - 1])
}

pub fn longest_common_dir(paths: &[&str]) -> String {
    if paths.is_empty() {
        return String::new();
    }
    let parents: Vec<Vec<&str>> = paths
        .iter()
        .map(|p| {
            let mut v: Vec<&str> = p.split('/').collect();
            v.pop();
            v
        })
        .collect();
    let min_len = parents.iter().map(|p| p.len()).min().unwrap_or(0);
    let mut common: Vec<&str> = Vec::new();
    for i in 0..min_len {
        let seg = parents[0][i];
        if parents.iter().all(|p| p[i] == seg) {
            common.push(seg);
        } else {
            break;
        }
    }
    common.join("/")
}

pub fn strip_prefix_dir(path: &str, prefix: &str) -> String {
    let pre = format!("{}/", prefix);
    match path.strip_prefix(&pre) {
        Some(rest) => rest.to_string(),
        None => path.to_string(),
    }
}

pub fn encode_seg(s: &str) -> String {
    s.replace('/', "%2F")
}

pub fn decode_seg(s: &str) -> String {
    s.replace("%2F", "/")
}

pub fn split_ext(name: &str) -> (String, String) {
    match name.rfind('.') {
        Some(i) => (name[..i].to_string(), name[i + 1..].to_string()),
        None => (name.to_string(), String::new()),
    }
}

pub fn join_ext(stem: &str, ext: &str) -> String {
    if ext.is_empty() {
        stem.to_string()
    } else {
        format!("{}.{}", stem, ext)
    }
}

pub fn is_hidden(name: &str) -> bool {
    name.starts_with('.')
}

pub fn visible_count(names: &[&str]) -> usize {
    names.iter().filter(|n| !is_hidden(n)).count()
}
