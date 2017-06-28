my role Real { ... }

my class Rakudo::QuantHash {

    # a Pair with the value 0
    my $p0 := nqp::p6bindattrinvres(nqp::create(Pair),Pair,'$!value',0);

    our role Pairs does Iterator {
        has $!elems;
        has $!picked;

        method !SET-SELF(\elems,\count) {
            nqp::stmts(
              ($!elems := elems),
              ($!picked := Rakudo::QuantHash.PICK-N(elems, count)),
              self
            )
        }
        method new(Mu \elems, \count) {
            nqp::if(
              (my $todo := Rakudo::QuantHash.TODO(count))
                && elems
                && nqp::elems(elems),
              nqp::create(self)!SET-SELF(elems, $todo),
              Rakudo::Iterator.Empty
            )
        }
    }

    # Return the iterator state of a randomly selected entry in a
    # given IterationSet
    method ROLL(Mu \elems) {
        nqp::stmts(
          (my int $i = nqp::add_i(nqp::rand_n(nqp::elems(elems)),1)),
          (my $iter := nqp::iterator(elems)),
          nqp::while(
            nqp::shift($iter) && ($i = nqp::sub_i($i,1)),
            nqp::null
          ),
          $iter
        )
    }

    # Return a list_s of N keys of the given IterationSet in random order.
    method PICK-N(Mu \elems, \count) {
        nqp::stmts(
          (my int $elems = nqp::elems(elems)),
          (my int $count = nqp::if(count > $elems,$elems,count)),
          (my $keys := nqp::setelems(nqp::list_s,$elems)),
          (my $iter := nqp::iterator(elems)),
          (my int $i = -1),
          nqp::while(
            nqp::islt_i(($i = nqp::add_i($i,1)),$elems),
            nqp::bindpos_s($keys,$i,nqp::iterkey_s(nqp::shift($iter)))
          ),
          (my $picked := nqp::setelems(nqp::list_s,$count)),
          ($i = -1),
          nqp::while(
            nqp::islt_i(($i = nqp::add_i($i,1)),$count),
            nqp::stmts(
              nqp::bindpos_s($picked,$i,
                nqp::atpos_s($keys,(my int $pick = $elems.rand.floor))
              ),
              nqp::bindpos_s($keys,$pick,
                nqp::atpos_s($keys,($elems = nqp::sub_i($elems,1)))
              )
            )
          ),
          $picked
        )
    }

    # Return number of items to be done if > 0, or 0 if < 1, or throw if NaN
    method TODO(\count) is raw {
        nqp::if(
          count < 1,
          0,
          nqp::if(
            count == Inf,
            count,
            nqp::if(
              nqp::istype((my $todo := count.Int),Failure),
              $todo.throw,
              $todo
            )
          )
        )
    }

    # Create intersection of 2 Baggies, default to given empty type
    method INTERSECT-BAGGIES(\a,\b,\empty) {
        nqp::if(
          (my $araw := a.raw_hash) && nqp::elems($araw)
            && (my $braw := b.raw_hash) && nqp::elems($braw),
          nqp::stmts(                          # both have elems
            nqp::if(
              nqp::islt_i(nqp::elems($araw),nqp::elems($braw)),
              nqp::stmts(                      # $a smallest, iterate over it
                (my $iter := nqp::iterator($araw)),
                (my $base := $braw)
              ),
              nqp::stmts(                      # $b smallest, iterate over that
                ($iter := nqp::iterator($braw)),
                ($base := $araw)
              )
            ),
            (my $elems := nqp::create(Rakudo::Internals::IterationSet)),
            nqp::while(
              $iter,
              nqp::if(                         # bind if in both
                nqp::existskey($base,nqp::iterkey_s(nqp::shift($iter))),
                nqp::bindkey(
                  $elems,
                  nqp::iterkey_s($iter),
                  nqp::if(
                    nqp::getattr(
                      nqp::decont(nqp::iterval($iter)),
                      Pair,
                      '$!value'
                    ) < nqp::getattr(          # must be HLL comparison
                          nqp::atkey($base,nqp::iterkey_s($iter)),
                          Pair,
                          '$!value'
                        ),
                    nqp::iterval($iter),
                    nqp::atkey($base,nqp::iterkey_s($iter))
                  )
                )
              )
            ),
            nqp::create(empty.WHAT).SET-SELF($elems),
          ),
          empty                                # one/neither has elems
        )
    }

    # create a deep clone of the given IterSet with baggy
    method BAGGY-CLONE(\raw) {
        nqp::stmts(
          (my $elems := nqp::clone(raw)),
          (my $iter  := nqp::iterator($elems)),
          nqp::while(
            $iter,
            nqp::bindkey(
              $elems,
              nqp::iterkey_s(nqp::shift($iter)),
              nqp::p6bindattrinvres(
                nqp::clone(nqp::iterval($iter)),
                Pair,
                '$!value',
                nqp::getattr(nqp::iterval($iter),Pair,'$!value')
              )
            )
          ),
          $elems
        )
    }

#--- Set/SetHash related methods

    # Create an IterationSet with baggy semantics from IterationSet with
    # Setty semantics.
    method SET-BAGGIFY(\raw) {
        nqp::stmts(
          (my $elems := nqp::clone(raw)),
          (my $iter  := nqp::iterator($elems)),
          nqp::while(
            $iter,
            nqp::bindkey(
              $elems,
              nqp::iterkey_s(nqp::shift($iter)),
              Pair.new(nqp::decont(nqp::iterval($iter)),1)
            )
          ),
          $elems
        )
    }

    method SET-IS-SUBSET($a,$b --> Bool:D) {
        nqp::stmts(
          nqp::unless(
            nqp::eqaddr(nqp::decont($a),nqp::decont($b)),
            nqp::if(
              (my $araw := $a.raw_hash)
                && nqp::elems($araw),
              nqp::if(                # number of elems in B *always* >= A
                (my $braw := $b.raw_hash)
                  && nqp::isle_i(nqp::elems($araw),nqp::elems($braw))
                  && (my $iter := nqp::iterator($araw)),
                nqp::while(           # number of elems in B >= A
                  $iter,
                  nqp::unless(
                    nqp::existskey($braw,nqp::iterkey_s(nqp::shift($iter))),
                    return False      # elem in A doesn't exist in B
                  )
                ),
                return False          # number of elems in B smaller than A
              )
            )
          ),
          True
        )
    }

    # add to given IterationSet the values of given iterator
    method ADD-ITERATOR-TO-SET(\elems,Mu \iterator) {
        nqp::stmts(
          nqp::until(
            nqp::eqaddr(
              (my $pulled := nqp::decont(iterator.pull-one)),
              IterationEnd
            ),
            nqp::bindkey(elems,$pulled.WHICH,$pulled)
          ),
          elems
        )
    }

    # add to given IterationSet the values of given iterator with Pair check
    method ADD-PAIRS-TO-SET(\elems,Mu \iterator) {
        nqp::stmts(
          nqp::until(
            nqp::eqaddr((my $pulled := iterator.pull-one),IterationEnd),
            nqp::if(
              nqp::istype($pulled,Pair),
              nqp::if(
                nqp::getattr(nqp::decont($pulled),Pair,'$!value'),
                nqp::bindkey(
                  elems,
                  nqp::getattr(nqp::decont($pulled),Pair,'$!key').WHICH,
                  nqp::getattr(nqp::decont($pulled),Pair,'$!key')
                )
              ),
              nqp::bindkey(elems,$pulled.WHICH,$pulled)
            )
          ),
          elems
        )
    }

    # Add to given IterationSet with setty semantics the keys of given Map
    method ADD-MAP-TO-SET(\elems, \map) {
        nqp::stmts(
          nqp::if(
            (my $raw := nqp::getattr(nqp::decont(map),Map,'$!storage'))
              && (my $iter := nqp::iterator($raw)),
            nqp::if(
              nqp::eqaddr(map.keyof,Str(Any)),
              nqp::while(                        # normal Map
                $iter,
                nqp::if(
                  nqp::iterval(nqp::shift($iter)),
                  nqp::bindkey(
                    elems,nqp::iterkey_s($iter).WHICH,nqp::iterkey_s($iter))
                )
              ),
              nqp::while(                        # object hash
                $iter,
                nqp::if(
                  nqp::getattr(
                    nqp::decont(nqp::iterval(nqp::shift($iter))),
                    Pair,
                    '$!value'
                  ),
                  nqp::bindkey(
                    elems,
                    nqp::iterkey_s($iter),
                    nqp::getattr(nqp::iterval($iter),Pair,'$!key')
                  )
                )
              )
            )
          ),
          elems
        )
    }

    # remove set elements from set, stop when the result is the empty Set
    method SUB-SET-FROM-SET(\aelems, \belems) {
        nqp::stmts(                            # both have elems
          (my $elems := nqp::clone(aelems)),
          (my $iter  := nqp::iterator(belems)),
          nqp::while(
            $iter && nqp::elems($elems),
            nqp::deletekey($elems,nqp::iterkey_s(nqp::shift($iter)))
          ),
          $elems
        )
    }

    # remove hash elements from set, stop if the result is the empty Set
    method SUB-MAP-FROM-SET(\aelems, \map) {
        nqp::stmts(
          (my $elems := nqp::clone(aelems)),
          nqp::if(
            (my $storage := nqp::getattr(nqp::decont(map),Map,'$!storage'))
             && (my $iter  := nqp::iterator($storage)),
            nqp::if(
              nqp::eqaddr(map.keyof,Str(Any)),
              nqp::while(                     # normal Map
                $iter && nqp::elems($elems),
                nqp::if(
                  nqp::iterval(nqp::shift($iter)),
                  nqp::deletekey($elems,nqp::iterkey_s($iter).WHICH)
                )
              ),
              nqp::while(                     # object hash
                $iter && nqp::elems($elems),
                nqp::if(
                  nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value'),
                  nqp::deletekey($elems,nqp::iterkey_s($iter))
                )
              )
            )
          ),
          $elems
        )
    }

    # remove iterator elements from set using Pair semantics, stops pulling
    # from the iterator as soon as the result is the empty set.
    method SUB-PAIRS-FROM-SET(\elems, \iterator) {
        nqp::stmts(
          (my $elems := nqp::clone(elems)),
          nqp::until(           
            nqp::eqaddr(                            # end of iterator?
              (my $pulled := iterator.pull-one),
              IterationEnd
            ) || nqp::not_i(nqp::elems($elems)),    # nothing left to remove?
            nqp::if(
              nqp::istype($pulled,Pair),
              nqp::if(                              # must check for thruthiness
                nqp::getattr($pulled,Pair,'$!value'),
                nqp::deletekey($elems,nqp::getattr($pulled,Pair,'$!key').WHICH)
              ),
              nqp::deletekey($elems,$pulled.WHICH)  # attempt to remove
            )
          ),
          $elems
        )
    }

#--- Bag/BagHash related methods

    # Calculate total of value of a Bag(Hash).  Takes a (possibly
    # uninitialized) IterationSet in Bag format.
    method BAG-TOTAL(Mu \elems) {
        nqp::if(
          elems && nqp::elems(elems),
          nqp::stmts(
            (my Int $total := 0),
            (my $iter := nqp::iterator(elems)),
            nqp::while(
              $iter,
              $total := nqp::add_I(
                $total,
                nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value'),
                Int
              )
            ),
            $total
          ),
          0
        )
    }

    # Return random iterator item from a given Bag(Hash).  Takes an
    # initialized IterationSet with at least 1 element in Bag format,
    # and the total value of values in the Bag.
    method BAG-ROLL(\elems, \total) {
        nqp::stmts(
          (my Int $rand := total.rand.Int),
          (my Int $seen := 0),
          (my $iter := nqp::iterator(elems)),
          nqp::while(
            $iter &&
              nqp::isle_I(
                ($seen := nqp::add_I(
                  $seen,
                  nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value'),
                  Int
                )),
                $rand
              ),
            nqp::null
          ),
          $iter
        )
    }

    # Return random object from a given BagHash.  Takes an initialized
    # IterationSet with at least 1 element in Bag format, and the total
    # value of values in the Bag.  Decrements the count of the iterator
    # found, completely removes it when going to 0.
    method BAG-GRAB(\elems, \total) {
        nqp::stmts(
          (my $iter := Rakudo::QuantHash.BAG-ROLL(elems,total)),
          nqp::if(
            nqp::iseq_i(
              (my $value := nqp::getattr(nqp::iterval($iter),Pair,'$!value')),
              1
            ),
            nqp::stmts(              # going to 0, so remove
              (my $object := nqp::getattr(nqp::iterval($iter),Pair,'$!key')),
              nqp::deletekey(elems,nqp::iterkey_s($iter)),
              $object
            ),
            nqp::stmts(
              nqp::bindattr(
                nqp::iterval($iter),
                Pair,
                '$!value',
                nqp::sub_i($value,1)
              ),
              nqp::getattr(nqp::iterval($iter),Pair,'$!key')
            )
          )
        )
    }

    method BAGGY-CLONE-RAW(Mu \baggy) {
        nqp::if(
          baggy && nqp::elems(baggy),
          nqp::stmts(                             # something to coerce
            (my $elems := nqp::clone(baggy)),
            (my $iter := nqp::iterator($elems)),
            nqp::while(
              $iter,
              nqp::bindkey(
                $elems,
                nqp::iterkey_s(nqp::shift($iter)),
                nqp::p6bindattrinvres(
                  nqp::clone(nqp::iterval($iter)),
                  Pair,
                  '$!value',
                  nqp::getattr(nqp::iterval($iter),Pair,'$!value')
                )
              )
            ),
            $elems
          ),
          baggy
        )
    }

    method ADD-BAG-TO-BAG(\elems,Mu \bag) {
        nqp::stmts(
          nqp::if(
            bag && nqp::elems(bag),
            nqp::stmts(
              (my $iter := nqp::iterator(bag)),
              nqp::while(
                $iter,
                nqp::if(
                  nqp::existskey(elems,nqp::iterkey_s(nqp::shift($iter))),
                  nqp::stmts(
                    (my $pair := nqp::atkey(elems,nqp::iterkey_s($iter))),
                    nqp::bindattr($pair,Pair,'$!value',
                      nqp::getattr($pair,Pair,'$!value')
                        + nqp::getattr(nqp::iterval($iter),Pair,'$!value')
                    )
                  ),
                  nqp::bindkey(elems,nqp::iterkey_s($iter),
                    nqp::clone(nqp::iterval($iter))
                  )
                )
              )
            )
          ),
          elems
        )
    }

    method ADD-ITERATOR-TO-BAG(\elems,Mu \iterator) {
        nqp::stmts(
          nqp::until(
            nqp::eqaddr((my $pulled := iterator.pull-one),IterationEnd),
            nqp::if(
              nqp::existskey(elems,(my $WHICH := $pulled.WHICH)),
              nqp::stmts(
                (my $pair := nqp::atkey(elems,$WHICH)),
                nqp::bindattr($pair,Pair,'$!value',
                  nqp::add_i(nqp::getattr($pair,Pair,'$!value'),1)
                )
              ),
              nqp::bindkey(elems,$WHICH,Pair.new($pulled,1))
            )
          ),
          elems
        )
    }

    # Add to given IterationSet with baggy semantics the keys of given Map
    method ADD-MAP-TO-BAG(\elems, \map) {
        nqp::stmts(
          nqp::if(
            (my $raw := nqp::getattr(nqp::decont(map),Map,'$!storage'))
              && (my $iter := nqp::iterator($raw)),
            nqp::if(
              nqp::eqaddr(map.keyof,Str(Any)),
              nqp::while(              # ordinary Map
                $iter,
                nqp::if(
                  nqp::istype(
                    (my $value := nqp::iterval(nqp::shift($iter)).Int),
                    Int
                  ),
                  nqp::if(             # a valid Int
                    $value > 0,
                    nqp::if(           # and a positive one at that
                      nqp::existskey(
                        elems,
                        (my $which := nqp::iterkey_s($iter).WHICH)
                      ),
                      nqp::stmts(      # seen before, add value
                        (my $pair := nqp::atkey(elems,$which)),
                        nqp::bindattr(
                          $pair,
                          Pair,
                          '$!value',
                          nqp::getattr($pair,Pair,'$!value') + $value
                        )
                      ),
                      nqp::bindkey(    # new, create new Pair
                        elems,
                        $which,
                        Pair.new(nqp::iterkey_s($iter),$value)
                      )
                    )
                  ),
                  $value.throw         # huh?  let the world know
                )
              ),
              nqp::while(              # object hash
                $iter,
                nqp::if(
                  nqp::istype(
                    ($value := nqp::getattr(
                      nqp::iterval(nqp::shift($iter)),Pair,'$!value'
                    ).Int),
                    Int
                  ),
                  nqp::if(             # a valid Int
                    $value > 0,
                    nqp::if(           # and a positive one at that
                      nqp::existskey(elems,nqp::iterkey_s($iter)),
                      nqp::stmts(      # seen before, add value
                        ($pair := nqp::atkey(elems,nqp::iterkey_s($iter))),
                        nqp::bindattr(
                          $pair,
                          Pair,
                          '$!value',
                          nqp::getattr($pair,Pair,'$!value') + $value
                        )
                      ),
                      nqp::bindkey(    # new, create new Pair
                        elems,
                        nqp::iterkey_s($iter),
                        nqp::p6bindattrinvres(
                          nqp::clone(nqp::iterval($iter)),
                          Pair,
                          '$!value',
                          $value
                        )
                      )
                    )
                  ),
                  $value.throw         # huh?  let the world know
                )
              )
            )
          ),
          elems
        )
    }

    # add to given IterationSet the values of given iterator with Pair check
    method ADD-PAIRS-TO-BAG(\elems,Mu \iterator) {
        nqp::stmts(
          nqp::until(
            nqp::eqaddr(
              (my $pulled := nqp::decont(iterator.pull-one)),
              IterationEnd
            ),
            nqp::if(
              nqp::istype($pulled,Pair),
              nqp::if(               # we have a Pair
                nqp::istype(
                  (my $value :=
                    nqp::decont(nqp::getattr($pulled,Pair,'$!value')).Int),
                  Int
                ),
                nqp::if(             # is a (coerced) Int
                  $value > 0,
                  nqp::if(           # and a positive one at that
                    nqp::existskey(
                      elems,
                      (my $which := nqp::getattr($pulled,Pair,'$!key').WHICH)
                    ),
                    nqp::stmts(      # seen before, add value
                      (my $pair := nqp::atkey(elems,$which)),
                      nqp::bindattr(
                        $pair,
                        Pair,
                        '$!value',
                        nqp::getattr($pair,Pair,'$!value') + $value
                      )
                    ),
                    nqp::bindkey(    # new, create new Pair
                      elems,
                      $which,
                      nqp::p6bindattrinvres(
                        nqp::clone($pulled),
                        Pair,
                        '$!value',
                        $value
                      )
                    )
                  )
                ),
                $value.throw         # value cannot be made Int, so throw
              ),
              nqp::if(               # not a Pair
                nqp::existskey(
                  elems,
                  ($which := $pulled.WHICH)
                ),
                nqp::stmts(
                  ($pair := nqp::atkey(elems,$which)),
                  nqp::bindattr(     # seen before, so increment
                    $pair,
                    Pair,
                    '$!value',
                    nqp::getattr($pair,Pair,'$!value') + 1
                  )
                ),
                nqp::bindkey(        # new, create new Pair
                  elems,$which,Pair.new($pulled,1))
              )
            )
          ),
          elems                      # we're done, return what we got so far
        )
    }

    # Take the given IterationSet with baggy semantics, and add the other
    # IterationSet with setty semantics to it.  Return the given IterationSet.
    method ADD-SET-TO-BAG(\elems,Mu \set) {
        nqp::stmts(
          nqp::if(
            set && nqp::elems(set),
            nqp::stmts(
              (my $iter := nqp::iterator(set)),
              nqp::while(
                $iter,
                nqp::if(
                  nqp::existskey(elems,nqp::iterkey_s(nqp::shift($iter))),
                  nqp::stmts(
                    (my $pair := nqp::atkey(elems,nqp::iterkey_s($iter))),
                    nqp::bindattr($pair,Pair,'$!value',
                      nqp::getattr($pair,Pair,'$!value') + 1
                    )
                  ),
                  nqp::bindkey(elems,nqp::iterkey_s($iter),
                    Pair.new(nqp::iterval($iter), 1)
                  )
                )
              )
            )
          ),
          elems
        )
    }

    method MULTIPLY-BAG-TO-BAG(\elems,Mu \bag) {
        nqp::stmts(
          (my $iter := nqp::iterator(elems)),
          nqp::if(
            bag && nqp::elems(bag),
            nqp::while(
              $iter,
              nqp::if(
                nqp::existskey(bag,nqp::iterkey_s(nqp::shift($iter))),
                nqp::stmts(
                  (my $pair := nqp::iterval($iter)),
                  nqp::bindattr($pair,Pair,'$!value',
                    nqp::mul_i(
                      nqp::getattr($pair,Pair,'$!value'),
                      nqp::getattr(
                        nqp::atkey(bag,nqp::iterkey_s($iter)),
                        Pair,
                        '$!value'
                      )
                    )
                  )
                ),
                nqp::deletekey(elems,nqp::iterkey_s($iter))
              )
            ),
            nqp::while(   # nothing to match against, so reset
              $iter,
              nqp::deletekey(elems,nqp::iterkey_s(nqp::shift($iter)))
            )
          ),
          elems
        )
    }

    method MULTIPLY-SET-TO-BAG(\elems,Mu \set) {
        nqp::stmts(
          (my $iter := nqp::iterator(elems)),
          nqp::if(
            set && nqp::elems(set),
            nqp::while(
              $iter,
              nqp::unless(
                nqp::existskey(set,nqp::iterkey_s(nqp::shift($iter))),
                nqp::deletekey(elems,nqp::iterkey_s($iter))
              )
            ),
            nqp::while(   # nothing to match against, so reset
              $iter,
              nqp::deletekey(elems,nqp::iterkey_s(nqp::shift($iter)))
            )
          ),
          elems
        )
    }

    # set difference Baggy IterSet from Bag IterSet, both assumed to have elems
    method SUB-BAGGY-FROM-BAG(\aelems, \belems) {
        nqp::stmts(
          (my $elems := nqp::create(Rakudo::Internals::IterationSet)),
          (my $iter  := nqp::iterator(aelems)),
          nqp::while(
            $iter,
            nqp::if(
              (my $value :=
                nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value')
                 - nqp::getattr(
                     nqp::ifnull(nqp::atkey(belems,nqp::iterkey_s($iter)),$p0),
                     Pair,
                     '$!value'
                   )
              ) > 0,
              nqp::bindkey(
                $elems,
                nqp::iterkey_s($iter),
                nqp::p6bindattrinvres(
                  nqp::clone(nqp::iterval($iter)),Pair,'$!value',$value
                )
              )
            )
          ),
          $elems
        )
    }

    # set difference Setty IterSet from Bag IterSet, both assumed to have elems
    method SUB-SETTY-FROM-BAG(\aelems, \belems) {
        nqp::stmts(
          (my $elems := nqp::create(Rakudo::Internals::IterationSet)),
          (my $iter  := nqp::iterator(aelems)),
          nqp::while(
            $iter,
            nqp::if(
              (my $value :=
                nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value')
                 - nqp::existskey(belems,nqp::iterkey_s($iter))
              ) > 0,
              nqp::bindkey(
                $elems,
                nqp::iterkey_s($iter),
                nqp::p6bindattrinvres(
                  nqp::clone(nqp::iterval($iter)),Pair,'$!value',$value
                )
              )
            )
          ),
          $elems
        )
    }

    # set difference of a Baggy and a QuantHash
    method DIFFERENCE-BAGGY-QUANTHASH(\a, \b) {
        nqp::if(
          (my $araw := a.raw_hash) && nqp::elems($araw),
          nqp::if(
            (my $braw := b.raw_hash) && nqp::elems($braw),
            nqp::create(Bag).SET-SELF(
              nqp::if(
                nqp::istype(b,Setty),
                self.SUB-SETTY-FROM-BAG($araw, $braw),
                self.SUB-BAGGY-FROM-BAG($araw, $braw)
              )
            ),
            a.Bag
          ),
          nqp::if(
            nqp::istype(b,Failure),
            b.throw,
            bag()
          )
        )
    }

#--- Mix/MixHash related methods

    # Calculate total of values of a Mix(Hash).  Takes a (possibly
    # uninitialized) IterationSet in Mix format.
    method MIX-TOTAL(Mu \elems) {
        nqp::if(
          elems && nqp::elems(elems),
          nqp::stmts(
            (my $total := 0),
            (my $iter := nqp::iterator(elems)),
            nqp::while(
              $iter,
              $total := $total
                + nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value')
            ),
            $total
          ),
          0
        )
    }

    # Calculate total of positive value of a Mix(Hash).  Takes a
    # (possibly uninitialized) IterationSet in Mix format.
    method MIX-TOTAL-POSITIVE(Mu \elems) {
        nqp::if(
          elems && nqp::elems(elems),
          nqp::stmts(
            (my $total := 0),
            (my $iter := nqp::iterator(elems)),
            nqp::while(
              $iter,
              nqp::if(
                0 < (my $value :=
                  nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value')),
                ($total := $total + $value)
              )
            ),
            $total
          ),
          0
        )
    }

    # Return random iterator item from a given Mix(Hash).  Takes an
    # initialized IterationSet with at least 1 element in Mix format,
    # and the total value of values in the Mix.
    method MIX-ROLL(\elems, \total) {
        nqp::stmts(
          (my     $rand := total.rand),
          (my Int $seen := 0),
          (my $iter := nqp::iterator(elems)),
          nqp::while(
            $iter && (
              0 > (my $value :=                      # negative values ignored
                nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value'))
              || $rand > ($seen := $seen + $value)   # positive values add up
            ),
            nqp::null
          ),
          $iter
        )
    }

    # Given an IterationSet in baggy/mixy format considered to contain the
    # final result, add the other IterationSet using Mix semantics and return
    # the first IterationSet.
    method ADD-MIX-TO-MIX(\elems, Mu \mix) {
        nqp::stmts(
          nqp::if(
            mix && nqp::elems(mix),
            nqp::stmts(
              (my $iter := nqp::iterator(mix)),
              nqp::while(
                $iter,
                nqp::if(
                  nqp::isnull((my $pair :=
                    nqp::atkey(elems,nqp::iterkey_s(nqp::shift($iter)))
                  )),
                  nqp::bindkey(                 # doesn't exist on left, create
                    elems,
                    nqp::iterkey_s($iter),
                    nqp::p6bindattrinvres(
                      nqp::clone(nqp::iterval($iter)),
                      Pair,
                      '$!value',
                      nqp::getattr(nqp::iterval($iter),Pair,'$!value')
                    )
                  ),
                  nqp::if(                      # exists on left, update
                    (my $value := nqp::getattr($pair,Pair,'$!value')
                      + nqp::getattr(nqp::iterval($iter),Pair,'$!value')),
                    nqp::bindattr($pair,Pair,'$!value',$value), # valid for Mix
                    nqp::deletekey(elems,nqp::iterkey_s($iter)) # bye bye
                  )
                )
              )
            )
          ),
          elems
        )
    }

    # Add to given IterationSet with mixy semantics the keys of given Map
    method ADD-MAP-TO-MIX(\elems, \map) {
        nqp::stmts(
          nqp::if(
            (my $raw := nqp::getattr(nqp::decont(map),Map,'$!storage'))
              && (my $iter := nqp::iterator($raw)),
            nqp::if(
              nqp::eqaddr(map.keyof,Str(Any)),
              nqp::while(              # normal Map
                $iter,
                nqp::if(
                  nqp::istype(
                    (my $value := nqp::iterval(nqp::shift($iter)).Real),
                    Real
                  ),
                  nqp::if(             # a valid Real
                    $value,
                    nqp::if(           # and not 0
                      nqp::existskey(
                        elems,
                        (my $which := nqp::iterkey_s($iter).WHICH)
                      ),
                      nqp::if(         # seen before, add value or remove if sum 0
                        ($value := nqp::getattr(
                          (my $pair := nqp::atkey(elems,$which)),
                          Pair,
                          '$!value'
                        ) + $value),
                        nqp::bindattr($pair,Pair,'$!value',$value), # okidoki
                        nqp::deletekey(elems,$which)                # alas, bye
                      ),
                      nqp::bindkey(    # new, create new Pair
                        elems,
                        $which,
                        Pair.new(nqp::iterkey_s($iter),$value)
                      )
                    )
                  ),
                  $value.throw         # huh?  let the world know
                )
              ),
              nqp::while(              # object hash
                $iter,
                nqp::if(
                  nqp::istype(
                    ($value := nqp::getattr(
                      nqp::iterval(nqp::shift($iter)),Pair,'$!value'
                    ).Real),
                    Real
                  ),
                  nqp::if(             # a valid Real
                    $value,
                    nqp::if(           # and not 0
                      nqp::existskey(elems,nqp::iterkey_s($iter)),
                      nqp::if(         # seen before: add value, remove if sum 0
                        ($value := nqp::getattr(
                          ($pair := nqp::atkey(elems,nqp::iterkey_s($iter))),
                          Pair,
                          '$!value'
                        ) + $value),
                        nqp::bindattr($pair,Pair,'$!value',$value), # okidoki
                        nqp::deletekey(elems,nqp::iterkey_s($iter)) # alas, bye
                      ),
                      nqp::bindkey(    # new, create new Pair
                        elems,
                        nqp::iterkey_s($iter),
                        nqp::p6bindattrinvres(
                          nqp::clone(nqp::iterval($iter)),
                          Pair,
                          '$!value',
                          nqp::getattr(nqp::iterval($iter),Pair,'$!value')
                        )
                      )
                    )
                  ),
                  $value.throw         # huh?  let the world know
                )
              )
            )
          ),
          elems
        )
    }

    # add to given IterationSet the values of given iterator with Pair check
    method ADD-PAIRS-TO-MIX(\elems,Mu \iterator) is raw {
        nqp::stmts(
          nqp::until(
            nqp::eqaddr(
              (my $pulled := nqp::decont(iterator.pull-one)),
              IterationEnd
            ),
            nqp::if(
              nqp::istype($pulled,Pair),
              nqp::if(               # got a Pair
                (my $value :=
                  nqp::decont(nqp::getattr($pulled,Pair,'$!value'))),
                nqp::if(             # non-zero value
                  nqp::istype($value,Num) && nqp::isnanorinf($value),
                  X::OutOfRange.new( # NaN or -Inf or Inf, we're done
                    what  => 'Value',
                    got   => $value,
                    range => '-Inf^..^Inf'
                  ).throw,
                  nqp::stmts(        # apparently valid
                    nqp::unless(
                      nqp::istype(($value := $value.Real),Real),
                      $value.throw   # not a Real value, so throw Failure
                    ),
                    nqp::if(         # valid Real value
                      nqp::existskey(
                        elems,
                        (my $which := nqp::getattr($pulled,Pair,'$!key').WHICH)
                      ),
                      nqp::if( # seen before, add value
                        ($value := nqp::getattr(
                          (my $pair := nqp::atkey(elems,$which)),
                          Pair,
                          '$!value'
                        ) + $value),
                        nqp::bindattr($pair,Pair,'$!value',$value),  # non-zero
                        nqp::deletekey(elems,$which)                 # zero
                      ),
                      nqp::bindkey(  # new, create new Pair
                        elems,
                        $which,
                        nqp::p6bindattrinvres(
                          nqp::clone($pulled),
                          Pair,
                          '$!value',
                          $value
                        )
                      )
                    )
                  )
                )
              ),
              nqp::if(               # not a Pair
                nqp::existskey(
                  elems,
                  ($which := $pulled.WHICH)
                ),
                nqp::stmts(
                  ($pair := nqp::atkey(elems,$which)),
                  nqp::bindattr(     # seen before, so increment
                    $pair,
                    Pair,
                    '$!value',
                    nqp::getattr($pair,Pair,'$!value') + 1
                  )
                ),
                nqp::bindkey(        # new, create new Pair
                  elems,$which,Pair.new($pulled,1))
              )
            )
          ),
          elems                      # we're done, return what we got so far
        )
    }

    # Take the given IterationSet with mixy semantics, and add the other
    # IterationSet with setty semantics to it.  Return the given IterationSet.
    method ADD-SET-TO-MIX(\elems,Mu \set) {
        nqp::stmts(
          nqp::if(
            set && nqp::elems(set),
            nqp::stmts(
              (my $iter := nqp::iterator(set)),
              nqp::while(
                $iter,
                nqp::if(
                  nqp::existskey(elems,nqp::iterkey_s(nqp::shift($iter))),
                  nqp::if(
                    (my $value := nqp::getattr(
                      (my $pair := nqp::atkey(elems,nqp::iterkey_s($iter))),
                      Pair,
                      '$!value'
                    ) + 1),
                    nqp::bindattr($pair,Pair,'$!value',$value),   # still valid
                    nqp::deletekey(elems,nqp::iterkey_s($iter))   # not, byebye
                  ),
                  nqp::bindkey(elems,nqp::iterkey_s($iter),       # new key
                    Pair.new(nqp::iterval($iter), 1)
                  )
                )
              )
            )
          ),
          elems
        )
    }

    method MULTIPLY-MIX-TO-MIX(\elems,Mu \mix --> Nil) {
        nqp::stmts(
          (my $iter := nqp::iterator(elems)),
          nqp::if(
            mix && nqp::elems(mix),
            nqp::while(
              $iter,
              nqp::if(
                nqp::existskey(mix,nqp::iterkey_s(nqp::shift($iter))),
                nqp::stmts(
                  (my $pair := nqp::iterval($iter)),
                  nqp::bindattr($pair,Pair,'$!value',
                    nqp::getattr($pair,Pair,'$!value')
                    * nqp::getattr(
                        nqp::atkey(mix,nqp::iterkey_s($iter)),
                        Pair,
                        '$!value'
                      )
                  )
                ),
                nqp::deletekey(elems,nqp::iterkey_s($iter))
              )
            ),
            nqp::while(   # nothing to match against, so reset
              $iter,
              nqp::deletekey(elems,nqp::iterkey_s(nqp::shift($iter)))
            )
          )
        )
    }
    method MIX-ALL-POSITIVE(\elems) {
        nqp::stmts(
          (my $iter := nqp::iterator(elems)),
          nqp::while(
            $iter,
            nqp::unless(
              nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value') > 0,
              return False
            )
          ),
          True
        )
    }
    method MIX-ALL-NEGATIVE(\elems) {
        nqp::stmts(
          (my $iter := nqp::iterator(elems)),
          nqp::while(
            $iter,
            nqp::unless(
              nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value') < 0,
              return False
            )
          ),
          True
        )
    }

    method MIX-IS-SUBSET($a,$b) {
        nqp::if(
          nqp::eqaddr(nqp::decont($a),nqp::decont($b)),
          True,                     # X is always a subset of itself
          nqp::if(
            (my $araw := $a.raw_hash) && nqp::elems($araw),
            nqp::if(                # elems in A
              (my $braw := $b.raw_hash) && nqp::elems($braw),
              nqp::stmts(           # elems in A and B
                (my $iter := nqp::iterator($araw)),
                nqp::while(         # check all values in A with B
                  $iter,
                  nqp::unless(
                    nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value')
                      <=            # value in A should be less or equal than B
                    nqp::getattr(
                      nqp::ifnull(nqp::atkey($araw,nqp::iterkey_s($iter)),$p0),
                      Pair,
                      '$!value'
                    ),
                    return False
                  )
                ),

                ($iter := nqp::iterator($braw)),
                nqp::while(         # check all values in B with A
                  $iter,
                  nqp::unless(
                    nqp::getattr(nqp::iterval(nqp::shift($iter)),Pair,'$!value')
                      >=            # value in B should be more or equal than A
                    nqp::getattr(
                      nqp::ifnull(nqp::atkey($araw,nqp::iterkey_s($iter)),$p0),
                      Pair,
                      '$!value'
                    ),
                    return False
                  )
                ),
                True                # all checks worked out, so ok
              ),
              # nothing in B, all elems in A should be < 0
              Rakudo::QuantHash.MIX-ALL-NEGATIVE($araw)
            ),
            nqp::if(
              ($braw := $b.raw_hash) && nqp::elems($braw),
              # nothing in A, all elems in B should be >= 0
              Rakudo::QuantHash.MIX-ALL-POSITIVE($braw),
              False                 # nothing in A nor B
            )
          )
        )
    }

    # set difference QuantHash IterSet from Mix IterSet, both assumed to have
    # elems.  3rd parameter is 1 for Setty, 0 for Baggy semantics
    method SUB-QUANTHASH-FROM-MIX(\aelems, \belems, \issetty) {
        nqp::stmts(
          (my $elems := nqp::create(Rakudo::Internals::IterationSet)),
          (my $iter  := nqp::iterator(belems)),
          nqp::while(                   # subtract all righthand keys
            $iter,
            nqp::bindkey(
              $elems,
              nqp::iterkey_s(nqp::shift($iter)),
              nqp::if(
                issetty,
                Pair.new(
                  nqp::iterval($iter),
                  nqp::getattr(
                    nqp::ifnull(nqp::atkey(aelems,nqp::iterkey_s($iter)),$p0),
                    Pair,
                    '$!value'
                  ) - 1
                ),
                nqp::p6bindattrinvres(
                  nqp::clone(nqp::iterval($iter)),
                  Pair,
                  '$!value',
                  nqp::getattr(
                    nqp::ifnull(nqp::atkey(aelems,nqp::iterkey_s($iter)),$p0),
                    Pair,
                    '$!value'
                  ) - nqp::getattr(nqp::iterval($iter),Pair,'$!value')
                )
              )
            )
          ),
          ($iter := nqp::iterator(aelems)),
          nqp::while(                   # vivify all untouched lefthand keys
            $iter,
            nqp::if(
              nqp::existskey($elems,nqp::iterkey_s(nqp::shift($iter))),
              nqp::unless(              # was touched
                nqp::getattr(
                  nqp::atkey($elems,nqp::iterkey_s($iter)),
                  Pair,
                  '$!value'
                ),
                nqp::deletekey($elems,nqp::iterkey_s($iter)) # but no value
              ),
              nqp::bindkey(             # not touched, add it
                $elems,
                nqp::iterkey_s($iter),
                nqp::p6bindattrinvres(
                  nqp::clone(nqp::iterval($iter)),
                  Pair,
                  '$!value',
                  nqp::getattr(nqp::iterval($iter),Pair,'$!value')
                )
              )
            )
          ),
          $elems
        )
    }

    # set difference of a Mixy and a QuantHash
    method DIFFERENCE-MIXY-QUANTHASH(\a, \b) {
        nqp::if(
          (my $araw := a.raw_hash) && nqp::elems($araw),
          nqp::if(
            (my $braw := b.raw_hash) && nqp::elems($braw),
            nqp::create(Mix).SET-SELF(
              self.SUB-QUANTHASH-FROM-MIX($araw, $braw, nqp::istype(b,Setty)),
            ),
            a.Mix
          ),
          nqp::if(
            nqp::istype(b,Failure),
            b.throw,
            nqp::if(
              ($braw := b.raw_hash) && nqp::elems($braw),
              nqp::stmts(
                (my $elems := nqp::clone($braw)),
                (my $iter  := nqp::iterator($braw)),
                nqp::while(
                  $iter,
                  nqp::bindkey(    # clone with negated value
                    $elems,
                    nqp::iterkey_s(nqp::shift($iter)),
                    nqp::p6bindattrinvres(
                      nqp::clone(nqp::iterval($iter)),
                      Pair,
                      '$!value',
                      - nqp::getattr(nqp::iterval($iter),Pair,'$!value')
                    )
                  )
                ),
                nqp::create(Mix).SET-SELF($elems)
              ),
              mix()
            )
          )
        )
    }
}

# vim: ft=perl6 expandtab sw=4
