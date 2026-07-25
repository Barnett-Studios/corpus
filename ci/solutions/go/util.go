// Reference solution for the go katas (validation only — NEVER shipped into
// red-baseline/). One solved file covers all six go katas; ci/prove-solvable.sh
// overlays it onto each kata's seed and asserts the fixed accept exits 0.
package util

import "strings"

func CompactPath(path string, max int) string {
	parts := strings.Split(path, "/")
	if len(parts) <= max {
		return path
	}
	return parts[0] + "/…/" + parts[len(parts)-1]
}

func LongestCommonDir(paths []string) string {
	if len(paths) == 0 {
		return ""
	}
	parents := make([][]string, len(paths))
	minLen := -1
	for i, p := range paths {
		ps := strings.Split(p, "/")
		parents[i] = ps[:len(ps)-1]
		if minLen == -1 || len(parents[i]) < minLen {
			minLen = len(parents[i])
		}
	}
	var common []string
	for i := 0; i < minLen; i++ {
		seg := parents[0][i]
		ok := true
		for _, par := range parents {
			if par[i] != seg {
				ok = false
				break
			}
		}
		if !ok {
			break
		}
		common = append(common, seg)
	}
	return strings.Join(common, "/")
}

func StripPrefixDir(path, prefix string) string {
	pre := prefix + "/"
	if strings.HasPrefix(path, pre) {
		return path[len(pre):]
	}
	return path
}

func EncodeSeg(s string) string { return strings.ReplaceAll(s, "/", "%2F") }
func DecodeSeg(s string) string { return strings.ReplaceAll(s, "%2F", "/") }

func SplitExt(name string) (string, string) {
	i := strings.LastIndex(name, ".")
	if i == -1 {
		return name, ""
	}
	return name[:i], name[i+1:]
}

func JoinExt(stem, ext string) string {
	if ext == "" {
		return stem
	}
	return stem + "." + ext
}

func IsHidden(name string) bool { return strings.HasPrefix(name, ".") }

func VisibleCount(names []string) int {
	c := 0
	for _, n := range names {
		if !IsHidden(n) {
			c++
		}
	}
	return c
}
