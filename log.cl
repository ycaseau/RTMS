// ********************************************************************
// *       RTMS: Repeated Tenders Market Share                        *
// *       copyright (C) 2013 Yves Caseau                             *
// *       file: log.cl                                               *
// ********************************************************************

// this is a stochastic game, designed to simulate a repeated tender, implemented with GTES
// the goal is to understand a closed B2B market's dynamics :)
// this is related to the problem proposed by Benoit Rottembourg


// -------------------------- v0.1 ---------------------------------------------------------------------

// 14/7/2013
start coding during flight :)
model.cl : classes
simul.cl : bidding tactics
test.cl : our sample problem = Bytel + ATOS/IBM/HP

// 16/7/2013
fin du code pour le cas le plus simple (one Year)
ajout des Measures
(avion/airport) : clean-up code + run !

// 18/7/2013
on garde l idee de la moyenne de 3 prix mais avec variante:
   - yearlyBal / dynBal     -> orienté marge
   - variable de fixed à YearlyBal en fonction de la marketshare
   - lastBid / bid-to-win   -> orienté réaction (génère des enchères)
Done ! (run one year)

//20/7/2013
- many years (keep lastbid +
- reloop
- Experiment
- simple local opt with a new model
   each player has a Business Tatic, which is composed of multiple tactics (one for each scenario; or a policy
   which is a mixed tactic - a list with associated probabilities)

   simple opt applies to tactic objects (with the slot

// 26/7/2013
- refresh the code

// 27/7/2010
- copy local opt code
- try to make step1 work :)


TODO:

STEP1  (Part 3)

- local opt step 1: optimize
- local opt step 2: two-opt from S3G
- local opt step 3: randomWalk with tabu from S3G

STEP 2
- loop for Nash  (Part 4)
- create a few interesting situations


STEP 3
- add win/loose distinction
- add drop-out behaviour
- add monopoly tactic
- enrich stats

STEP4
- randomized tactics

- search for Nash equilibriums


STEP4
- introduce "policies" = vector of probability distributions
- look at different algorithms to learn those policies


