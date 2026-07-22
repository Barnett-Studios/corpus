"""Reference solution for the python katas (validation only — NEVER shipped into
red-baseline/). One solved file covers all six python katas; ci/prove-solvable.sh
overlays it onto each kata's seed and asserts the fixed accept exits 0."""


def compact_path(path, max_components):
    parts = path.split('/')
    if len(parts) <= max_components:
        return path
    return parts[0] + '/…/' + parts[-1]


def longest_common_dir(paths):
    if not paths:
        return ''
    parents = [p.split('/')[:-1] for p in paths]
    common = []
    for i in range(min(len(par) for par in parents)):
        seg = parents[0][i]
        if all(par[i] == seg for par in parents):
            common.append(seg)
        else:
            break
    return '/'.join(common)


def strip_prefix_dir(path, prefix):
    pre = prefix + '/'
    return path[len(pre):] if path.startswith(pre) else path


def encode_seg(s):
    return s.replace('/', '%2F')


def decode_seg(s):
    return s.replace('%2F', '/')


def split_ext(name):
    i = name.rfind('.')
    return (name, '') if i == -1 else (name[:i], name[i + 1:])


def join_ext(stem, ext):
    return stem if ext == '' else stem + '.' + ext


def is_hidden(name):
    return name.startswith('.')


def visible_count(names):
    return sum(1 for n in names if not is_hidden(n))
