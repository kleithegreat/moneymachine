open Core

let html_escape s =
  let buf = Buffer.create (String.length s) in
  String.iter s ~f:(function
    | '&' -> Buffer.add_string buf "&amp;"
    | '<' -> Buffer.add_string buf "&lt;"
    | '>' -> Buffer.add_string buf "&gt;"
    | '"' -> Buffer.add_string buf "&quot;"
    | '\'' -> Buffer.add_string buf "&#39;"
    | c -> Buffer.add_char buf c);
  Buffer.contents buf
;;

let is_unreserved_path_char = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' | '.' | '~' | '/' -> true
  | _ -> false
;;

let url_encode_path path =
  let buf = Buffer.create (String.length path) in
  String.iter path ~f:(fun c ->
    if is_unreserved_path_char c
    then Buffer.add_char buf c
    else Buffer.add_string buf (sprintf "%%%02X" (Char.to_int c)));
  Buffer.contents buf
;;

let url_encode_query s =
  let buf = Buffer.create (String.length s) in
  String.iter s ~f:(fun c ->
    match c with
    | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '-' | '_' | '.' | '~' ->
      Buffer.add_char buf c
    | ' ' -> Buffer.add_char buf '+'
    | _ -> Buffer.add_string buf (sprintf "%%%02X" (Char.to_int c)));
  Buffer.contents buf
;;

let render_markdown_html md =
  let doc = Cmarkit.Doc.of_string ~heading_auto_ids:true ~strict:false md in
  Cmarkit_html.of_doc ~safe:true doc
;;

