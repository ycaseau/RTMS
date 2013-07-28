// *****************************************************************************
// *       RTMS: Repeated Tenders Market Share                                 *
// *       copyright (C) 2013 Yves Caseau                                      *
// *       file: simul.cl                                                      *
// *****************************************************************************

// *****************************************************************************
// *    Part 1: Client Tender                                                  *
// *    Part 2: Supplier Bid                                                   *
// *    Part 3: local moves & optimization                                     *
// *    Part 4: Nash equilibriums                                              *
// *****************************************************************************

// musique: eblouissant la nuit, un coup de lumière mortelle

// *****************************************************************************
// *    Part 1: Client Tender                                                  *
// *****************************************************************************

// run one tender
[tender(e:Experiment) : void
  -> pb.time :+ 1,
     let c := e.client, td := Tender(time = pb.time, nUnits = 100) in
       (//[SHOW] [~A] === ~S create a bid for ~S units // pb.time,c,td.nUnits,
        for s in e.suppliers c.bids[s.index] := makeBid(s,td),
        for s in e.suppliers c.adjusted[s.index] := adjust(c,s,c.bids[s.index]),
        let l2 := c.adjusted, iMin := 0, vMin := 1e9, v2 := 1e9 in
           (for i in (1 .. length(l2))
              (if (l2[i] < vMin)
                  (if (vMin < v2) v2 := vMin,
                   vMin := l2[i], iMin := i)
               else if (l2[i] < v2) v2 := l2[i]),
            let v := c.bids[iMin], s := e[iMin] in
               (//[SHOW] --- best bid is ~S:~A -> ~A (~A$) // s, vMin, c.bids[iMin],v / td.nUnits,
                td.cost := v,
                td.bid := v2 - 1.0,                // actual value that was needed to win
                td.winner := s,
                c.cost :+ v,
                c.total :+ td.nUnits,
                s.cost :+ td.nUnits * s.varCost,
                s.revenue :+ v,
                for s2 in e.suppliers
                  (add(s2.result.bid,c.bids[s.index]),
                   add(s2.result.win,(if (s = s2) 1.0 else 0.0))),
                c.tenders :add td))) ]            // adds the tender to history when completed

[unitCost(td:Tender) : Price -> (td.cost / td.nUnits) ]

// adjust the bidding price according to the client's tactic
[adjust(c:Client,s:Supplier,p0:Price) : Price
  -> let ms1 := marketShare(s), ms2 := c.tactic.maxShare in
       (if (ms1 >= ms2) 1e9
        else p0 * (1.0 + c.tactic.diversity / (ms2 - ms1))) ]


// run n years
[runYear(e:Experiment) : void
   -> for y in (1 .. e.nYear)
         (for k in (1 .. e.client.nTender) tender(e),
          yearDisplay(e,y),
          resetYear(e)) ]

// averagePrice
[averagePrice(c:Client) : Price  -> c.cost / c.total ]

// satisfaction is straightforward
[satisfaction(c:Client) : Percent
  -> ratio(c.strategy,averagePrice(c)) ]

// show one year's result
[yearDisplay(e:Experiment,y:integer) : void
  -> let c := e.client in
       printf("[year ~A] ~S[~A] -> ~A tenders @ cost ~A\n",y,c,satisfaction(c),c.nTender,averagePrice(c)),
     showSuppliers(e) ]

// reset after one Year
[resetYear(e:Experiment) : void
  -> let c := e.client in
       (add(c.result.satisfaction,satisfaction(c)),
        add(c.result.bid,averagePrice(c)),
        c.cost := 0.0,
        c.total := 0,
        for s in e.suppliers
            (add(s.result.satisfaction,satisfaction(c)),
             add(s.result.mShare,marketShare(s)),
             s.prevShare := marketShare(s),
             s.revenue := 0.0,
             s.cost := s.fixedCost)) ]

// global reset
[reset(e:Experiment) : void
  -> let c := e.client in
       (c.cost := 0.0,
        c.total := 0,
        reset(c.result.satisfaction),
        reset(c.result.bid),
        shrink(c.tenders,0)),
     for s in e.suppliers
        (s.prevShare := s.strategy.mShare,
         s.revenue := 0.0,
         s.cost := s.fixedCost,
         reset(s.result.satisfaction),
         reset(s.result.mShare),
         reset(s.result.bid),
         reset(s.result.win)) ]


// this is the main loop for GTES
[runLoop(e:Experiment) : void
  -> reset(e),
     runYear(e),
     e.client.cursat := mean(e.client.result.satisfaction),
     for s in e.suppliers s.cursat := mean(s.result.satisfaction) ]

[runLoop(p:Player) : float -> runLoop(e), p.cursat]

// *****************************************************************************
// *    Part 2: Supplier Bid                                                   *
// *****************************************************************************

// current market share (value, not volume)
[marketShare(s:Supplier) : Percent
  -> if (s.revenue = 0.0) 0.0
     else s.revenue / s.client.cost ]

// bidding is based on a number of reference points
// - yearly equilibrium
// - current equilibrium  (dynamic version of previous one)
// - last winning bid
// - last min-to-win price (same plus regret)

