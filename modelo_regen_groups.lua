import("gis")

proj  = Project {
    file = "project_regen.qgs",
    grid = "dados/CELL_GRID_ENTRADA_MODELO.shp",
    clean = true,
}
INC = {
    .287,
    .325,
    .437,
    .452,
    .470,
    .478,
    .531,
    .417,
    .0
}

DMC = 6

CUT_CICLE = 30

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

cell = Cell{
    trees_cut = 0,
    trees_seeds = 0,
    treees_reman = 0,
    all_trees = 0,
    init = function(self)
            self.class1 = {}
            self.class2 = {}
            self.class3 = {}
            self.class4 = {}
            self.class5 = {}
            self.class6 = {}
            self.class7 = {}
            self.class8 = {}
            self.class9 = {}
        -- to groups
        for c=1,9 do
            table.insert(self["class"..c], {d=c*10-10, q=self["class"..c.."_sum"]})
        end
        self:update_dest()
    end,
    trees_count = function(self, from, to)
        local trees = 0
        for c=from,to do
            for i in pairs(self["class"..c]) do
                trees = trees + self["class"..c][i].q
            end
        end
        return trees
    end,
    update_dest = function(self)
        local cut = self:trees_count(DMC, 9)
        local seeds = math.ceil(cut * 0.1)
        cut = cut - seeds
        local reman = self:trees_count(DMC-2, DMC-1)
        if reman < seeds and cut > 0 then
            cut = cut - (seeds - reman)
            reman = seeds
        end
        self.trees_cut = cut
        self.trees_seeds = seeds
        self.trees_reman = reman
        self.all_trees = self:trees_count(1,9)
    end,
    regen = function(self)
        for c=8,1,-1 do
            local group = deepcopy(self["class"..c])
            for i,v in pairs(group) do
                v.d = v.d + INC[c]
                if v.d >= c*10 then
                    table.insert(self["class"..(c+1)],{d=v.d, q=v.q})
                    group.i = nil
                end
            end
            self["class"..c] = group
        end
        table.insert(self.class1,{d=0, q= 16})
    end,
    extract = function(self)

    end,
}

cs = CellularSpace {
    project = proj,
    layer  = "grid",
    missing = 0,
    instance = cell,
}

t = Timer{
    Event{action= function()
            print(t:getTime())
            cs:regen()
            if t:getTime()%CUT_CICLE == 0 then
                --print(cs:trees_cut())
                --cs:extract()
            end
            --cs:update_dest()
        end
    }
}
print(cs:all_trees())
t:run(90)
cs:update_dest()
print(cs:all_trees())





