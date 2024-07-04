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
         sort_package;
}

void main(string[] args)
{
    Options options;
    JSONValue json;
    string[] pkgs;
    string uri = "https://repology.org/api/v1/project";
    string[string] queryParts = null;
    bool v;

    version (FreeBSD) options.repo = "freebsd";
    else version (NetBSD) options.repo = "pkgsrc_current";
    else options.repo = "openbsd";

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
        "version", "Print version information.", &v
    );

    if (opts.helpWanted) {
        defaultGetoptPrinter("usage: repology [options] [package ...]",
            opts.options);
        return;
    }

    if (v) {
        writeln("1.1.0 (02 Jul 2024)");
        return;
    }

    if (options.repo == "pkgsrc")
        options.repo = "pkgsrc_current";

    enum queryOptions = [__traits(allMembers, Options)]
        .filter!(a => !["repo", "begin", "end", "repos", "sort_package"].canFind(a));
    static foreach (member; queryOptions) {
        if (mixin(`options.` ~ member)) {
            alias T = typeof(mixin(`options.` ~ member));
            static if (is(T == bool)) {
                queryParts[member] = "1";
            } else {
                queryParts[member] = mixin(`options.` ~ member);
            }
        }
    }

    string query = "?" ~ queryParts.byKeyValue.map!(a => a.key ~ "=" ~ a.value).join("&");
    if (args.length == 1) {
        if (query == "?")
            query ~= "inrepo=" ~ options.repo;
        uri ~= "s/";
        if (options.begin)
            uri ~= options.begin ~ "/";
        else if (options.end)
            uri ~= ".." ~ options.end ~ "/";
        auto resMulti = get(uri ~ query);
        json = parseJSON(resMulti);
        pkgs = processMulti(json, options);
        foreach (pkg; pkgs)
            writeln(pkg);
    } else {
        foreach (arg; args[1 .. $]) {
            auto res = get(uri ~ "/" ~ arg ~ query);
            json = parseJSON(res);
            string pkg = processSingle(json, options);
            writeln(pkg);
        }
    }
}

string[] processMulti(JSONValue json, Options options)
{
    string[] ret;

    foreach (obj; json.object)
        ret ~= processSingle(obj, options);

    ret.sort;

    return ret;
}

string processSingle(JSONValue json, Options options)
{
    JSONValue[] j;
    string info, latest;
    bool first = true;

    foreach (obj; json.array) {
        switch (obj["status"].str) {
        case "newest":
        case "devel":
        case "unique":
        case "noscheme":
        case "rolling":
            latest = obj["version"].str;
            break;
        default:
            break;
        }
        if (obj["repo"].str == options.repo)
            j ~= obj;
    }

    foreach (obj; j) {
        if (!first)
            info ~= "\n";
        if (!options.repo)
            info ~= obj["repo"].str ~ " ";
        if (options.sort_package)
            info ~= obj["binname"].str ~ " ";
        info ~= obj["srcname"].str ~ " ";
        string color;
        switch (obj["status"].str) {
        case "newest":
            color = "32";
            break;
        case "outdated":
            color = "31";
            break;
        case "devel":
        case "unique":
            color = "36";
            break;
        case "legacy":
        case "incorrect":
            color = "33";
            break;
        case "noscheme":
        case "rolling":
            color = "35";
            break;
        case "untrusted":
        case "ignored":
            color = "34";
            break;
        default:
            color = "32";
        }
        string ver = "\033[" ~ color ~ "m" ~ obj["version"].str ~ "\033[0m";
        string maintainer = "";
        auto maintainers = obj["maintainers"].array;
        foreach (i; 0 .. maintainers.length) {
            maintainer ~= maintainers[i].str;
            if (i < maintainers.length - 1)
                maintainer ~= " ";
        }
        info ~= ver ~ " " ~ latest ~ " " ~ maintainer;
        first = false;
    }

    return info;
}
