proc {SF , par 'j:1,3' 'y:1,4' {GC + LT 'j,y'} | sum 's:4,5' {FF}}

proc 'j:2,4' {GN 'j', act 'j'}

-- rel new/old

proc {Name, rel { A, {'j:2,3', act 'j' / bact 'j'}, {'i:3,5', ict 'i'}, act2 } }

f = 3
proc { name, jj 'f' | ~act 'f' - ll}

-- proc 'f:1,3' { CB , A 'f' - set {~act1, act2} }
