import("gis")

proj  = Project {
    file = "abm-tree-harvest.qgs",
    grid = "dados/input/CELL_GRID_ENTRADA_MODELO.shp",
    clean = true,
}

--[[
class 1 = [0, 10)
class 2 = [10,20)
...
class 6 = [50, 60)
...
class 9 = [80, inf)
]]--

NAME = "borges"   -- select a diametric increment
NEW_TREES = 0.7     -- % of new trees
DEATH = 0.7        -- % of trees to die
IDA = {             -- anual diametric increment
    braz_2017 = {
        0.291,        -- class1
        0.317,        -- class2
        0.442,        -- class3
        0.473,        -- class4
        0.623,        -- class5
        0.587,        -- class6
        0.587,        -- class7
        0.717,        -- class8
        0.836,        -- class9
    },
    borges = {  -- pessimistic
        .287,
        .325,
        .437,
        .452,
        .470,
        .478,
        .531,
        .417,
        .0,
    },
    canneti = {
        .283,
        .377,
        .451,
        .475,
        .485,
        .493,
        .569,
        .580,
        .546,
    },
    oliveira = {  -- otimistic
        .427,
        .606,
        .720,
        .805,
        .710,
        .751,
        .903,
        .816,
        .838,
    },
}

DMC = 6           -- class dmc of (50 cm)
CUT_CICLE = 30    -- lapse between cut cicles
YPL = 10          -- years per loop
time = 90         -- years of simulation
DAMAGE_EXP = 18   -- collateral damage of exploration exploaration

cell = Cell{
    trees_cut = 0,
    trees_reman = 0,
    trees_seeds = 0,
    all_trees = 0,
    init = function(self)
        self:update_dest()
    end,
    update_dest = function(self)
        local cut = self:trees_count(DMC, 9)
        local seeds = math.ceil(cut * 0.1)
        local reman = self:trees_count(DMC-2, DMC-1)

        -- remaining trees should be at least 10% of cut trees
        if reman < seeds then
            if cut > 2*seeds then
                cut = cut - 2 * seeds
                reman = seeds
            elseif cut > 0 then
                reman = reman + cut
                cut = 0
            end
        end
        self.trees_cut = cut
        self.trees_seeds = seeds
        self.trees_reman = reman
        self.all_trees = self:trees_count(1,9)
    end,
    trees_count = function(self, from, to)
        local trees = 0
        for i = from, to do
            trees = trees + self["class"..i.."_sum"]
        end
        return trees
    end,
    update = function(self, all_trees)
        self:grow()
        -- run birth and death YPL times
        for _ = 1, YPL do
            local new_trees = all_trees * (NEW_TREES/100) / CELLS_Q
            new_trees = round(new_trees)
            self:birth(new_trees)
            local trees_death = all_trees * (DEATH/100) / CELLS_Q
            trees_death = round(trees_death)
            self:death(trees_death,1,9)
        end
    end,
    birth = function(self, total)
        self.class1_sum = self.class1_sum + total
        self.all_trees = self.all_trees + total
    end,
    grow = function(self)
        for i = 8, 1, -1 do
            local growing
            local class = "class"..i.."_sum"
            growing = self[class] * 0.10 * YPL * IDA[NAME][i]
            growing = round(growing)
            if self[class] == 1 then
                growing = 1
            end
            self["class"..(i+1).."_sum"] = self["class"..(i+1).."_sum"] + growing
            self[class] = self[class] - growing
        end
    end,
    death = function(self, total, left, right)
        local c = left
        local class
        while total > 0 and left <= c and c <= right do
            class = "class"..c.."_sum"
            total = total - self[class]
            self[class] = 0
            c = c + 1
        end
        if total < 0 then
            self[class] = -total
            total = 0
        end
        return total
    end,
    extract = function(self)
        local c = 9
        local class
        local dmg = DAMAGE_EXP * self.trees_cut
        -- extrating trees
        while self.trees_cut > 0 and c >= DMC do
            class = "class"..c.."_sum"
            self.trees_cut = self.trees_cut - self[class]
            self.all_trees = self.all_trees - self[class]
            self[class] = 0
            c = c - 1
        end
        -- make shure to cut just right amount
        if self.trees_cut < 0 then
            self[class] = - self.trees_cut
            self.all_trees = self.all_trees + self[class]
            self.trees_cut = 0
        end
        -- damaging
        -- self:death(dmg, 1, 9)
    end
}

