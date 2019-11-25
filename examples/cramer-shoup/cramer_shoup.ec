require import AllCore IntDiv List Distr Dexcepted PKE.
require import StdOrder StdBigop.
import RealOrder Bigreal.

require TCR RndExcept.

(** DiffieHellman *)
require import DiffieHellman.
import DDH G Gabs ZModE.

axiom prime_order : prime order.

lemma unit_nz (x : exp) : unit x <=> x <> ZModE.zero.
proof.
split=> //=.
+ by apply/contraLR=> /= ->; exact/ZModpRing.unitr0.
rewrite -{1}asintK /zero -negP -eq_inzmod=> /= x_neq_0.
move: (modinv_prime _ prime_order _ x_neq_0)=> [invx] h.
exists (inzmod invx); rewrite -asintK -inzmodM -eq_inzmod mulzC h.
by rewrite pmod_small // gt1_prime prime_order.
qed.

instance field with exp
  op rzero = ZModE.zero
  op rone  = ZModE.one
  op add   = ZModE.( + )
  op opp   = ZModE.([-])
  op mul   = ZModE.( * )
  op expr  = ZModpRing.exp
  op ofint = ZModpRing.ofint
  op inv   = ZModE.inv

  proof oner_neq0 by exact/ComRing.oner_neq0
  proof addr0     by exact/ZModpRing.addr0
  proof addrA     by exact/ZModpRing.addrA
  proof addrC     by exact/ZModpRing.addrC
  proof addrN     by exact/ZModpRing.addrN
  proof mulr1     by exact/ZModpRing.mulr1
  proof mulrA     by exact/ZModpRing.mulrA
  proof mulrC     by exact/ComRing.mulrC
  proof mulrDl    by exact/ZModpRing.mulrDl
  proof mulrV     by (move=> x; rewrite -unit_nz=> /ZModpRing.mulrV)
  proof expr0     by exact/ZModpRing.expr0
  proof exprS     by exact/ZModpRing.exprS
  proof exprN     by (move=> x n _; exact/ZModpRing.exprN)
  proof ofint0    by exact/ZModpRing.ofint0
  proof ofint1    by exact/ZModpRing.ofint1
  proof ofintS    by exact/ZModpRing.ofintS
  proof ofintN    by exact/ZModpRing.ofintN.

theory Ad1.
  clone import RndExcept as RndE with
    type input <- unit,
    type t     <- exp,
    op   d     <- fun _ => dp,
    type out   <- bool
    proof *.
    realize d_ll. by move=> _; exact/dp_ll. qed.

  clone include Adversary1_1 with
    op n <- order
    proof *.
  realize gt1_n by exact/gt1_prime/prime_order.
  realize d_uni by move=> _ x; rewrite dp1E.
end Ad1.

theory DDH_ex.
  module DDH0_ex (A:Adversary) = {
    proc main() : bool = {
      var b, x, y;
      x <$ dp \ (pred1 ZModE.zero);
      y <$ dp;
      b <@ A.guess(g ^ x, g ^ y, g ^ (x*y));
      return b;
    }
  }.

  module DDH1_ex (A:Adversary) = {
    proc main() : bool = {
      var b, x, y, z;

      x <$ dp \ (pred1 ZModE.zero);
      y <$ dp;
      z <$ dp;
      b <@ A.guess(g ^ x, g ^ y, g ^ z);
      return b;
    }
  }.

  section PROOFS.

  declare module A:Adversary.  

  axiom A_ll : islossless A.guess.

  local module Addh0 : Ad1.ADV = {
    proc a1 () = {
      return ((), ZModE.zero);
    }

    proc a2 (x : exp) = {
      var b, y;

      y <$ dp;
      b <@ A.guess(g ^ x, g ^ y, g ^ (x * y));
      return b;
    }
  }.

  local module Addh1 = {
    proc a1 = Addh0.a1

    proc a2 (x : exp) = {
      var b, y, z;

      y <$ dp;
      z <$ dp;
      b <@ A.guess(g ^ x, g ^ y, g ^ z);
      return b;
    }
  }.

  local lemma a1_ll : islossless Addh0.a1.
  proof. by proc; auto. qed.

  lemma adv_DDH_DDH_ex &m :
     `| Pr[DDH0_ex(A).main()@ &m : res] - Pr[DDH1_ex(A).main()@ &m : res] | <=
     `| Pr[DDH0(A).main()@ &m : res] - Pr[DDH1(A).main()@ &m : res] | + 2%r / order%r.
  proof.
    have /= H0 := Ad1.pr_abs Addh0 a1_ll _ &m (fun b _ => b).      
    + by proc;call A_ll;rnd;skip;rewrite /= dp_ll.
    have /= H1 := Ad1.pr_abs Addh1 a1_ll _ &m (fun b _ => b). 
    + by proc;call A_ll;do !rnd;skip;rewrite /= dp_ll.
    have -> : 2%r / order%r = inv order%r + inv order%r.
    + field; smt(gt0_order lt_fromint).
    have <- : Pr[Ad1.MainE(Addh0).main() @ &m : res] = Pr[DDH0_ex(A).main() @ &m : res].
    + by byequiv => //;proc;inline *;sim;auto.
    have <- : Pr[Ad1.MainE(Addh1).main() @ &m : res] = Pr[DDH1_ex(A).main() @ &m : res].
    + by byequiv => //;proc;inline *;sim;auto.
    have <- : Pr[Ad1.Main(Addh0).main() @ &m : res] = Pr[DDH0(A).main() @ &m : res].
    + by byequiv => //;proc;inline *;sim;auto.
    have <- /# : Pr[Ad1.Main(Addh1).main() @ &m : res] = Pr[DDH1(A).main() @ &m : res].
    by byequiv => //;proc;inline *;sim;auto.
  qed.

  end section PROOFS.

end DDH_ex.
import DDH_ex.

(** Target Collision Resistance *)
clone import TCR as TCR_H with 
  type t_from <- group * group * group,
  type t_to   <- exp.

axiom dk_ll : is_lossless dk.

(** Cramer Shoup Encryption *)

clone import PKE as PKE_ with
   type pkey = K * group * group * group * group * group,
   type skey = K * group * group * exp * exp * exp * exp * exp * exp,
   type plaintext = group,
   type ciphertext = group * group * group * group.

module CramerShoup : Scheme = {
  proc kg() : pkey * skey = {
    var x1, x2, y1, y2, z1, z2, k, w, g_, pk, sk;
    x1 <$ dp;
    x2 <$ dp;
    y1 <$ dp;
    y2 <$ dp;
    z1 <$ dp;
    z2 <$ dp;
    w  <$ dp \ (pred1 ZModE.zero);
    k  <$ dk;
    g_ <- g ^ w;
    pk <- (k, g, g_, g^x1 * g_^x2, g^y1 * g_^y2, g^z1 * g_^z2);
    sk <- (k, g, g_, x1, x2, y1, y2, z1, z2);
    return (pk, sk);
  }

  proc enc(pk:pkey, m:plaintext) : ciphertext = {
    var k,g,g_,e,f,h,u,a,a_,c,v,d;
    (k,g,g_,e,f,h) = pk;
    u <$ dp;
    a <- g^u; a_ <- g_^u;
    c <- h^u * m;
    v <- H k (a, a_, c);
    d <- e^u * f^(u*v);
    return (a,a_,c,d);
  } 

  proc dec(sk:skey, ci:ciphertext) = {
    var k,g,g_,x1,x2,y1,y2,z1,z2,a,a_,c,d,v;
    (k,g,g_,x1,x2,y1,y2,z1,z2) <- sk;
    (a,a_,c,d) <- ci;
    v <- H k (a, a_, c);
    return (if   d = a ^ (x1 + v * y1) * a_^(x2 + v * y2)
            then Some (c / (a^z1 * a_^z2))
            else None);
  }

}.

