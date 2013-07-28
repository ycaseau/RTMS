// *****************************************************************************
// *       RTMS: Repeated Tenders Market Share                                 *
// *       copyright (C) 2013 Yves Caseau                                      *
// *       file: model.cl                                                      *
// *****************************************************************************

// this file contains the data model
Version :: 0.1
Percent :: float
Price :: float

// *****************************************************************************
// *    Part 1: Client                                                         *
// *    Part 2: Supplier                                                       *
// *    Part 3: Experiments & GTES environment                                 *
// *    Part 4: Utilities                                                      *
// *****************************************************************************

// names
Percent :: float
Price :: float

// GTES-Player
Player <: thing(cursat:float)

// forward
Supplier <: Player
Measure <: ephemeral_object
SupplierResult <: object
ClientResult <: object

// verbosity/TRACE
TALK:integer :: 1
SHOW:integer :: 1

// *****************************************************************************
// *    Part 1: Client                                                         *
// *****************************************************************************

// Root object which supports the GTES local opt methods - see simul.cl
Tactic <: object(
     properties:list<property>)              // list of properties to which opt must be applied (cf. constructor)


// Client Tactic simply tells which bidder to select
ClientTactic <: Tactic(
     maxShare:Percent,                 // will not let supplier get too big
     diversity:Percent)                //

[clientTactic(a:Percent,b:Percent) : ClientTactic
  -> ClientTactic(properties = list<property>(maxShare,diversity),
                  maxShare = a, diversity = b)]

// we create a Tender object mostly for book keeping.
// in this first version,each tender is characterized by a number of units
// (such as man.days in a SW project bid)
Tender <: object(
     time:integer,            // index (t = 1,2,3 ...)
     nUnits:integer,            // number of units for this bid
     cost:Price,              // actual amount that was paid
     winner:Supplier,         // winner of the bid
     bid:Price)               // optimal value for bid (2nd best = best - regret)

// the client issues the series of tenders
// no strategy is needed : goal is to minimize the total cost
Client <: Player(
     nTender:integer = 10,              // number of tenders per year
     cost:Price = 0.0,                  // total money spent
     total:integer = 0,                 // number of units purchased
     tactic:ClientTactic,               // one simple tactic
     result:ClientResult,               // all variables that are kept (stats)
     strategy:Price,                    // target price - the strategy is to buy cheap :)
     // used by algorithm
     tenders:list<Tender>,              // list of tenders (yearly)
     bids:list<Price>,                  // list of prices for each bid
     adjusted:list<Price>)              // list of prices for each bid

// *****************************************************************************
// *    Part 2: Supplier                                                       *
// *****************************************************************************


// note : tho objective is simply to maximize (average) revenue, according to two
// criterias: marketshare and margin
SupplierStrategy <: object(
      mShare:Percent,          // target market share
      margin:Percent)          // target margin (revenue / cost - 1.0)

// constructor
[goal(a1:Percent,a2:Percent) : SupplierStrategy
   -> SupplierStrategy(mShare = a1, margin = a2)]
[self_print(x:SupplierStrategy) : void
   -> printf("goal(~S,~S)",x.mShare,x.margin)]

// supplier tactic tells how to price the bid according to previous info
BidTactic <: Tactic()

// in this simple version, it is a simple linear combination of "trigger prices"
Combination <: BidTactic(
      a1:float,
      a2:float,
      a3:float)

// constructor
[combine(a:float,b:float,c:float) : Combination
   -> Combination(properties = list<property>(a1,a2,a3), a1 = a, a2 = b, a3 = c) ]
[self_print(x:Combination) : void
   -> printf("combine(~S,~S,~S)",x.a1,x.a2,x.a3) ]


// variation on the 1st price: use a dynamic formula instead of "balance"
Combination1 <: BidTactic(
      a1:float,
      a2:float,
      a3:float)

// constructor
[combine1(a:float,b:float,c:float) : Combination
   -> Combination1(properties = list<property>(a1,a2,a3), a1 = a, a2 = b, a3 = c) ]
[self_print(x:Combination1) : void
   -> printf("combine1(~S,~S,~S)",x.a1,x.a2,x.a3) ]

