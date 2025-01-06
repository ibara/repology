repology
========
`repology` is a command line interface for
[Repology.org](https://repology.org/)
written in
[D](https://dlang.org/).

`repology` will attempt to autodetect your operating system for
selecting a repository when `--repo` is not specified. This
autodetection works for the BSDs, macOS, and Windows.

Autodetection works partially for Linux-based operating systems.
Currently, Alpine, Debian, Fedora, and Ubuntu are autodetected.

Autodetection works partially for Illumos-based operating systems.
Currently, OpenIndiana is autodetected.

Building
--------
```sh
$ ./configure
$ make
$ sudo make install
```

Usage examples
--------------
Get information on the Digital Mars D compiler from your operating
system's autodetected repository:
* `repology dmd`

Get information on the Digital Mars D compiler from all repositories:
* `repology --all dmd`

Get 200 items from pkgsrc:
* `repology --repo pkgsrc_current`

Get information about both Chrome and Firefox from FreeBSD ports:
* `repology --repo freebsd chromium firefox`

Get up to 200 packages maintained by ports@openbsd.org,
starting with coreutils:
* `repology --maintainer ports@openbsd.org --begin coreutils`

See the
[manual page](repology.1)
for more information.

License
-------
ISC License. See
[`LICENSE`](LICENSE)
for more information.
