proc {SF , par 'j:1,3' 'y:1,4' {GC + LT 'j,y'} | sum 's:4,5' {FF}}

proc 'j:2,4' {GN 'j', act 'j'}

-- rel new/old

dset 'z:7,9' {Name, set { {'j:2,4', act 'j,z'}, {'i:3,5', ict 'i'}, act2 }}