(** Correctness of the scheme *)

hoare CramerShoup_correct : Correctness(CramerShoup).main : true ==> res.
proof.
  proc;inline *;auto => /> &m1 x1 _ x2 _ y1 _ y2 _ z1 _ z2 _ w Hw k _ u _.
  have -> /=: (g ^ x1 * g ^ w ^ x2) ^ u *
    (g ^ y1 * g ^ w ^ y2) ^
    (u * H k (g ^ u, g ^ w ^ u, (g ^ z1 * g ^ w ^ z2) ^ u * m{m1})) =
    g ^ u ^
    (x1 + H k (g ^ u, g ^ w ^ u, (g ^ z1 * g ^ w ^ z2) ^ u * m{m1}) * y1) *
    g ^ w ^ u ^
    (x2 + H k (g ^ u, g ^ w ^ u, (g ^ z1 * g ^ w ^ z2) ^ u * m{m1}) * y2).
  + pose h := H _ _.
    rewrite -expM -expD -expM -expM -expD -expM -expD -expM -expM- expM -expD.
    by algebra.
  rewrite -(expgK m{m1}) -expM -expM -expM -expM -expD -expD -expN -expM -expD -expD.
  by algebra.
qed.

(** IND-CCA Security of the scheme *)
module B_DDH (A:CCA_ADV) = {

  module CCA = CCA(CramerShoup, A)

