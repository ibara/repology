/+
 + Copyright (c) 2024 Brian Callahan <bcallah@openbsd.org>
 +
 + Permission to use, copy, modify, and distribute this software for any
 + purpose with or without fee is hereby granted, provided that the above
 + copyright notice and this permission notice appear in all copies.
 +
 + THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 + WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 + MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 + ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 + WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 + ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 + OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 +/

import std.stdio;
import std.algorithm;
import std.getopt;
import std.json;
import std.meta;
import std.range;
import std.net.curl;

struct Options
{
    string repo,
           begin,
           end,
           search,
           maintainer,
           category,
           inrepo,
           notinrepo,
           repos,
           families,
           repos_newest,
           families_newest;

    bool newest,
         outdated,
         problematic,
         sort_package,
         all,
         vers;
}

int main(string[] args)
{
    Options options;
    JSONValue json;
    string[] pkgs;
    string uri = "https://repology.org/api/v1/project";
    string[string] queryParts = null;

    version (OpenBSD) options.repo = "openbsd";
    else version (FreeBSD) options.repo = "freebsd";
    else version (NetBSD) options.repo = "pkgsrc_current";
    else version (OSX) options.repo = "homebrew";
    else version (Windows) options.repo = "chocolatey";
    else version (linux) {
        import std.process;
        import std.string;
        string distro, release;
        auto p = pipeProcess(["cat", "/etc/os-release"], Redirect.stdout);
        scope(exit) wait(p.pid);
        foreach (line; p.stdout.byLine) {
            if (line.startsWith("ID=")) {
                auto id = line.split("=");
                distro = id[1].idup;
            } else if (line.startsWith("VERSION_ID=")) {
                auto versionid = line.split("=");
                release = versionid[1].idup;
            }
        }
        switch (distro) {
        case "alpine":
            options.repo = distro ~ "_edge";
            break;
        case "debian":
            options.repo = distro ~ "_unstable";
            break;
        case "fedora":
            options.repo = distro ~ "_rawhide";
            break;
        case "ubuntu":
            options.repo = distro ~ "_" ~
                release.strip("\"").replaceFirst(".", "_");
            break;
        default:
            stderr.writeln("repology: specify your repo with the --repo flag");
        }
    } else {
        stderr.writeln("repology: specify your repo with the --repo flag");
    }

    auto opts = getopt(
        args,
        "repo", "string", &options.repo,
        "begin", "string", &options.begin,
        "end", "string", &options.end,
        "search", "string", &options.search,
        "maintainer", "string", &options.maintainer,
        "category", "string", &options.category,
        "inrepo", "string", &options.inrepo,
        "notinrepo", "string", &options.notinrepo,
        "repos", "string", &options.repos,
        "families", "string", &options.families,
        "repos_newest", "string", &options.repos_newest,
        "families_newest", "string", &options.families_newest,
        "newest", "boolean", &options.newest,
        "outdated", "boolean", &options.outdated,
        "problematic", "boolean", &options.problematic,
        "sort_package", "boolean", &options.sort_package,
        "all", "boolean", &options.all,
        "version", "Print version information.", &options.vers
    );

    if (opts.helpWanted) {
        defaultGetoptPrinter("usage: repology [options] [package ...]",
            opts.options);
        return 1;
    }

    if (options.vers) {
        writeln("1.7.3 (29 Dec 2024)");
        return 1;
    }

    switch (options.repo) {
    case "alpine":
        options.repo = "alpine_edge";
        break;
    case "debian":
        options.repo = "debian_unstable";
        break;
    case "fedora":
        options.repo = "fedora_rawhide";
        break;
    case "pkgsrc":
        options.repo = "pkgsrc_current";
        break;
    default:
        {}
    }

    if (!options.all) {
        if (!options.inrepo)
            options.inrepo = options.repo;
    }

    enum queryOptions = [__traits(allMembers, Options)]
        .filter!(a => !["repo", "begin", "end", "repos", "sort_package"].canFind(a));
    static foreach (member; queryOptions) {
        if (mixin(`options.` ~ member)) {
            alias T = typeof(mixin(`options.` ~ member));
            static if (is(T == bool))
                queryParts[member] = "1";
            else
                queryParts[member] = mixin(`options.` ~ member);
        }
    }

    string query = "?" ~ queryParts.byKeyValue.map!(a => a.key ~ "=" ~ a.value).join("&");
    if (args.length == 1) {
        uri ~= "s/";
        if (options.begin)
            uri ~= options.begin ~ "/";
        else if (options.end)
            uri ~= ".." ~ options.end ~ "/";
        auto res = get(uri ~ query);
        json = parseJSON(res);
        foreach (obj; json.object)
            pkgs ~= process(obj, options);
    } else {
        foreach (arg; args[1 .. $]) {
            auto res = get(uri ~ "/" ~ arg ~ query);
            json = parseJSON(res);
            pkgs ~= process(json, options);
        }
    }
    pkgs.sort;
    foreach (pkg; pkgs) {
        if (!pkg.empty)
            writeln(pkg);
    }

    return 0;
}