let css =
  {|
:root { color-scheme: light dark; --bg: #fdfdfd; --fg: #181a1f; --muted: #5f6672; --panel: #f4f5f7; --border: #dde1e7; --accent: #0969da; --code-bg: #f1f3f5; }
@media (prefers-color-scheme: dark) {
  :root { --bg: #0d1117; --fg: #e6edf3; --muted: #8b949e; --panel: #161b22; --border: #30363d; --accent: #58a6ff; --code-bg: #1c2128; }
}
* { box-sizing: border-box; }
body { margin: 0; font-family: system-ui, -apple-system, sans-serif; background: var(--bg); color: var(--fg); line-height: 1.6; }
.layout { display: grid; grid-template-columns: 290px minmax(0, 1fr); min-height: 100vh; }
aside { background: var(--panel); border-right: 1px solid var(--border); padding: 1rem; overflow-y: auto; max-height: 100vh; position: sticky; top: 0; }
aside h1 { font-size: 1rem; margin: 0 0 0.75rem 0; }
aside form { display: flex; gap: 0.35rem; margin-bottom: 1rem; }
aside input[type="search"] { flex: 1; padding: 0.35rem 0.5rem; border: 1px solid var(--border); border-radius: 4px; background: var(--bg); color: var(--fg); font-size: 0.85rem; }
aside button { padding: 0.35rem 0.6rem; border: 1px solid var(--border); border-radius: 4px; background: var(--bg); color: var(--fg); cursor: pointer; font-size: 0.85rem; }
aside h2 { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.04em; color: var(--muted); margin: 1rem 0 0.35rem 0; }
aside ul { list-style: none; margin: 0; padding: 0; }
aside li a { display: block; padding: 0.18rem 0.35rem; border-radius: 4px; color: var(--fg); text-decoration: none; font-size: 0.86rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
aside li a:hover, aside li a.active { background: var(--border); color: var(--accent); }
main { padding: 1.5rem 2.5rem; max-width: 960px; }
header.topbar { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 0.5rem; padding-bottom: 0.75rem; margin-bottom: 1.25rem; border-bottom: 1px solid var(--border); font-size: 0.85rem; color: var(--muted); }
header.topbar a { color: var(--accent); text-decoration: none; }
a { color: var(--accent); }
pre, code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background: var(--code-bg); border-radius: 4px; }
code { padding: 0.12rem 0.32rem; font-size: 0.88em; }
pre { padding: 0.85rem; overflow-x: auto; }
pre code { padding: 0; background: none; }
table { border-collapse: collapse; margin: 1rem 0; width: 100%; }
th, td { border: 1px solid var(--border); padding: 0.45rem 0.65rem; text-align: left; }
th { background: var(--panel); }
blockquote { border-left: 3px solid var(--border); margin: 1rem 0; padding: 0.15rem 1rem; color: var(--muted); }
@media (max-width: 820px) { .layout { grid-template-columns: 1fr; } aside { position: static; max-height: none; border-right: none; border-bottom: 1px solid var(--border); } main { padding: 1rem; } }
|}
;;

let render_sidebar ~docs ~active_path ~query =
  let grouped =
    List.fold docs ~init:[] ~f:(fun acc (doc : Catalog.doc_entry) ->
      match List.Assoc.find acc doc.category ~equal:String.equal with
      | Some items ->
        List.Assoc.add acc doc.category (items @ [ doc ]) ~equal:String.equal
      | None -> acc @ [ doc.category, [ doc ] ])
  in
  let buf = Buffer.create 4096 in
  Buffer.add_string buf "<aside>";
  Buffer.add_string
    buf
    {|<h1><a href="/view/wiki/index.md" style="text-decoration:none;color:inherit">moneymachine wiki</a></h1>|};
  Buffer.add_string
    buf
    (sprintf
       {|<form action="/search" method="get"><input type="search" name="q" value="%s" placeholder="Search docs..."/><button type="submit">Go</button></form>|}
       (html_escape query));
  List.iter grouped ~f:(fun (cat, items) ->
    Buffer.add_string buf (sprintf "<h2>%s</h2><ul>" (html_escape cat));
    List.iter items ~f:(fun (doc : Catalog.doc_entry) ->
      let cls =
        match active_path with
        | Some p when String.equal p doc.path -> " class=\"active\""
        | Some _ | None -> ""
      in
      let href = "/view/" ^ url_encode_path doc.path in
      let label = html_escape doc.title in
      Buffer.add_string
        buf
        (sprintf
           "<li><a%s href=\"%s\" title=\"%s\">%s</a></li>"
           cls
           href
           (html_escape doc.path)
           label));
    Buffer.add_string buf "</ul>");
  Buffer.add_string buf "</aside>";
  Buffer.contents buf
;;

let shell ~docs ~active_path ~page_title ~topbar ~body_html ?(query = "") () =
  let sidebar = render_sidebar ~docs ~active_path ~query in
  sprintf
    {|<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>%s — moneymachine wiki</title>
<style>%s</style>
</head>
<body>
<div class="layout">
%s
<main>
<header class="topbar">%s</header>
%s
</main>
</div>
</body>
</html>
|}
    (html_escape page_title)
    css
    sidebar
    topbar
    body_html
;;

let render_doc_page ~docs ~rel_path ~title ~markdown =
  let raw_href = "/raw/" ^ url_encode_path rel_path in
  let topbar =
    sprintf
      "<span>%s</span><span><a href=\"%s\">Raw Markdown</a> &middot; <a \
       href=\"/api/index\">JSON Index</a></span>"
      (html_escape rel_path)
      raw_href
  in
  let body_html = render_markdown_html markdown in
  shell ~docs ~active_path:(Some rel_path) ~page_title:title ~topbar ~body_html ()
;;

let render_text_page ~docs ~rel_path ~content =
  let raw_href = "/raw/" ^ url_encode_path rel_path in
  let topbar =
    sprintf
      "<span>%s</span><span><a href=\"%s\">Raw File</a> &middot; <a \
       href=\"/api/index\">JSON Index</a></span>"
      (html_escape rel_path)
      raw_href
  in
  let body_html =
    sprintf
      "<h1>%s</h1><pre><code>%s</code></pre>"
      (html_escape rel_path)
      (html_escape content)
  in
  shell ~docs ~active_path:(Some rel_path) ~page_title:rel_path ~topbar ~body_html ()
;;

let render_dir_page ~docs ~rel_dir ~entries =
  let prefix = if String.is_empty rel_dir then "" else rel_dir ^ "/" in
  let items =
    List.map entries ~f:(fun name ->
      let full = prefix ^ name in
      sprintf
        "<li><a href=\"/view/%s\">%s</a></li>"
        (url_encode_path full)
        (html_escape name))
    |> String.concat ~sep:"\n"
  in
  let topbar =
    sprintf
      "<span>Directory: %s</span><span><a href=\"/api/index\">JSON Index</a></span>"
      (html_escape (if String.is_empty rel_dir then "/" else rel_dir))
  in
  let body_html = sprintf "<h1>Index of %s</h1><ul>%s</ul>" (html_escape rel_dir) items in
  shell ~docs ~active_path:None ~page_title:("Index: " ^ rel_dir) ~topbar ~body_html ()
;;

let render_search_page ~docs ~query ~hits =
  let api_href = "/api/search?q=" ^ url_encode_query query in
  let topbar =
    sprintf
      "<span>Search results (%d)</span><span><a href=\"%s\">JSON Results</a></span>"
      (List.length hits)
      api_href
  in
  let items =
    if List.is_empty hits
    then "<p>No matching documentation found.</p>"
    else
      List.map hits ~f:(fun (hit : Catalog.search_hit) ->
        sprintf
          "<li><a href=\"/view/%s\"><strong>%s</strong></a> <small>(%s, line \
           %d)</small><br/><code>%s</code></li>"
          (url_encode_path hit.path)
          (html_escape hit.title)
          (html_escape hit.path)
          hit.line_no
          (html_escape hit.snippet))
      |> String.concat ~sep:"\n"
      |> fun ul -> "<ul>" ^ ul ^ "</ul>"
  in
  let body_html = sprintf "<h1>Search: %s</h1>%s" (html_escape query) items in
  shell
    ~docs
    ~active_path:None
    ~page_title:("Search: " ^ query)
    ~topbar
    ~body_html
    ~query
    ()
;;

let render_error_page ~docs ~code ~message =
  let topbar =
    sprintf
      "<span>HTTP %d</span><span><a href=\"/view/wiki/index.md\">Home</a></span>"
      code
  in
  let body_html = sprintf "<h1>HTTP %d</h1><p>%s</p>" code (html_escape message) in
  shell
    ~docs
    ~active_path:None
    ~page_title:(sprintf "Error %d" code)
    ~topbar
    ~body_html
    ()
;;