  proc guess(gx gy gz:group): bool = {
    var g_, a, a_, x1,x2,y1,y2,z1,z2,k,e,f,h,m0,m1,b,b',c,v,d,c',pk;
    x1 <$ dp;
    x2 <$ dp;
    y1 <$ dp;
    y2 <$ dp;
    z1 <$ dp;
    z2 <$ dp;
    g_ <- gx;
    a  <- gy;
    a_ <- gz;
    k  <$ dk;
    e  <- g^x1 * g_^x2;
    f  <- g^y1 * g_^y2;
    h  <- g^z1 * g_^z2;
    CCA.log <- [];
    CCA.cstar <- None;
    pk <- (k, g, g_, g^x1 * g_^x2, g^y1 * g_^y2, g^z1 * g_^z2);
    CCA.sk <- (k, g, g_, x1, x2, y1, y2, z1, z2);
    (m0,m1) <- CCA.A.choose(pk);
    b <$ {0,1};
    c <- a^z1 * a_^z2 * (b ? m1 : m0);
    v <- H k (a,a_,c);
    d <- a^(x1 + v*y1) * a_^(x2+v*y2);
    c' <- (a,a_,c,d);
    CCA.cstar <- Some c';
    b' <- CCA.A.guess(c');
    return (b = b');
  }
    
}.

 module B_TCR (A:CCA_ADV) = {
    var log   : ciphertext list
    var cstar : ciphertext option
    var g3    : ( group * group * group) option
    var g_, a, a_, c, d : group
    var w, u , u', x, y, z, alpha, v' : exp
    var k : K
    module O = {
      proc dec(ci:ciphertext) = {
        var m, a,a_,c,d,v;
        m <- None;
        if (size log < PKE_.qD && Some ci <> cstar) {
          log <- ci :: log;
          (a,a_,c,d) <- ci;
          v <- H k (a, a_, c);
          if (a_ <> a^w /\ v = v' /\ (a,a_,c) <> (B_TCR.a, B_TCR.a_,B_TCR.c)) g3 <- Some (a,a_,c);
          m = if (a_ = a^w /\ d = a ^ (x + v*y)) then Some (c / a ^ z)
              else None;
        }
        return m;
      }
    }

    module A = A (O)

    proc c1() = {
      var r';
      log <- [];
      g3 <- None;
      cstar <- None;
      w <$ dp \ (pred1 ZModE.zero);
      u <$ dp;
      u' <$ dp \ (pred1 u);
      g_ <- g ^ w; 
      a <- g^u; a_ <- g_^u';
      r' <$ dp; c <- g^r';
      return (a, a_, c);
    }
    
    proc c2 (k:K) = {
      var m0, m1, b0, e, f, h, r;
      B_TCR.k <- k;
      y <$ dp; f <- g^y;
      z <$ dp; h <- g^z;      
      v' <- H k (a, a_, c);
      x <$ dp; r <$ dp; e <- g^x;
      alpha <- (r - u * (x + v' * y)) / (w*(u'-u));
      d <- g ^ r;
      (m0,m1) <@ A.choose(k, g, g_, e, f, h); 
      cstar <- Some (a,a_,c,d);
      b0 <@ A.guess(a,a_,c,d);
      return (oget g3);    
    }
  }.

lemma CCA_dec_ll (A<:CCA_ADV) : islossless CCA(CramerShoup, A).O.dec.
proof. by proc; inline *; auto. qed.

section Security_Aux.

  declare module A : CCA_ADV {CCA, B_TCR}.
  axiom guess_ll : forall (O <: CCA_ORC{A}), islossless O.dec => islossless A(O).guess.
  axiom choose_ll : forall (O <: CCA_ORC{A}), islossless O.dec => islossless A(O).choose.

  equiv CCA_DDH0 : CCA(CramerShoup, A).main ~ DDH0_ex(B_DDH(A)).main : ={glob A} ==> ={res}.
  proof.   
    proc;inline *;wp.
    call (_: ={glob CCA}); 1: sim.
    swap{1} 9 -8; swap{1} 20 -18; auto.
    call (_: ={glob CCA}); 1: sim.
    auto => &m1 &m2 /> w _ u _ x1 _ x2 _ y1 _ y2 _ z1 _ z2 _ k _ r b _.
    have -> : 
      H k
       (g ^ u, g ^ w ^ u,
        (g ^ z1 * g ^ w ^ z2) ^ u * if b then r.`2 else r.`1) =
      H k
       (g ^ u, g ^ (w * u),
        g ^ u ^ z1 * g ^ (w * u) ^ z2 * if b then r.`2 else r.`1).
    + congr; congr=> //=.
      + by rewrite -expM.
      rewrite -expM -expD -expM -expM -expM -expD.
      by algebra.
    rewrite -expM //=.
    pose h:= H k _.
    do!split; last by smt().
    + by rewrite -expM -expD -expM -expM -expM -expD; algebra.
    + by rewrite -expM -expD -expM -expM -expD -expM -expD -expM -expM -expD; algebra.
    + by rewrite -expM -expD -expM -expM -expM -expD; algebra.
    by rewrite -expM -expD -expM -expM -expD -expM -expD -expM -expM -expD; algebra.
  qed.

  lemma pr_CCA_DDH0 &m : 
    Pr[CCA(CramerShoup, A).main() @ &m : res] = 
    Pr[DDH0_ex(B_DDH(A)).main() @ &m : res].
  proof. by byequiv CCA_DDH0. qed.

  local module G1 = {
    var log     : ciphertext list
    var cstar   : ciphertext option
    var bad     : bool
    var u,u',w  : exp
    var x,x1,x2 : exp
    var y,y1,y2 : exp
    var z,z1,z2 : exp
    var g_: group
    var k       : K

    module O = {
      proc dec(ci:ciphertext) = {
        var m, a,a_,c,d,v;
        m <- None;
        if (size log < PKE_.qD && Some ci <> G1.cstar) {
          log <- ci :: log;
          (a,a_,c,d) <- ci;
          v <- H k (a, a_, c);
          bad <- bad \/ (a_ <> a^w /\ d = a ^ (x1 + v*y1) * a_ ^ (x2 + v * y2));
          m = if (a_ = a^w /\ d = a ^ (x + v*y)) then Some (c / a ^ z)
              else None;
        }
        return m;
      }
    }

    module A = A(O)

    proc a1 () = {
      log <- [];
      cstar <- None;
      bad <- false;
      w <$ dp \ (pred1 ZModE.zero);
      u <$ dp;
      return ((),u);
    }

    proc a2 (u0' : exp) = {
      var m0, m1, b, b0, a, a_, c, d, v, e, f, h;
      u' <- u0';
      g_ <- g ^ w; k  <$ dk;
      a <- g^u; a_ <- g_^u';
      x <$ dp; x2 <$ dp; x1 <- x - w * x2; e <- g^x;
      y <$ dp; y2 <$ dp; y1 <- y - w * y2; f <- g^y;
      z <$ dp; z2 <$ dp; z1 <- z - w * z2; h <- g^z;
      (m0,m1) <@ A.choose(k, g, g_, e, f, h); 
      b <$ {0,1}; 
      c <- a^z1 * a_^z2 * (b ? m1 : m0);
      v <- H k (a, a_, c);
      d <- a^(x1 + v*y1) * a_^(x2+v*y2);
      cstar <- Some (a,a_,c,d);
      b0 <@ A.guess(a,a_,c,d);
      return (b = b0);
    }
  }.

  local equiv DDH1_G1_dec : 
    CCA(CramerShoup, A).O.dec ~ G1.O.dec : 
    ( !G1.bad{2} /\ c{1} = ci{2} /\
      (G1.x{2} = G1.x1{2} + G1.w{2} * G1.x2{2} /\
       G1.y{2} = G1.y1{2} + G1.w{2} * G1.y2{2} /\
       G1.z{2} = G1.z1{2} + G1.w{2} * G1.z2{2}) /\
       CCA.log{1} = G1.log{2} /\ CCA.cstar{1} = G1.cstar{2} /\
       CCA.sk{1} = (G1.k{2}, g, G1.g_{2}, G1.x1{2}, G1.x2{2}, G1.y1{2}, G1.y2{2}, G1.z1{2}, G1.z2{2})) ==>
    (!G1.bad{2} =>
       ={res} /\
       (G1.x{2} = G1.x1{2} + G1.w{2} * G1.x2{2} /\
        G1.y{2} = G1.y1{2} + G1.w{2} * G1.y2{2} /\
        G1.z{2} = G1.z1{2} + G1.w{2} * G1.z2{2}) /\
       CCA.log{1} = G1.log{2} /\ CCA.cstar{1} = G1.cstar{2} /\
       CCA.sk{1} = (G1.k{2}, g, G1.g_{2}, G1.x1{2}, G1.x2{2}, G1.y1{2}, G1.y2{2}, G1.z1{2}, G1.z2{2})).
  proof.
    proc;sp 0 1;inline *;if => //;auto.
    move=> &m1 &m2 /> _ /=;rewrite negb_and /=.
    case: (ci{m2}) => a a_ c d => /=.
    case: (a_ = a ^ G1.w{m2}) => [ -> _ _ | _ _ _ -> ] //=.
    have -> : 
      a ^ (G1.x1{m2} + H G1.k{m2} (a, a ^ G1.w{m2}, c) * G1.y1{m2}) *
      a ^ G1.w{m2} ^ (G1.x2{m2} + H G1.k{m2} (a, a ^ G1.w{m2}, c) * G1.y2{m2}) =
      a ^ (G1.x1{m2} + G1.w{m2} * G1.x2{m2} +
           H G1.k{m2} (a, a ^ G1.w{m2}, c) * (G1.y1{m2} + G1.w{m2} * G1.y2{m2})).
    + by pose h := H _ _; rewrite -expM -expD; algebra.
    by pose h:= H _ _; rewrite -!expM -!expD; algebra.
  qed.

  local lemma G1_dec_ll : islossless G1.O.dec. 
  proof. by proc;inline *;auto. qed.

  local lemma G1_dec_bad : phoare[ G1.O.dec : G1.bad ==> G1.bad ] = 1%r.
  proof. by proc; auto => ? ->. qed.

  local equiv DDH1_G1 : DDH1_ex(B_DDH(A)).main ~ Ad1.Main(G1).main : 
                        ={glob A} ==> !G1.bad{2} => ={res}.
  proof.
    proc;inline *;wp.
    call (_: G1.bad, 
             (
              (G1.x = G1.x1 + G1.w * G1.x2 /\
               G1.y = G1.y1 + G1.w * G1.y2 /\
               G1.z = G1.z1 + G1.w * G1.z2){2} /\
              CCA.log{1} = G1.log{2} /\ CCA.cstar{1} = G1.cstar{2} /\ 
              CCA.sk{1} = (G1.k, g, G1.g_, G1.x1, G1.x2, G1.y1, G1.y2, G1.z1, G1.z2){2})).
      + by apply guess_ll.
      + by apply DDH1_G1_dec.
      + by move=> _ _; apply (CCA_dec_ll A).
      + by move=> _;apply G1_dec_bad.
    wp;rnd.
    call (_: G1.bad, 
             (
              (G1.x = G1.x1 + G1.w * G1.x2 /\
               G1.y = G1.y1 + G1.w * G1.y2 /\
               G1.z = G1.z1 + G1.w * G1.z2){2} /\
              CCA.log{1} = G1.log{2} /\ CCA.cstar{1} = G1.cstar{2} /\ 
              CCA.sk{1} = (G1.k, g, G1.g_, G1.x1, G1.x2, G1.y1, G1.y2, G1.z1, G1.z2){2})).
      + by apply choose_ll.
      + by apply DDH1_G1_dec.
      + by move=> _ _; apply (CCA_dec_ll A).
      + by move=> _;apply G1_dec_bad.
    swap{1} 16 -9;wp.
    swap -1;rnd (fun z => z + G1.w{2} * G1.z2{2})
                (fun z => z - G1.w{2} * G1.z2{2}).
    rnd;wp.
    swap -1;rnd (fun z => z + G1.w{2} * G1.y2{2})
                (fun z => z - G1.w{2} * G1.y2{2}).
    rnd;wp.
    swap -1;rnd (fun z => z + G1.w{2} * G1.x2{2})
                (fun z => z - G1.w{2} * G1.x2{2}).
    rnd;wp;rnd;wp.
    rnd (fun z => z / x{1}) (fun z => z * x{1}) => /=.
    auto => &m1 &m2 /= -> xL H;rewrite H /=;move: H => /supp_dexcepted. 
    rewrite /pred1 => -[] InxL HxL yL -> /=.
    split => [ ? _ | eqxL].
    + by field; rewrite ZModpRing.ofint0.
    split => [ ? _ | _]; first exact/dp_funi.
    move=> zL InzL_;split => [ | H{H}]; first exact/supp_dp.
    split => [ | _].
    + by field; rewrite ZModpRing.ofint0.
    move=> kL -> x2L -> /=.
    split => [ ? _ | Eqx2L]; first by algebra.
    split => [ ? _ | H {H}]; first exact/dp_funi.
    move=> x1L Inx1L;split => [ | Eqx1L]; first exact/supp_dp.
    split => [ | H{H}]; first by algebra.
    move=> y2L -> /=;split => [ ? _ | Eqy2L]; first by algebra.
    split => [ ? _ | H {H}]; first exact/dp_funi.
    move=> y1L Iny1L;split => [ | H{H}]; 1: by exact/supp_dp.
    split => [ | H{H}]; first by algebra.
    move=> z2L -> /=;split => [ ? _ | Eqz2L]; first by algebra.
    split => [ ? _ | H {H}]; first exact/dp_funi.
    move=> z1L Inz1L;split => [ | H{H}]; first exact/supp_dp.
    split=> [|_]; first by algebra.
    split=> [|_].
    + by (do!split; first 3 by rewrite -expM -expD; algebra); by algebra.
    move=> /> rL rR aL lL aR bad lR Hbad b _.
    split=> [/Hbad />|/#].
    have -> //=: g ^ xL ^ (zL / xL) = g ^ zL.
    + by rewrite -expM; congr; field; rewrite ZModpRing.ofint0.
    pose h := H _ _. pose h' := H _ _.
    have ->: h = h'.
    + by rewrite /h /h'; algebra.
    by move=> _ _ _ _ _ _; do!split; algebra.
  qed.

  lemma dt_r_ll x : is_lossless (dp \ pred1 x).
  proof. by rewrite dexcepted_ll 1:dp_ll dp1E; smt(gt1_prime prime_order). qed.
  
  local lemma aux1 &m : 
    Pr[CCA(CramerShoup, A).main() @ &m : res] <= 
       `| Pr[DDH0(B_DDH(A)).main() @ &m : res] - Pr[DDH1(B_DDH(A)).main() @ &m : res] | 
    + Pr[Ad1.MainE(G1).main() @ &m : res \/ G1.bad] + 3%r/order%r.
  proof.
    have -> : 
     Pr[CCA(CramerShoup, A).main() @ &m : res] = Pr[DDH0_ex(B_DDH(A)).main() @ &m : res].
    + byequiv CCA_DDH0 => //.
    have := adv_DDH_DDH_ex (B_DDH(A)) _ &m.
    + proc;call (guess_ll (<:CCA(CramerShoup,A).O) (CCA_dec_ll A));auto.
      call (choose_ll (<:CCA(CramerShoup,A).O) (CCA_dec_ll A));auto => /=.
      by rewrite dp_ll  DBool.dbool_ll dk_ll.
    have : Pr[DDH1_ex(B_DDH(A)).main() @ &m : res] <= 
           Pr[Ad1.Main(G1).main() @ &m : res \/ G1.bad].
    + byequiv DDH1_G1 => //;1: smt ().
    (* print glob G1. *)
    have /= := Ad1.pr_abs G1 _ _ &m (fun (b:bool) (x : glob G1) => b \/ x.`14).
    + proc;auto => />; by rewrite dt_r_ll ?dp_ll.
    + proc;auto;call (guess_ll (<:G1.O) G1_dec_ll);auto.
      by call (choose_ll (<:G1.O) G1_dec_ll);auto; rewrite dk_ll  dp_ll DBool.dbool_ll.  
    smt (mu_bounded).
  qed.

  local module G2 = {

    module O = G1.O

    module A = G1.A

    var alpha, v: exp

    proc main1 () = {
      var m0, m1, b, b0, v, e, f, h, r', a, a_, c, d;
      G1.log <- [];
      G1.cstar <- None;
      G1.bad <- false;
      G1.w <$ dp \ (pred1 ZModE.zero);
      G1.u <$ dp; 
      G1.u' <$ dp \ (pred1 G1.u);
      G1.g_ <- g ^ G1.w; G1.k  <$ dk;
      a <- g^G1.u; a_ <- G1.g_^G1.u';
      G1.x <$ dp; G1.x2 <$ dp; G1.x1 <- G1.x - G1.w * G1.x2; e <- g^G1.x;
      G1.y <$ dp; G1.y2 <$ dp; G1.y1 <- G1.y - G1.w * G1.y2; f <- g^G1.y;
      G1.z <$ dp; h <- g^G1.z; 
      (m0,m1) <@ A.choose(G1.k, g, G1.g_, e, f, h); 
      b <$ {0,1}; 
      r' <$ dp; 
      c <- g^r';
      v <- H G1.k (a, a_, c);
      d <- a^(G1.x1 + v*G1.y1) * a_^(G1.x2+v*G1.y2);
      G1.cstar <- Some (a,a_,c,d);
      b0 <@ A.guess(a,a_,c,d);
      return (b = b0);
    }
  
    proc main () = {
      var m0, m1, b, b0, e, f, h, r, r', a, a_, c, d;
      G1.log <- [];
      G1.cstar <- None;
      G1.bad <- false;
      G1.w <$ dp \ (pred1 ZModE.zero);
      G1.u <$ dp; 
      G1.u' <$ dp \ (pred1 G1.u);
      G1.g_ <- g ^ G1.w; G1.k  <$ dk;
      a <- g^G1.u; a_ <- G1.g_^G1.u';
      G1.y <$ dp; G1.y2 <$ dp; G1.y1 <- G1.y - G1.w * G1.y2; f <- g^G1.y;
      G1.z <$ dp; r' <$ dp; h <- g^G1.z;
      c <- g^r';
      v <- H G1.k (a, a_, c);
      G1.x <$ dp; r <$ dp;
      alpha <- (r - G1.u*(G1.x + v*G1.y)) / (G1.w*(G1.u'-G1.u));
      G1.x2 <- alpha - v*G1.y2;
      G1.x1 <- G1.x - G1.w * G1.x2; e <- g^G1.x;
      d <- g ^ r;
      (m0,m1) <@ A.choose(G1.k, g, G1.g_, e, f, h); 
      G1.cstar <- Some (a,a_,c,d);
      b0 <@ A.guess(a,a_,c,d);
      b <$ {0,1}; 
      return (b = b0);
    }
  }.

  local equiv G1_G21 : Ad1.MainE(G1).main ~ G2.main1 : ={glob A} ==> ={res, G1.bad}.
  proof.
    proc;inline *;wp.
    call (_: ={G1.bad, G1.cstar, G1.log, G1.x, G1.x1, G1.x2, G1.y, 
               G1.y1, G1.y2, G1.z, G1.w, G1.k}).
    + by sim => />.
    swap{1} [23..24] 3;wp => /=.
    rnd  (fun z2 => G1.u*G1.z - G1.u*G1.w*z2 + G1.w*G1.u'* z2 + loge (b ? m1 : m0)){1}
         (fun r' => (r' - G1.u*G1.z - loge (b ? m1 : m0)) / (G1.w * (G1.u' - G1.u))){1}.
    rnd.
    call (_: ={G1.bad, G1.cstar, G1.log, G1.x, G1.x1, G1.x2, G1.y,
               G1.y1, G1.y2, G1.z, G1.w, G1.k}).
    + by sim => />.
    auto => &m1 &m2 />;rewrite /pred1.
    move=> wL /supp_dexcepted [] _ /= HwL uL _ u'L /supp_dexcepted [] _ /= Hu'L .
    move=> kL _ xL _ x2L _ yL _ y2L _ zL _ resu bL _.
    split => [? _ | _ ].
    + field.
      rewrite -ZModpRing.mulrDl ZModpRing.ofint0 -unit_nz ZModpRing.unitrMr unit_nz //.
      by rewrite ZModpRing.addrC ZModpRing.addr_eq0 ZModpRing.opprK.
    split => [? _ | _ z2L _]; first exact/dp_funi.
    split; first exact/supp_dp.
    move=> _;split => [ | _].
    + field.
      rewrite -ZModpRing.mulrDl ZModpRing.ofint0 -unit_nz ZModpRing.unitrMr unit_nz //.
      by rewrite ZModpRing.addrC ZModpRing.addr_eq0 ZModpRing.opprK.
    rewrite -expM -{1 3 4 7 9 10}(expgK (if bL then resu.`2 else resu.`1)).
    pose lb := loge (if bL then resu.`2 else resu.`1).
    pose h := H _ _. pose h' := H _ _.
    have ->: h = h'.
    + rewrite /h /h'; move: lb h h'=> lb h h'; do 2!congr.
      by rewrite -expM -expM -expD -expD; algebra. (* slow!!! *)
    do !split.
    + by rewrite -expM -expM -expD -expD; algebra.
    by rewrite -expM -expM -expD -expD; algebra.
  qed.

  local equiv G21_G2 : G2.main1 ~ G2.main : ={glob A} ==> ={res, G1.bad}.
  proof.
    proc;inline *;wp. swap{2} -2.
    call (_: ={G1.bad, G1.cstar, G1.log, G1.x, G1.x1, G1.x2, G1.y, 
               G1.y1, G1.y2, G1.z, G1.w, G1.k}).
    + by sim => />.
    wp;swap {1} [11..14] 6;swap{1} -7;rnd.
    call (_: ={G1.bad, G1.cstar, G1.log, G1.x, G1.x1, G1.x2, G1.y, 
               G1.y1, G1.y2, G1.z, G1.w, G1.k}).
    + by sim => />.
    wp.
    rnd (fun x2 => (x2 + G2.v*G1.y2) * (G1.w*(G1.u'-G1.u)) + G1.u*(G1.x + G2.v*G1.y)){2}
        (fun r => (r - G1.u*(G1.x + G2.v*G1.y)) / (G1.w*(G1.u'-G1.u)) - G2.v*G1.y2){2}.
    do !(wp; rnd; wp); skip=> &1 &2 <-; split=> [//|_].
    split=> [//|_ w /Dexcepted.supp_dexcepted [] _ @{1}/pred1 w_nz].
    split=> [|_]; first by rewrite Dexcepted.supp_dexcepted.
    split=> [//|_].
    split=> [//|_].
    split=> [//|_ u u_in_dp].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_ u' /Dexcepted.supp_dexcepted [] _ @{1}/pred1 u'_nz].
    split=> [|_]; first by rewrite Dexcepted.supp_dexcepted.
    split=> [//|_].
    split=> [//|_].
    split=> [//|_ k k_in_dk].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_ y y_in_dp].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_ y2 y2_in_dp].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_ z z_in_dp].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_ r' r'_in_dp].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_].
    split=> [//|_ x x_in_dp].
    split=> [//|_].
    split=> [//|_].
    split=> [r r_in_dp|_].
    + pose h := H _ _; field.
      rewrite -ComRing.mulrDl ZModpRing.ofint0 -unit_nz ZModpRing.unitrMr unit_nz //.
      by rewrite ZModpRing.addrC ZModpRing.addr_eq0 ZModpRing.opprK.
    split=> [r r_in_dp|_ x2 x2_in_dp]; first exact/dp_funi.
    split=> [|_]; first exact/supp_dp.
    split=> [|_].
    + pose h := H _ _; field.
      rewrite -ComRing.mulrDl ZModpRing.ofint0 -unit_nz ZModpRing.unitrMr unit_nz //.
      by rewrite ZModpRing.addrC ZModpRing.addr_eq0 ZModpRing.opprK.
    split=> [/=|_].
    + split.
      + pose h := H _ _; field.
        rewrite -ComRing.mulrDl ZModpRing.ofint0 -unit_nz ZModpRing.unitrMr unit_nz //.
        by rewrite ZModpRing.addrC ZModpRing.addr_eq0 ZModpRing.opprK.
      pose h := H _ _; field.
      rewrite -ComRing.mulrDl ZModpRing.ofint0 -unit_nz ZModpRing.unitrMr unit_nz //.
      by rewrite ZModpRing.addrC ZModpRing.addr_eq0 ZModpRing.opprK.
    move=> /> _ _ b _; split.
    + by rewrite -expM -expM -expM -expD; algebra.
    by rewrite -expM -expM -expM -expD; algebra.
  qed.

  local lemma pr_G2_res &m: Pr[G2.main() @ &m : res] <= 1%r/2%r.
  proof.
    byphoare=> //;proc;rnd;conseq (_: _ ==> true) => //=.
    by move=> ?;rewrite DBool.dbool1E.
  qed.

  local module G3 = {
    var g3 : ( group * group * group) option
    var y2log : exp list
    var cilog : ciphertext list
    var a, a_, c, d: group

    module O = {
      proc dec(ci:ciphertext) = {
        var m, a,a_,c,d,v, y2';
        m <- None;
        if (size G1.log < PKE_.qD && Some ci <> G1.cstar) {
          cilog <- (G1.cstar = None) ? ci :: cilog : cilog;
          G1.log <- ci :: G1.log;
          (a,a_,c,d) <- ci;
          v <- H G1.k (a, a_, c);
          if (a_ <> a^G1.w) {
            if (v = G2.v /\ (a,a_,c) <> (G3.a,G3.a_,G3.c)) g3 <- Some (a,a_,c);
            else {
              y2' <- ((loge d - loge a*(G1.x + v*G1.y))/(loge a_ - loge a*G1.w) - G2.alpha) / (v -G2.v);
              y2log <-  y2' :: y2log;
            }
          }
          m = if (a_ = a^G1.w /\ d = a ^ (G1.x + v*G1.y)) then Some (c / a ^ G1.z)
              else None;
        }
        return m;
      }
    }

    module A = A (O)

    proc main () = {
      var m0, m1, b0, e, f, h, r, r';
      G1.log <- [];
      G3.y2log <- [];
      G3.cilog <- [];
      G3.g3 <- None;
      G1.cstar <- None;
      G1.w <$ dp \ (pred1 ZModE.zero);
      G1.u <$ dp; 
      G1.u' <$ dp \ (pred1 G1.u);
      G1.g_ <- g ^ G1.w; G1.k  <$ dk;
      a <- g^G1.u; a_ <- G1.g_^G1.u';
      G1.y <$ dp; f <- g^G1.y;
      G1.z <$ dp; r' <$ dp; h <- g^G1.z;
      c <- g^r';
      G2.v <- H G1.k (a, a_, c);
      G1.x <$ dp; r <$ dp; e <- g^G1.x;
      G2.alpha <- (r - G1.u*(G1.x + G2.v*G1.y))/ (G1.w*(G1.u'-G1.u));     
      d <- g ^ r;
      (m0,m1) <@ A.choose(G1.k, g, G1.g_, e, f, h); 
      G1.cstar <- Some (a,a_,c,d);
      b0 <@ A.guess(a,a_,c,d);
      G1.y2 <$ dp; 
      G1.y1 <- G1.y - G1.w * G1.y2;
      G1.x2 <- G2.alpha - G2.v*G1.y2;
      G1.x1 <- G1.x - G1.w * G1.x2; 
    }
  }.

  local equiv G2_G3_dec :  G1.O.dec ~ G3.O.dec : 
    ! (G3.g3 <> None \/ (G3.a, G3.a_,G3.c, G3.d) \in G3.cilog){2}  /\
    ={ci} /\ ={G1.x, G1.y, G1.z, G1.x1, G1.x2, G1.y1, G1.y2, G1.log, G1.cstar, G1.w,
               G1.u, G1.u', G1.k} /\
    (G1.cstar <> None => G1.cstar = Some (G3.a,G3.a_,G3.c,G3.d)){2} /\
    (G3.d = G3.a^(G1.x1 + G2.v*G1.y1) * G3.a_^(G1.x2+G2.v*G1.y2) /\
     G1.y1 = G1.y - G1.w * G1.y2 /\
     G1.x1 = G1.x - G1.w * G1.x2 /\
     G1.x2 = G2.alpha - G2.v * G1.y2){2} /\
    (G1.bad{1} => G1.y2{2} \in G3.y2log{2}) ==>
    !(G3.g3 <> None \/ (G3.a, G3.a_,G3.c, G3.d) \in G3.cilog){2} =>
     (={res} /\ ={G1.x, G1.y, G1.z, G1.x1, G1.x2, G1.y1, G1.y2, G1.log, G1.cstar, G1.w,
                 G1.u, G1.u', G1.k} /\
      (G1.cstar <> None => G1.cstar = Some (G3.a,G3.a_,G3.c,G3.d)){2} /\
      (G3.d = G3.a^(G1.x1 + G2.v*G1.y1) * G3.a_^(G1.x2+G2.v*G1.y2) /\
       G1.y1 = G1.y - G1.w * G1.y2 /\
       G1.x1 = G1.x - G1.w * G1.x2 /\
       G1.x2 = G2.alpha - G2.v * G1.y2){2} /\
      (G1.bad{1} => G1.y2{2} \in G3.y2log{2})).
  proof.
    proc;auto => &m1 &m2 />.
    case: (ci{m2}) => a a_ c d /=.
    pose v := H _ _. rewrite !negb_or => [[]] Hg3 Hcilog Hstareq.
    rewrite Hg3 /=. 
    case: (G1.bad{m1}) => [_ -> | ] //=. 
    move=> Hbad Hsize Hstar;rewrite !negb_and /= 2!negb_or /= -!andaE.
    case (v = G2.v{m2}) => [->> /= ? [#]!->> Hstar1 ->>| /=].
    + by case: (G1.cstar{m2}) Hstareq Hstar Hstar1.
    move=> Hv Ha _ ->>;left.
    rewrite logDr !logrzM; field.
    + rewrite ZModpRing.ofint0 ZModpRing.addrC ZModpRing.addr_eq0 -ZModpRing.mulNr.
      rewrite -logrzM -negP=> /(congr1 (fun (x : exp)=> g^x)) /=.
      by rewrite !expgK ZModpRing.opprK.
    by rewrite ZModpRing.ofint0 ZModpRing.addrC ZModpRing.addr_eq0 ZModpRing.opprK.
  qed.

  local equiv G2_G3 : G2.main ~ G3.main : 
    ={glob A} ==> 
      !(G3.g3 <> None \/ (G3.a, G3.a_,G3.c, G3.d) \in G3.cilog){2} => 
      (G1.bad{1} => (G1.y2 \in G3.y2log){2}).
  proof.
    proc.
    swap{2} [28..29] -14. swap{2} [30..31] -4. rnd{1}.
    call (_ : (G3.g3 <> None \/ (G3.a, G3.a_,G3.c, G3.d) \in G3.cilog),
               (={G1.x, G1.y, G1.z, G1.x1, G1.x2, G1.y1, G1.y2, G1.log, G1.cstar, G1.w,
                  G1.u, G1.u', G1.k} /\
                (G1.cstar <> None => G1.cstar = Some (G3.a,G3.a_,G3.c,G3.d)){2} /\
                (G3.d = G3.a^(G1.x1 + G2.v*G1.y1) * G3.a_^(G1.x2+G2.v*G1.y2) /\
                 G1.y1 = G1.y - G1.w * G1.y2 /\
                 G1.x1 = G1.x - G1.w * G1.x2 /\
                 G1.x2 = G2.alpha - G2.v * G1.y2){2} /\
                (G1.bad{1} => G1.y2{2} \in G3.y2log{2}))).
    + by apply guess_ll.
    + by apply G2_G3_dec.
    + by move=> &m2 _;apply G1_dec_ll.
    + by move=> /=;proc;auto => /#.
    wp;call (_ : (G3.g3 <> None \/ (G3.a, G3.a_,G3.c, G3.d) \in G3.cilog),
               (={G1.x, G1.y, G1.z, G1.x1, G1.x2, G1.y1, G1.y2, G1.log, G1.cstar, G1.w,
                  G1.u, G1.u', G1.k} /\
                (G1.cstar <> None => G1.cstar = Some (G3.a,G3.a_,G3.c,G3.d)){2} /\
                (G3.d = G3.a^(G1.x1 + G2.v*G1.y1) * G3.a_^(G1.x2+G2.v*G1.y2) /\
                 G1.y1 = G1.y - G1.w * G1.y2 /\
                 G1.x1 = G1.x - G1.w * G1.x2 /\
                 G1.x2 = G2.alpha - G2.v * G1.y2){2} /\
                (G1.bad{1} => G1.y2{2} \in G3.y2log{2}))).
    + by apply choose_ll. 
    + by apply G2_G3_dec.
    + by move=> &m2 _;apply G1_dec_ll.
    + by move=> /=;proc;auto => /#.
    auto => &m1 &m2 />.
    move=> wL /supp_dexcepted [] _;rewrite /pred1 => HwL0.
    move=> uL _ u'L /supp_dexcepted [] _ /= HuL kL _.
    move=> yL _ y2L _ zL _ r'L _ xL _ rL _.
    have H1 : (-uL) * wL + u'L * wL = wL * (u'L - uL) by ring.
    have H2 : (-uL) * wL + u'L * wL <> ZModpRing.ofint 0.
    + rewrite H1 ZModpRing.ofint0 -unit_nz ZModpRing.unitrMr unit_nz //.
      by rewrite ZModpRing.addr_eq0 ZModpRing.opprK.
    split => [ | _].
    + by rewrite -expM -expM -expM -expD; congr; field.
    by rewrite DBool.dbool_ll=> /#.
  qed.

  local lemma pr_G3_y2log &m : 
    Pr[G3.main() @ &m : G1.y2 \in G3.y2log] <= PKE_.qD%r / order%r.
  proof. 
    byphoare => //;proc;wp;rnd.
    conseq (_: _ ==> size G3.y2log <=  PKE_.qD) => /=.
    + move=> y2log Hsize;apply (ler_trans ((size y2log)%r/order%r)).
      + by apply (mu_mem_le_mu1 dp y2log (inv order%r)) => x;rewrite dp1E.
      apply ler_wpmul2r => //;2: by apply le_fromint.
      apply invr_ge0;smt (le_fromint gt1_prime prime_order).
    call (_: size G3.y2log <= size G1.log /\ size G3.y2log <= PKE_.qD). 
    + proc;auto => /#. 
    auto;call (_: size G3.y2log <= size G1.log /\ size G3.y2log <= PKE_.qD). 
    + proc;auto => /#. 
    auto => />;smt (qD_pos).
  qed.

  local equiv G3_TCR : G3.main ~ TCR(B_TCR(A)).main : ={glob A} ==> G3.g3{1} <> None => res{2}.
  proof.
    proc;inline *;wp;rnd{1}.
    call (_ : B_TCR.log{2} = G1.log{1} /\
              B_TCR.cstar{2} = G1.cstar{1} /\
              B_TCR.k{2} = G1.k{1} /\ 
              B_TCR.x{2} = G1.x{1} /\ B_TCR.y{2} = G1.y{1} /\ B_TCR.z{2} = G1.z{1} /\
              B_TCR.a{2} = G3.a{1} /\ B_TCR.a_{2} = G3.a_{1} /\ B_TCR.c{2} = G3.c{1} /\
              B_TCR.v'{2} = G2.v{1} /\
              B_TCR.w{2}  = G1.w{1} /\
              B_TCR.g3{2} = G3.g3{1} /\
              (G3.g3{1} <> None => 
               (H B_TCR.k (oget B_TCR.g3) = B_TCR.v' /\ (oget B_TCR.g3) <> 
                                                   (B_TCR.a,B_TCR.a_,B_TCR.c)){2})).
    + by proc;auto=> /#.
    wp; call (_ : B_TCR.log{2} = G1.log{1} /\
              B_TCR.cstar{2} = G1.cstar{1} /\
              B_TCR.k{2} = G1.k{1} /\ 
              B_TCR.x{2} = G1.x{1} /\ B_TCR.y{2} = G1.y{1} /\ B_TCR.z{2} = G1.z{1} /\
              B_TCR.a{2} = G3.a{1} /\ B_TCR.a_{2} = G3.a_{1} /\ B_TCR.c{2} = G3.c{1} /\
              B_TCR.v'{2} = G2.v{1} /\
              B_TCR.w{2}  = G1.w{1} /\
              B_TCR.g3{2} = G3.g3{1} /\
              (G3.g3{1} <> None => 
               (H B_TCR.k (oget B_TCR.g3) = B_TCR.v' /\ (oget B_TCR.g3) <> 
                                                   (B_TCR.a,B_TCR.a_,B_TCR.c)){2})).
    + by proc;auto=> /#.
    swap{1} 16 -7;auto; smt (dp_ll).
  qed.


 local module G4 = {

    module O = {
      proc dec(ci:ciphertext) = {
        var m, a,a_,c,d,v;
        m <- None;
        if (size G1.log < PKE_.qD && Some ci <> G1.cstar) {
          G3.cilog <- (G1.cstar = None) ? ci :: G3.cilog : G3.cilog;
          G1.log <- ci :: G1.log;
          (a,a_,c,d) <- ci;
          v <- H G1.k (a, a_, c);
          m = if (a_ = a^G1.w /\ d = a ^ (G1.x + v*G1.y)) then Some (c / a ^ G1.z)
              else None;
        }
        return m;
      }
    }

    module A = A (O)

    proc main () = {
      var m0, m1, b0, e, f, h, r, r';
      G1.log <- [];
      G3.cilog <- [];
      G1.cstar <- None;
      G1.w <$ dp \ (pred1 ZModE.zero);
      G1.g_ <- g ^ G1.w;
     
      G1.k  <$ dk;
      G1.y <$ dp; f <- g^G1.y;
      G1.z <$ dp;  h <- g^G1.z; 
      G1.x <$ dp; e <- g^G1.x;
      (m0,m1) <@ A.choose(G1.k, g, G1.g_, e, f, h);
      G1.u <$ dp; 
      G1.u' <$ dp \ (pred1 G1.u); 
      r' <$ dp; 
      r <$ dp;
      G3.a <- g^G1.u; G3.a_ <- G1.g_^G1.u';G3.c <- g^r'; G3.d <- g ^ r;
      G2.v <- H G1.k (G3.a, G3.a_, G3.c);
      G2.alpha <- (r - G1.u*(G1.x + G2.v*G1.y))/ (G1.w*(G1.u'-G1.u));      
      G1.cstar <- Some (G3.a,G3.a_,G3.c,G3.d);
      b0 <@ A.guess(G3.a,G3.a_,G3.c,G3.d);
    }
  }.

  local equiv G3_G4 : G3.main ~ G4.main : ={glob A} ==> ={G3.a, G3.a_,G3.c, G3.d, G3.cilog}.
  proof.
    proc;wp;rnd{1}.
    call (_ : ={G1.log, G1.cstar, G1.k, G1.w, G1.x, G1.y, G1.z, G3.cilog}).
    + by proc;auto => />.
    wp. swap{2} [14..17] -1.
    call (_ : ={G1.log, G1.cstar, G1.k, G1.w, G1.x, G1.y, G1.z, G3.cilog}).
    + by proc;auto => />.
    swap{2} [13..14]-8.  swap{2} [13..14]1.
    by auto => />;rewrite dp_ll.
  qed.

  (* TODO: move this ?*)
  lemma mu_mem_le_mu1_size (dt : 'a distr) (l : 'a list) (r : real) n: 
    size l <= n => 
    (forall (x : 'a), mu1 dt x <= r) => mu dt (mem l) <= n%r * r.
  proof.
    move=> Hsize Hmu1;apply (ler_trans ((size l)%r * r)). 
    + by apply mu_mem_le_mu1.
    apply ler_wpmul2r; 1: smt (mu_bounded). 
    by apply le_fromint.
  qed.

import StdRing.RField.

  local lemma pr_G4 &m:
    Pr[G4.main() @ &m : (G3.a, G3.a_,G3.c, G3.d) \in G3.cilog] <=
      (PKE_.qD%r/order%r)^3 * (PKE_.qD%r/(order-1)%r).
  proof.
    byphoare=> //;proc.
    seq 23 : ((G3.a, G3.a_, G3.c, G3.d) \in G3.cilog) 
             ((PKE_.qD%r / order%r)^3 * (PKE_.qD%r / (order - 1)%r)) 1%r _ 0%r => //;last first.
    + hoare; call (_ : G1.cstar <> None /\ !(G3.a, G3.a_, G3.c, G3.d) \in G3.cilog).
      + by proc;auto => /#.
      by auto.      
    seq 13 : true 1%r ((PKE_.qD%r / order%r) ^ 3 * (PKE_.qD%r / (order - 1)%r))
                 0%r _ (size G3.cilog <= PKE_.qD /\ G1.w <> ZModE.zero /\ G1.g_ = g ^ G1.w) => //.
    + call (_ : size G3.cilog <= size G1.log /\ size G1.log <= PKE_.qD).
      + proc;auto => /#.
      auto => /= w /supp_dexcepted;smt (qD_pos).
    wp;conseq (_ : _ ==> G1.u \in map (fun (g4:ciphertext) => loge g4.`1) G3.cilog /\
                      G1.u' \in map (fun (g4:ciphertext) => loge g4.`2 / G1.w) G3.cilog /\
                      r' \in map (fun (g4:ciphertext) => loge g4.`3) G3.cilog /\
                      r \in map (fun (g4:ciphertext) => loge g4.`4) G3.cilog).
    + move=> &hr /> => _ Hw u u' r r' Hlog.
      do !split;apply/mapP;
       exists (G.g ^ u, g ^ G1.w{hr} ^ u', G.g ^ r', G.g ^ r); rewrite Hlog /=.
       + by rewrite loggK.
       + by rewrite -expM loggK; algebra.
       + by rewrite loggK.
       by rewrite loggK.
    seq 1 : (G1.u \in map (fun (g4 : ciphertext) => loge g4.`1) G3.cilog)
            (PKE_.qD%r / order%r) ((PKE_.qD%r / order%r)^2 * (PKE_.qD%r / (order - 1)%r))
            _ 0%r (size G3.cilog <= PKE_.qD) => //;
    last 2 first.
    + hoare;conseq (_ : _ ==> true) => // /#.
    + move=> &hr _;apply lerr_eq;ring.
    + by auto.
    + rnd;skip => /> &hr Hsize _;pose m' := map _ _.
      apply (mu_mem_le_mu1_size dp m') => //.
      + by rewrite /m' size_map.
      by move=> ?;rewrite dp1E.
    seq 1 : (G1.u' \in map (fun (g4 : ciphertext) => loge g4.`2 / G1.w) G3.cilog)
            (PKE_.qD%r / (order-1)%r) ((PKE_.qD%r / order%r)^2) _ 0%r 
            (size G3.cilog <= PKE_.qD) => //;last 2 first.
    + hoare;conseq (_ : _ ==> true) => // /#.
    + move=> &hr _;apply lerr_eq;ring.
    + by auto.
    + rnd;skip => /> &hr Hsize _;pose m' := map _ _.
      apply (mu_mem_le_mu1_size (dp \ pred1 G1.u{hr}) m') => //.
      + by rewrite /m' size_map.
      move=> x;rewrite dexcepted1E {1}/pred1. 
      case: (x = G1.u{hr}) => _.
      + apply invr_ge0;smt (le_fromint gt1_prime prime_order).
      rewrite dp_ll !dp1E;apply lerr_eq.
      field;smt (gt1_prime prime_order le_fromint). 
    seq 1 : (r' \in map (fun (g4 : ciphertext) => loge g4.`3) G3.cilog)
            (PKE_.qD%r / order%r) (PKE_.qD%r / order%r) _ 0%r 
            (size G3.cilog <= PKE_.qD) => //;last 2 first.
    + hoare;conseq (_ : _ ==> true) => // /#.
    + move=> &hr _;apply lerr_eq;field.
      + rewrite (_: 2 = (0 + 1) + 1) // !powrS // powr0;smt (le_fromint gt1_prime prime_order). 
      smt (le_fromint gt1_prime prime_order). 
    + by auto.
    + rnd;skip => /> &hr Hsize _;pose m' := map _ _.
      apply (mu_mem_le_mu1_size dp m') => //.
      + by rewrite /m' size_map.
      by move=> ?;rewrite dp1E.
    conseq (_ : _ ==> (r \in map (fun (g4 : ciphertext) => loge g4.`4) G3.cilog)) => //.
    rnd;skip => /> &hr Hsize _;pose m' := map _ _.
    apply (mu_mem_le_mu1_size dp m') => //.
    + by rewrite /m' size_map.
    by move=> ?;rewrite dp1E.
  qed.

  lemma aux2 &m : 
    Pr[CCA(CramerShoup, A).main() @ &m : res] <=
    `|Pr[DDH0(B_DDH(A)).main() @ &m : res] -
      Pr[DDH1(B_DDH(A)).main() @ &m : res]| +
    Pr[TCR(B_TCR(A)).main() @ &m : res] + 
    1%r/2%r + (PKE_.qD + 3)%r / order%r + (PKE_.qD%r/order%r)^3 * (PKE_.qD%r/(order-1)%r).
  proof.
    have := aux1 &m.
    have -> : Pr[Ad1.MainE(G1).main() @ &m : res \/ G1.bad] = 
              Pr[G2.main1() @ &m : res \/ G1.bad].
    + by byequiv G1_G21.
    have -> : Pr[G2.main1() @ &m : res \/ G1.bad] = Pr[G2.main() @ &m : res \/ G1.bad].
    + by byequiv G21_G2.
    have : Pr[G2.main() @ &m : res \/ G1.bad] <= 1%r/2%r + Pr[G2.main() @ &m : G1.bad].
    + by rewrite Pr [mu_or];have := (pr_G2_res &m);smt (mu_bounded).
    have : Pr[G2.main() @ &m : G1.bad] <= 
           Pr[G3.main() @ &m : G3.g3 <> None \/ (G3.a, G3.a_,G3.c, G3.d) \in G3.cilog \/
                               G1.y2 \in G3.y2log].
    + byequiv G2_G3 => // /#.                                
    rewrite Pr [mu_or];rewrite Pr [mu_or].
    have : Pr[G3.main() @ &m : G3.g3 <> None] <= Pr[TCR(B_TCR(A)).main() @ &m : res].
    + byequiv G3_TCR => //.
    have : Pr[G3.main() @ &m : (G3.a, G3.a_,G3.c, G3.d) \in G3.cilog] =
           Pr[G4.main() @ &m : (G3.a, G3.a_,G3.c, G3.d) \in G3.cilog].
    + byequiv G3_G4=> //.
    have := pr_G4 &m.
    have := pr_G3_y2log &m.
    have -> : (PKE_.qD + 3)%r / order%r = PKE_.qD%r/order%r + 3%r/order%r.
    + by rewrite fromintD;ring.
    smt (mu_bounded).
  qed.

end section Security_Aux.

section Security.

  declare module A : CCA_ADV {CCA, B_TCR}.
  axiom guess_ll : forall (O <: CCA_ORC{A}), islossless O.dec => islossless A(O).guess.
  axiom choose_ll : forall (O <: CCA_ORC{A}), islossless O.dec => islossless A(O).choose.

  local module NA (O:CCA_ORC) = {
    module A = A(O)
    proc choose = A.choose
    proc guess(c:ciphertext) = {
      var b;
      b <@ A.guess(c);
      return !b;
    }
  }.

  local lemma CCA_NA &m : 
     Pr[CCA(CramerShoup, A).main() @ &m : res] = 
     1%r - Pr[CCA(CramerShoup, NA).main() @ &m : res].
  proof.
    have -> : Pr[CCA(CramerShoup, NA).main() @ &m : res] = 
              Pr[CCA(CramerShoup, A).main() @ &m : !res].
    + byequiv=> //;proc;inline *;wp.
      by conseq (_ : _ ==> ={b} /\ b'{2} = b0{1});[ smt() | sim].
    rewrite Pr [mu_not].
    have -> : Pr[CCA(CramerShoup, A).main() @ &m : true] = 1%r;last by ring.
    byphoare=> //;proc;inline *;auto.
    call (guess_ll (<:CCA(CramerShoup,A).O) (CCA_dec_ll A));auto.
    call (choose_ll (<:CCA(CramerShoup,A).O) (CCA_dec_ll A));auto.
    auto => />;rewrite dp_ll dk_ll DBool.dbool_ll /= => *.
    apply dexcepted_ll; 1: by apply dp_ll.
    rewrite dp1E;smt (le_fromint gt1_prime prime_order).  
  qed.

  local lemma DDH0_NA &m : Pr[DDH0(B_DDH(NA)).main() @ &m : res] = 
                        1%r - Pr[DDH0(B_DDH(A)).main() @ &m : res].
  proof.
    have -> : Pr[DDH0(B_DDH(NA)).main() @ &m : res] = 
              Pr[DDH0(B_DDH(A)).main() @ &m : !res].
    + byequiv=> //;proc;inline *;wp.
      by conseq (_ : _ ==> ={b0} /\ b'{2} = b1{1});[ smt() | sim].   
    rewrite Pr [mu_not];congr.
    byphoare=> //;proc;inline *;auto.
    call (guess_ll (<:CCA(CramerShoup,A).O) (CCA_dec_ll A));auto.
    call (choose_ll (<:CCA(CramerShoup,A).O) (CCA_dec_ll A));auto.
    by auto => />;rewrite dp_ll dk_ll DBool.dbool_ll.
  qed.

  local lemma DDH1_NA &m : Pr[DDH1(B_DDH(NA)).main() @ &m : res] = 
                        1%r - Pr[DDH1(B_DDH(A)).main() @ &m : res].
  proof.
    have -> : Pr[DDH1(B_DDH(NA)).main() @ &m : res] = 
              Pr[DDH1(B_DDH(A)).main() @ &m : !res].
    + byequiv=> //;proc;inline *;wp.
      by conseq (_ : _ ==> ={b0} /\ b'{2} = b1{1});[ smt() | sim].   
    rewrite Pr [mu_not];congr.
    byphoare=> //;proc;inline *;auto.
    call (guess_ll (<:CCA(CramerShoup,A).O) (CCA_dec_ll A));auto.
    call (choose_ll (<:CCA(CramerShoup,A).O) (CCA_dec_ll A));auto.
    by auto => />;rewrite dp_ll dk_ll DBool.dbool_ll.
  qed.


  local lemma TCR_NA &m : Pr[TCR(B_TCR(NA)).main() @ &m : res] = 
                          Pr[TCR(B_TCR(A)).main() @ &m : res].
  proof.
    byequiv=> //;proc;inline *;sim.
    call (_: ={ B_TCR.v', B_TCR.k, B_TCR.cstar, B_TCR.a, B_TCR.a_, B_TCR.c,
                B_TCR.log, B_TCR.g3, B_TCR.w, B_TCR.x, B_TCR.y, B_TCR.z}).
    + by sim.
    auto;call (_: ={ B_TCR.v', B_TCR.k, B_TCR.cstar, B_TCR.a, B_TCR.a_, B_TCR.c,
                     B_TCR.log, B_TCR.g3, B_TCR.w, B_TCR.x, B_TCR.y, B_TCR.z});2: by auto.
    by sim.
  qed.

  lemma conclusion &m : 
    `|Pr[CCA(CramerShoup, A).main() @ &m : res] - 1%r/2%r | <=
    `|Pr[DDH0(B_DDH(A)).main() @ &m : res] - Pr[DDH1(B_DDH(A)).main() @ &m : res]| +
    Pr[TCR(B_TCR(A)).main() @ &m : res] + 
    (PKE_.qD + 3)%r / order%r + (PKE_.qD%r/order%r)^3 * (PKE_.qD%r/(order-1)%r).
  proof.
    case (Pr[CCA(CramerShoup, A).main() @ &m : res] <= 1%r/2%r);last first.
    + have /# := aux2 A guess_ll choose_ll &m.
    have := aux2 NA _ choose_ll &m.            
    + by move=> O O_ll;proc;inline *;call (_ : true) => //; apply guess_ll.
    rewrite (CCA_NA &m) (DDH0_NA &m) (DDH1_NA &m) (TCR_NA &m).
    smt (mu_bounded).
  qed.

end section Security.

