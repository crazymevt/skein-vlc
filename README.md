# skein-vlc

libVLC bindings for playing audio in Skein applications. The `skein.vlc` package plays files and streams, controls pause, seeking, volume and speed, and reads tags such as title, artist and album. It calls libVLC 3 directly through `skein.ffi`, so it plays every format VLC does: MP3, AAC, FLAC, Ogg, Opus, WAV, internet radio and more.

## Install and play

Install VLC 3 (64-bit). There is nothing to build.

- **macOS:** `brew install --cask vlc`, or the installer from videolan.org.
- **Windows:** the 64-bit installer from videolan.org.
- **Linux:** your distribution's `vlc` or `libvlc` package.

```sh
skein examples/play.skn song.mp3
```

Run examples from this folder. The package looks for libVLC in the usual install folders:

| OS | Folders |
| --- | --- |
| macOS | `/Applications/VLC.app/Contents/MacOS/lib`, `~/Applications/VLC.app/...`, `/opt/homebrew/lib`, `/usr/local/lib` |
| Windows | `%ProgramW6432%\VideoLAN\VLC`, `%ProgramFiles%\VideoLAN\VLC` |
| Linux | the system loader's path (`libvlc.so.5`) |

Set `SKEIN_VLC_LIBRARY` to the path of `libvlc.dylib`, `libvlc.dll` or `libvlc.so.5` to use another copy. `libvlccore` must sit in the same folder. The package loads `libvlccore` first by its full path, because the system loader doesn't search libvlc's own folder for it. On macOS it also points `VLC_PLUGIN_PATH` at the bundle's `plugins` folder, unless you set it yourself.

## Use in another Skein project

Add this checkout to your application's `skein.edn`. The dependency path is relative to your application.

```clojure
:deps {skein-vlc {:path "../skein-vlc"}}
```

```clojure
(require '[skein.vlc :as vlc])

(vlc/metadata "music/song.flac")
; => {:title "Song" :artist "Band" :album "Album" :duration-ms 215000 ...}

(vlc/with-player [player {:volume 80}]
  (vlc/play! player "music/song.flac")
  (vlc/wait! player))  ; parks this fiber until the song ends
```

A source is a file path or a URL. VLC opens anything with a scheme (`https://`, `file://` and the rest) as a URL, and anything else as a local file, which must exist. Calls are thread-safe, and `wait!` sleeps rather than holding a carrier, so a UI fiber can keep running while another waits.

| Function | Behavior |
| --- | --- |
| `(open-player! {:volume n})` | Make a player. Volume is 0..200 and defaults to 100. |
| `(close-player! p)` | Stop and release the player. Safe to call again. |
| `(with-player [p opts] body)` | Open a player for body and close it afterwards. |
| `(play! p source)`, `(play! p source {:start-ms n})` | Replace what the player had and start playing, optionally `n` ms in. |
| `pause!`, `resume!`, `toggle-pause!`, `stop!` | Control playback. `play!` starts again after a stop or the end. |
| `(seek! p ms)` | Move to `ms`. libVLC ignores this until the media has opened, and for streams that can't seek. |
| `volume`, `set-volume!` | Volume in percent: 0 is silent, 100 the file's own level, up to 200. |
| `muted?`, `set-muted!` | Mute without losing the volume. |
| `rate`, `set-rate!` | Playback speed from 0.25 to 4.0. It belongs to the player and carries over to the next `play!`. |
| `(state p)` | `:idle`, `:opening`, `:buffering`, `:playing`, `:paused`, `:stopped`, `:ended` or `:error`. |
| `(status p)` | `:state`, `:source`, `:time-ms`, `:length-ms`, `:volume`, `:muted?`, `:rate` and `:seekable?`. Unknown values are nil. |
| `(wait! p)`, `(wait! p timeout-ms)` | Park until playback ends, stops or fails, or the timeout passes, and return the state. |
| `(metadata source)`, `(metadata source {:timeout-ms n})` | Tags of a file or URL, plus `:duration-ms`. Takes up to 5 seconds by default. |
| `(metadata p)` | Tags of what the player is playing, including a stream's `:now-playing`. |
| `(metadata source {:art? true})` | Also finds cover art, in the file or beside it: `:artwork-url` is a `file://` URL of a copy in VLC's art cache. |
| `(version)` | The loaded libVLC's version string. |
| `(available?)` | Whether libVLC can be loaded. It loads it if it can. A failure isn't remembered, so a program can install VLC and ask again. |
| `(use-library! path)` | Load libVLC from `path` instead of looking for an installed VLC, for a copy an application downloaded or ships. It wins over `SKEIN_VLC_LIBRARY`. Call it before anything uses libVLC. |
| `(configure! {:options [...]})` | Extra libVLC options, such as `["--aout=adummy"]`, before the first player or metadata call. |

Tags use the names in libVLC's `libvlc_meta_t`, such as `:title`, `:artist`, `:album`, `:genre`, `:date`, `:track-number`, `:album-artist` and `:artwork-url`. Only tags the source has appear. libVLC reports the file name as `:title` when a file has no title tag. Time and length are reported in coarse steps, and `:time-ms` stays 0 for the first few hundred milliseconds of playback.

One libVLC instance serves the whole process, as libVLC recommends. It starts on first use with `--no-video --quiet` plus any options given to `configure!`, and lasts as long as the process.

## Shipping to Windows users

Every libVLC call passes pointers, integers and floats only. There are no structs by value, variadic calls or callbacks, so the bindings don't depend on the parts of `skein.ffi` that are arm64-only today. The bindings have been tested on macOS (Apple Silicon) but not yet on Windows.

To ship without asking users to install VLC, copy `libvlc.dll`, `libvlccore.dll` and the `plugins` folder from a 64-bit VLC 3 install into your application. Set `SKEIN_VLC_LIBRARY` to the bundled `libvlc.dll`. VLC finds `plugins` beside `libvlccore.dll`. You can delete plugins you don't need, such as video outputs and filters, to shrink the bundle. libVLC is LGPL 2.1: ship it as separate DLLs and include its license and source offer.

## Tests

```sh
make test
```

The tests play `tests/fixtures/silence.flac`, two seconds of tagged silence, through the real audio output, so they make no sound. `make fixture` regenerates it with ffmpeg.
