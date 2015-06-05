(* -------------------------------------------------------------------- *)
open EcIdent
open EcPath
open EcTypes
open EcEnv
open EcFol
open EcModules

(* -------------------------------------------------------------------- *)
val lmd_app : (EcIdent.t * memtype) -> lmd_form -> lmd_form
val lmd_forall_imp : lmd_form -> lmd_form -> form

(* -------------------------------------------------------------------- *)
val oplus : memtype -> ident -> ident -> ident -> form -> form
val curly : env -> expr -> lmd_form -> lmd_form -> lmd_form

(* -------------------------------------------------------------------- *)
exception NoWpMuhoare

(* -------------------------------------------------------------------- *)
val wp_muhoare : env -> stmt -> lmd_form -> lmd_form

val wp_pre : env -> memtype -> xpath -> funsig -> lmd_form -> lmd_form
val wp_ret : env -> memtype -> prog_var -> expr -> lmd_form -> lmd_form

val max_wp : stmt -> int
