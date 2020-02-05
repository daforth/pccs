local pccs
local function newpobj(callf)
  local mt = {
    __bnot=function(a)
      return newpobj(function()
          return  "'" .. a()
      end)
    end,
    __sub=function(a,b)
      return newpobj(function()
          return  '('.. a() .. ' \\ ' .. b() .. ')'
      end)
    end,
    __div=function(a,b)
      return newpobj(function()
          return  a() .. ' / ' .. b()
      end)
    end,
    __bor=function(a,b)
      return newpobj(function()
          return '(' .. a() .. ' | ' .. b() .. ')'
      end)
    end,
    __concat=function(a,b)
      return newpobj(function()
          return '(' .. a() .. ' . ' .. b() .. ')'
      end)
    end,
    __add=function(a,b)
      return newpobj(function()
          return '(' .. a() .. ' + ' .. b() .. ')'
      end)
    end,
    __call=callf
  }
  local t = {__type='pname'}
  return setmetatable(t, mt)
end

local function loadsafe(str)
  local t = table.pack(load('return ' .. str, nil, 't', pccs)())
  for i=1,t.n do
    if type(t[i]) == 'table' then
      t[i] = t[i]()
    end
  end
  return table.unpack(t)
end

-- call f with env set by looping over ranges ... (range: {'j', 1, 3})
local function rangeswalker(f, ...)
  local nr = select('#', ...)
  if nr == 0 then
    f()
  else
    local r = (...)
    if r[4] then
      for i=r[2],r[3],r[4] do
        pccs[r[1]]=i
        rangeswalker(f, select(2,...))
      end
    else
      for i=r[2],r[3] do
        pccs[r[1]]=i
        rangeswalker(f, select(2,...))
      end
    end
    pccs[r[1]]=nil
  end
end

local function rangesacc(rf, f, ranges)
  ranges = ranges or {}
  if type(rf) == "string" then
    table.insert(ranges, rf)
    return function(nrf)
      return rangesacc(nrf, f, ranges)
    end
  else
    return f(ranges,rf)
  end
end

local function evalrange(range)
  local name, ab = string.match(range, "(.*):(.*)")
  --return {name,   assert(load('return ' .. ab, nil, 't', pccs))()}
  return {name, loadsafe(ab)}
end

local function evalranges(ranges)
  for i,v in ipairs(ranges) do
    ranges[i] = evalrange(v)
  end
end

local function operator(sym)
  return function (ranges, body)
    if body == nil then error ("Range operator "..sym.." needs at least one argument") end
    if #ranges == 0 then error ("Range operator "..sym.." needs at least one range") end
    return newpobj(function ()
        local operands = {}
        local function addoperands()
          table.insert(operands, body[1]())
        end
        evalranges(ranges)
        rangeswalker(addoperands, table.unpack(ranges))
        return '('..table.concat(operands, ' ' .. sym .. ' ')..')'
    end)
  end
end


local function definition (rf, class)
  local function _def(ranges, body)
    if body == nil then error ("A "..class.." definition needs at least one table argument") end
    if #body ~= 2 then error ("A "..class.." definition requires two arguments in following table") end
    local function adddef()
      table.insert(pccs.__result, class..' '..body[1]()..' = '..body[2]())
    end
    if ranges and #ranges ~= 0 then
      evalranges(ranges)
      rangeswalker(adddef ,table.unpack(ranges))
    else
      adddef()
    end
  end
  return rangesacc(rf, _def)
end

local function proc(rf)
  return definition(rf, 'proc')
end

local function dset(rf)
  return definition(rf, 'set')
end

-- return an array with the ranges
local function getranges(el)
  local j = 1
  local ranges={}
  while type(el[j]) == "string" do
    table.insert(ranges, el[j])
    j = j + 1
  end
  if j ~= #el or j == 1 then error("The first arguments should be string ranges") end
  return ranges
end

-- make a list for set and rel
local function makelist(t)
  local actions={}
  for _, el in ipairs(t) do
    if type(el) == "table" and el.__type ~= "pname" then
      local ranges = getranges(el)
      local function addaction()
        table.insert(actions, el[#el]())
      end
      evalranges(ranges)
      rangeswalker(addaction ,table.unpack(ranges))
    else
      table.insert(actions, el())
    end
  end
  return table.concat(actions, ', ')

end

local function set(t)
  if type(t) ~= 'table' then error("Set requires a table argument in first position") end
  return newpobj(function()
      return '{'..makelist(t)..'}'
  end)
end

local function rel(t)
  if type(t) ~= 'table' then error("Rel requires a table argument in first position") end
  if #t < 2 then error("Rel requires as input a table containing at least two elements") end
  local name = table.remove(t,1)
  if name.__type ~= "pname" then error("First argument must be a name") end
  return newpobj(function()
      return '('..name()..'['..makelist(t)..'])'
  end)
end

local function sum(rf)
  return rangesacc(rf, operator('+'))
end

local function pre(rf)
  return rangesacc(rf, operator('.'))
end

local function par(rf)
  return rangesacc(rf, operator('|'))
end

local function refreshenv()
  pccs = {}
  pccs.__result = {}
  pccs.proc = proc
  pccs.dset = dset
  pccs.set = set
  pccs.rel = rel
  pccs.sum = sum
  pccs.pre = pre
  pccs.par = par
  setmetatable(pccs, {__index = function(self, key)
                        return newpobj(
                          function(_, str)
                            if type(str) == "string" then
                              return newpobj(function()
                                  return table.concat({key, loadsafe(str)}, '_')
                              end)
                            else
                              return key
                            end
                        end)
  end})
end

local function compile(str)
  refreshenv()
  load(str, nil, "t", pccs)()
  return table.concat(pccs.__result, '\n')
end

return compile
