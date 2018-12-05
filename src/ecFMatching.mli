open EcFol
open EcIdent
open EcEnv
open EcPattern

(* ---------------------------------------------------------------------- *)
exception Matches
exception NoMatches
exception CannotUnify
exception NoNext

type environment = {
    env_hyps             : EcEnv.LDecl.hyps;
    env_unienv           : EcUnify.unienv;
    env_red_info_p       : EcReduction.reduction_info;
    env_red_info_a       : EcReduction.reduction_info;
    env_restore_unienv   : EcUnify.unienv option;
    env_subst            : Psubst.p_subst;
    env_current_binds    : pbindings;
    env_meta_restr_binds : pbindings Mid.t;
    env_fmt              : Format.formatter;
    env_ppe              : EcPrinting.PPEnv.t;
    env_meta_vars        : Sid.t;
    (* FIXME : ajouter ici les stratégies *)
  }

type pat_continuation =
  | ZTop
  | Znamed     of pattern * meta_name * pbindings option * pat_continuation

  (* Zor (cont, e_list, ne) :
       - cont   : the continuation if the matching is correct
       - e_list : if not, the sorted list of next engines to try matching with
       - ne     : if no match at all, then take the nengine to go up
   *)
  | Zor        of pat_continuation * engine list * nengine

  (* Zand (before, after, cont) :
       - before : list of couples (form, pattern) that has already been checked
       - after  : list of couples (form, pattern) to check in the following
       - cont   : continuation if all the matches succeed
   *)
  | Zand       of (axiom * pattern) list
                  * (axiom * pattern) list
                  * pat_continuation

  | Zbinds     of pat_continuation * pbindings

and engine = {
    e_head         : axiom;
    e_pattern      : pattern;
    e_continuation : pat_continuation;
    e_env          : environment;
  }

and nengine = {
    ne_continuation : pat_continuation;
    ne_env          : environment;
  }


val search          : ?ppe:EcPrinting.PPEnv.t -> ?fmt:Format.formatter ->
                      form -> pattern -> LDecl.hyps ->
                      EcReduction.reduction_info ->
                      EcReduction.reduction_info -> EcUnify.unienv ->
                      (Psubst.p_subst * environment) option

val search_eng      : engine -> nengine option

val mkenv           : ?ppe:EcPrinting.PPEnv.t -> ?fmt:Format.formatter ->
                      LDecl.hyps -> EcReduction.reduction_info ->
                      EcReduction.reduction_info -> EcUnify.unienv -> environment

val mkengine        : axiom -> pattern -> environment -> engine
val mk_engine       : ?ppe:EcPrinting.PPEnv.t -> ?fmt:Format.formatter ->
                      form -> pattern -> LDecl.hyps ->
                      EcReduction.reduction_info ->
                      EcReduction.reduction_info -> EcUnify.unienv -> engine

val pattern_of_form : bindings -> form -> pattern

val rewrite_term    : engine -> EcFol.form -> pattern

val match_is_full   : environment -> bool