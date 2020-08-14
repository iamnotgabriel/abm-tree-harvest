import("gis")
-- set a fixed random seed
random= Random()
random:reSeed(42)
-- reading the data
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
final_chart = {
    arv_ext = {},
    vol_ext = {}
}

IDA_DT = "borges"   -- select a diametric increment
BD_DT =  "gouveia"  -- select birth and death rate
arq_name = IDA_DT.."-"..BD_DT
IDA = {             -- annual diametric increment
    braz_2017 = {
        0.291,        -- class1
        0.317,        -- class2 (birth class)
        0.442,        -- class3
        0.473,        -- class4
        0.623,        -- class5
        0.587,        -- class6
        0.587,        -- class7
        0.717,        -- class8
        0.836,        -- class9
    },
    borges = { -- slow
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
    oliveira = { -- fast
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
    mean = { -- intermeditate
        .290,
        .413,
        .451,
        .551,
        .617,
        .598,
        .658,
        .684,
        .712,
    },
}

BIRTH_DEATH = {
    colpini =   {birth=0.3, death=0.78},   -- -0.48
    andrade_t1 ={birth=2.51, death=1.7},   -- +0.81
    higuchi =   {birth=0.7, death=0.7},    --  0.00
    rocha =     {birth=0.9, death=0},      -- +0.04
    souza =     {birth=1.9, death=1.13},   -- +0.77
    oliveira_t0 = {birth=1, death=1.2},    -- +0.20
    oliveira_t1 = {birth=2, death=2},      --  0.00 PMFS
    oliveira_t3 = {birth=3.5, death=2.5},  -- +1.00 PMFS
    gouveia_t1  = {birth=3.3, death=2.6},  -- +0.70 PMFS
    gouveia_t2  = {birth=3.78, death=2.94},-- +0.84 PMFS
    gouveia     = {birth=3.54, death=2.77},-- +0.77 SELECTED
    oliveira_16 = {birth=4.57, death=3.62} -- +0.95 PMFS
}
DMC = 6           -- class dmc of (50 cm)
CUT_CICLE = 30    -- lapse between cut cicles
YPL = 10          -- years per loop
TIME = 90         -- years of simulation
-- collateral damage of exploration exploaration
DAMAGE_EXP = .13  -- % of trees in cell
FIRST_CLASS = 1   -- start class of new trees
if BD_DT == "oliveira_16" then FIRST_CLASS = 2 end
CUT_VOL = 3.3340  -- volume of one cut tree
REMAN_VOL = 0.9822
SEEDS_VOL = 1.7466
-- multiply MAX_VOL with #cs
MAX_VOL = 30      -- max vol/ha of extraction
-- update after change MAX_VOL
MAX_EXT = MAX_VOL / CUT_VOL  -- max trees of extraction
-- equations
DEATH = (1+BIRTH_DEATH[BD_DT].death/100)^YPL - 1
NEW_TREES = (1+BIRTH_DEATH[BD_DT].birth/100)^YPL - 1

-- utils
function min(a,b)
    if a <= b then
        return a
    end
    return b
end

cell = Cell{
    trees_cut = 0,
    trees_reman = 0,
    trees_seeds = 0,
    all_trees = 0,
    died = 0, -- number of trees that died on this cell
    init = function(self)
        self.q_nao_comerc = self.nao_comerc / self:trees_count(1, 9)
        self.q_proib_cort = self.proib_cort / self:trees_count(1, 9)
        self:update_dest()
    end,
    update_dest = function(self)
        -- calc cut trees - illegal trees/unvaluabe trees
        local cut = self:trees_count(DMC, 9)
        local dontcut = self.nao_comerc + self.proib_cort
        local aux = min(dontcut, cut)
        cut = cut - aux
        dontcut = dontcut - aux
        -- calc seed carriers/ remaining trees - illegal/unvaluable
        local seeds = math.ceil(cut * 0.1)
        local reman = self:trees_count(DMC-2, DMC-1)
        aux = min(dontcut, reman)
        reman = reman - aux
        dontcut = dontcut - aux
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
        self.all_trees = self:trees_count()
        self:calc_volume()
    end,
    trees_count = function(self, from, to)
        from = from or 1
        to = to or 9
        local trees = 0
        for i = from, to do
            trees = trees + self["class"..i.."_sum"]
        end
        return math.floor(trees)
    end,
    calc_volume = function(self)
        self.volume = self.trees_cut * CUT_VOL + self.trees_reman * REMAN_VOL + self.trees_seeds * SEEDS_VOL
        return self.volume
    end,
    birth = function(self, new_trees)
        local class = "class"..FIRST_CLASS.."_sum"
        self.nao_comerc = self.nao_comerc + new_trees * self.q_nao_comerc
        self.proib_cort = self.proib_cort + new_trees * self.q_proib_cort
        self[class] = self[class] + new_trees
        self.all_trees = self.all_trees + new_trees
    end,
    growth = function(self)
        for i = 8, 1, -1 do
            local growing_trees
            local class = "class"..i.."_sum"
            growing_trees = self[class] * 0.1 * YPL  * IDA[IDA_DT][i]
            --growing_trees = 10^(growing_trees) / 10
            growing_trees = min(self[class], growing_trees)
            self["class"..(i+1).."_sum"] = self["class"..(i+1).."_sum"] + growing_trees
            self[class] = self[class] - growing_trees
        end
    end,
    death = function(self, total, left, right)
        left  = left or 1
        right = right or 9
        local c = left
        local class
        local died = 0
        -- loop the total youngest trees
        while died < total and c <= right do
            class = "class"..c.."_sum"
            local dead_trees = min(self[class], total-died)
            died = died + dead_trees
            self[class] = self[class] - dead_trees
            c = c + 1
        end
        self.all_trees = self:trees_count()
        self.died = self.died + died
        self.nao_comerc = self.nao_comerc - died * self.q_nao_comerc
        if self.nao_comerc < 0 then
            self.nao_comerc = 0
        end
        self.proib_cort = self.proib_cort - died * self.q_proib_cort
        if self.nao_comerc < 0 then
            self.nao_comerc = 0
        end
        return died
    end,
    extract = function(self, goal)
        local c = DMC
        local class
        local cut = self.trees_cut
        local cutted = 0
        -- extrating trees
        while cutted < cut and c <= 9 and goal * CUT_VOL < MAX_VOL do
            class = "class"..c.."_sum"
            cutted = cutted + self[class]
            goal = goal - self[class]
            self[class] = 0
            c = c + 1
        end
        -- make shure to cut right amount
        if goal < 0 then -- cutted more the goal
            self[class] = -goal
            cutted = cutted - self[class]
            goal = 0
        end
        if cutted > goal then
            self[class] = goal - cutted
            cutted = cutted - self[class]
            goal = 0
        end
        self.all_trees = self.all_trees - cutted
        self.trees_cut = self.trees_cut - cutted
        self.died = self.died + cutted
        return cutted
    end,
    damaging = function(self)
        -- author does not consider class 1 trees
        local damage_trees = (self.all_trees - self.class1_sum) * DAMAGE_EXP
        local trees_count = 0
        local c = 2 -- initial class of data
        while trees_count < damage_trees and c <= 9 do
            local class = "class"..c.."_sum"
            local trees = min(damage_trees - trees_count, self[class])
            trees_count = trees_count + trees
            self[class] = self[class] - trees
            c = c + 1
        end
        self.died = self.died + trees_count
        self.nao_comerc = min(0, self.nao_comerc - trees_count*self.q_nao_comerc)
        self.nao_comerc = min(0, self.proib_cort - trees_count*self.q_proib_cort)
    end,
}

cs = CellularSpace {
    project = proj,
    layer  = "grid",
    missing = 0,
    instance = cell,
    exec_birth = function(self, new_trees)
        birth_t:rebuild()
        while new_trees > 0 do
            forEachCell(birth_t, function(cell)
                    if new_trees == 0 then return end
                    local trees = min(cell.died, new_trees)
                    cell:birth(trees)
                    new_trees = new_trees - trees
                    cell.died = cell.died - trees
                end)
            if new_trees == 0 then return end
            forEachCell(birth_t, function(cell)
                if new_trees == 0 then return end
                forEachNeighbor(cell,function(other)
                    local trees = min(1, new_trees)
                    if new_trees == 0 then return end
                    other:birth(trees)
                    -- decrement dead trees count in cell
                    if other.died >= trees then
                        other.died = other.died - trees
                    elseif other.died > 0 then
                        other.died = 0
                    end
                    new_trees = new_trees - trees
                end)
            end)
        end
    end,
    exec_death = function(self, dead)
        while dead > 0 do
            local cell
            repeat
                cell = cs:sample()
            until cell.all_trees > 0
            local trees = min(1, dead)
             trees = cell:death(trees)
            dead = dead - trees
        end
    end,
    exec_extract = function(self)
            local before = cs:all_trees()
            -- waste
            local ext = cs:trees_cut() * 0.6
            -- max volume
            ext = min(ext, MAX_EXT)
            print("extracted: "..ext)
            table.insert(final_chart.arv_ext, ext)
            table.insert(final_chart.vol_ext, ext * CUT_VOL)
            cs:_exec_extract(ext)
            return ext
    end,
    _exec_extract = function(self, goal)
        extract_t:rebuild()
        forEachCell(extract_t, function(cell)
            if goal == 0 or goal * CUT_VOL > MAX_VOL then return end
            goal = goal - cell:extract(goal)
            cell:damaging()
        end)
    end,
    get_volume = function(self)
        local volume = 0
        forEachCell(self, function(cell)
            volume = volume + cell:calc_volume()
        end)
        return volume
    end
}
MAX_VOL = MAX_VOL * #cs       -- max vol/ha of extraction
MAX_EXT = MAX_VOL / CUT_VOL -- max trees of extraction

cs:createNeighborhood()

birth_t = Trajectory {
    target = cs,
    select = function(self)
        return self.died > 0
    end,
    greater = function(self, other)
        return self.died > other.died
    end
}

extract_t = Trajectory {
    target = cs,
    select = function(self)
        return self.trees_cut > 0
    end,
    greater = function(self, other)
        return self.trees_cut > other.trees_cut
    end
}

all_trees_m = Map{
    target = cs,
    select = "all_trees",
    color = "Greens",
    min = 0,
    max =  60,
    slices = 6,
}

trees_cut_m = Map{
    target = cs,
    select = "trees_cut",
    color = "Reds",
    min = 0,
    max =  25,
    slices = 5,
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
    all_trees = {cs:all_trees()},
    nao_comerc ={cs:nao_comerc()},
    proib_cort = {cs:proib_cort()}
}

cuts = DataFrame{
    before = {},
    cut= {},
    after = {},
    vol_cut = {}
}

t_vol = Cell{
    value = cs:volume(),
    update = function(self, volume)
        self.value = volume or cs:volume()
    end
}

trees_vol = Chart{
    target = t_vol,
    select = "value",
    title = "Volume de árvores ao longo do tempo"
}

function toDF()
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
        all_trees = cs:all_trees(),
        nao_comerc = cs:nao_comerc(),
        proib_cort = cs:proib_cort()
    }
end

function stats()
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
    print("total cut trees:"..cs:trees_cut())
    print("total: "..cs:all_trees())
    print("----------")
end
time = 1
t = Timer{
    Event{start = 1, priority = -5, period=CUT_CICLE//YPL,
        action = function()
            -- extraction function
            stats()
            local trees_ext = cs:exec_extract()
            cuts:add{cut=trees_ext, after=cs:all_trees(), before=before, vol_cut=trees_ext*CUT_VOL}
            stats()
    end},
    Event{action = function()
            -- forest death, birth, growth and update dest
            local all_trees = cs:all_trees()
            local new_trees = all_trees * NEW_TREES
            local dead_trees = all_trees * DEATH
            print(cs:all_trees())
            cs:exec_death(dead_trees)
            cs:exec_birth(new_trees)
            print("-", dead_trees)
            print("+", new_trees)
            print("v", cs:get_volume())
            cs:growth()
            cs:update_dest()
            print("=", cs:all_trees())
    end},
    Event{priority = 5,action = function()
            all_trees_m:update()
            trees_cut_m:update()
            toDF()
            t_vol:update()
            trees_vol:update((time) * YPL)
            time = time + 1
    end}
}
trees_vol:update(0)
trees_cut_m:save("trees_cut.png")
t:run(TIME//YPL)
cs:exec_extract() -- extra time to do the final year
stats()
print("year", "tota volume", "volume per cell")
for i=1,#final_chart.arv_ext do
    local trees_cut = final_chart.arv_ext[i]
    local volume = final_chart.vol_ext[i]
    trees_cut = math.floor(trees_cut)
    print(trees_cut, volume, volume/#cs)
end
print("volule final: "..cs:get_volume())
print("Saving output...")
df:save("dados/output/classes-"..arq_name..".csv")
cs:save("result",{"trees_cut","trees_seeds", "trees_reman"}) -- salvar no lugar certo
cuts:save("dados/output/cuts-"..arq_name..".csv")
all_trees_m:save("all_trees.png")
trees_cut_m:save("trees_cut.png")
trees_vol:save("dados/output/vol_chart-"..arq_name..".png")
print("Output saved")