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

IMAGE = "braz(2017)"
DMC = 6           -- class dmc of (50 cm)
NEW_TREES = 16    -- tree/ha/ano
INC = {
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

CUT_CICLE = 30    -- lapse between cut cicles
YPL = 10          -- years per loop
time = 90         -- years of simulation
DAMAGE_EXP = 82   -- damage during exploaration
DAMAGE_AFTER = 64 -- damage after exploration

cell = Cell{
    trees_cut   = 0,
    trees_reman = 0,
    trees_seeds = 0,
    init = function(self)
        self:update_dest()
    end,
    update_dest = function(self)
        local cut = self:trees_count(DMC, 9)
        local reman = math.ceil(cut * 0.1)
        local true_reman = self:trees_count(DMC-2, DMC-1)

        self.trees_seeds = math.ceil(cut * 0.1)
        -- remaining trees should be at least 10% of cut trees
        if true_reman >= reman then
            self.trees_cut = cut - self.trees_seeds
            self.trees_reman = true_reman
        else
            self.trees_cut = cut - (self.trees_seeds + reman - true_reman)
            self.trees_reman = reman
        end
    end,
    trees_count = function(self, from, to)
        local trees = 0
        for i = from, to do
            trees = trees + self["class"..i.."_sum"]
        end
        return trees
    end,
    diameter = {},
    all_trees = function(self)
        return self:trees_count(1, 9)
    end,
    regen = function(self)
        for i = 8, 1, -1 do
            local growing = 0
            growing = self["class"..i.."_sum"] * 0.10 * (YPL / INC[i])

            if growing > 1 then
                growing = math.floor(growing)
            else
                growing = math.ceil(growing)
            end
            self["class"..(i+1).."_sum"] = self["class"..(i+1).."_sum"] + growing
            self["class"..i.."_sum"] = self["class"..i.."_sum"] - growing
        end
        -- Adding new trees
        self.class1_sum = self.class1_sum + NEW_TREES * YPL
    end,
}

madeireiro = Agent{
    name = "RIL",
    cicle = CUT_CICLE,
    extract = function()
        forEachCell(cs, function(self)
                if self.trees_cut > 0 then
                    local trees = self.trees_cut
                    local dmg_total = DAMAGE_EXP + DAMAGE_AFTER
                    -- exploration
                    local i = 9
                    while trees > 0 and i >= DMC do
                        if trees >= self["class"..i.."_sum"] then
                            trees = trees - self["class"..i.."_sum"]
                            self["class"..i.."_sum"] = 0
                        else
                            self["class"..i.."_sum"] = self["class"..i.."_sum"] - trees
                            trees = 0
                        end
                        i = i - 1
                    end
                    -- damaging
                    i = 1
                    while dmg_total > 0 and i <= 9 do
                        if dmg_total >= self["class"..i.."_sum"] then
                            dmg_total = dmg_total - self["class"..i.."_sum"]
                            self["class"..i.."_sum"] = 0
                        else
                            self["class"..i.."_sum"] = self["class"..i.."_sum"] - dmg_total
                            dmg_total = 0
                        end
                        i = i + 1
                    end
                end
        end)
    end,

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

all_trees = function()
    local trees = 0
    forEachCell(cs, function(self)
            trees = trees + self:all_trees()
        end)
    return trees
end

t = Timer{
    Event{priority=-1, action = function()
            print(t:getTime())
            cs:regen()
            cs:update_dest()
            map1:update()
    end},
    Event{period = madeireiro.cicle//YPL, action = function()
            local trees_b = all_trees()
            print("trees before:",trees_b)
            map1:save(IMAGE.."antes"..t:getTime()..".png")
            madeireiro:extract()
            map1:update()
            map1:save(IMAGE.."depois"..t:getTime()..".png")
            local trees_a = all_trees()
            print("trees extracted:", trees_b - trees_a)
            print("trees after:", trees_a)
            print("-----------")
    end},
    Event {action = function()
            toDF()
    end}
}

map1 = Map{
    target = cs,
    title = "Total arvores",
    select = "all_trees",
    slices = 10,
    color = "YlOrRd",
    min = 0,
    max = 2500
}

map1:save(IMAGE.."inicial.png")
t:run(time//YPL)
map1:save(IMAGE.."final.png")
df:save(IMAGE..".csv")