// in this simple version, it is a simple linear combination of "trigger prices"
Combination2 <: BidTactic(
      a1:float,
      a2: float,
      a3:float)

// variation about the 3rd price: last bid or last bid + regret
[combine2(a:float,b:float,c:float) : Combination
   -> Combination2(properties = list<property>(a1,a2,a3), a1 = a, a2 = b, a3 = c) ]
[self_print(x:Combination2) : void
   -> printf("combine2(~S,~S,~S)",x.a1,x.a2,x.a3) ]

// a supplier tactic is a triplet of bid tactics, one for each situation: win, loose
SupplierTactic <: object(
      win:BidTactic,                // tactic when winning the previous bid
      loose:BidTactic,              // tactic when loosing the previous bid
      monopoly:BidTactic)           // tactic when in a monopoly (other bidders quit)


// a supplier is defined by three tactics
Supplier <: Player(
      index:integer = 0,
      fixedCost:Price,              // yearly fixed cost
      varCost:Price,                // variable cost per unit
      strategy:SupplierStrategy,    // goals: ms & margin
      tactic:SupplierTactic,           // tactic when the supplier won the previous round
      result:SupplierResult,
      // computed by the simulation
      client:Client,
      cost:Price,                   // production cost
      revenue:Price,                // total revenue from sales
      prevShare:Percent)            // previous yearly market share


// *****************************************************************************
// *    Part 3: Experiments & GTES environment                                 *
// *****************************************************************************

// Experiments are defined with a selection from the suppliers
Experiment <: thing(
   client:Client,
   suppliers:list<Supplier>,
   nYear:integer = 1,                   // number of years
   // results obtained from
   sats:list<float>)                    // list of each satisfaction ?

// retreive a suplier from its index
[nth(e:Experiment,i:integer) : Supplier
  -> if (i < 1 | i > length(e.suppliers)) error("S(~S) : wrong index",i)
     else e.suppliers[i] ]


// our global environment object
Problem <: thing(
   time:integer = 0,                 // time unit is # of bids
   nUnits:integer = 100)             // average number of units in a tender (could vary)


pb :: Problem()


// statistics & results
// what we measure for one run
Measure <: ephemeral_object(
  sum:float = 0.0,
  square:float = 0.0,           // used for standard deviation
  num:float = 0.0)          // number of experiments

// simple methods add, mean, stdev
[add(x:Measure, f:float) : void -> x.num :+ 1.0, x.sum :+ f, x.square :+ f * f ]
[mean(x:Measure) : float -> if (x.num = 0.0) 0.0 else x.sum / x.num]
[stdev(x:Measure) : float
   -> let y := ((x.square / x.num) - ((x.sum / x.num) ^ 2.0)) in
         (if (y > 0.0) sqrt(y) else 0.0) ]
[stdev%(x:Measure) : Percent -> stdev(x) / mean(x) ]
[reset(x:Measure) : void -> x.square := 0.0, x.num := 0.0, x.sum := 0.0 ]

// SupplierMeasure
SupplierResult <: object(
    satisfaction:Measure,     // averare yearly satisfaction
    win:Measure,              // success rate (1.0 when win, 0.0)
    bid:Measure,              // average unit bid price
    mShare:Measure)           // average yearly market share

// SupplierMeasure
ClientResult <: object(
    satisfaction:Measure,
    bid:Measure)                // average unit bid price


// *****************************************************************************
// *    Part 4: Utilities                                                      *
// *****************************************************************************


// create all the necessary measure object
[init(e:Experiment) : void
  -> let c := e.client, i := 1 in
        (c.result := ClientResult(satisfaction = Measure(), bid = Measure()),
         c.bids := list<Price>{0.0 | s in e.suppliers},
         c.adjusted := list<Price>{0.0 | s in e.suppliers},
         for s in e.suppliers
          (s.result := SupplierResult(satisfaction = Measure(), win = Measure(), bid = Measure(), mShare = Measure()),
           s.cost := s.fixedCost,                 // fixed costs are added once yearly
           s.prevShare := s.strategy.mShare,        // init with target value :)
           s.client := c,
           s.index := i,
           i :+ 1)) ]

