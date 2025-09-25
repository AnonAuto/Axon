Set = {}
   
function Set:new(t)
  local set = {}
  setmetatable(set, self)
  self.__index = self
  for _, l in ipairs(t) do set[l] = true end
  return set
end
    
function Set.union (a,b)
  local res = Set.new{}
  for k in pairs(a) do res[k] = true end
  for k in pairs(b) do res[k] = true end
  return res
end
    
function Set.intersection (a,b)
  local res = Set.new{}
  for k in pairs(a) do
    res[k] = b[k]
  end
  return res
end

function Set.contains(set, a)
  return set[a]
end

function Set.add(set, a)
  if (type(a) == "table") then
    for k in pairs(a) do set[k] = true end
  else
    set[a] = true
  end
  return set
end

function Set.toarray(set)
  local r = {}
  for k in pairs(set) do table.insert(r, k) end
  return r
end

function Set.tostring (set)
  local s = "{"
  local sep = ""
  for e in pairs(set) do
    s = s .. sep .. e
    sep = ", "
  end
  return s .. "}"
end
    
function Set.print (s)
  print(Set.tostring(s))
end

Set.__add = Set.union
Set.__mul = Set.intersection
Set.__concat = Set.union


