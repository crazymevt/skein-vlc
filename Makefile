# The Skein executable: the sibling skein-lang checkout's release build when
# there is one, otherwise skein on PATH.
SKEIN ?= $(if $(wildcard ../../skein-lang/target/release/skein),$(CURDIR)/../../skein-lang/target/release/skein,skein)

.PHONY: test fixture
# The tests play a silent file through the real audio output.
test:
	"$(SKEIN)" test --serial tests

# Regenerate the test fixture: two seconds of tagged silence (needs ffmpeg).
fixture:
	ffmpeg -y -f lavfi -i "anullsrc=r=8000:cl=mono" -t 2 -c:a flac \
		-metadata title="Quiet Test" -metadata artist="Skein" -metadata album="Fixtures" \
		-metadata genre="Silence" -metadata track=3 tests/fixtures/silence.flac