// yearly equilibrium means that we reach the margin if we get the market share
//  N * P = fixed + N * variable
[yearlyBalance(s:Supplier) : Price
  -> let q := float!(pb.nUnits * s.client.nTender) * s.strategy.mShare in
       (1.0 + s.strategy.margin) * (s.fixedCost + q * s.varCost) / q ]

// dynamic version that takes the current revenues & costs into account
//  revenue + (N' * P) = cost + N' * variable
[dynamicBalance(s:Supplier) : Price
  -> let q := float!(pb.nUnits * (s.client.nTender - length(s.client.tenders))) * s.strategy.mShare in
       (1.0 + s.strategy.margin) * ((s.cost - s.revenue) + q * s.varCost) / q ]

// explain
[bal(s:Supplier) : void
    -> let q := float!(pb.nUnits * (s.client.nTender - length(s.client.tenders))) * s.strategy.mShare,
           curBal := (s.cost - s.revenue),
           p := (curBal + q * s.varCost) / q,
           p2 := (1.0 + s.strategy.margin) * p in
        printf("for ~A expected units and ~A$ balance, equilibrium = ~S x margin = ~S \n",
               q,curBal,p,p2) ]

// sharePrice applies a correction factor linked to market share
[sharePrice(s:Supplier) : Price
  -> let p1 := s.varCost, delta := (yearlyBalance(s) - p1),
         msf := marketShare(s) / s.strategy.mShare in
       (p1 + delta * (msf ^ 0.25)) ]


// last winning bid
[lastBid(s:Supplier)
  -> let l := s.client.tenders in
        (if (length(l) = 0) yearlyBalance(s)
         else unitCost(last(l))) ]

// last min-to-win tender (unit) price, based on regret
//
[min2win(s:Supplier)
  -> let l := s.client.tenders in
        (if (length(l) = 0) yearlyBalance(s)
         else let v := last(l).bid, f := adjust(s.client,s,1.0) in (v / f)) ]


// apply a tactic to produce a bid price
[makeBid(x:Combination,s:Supplier) : Price
  -> let p1 := yearlyBalance(s),
         p2 := sharePrice(s),
         p3 := lastBid(s) in
       (//[SHOW] makeBid(~S) : ~S [~A]:~A (~A):~A {~A}:~A // s,x.a1 * p1 + x.a2 * p2 + x.a3 * p3,x.a1,p1,x.a2,p2,x.a3,p3,
        x.a1 * p1 + x.a2 * p2 + x.a3 * p3) ]

[makeBid(x:Combination1,s:Supplier) : Price
  -> let p1 := max(s.varCost,dynamicBalance(s)), // pas de vente à perte
         p2 := sharePrice(s),
         p3 := lastBid(s) in
       (//[SHOW] makeBid2(~S) : ~S ~A:~A ~A:~A ~A:~A // s,x.a1 * p1 + x.a2 * p2 + x.a3 * p3,x.a1,p1,x.a2,p2,x.a3,p3,
        x.a1 * p1 + x.a2 * p2 + x.a3 * p3) ]

[makeBid(x:Combination2,s:Supplier) : Price
  -> let p1 := yearlyBalance(s),
         p2 := sharePrice(s),
         p3 := min2win(s) in
       (//[SHOW] makeBid3(~S) : ~S ~A:~A ~A:~A ~A:~A // s,x.a1 * p1 + x.a2 * p2 + x.a3 * p3,x.a1,p1,x.a2,p2,x.a3,p3,
        x.a1 * p1 + x.a2 * p2 + x.a3 * p3) ]

// answer to a tender with a price
[makeBid(s:Supplier,td:Tender) : Price
  -> float!(td.nUnits) * makeBid((if win?(s) s.tactic.win else s.tactic.loose),s) ]

// did s win the previous tender ? used to select the proper tactic
[win?(s:Supplier) : boolean
  -> length(s.client.tenders) > 0 & last(s.client.tenders) = s ]


// computes the actual margin
[margin(s:Supplier) : Percent   ->  (s.revenue / s.cost) - 1.0]


// satisfaction is product-based : ms // ms_goal * margin // margin_goal
// // is a capped ratio
[ratio(x:float,y:float) : float
  -> if (y <= 0.0) 1.0
     else min(1.0, x / y)]

[satisfaction(s:Supplier) : Percent
   -> ratio(marketShare(s),s.strategy.mShare) * ratio(margin(s),s.strategy.margin) ]

// show the suppliers
[showSuppliers(e:Experiment)
  -> for s in e.suppliers
       printf("~S[~A]: cost=~A, rev=~A, mshare=~A, margin=~A\n",s,satisfaction(s), s.cost,s.revenue,
                              marketShare(s),margin(s)) ]

// *****************************************************************************
// *    Part 3: local moves & optimization                                     *
// *****************************************************************************


// ---------------------- generic optimization engine [float flavor] -------------------------
// [this is a reusable code fragment - source: project PSR Game - 2007 ======================]