cs = CellularSpace {
    project = proj,
    layer  = "grid",
    missing = 0,
    instance = cell,
}
CELLS_Q = #cs -- quantity of cells

traj= Trajectory {
    target = cs,
    greater = greaterByAttribute("all_trees")
}

aux_death = function(dead)
    forEachCell(traj, function(self)
            if dead <= 0 then return end
            self:death(1,1,9)
            dead = dead - 1
    end)
end

traj2 = Trajectory {
    target = cs,
    greater = function(c,d)
        return c.all_trees < d.all_trees
    end
}

aux_birth = function(new_trees)
    forEachCell(traj, function(self)
            if new_trees <= 0 then return end
            self:birth(1)
            new_trees = new_trees - 1
    end)
end

c = Cell {
    all_trees = function() return cs:all_trees() end
}

map1 = Map{
    target = cs,
    select = "all_trees",
    color = "Greens",
    min = 0,
    max =  60,
    slices = 6,
}

map2 = Map{
    target = cs,
    select = "trees_cut",
    color = "Reds",
    min = 0,
    max =  60,
    slices = 6,
}

df = DataFrame{
    class1 = {cs:class1_sum()},
    class2 = {cs:class2_sum()},
    class3 = {cs:class3_sum()},
    class4 = {cs:class4_sum()},
    class5 = {cs:class5_sum()},
    class6 = {cs:class6_sum()},
    class7 = {cs:class7_sum()},
    class8 = {cs:class8_sum()},
    class9 = {cs:class9_sum()},
    trees_cut = {cs:trees_cut()},
    trees_reman = {cs:trees_reman()},
    trees_seeds = {cs:trees_seeds()},
    all_trees ={cs:all_trees()}
}

cuts = DataFrame{
    cut= {cs:trees_cut()}
}

toDF = function()
    df:add{
        class1 = cs:class1_sum(),
        class2 = cs:class2_sum(),
        class3 = cs:class3_sum(),
        class4 = cs:class4_sum(),
        class5 = cs:class5_sum(),
        class6 = cs:class6_sum(),
        class7 = cs:class7_sum(),
        class8 = cs:class8_sum(),
        class9 = cs:class9_sum(),
        trees_cut = cs:trees_cut(),
        trees_reman = cs:trees_reman(),
        trees_seeds = cs:trees_seeds(),
        all_trees= cs:all_trees()
    }
end

t = Timer{
    Event{priority = -5, action = function()
            local total = cs:all_trees()
            local new_trees = round(total * NEW_TREES/100)
            local die = round(total *  DEATH/100)
            aux_birth(new_trees%CELLS_Q)
            aux_death(die%CELLS_Q)
            cs:update(total)
            cs:update_dest()
    end},
    Event{period=CUT_CICLE//YPL, action = function()
            local cut = cs:trees_cut()
            print("extracted: "..cut)
            cuts:add{cut=cut}
            cs:extract()
            print("total: "..cs:all_trees())
    end},
    Event{priority = 5,action=function()
            map1:update()
            map2:update()
            toDF()
    end}
}

stats = function()
    print("----------")
    local max = cs:sample().all_trees
    local min = max
    forEachCell(cs, function(self)
            if min > self.all_trees then min = self.all_trees end
            if max < self.all_trees then max = self.all_trees end
        end)
    print("mean: "..cs:all_trees()/#cs)
    print("min: "..min)
    print("max: "..max)
    print("total: "..cs:all_trees())
    print("----------")
end

t:run(time//YPL)


print("Saving output...")
df:save("dados/output/result.csv")
cs:save("result",{"trees_cut","trees_seeds", "trees_reman"})
cuts:save("dados/output/cut.csv")
map1:save("all_trees.png")
map2:save("trees_cut.png")
print("Output saved")


-- utils
round = function(x)
    if x%1 >= 0.5 then
        return math.ceil(x)
    else
        return math.floor(x)
    end
end