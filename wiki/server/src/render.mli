(** Offline HTML and Markdown page rendering for [mmwiki]. *)

val html_escape : string -> string
val url_encode_path : string -> string
val render_markdown_html : string -> string

val render_doc_page
  :  docs:Catalog.doc_entry list
  -> rel_path:string
  -> title:string
  -> markdown:string
  -> string

val render_text_page
  :  docs:Catalog.doc_entry list
  -> rel_path:string
  -> content:string
  -> string

val render_dir_page
  :  docs:Catalog.doc_entry list
  -> rel_dir:string
  -> entries:string list
  -> string

val render_search_page
  :  docs:Catalog.doc_entry list
  -> query:string
  -> hits:Catalog.search_hit list
  -> string

val render_error_page
  :  docs:Catalog.doc_entry list
  -> code:int
  -> message:string
  -> string