OPTI:integer :: 1                  // TRACE/DEBUG verbosity
NUM1:integer :: 5                  // number of steps in a loop (1/2, 1/4, ... 1/2^5) => precision
MULTI:integer :: 5                 // number of successive optimization loops

MaxValue[p:property] : float := 1.0            // default value is for percentage => 1.0 is max

// define maxValues for prices

// optimize all players
[optimize(x:Client) -> optimize(x,tactic)]

[optimize(x:Supplier) -> optimize(x,x.tactic.win), optimize(x,x.tactic.loose) ]

// optimise the tactic component y for a player x
[optimize(x:Player, y:Tactic) : void
  -> for p in x.tacticProperties optimize(x,y,p),
     trace(TALK,"--- end optimize(~S) -> ~A \n",x,x.satisfaction) ]

// first approach : relative steps (=> does not cross the 0 boundary, keeps the sign) ----------

// optimize a given slot in a set of two dichotomic steps
[optimize(c:Player,y:Tactic,p:property)
  -> for i in (1 .. NUM1) optimize(c,y,p,float!(2 ^ (i - 1))),
     trace(OPTI,"best ~S for ~S is ~A => ~A\n", p,c,read(p,y), c.satisfaction) ]

DD:integer := 0   // debug counter
DGO:integer := 0
WHY:boolean :: false   // debug

// the seed value is problem dependant !
// it is used twice - when the value is 0, to boost the multiplicative increment loop (opt)
//                    when the value is very small, to boost the additive loop
SEED:float :: 1.0

[optimize(c:Player,y:Tactic,p:property,r:float)
   ->  let vr := c.satisfaction, val := 0.0,
           vp := read(p,y), v0 := (if (vp > 0.0) vp else SEED),        // v0.4 do not waste cycles
           v1 := vp / (1.0 +  (1.0 / r)), v2 := vp * (1.0 + (1.0 / r)) in
        (write(p,y,v1),
         if (v1 >= 0.0) val := runLoop(c),
         DD :+ 1,
         //[OPTI] try ~A (vs.~A) for ~S(~S) -> ~A (vs. ~A) [DD:~A] // v1,vp,p,c,val,vr,DD,
         if (DD = DGO) (TALK := 0, SHOW := 0),
         if (val > vr) (vp := v1, vr := val),
         write(p,y,v2),
         if (v2 <= MaxValue[p]) val := runLoop(c) else trace(OPTI,"MAX-NO"),
         //[OPTI] try ~A for ~S(~S) -> ~A // v2,p,c,val,
         if (val > vr) (vp := v2, vr := val),
         write(p,y,vp),
         c.satisfaction := vr) ]

// TODO : copy whatif from MMS
[whatif(c:Supplier,win?:boolean,p:property,v:float)
  -> let y := (if win? c.tactic.win else c.tactic.loose), v2 := read(p,y) , s2 := c.cursat in
      (write(p,y,v),
       runLoop(c),
       //[0] whatif ~A(~S) = ~A -> sat = ~A vs ~A->~A // label(i),c,v,c.cursat,v2,s2,
       display(c),
       write(p,y,v2)) ]

// ------------------------------- 2-opt ----------------------------------------------------------------------
OPTI2:integer :: 1

// randomized 2-opt, borrowed from SOCC, but smarter:once the first random move is made, try to fix it with optimize
// tries more complex moves which are sometimes necessary
// n is the number of loops
[twoOpt(c:Player,y:Tactic,n:integer)
  -> // optimize(c),                      // first run a single pass
     let vr := c.satisfaction,  val := 0.0 in
        (for i in (1 .. n)
         let p1 := (randomIn(y.properties) as property),
             p2 := (randomIn(y.properties) as property),
             v1 := read(p1,y), v2 := read(p2,y) in
           (if (p1 = p2) nil
            else
             (write(p1,y,v1),
              trace(OPTI,"=== shift: ~S(~S) = ~A vs ~A\n",p1,c,get(p1,y),v1),
              if (get(p1,y) != v1) optimize(c,p2),
              val := c.cursat,
              trace(OPTI2,"=== try2opt [~A vs ~A] with ~S(~A<-~A) x ~S(~A<-~A)\n",
                 val,vr,p1,get(p1,y),v1,p2,get(p2,x),v2),
           if (val <= vr) (c.satisfaction := vr, write(p1,y,v1), write(p2,y  ,v2))
           else (vr := val,
                 trace(OPTI2,"*** improve ~A with ~S:~A x ~S:~A -> ~A\n",
                      val,p1,get(p1,c.tactic),p2,get(p2,y), val))))),
      runLoop(c),
      trace(OPTI2,"--- end 2opt(~S,~A) -> ~A% \n",c,n,c.cursat * 100.0) ]

// TODO : copy random walk - from S3G (try later !)

// *****************************************************************************
// *    Part 4: Nash equilibriums                                              *
// *****************************************************************************


// ------------------------- our reusable trick -------------------------

[ld1() : void -> load(Id(*src* /+ "\\rtmsv" /+ string!(Version) /+ "\\test")) ]

// we load a file of interpreted code which contains the program description
(#if (compiler.active? = false | compiler.loading? = true) ld1() else nil)

