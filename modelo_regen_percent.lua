import("gis")

proj  = Project {
    file = "project_regen.qgs",
    grid = "dados/CELL_GRID_ENTRADA_MODELO.shp",
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
-- author year   death
-- Higuchi 2004  4.7
-- MPEG 2004     4.18
-- Versides 2010   8
-- Andrade 2018 T0 = 11.64, T1 = 21.3 
-- Souza  2012    6.7

NAME = "borges"
NEW_TREES = 16      -- tree/ha/year (11.35)
DEATH = 0           -- tree/ha/year (6.7)
IDAs = {}
IDAs["braz_2017"] = {
    0.291,        -- class1
    0.317,        -- class2
    0.442,        -- class3
    0.473,        -- class4
    0.623,        -- class5
    0.587,        -- class6
    0.587,        -- class7
    0.717,        -- class8
    0.836,        -- class9
}
IDAs["borges"] = {
    .287,
    .325,
    .437,
    .452,
    .470,
    .478,
    .531,
    .417,
    .0,
}
IDAs["canneti"] = {
    .283,
    .377,
    .451,
    .475,
    .485,
    .493,
    .569,
    .580,
    .546,
}
IDAs["oliveira"] = {
    .427,
    .606,
    .720,
    .805,
    .710,
    .751,
    .903,
    .816,
    .838,
}

INC = IDAs[NAME]
DMC = 6           -- class dmc of (50 cm)
CUT_CICLE = 30    -- lapse between cut cicles
YPL = 10          -- years per loop
time = 90         -- years of simulation
DAMAGE_EXP = 82   -- damage during exploaration
DAMAGE_AFTER = 64 -- damage after exploration

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
        cut = cut - seeds
        local reman = self:trees_count(DMC-2, DMC-1)

        -- remaining trees should be at least 10% of cut trees
        if reman < seeds and cut > 0  then
            cut = cut - (seeds - reman)
            reman = seeds
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
    regen = function(self)
        -- Growing trees
        for i = 8, 1, -1 do
            local growing = 0
            growing = self["class"..i.."_sum"] * 0.30 * YPL * INC[i] / 3
            growing = round(growing)
            if self["class"..i.."_sum"] == 1 then
                growing = 1
            end
            self["class"..(i+1).."_sum"] = self["class"..(i+1).."_sum"] + growing
            self["class"..i.."_sum"] = self["class"..i.."_sum"] - growing
        end
        -- Adding new trees
        self.class1_sum = self.class1_sum + NEW_TREES * YPL
        -- Death
        local young = math.ceil(DEATH * YPL * 0.6)
        self.death(young)
        self.death(DEATH - young, 9, 1)
    end,
    death = function(self, total, left, right)
        right = right or 9
        left = left or 1
        local i
        if left < right then 
            i = 1
        else 
            i = -1
        end

        for c = left, right, i do
            if total <= 0 then 
                break 
            end
            total = total - self["class"..c.."_sum"]
            self["class"..c.."_sum"] = 0
            if total < 0 then
                self["class"..c.."_sum"] = -total
            end
            c = c + i
        end 
    end,
    extract = function(self)
        local trees_total = self.trees_cut
        local trees = 0
        local c = 9
        -- extrating trees
        while trees < trees_total and c >= DMC do
            trees = trees + self["class"..c.."_sum"]
            if trees > trees_total then
                self["class"..c.."_sum"] = trees - trees_total
                trees = trees_total
            else
                self["class"..c.."_sum"] = 0
            end
            c = c - 1
        end
        self.trees_cut = 0
        -- damaging
        self.death(DAMAGE_EXP + DAMAGE_AFTER)
    end
}

cs = CellularSpace {
    project = proj,
    layer  = "grid",
    missing = 0,
    instance = cell,
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
    trees_seeds = {cs:trees_seeds()}
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
        trees_seeds = cs:trees_seeds()
    }
end

t = Timer{
    Event{ action = function()
            local curr = t:getTime()
            cs:regen()
            cs:update_dest()
            if curr%(CUT_CICLE//YPL) == 0 then
                cuts:add{cut=cs:trees_cut()}
                cs:extract()
            end
            toDF()
    end},
}

round = function(x)
    if x%1 >= 0.5 then
        return math.ceil(x)
    else
        return math.floor(x)
    end
end

t:run(time//YPL)
print("Saving output...")
df:save(NAME.."/"..NAME.."ex.csv")
--cs:save(NAME, {"class1_sum","class2_sum","class3_sum","class4_sum","class5_sum","class6_sum","class7_sum","class8_sum","class9_sum", "trees_cut","trees_seeds", "trees_reman"})
cuts:save(NAME.."/cutsex.csv")
print("Output saved")