string[] process(JSONValue json, Options options)
{
    JSONValue[] j;
    string[] info;
    string latest;
    bool hasmaintainer, havelatest;

    switch (options.repo) {
    case "alpine_3_20":
    case "alpine_3_21":
    case "alpine_edge":
    case "debian_10":
    case "debian_11":
    case "debian_12":
    case "debian_13":
    case "debian_experimental":
    case "debian_unstable":
    case "freebsd":
    case "openbsd":
    case "pkgsrc_current":
    case "ubuntu_24_04":
    case "ubuntu_24_04_backports":
    case "ubuntu_24_10":
    case "ubuntu_24_10_backports":
    case "ubuntu_25_04":
    case "ubuntu_25_04_proposed":
        hasmaintainer = true;
        break;
    default:
        hasmaintainer = false;
    }

    foreach (obj; json.array) {
        switch (obj["status"].str) {
        case "newest":
            latest = obj["version"].str;
            havelatest = true;
            break;
        case "devel":
        case "unique":
            if (!havelatest) {
                latest = obj["version"].str;
                havelatest = true;
            }
            break;
        case "noscheme":
            if (!havelatest) {
                latest = "noscheme";
                havelatest = true;
            }
            break;
        case "rolling":
            if (!havelatest) {
                latest = "rolling";
                havelatest = true;
            }
            break;
        default:
            break;
        }
        if (options.all) {
            j ~= obj;
        } else {
            if (obj["repo"].str == options.repo)
                j ~= obj;
        }
    }

    foreach (obj; j) {
        string tmp;
        if (options.all) {
            tmp ~= obj["repo"].str ~ " ";
            tmp ~= obj["visiblename"].str ~ " ";
        }
        if (!options.all) {
            if (options.sort_package)
                tmp ~= obj["binname"].str ~ " ";
            if (options.repo == "chocolatey")
                tmp ~= obj["binname"].str ~ " ";
            else
                tmp ~= obj["srcname"].str ~ " ";
        }
        string color;
        switch (obj["status"].str) {
        case "newest":
            color = "32";
            break;
        case "outdated":
            color = "31";
            break;
        case "devel":
        case "rolling":
        case "unique":
            color = "36";
            break;
        case "legacy":
            color = "33";
            break;
        case "noscheme":
            color = "35";
            break;
        case "incorrect":
        case "untrusted":
        case "ignored":
            color = "34";
            break;
        default:
            color = "32";
        }
        string ver = "\033[" ~ color ~ "m" ~ obj["version"].str ~ "\033[0m";
        if (!options.all && hasmaintainer) {
            string maintainer = "";
            auto maintainers = obj["maintainers"].array;
            foreach (i; 0 .. maintainers.length) {
                maintainer ~= maintainers[i].str;
                if (i < maintainers.length - 1)
                    maintainer ~= " ";
            }
            tmp ~= ver ~ " " ~ latest ~ " " ~ maintainer;
        } else {
            tmp ~= ver ~ " " ~ latest;
        }
        info ~= tmp;
    }

    return info;
}
