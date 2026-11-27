(** Pure request dispatch and Tiny_httpd server entry point for [mmwiki]. *)

val dispatch
  :  root:string
  -> meth:Tiny_httpd.Meth.t
  -> path_components:string list
  -> query:(string * string) list
  -> Tiny_httpd.Response.t

val serve : root:string -> addr:string -> port:int -> unit
