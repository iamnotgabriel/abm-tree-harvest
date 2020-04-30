import("gis")

proj  = Project {
    file = "project_regen.qgs",
    grid = "dados/borges.shp",
    clean = true,
}

df = DataFrame{
    borges={},
}

cell = Cell{
    init = function(self)
        print(self:trees_count())
        df:add{borges=self:trees_count()}
    end,
    trees_count = function(self)
        local trees = 0
        for i = 1,9 do
            trees = trees + self["class"..i.."_sum"]
        end
        return trees
    end,
}

cs = CellularSpace {
    project = proj,
    layer  = "grid",
    missing = 0,
    instance = cell,
}

df:save("borges.csv")



