repology
========
`repology` is a command line interface for Repology.org.
It is primarily designed for
[OpenBSD](https://www.openbsd.org/),
[FreeBSD](https://www.freebsd.org/),
and
[NetBSD](https://www.netbsd.org/)
developers, users, and port maintainers.

It is written in
[D](https://dlang.org/).

Building
--------
If you are using
[DMD](https://wiki.dlang.org/DMD):
```sh
$ make
$ sudo make install
```

If you are using
[LDC](https://wiki.dlang.org/LDC):
```sh
$ make DMD=ldmd2
$ sudo make install
```

If you are using
[GDC](https://wiki.dlang.org/GDC):
```sh
$ make DMD=gdc DFLAGS='-O2 -pipe -frelease -finline -o repology'
$ sudo make install
```

Usage examples
--------------
Get information on the Digital Mars D compiler from the default repository:
* `repology dmd`

Get information on the Digital Mars D compiler from all repositories:
* `repology --all dmd`

Get 200 items from pkgsrc:
* `repology --repo pkgsrc`

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
