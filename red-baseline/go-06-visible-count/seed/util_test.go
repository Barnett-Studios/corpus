package util

import "testing"

func eq(t *testing.T, got, want string) {
	t.Helper()
	if got != want {
		t.Fatalf("got %q want %q", got, want)
	}
}

func TestCompactPath(t *testing.T) {
	eq(t, CompactPath("a/b/c/d", 3), "a/…/d")
	eq(t, CompactPath("a/b", 3), "a/b")
	eq(t, CompactPath("only", 3), "only")
}

func TestLongestCommonDir(t *testing.T) {
	eq(t, LongestCommonDir([]string{"src/a/x.go", "src/a/y.go", "src/b/z.go"}), "src")
	eq(t, LongestCommonDir([]string{"src/a/x.go"}), "src/a")
	eq(t, LongestCommonDir([]string{"a.go", "b.go"}), "")
	eq(t, LongestCommonDir([]string{}), "")
}

func TestStripPrefixDir(t *testing.T) {
	eq(t, StripPrefixDir("src/a/x.go", "src"), "a/x.go")
	eq(t, StripPrefixDir("src/a/x.go", "lib"), "src/a/x.go")
	eq(t, StripPrefixDir("src", "src"), "src")
}

func TestEncodeDecodeRoundtrip(t *testing.T) {
	for _, s := range []string{"a/b/c", "plain", "x/y", "/leading", "trailing/"} {
		eq(t, DecodeSeg(EncodeSeg(s)), s)
	}
	eq(t, EncodeSeg("a/b"), "a%2Fb")
}

func TestSplitJoinExtRoundtrip(t *testing.T) {
	s, e := SplitExt("main.go")
	eq(t, s, "main")
	eq(t, e, "go")
	s2, e2 := SplitExt("README")
	eq(t, s2, "README")
	eq(t, e2, "")
	eq(t, JoinExt("main", "go"), "main.go")
	eq(t, JoinExt("README", ""), "README")
	s3, e3 := SplitExt("archive.tar")
	eq(t, JoinExt(s3, e3), "archive.tar")
}

func TestVisibleCount(t *testing.T) {
	if !IsHidden(".git") || IsHidden("src") {
		t.Fatal("is_hidden wrong")
	}
	if n := VisibleCount([]string{".git", "src", ".env", "main.go"}); n != 2 {
		t.Fatalf("visible_count got %d want 2", n)
	}
}
