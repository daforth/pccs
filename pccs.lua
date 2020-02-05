local function newpobj(callf)
  local mt = {
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
  local t = {}
  return setmetatable(t, mt)
end

local pccs = {}
setmetatable(pccs, {__index = function(self, key)
                      return newpobj(
                        function(_, str)
                          if type(str) == "string" then
                            return newpobj(function()
                                return table.concat({key, load('return ' .. str, nil, 't', pccs)()}, '_')
                            end)
                          else
                            return key
                          end
                      end)
end})

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
  return {name, assert(load('return ' .. ab, nil, 't', pccs))()}
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

pccs.__result = {}

function pccs.proc(rf)

end

function pccs.sum(rf)
  return rangesacc(rf, operator('+'))
end

function pccs.pre(rf)
  return rangesacc(rf, operator('.'))
end

function pccs.par(rf)
  return rangesacc(rf, operator('|'))
end

pccs.print = print
local f = io.open 'test.lua'
load(f:read("a"), nil, "t", pccs)()
f:close()
