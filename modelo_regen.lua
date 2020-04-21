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
extracted = {}
DMC = 6           -- class dmc of (50 cm)
NEW_TREES = 16    -- tree/ha/ano
INC = 0.3         -- cm/year (base, class1)
time = 110        -- years of simulation
DAMAGE_EXP = 82
DAMAGE_AFTER = 64
cell = Cell{
    trees_cut   = 0,
    trees_reman = 0,
    trees_seeds = 0,
    init = function(self)
        for i = 1, 9 do
            if self["class"..i.."_sum"] > 0 then
                self.diameter[i] = i*10 - 10
            else
                self.diameter[i] = 0
            end
        end
        --self.tree_an = self:trees_total()
    end,
    update = function(self)
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
    trees_total = function(self)
        return self:trees_count(1, 9)
    end,
    regen = function(self)
        for i = 8, 1, -1 do
            if self["class"..i.."_sum"] > 0 then
                self.diameter[i] = self.diameter[i] + INC
            end

            if self.diameter[i] >=  i*10 then
                local trees = self["class"..i.."_sum"]
                local trees_next = self["class"..(i+1).."_sum"]
                self["class"..(i+1).."_sum"] = trees_next + trees
                if self.diameter[i+1] == 0 then
                    self.diameter[i+1] = i*10
                end
                self.diameter[i] = 0
                self["class"..i.."_sum"] = 0
            end
        end
        self["class1_sum"] = self["class1_sum"] + NEW_TREES
    end,
}

madeireiro = Agent{
    name = "RIL",
    cicle = 25,
    extrair = function()
        forEachCell(cs, function(self)
                if self.trees_cut > 0 then
                    local trees = self.trees_cut
                    local i = 9
                    local dmg_total = DAMAGE_EXP + DAMAGE_AFTER
                    -- exploration
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

all_trees = function()
    local trees = 0
    forEachCell(cs, function(self)
            trees = trees + self:trees_total()
        end)
    return trees
end

t = Timer{
    Event{action = function()
            cs:regen()
            cs:update()
            map1:update()
            os.execute("ping -n " .. tonumber(0+1) .. " localhost > NUL")
    end},
    Event{period = madeireiro.cicle, action = function()
            local trees_b = all_trees()
            --local trees_a = 0
            print("trees before:",trees_b)
            map1:save("antes.png")
            madeireiro:extrair()
            map1:update()
            map1:save("depois.png")
            local trees_a = all_trees()
            print("trees extracted:", trees_b - trees_a)
            print("trees after:",trees_a)
            print("-----------")
            table.insert(extracted, trees_b - trees_a)

    end}
}

map1 = Map{
    target = cs,
    title = "Total arvores",
    select = "trees_total",
    slices = 10,
    color = "YlOrRd",
    min = 0,
    max = 300
}

map1:save("inicial.png")
t:run(time)
map1:save("final.png")

for i = 0, table.maxn(extracted) do
    print(i..".", extracted[i])
end