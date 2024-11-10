util.require_natives(1676318796)

Print = util.toast
Wait = util.yield
joaat = util.joaat

json = require "json"

local MaxLoopCount = 1000

local GlobalRaycastFlags = 83

local FlagBitNames = {
	Jump = 1,
	UsePoint = 2,
	JumpTo = 3
}

local FlagsBits = 0

local GridStartType = 0

function LoadJSONFile(Path)
    local MyTable = {}
    local File = io.open( Path, "r" )

    if File then
        -- read all contents of file into a string
        local Contents = File:read( "*a" )
        MyTable = json.decode(Contents)
        io.close( File )
        return MyTable
    end
    return nil
end

local Polys1 = {}
local VehNavIDs = {}
local PlatformIDs = {}
local Grid = {}
local Polys1Center = {}

local GridSizeIteration = 10
local GlobalCellSize = 5.0
local GlobalInfluenceRadius = 2.0
local GlobalGridAreaX = 100.0
local GlobalGridAreaY = 100.0

function LoadNavmesh(File, TableTarget, LoadAll)
	local T = Polys1
	if TableTarget ~= nil then
		T = TableTarget
	end
	local IDs = {}
	local Contents = LoadJSONFile(filesystem.scripts_dir().."\\navs\\"..File)
	if Contents ~= nil then
		local ContentsIT = 0
		for k = 1, #Contents do
			local Vertexes = {}
			local IsNil = true
			for i = 1, 10 do
				local Key = "Poly"..i
				if Contents[k][Key] ~= nil then
					Vertexes[#Vertexes+1] = Contents[k][Key]
					IsNil = false
				end
			end
			if Contents[k].vertices ~= nil then
				for j = 1, 3 do
					Vertexes[#Vertexes+1] = Contents[k].vertices[j]
				end
			end
			T[#T+1] = {}
			if IsNil then
				for i = 1, #Vertexes do
					local Key = "Poly"..i
					T[#T][#T[#T]+1] = {x = Vertexes[i][1], y = Vertexes[i][2], z = Vertexes[i][3]}
				end
			else
				for i = 1, #Vertexes do
					local Key = "Poly"..i
					T[#T][#T[#T]+1] = {x = Contents[k][Key].x, y = Contents[k][Key].y, z = Contents[k][Key].z}
				end
			end
			T[#T].LinkedIDs = Contents[k].LinkedIDs
			T[#T].Flags = Contents[k].Flags
			T[#T].Point = Contents[k].Point
			T[#T].JumpTo = Contents[k].JumpTo or nil
			T[#T].JumpedFrom = Contents[k].JumpedFrom or nil
			if LoadAll then
				T[#T].Neighboors = Contents[k].Neighboors
				T[#T].Center = Contents[k].Center
				T[#T].ID = #T
				if T[#T].LinkedIDs ~= nil then
					for k = 1, #T[#T].LinkedIDs do
						T[#T].Neighboors[#T[#T].Neighboors+1] = T[#T].LinkedIDs[k]
					end
				end
			end
			ContentsIT = ContentsIT + 1
			if ContentsIT > 10 then
				ContentsIT = 0
				Wait()
			end
			IDs[#IDs+1] = #T
			Print("Loading Navs")
		end
		Print("Loaded. Total Polygons is "..#T)

		SetAllPolysNeighboors(nil, T, LoadAll)
	end
	return IDs
end
util.create_thread(function()
	PlatformIDs = LoadNavmesh("LastNav.json", nil, true)
end)

function GetPolygonCenter(polygon)
	local Center = calcularCentroidePoligono3D(polygon)
    return Center
end

function SetAllPolysNeighboors(EditIndex, TableTarget, IgnoreCalculations)
	local T = Polys1
	if TableTarget ~= nil then
		T = TableTarget
	end
	local Start = 1
	local End = #T
	local It = 0
	local ItMax = 20
	if EditIndex ~= nil then
		Start = EditIndex
		End = EditIndex
	end
	local UsePointCalc = false
	if not IgnoreCalculations then
		for i = Start, End do
			T[i].Center = GetPolygonCenter(T[i])
			T[i].Neighboors = {}
			T[i].Edges = {}
			local index = #T[i]
			for k = 1, #T[i] do
				local Sub = {
					x = T[i][k].x - ((T[i][k].x - T[i][index].x) / 2),
					y = T[i][k].y - ((T[i][k].y - T[i][index].y) / 2),
					z = T[i][k].z - ((T[i][k].z - T[i][index].z) / 2)
				}
				T[i].Edges[#T[i].Edges+1] = Sub
				index = k
			end
			T[i].ID = i
			T[i].Closed = false
			T[i].Parent = i
			T[i].LocalPoints = {}
			if UsePointCalc then
				for k = 1, 19 do --Old is 9
					local Div = 0.0 + 0.05 * k
					local NewSub = {
						x = T[i][1].x - ((T[i][1].x - T[i][3].x) * Div),
						y = T[i][1].y - ((T[i][1].y - T[i][3].y) * Div),
						z = T[i][1].z - ((T[i][1].z - T[i][3].z) * Div)}
					local NewSub2 = {
						x = T[i][2].x - ((T[i][2].x - T[i][3].x) * Div),
						y = T[i][2].y - ((T[i][2].y - T[i][3].y) * Div),
						z = T[i][2].z - ((T[i][2].z - T[i][3].z) * Div)}
					local NewSub3 = {
						x = T[i][1].x - ((T[i][1].x - T[i][2].x) * Div),
						y = T[i][1].y - ((T[i][1].y - T[i][2].y) * Div),
						z = T[i][1].z - ((T[i][1].z - T[i][2].z) * Div)
					}
					T[i].LocalPoints[#T[i].LocalPoints+1] = NewSub
					T[i].LocalPoints[#T[i].LocalPoints+1] = NewSub2
					T[i].LocalPoints[#T[i].LocalPoints+1] = NewSub3
				end
			end
			if T[i].JumpTo == nil then
				T[i].JumpTo = {}
			end
			if T[i].JumpedFrom == nil then
				T[i].JumpedFrom = {}
			end
			if T[i].LinkedIDs ~= nil then
				for k = 1, #T[i].LinkedIDs do
					local CanInsert = true
					for j = 1, #T[i].Neighboors do
						if T[i].LinkedIDs[k] == T[i].Neighboors[j] then
							CanInsert = false
							break
						end
					end
					if CanInsert then
						T[i].Neighboors[#T[i].Neighboors+1] = T[i].LinkedIDs[k]
					end
				end
			else
				T[i].LinkedIDs = {}
			end
			if T[i].Flags == nil then
				T[i].Flags = 0
			end
			Print("Calculating")
			It = It + 1
			--T[i].BoundingBox = calcularBoundingBoxPoligono(T[i])
			--if It > ItMax then
			--	It = 0
			--	Wait()
			--end
		end
		local UseNewNeighborCalc = 1
		if UseNewNeighborCalc == 0 then
			ItMax = 150000
			local It2 = 0
			local It3 = 0
			local It4 = 0
			local It5 = 0
			for i = 1, #T do
				for k = 1, #T do
					if k ~= i then
						for j = 1, #T[i].Edges do
							for a = 1, #T[k].Edges do
								if T[i].Edges[j].x == T[k].Edges[a].x and
								T[i].Edges[j].y == T[k].Edges[a].y and
								T[i].Edges[j].z == T[k].Edges[a].z then
								--if polygons_are_neighbors(Polys1[i], Polys1[k]) then
									T[i].Neighboors[#T[i].Neighboors+1] = k
								end
								
								Print("Calculating neighbors")
								It2 = It2 + 1
								if It2 > ItMax then
									It2 = 0
									--Print(ItMax)
									Wait()
								end
							end
							Print("Calculating neighbors")
							It3 = It3 + 1
							if It3 > ItMax then
								It3 = 0
								Wait()
							end
						end
					end
					Print("Calculating neighbors")
					It4 = It4 + 1
					if It4 > ItMax then
						It4 = 0
						Wait()
					end
				end
				Print("Calculating neighbors")
				It5 = It5 + 1
				if It5 > ItMax then
					It5 = 0
					Wait()
				end
				--Wait()
			end
		elseif UseNewNeighborCalc == 1 then
			conectarVizinhosComRaycast(T, 0.1)
		elseif UseNewNeighborCalc == 2 then
			-- Construir a kd-tree a partir dos polígonos
			local PolygonsNewIDs = {}
			for k = 1, #T do
				PolygonsNewIDs[#PolygonsNewIDs+1] = {T[k].Center.x, T[k].Center.y, T[k].Center.z}
			end
			local kdTree = construirKdTree(PolygonsNewIDs)

			-- Calcular os vizinhos para cada polígono
			local k = 5 -- Número de vizinhos mais próximos que queremos encontrar
			local vizinhosPorPoligono = calcularVizinhosParaPoligonosComDistanciaMaxima(T, kdTree, k, 5.0, 1.0)
			--calcularVizinhosParaPoligonosComVerticesSemRaycast(T, kdTree, k, 100.0, 1.0)
			--calcularVizinhosParaPoligonosComVerticesERaycast(T, kdTree, k, 1.0)
			--calcularVizinhosParaTodosOsPoligonos(PolygonsNewIDs, kdTree, k)
			--Print(#vizinhosPorPoligono)
			for k = 1, #vizinhosPorPoligono do
				T[k].Neighboors = vizinhosPorPoligono[k]
			end
		end
	end
	Grid = {}
	if GridStartType == 0 then
		local IDs = {}
		for k = 1, #T do
			IDs[#IDs+1] = T[k].ID
		end
		Polys1Center = calcularCentroNavmeshComIndices(T, IDs)
		Grid = inicializarGridEstatico(Polys1Center.x, Polys1Center.y, GlobalCellSize)
		--inicializarGridEstatico(GlobalGridAreaX, GlobalGridAreaY, GlobalCellSize)
		armazenarPoligonosNoGridEstatico(Grid, T, GlobalCellSize, GlobalInfluenceRadius * GlobalCellSize)
	elseif GridStartType == 1 then
		armazenarPoligonosNoGrid(T, GridSizeIteration)
	end
	

	--armazenarPoligonosNoGrid(T, GridSizeIteration)
	--armazenarPoligonosNoGridComOrigem(Grid, Polys1, 5.0, Center.x, Center.y, Center.z, 10.0)
	
	Print("Calculation done.")
end

function SetPolyEdges(PolyID)
	Polys1[PolyID].Edges = {}
	local index = #Polys1[PolyID]
	for k = 1, #Polys1[PolyID] do
		local Sub = {
			x = Polys1[PolyID][k].x - ((Polys1[PolyID][k].x - Polys1[PolyID][index].x) / 2),
			y = Polys1[PolyID][k].y - ((Polys1[PolyID][k].y - Polys1[PolyID][index].y) / 2),
			z = Polys1[PolyID][k].z - ((Polys1[PolyID][k].z - Polys1[PolyID][index].z) / 2)
		}
		Polys1[PolyID].Edges[#Polys1[PolyID].Edges+1] = Sub
		index = k
	end
end

--SetAllPolysNeighboors()
local NavmeshingMenu = menu.list(menu.my_root(), "Navmeshing", {}, "")
--local VehicleWaypointsMenu = menu.list(menu.my_root(), "Vehicle Waypoints", {}, "")
local DrawFunctionsMenu = menu.list(NavmeshingMenu, "Draw Functions", {}, "To see where polygons are.")

local ShowNavPoints = false
menu.toggle(DrawFunctionsMenu, "Draw Polys", {}, "", function(Toggle)
	ShowNavPoints = Toggle
	if ShowNavPoints then
		local LoopCount = 0
		while ShowNavPoints do
			GRAPHICS.SET_BACKFACECULLING(false)
			local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			for i = 1, #Polys1 do
				if Polys1[i] ~= nil then
					local R, G, B = 255, 255, 255
					--if InsidePolygon2(Polys1[i], Pos, "z", "x") and InsidePolygon2(Polys1[i], Pos, "y", "z") then
					--if InsidePolygon(Polys1[i], Pos) then
					--if Inside3DPolygon(Polys1[i], Pos) then
					--if GetPolygonDirectIndex(Pos) == i then
					if Inside3DPolygon2(Polys1[i], Pos) then
						R = 0
						G = 0
						Print("Index is "..i)
					
					end
					if Polys1[i].LinkedIDs ~= nil then
						for k = 1, #Polys1[i].LinkedIDs do
							if Polys1[Polys1[i].LinkedIDs[k]] ~= nil then
								GRAPHICS.DRAW_LINE(Polys1[i].Center.x, Polys1[i].Center.y, Polys1[i].Center.z,
								Polys1[Polys1[i].LinkedIDs[k]].Center.x, Polys1[Polys1[i].LinkedIDs[k]].Center.y, Polys1[Polys1[i].LinkedIDs[k]].Center.z, 255, 255, 255, 150)
							end
						end
					end
					if Polys1[i].JumpTo ~= nil then
						for k = 1, #Polys1[i].JumpTo do
							GRAPHICS.DRAW_LINE(Polys1[i].Center.x, Polys1[i].Center.y, Polys1[i].Center.z + 1.0,
							Polys1[Polys1[i].JumpTo[k]].Center.x, Polys1[Polys1[i].JumpTo[k]].Center.y, Polys1[Polys1[i].JumpTo[k]].Center.z + 1.0, 255, 0, 0, 150)
						end
					end
					if Polys1[i].Flags ~= nil then
						if is_bit_set(Polys1[i].Flags, FlagBitNames.Jump) then
							R = 100
							G = 100
						end
					end
					--Print(Polys[i].Neighboors[1])
					GRAPHICS.DRAW_POLY(Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z,
						Polys1[i][2].x, Polys1[i][2].y, Polys1[i][2].z,
						Polys1[i][3].x, Polys1[i][3].y, Polys1[i][3].z,
						R, G, B, 100)
					if Polys1[i][4] ~= nil then
						GRAPHICS.DRAW_POLY(Polys1[i][4].x, Polys1[i][4].y, Polys1[i][4].z,
						Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z,
						Polys1[i][3].x, Polys1[i][3].y, Polys1[i][3].z,
						R, G, B, 100)
					end
					for k = 1, #Polys1[i] do
						if k == #Polys1[i] then
							GRAPHICS.DRAW_LINE(Polys1[i][k].x, Polys1[i][k].y, Polys1[i][k].z,
							Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z, R, G, B, 150)
						else
							GRAPHICS.DRAW_LINE(Polys1[i][k].x, Polys1[i][k].y, Polys1[i][k].z,
							Polys1[i][k+1].x, Polys1[i][k+1].y, Polys1[i][k+1].z, R, G, B, 150)
						end
						--GRAPHICS.DRAW_MARKER(28, Polys1[i][k].x,
						--Polys1[i][k].y, Polys1[i][k].z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 150, 0, 0, 100, 0, false, 2, false, 0, 0, false)
					end
					if Polys1[i].Point ~= nil then
						GRAPHICS.DRAW_MARKER(28, Polys1[i].Point.x,
						Polys1[i].Point.y, Polys1[i].Point.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 150, 0, 0, 100, 0, false, 2, false, 0, 0, false)
					end
					--GRAPHICS.DRAW_MARKER(28, Polys1[i].Center.x,
					--Polys1[i].Center.y, Polys1[i].Center.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 150, 0, 0, 100, 0, false, 2, false, 0, 0, false)
				end
				LoopCount = LoopCount + 1
				if LoopCount > 9000 then
					LoopCount = 0
					Wait()
				end
			end
			Wait()
		end
		GRAPHICS.SET_BACKFACECULLING(true)
	end
end)

local ShowNavPoints2 = false
menu.toggle(DrawFunctionsMenu, "Draw Polys Neighboors", {}, "", function(Toggle)
	ShowNavPoints2 = Toggle
	if ShowNavPoints2 then
		while ShowNavPoints2 do
			GRAPHICS.SET_BACKFACECULLING(false)
			local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			for i = 1, #Polys1 do
				local R, G, B = 0, 255, 255
				if Inside3DPolygon2(Polys1[i], Pos) then
					GRAPHICS.DRAW_POLY(Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z,
					Polys1[i][2].x, Polys1[i][2].y, Polys1[i][2].z,
					Polys1[i][3].x, Polys1[i][3].y, Polys1[i][3].z,
					R, G, B, 100)
					for k = 1, #Polys1[i] do
						if k == #Polys1[i] then
							GRAPHICS.DRAW_LINE(Polys1[i][k].x, Polys1[i][k].y, Polys1[i][k].z,
							Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z, R, G, B, 150)
						else
							GRAPHICS.DRAW_LINE(Polys1[i][k].x, Polys1[i][k].y, Polys1[i][k].z,
							Polys1[i][k+1].x, Polys1[i][k+1].y, Polys1[i][k+1].z, R, G, B, 150)
						end
					end
					if Polys1[i][4] ~= nil then
						GRAPHICS.DRAW_POLY(Polys1[i][4].x, Polys1[i][4].y, Polys1[i][4].z,
						Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z,
						Polys1[i][3].x, Polys1[i][3].y, Polys1[i][3].z,
						R, G, B, 100)
					end
					for k = 1, #Polys1[i].Neighboors do
						GRAPHICS.DRAW_POLY(Polys1[Polys1[i].Neighboors[k]][1].x, Polys1[Polys1[i].Neighboors[k]][1].y, Polys1[Polys1[i].Neighboors[k]][1].z,
						Polys1[Polys1[i].Neighboors[k]][2].x, Polys1[Polys1[i].Neighboors[k]][2].y, Polys1[Polys1[i].Neighboors[k]][2].z,
						Polys1[Polys1[i].Neighboors[k]][3].x, Polys1[Polys1[i].Neighboors[k]][3].y, Polys1[Polys1[i].Neighboors[k]][3].z,
						R, G, B, 100)
						if Polys1[Polys1[i].Neighboors[k]][4] ~= nil then
							GRAPHICS.DRAW_POLY(Polys1[Polys1[i].Neighboors[k]][4].x, Polys1[Polys1[i].Neighboors[k]][4].y, Polys1[Polys1[i].Neighboors[k]][4].z,
							Polys1[Polys1[i].Neighboors[k]][1].x, Polys1[Polys1[i].Neighboors[k]][1].y, Polys1[Polys1[i].Neighboors[k]][1].z,
							Polys1[Polys1[i].Neighboors[k]][3].x, Polys1[Polys1[i].Neighboors[k]][3].y, Polys1[Polys1[i].Neighboors[k]][3].z,
							R, G, B, 100)
						end
						for j = 1, #Polys1[i] do
							if j == #Polys1[i] then
								GRAPHICS.DRAW_LINE(Polys1[Polys1[i].Neighboors[k]][j].x,Polys1[Polys1[i].Neighboors[k]][j].y, Polys1[Polys1[i].Neighboors[k]][j].z,
								Polys1[Polys1[i].Neighboors[k]][1].x, Polys1[Polys1[i].Neighboors[k]][1].y, Polys1[Polys1[i].Neighboors[k]][1].z, R, G, B, 150)
							else
								GRAPHICS.DRAW_LINE(Polys1[Polys1[i].Neighboors[k]][j].x,Polys1[Polys1[i].Neighboors[k]][j].y, Polys1[Polys1[i].Neighboors[k]][j].z,
								Polys1[Polys1[i].Neighboors[k]][j+1].x,Polys1[Polys1[i].Neighboors[k]][j+1].y, Polys1[Polys1[i].Neighboors[k]][j+1].z, R, G, B, 150)
							end
						end
						
					end
				end
			end
			Wait()
		end
		GRAPHICS.SET_BACKFACECULLING(true)
	end
end)

local DrawPolysNeighbors = false
menu.toggle(DrawFunctionsMenu, "Draw Polys Neighbors Extended", {}, "", function(Toggle)
	DrawPolysNeighbors = Toggle
	if DrawPolysNeighbors then
		while DrawPolysNeighbors do
			local Indexes = {}
			GRAPHICS.SET_BACKFACECULLING(false)
			local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			for i = 1, #Polys1 do
				local R, G, B = 0, 255, 255
				if Inside3DPolygon2(Polys1[i], Pos) then
					Indexes[#Indexes+1] = i
					for k = 1, #Polys1[i].Neighboors do
						local CanInsert = true
						for j = 1, #Indexes do
							if Polys1[i].Neighboors[k] == Indexes[j] then
								CanInsert = false
								break
							end
						end
						if CanInsert then
							Indexes[#Indexes+1] = Polys1[i].Neighboors[k]
						end
					end
					--if #Indexes < 20 then
						for r = 1, 10 do
							--if #Indexes < 20 then
								for k = 1, #Indexes do
									for j = 1, #Polys1[Indexes[k]].Neighboors do
										local CanInsert = true
										for a = 1, #Indexes do
											if Polys1[Indexes[k]].Neighboors[j] == Indexes[a] then
												CanInsert = false
												break
											end
										end
										if CanInsert then
											Indexes[#Indexes+1] = Polys1[Indexes[k]].Neighboors[j]
										end
									end
								end
							--else
								--break
							--end
						end
					--end
				end
			end
			for i = 1, #Indexes do
				GRAPHICS.DRAW_POLY(Polys1[Indexes[i]][1].x, Polys1[Indexes[i]][1].y, Polys1[Indexes[i]][1].z,
				Polys1[Indexes[i]][2].x, Polys1[Indexes[i]][2].y, Polys1[Indexes[i]][2].z,
				Polys1[Indexes[i]][3].x, Polys1[Indexes[i]][3].y, Polys1[Indexes[i]][3].z,
				R, G, B, 100)
				GRAPHICS.DRAW_LINE(Polys1[Indexes[i]][1].x, Polys1[Indexes[i]][1].y, Polys1[Indexes[i]][1].z,
				Polys1[Indexes[i]][2].x, Polys1[Indexes[i]][2].y, Polys1[Indexes[i]][2].z, 255, 0, 0, 150)
				GRAPHICS.DRAW_LINE(Polys1[Indexes[i]][2].x, Polys1[Indexes[i]][2].y, Polys1[Indexes[i]][2].z,
				Polys1[Indexes[i]][3].x, Polys1[Indexes[i]][3].y, Polys1[Indexes[i]][3].z, 0, 255, 0, 150)
				GRAPHICS.DRAW_LINE(Polys1[Indexes[i]][3].x, Polys1[Indexes[i]][3].y, Polys1[Indexes[i]][3].z,
				Polys1[Indexes[i]][1].x, Polys1[Indexes[i]][1].y, Polys1[Indexes[i]][1].z, 0, 0, 255, 150)
			end
			Print(#Indexes)
			Wait()
		end
		GRAPHICS.SET_BACKFACECULLING(true)
	end
end)

local ShowNavPoints3 = false
menu.toggle(DrawFunctionsMenu, "Draw Polys Edge Center", {}, "", function(Toggle)
	ShowNavPoints3 = Toggle
	if ShowNavPoints3 then
		while ShowNavPoints3 do
			GRAPHICS.SET_BACKFACECULLING(false)
			local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			for i = 1, #Polys1 do
				local R, G, B = 0, 255, 255
				if Inside3DPolygon2(Polys1[i], Pos) then
					GRAPHICS.DRAW_POLY(Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z,
					Polys1[i][2].x, Polys1[i][2].y, Polys1[i][2].z,
					Polys1[i][3].x, Polys1[i][3].y, Polys1[i][3].z,
					R, G, B, 10)
					GRAPHICS.DRAW_LINE(Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z,
					Polys1[i][2].x, Polys1[i][2].y, Polys1[i][2].z, 255, 0, 0, 150)
					GRAPHICS.DRAW_LINE(Polys1[i][2].x, Polys1[i][2].y, Polys1[i][2].z,
					Polys1[i][3].x, Polys1[i][3].y, Polys1[i][3].z, 0, 255, 0, 150)
					GRAPHICS.DRAW_LINE(Polys1[i][3].x, Polys1[i][3].y, Polys1[i][3].z,
					Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z, 0, 0, 255, 150)
					
					for k = 1, #Polys1[i].Edges do
						local Sub = Polys1[i].Edges[k]
						GRAPHICS.DRAW_MARKER(28, Sub.x,
						Sub.y, Sub.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 150, 0, 0, 100, 0, false, 2, false, 0, 0, false)
					end
					
				end
			end
			Wait()
		end
		GRAPHICS.SET_BACKFACECULLING(true)
	end
end)

local ShowPoints = false
menu.toggle(DrawFunctionsMenu, "Draw Polys Points", {}, "", function(Toggle)
	ShowPoints = Toggle
	if ShowPoints then
		while ShowPoints do
			GRAPHICS.SET_BACKFACECULLING(false)
			local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			for i = 1, #Polys1 do
				local R, G, B = 0, 255, 255
				if Inside3DPolygon2(Polys1[i], Pos) then
					GRAPHICS.DRAW_POLY(Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z,
					Polys1[i][2].x, Polys1[i][2].y, Polys1[i][2].z,
					Polys1[i][3].x, Polys1[i][3].y, Polys1[i][3].z,
					R, G, B, 10)
					GRAPHICS.DRAW_LINE(Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z,
					Polys1[i][2].x, Polys1[i][2].y, Polys1[i][2].z, 255, 0, 0, 150)
					GRAPHICS.DRAW_LINE(Polys1[i][2].x, Polys1[i][2].y, Polys1[i][2].z,
					Polys1[i][3].x, Polys1[i][3].y, Polys1[i][3].z, 0, 255, 0, 150)
					GRAPHICS.DRAW_LINE(Polys1[i][3].x, Polys1[i][3].y, Polys1[i][3].z,
					Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z, 0, 0, 255, 150)
					for k = 1, #Polys1[i].LocalPoints do
						--GRAPHICS.DRAW_MARKER(28, Polys1[i].LocalPoints[k].x,
						--Polys1[i].LocalPoints[k].y, Polys1[i].LocalPoints[k].z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.1, 0.1, 150, 150, 150, 100, 0, false, 2, false, 0, 0, false)
						GRAPHICS.DRAW_LINE(Polys1[i].LocalPoints[k].x,
						Polys1[i].LocalPoints[k].y, Polys1[i].LocalPoints[k].z,
						Pos.x, Pos.y, Pos.z, 255, 0, 0, 150)
					end
					
				end
			end
			Wait()
		end
		GRAPHICS.SET_BACKFACECULLING(true)
	end
end)

local DrawGrid = false
menu.toggle(DrawFunctionsMenu, "Draw Grid", {}, "", function(Toggle)
	DrawGrid = Toggle
	if DrawGrid then
		while DrawGrid do
			local PlayerPed = PLAYER.PLAYER_PED_ID()
			local LinesT = {}
			for i = -1, 1 do
				local DrawsT = {}
				for k = 2, 5 do
					local Pos = GetOffsetFromEntityInWorldCoords(PlayerPed, -0.5 + 1.0 * i, 0.5 + 1.0 * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 255, 0, 0}
					local Pos = GetOffsetFromEntityInWorldCoords(PlayerPed, -0.5 + 1.0 * i, -0.5 + 1.0 * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 255, 0}
					local Pos = GetOffsetFromEntityInWorldCoords(PlayerPed, 0.5 + 1.0 * i, -0.5 + 1.0 * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 0, 255}
					local Pos = GetOffsetFromEntityInWorldCoords(PlayerPed, 0.5 + 1.0 * i, 0.5 + 1.0 * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 255, 255, 0}
					local Pos = GetOffsetFromEntityInWorldCoords(PlayerPed, -0.5 + 1.0 * i, 0.5 + 1.0 * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 255, 255}
				end
				LinesT[#LinesT+1] = DrawsT
			end
			for i = 1, #LinesT do
				for k = 1, #LinesT[i]-1 do
					GRAPHICS.DRAW_LINE(LinesT[i][k][1].x, LinesT[i][k][1].y, LinesT[i][k][1].z,
					LinesT[i][k+1][1].x, LinesT[i][k+1][1].y, LinesT[i][k+1][1].z, LinesT[i][k+1][2], LinesT[i][k+1][3], LinesT[i][k+1][4], 150)
				end
			end
			Wait()
		end
	end
end)

local DrawPolyGrid = false
menu.toggle(DrawFunctionsMenu, "Draw Poly Grid", {}, "", function(Toggle)
	DrawPolyGrid = Toggle
	if DrawPolyGrid then
		while DrawPolyGrid do
			GRAPHICS.SET_BACKFACECULLING(false)
			local PlayerPed = PLAYER.PLAYER_PED_ID()
			local LinesT = {}
			for i = -1, 1 do
				local DrawsT = {}
				for k = 2, 5 do
					local Pos = GetOffsetFromEntityInWorldCoords(PlayerPed, -0.5 + 1.0 * i, 0.5 + 1.0 * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 255, 0, 0}
					local Pos = GetOffsetFromEntityInWorldCoords(PlayerPed, -0.5 + 1.0 * i, -0.5 + 1.0 * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 255, 0}
					local Pos = GetOffsetFromEntityInWorldCoords(PlayerPed, 0.5 + 1.0 * i, -0.5 + 1.0 * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 0, 255}
					local Pos = GetOffsetFromEntityInWorldCoords(PlayerPed, 0.5 + 1.0 * i, 0.5 + 1.0 * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 255, 255, 0}
					local Pos = GetOffsetFromEntityInWorldCoords(PlayerPed, -0.5 + 1.0 * i, 0.5 + 1.0 * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 255, 255}
				end
				LinesT[#LinesT+1] = DrawsT
			end
			for i = 1, #LinesT do
				local kIt = 1
				while kIt <= #LinesT[i]-4 do
					GRAPHICS.DRAW_POLY(LinesT[i][kIt][1].x, LinesT[i][kIt][1].y, LinesT[i][kIt][1].z,
					LinesT[i][kIt+1][1].x, LinesT[i][kIt+1][1].y, LinesT[i][kIt+1][1].z,
					LinesT[i][kIt+2][1].x, LinesT[i][kIt+2][1].y, LinesT[i][kIt+2][1].z,
					LinesT[i][kIt+3][2], LinesT[i][kIt+3][3], LinesT[i][kIt+3][4], 100)
					GRAPHICS.DRAW_POLY(LinesT[i][kIt+3][1].x, LinesT[i][kIt+3][1].y, LinesT[i][kIt+3][1].z,
					LinesT[i][kIt+4][1].x, LinesT[i][kIt+4][1].y, LinesT[i][kIt+4][1].z,
					LinesT[i][kIt+2][1].x, LinesT[i][kIt+2][1].y, LinesT[i][kIt+2][1].z,
					LinesT[i][kIt+3][2], LinesT[i][kIt+3][3], LinesT[i][kIt+3][4], 100)
					kIt = kIt + 5
				end
			end
			Wait()
		end
	else
		GRAPHICS.SET_BACKFACECULLING(true)
	end
end)

menu.action(menu.my_root(), "Copy Coords", {}, "", function(Toggle)
	local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	util.copy_to_clipboard("x = "..Pos.x..", y = "..Pos.y..", z = "..Pos.z)
end)

local AddPolysMenu = menu.list(NavmeshingMenu, "Add Polygons Tools", {}, "Start building here.")
local PolyFlagsMenu = menu.list(AddPolysMenu, "Flags", {}, "Attach navigation behaviour to polygons.")

local JumpToNode = false
menu.toggle(PolyFlagsMenu, "Jump", {}, "", function(Toggle)
	JumpToNode = Toggle
	if JumpToNode then
		if not is_bit_set(FlagsBits, FlagBitNames.Jump) then
			FlagsBits = set_bit(FlagsBits, FlagBitNames.Jump)
		end
	else
		if is_bit_set(FlagsBits, FlagBitNames.Jump) then
			FlagsBits = clear_bit(FlagsBits, FlagBitNames.Jump)
		end
	end
end)

local NodeUsesPoint = false
menu.toggle(PolyFlagsMenu, "Use Point", {}, "", function(Toggle)
	NodeUsesPoint = Toggle
	if NodeUsesPoint then
		if not is_bit_set(FlagsBits, FlagBitNames.UsePoint) then
			FlagsBits = set_bit(FlagsBits, FlagBitNames.UsePoint)
		end
	else
		if is_bit_set(FlagsBits, FlagBitNames.UsePoint) then
			FlagsBits = clear_bit(FlagsBits, FlagBitNames.UsePoint)
		end
	end
end)

local JumpToNode2 = false
menu.toggle(PolyFlagsMenu, "Jump To", {}, "", function(Toggle)
	JumpToNode2 = Toggle
	if JumpToNode2 then
		if not is_bit_set(FlagsBits, FlagBitNames.JumpTo) then
			FlagsBits = set_bit(FlagsBits, FlagBitNames.JumpTo)
		end
	else
		if is_bit_set(FlagsBits, FlagBitNames.JumpTo) then
			FlagsBits = clear_bit(FlagsBits, FlagBitNames.JumpTo)
		end
	end
end)

menu.action(PolyFlagsMenu, "Apply Flag To Selected Poly", {}, "", function(Toggle)
	local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	if #Polys1 > 0 then
		local PolyIdx = 0
		for k = 1, #Polys1 do
			if Inside3DPolygon2(Polys1[k], PlayerPos) then
				PolyIdx = k
				break
			end
		end
		if PolyIdx ~= 0 then
			Polys1[PolyIdx].Flags = FlagsBits
			Print("Applied flag bits "..FlagsBits.." to polygon index "..PolyIdx..".")
		end
	end
end)

local LinkJumpState = 0
local LinkJumpID2 = 0
local ToLinkJumpID2 = 0
menu.action(AddPolysMenu, "Apply Jump To Polygon", {}, "Select the first polygon, and press again to apply the jump to the other selected polygon.", function(Toggle)
	local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	local PolyIdx = 0
	if LinkJumpState == 0 then
		for k = 1, #Polys1 do
			if Inside3DPolygon2(Polys1[k], PlayerPos) then
				PolyIdx = k
				break
			end
		end
		if PolyIdx ~= 0 then
			LinkJumpState = 1
			LinkJumpID2 = PolyIdx
			Print("Index is "..LinkJumpID2.." and now waiting for user input the next ID.")
		end
	end
	if LinkJumpState == 1 then
		for k = 1, #Polys1 do
			if Inside3DPolygon2(Polys1[k], PlayerPos) then
				PolyIdx = k
				break
			end
		end
		if PolyIdx ~= 0 then
			if PolyIdx ~= LinkJumpID2 then
				ToLinkJumpID2 = PolyIdx
				local CanInsertToID = true
				if Polys1[LinkJumpID2].JumpTo ~= nil then
					for k = 1, #Polys1[LinkJumpID2].JumpTo do
						if Polys1[LinkJumpID2].JumpTo[k] == ToLinkJumpID2 then
							CanInsertToID = false
							break
						end
					end
				end
				if CanInsertToID then
					if Polys1[LinkJumpID2].JumpTo == nil then
						Polys1[LinkJumpID2].JumpTo = {}
					end
					Polys1[LinkJumpID2].JumpTo[#Polys1[LinkJumpID2].JumpTo+1] = ToLinkJumpID2
					Print("Index ".. LinkJumpID2.." and index "..ToLinkJumpID2.." are jump to set.")
					CanInsertToID = true
					if Polys1[ToLinkJumpID2].JumpedFrom ~= nil then
						for k = 1, #Polys1[ToLinkJumpID2].JumpedFrom do
							if Polys1[ToLinkJumpID2].JumpedFrom[k] == LinkJumpID2 then
								CanInsertToID = false
								break
							end
						end
					end
					if CanInsertToID then
						Polys1[ToLinkJumpID2].JumpedFrom[#Polys1[ToLinkJumpID2].JumpedFrom+1] = LinkJumpID2
					end
				end
				ToLinkJumpID2 = 0
				LinkJumpID2 = 0
				LinkJumpState = 0
			end
		end
	end
end)

local ShowLinesStarted = false
local Vertexes_1 = {}

local PolyVertexCreator = false
menu.toggle(AddPolysMenu, "Poly Vertex Creator Raycast", {}, "", function(Toggle)
	PolyVertexCreator = Toggle
	if PolyVertexCreator then
		local IsMovingVertexes = false
		while PolyVertexCreator do
			local ReleasedMove = PAD.IS_CONTROL_JUST_RELEASED(0, 25)
			local ReleasedPlace = PAD.IS_CONTROL_JUST_RELEASED(0, 24)
			local ReleasedApply = PAD.IS_CONTROL_JUST_RELEASED(0, 22)
			local OutPos = RaycastFromCamera(PLAYER.PLAYER_PED_ID(), 1000.0, -1)
			OutPos.z = OutPos.z + 1.0
			GRAPHICS.DRAW_MARKER(28, OutPos.x,
			OutPos.y, OutPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 0, 150, 0, 100, 0, false, 2, false, 0, 0, false)
			for i = 1, #Polys1 do
				local R, G, B = 255, 255, 255
				if Inside3DPolygon2(Polys1[i], OutPos) then
					R = 0
					G = 0
					Print("Index is "..i)
				end
				if Polys1[i].LinkedIDs ~= nil then
					for k = 1, #Polys1[i].LinkedIDs do
						if Polys1[Polys1[i].LinkedIDs[k]] ~= nil then
							GRAPHICS.DRAW_LINE(Polys1[i].Center.x, Polys1[i].Center.y, Polys1[i].Center.z,
							Polys1[Polys1[i].LinkedIDs[k]].Center.x, Polys1[Polys1[i].LinkedIDs[k]].Center.y, Polys1[Polys1[i].LinkedIDs[k]].Center.z, 255, 255, 255, 150)
						end
					end
				end
				if Polys1[i].JumpTo ~= nil then
					for k = 1, #Polys1[i].JumpTo do
						GRAPHICS.DRAW_LINE(Polys1[i].Center.x, Polys1[i].Center.y, Polys1[i].Center.z + 1.0,
						Polys1[Polys1[i].JumpTo[k]].Center.x, Polys1[Polys1[i].JumpTo[k]].Center.y, Polys1[Polys1[i].JumpTo[k]].Center.z + 1.0, 255, 0, 0, 150)
					end
				end
				if Polys1[i].Flags ~= nil then
					if is_bit_set(Polys1[i].Flags, FlagBitNames.Jump) then
						R = 100
						G = 100
					end
				end
				for k = 1, #Polys1[i] do
					if k == #Polys1[i] then
						GRAPHICS.DRAW_LINE(Polys1[i][k].x, Polys1[i][k].y, Polys1[i][k].z,
						Polys1[i][1].x, Polys1[i][1].y, Polys1[i][1].z, R, G, B, 150)
					else
						GRAPHICS.DRAW_LINE(Polys1[i][k].x, Polys1[i][k].y, Polys1[i][k].z,
						Polys1[i][k+1].x, Polys1[i][k+1].y, Polys1[i][k+1].z, R, G, B, 150)
					end
				end
				if Polys1[i].Point ~= nil then
					GRAPHICS.DRAW_MARKER(28, Polys1[i].Point.x,
					Polys1[i].Point.y, Polys1[i].Point.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 150, 0, 0, 100, 0, false, 2, false, 0, 0, false)
				end
			end
			if ReleasedPlace then
				local Idx = AddPolyVertexSnap(OutPos)
				if Idx == 0 then
					AddNewPolyVertex(OutPos)
				end
			end
			if ReleasedApply then
				ApplyPolyVertexes()
			end
			if ReleasedMove then
				local PolyIdx = 0
				if MoveState == 0 then
					util.create_thread(function()
						for k = 1, #Polys1 do
							if Inside3DPolygon2(Polys1[k], OutPos) then
								PolyIdx = k
								InsideOfPolygonAdd = true
								break
							end
						end
						if PolyIdx ~= 0 then
							local Dist = 10000.0
							local ClosestVertex = {x = 0.0, y = 0.0, z = 0.0}
							local PolysVertex = {}
							for k = 1, #Polys1[PolyIdx] do
								PolysVertex[#PolysVertex+1] = {x = Polys1[PolyIdx][k].x, y = Polys1[PolyIdx][k].y, z = Polys1[PolyIdx][k].z}
							end
							for k = 1, #PolysVertex do
								local Distance = MISC.GET_DISTANCE_BETWEEN_COORDS(OutPos.x, OutPos.y, OutPos.z, PolysVertex[k].x, PolysVertex[k].y, PolysVertex[k].z, true)
								if Distance < Dist then
									Dist = Distance
									ClosestVertex.x = PolysVertex[k].x
									ClosestVertex.y = PolysVertex[k].y
									ClosestVertex.z = PolysVertex[k].z
								end
							end
							local PolysIdxs = {}
							for k = 1, #Polys1 do
								for i = 1, #Polys1[k] do
									if Polys1[k][i].x == ClosestVertex.x and Polys1[k][i].y == ClosestVertex.y and Polys1[k][i].z == ClosestVertex.z then
										PolysIdxs[#PolysIdxs+1] = {PolyID = k, VertexID = i}
									end
								end
							end
							MoveState = 1
							while MoveState == 1 do
								local OutPos2 = RaycastFromCamera(PLAYER.PLAYER_PED_ID(), 1000.0, -1)
								OutPos2.z = OutPos2.z + 1.0
								for k = 1, #PolysIdxs do
									Polys1[PolysIdxs[k].PolyID][PolysIdxs[k].VertexID].x = OutPos2.x
									Polys1[PolysIdxs[k].PolyID][PolysIdxs[k].VertexID].y = OutPos2.y
									Polys1[PolysIdxs[k].PolyID][PolysIdxs[k].VertexID].z = OutPos2.z
								end
								Wait()
							end
						end
					end)
				else
					MoveState = 0
				end
			end
			Wait()
		end
	end
end)

menu.action(AddPolysMenu, "Add New Poly Vertex", {}, "", function(Toggle)
	AddNewPolyVertex()
end)

menu.action(AddPolysMenu, "Add Poly Vertex From Selected", {}, "", function(Toggle)
	AddPolyVertexSnap()
end)

menu.action(AddPolysMenu, "Apply Poly Vertexes", {}, "", function(Toggle)
	ApplyPolyVertexes()
end)

function AddNewPolyVertex(CustomPos)
	local PosVar = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	if CustomPos ~= nil then
		PosVar = CustomPos
	end
	Vertexes_1[#Vertexes_1+1] = PosVar
	ShowLinesEdit()
end

function AddPolyVertexSnap(CustomPos)
	local PosVar = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	if CustomPos ~= nil then
		PosVar = CustomPos
	end
	local PolyIdx = 0
	local SnapCoords = {x = 0.0, y = 0.0, z = 0.0}
	if #Polys1 > 0 then
		for k = 1, #Polys1 do
			if Inside3DPolygon2(Polys1[k], PosVar) then
				PolyIdx = k
				break
			end
		end
		if PolyIdx ~= 0 then
			local Dist = 10000.0
			local PolysVertex = {}
			for k = 1, #Polys1[PolyIdx] do
				PolysVertex[#PolysVertex+1] = {x = Polys1[PolyIdx][k].x, y = Polys1[PolyIdx][k].y, z = Polys1[PolyIdx][k].z}
			end
			for k = 1, #PolysVertex do
				local Distance = MISC.GET_DISTANCE_BETWEEN_COORDS(PosVar.x, PosVar.y, PosVar.z, PolysVertex[k].x, PolysVertex[k].y, PolysVertex[k].z, true)
				if Distance < Dist then
					Dist = Distance
					SnapCoords.x = PolysVertex[k].x
					SnapCoords.y = PolysVertex[k].y
					SnapCoords.z = PolysVertex[k].z
				end
			end
			Vertexes_1[#Vertexes_1+1] = {x = SnapCoords.x, y = SnapCoords.y, z = SnapCoords.z}
			ShowLinesEdit()
		end
	end
	return PolyIdx
end

function ApplyPolyVertexes()
	if #Vertexes_1 > 2 then
		Polys1[#Polys1+1] = {}
		for k = 1, #Vertexes_1 do
			Polys1[#Polys1][#Polys1[#Polys1]+1] = Vertexes_1[k]
		end
		SetAllPolysNeighboors(#Polys1)
		for k = 1, #Vertexes_1 do
			table.remove(Vertexes_1, #Vertexes_1)
		end
	end
end

local MoveState = 0
menu.action(AddPolysMenu, "Move All Polygon Vertexes", {}, "", function(Toggle)
	local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	local PolyIdx = 0
	if MoveState == 0 then
		for k = 1, #Polys1 do
			if Inside3DPolygon2(Polys1[k], PlayerPos) then
				PolyIdx = k
				InsideOfPolygonAdd = true
				break
			end
		end
		if PolyIdx ~= 0 then
			local Dist = 10000.0
			local ClosestVertex = {x = 0.0, y = 0.0, z = 0.0}
			local PolysVertex = {}
			for k = 1, #Polys1[PolyIdx] do
				PolysVertex[#PolysVertex+1] = {x = Polys1[PolyIdx][k].x, y = Polys1[PolyIdx][k].y, z = Polys1[PolyIdx][k].z}
			end
			for k = 1, #PolysVertex do
				local Distance = MISC.GET_DISTANCE_BETWEEN_COORDS(PlayerPos.x, PlayerPos.y, PlayerPos.z, PolysVertex[k].x, PolysVertex[k].y, PolysVertex[k].z, true)
				if Distance < Dist then
					Dist = Distance
					ClosestVertex.x = PolysVertex[k].x
					ClosestVertex.y = PolysVertex[k].y
					ClosestVertex.z = PolysVertex[k].z
				end
			end
			local PolysIdxs = {}
			for k = 1, #Polys1 do
				for i = 1, #Polys1[k] do
					if Polys1[k][i].x == ClosestVertex.x and Polys1[k][i].y == ClosestVertex.y and Polys1[k][i].z == ClosestVertex.z then
						PolysIdxs[#PolysIdxs+1] = {PolyID = k, VertexID = i}
					end
				end
			end
			MoveState = 1
			while MoveState == 1 do
				PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
				for k = 1, #PolysIdxs do
					Polys1[PolysIdxs[k].PolyID][PolysIdxs[k].VertexID].x = PlayerPos.x
					Polys1[PolysIdxs[k].PolyID][PolysIdxs[k].VertexID].y = PlayerPos.y
					Polys1[PolysIdxs[k].PolyID][PolysIdxs[k].VertexID].z = PlayerPos.z
				end
				Wait()
			end
		end
	else
		MoveState = 0
	end
end)

menu.action(AddPolysMenu, "Delete Last Poly", {}, "", function(Toggle)
	table.remove(Polys1, #Polys1)
	PolyStart = #Polys1
end)

menu.action(AddPolysMenu, "Delete Selected Poly", {}, "", function(Toggle)
	local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	for k = 1, #Polys1 do
		if Inside3DPolygon2(Polys1[k], PlayerPos) then
			table.remove(Polys1, k)
			break
		end
	end
end)

local Coords1_2 = {x = 0.0, y = 0.0, z = 0.0}
local Coords2_2 = {x = 0.0, y = 0.0, z = 0.0}
local GridSizeX = 1
local GridSizeY = 1
local GridOffset = 0.5
menu.slider(AddPolysMenu, "Grid Size X", {"gridsizex"}, "", 0, 30, GridSizeX, 1, function(on_change)
	GridSizeX = on_change
end)
menu.slider(AddPolysMenu, "Grid Size Y", {"gridsizex"}, "", 0, 30, GridSizeY, 1, function(on_change)
	GridSizeY = on_change
end)
menu.slider_float(AddPolysMenu, "Grid Size Offset", {"gridoffset"}, "", 50, 1000, 50, 50, function(on_change)
	GridOffset = on_change / 100
end)
local GridRotationX = 0.0
local GridRotationY = 0.0
local GridRotationZ = 0.0
menu.slider_float(AddPolysMenu, "Grid Rotation X", {"gridrotationx"}, "", 0, 36000, 0, 1000, function(on_change)
	GridRotationX = on_change / 100
end)
menu.slider_float(AddPolysMenu, "Grid Rotation Y", {"gridrotationy"}, "", 0, 36000, 0, 1000, function(on_change)
	GridRotationY = on_change / 100
end)
menu.slider_float(AddPolysMenu, "Grid Rotation Z", {"gridrotationz"}, "", 0, 36000, 0, 1000, function(on_change)
	GridRotationZ = on_change / 100
end)

local AddState6 = 0
menu.action(AddPolysMenu, "Add Poly Grid", {}, "", function(Toggle)
	AddState6 = AddState6 + 1
	if AddState6 == 1 then
		Print("Press again to confirm.")
		local NewLinesT = {}
		while AddState6 == 1 do
			local PlayerPed = PLAYER.PLAYER_PED_ID()
			local Rot = ENTITY.GET_ENTITY_ROTATION(PlayerPed, 2)
			local Pos2 = ENTITY.GET_ENTITY_COORDS(PlayerPed)
			Rot.x = Rot.x + GridRotationX
			Rot.y = Rot.y + GridRotationY
			Rot.z = Rot.z + GridRotationZ
			local LinesT = {}
			for i = -GridSizeX, GridSizeX do
				local DrawsT = {}
				for k = -GridSizeY, GridSizeY do
					local Pos = GetOffsetFromRotationInWorldCoords(Rot, Pos2, -GridOffset + (GridOffset * 2) * i, GridOffset + (GridOffset * 2) * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 255, 0, 0}
					local Pos = GetOffsetFromRotationInWorldCoords(Rot, Pos2, -GridOffset + (GridOffset * 2) * i, -GridOffset + (GridOffset * 2) * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 255, 0}
					local Pos = GetOffsetFromRotationInWorldCoords(Rot, Pos2, GridOffset + (GridOffset * 2) * i, -GridOffset + (GridOffset * 2) * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 0, 255}
					local Pos = GetOffsetFromRotationInWorldCoords(Rot, Pos2, GridOffset + (GridOffset * 2) * i, GridOffset + (GridOffset * 2) * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 255, 255, 0}
					local Pos = GetOffsetFromRotationInWorldCoords(Rot, Pos2, -GridOffset + (GridOffset * 2) * i, GridOffset + (GridOffset * 2) * k, 1.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 255, 255}
				end
				LinesT[#LinesT+1] = DrawsT
			end
			for i = 1, #LinesT do
				local kIt = 1
				while kIt <= #LinesT[i]-4 do
					GRAPHICS.DRAW_POLY(LinesT[i][kIt][1].x, LinesT[i][kIt][1].y, LinesT[i][kIt][1].z,
					LinesT[i][kIt+1][1].x, LinesT[i][kIt+1][1].y, LinesT[i][kIt+1][1].z,
					LinesT[i][kIt+2][1].x, LinesT[i][kIt+2][1].y, LinesT[i][kIt+2][1].z,
					LinesT[i][kIt+3][2], LinesT[i][kIt+3][3], LinesT[i][kIt+3][4], 100)
					GRAPHICS.DRAW_POLY(LinesT[i][kIt+3][1].x, LinesT[i][kIt+3][1].y, LinesT[i][kIt+3][1].z,
					LinesT[i][kIt+4][1].x, LinesT[i][kIt+4][1].y, LinesT[i][kIt+4][1].z,
					LinesT[i][kIt+2][1].x, LinesT[i][kIt+2][1].y, LinesT[i][kIt+2][1].z,
					LinesT[i][kIt+3][2], LinesT[i][kIt+3][3], LinesT[i][kIt+3][4], 100)
					kIt = kIt + 5
				end
			end
			for i = 1, #LinesT do
				for k = 1, #LinesT[i]-1 do
					GRAPHICS.DRAW_LINE(LinesT[i][k][1].x, LinesT[i][k][1].y, LinesT[i][k][1].z,
					LinesT[i][k+1][1].x, LinesT[i][k+1][1].y, LinesT[i][k+1][1].z, LinesT[i][k+1][2], LinesT[i][k+1][3], LinesT[i][k+1][4], 150)
				end
			end
			NewLinesT = LinesT
			Wait()
		end
		if AddState6 == 2 then
			for i = 1, #NewLinesT do
				local kIt = 1
				while kIt <= #NewLinesT[i]-4 do
					Print(#NewLinesT[i])
					Polys1[#Polys1+1] = {
						{x = NewLinesT[i][kIt][1].x, y = NewLinesT[i][kIt][1].y, z = NewLinesT[i][kIt][1].z},
						{x = NewLinesT[i][kIt+1][1].x, y = NewLinesT[i][kIt+1][1].y, z = NewLinesT[i][kIt+1][1].z},
						{x = NewLinesT[i][kIt+2][1].x, y = NewLinesT[i][kIt+2][1].y, z = NewLinesT[i][kIt+2][1].z}
					}
					Polys1[#Polys1].Center = GetPolygonCenter(Polys1[#Polys1])
					SetPolyEdges(#Polys1)
					Polys1[#Polys1+1] = {
						{x = NewLinesT[i][kIt+3][1].x, y = NewLinesT[i][kIt+3][1].y, z = NewLinesT[i][kIt+3][1].z},
						{x = NewLinesT[i][kIt+4][1].x, y = NewLinesT[i][kIt+4][1].y, z = NewLinesT[i][kIt+4][1].z},
						{x = NewLinesT[i][kIt+2][1].x, y = NewLinesT[i][kIt+2][1].y, z = NewLinesT[i][kIt+2][1].z}
					}
					Polys1[#Polys1].Center = GetPolygonCenter(Polys1[#Polys1])
					SetPolyEdges(#Polys1)
					kIt = kIt + 5
				end
			end
		end
		
		--SetAllPolysNeighboors()
	end
	if AddState6 == 2 then
		Wait()
		AddState6 = 0
	end
end)

local AddState7 = 0
menu.action(AddPolysMenu, "Add Poly Grid Raycast Manual", {}, "Use NUMPAD to move.", function(Toggle)
	AddState7 = AddState7 + 1 
	if AddState7 == 1 then
		Print("Press again to confirm.")
		local NewLinesT = {}
		local PlayerPed = PLAYER.PLAYER_PED_ID()
		local Pos2 = RaycastFromCamera(PlayerPed, 1000.0, -1)
		while AddState7 == 1 do
			local Rot = {}
			Rot.x = GridRotationX
			Rot.y = GridRotationY
			Rot.z = GridRotationZ
			if not menu.is_open() and not menu.command_box_is_open() then
				local ButtonLeftPressed = util.is_key_down(0x64)
				local ButtonRightPressed = util.is_key_down(0x66)
				local ButtonDownPressed = util.is_key_down(0x62)
				local ButtonUpPressed = util.is_key_down(0x68)
				local RotateLeftPressed = util.is_key_down(0x67)
				local RotateRightPressed = util.is_key_down(0x69)
				if ButtonDownPressed then
					Pos2.y = Pos2.y - 0.1
				end
				if ButtonUpPressed then
					Pos2.y = Pos2.y + 0.1
				end
				if ButtonLeftPressed then
					Pos2.x = Pos2.x - 0.1
				end
				if ButtonRightPressed then
					Pos2.x = Pos2.x + 0.1
				end
				if RotateLeftPressed then
					Pos2.z = Pos2.z - 0.1
				end
				if RotateRightPressed then
					Pos2.z = Pos2.z + 0.1
				end
			end
			local LinesT = {}
			for i = -GridSizeX, GridSizeX do
				local DrawsT = {}
				for k = -GridSizeY, GridSizeY do
					local Pos = GetOffsetFromRotationInWorldCoords(Rot, Pos2, -GridOffset + (GridOffset * 2) * i, GridOffset + (GridOffset * 2) * k, 2.0)
					DrawsT[#DrawsT+1] = {Pos, 255, 0, 0}
					local Pos = GetOffsetFromRotationInWorldCoords(Rot, Pos2, -GridOffset + (GridOffset * 2) * i, -GridOffset + (GridOffset * 2) * k, 2.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 255, 0}
					local Pos = GetOffsetFromRotationInWorldCoords(Rot, Pos2, GridOffset + (GridOffset * 2) * i, -GridOffset + (GridOffset * 2) * k, 2.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 0, 255}
					local Pos = GetOffsetFromRotationInWorldCoords(Rot, Pos2, GridOffset + (GridOffset * 2) * i, GridOffset + (GridOffset * 2) * k, 2.0)
					DrawsT[#DrawsT+1] = {Pos, 255, 255, 0}
					local Pos = GetOffsetFromRotationInWorldCoords(Rot, Pos2, -GridOffset + (GridOffset * 2) * i, GridOffset + (GridOffset * 2) * k, 2.0)
					DrawsT[#DrawsT+1] = {Pos, 0, 255, 255}
				end
				LinesT[#LinesT+1] = DrawsT
			end
			for i = 1, #LinesT do
				local kIt = 1
				while kIt <= #LinesT[i]-4 do
					GRAPHICS.DRAW_POLY(LinesT[i][kIt][1].x, LinesT[i][kIt][1].y, LinesT[i][kIt][1].z,
					LinesT[i][kIt+1][1].x, LinesT[i][kIt+1][1].y, LinesT[i][kIt+1][1].z,
					LinesT[i][kIt+2][1].x, LinesT[i][kIt+2][1].y, LinesT[i][kIt+2][1].z,
					LinesT[i][kIt+3][2], LinesT[i][kIt+3][3], LinesT[i][kIt+3][4], 100)
					GRAPHICS.DRAW_POLY(LinesT[i][kIt+3][1].x, LinesT[i][kIt+3][1].y, LinesT[i][kIt+3][1].z,
					LinesT[i][kIt+4][1].x, LinesT[i][kIt+4][1].y, LinesT[i][kIt+4][1].z,
					LinesT[i][kIt+2][1].x, LinesT[i][kIt+2][1].y, LinesT[i][kIt+2][1].z,
					LinesT[i][kIt+3][2], LinesT[i][kIt+3][3], LinesT[i][kIt+3][4], 100)
					kIt = kIt + 5
				end
			end
			for i = 1, #LinesT do
				for k = 1, #LinesT[i]-1 do
					GRAPHICS.DRAW_LINE(LinesT[i][k][1].x, LinesT[i][k][1].y, LinesT[i][k][1].z,
					LinesT[i][k+1][1].x, LinesT[i][k+1][1].y, LinesT[i][k+1][1].z, LinesT[i][k+1][2], LinesT[i][k+1][3], LinesT[i][k+1][4], 150)
				end
			end
			NewLinesT = LinesT
			Wait()
		end
		if AddState7 == 2 then
			for i = 1, #NewLinesT do
				local kIt = 1
				while kIt <= #NewLinesT[i]-4 do
					Print(#NewLinesT[i])
					Polys1[#Polys1+1] = {
						{x = NewLinesT[i][kIt][1].x, y = NewLinesT[i][kIt][1].y, z = NewLinesT[i][kIt][1].z},
						{x = NewLinesT[i][kIt+1][1].x, y = NewLinesT[i][kIt+1][1].y, z = NewLinesT[i][kIt+1][1].z},
						{x = NewLinesT[i][kIt+2][1].x, y = NewLinesT[i][kIt+2][1].y, z = NewLinesT[i][kIt+2][1].z}
					}
					Polys1[#Polys1].Center = GetPolygonCenter(Polys1[#Polys1])
					SetPolyEdges(#Polys1)
					Polys1[#Polys1+1] = {
						{x = NewLinesT[i][kIt+3][1].x, y = NewLinesT[i][kIt+3][1].y, z = NewLinesT[i][kIt+3][1].z},
						{x = NewLinesT[i][kIt+4][1].x, y = NewLinesT[i][kIt+4][1].y, z = NewLinesT[i][kIt+4][1].z},
						{x = NewLinesT[i][kIt+2][1].x, y = NewLinesT[i][kIt+2][1].y, z = NewLinesT[i][kIt+2][1].z}
					}
					Polys1[#Polys1].Center = GetPolygonCenter(Polys1[#Polys1])
					SetPolyEdges(#Polys1)
					kIt = kIt + 5
				end
			end
		end
		--SetAllPolysNeighboors()
	end
	if AddState7 == 2 then
		Wait(10)
		AddState7 = 0
	end
end)

menu.action(AddPolysMenu, "Cancel Add Poly Grid", {}, "", function(Toggle)
	AddState6 = 0
	AddState7 = 0
end)

local LinkState = 0
local LinkID = 0
local ToLinkID = 0
menu.action(AddPolysMenu, "Link Polygon To Polygon", {}, "", function(Toggle)
	local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	local PolyIdx = 0
	if LinkState == 0 then
		for k = 1, #Polys1 do
			if Inside3DPolygon2(Polys1[k], PlayerPos) then
				PolyIdx = k
				break
			end
		end
		if PolyIdx ~= 0 then
			LinkState = 1
			LinkID = PolyIdx
			Print("Index is "..LinkID.." and now waiting for user input the next ID.")
		end
	end
	if LinkState == 1 then
		for k = 1, #Polys1 do
			if Inside3DPolygon2(Polys1[k], PlayerPos) then
				PolyIdx = k
				break
			end
		end
		if PolyIdx ~= 0 then
			if PolyIdx ~= LinkID then
				ToLinkID = PolyIdx
				local CanInsert = true
				local CanInsertToID = true
				if Polys1[LinkID].LinkedIDs ~= nil then
					for k = 1, #Polys1[LinkID].LinkedIDs do
						if Polys1[LinkID].LinkedIDs[k] == ToLinkID then
							CanInsert = false
							break
						end
					end
				end
				if Polys1[ToLinkID].LinkedIDs ~= nil then
					for k = 1, #Polys1[ToLinkID].LinkedIDs do
						if Polys1[ToLinkID].LinkedIDs[k] == LinkID then
							CanInsertToID = false
							break
						end
					end
				end
				if CanInsert then
					if Polys1[LinkID].LinkedIDs == nil then
						Polys1[LinkID].LinkedIDs = {}
					end
					Polys1[LinkID].LinkedIDs[#Polys1[LinkID].LinkedIDs+1] = ToLinkID
				end
				if CanInsertToID then
					if Polys1[ToLinkID].LinkedIDs == nil then
						Polys1[ToLinkID].LinkedIDs = {}
					end
					Polys1[ToLinkID].LinkedIDs[#Polys1[ToLinkID].LinkedIDs+1] = LinkID
					Print("Index ".. LinkID.." and index "..ToLinkID.." are linked.")
				end
				ToLinkID = 0
				LinkID = 0
				LinkState = 0
			end
		end
	end
end)

local LinkState2 = 0
local LinkID2 = 0
local ToLinkID2 = 0
menu.action(AddPolysMenu, "Link Polygon To Polygon 2", {}, "Only the previous polygon will have the next polygon as neighbor id.", function(Toggle)
	local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	local PolyIdx = 0
	if LinkState2 == 0 then
		for k = 1, #Polys1 do
			if Inside3DPolygon2(Polys1[k], PlayerPos) then
				PolyIdx = k
				break
			end
		end
		if PolyIdx ~= 0 then
			LinkState2 = 1
			LinkID2 = PolyIdx
			Print("Index is "..LinkID2.." and now waiting for user input the next ID.")
		end
	end
	if LinkState2 == 1 then
		for k = 1, #Polys1 do
			if Inside3DPolygon2(Polys1[k], PlayerPos) then
				PolyIdx = k
				break
			end
		end
		if PolyIdx ~= 0 then
			if PolyIdx ~= LinkID2 then
				ToLinkID2 = PolyIdx
				local CanInsertToID = true
				if Polys1[LinkID2].LinkedIDs ~= nil then
					for k = 1, #Polys1[LinkID2].LinkedIDs do
						if Polys1[LinkID2].LinkedIDs[k] == ToLinkID2 then
							CanInsertToID = false
							break
						end
					end
				end
				if CanInsertToID then
					if Polys1[LinkID2].LinkedIDs == nil then
						Polys1[LinkID2].LinkedIDs = {}
					end
					Polys1[LinkID2].LinkedIDs[#Polys1[LinkID2].LinkedIDs+1] = ToLinkID2
					Print("Index ".. LinkID2.." and index "..ToLinkID2.." are linked.")
				end
				
				ToLinkID2 = 0
				LinkID2 = 0
				LinkState2 = 0
			end
		end
	end
end)

menu.action(AddPolysMenu, "Clear Linked Polygons To Selected", {}, "", function(Toggle)
	local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	local PolyIdx = 0
	for k = 1, #Polys1 do
		if Inside3DPolygon2(Polys1[k], PlayerPos) then
			PolyIdx = k
			break
		end
	end
	if PolyIdx ~= 0 then
		for k = 1, #Polys1[PolyIdx].LinkedIDs do
			table.remove(Polys1[PolyIdx].LinkedIDs, #Polys1[PolyIdx].LinkedIDs)
		end
		--Polys1[PolyIdx].LinkedIDs = nil
	end
end)

menu.action(AddPolysMenu, "Clear All Linked Polygons", {}, "", function(Toggle)
	local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	local PolyIdx = 0
	for k = 1, #Polys1 do
		for i = 1, #Polys1[k].LinkedIDs do
			table.remove(Polys1[k].LinkedIDs, #Polys1[k].LinkedIDs)
		end
	end
end)

local PointToPolyIndex = 0
menu.action(AddPolysMenu, "Add Point To Polygon", {}, "", function(Toggle)
	local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	if PointToPolyIndex == 0 then
		local PolyIdx = 0
		for k = 1, #Polys1 do
			if Inside3DPolygon2(Polys1[k], PlayerPos) then
				PolyIdx = k
				break
			end
		end
		if PolyIdx ~= 0 then
			PointToPolyIndex = PolyIdx
			Print("Now place the point to the desired coords.")
		end
	else
		if PointToPolyIndex ~= 0 then
			Polys1[PointToPolyIndex].Point = {
				x = PlayerPos.x,
				y = PlayerPos.y,
				z = PlayerPos.z,
				Heading = ENTITY.GET_ENTITY_HEADING(PLAYER.PLAYER_PED_ID())
			}
			Print("Point added to polygon index "..PointToPolyIndex..".")
			PointToPolyIndex = 0
		end
	end
end)

menu.action(AddPolysMenu, "Delete Selected Poly Point", {}, "", function(Toggle)
	local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	local PolyIdx = 0
	for k = 1, #Polys1 do
		if Inside3DPolygon2(Polys1[k], PlayerPos) then
			PolyIdx = k
			break
		end
	end
	if PolyIdx ~= 0 then
		Polys1[PolyIdx].Point = nil
	end
end)

menu.action(AddPolysMenu, "Delete All Poly Points", {}, "", function(Toggle)
	for k = 1, #Polys1 do
		Polys1[k].Point = nil
	end
end)

menu.action(AddPolysMenu, "Calculate All Polygon Neighbors", {}, "", function(Toggle)
	SetAllPolysNeighboors()
end)

local PolygonLoadOrSaveMenu = menu.list(NavmeshingMenu, "Save Load Polygons", {}, "")
menu.action(PolygonLoadOrSaveMenu, "Save Polys", {}, "", function(Toggle)
	local ToJSON = {}
	for k = 1, #Polys1 do
		ToJSON[#ToJSON+1] = {}
		for i = 1, #Polys1[k] do
			ToJSON[#ToJSON]["Poly"..i] = {x = Polys1[k][i].x, y = Polys1[k][i].y, z = Polys1[k][i].z}
		end
		ToJSON[#ToJSON].Center = Polys1[k].Center
		ToJSON[#ToJSON].Neighboors = Polys1[k].Neighboors
		ToJSON[#ToJSON].LinkedIDs = Polys1[k].LinkedIDs
		ToJSON[#ToJSON].Flags = Polys1[k].Flags
		ToJSON[#ToJSON].Point = Polys1[k].Point
		ToJSON[#ToJSON].JumpTo = Polys1[k].JumpTo or nil
		ToJSON[#ToJSON].JumpedFrom = Polys1[k].JumpedFrom or nil
		ToJSON[#ToJSON].Edges = Polys1[k].Edges
	end
	SaveJSONFile(filesystem.scripts_dir().."\\navs\\LastNav.json", ToJSON)
end)

menu.action(PolygonLoadOrSaveMenu, "Load Polys", {}, "", function(Toggle)
	PlatformIDs = LoadNavmesh("LastNav.json", Polys1, true)
end)

menu.action(PolygonLoadOrSaveMenu, "Load Vehicle Polys", {}, "", function(Toggle)
	VehNavIDs = LoadNavmesh("PlaneNav.json", Polys1)
end)

local TestMenu = menu.list(NavmeshingMenu, "Test Navigation", {}, "")
local StartPath = {x = -979.44439697266, y = 166.95582580566, z = 373.1741027832}

local NavNetID = 0
local NavHandle = 0
local PedNav = false
menu.toggle(TestMenu, "Create Ped For Nav", {}, "", function(Toggle)
	PedNav = Toggle
	if not PedNav then
		if NavNetID ~= 0 then
			NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(NavNetID, PLAYER.PLAYER_ID(), false)
		end
		entities.delete_by_handle(NavHandle)
	end
	if PedNav then
		local StartPos = {x = StartPath.x, y = StartPath.y, z = StartPath.z}
		local GoToCoords = {x = -955.48394775391, y = 166.00401306152, z = 373.17413330078}
		STREAMING.REQUEST_MODEL(joaat("mp_m_bogdangoon"))
		while not STREAMING.HAS_MODEL_LOADED(joaat("mp_m_bogdangoon")) do
			Wait()
		end
		--local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
		NavHandle = PED.CREATE_PED(28, joaat("mp_m_bogdangoon"), StartPos.x, StartPos.y, StartPos.z, 0.0, true, true)
		WEAPON.GIVE_WEAPON_TO_PED(NavHandle, joaat("weapon_pistol"), 99999, false, true)
		ENTITY.SET_ENTITY_AS_MISSION_ENTITY(NavHandle, false, true)
		NavNetID = NETWORK.PED_TO_NET(NavHandle)
		if NavNetID ~= 0 then
			--NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(NavNetID, PLAYER.PLAYER_ID(), true)
			--NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(NavNetID, true)
			NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NavNetID, false)
		end
		local FoundIndex = 0
		local TaskStatus = 0
		local TaskCoords = {x = 0.0, y = 0.0, z = 0.0}
		local FoundPaths = nil
		local PathIndex = 1
		local InPolyIndex = 1
		local TargetPolyIndex = 1
		local InsideStartPolygon = false
		local TargetInsideTargetPolygon = false
		local LastTargetPos = {x = 0.0, y = 0.0, z = 0.0}
		local JumpDelay = 0
		local Distance = 0.5
		while PedNav do
			local Pos = ENTITY.GET_ENTITY_COORDS(NavHandle)
			local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			--PED.SET_PED_MIN_MOVE_BLEND_RATIO(NavHandle, 3.0)
			--PED.SET_PED_MAX_MOVE_BLEND_RATIO(NavHandle, 3.0)
			local FVect = ENTITY.GET_ENTITY_FORWARD_VECTOR(NavHandle)
			local AdjustedX = Pos.x + FVect.x * Distance
			local AdjustedY = Pos.y + FVect.y * Distance
			local AdjustedZ = (Pos.z + 0.5) + FVect.z * Distance
			GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z - 0.5,
			AdjustedX, AdjustedY, AdjustedZ, 255, 0, 255, 255)
			if JumpDelay <= 0 then
				if HitClimbableObject(NavHandle) then
					TASK.TASK_CLIMB(NavHandle, false)
					JumpDelay = 30
				end
			else
				JumpDelay = JumpDelay - 1
			end
			if FoundIndex == 0 then
				FoundPaths, InPolyIndex, TargetPolyIndex, InsideStartPolygon, TargetInsideTargetPolygon = AStarPathFind(Pos, PlayerPos, 3, false, nil, nil, nil, nil, nil, nil)
				if FoundPaths ~= nil then
					FoundIndex = 1
					LastTargetPos = PlayerPos
					--Print(#FoundPaths)
				end
			else
				if FoundPaths ~= nil then
					if TaskStatus == 0 then
						if PathIndex > #FoundPaths then
							PathIndex = 1
						end
						TaskCoords = FoundPaths[PathIndex]
						--Print(FoundPaths[PathIndex].NodeFlags)
						if not ENTITY.IS_ENTITY_AT_COORD(NavHandle, TaskCoords.x, TaskCoords.y, TaskCoords.z, 0.5, 0.5, 1.0, false, false, 0) then
							--local NewV3 = v3.new(TaskCoords.x, TaskCoords.y, TaskCoords.z)
							--local Sub = v3.sub(NewV3, Pos)
							--local Rot = Sub:toRot()
							--Dir = Rot:toDir()
							if RequestControlOfEntity(NavHandle) then
								
								TASK.TASK_GO_STRAIGHT_TO_COORD(NavHandle, TaskCoords.x, TaskCoords.y, TaskCoords.z, 3.0, -1, 40000.0, 0.0)
								--TASK.TASK_GO_TO_COORD_ANY_MEANS(NavHandle, TaskCoords.x, TaskCoords.y, TaskCoords.z, 2.0, 0, false, 1, -1.0)
								if TASK.GET_SCRIPT_TASK_STATUS(NavHandle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) ~= 7 then
									--TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(NavHandle, TaskCoords.x, TaskCoords.y, TaskCoords.z, PLAYER.PLAYER_PED_ID(), 2.0, true, 0.1, 0.1, false, 0, true, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
									TaskStatus = 1
								end
							end
						else
							TaskStatus = 1
						end
					end
					if TaskStatus == 1 then
						RequestControlOfEntity(NavHandle)
						if TASK.GET_SCRIPT_TASK_STATUS(NavHandle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) == 7 then
							TaskStatus = 0
						end
						if ENTITY.IS_ENTITY_AT_COORD(NavHandle, TaskCoords.x, TaskCoords.y, TaskCoords.z, 0.5, 0.5, 1.0, false, false, 0) then
							if FoundPaths[PathIndex].Action ~= nil then
								Print("Action isn't nil")
								TASK.TASK_ACHIEVE_HEADING(NavHandle, FoundPaths[PathIndex].Heading, 2000)
								Wait(2000)
								--if is_bit_set(FoundPaths[PathIndex].Action, FlagBitNames.Jump) then
									TASK.TASK_CLIMB(NavHandle, false)
									--Print("Climb")
									Wait(1000)
								--end
							end
							TaskStatus = 0
							PathIndex = PathIndex + 1
							if PathIndex > #FoundPaths then
								FoundIndex = 0
								PathIndex = 1
							end
						end
					end
					--GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z,
					--TaskCoords.x, TaskCoords.y, TaskCoords.z, 255, 255, 255, 255)
					GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z,
					TaskCoords.x, TaskCoords.y, TaskCoords.z, 255, 255, 255, 255)
					if FoundPaths ~= nil then
						for i = PathIndex, #FoundPaths-1 do
							GRAPHICS.DRAW_LINE(FoundPaths[i].x, FoundPaths[i].y, FoundPaths[i].z,
							FoundPaths[i+1].x, FoundPaths[i+1].y, FoundPaths[i+1].z, 255, 255, 255, 255)
						end
					end
					--if not InsidePolygon(Polys1[InPolyIndex], Pos) then
						if TargetInsideTargetPolygon or DistanceBetween(PlayerPos.x, PlayerPos.y, PlayerPos.z, LastTargetPos.x, LastTargetPos.y ,LastTargetPos.z) > 2.0 then
							if not InsidePolygon(Polys1[TargetPolyIndex], PlayerPos) then
								FoundIndex = 0
								TaskStatus = 0

							end
						else
							if InsidePolygon(Polys1[TargetPolyIndex], PlayerPos) then
								FoundIndex = 0
								TaskStatus = 0
							end
						end
					--end
				end
			end
			Wait()
		end
	end
end)

local GetPathToPoly2 = false
menu.toggle(TestMenu, "Get Path To Poly", {}, "", function(Toggle)
	GetPathToPoly2 = Toggle
	if GetPathToPoly2 then
		--local Pos = {x = 1382.1535644531, y = -3301.1430664062, z = 3.5249807834625}
		--local Pos = {x = 1370.142578125, y = -3324.0402832031, z = 3.5249841213226}
		local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
		--local GoToCoords = {x = -955.48394775391, y = 166.00401306152, z = 373.17413330078}
		
		local FinalPaths = AStarPathFind(StartPath, Pos, 0, 1, nil, nil, false, false, false, true)
		if FinalPaths ~= nil then
			Print(#FinalPaths)
			while GetPathToPoly2 do
				for i = 1, #FinalPaths-1 do
					GRAPHICS.DRAW_LINE(FinalPaths[i].x, FinalPaths[i].y, FinalPaths[i].z,
					FinalPaths[i+1].x, FinalPaths[i+1].y, FinalPaths[i+1].z, 255, 255, 255, 255)
					--GRAPHICS.DRAW_MARKER(28, FinalPaths[i+1].x,
					--FinalPaths[i+1].y, FinalPaths[i+1].z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 10 + 30 * i, 100, 0, 100, 0, false, 2, false, 0, 0, false)
				end
				if #FinalPaths == 1 then
					--Print("Yeah")
					--GRAPHICS.DRAW_LINE(StartPath.x, StartPath.y, StartPath.z,
					--FinalPaths[1].x, FinalPaths[1].y, FinalPaths[1].z, 255, 255, 255, 255)
				end
				Wait()
			end
		end
	end
end)

local GetPathToPoly3 = false
menu.toggle(TestMenu, "Get Path To Poly Real Time", {}, "", function(Toggle)
	GetPathToPoly3 = Toggle
	if GetPathToPoly3 then
		local SearchState = 0
		local FoundPaths = nil
		local PathIndex = 1
		local StartPolyIndex = nil
		local TargetPolyIndex = nil
		local LastTargetPolyIndex = 0
		local InsideStartPolygon = false
		local TargetInsideTargetPolygon = false
		local StartPolysT = {}
		local TargetPolysT = {}
		local FinalPaths = nil
		while GetPathToPoly3 do
			local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			if SearchState == 0 then
				FinalPaths, StartPolyIndex, TargetPolyIndex = AStarPathFind(StartPath, Pos, 1, true, StartPolyIndex, TargetPolyIndex, true, false, true)
				if FinalPaths ~= nil then
					TargetPolysT = GetNearPolygonNeighbors(TargetPolyIndex, 10)
					SearchState = 1
				end
			end
			if SearchState == 2 then
				FinalPaths, StartPolyIndex, TargetPolyIndex = AStarPathFind(StartPath, Pos, 1, true, StartPolyIndex, TargetPolyIndex, true, false, true)
				if FinalPaths ~= nil then
					SearchState = 1
				end
			end
			if TargetPolyIndex ~= nil then
				local IsInsidePolygon = false
				TargetPolyIndex, IsInsidePolygon = TrackPolygonIndex(TargetPolysT, TargetPolyIndex, Pos, 10)
				if not IsInsidePolygon then
					SearchState = 2
				end
			end
			if FinalPaths ~= nil then
				for i = 1, #FinalPaths-1 do
					GRAPHICS.DRAW_LINE(FinalPaths[i].x, FinalPaths[i].y, FinalPaths[i].z,
					FinalPaths[i+1].x, FinalPaths[i+1].y, FinalPaths[i+1].z, 255, 255, 255, 255)
				end
				if #FinalPaths == 1 then
					Print("Yeah")
					GRAPHICS.DRAW_LINE(StartPath.x, StartPath.y, StartPath.z,
					FinalPaths[1].x, FinalPaths[1].y, FinalPaths[1].z, 255, 255, 255, 255)
				end
			end
			Wait()
		end
	end
end)

local CarHandle = 0
local CarPathToPoly = false
menu.toggle(TestMenu, "Car Path To Poly", {}, "", function(Toggle)
	CarPathToPoly = Toggle
	if not CarPathToPoly then
		entities.delete_by_handle(CarHandle)
	end
	if CarPathToPoly then
		--local Pos = {x = 1382.1535644531, y = -3301.1430664062, z = 3.5249807834625}
		--local Pos = {x = 1370.142578125, y = -3324.0402832031, z = 3.5249841213226}
		local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
		--local GoToCoords = {x = -955.48394775391, y = 166.00401306152, z = 373.17413330078}
		local TaskState = 1
		local FinalPaths = AStarPathFind(StartPath, Pos, 1)
		local ActualPath = 1
		local TaskCoords = {x = 0.0, y = 0.0, z = 0.0}
		if FinalPaths ~= nil then
			local ModelName = "panto"
			STREAMING.REQUEST_MODEL(joaat(ModelName))
			while not STREAMING.HAS_MODEL_LOADED(joaat(ModelName)) do
				Wait()
			end
			CarHandle = VEHICLE.CREATE_VEHICLE(joaat(ModelName), StartPath.x, StartPath.y, StartPath.z, 0.0, true, true, false)
			STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(ModelName))
			while CarPathToPoly do
				local StartPos = ENTITY.GET_ENTITY_COORDS(CarHandle)
				if TaskState == 0 then
					Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
					FinalPaths = AStarPathFind(StartPos, Pos, 1, nil, nil, nil, nil, nil, nil, true)
					if FinalPaths ~= nil then
						TaskState = 1
					end
				end
				if TaskState == 1 then
					if ActualPath > #FinalPaths then
						TaskState = 0
						ActualPath = 1
					end
					TaskCoords = FinalPaths[ActualPath]
					local Sub = {
						x = TaskCoords.x - StartPos.x,
						y = TaskCoords.y - StartPos.y,
						z = TaskCoords.z - StartPos.z
					}
					local NewV3 = v3.new(Sub.x, Sub.y, Sub.z)
					NewV3:normalise()
					if RequestControlOfEntity(CarHandle) then
						local ActualVel = ENTITY.GET_ENTITY_VELOCITY(CarHandle)
						if NewV3.x < 6.0 and NewV3.x > -6.0 then
							ENTITY.SET_ENTITY_VELOCITY(CarHandle, NewV3.x * 5.0, NewV3.y * 5.0, ActualVel.z)
						end
					end
					if ENTITY.IS_ENTITY_AT_COORD(CarHandle, TaskCoords.x, TaskCoords.y, TaskCoords.z, 0.5, 0.5, 1.5, false, true, 0) then
						ActualPath = ActualPath + 1
					end
				end
				Wait()
			end
		end
	end
end)

local NavNetID2 = 0
local NavHandle2 = 0
local CarHandle2 = 0
local PedNav2 = false
menu.toggle(TestMenu, "Create Ped In Car For Nav", {}, "", function(Toggle)
	PedNav2 = Toggle
	if not PedNav2 then
		if NavNetID2 ~= 0 then
			NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(NavNetID2, PLAYER.PLAYER_ID(), false)
		end
		entities.delete_by_handle(NavHandle2)
		entities.delete_by_handle(CarHandle2)
	end
	if PedNav2 then
		local StartPos = {x = StartPath.x, y = StartPath.y, z = StartPath.z}
		local GoToCoords = {x = -955.48394775391, y = 166.00401306152, z = 373.17413330078}
		STREAMING.REQUEST_MODEL(joaat("mp_m_bogdangoon"))
		while not STREAMING.HAS_MODEL_LOADED(joaat("mp_m_bogdangoon")) do
			Wait()
		end
		NavHandle2 = PED.CREATE_PED(28, joaat("mp_m_bogdangoon"), StartPos.x, StartPos.y, StartPos.z, 0.0, true, true)
		WEAPON.GIVE_WEAPON_TO_PED(NavHandle2, joaat("weapon_pistol"), 99999, false, true)
		NavNetID2 = NETWORK.PED_TO_NET(NavHandle2)
		if NavNetID ~= 0 then
			NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NavNetID2, false)
		end
		local ModelName = "bati"
		STREAMING.REQUEST_MODEL(joaat(ModelName))
		while not STREAMING.HAS_MODEL_LOADED(joaat(ModelName)) do
			Wait()
		end
		CarHandle2 = VEHICLE.CREATE_VEHICLE(joaat(ModelName), StartPath.x, StartPath.y, StartPath.z, ENTITY.GET_ENTITY_HEADING(PLAYER.PLAYER_PED_ID()), true, true, false)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(ModelName))
		PED.SET_PED_INTO_VEHICLE(NavHandle2, CarHandle2, -1)
		local FoundIndex = 0
		local TaskStatus = 0
		local TaskCoords = {x = 0.0, y = 0.0, z = 0.0}
		local FoundPaths = nil
		local PathIndex = 1
		local InPolyIndex = nil
		local TargetPolyIndex = nil
		local InsideStartPolygon = false
		local TargetInsideTargetPolygon = false
		local StartPolysT = {}
		local TargetPolysT = {}
		local LastDistance = 0.0
		local MinDist = 1.5
		local DistState = 1
		while PedNav2 do
			local Pos = ENTITY.GET_ENTITY_COORDS(NavHandle2)
			local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			if FoundIndex == 0 then
				FoundPaths, InPolyIndex, TargetPolyIndex, InsideStartPolygon, TargetInsideTargetPolygon = AStarPathFind(Pos, PlayerPos, 1, false, nil, nil, nil, nil, nil, nil, nil)
				if FoundPaths ~= nil then
					FoundIndex = 2
					Print(#FoundPaths)
					--StartPolysT = GetNearPolygonNeighbors(InPolyIndex, 10)
					--TargetPolysT = GetNearPolygonNeighbors(TargetPolyIndex, 10)
					LastDistance = 1000.0
				end
			end
			if FoundIndex == 1 then
				FoundPaths, InPolyIndex, TargetPolyIndex, InsideStartPolygon, TargetInsideTargetPolygon = AStarPathFind(Pos, PlayerPos, 1, false, nil, nil, nil, nil, nil, nil, nil)
				if FoundPaths ~= nil then
					FoundIndex = 2
					LastDistance = 1000.0
				end
			end
			if FoundPaths ~= nil then
				local Distance = DistanceBetween(Pos.x, Pos.y, Pos.z, PlayerPos.x, PlayerPos.y, PlayerPos.z)
				local IsInsidePolygon = true
				if InPolyIndex ~= nil then
					--InPolyIndex, IsInsidePolygon = TrackPolygonIndex(StartPolysT, InPolyIndex, Pos, 10)
				end
				local IsInsidePolygon2 = true
				if TargetPolyIndex ~= nil then
					--TargetPolyIndex, IsInsidePolygon2 = TrackPolygonIndex(TargetPolysT, TargetPolyIndex, PlayerPos, 10)
				end
				if Distance < 10.0 then
					if not IsInsidePolygon2 then
						FoundIndex = 1
					end
				end
				if TaskStatus == 0 then
					if PathIndex > #FoundPaths then
						PathIndex = 1
					end
					TaskCoords = FoundPaths[PathIndex]
					if not ENTITY.IS_ENTITY_AT_COORD(NavHandle2, TaskCoords.x, TaskCoords.y, TaskCoords.z, 1.0, 1.0, 1.0, false, true, 0) then
						if RequestControlOfEntity(NavHandle2) then
							TASK.TASK_VEHICLE_DRIVE_TO_COORD(NavHandle2, CarHandle2, TaskCoords.x, TaskCoords.y, TaskCoords.z, 5.0, 1, joaat(ModelName), 16777216, 0.01, 40000.0)
							TaskStatus = 1
							LastDistance = DistanceBetween(Pos.x, Pos.y, Pos.z, TaskCoords.x, TaskCoords.y, TaskCoords.z)
						end
					else
						TaskStatus = 1
					end
				end
				if TaskStatus == 1 then
					local Distance2 = DistanceBetween(Pos.x, Pos.y, Pos.z, TaskCoords.x, TaskCoords.y, TaskCoords.z)
					if DistState == 0 then
						if math.floor(Distance2) > math.floor(LastDistance) then
							LastDistance = Distance2
							DistState = 1
						end
					end
					if DistState == 1 then
						if math.floor(Distance2) < math.floor(LastDistance) then
							LastDistance = Distance2
						end
						if math.floor(Distance2) > math.floor(LastDistance) then
							TaskStatus = 0
							PathIndex = 1
							FoundIndex = 1
							Print("Called")
						end
					end
					if ENTITY.IS_ENTITY_AT_COORD(NavHandle2, TaskCoords.x, TaskCoords.y, TaskCoords.z, MinDist, MinDist, MinDist, false, true, 0) then
						TaskStatus = 0
						PathIndex = PathIndex + 1
						if PathIndex > #FoundPaths then
							FoundIndex = 0
							PathIndex = 1
						end
					end
				end
				GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z,
				TaskCoords.x, TaskCoords.y, TaskCoords.z, 255, 255, 255, 255)
			end
			Wait()
		end
	end
end)

menu.action(TestMenu, "Set Start Path", {}, "", function(Toggle)
	StartPath = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
end)

menu.action(TestMenu, "Pathfind Test", {}, "", function(Toggle)
	local PlayerPed = PLAYER.PLAYER_PED_ID()
	local Pos = ENTITY.GET_ENTITY_COORDS(PlayerPed)
	--local StartPolyID = GetClosestPolygon(Polys1, StartPath, false)
	--local TargetPolyID = GetClosestPolygon(Polys1, Pos, false)
	--[[
	for i = 1, 1000 do
		GRAPHICS.DRAW_LINE(Polys1[StartPolyID][1].x, Polys1[StartPolyID][1].y, Polys1[StartPolyID][1].z, Polys1[StartPolyID][2].x, Polys1[StartPolyID][2].y, Polys1[StartPolyID][2].z, 255, 255, 255, 255)
		GRAPHICS.DRAW_LINE(Polys1[StartPolyID][2].x, Polys1[StartPolyID][2].y, Polys1[StartPolyID][2].z, Polys1[StartPolyID][3].x, Polys1[StartPolyID][3].y, Polys1[StartPolyID][3].z, 255, 255, 255, 255)
		GRAPHICS.DRAW_LINE(Polys1[StartPolyID][1].x, Polys1[StartPolyID][1].y, Polys1[StartPolyID][1].z, Polys1[StartPolyID][3].x, Polys1[StartPolyID][3].y, Polys1[StartPolyID][3].z, 255, 255, 255, 255)
		Wait()
	end
	]]
	local Paths = AStarPathFind(StartPath, Pos, 1, nil, nil, nil, nil, nil)
	--for i = 1, 1000 do
	--	for k = 1, #Paths do
	--		GRAPHICS.DRAW_LINE(Polys1[Paths[k].PolyID][1].x, Polys1[Paths[k].PolyID][1].y, Polys1[Paths[k].PolyID][1].z, Polys1[Paths[k].PolyID][2].x, Polys1[Paths[k].PolyID][2].y, Polys1[Paths[k].PolyID][2].z, 255, 255, 255, 255)
	--		GRAPHICS.DRAW_LINE(Polys1[Paths[k].PolyID][2].x, Polys1[Paths[k].PolyID][2].y, Polys1[Paths[k].PolyID][2].z, Polys1[Paths[k].PolyID][3].x, Polys1[Paths[k].PolyID][3].y, Polys1[Paths[k].PolyID][3].z, 255, 255, 255, 255)
	--		GRAPHICS.DRAW_LINE(Polys1[Paths[k].PolyID][1].x, Polys1[Paths[k].PolyID][1].y, Polys1[Paths[k].PolyID][1].z, Polys1[Paths[k].PolyID][3].x, Polys1[Paths[k].PolyID][3].y, Polys1[Paths[k].PolyID][3].z, 255, 255, 255, 255)
	--	end
	--	Wait()
	--end
	local NewPaths = {}
	local Finished = false
	local Start = {x = Paths[1].x, y = Paths[1].y, z = Paths[1].z}
	local End = {x = Paths[#Paths].x, y = Paths[#Paths].y, z = Paths[#Paths].z}
	local Current = 1
	local CanReach = true
	local LastIndex = 1
	for i = 1, 1000 do
		if not Finished then
			local Reached = false
			for k = Current, #Paths do
				local Intersect1 = math.findIntersect(Polys1[Paths[k].PolyID][1].x, Polys1[Paths[k].PolyID][1].y, Polys1[Paths[k].PolyID][2].x, Polys1[Paths[k].PolyID][2].y, Start.x, Start.y, End.x, End.y, true, true)
				local Intersect2 = math.findIntersect(Polys1[Paths[k].PolyID][2].x, Polys1[Paths[k].PolyID][2].y, Polys1[Paths[k].PolyID][3].x, Polys1[Paths[k].PolyID][3].y, Start.x, Start.y, End.x, End.y, true, true)
				local Intersect3 = math.findIntersect(Polys1[Paths[k].PolyID][1].x, Polys1[Paths[k].PolyID][1].y, Polys1[Paths[k].PolyID][3].x, Polys1[Paths[k].PolyID][3].y, Start.x, Start.y, End.x, End.y, true, true)
				local Intersect = Intersect1 or Intersect2 or Intersect3
				LastIndex = k
				--Start = {x = Paths[k].x, y = Paths[k].y, z = Paths[k].z}
				if not Intersect then
					Current = k
					Start = {x = Paths[Current].x, y = Paths[Current].y, z = Paths[Current].z}
					--break
				else
					if k >= #Paths then
						--Current = k
						local Amount = #Paths - (Current)
						for j = 1, Amount do
							table.remove(Paths, #Paths)
						end
						Paths[#Paths+1] = {x = End.x, y = End.y, z = End.z}
						Finished = true
						break
					end
				end
			end
			if Current >= #Paths then
				Finished = true
			end
		end
		--if Finished then
			if CanReach then
				for k = 1, #Paths-1 do
					GRAPHICS.DRAW_LINE(Paths[k].x, Paths[k].y, Paths[k].z, Paths[k+1].x, Paths[k+1].y, Paths[k+1].z, 255, 255, 255, 255)
				end
				--GRAPHICS.DRAW_LINE(Start.x, Start.y, Start.z, End.x, End.y, End.z, 255, 255, 255, 255)
			end
		--end
		Wait()
	end
end)

local GameModesMenu = menu.list(menu.my_root(), "Game Modes", {}, "Start any game mode using AI.")
local Deathmatch = false
menu.toggle(GameModesMenu, "Deathmatch", {}, "", function(Toggle)
	Deathmatch = Toggle
	if not Deathmatch then
		for index, peds in pairs(entities.get_all_peds_as_handles()) do
			if DECORATOR.DECOR_EXIST_ON(peds, "Casino_Game_Info_Decorator") then
				RequestControlOfEntity(peds)
				local NetID = NETWORK.PED_TO_NET(peds)
				if NetID ~= 0 then
					NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(NetID, PLAYER.PLAYER_ID(), false)
				end
				entities.delete_by_handle(peds)
			end
		end
	end
	if Deathmatch then
		local AiTeam1Hash = joaat("rgFM_AiPed20000")
		local Peds = {}
		local HandlesT = {}
		while Deathmatch do
			if #Peds < 80 then
				if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_mission_controller")) > 0 then
					for i = 1, 80 do
						local NetID = memory.read_int(memory.script_local("fm_mission_controller", 22960+834+i))
						if NetID ~= 0 then
							local PedHandle = 0
							util.spoof_script("fm_mission_controller", function()
								PedHandle = NETWORK.NET_TO_PED(NetID)
							end)
							if PedHandle ~= 0 then
								if HandlesT[PedHandle] == nil then
									Peds[#Peds+1] = {}
									Peds[#Peds].Handle = PedHandle
									Peds[#Peds].TaskState = 0
									Peds[#Peds].Target = 0
									Peds[#Peds].TaskCoords = {x = 0.0, y = 0.0, z = 0.0}
									Peds[#Peds].TaskCoords2 = {x = 0.0, y = 0.0, z = 0.0}
									Peds[#Peds].Paths = nil
									Peds[#Peds].ActualPath = 1
									Peds[#Peds].SearchState = 0
									Peds[#Peds].SearchCalled = false
									Peds[#Peds].Start = nil
									Peds[#Peds].TargetPoly = nil
									Peds[#Peds].InsideStartPolygon = false
									Peds[#Peds].TargetInsideTargetPolygon = false
									Peds[#Peds].HasSetRel = false
									Peds[#Peds].TimeOut = 0
									Peds[#Peds].SearchLowLevel = 3+16
									Peds[#Peds].IsInVeh = false
									Peds[#Peds].VehHandle = 0
									Peds[#Peds].LastDistance = 0.0
									Peds[#Peds].SameDistanceTick = 0
									Peds[#Peds].StartPolysT = {}
									Peds[#Peds].TargetPolysT = {}
									Peds[#Peds].DrivingStyle = 0
									Peds[#Peds].NetID = NetID
									Peds[#Peds].IsZombie = false
									Peds[#Peds].JumpDelay = 0
									Peds[#Peds].StartIndexArg = nil
									Peds[#Peds].TargetIndexArg = nil
									Peds[#Peds].AddMode = false
									Peds[#Peds].HasChecked = false
									Peds[#Peds].LastPolyID = 0
									Peds[#Peds].OldPaths = {}
									PED.SET_PED_TARGET_LOSS_RESPONSE(PedHandle, 1)
									PED.SET_COMBAT_FLOAT(PedHandle, 2, 4000.0)
									PED.SET_PED_COMBAT_RANGE(PedHandle, 3)
									PED.SET_PED_FIRING_PATTERN(PedHandle, joaat("FIRING_PATTERN_FULL_AUTO"))
									if PED.GET_PED_RELATIONSHIP_GROUP_HASH(PedHandle) == AiTeam1Hash then
										ENTITY.SET_ENTITY_CAN_BE_DAMAGED_BY_RELATIONSHIP_GROUP(PedHandle, false, AiTeam1Hash)
									end
									HandlesT[PedHandle] = 0
								end
							end
						end
					end
				else
					for k = 1, #Peds do
						HandlesT[Peds[#Peds].Handle] = nil
						table.remove(Peds, #Peds)
					end
				end
			end
			for k = 1, #Peds do
				if Peds[k] ~= nil then
					if not ENTITY.IS_ENTITY_DEAD(Peds[k].Handle) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Handle) then
						if RequestControlOfEntity(Peds[k].Handle) then
							entities.set_can_migrate(Peds[k].Handle, false)
						end
						if Peds[k].JumpDelay <= 0 then
							if HitClimbableObject(Peds[k].Handle) then
								TASK.TASK_CLIMB(Peds[k].Handle, false)
								Peds[k].JumpDelay = 1000
							end
							if JumpPassThroughHole(Peds[k].Handle) then
								TASK.TASK_CLIMB(Peds[k].Handle, true)
								Peds[k].JumpDelay = 1000
							end
						else
							Peds[k].JumpDelay = Peds[k].JumpDelay - 1
						end
						if WEAPON.IS_PED_ARMED(Peds[k].Handle, 1) then
							Peds[k].IsZombie = true
							PED.SET_COMBAT_FLOAT(Peds[k].Handle, 7, 3.0)
							PED.SET_PED_RESET_FLAG(Peds[k].Handle, 306, true)
							PED.SET_PED_CONFIG_FLAG(Peds[k].Handle, 435, true)
						end
						if Peds[k].IsZombie then
							--PED.SET_PED_MOVE_RATE_OVERRIDE(Peds[k].Handle, 1.5)
							--PED.SET_AI_MELEE_WEAPON_DAMAGE_MODIFIER(100.0)
							PED.SET_PED_USING_ACTION_MODE(Peds[k].Handle, false, -1, 0)
							--PED.SET_PED_MIN_MOVE_BLEND_RATIO(Peds[k].Handle, 3.0)
							--PED.SET_PED_MAX_MOVE_BLEND_RATIO(Peds[k].Handle, 3.0)
						end
						--local LastEnt = ENTITY._GET_LAST_ENTITY_HIT_BY_ENTITY(Peds[k].Handle)
						--if LastEnt ~= 0 then
						--	if ENTITY.IS_ENTITY_A_PED(LastEnt) then
						--		if PED.GET_PED_RELATIONSHIP_GROUP_HASH(LastEnt) == PED.GET_PED_RELATIONSHIP_GROUP_HASH(Peds[k].Handle) then
						--			ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Peds[k].Handle, LastEnt, false)
						--		end
						--	end
						--end
						--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Peds[k].Handle, LastHandle, false)
						local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
						if not Peds[k].HasSetRel then
							if PED.DOES_RELATIONSHIP_GROUP_EXIST(AiTeam1Hash) then
								if RequestControlOfEntity(Peds[k].Handle) then
									--PED.SET_PED_RELATIONSHIP_GROUP_HASH(Peds[k].Handle, AiTeam1Hash)
									Peds[k].HasSetRel = true
								end
							end
						end
						if Peds[k].TaskState == 6 then
							--TASK.TASK_COMBAT_HATED_TARGETS_AROUND_PED(Peds[k].Handle, 1000.0, 16)
							local Target = PED.GET_PED_TARGET_FROM_COMBAT_PED(Peds[k].Handle, 0)
							if Target ~= 0 then
								Peds[k].Target = Target
								Peds[k].TaskState = 1
							end
						end
						if Peds[k].TaskState == 0 then
							--TASK.TASK_COMBAT_HATED_TARGETS_AROUND_PED(Peds[k].Handle, 1000.0, 16)
							local Target = PED.GET_PED_TARGET_FROM_COMBAT_PED(Peds[k].Handle, 0)
							if Target ~= 0 then
								Peds[k].Target = Target
								Peds[k].TaskState = 1
							end
						end
						if Peds[k].SearchState == 0 then
							if Peds[k].Target ~= 0 then
								local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
								local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
								Peds[k].SearchState = 1
								util.create_thread(function()
									local NewPaths = nil
									NewPaths, Peds[k].Start, Peds[k].TargetPoly, Peds[k].InsideStartPolygon, Peds[k].TargetInsideTargetPolygon, Nodes = AStarPathFind(Pos, TargetPos, Peds[k].SearchLowLevel, false, Peds[k].StartIndexArg, Peds[k].TargetIndexArg, false, false, nil, false, false)
									if NewPaths ~= nil then
										if Peds[k] ~= nil then
											if not Peds[k].AddMode then
												Peds[k].Paths = NewPaths
											else
												for i = 1, #NewPaths do
													table.insert(Peds[k].Paths, NewPaths[i])
												end
											end
											--Peds[k].SearchLowLevel = 1
											--Print("Found path")
											Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
											if Nodes ~= nil then
												Peds[k].ActualPath = AdjustTraveledPaths(Nodes, Polys1, Pos)--1
											else
												Peds[k].ActualPath = 1
											end
											--Print(Peds[k].ActualPath)
											Peds[k].TaskState = 1
											Peds[k].StartIndexArg = nil
											Peds[k].TargetIndexArg = nil
											Peds[k].AddMode = false
										end
										--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
									end
									
									Wait(1000)
									if Peds[k] ~= nil then
										Peds[k].SearchState = 2
										--Print("Reset")
									end
								end)
							end
						end
						local Polygons = {}
						if Peds[k].Target ~= 0 then
							if Peds[k].Paths ~= nil then
								local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
								local DistanceFinal = DistanceBetween(TargetPos.x, TargetPos.y, TargetPos.z, Peds[k].Paths[#Peds[k].Paths].x, Peds[k].Paths[#Peds[k].Paths].y, Peds[k].Paths[#Peds[k].Paths].z)
								if DistanceFinal > 30.0 then
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 4+16
									end
								end
								--if not Peds[k].HasChecked then
								--	if not InsidePolygon(Polys1[Peds[k].Paths[#Peds[k].Paths].PolyID], TargetPos) then
								--		if Peds[k].SearchState == 2 then
								--			Peds[k].SearchState = 0
								--			Peds[k].SearchLowLevel = 4
								--			Peds[k].StartIndexArg = Peds[k].Paths[#Peds[k].Paths].PolyID
								--			Peds[k].AddMode = true
								--			Peds[k].HasChecked = true
								--		end
								--	end
								--else
								--	if InsidePolygon(Polys1[Peds[k].Paths[#Peds[k].Paths].PolyID], TargetPos) then
								--		Peds[k].HasChecked = false
								--	end
								--end
							end
						end
						if Peds[k].TaskState == 1 then
							if Peds[k].Paths ~= nil then
								--if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_CLIMB")) == 7 then
								if not Peds[k].IsZombie then
									if RequestControlOfEntity(Peds[k].Handle) then
										--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										if Peds[k].ActualPath > #Peds[k].Paths then
											Peds[k].ActualPath = 1
											if Peds[k].SearchState == 2 then
												Peds[k].SearchState = 0
												Peds[k].SearchLowLevel = 3+16
											end
										end
										if Peds[k].Paths[Peds[k].ActualPath] ~= nil then
											local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
											local NewV3 = v3.new(Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
											local Sub = v3.sub(NewV3, Pos)
											local Rot = Sub:toRot()
											--ENTITY.SET_ENTITY_HEADING(Peds[k].Handle, Rot.z, 2)
											Dir = Rot:toDir()
											Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
											Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
											Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
											Peds[k].TaskCoords2.x = Peds[k].Paths[Peds[k].ActualPath].x + Dir.x * 2.0
											Peds[k].TaskCoords2.y = Peds[k].Paths[Peds[k].ActualPath].y + Dir.y * 2.0
											Peds[k].TaskCoords2.z = Peds[k].Paths[Peds[k].ActualPath].z + Dir.z * 2.0
											
											if ENTITY.HAS_ENTITY_CLEAR_LOS_TO_ENTITY(Peds[k].Handle, Peds[k].Target, 17) then
												TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, Peds[k].Target, 2.0, true, 0.1, 0.1, false, 0, true, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY")) ~= 7 then
													Peds[k].TaskState = 2
												end
											else
												TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 3.0, -1, 40000.0, 0.1)
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) ~= 7 then
													Peds[k].TaskState = 7
													--Print("Straight")
												end
											end
										end
									end
								else
									if not ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 5.5, 5.5, 2.5, false, true, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
											if Peds[k].ActualPath > #Peds[k].Paths then
												Peds[k].ActualPath = 1
												if Peds[k].SearchState == 2 then
													Peds[k].SearchState = 0
													Peds[k].SearchLowLevel = 3+16
												end
											end
											if Peds[k].Paths[Peds[k].ActualPath] ~= nil then
												local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
												local NewV3 = v3.new(Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
												local Sub = v3.sub(NewV3, Pos)
												local Rot = Sub:toRot()
												--ENTITY.SET_ENTITY_HEADING(Peds[k].Handle, Rot.z, 2)
												Dir = Rot:toDir()
												Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
												Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
												Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
												Peds[k].TaskCoords2.x = Peds[k].Paths[Peds[k].ActualPath].x + Dir.x * 2.0
												Peds[k].TaskCoords2.y = Peds[k].Paths[Peds[k].ActualPath].y + Dir.y * 2.0
												Peds[k].TaskCoords2.z = Peds[k].Paths[Peds[k].ActualPath].z + Dir.z * 2.0
												Peds[k].LastDistance = DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
												--TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, Peds[k].Target, 2.0, true, 0.1, 0.1, false, 0, true, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
												--TASK.TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, 3.0, -1, 40000.0, 0.1)
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) ~= 7 then
													Peds[k].TaskState = 3
													--Print("Straight")
												end
											end
										end
									else
										local HasSetTask = false
										local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
										local Distance3 = DistanceBetween(Pos.x, Pos.y, Pos.z, TargetPos.x, TargetPos.y, TargetPos.z)
										if Distance3 < 1.5 then
											if RequestControlOfEntity(Peds[k].Handle) then
												TASK.TASK_COMBAT_PED(Peds[k].Handle, Peds[k].Target, 201326592, 16)
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_COMBAT")) ~= 7 then
													--Print("Combat")
													Peds[k].TaskState = 4
												end
												HasSetTask = true
											end
										end
										if not HasSetTask then
											--if Distance3 < 1.5 then
												if ENTITY.HAS_ENTITY_CLEAR_LOS_TO_ENTITY(Peds[k].Handle, Peds[k].Target, 17) then
													if RequestControlOfEntity(Peds[k].Handle) then
														TASK.TASK_GO_STRAIGHT_TO_COORD_RELATIVE_TO_ENTITY(Peds[k].Handle, Peds[k].Target, 0.0, 0.0, 2.0, 3.0, -1)
														PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
														if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD_RELATIVE_TO_ENTITY")) ~= 7 then
															--Print("Combat")
															Peds[k].TaskState = 6
														end
													end
												else
													if RequestControlOfEntity(Peds[k].Handle) then
														if Peds[k].ActualPath > #Peds[k].Paths then
															Peds[k].ActualPath = 1
															if Peds[k].SearchState == 2 then
																Peds[k].SearchState = 0
																Peds[k].SearchLowLevel = 3+16
															end
														end
														if Peds[k].Paths[Peds[k].ActualPath] ~= nil then
															local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
															local NewV3 = v3.new(Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
															local Sub = v3.sub(NewV3, Pos)
															local Rot = Sub:toRot()
															Dir = Rot:toDir()
															Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
															Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
															Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
															Peds[k].TaskCoords2.x = Peds[k].Paths[Peds[k].ActualPath].x + Dir.x * 1.0
															Peds[k].TaskCoords2.y = Peds[k].Paths[Peds[k].ActualPath].y + Dir.y * 1.0
															Peds[k].TaskCoords2.z = Peds[k].Paths[Peds[k].ActualPath].z + Dir.z * 1.0
															Peds[k].LastDistance = DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
															--TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, Peds[k].Target, 2.0, true, 0.1, 0.1, false, 0, true, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
															--TASK.TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
															TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, 3.0, -1, 40000.0, 0.1)
															
															PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
															if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) ~= 7 then
																Peds[k].TaskState = 3
																--Print("Straight")
															end
														end
													end
												end
											--end
										end
									end
								end
							--end
							else
								if Peds[k].SearchState == 2 then
									Peds[k].SearchState = 0
									Peds[k].SearchLowLevel = 3+16
								end
							end
						end
						if Peds[k].TaskState == 2 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if Peds[k].Paths ~= nil then
									if Peds[k].SearchState == 2 then
										if Peds[k].TargetPoly ~= nil then
											local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
											if Peds[k].TargetInsideTargetPolygon then
												if not InsidePolygon(Polys1[Peds[k].TargetPoly], TargetPos) then
													--Peds[k].TaskState = 1
													if Peds[k].SearchState == 2 then
														Peds[k].SearchState = 0
														
													end
												end
											end
										else
											--Peds[k].SearchState = 0
										end
									end
									--if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.15, 0.15, 100.0, false, false, 0) then
									--	if Peds[k].SearchState == 2 then
									--		Peds[k].SearchState = 0
									--	end
									--end
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.5, 0.5, 1.0, false, false, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											Peds[k].ActualPath = Peds[k].ActualPath + 1
											if Peds[k].ActualPath > #Peds[k].Paths then
												Peds[k].ActualPath = 1
												if Peds[k].SearchState == 2 then
													Peds[k].SearchState = 0
													Peds[k].SearchLowLevel = 3+16
												end
											end
											Peds[k].TaskState = 1
										end
									else
										Peds[k].TimeOut = Peds[k].TimeOut + 1
										if Peds[k].TimeOut > 10000 then
											if Peds[k].SearchState == 2 then
												if RequestControlOfEntity(Peds[k].Handle) then
													PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
													TASK.CLEAR_PED_TASKS(Peds[k].Handle)
													Peds[k].SearchState = 0
													Peds[k].TaskState = 1
												end
											end
										end
									end
									if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY")) == 7 then
										Peds[k].TaskState = 1
										--Print("No action")
									end
								else
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 3+16
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
									Peds[k].ActualPath = 1
									Peds[k].SearchLowLevel = 3+16
								end
							end
						end
						GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z,
						Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 255, 255, 255, 255)
						if Peds[k].Paths ~= nil then
							for i = Peds[k].ActualPath, #Peds[k].Paths-1 do
								GRAPHICS.DRAW_LINE(Peds[k].Paths[i].x, Peds[k].Paths[i].y, Peds[k].Paths[i].z,
								Peds[k].Paths[i+1].x, Peds[k].Paths[i+1].y, Peds[k].Paths[i+1].z, 255, 255, 255, 255)
							end
						end
						if Peds[k].TaskState == 3 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								local Distance2 = DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
								Peds[k].SameDistanceTick = Peds[k].SameDistanceTick + 1
								local HasSet = false
								if Distance2 < Peds[k].LastDistance then
									Peds[k].LastDistance = Distance2
									Peds[k].SameDistanceTick = 0
								else
									if Peds[k].ActualPath < #Peds[k].Paths then
										if Peds[k].ActualPath == 1 then
											Peds[k].ActualPath = Peds[k].ActualPath + 1
											Peds[k].TaskState = 1
										end
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
										end
									end
								end
								--Distance2 > Peds[k].LastDistance then
								if Peds[k].SameDistanceTick > 50 or math.floor(Distance2) > math.floor(Peds[k].LastDistance) then
									--Peds[k].TaskState = 1
									--Peds[k].ActualPath = Peds[k].ActualPath + 1
									--if Peds[k].ActualPath > #Peds[k].Paths then
									--	Peds[k].ActualPath = 1
									--	if Peds[k].SearchState == 2 then
									--		Peds[k].SearchState = 0
									--	end
									--end
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 3+16
									end
								end
								if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) == 7 then
									if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_CLIMB")) == 7 then
										if RequestControlOfEntity(Peds[k].Handle) then
											Peds[k].TaskState = 1
											TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, 3.0, -1, 40000.0, 0.1)
										end
									end
								end
								if not HasSet then
									if ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 5.0, 5.0, 2.5, false, true, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											Peds[k].TaskState = 1
											--HasSet = true
											Peds[k].SameDistanceTick = 0
										end
									end
								end
								local R = 1.0
								local CurSpd = ENTITY.GET_ENTITY_SPEED(Peds[k].Handle)
								--R = R + CurSpd / 2
								--Print(R)
								if not HasSet then
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, R, R, 2.0, false, false, 0) or
									ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, R, R, 2.0, false, false, 0) then
										Peds[k].ActualPath = Peds[k].ActualPath + 1
										if Peds[k].ActualPath > #Peds[k].Paths then
											Peds[k].ActualPath = 1
											if Peds[k].SearchState == 2 then
												Peds[k].SearchState = 0
												Peds[k].SearchLowLevel = 3+16
											end
										end
										Peds[k].TaskState = 1
										Peds[k].SameDistanceTick = 0
									end
								end
							else
								Peds[k].TaskState = 0
								Peds[k].Target = 0
							end
						end
						if Peds[k].TaskState == 4 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if not ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 2.5, 2.5, 2.5, false, true, 0) then
									if RequestControlOfEntity(Peds[k].Handle) then
										PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										Peds[k].TaskState = 1
										
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
								end
							end
						end
						if Peds[k].TaskState == 5 then
							if not PED.IS_PED_CLIMBING(Peds[k].Handle) and not PED.IS_PED_JUMPING(Peds[k].Handle) then
								Peds[k].JumpDelay = Peds[k].JumpDelay - 1
								if Peds[k].JumpDelay <= 0 then
								--if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_CLIMB")) == 7 then
									Peds[k].ActualPath = Peds[k].ActualPath + 1
									if Peds[k].ActualPath > #Peds[k].Paths then
										Peds[k].ActualPath = 1
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
											Peds[k].SearchLowLevel = 3+16
										end
									end
									Peds[k].TaskState = 1
									Peds[k].SameDistanceTick = 0
								end
							end
						end
						if Peds[k].TaskState == 6 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 1.0, 1.0, 2.5, false, true, 0) then--or not CanIntersectEntity(Pos, ENTITY.GET_ENTITY_COORDS(Peds[k].Target, Peds[k].Paths, Peds[k].ActualPath)) then
									if RequestControlOfEntity(Peds[k].Handle) then
										PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										Peds[k].TaskState = 1
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
											Peds[k].SearchLowLevel = 3+16
										end
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
								end
							end
						end
						if Peds[k].TaskState == 7 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if Peds[k].Paths ~= nil then
									if Peds[k].SearchState == 2 then
										if Peds[k].TargetPoly ~= nil then
											local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
											if Peds[k].TargetInsideTargetPolygon then
												if not InsidePolygon(Polys1[Peds[k].TargetPoly], TargetPos) then
													--Peds[k].TaskState = 1
													if Peds[k].SearchState == 2 then
														Peds[k].SearchState = 0
													end
												end
											end
										else
											Peds[k].SearchState = 0
										end
									end
									--if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.15, 0.15, 100.0, false, false, 0) then
									--	if Peds[k].SearchState == 2 then
									--		Peds[k].SearchState = 0
									--	end
									--end
									if ENTITY.HAS_ENTITY_CLEAR_LOS_TO_ENTITY(Peds[k].Handle, Peds[k].Target, 17) then
										Peds[k].TaskState = 1
									end
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.5, 0.5, 1.0, false, false, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											Peds[k].ActualPath = Peds[k].ActualPath + 1
											if Peds[k].ActualPath > #Peds[k].Paths then
												Peds[k].ActualPath = 1
												Peds[k].SearchState = 0
												Peds[k].SearchLowLevel = 3+16
											end
											Peds[k].TaskState = 1
										end
									else
										Peds[k].TimeOut = Peds[k].TimeOut + 1
										if Peds[k].TimeOut > 10000 then
											if Peds[k].SearchState == 2 then
												if RequestControlOfEntity(Peds[k].Handle) then
													PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
													TASK.CLEAR_PED_TASKS(Peds[k].Handle)
													Peds[k].SearchState = 0
													Peds[k].TaskState = 1
												end
											end
										end
									end
									if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) == 7 then
										Peds[k].TaskState = 1
										--Print("No action")
									end
								else
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 3+16
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
									Peds[k].ActualPath = 1
									Peds[k].SearchLowLevel = 3+16
								end
							end
						end
					else
						--if RequestControlOfEntity(Peds[k].Handle) then
							--set_entity_as_no_longer_needed(Peds[k].Handle)
							HandlesT[Peds[k].Handle] = nil
							table.remove(Peds, k)
						--end
					end
				end
			end
			Wait()
		end
	end
end)

local RPGVSInsurgents = false
menu.toggle(GameModesMenu, "RPG VS Insurgents", {}, "", function(Toggle)
	RPGVSInsurgents = Toggle
	if not RPGVSInsurgents then
		for index, peds in pairs(entities.get_all_peds_as_handles()) do
			if DECORATOR.DECOR_EXIST_ON(peds, "Casino_Game_Info_Decorator") then
				RequestControlOfEntity(peds)
				local NetID = NETWORK.PED_TO_NET(peds)
				if NetID ~= 0 then
					NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(NetID, PLAYER.PLAYER_ID(), false)
				end
				entities.delete_by_handle(peds)
			end
		end
	end
	if RPGVSInsurgents then
		local MinOffset = -1.0
		local MaxOffset = 0.0
		local AiTeam1Hash = joaat("rgFM_AiPed20000")
		local AiTeam2Hash = joaat("rgFM_AiPed02000")
		local Peds = {}
		local HandlesT = {}
		local Team1Hash = joaat("rgFM_PlayerTeam0")
		while RPGVSInsurgents do
			if PED.DOES_RELATIONSHIP_GROUP_EXIST(AiTeam1Hash) and PED.DOES_RELATIONSHIP_GROUP_EXIST(AiTeam2Hash) then
				PED.SET_RELATIONSHIP_BETWEEN_GROUPS(5, AiTeam1Hash, AiTeam2Hash)
				PED.SET_RELATIONSHIP_BETWEEN_GROUPS(5, AiTeam2Hash, AiTeam1Hash)
			end
			if #Peds < 80 then
				--for index, peds in pairs(entities.get_all_peds_as_handles()) do
					--local EntScript = ENTITY.GET_ENTITY_SCRIPT(peds, 0)
					--if EntScript ~= nil then
						--if EntScript == "FM_Mission_Controller" then
				if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_mission_controller")) > 0 then
					
				else
					for k = 1, 50 do
						Peds[k] = nil
					end
				end
			end
			for k = 1, 50 do
				if Peds[k] == nil then
					local Addr = memory.script_local("fm_mission_controller", 22960+834+k)
					if Addr ~= 0 then
						local NetID = memory.read_int(Addr)
						if NetID ~= 0 then
							local PedHandle = 0
							util.spoof_script("fm_mission_controller", function()
								if NETWORK.NETWORK_GET_SCRIPT_STATUS() == 2 then
									PedHandle = NETWORK.NET_TO_PED(NetID)
								end
							end)
							if PedHandle ~= 0 then
								Peds[k] = {}
								Peds[k].Handle = PedHandle
								Peds[k].TaskState = 0
								Peds[k].Target = 0
								Peds[k].TaskCoords = {x = 0.0, y = 0.0, z = 0.0}
								Peds[k].TaskCoords2 = {x = 0.0, y = 0.0, z = 0.0}
								Peds[k].Paths = nil
								Peds[k].ActualPath = 1
								Peds[k].SearchState = 0
								Peds[k].SearchCalled = false
								Peds[k].Start = 1
								Peds[k].TargetPoly = 1
								Peds[k].InsideStartPolygon = false
								Peds[k].TargetInsideTargetPolygon = false
								Peds[k].HasSetRel = false
								Peds[k].TimeOut = 0
								Peds[k].SearchLowLevel = 1
								Peds[k].IsInVeh = false
								Peds[k].VehHandle = 0
								Peds[k].LastDistance = 0.0
								Peds[k].LastDistance2 = 0
								Peds[k].SameDistanceTick = 0
								Peds[k].StartPolysT = {}
								Peds[k].TargetPolysT = {}
								Peds[k].DrivingStyle = 0
								Peds[k].NetID = NetID
								Peds[k].TargetDelay = 0
								Peds[k].LastYOffset = 0
								PED.SET_PED_COMBAT_ATTRIBUTES(PedHandle, 3, false)
								PED.SET_PED_TARGET_LOSS_RESPONSE(PedHandle, 1)
								--WEAPON.SET_PED_INFINITE_AMMO_CLIP(PedHandle, true)
								PED.SET_COMBAT_FLOAT(PedHandle, 2, 4000.0)
								PED.SET_PED_COMBAT_RANGE(PedHandle, 3)
								PED.SET_PED_FIRING_PATTERN(PedHandle, joaat("FIRING_PATTERN_FULL_AUTO"))
								if PED.GET_RELATIONSHIP_BETWEEN_GROUPS(PED.GET_PED_RELATIONSHIP_GROUP_HASH(PedHandle), Team1Hash) == 1 then
								--if PED.GET_PED_RELATIONSHIP_GROUP_HASH(PedHandle) == AiTeam1Hash then
									ENTITY.SET_ENTITY_CAN_BE_DAMAGED_BY_RELATIONSHIP_GROUP(PedHandle, false, AiTeam1Hash)
									ENTITY.SET_ENTITY_CAN_BE_DAMAGED_BY_RELATIONSHIP_GROUP(PedHandle, false, Team1Hash)
									ENTITY.SET_ENTITY_PROOFS(PedHandle, true, true, true, false, false, false, true, false)
									--ENTITY.SET_ENTITY_MAX_HEALTH(PedHandle, 1100)
									--PED.SET_PED_MAX_HEALTH(PedHandle, 1100)
									--ENTITY.SET_ENTITY_HEALTH(PedHandle, 1100)
									--ENTITY.SET_ENTITY_CAN_BE_DAMAGED(PedHandle, false)
								end
							end
						end
					end
				end
				if Peds[k] ~= nil then
					if not ENTITY.IS_ENTITY_DEAD(Peds[k].Handle) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Handle) then
					--and SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_mission_controller")) > 0 then
						--util.spoof_script("fm_mission_controller", function()
						--	if NETWORK.NETWORK_REQUEST_CONTROL_OF_NETWORK_ID(Peds[k].NetID) then
						--		NETWORK.SET_NETWORK_ID_CAN_MIGRATE(Peds[k].NetID, true)
						--	end
						--end)
						if RequestControlOfEntity(Peds[k].Handle) then
							entities.set_can_migrate(Peds[k].Handle, false)
						--end
							if PED.GET_RELATIONSHIP_BETWEEN_GROUPS(PED.GET_PED_RELATIONSHIP_GROUP_HASH(Peds[k].Handle), Team1Hash) == 1 then
							--if PED.GET_PED_RELATIONSHIP_GROUP_HASH(Peds[k].Handle) == AiTeam1Hash then
								ENTITY.SET_ENTITY_CAN_BE_DAMAGED_BY_RELATIONSHIP_GROUP(Peds[k].Handle, false, AiTeam1Hash)
								ENTITY.SET_ENTITY_CAN_BE_DAMAGED_BY_RELATIONSHIP_GROUP(Peds[k].Handle, false, Team1Hash)
								--ENTITY.SET_ENTITY_PROOFS(Peds[k].Handle, true, true, true, false, true, true, true, true)
								ENTITY.SET_ENTITY_PROOFS(Peds[k].Handle, true, true, true, false, false, false, true, false)
								PED.SET_PED_COMBAT_ATTRIBUTES(Peds[k].Handle, 3, false)
								PED.SET_PED_TARGET_LOSS_RESPONSE(Peds[k].Handle, 1)
								WEAPON.SET_PED_INFINITE_AMMO_CLIP(Peds[k].Handle, true)
								PED.SET_COMBAT_FLOAT(Peds[k].Handle, 2, 4000.0)
								PED.SET_PED_COMBAT_RANGE(Peds[k].Handle, 3)
								PED.SET_PED_FIRING_PATTERN(Peds[k].Handle, joaat("FIRING_PATTERN_FULL_AUTO"))
								
								--ENTITY.SET_ENTITY_MAX_HEALTH(Peds[k].Handle, 1100)
								--PED.SET_PED_MAX_HEALTH(Peds[k].Handle, 1100)
								--ENTITY.SET_ENTITY_HEALTH(Peds[k].Handle, 1100)
								
								--ENTITY.SET_ENTITY_CAN_BE_DAMAGED(Peds[k].Handle, false)
							end
						end
						if PED.IS_PED_IN_ANY_VEHICLE(Peds[k].Handle, false) then
							Peds[k].IsInVeh = true
							Peds[k].VehHandle = PED.GET_VEHICLE_PED_IS_IN(Peds[k].Handle, false)
						else
							Peds[k].IsInVeh = false
							Peds[k].VehHandle = 0
						end
						if not Peds[k].HasSetRel then
							if PED.DOES_RELATIONSHIP_GROUP_EXIST(AiTeam1Hash) then
								if RequestControlOfEntity(Peds[k].Handle) then
									--PED.SET_PED_RELATIONSHIP_GROUP_HASH(Peds[k].Handle, AiTeam1Hash)
									Peds[k].HasSetRel = true
								end
							end
						end
						if not Peds[k].IsInVeh then
							if Peds[k].TaskState == 0 then
								--TASK.TASK_COMBAT_HATED_TARGETS_AROUND_PED(Peds[k].Handle, 1000.0, 16)
								local Target = PED.GET_PED_TARGET_FROM_COMBAT_PED(Peds[k].Handle, 0)
								--Print(Target)
								if Target ~= 0 then
									Peds[k].Target = Target
									Peds[k].TaskState = 1
								end
							end
							if Peds[k].Target ~= 0 then
								PED.SET_PED_MIN_MOVE_BLEND_RATIO(Peds[k].Handle, 3.0)
								PED.SET_PED_MAX_MOVE_BLEND_RATIO(Peds[k].Handle, 3.0)
							end
							if Peds[k].SearchState == 0 then
								if Peds[k].Target ~= 0 then
									--172.71616, -846.8681, 1005.89124
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, 172.71616, -846.8681, 1005.89124, 100.0, 100.0, 10.0, false, false, 0) then
										local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
										local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
										local Distance = DistanceBetween(Pos.x, Pos.y, Pos.z, TargetPos.x, TargetPos.y, TargetPos.z)
										local NewV3 = v3.new(TargetPos.x, TargetPos.y, TargetPos.z)
										local Sub = v3.sub(NewV3, Pos)
										local Rot = Sub:toRot()
										Dir = Rot:toDir()
										if Distance > 15.0 then
											TargetPos.x = Pos.x + Dir.x * 5.0
											TargetPos.y = Pos.y + Dir.y * 5.0
											TargetPos.z = Pos.z
										else
											TargetPos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Peds[k].Target, 5.0, 0.0, 0.0)
											--TargetPos.x = Pos.x - Dir.x * 5.0
											--TargetPos.y = Pos.y - Dir.y * 5.0
											--TargetPos.z = Pos.z
										end
										Peds[k].SearchState = 1
										util.create_thread(function()
											local NewPaths = nil
											NewPaths, Peds[k].Start, Peds[k].TargetPoly, Peds[k].InsideStartPolygon, Peds[k].TargetInsideTargetPolygon = AStarPathFind(Pos, TargetPos, Peds[k].SearchLowLevel, true, nil, nil, nil, nil, nil, true)
											if NewPaths ~= nil then
												if Peds[k] ~= nil then
													Peds[k].Paths = NewPaths
													Peds[k].SearchLowLevel = 1
													--Print("Found path")
													Peds[k].ActualPath = 1
													Peds[k].TaskState = 1
												end
												--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
											end
											Wait(1000)
											if Peds[k] ~= nil then
												if not Peds[k].IsInVeh then
													Peds[k].SearchState = 3
												end
												--Print("Reset")
											end
										end)
									end
								end
							end
							if Peds[k].SearchState == 3 then
								local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
								--local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
								--local Distance = DistanceBetween(Pos.x, Pos.y, Pos.z, )
								if Peds[k].Start ~= nil then

									
									if not InsidePolygon(Polys1[Peds[k].Start], Pos) then
										Peds[k].SearchState = 2
									end
								else
									Peds[k].SearchState = 2
								end
							end
							if Peds[k].TaskState == 1 then
								if Peds[k].Paths ~= nil then
									if RequestControlOfEntity(Peds[k].Handle) then
										--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										if Peds[k].ActualPath > #Peds[k].Paths then
											Peds[k].ActualPath = 1
										end
										if Peds[k].Paths[Peds[k].ActualPath] ~= nil then
											Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
											Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
											Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
											TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, Peds[k].Target, 2.0, true, 0.1, 0.1, false, 0, false, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
											PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
											if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY")) ~= 7 then
												Peds[k].TaskState = 2
											end
											if not Shoot then
												--WEAPON.MAKE_PED_RELOAD(Peds[k].Handle)
												--WEAPON.SET_AMMO_IN_CLIP(Peds[k].Handle, joaat("weapon_rpg"), 1)
												--WEAPON.REFILL_AMMO_INSTANTLY(Peds[k].Handle)
											end
										end
									end
								else
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
									end
								end
							end
							if Peds[k].TaskState == 2 then
								if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
									if Peds[k].Paths ~= nil then
										if Peds[k].SearchState == 2 then
											--if Peds[k].TargetPoly ~= nil then
											--	local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
											--	if Peds[k].TargetInsideTargetPolygon then
											--		if not InsidePolygon(Polys1[Peds[k].TargetPoly], TargetPos) then
											--			--Peds[k].TaskState = 1
											--			Peds[k].SearchState = 0
											--		end
											--	else
											--		if InsidePolygon(Polys1[Peds[k].TargetPoly], TargetPos) then
											--			--Peds[k].TaskState = 1
											--			Peds[k].SearchState = 0
											--		end
											--	end
											--else
											--	Peds[k].SearchState = 0
											--end
										end
										if not ENTITY.HAS_ENTITY_CLEAR_LOS_TO_ENTITY(Peds[k].Handle, Peds[k].Target, 17) then
											if RequestControlOfEntity(Peds[k].Handle) then
												Peds[k].TaskState = 0
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
												TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											end
										end
										if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.15, 0.15, 100.0, false, false, 0) then
											if Peds[k].SearchState == 2 then
												Peds[k].SearchState = 0
											end
										end
										if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.5, 0.5, 1.0, false, true, 0) then
											if RequestControlOfEntity(Peds[k].Handle) then
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
												TASK.CLEAR_PED_TASKS(Peds[k].Handle)
												Peds[k].ActualPath = Peds[k].ActualPath + 1
												if Peds[k].ActualPath > #Peds[k].Paths then
													Peds[k].ActualPath = 1
													if Peds[k].SearchState == 2 then
														Peds[k].SearchState = 0
													end
												end
												Peds[k].TaskState = 1
											end
										else
											Peds[k].TimeOut = Peds[k].TimeOut + 1
											if Peds[k].TimeOut > 1000 then
												if Peds[k].SearchState == 2 then
													if RequestControlOfEntity(Peds[k].Handle) then
														PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
														TASK.CLEAR_PED_TASKS(Peds[k].Handle)
														Peds[k].SearchState = 0
														Peds[k].TaskState = 1
													end
												end
											end
										end
										if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY")) == 7 then
											Peds[k].TaskState = 1
											--Print("No action")
										end
									else
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
										end
									end
								else
									if RequestControlOfEntity(Peds[k].Handle) then
										PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										Peds[k].TaskState = 0
										Peds[k].Target = 0
										Peds[k].ActualPath = 1
										Peds[k].SearchLowLevel = 2
									end
								end
							end
						else
							if Peds[k].VehHandle ~= 0 then
								if RequestControlOfEntity(Peds[k].VehHandle) then
									entities.set_can_migrate(Peds[k].VehHandle, false)
								end
								local Rot = ENTITY.GET_ENTITY_ROTATION(Peds[k].VehHandle, 2)
								--VEHICLE.SET_DISABLE_VEHICLE_ENGINE_FIRES(Peds[k].VehHandle, true)
								if Rot.y > 150.0 or Rot.y < -150.0 then
									if RequestControlOfEntity(Peds[k].VehHandle) then
										ENTITY.SET_ENTITY_ROTATION(Peds[k].VehHandle, Rot.x, 0.0, Rot.z, 2)
									end
								end
								if Peds[k].TaskState == 6 then
									local Target = PED.GET_PED_TARGET_FROM_COMBAT_PED(Peds[k].Handle, 0)
									if Target ~= 0 then
										Peds[k].Target = Target
										Peds[k].TaskState = 1
									else
										Peds[k].TargetDelay = Peds[k].TargetDelay + 1
										if Peds[k].TargetDelay > 10 then
											Peds[k].TaskState = 0
											Peds[k].TargetDelay = 0
										end
									end
								end
								if Peds[k].TaskState == 0 then
									--TASK.TASK_COMBAT_HATED_TARGETS_AROUND_PED(Peds[k].Handle, 1000.0, 16)
									TASK.TASK_COMBAT_HATED_TARGETS_IN_AREA(Peds[k].Handle, 172.53906, -847.31964, 1005.8912, 1000.0, 16)
									Peds[k].TaskState = 6
								end
								if Peds[k].SearchState == 0 then
									if Peds[k].Target ~= 0 then
										local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
										local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
										Peds[k].SearchState = 1
										util.create_thread(function()
											local NewPaths = nil
											NewPaths, Peds[k].Start, Peds[k].TargetPoly, Peds[k].InsideStartPolygon, Peds[k].TargetInsideTargetPolygon = AStarPathFind(Pos, TargetPos, Peds[k].SearchLowLevel, false, nil, nil, false, nil, false, true, true, 1)
											if NewPaths ~= nil then
												if Peds[k] ~= nil then
													Peds[k].Paths = NewPaths
													Peds[k].SearchLowLevel = 1
													--Print("Found path")
													Peds[k].ActualPath = 1
													Peds[k].TaskState = 1
													Peds[k].SameDistanceTick = 0
												end
												--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
											end
											Wait(1000)
											if Peds[k] ~= nil then
												Peds[k].SearchState = 2
												--Print("Reset")
											end
										end)
									end
								end
								local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
								if Peds[k].Target ~= 0 then
									if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then

									else
										if RequestControlOfEntity(Peds[k].Handle) then
											Peds[k].Target = 0
											Peds[k].TaskState = 0
											TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										end
									end
								end
								if Peds[k].TaskState == 1 then
									if Peds[k].Paths ~= nil then
										if Peds[k].ActualPath > #Peds[k].Paths then
											Peds[k].ActualPath = 1
										end
										Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
										Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
										Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
										--Print("Called Go")
										if not ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 1.0, 1.0, 1.0, false, true, 0) then
											if RequestControlOfEntity(Peds[k].Handle) then
												local Offset = ENTITY.GET_OFFSET_FROM_ENTITY_GIVEN_WORLD_COORDS(Peds[k].VehHandle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
												local Bits = 16777216
												if Peds[k].LastYOffset == 0 then
													if Offset.y < MinOffset then
														Bits = 16777216 + 1024
														Peds[k].LastYOffset = 1
													else
														Peds[k].LastYOffset = 2
													end
												end
												if Peds[k].LastYOffset == 3 then
													Bits = 16777216 + 1024
												end
												TASK.TASK_VEHICLE_DRIVE_TO_COORD(Peds[k].Handle, Peds[k].VehHandle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 350.0, 0, ENTITY.GET_ENTITY_MODEL(Peds[k].VehHandle), Bits, 0.0, 40000.0)
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_VEHICLE_DRIVE_TO_COORD")) ~= 7 then
													Peds[k].TaskState = 2
													Peds[k].LastDistance2 = math.floor(DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z))
												end
											end
										else
											Peds[k].TaskState = 2
										end
									else
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
										end
										Peds[k].SearchLowLevel = 1
									end
								end
								GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z,
								Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 255, 255, 255, 255)
								if Peds[k].TaskState == 2 then
									local Distance2 = DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
									if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_VEHICLE_DRIVE_TO_COORD")) == 7 then
										if RequestControlOfEntity(Peds[k].Handle) then
											Peds[k].TaskState = 1
											--Print("No action")
											TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										end
									end
									local FVect = ENTITY.GET_ENTITY_FORWARD_VECTOR(Peds[k].VehHandle)
									local VPos = ENTITY.GET_ENTITY_COORDS(Peds[k].VehHandle)
									local AdjustedVect = {
										x = VPos.x + FVect.x * 5.0,
										y = VPos.y + FVect.y * 5.0,
										z = VPos.z + FVect.z * 5.0
									}
									local Offset = ENTITY.GET_OFFSET_FROM_ENTITY_GIVEN_WORLD_COORDS(Peds[k].VehHandle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z) 
									--Print(Peds[k].LastDistance)
									Peds[k].SameDistanceTick = Peds[k].SameDistanceTick + 1
									--if Distance2 < Peds[k].LastDistance then
									if math.floor(Distance2) < Peds[k].LastDistance2 then
										Peds[k].LastDistance2 = math.floor(Distance2)
										Peds[k].SameDistanceTick = 0
									end
									if Peds[k].LastOffsetDelay == nil then
										Peds[k].LastOffsetDelay = 0
									end
									--if Distance2 > Peds[k].LastDistance then
									--Print(Peds[k].SameDistanceTick)
									if Peds[k].LastOffsetDelay <= 0 then
										if Peds[k].LastYOffset ~= 0 then
											if Peds[k].LastYOffset == 1 then
												if Offset.y > MaxOffset then
													Peds[k].TaskState = 1
													Peds[k].LastYOffset = 0
													Peds[k].LastOffsetDelay = 500
												end
											end
											if Peds[k].LastYOffset == 2 then
												if Offset.y < MinOffset then
													Peds[k].TaskState = 1
													Peds[k].LastYOffset = 0
													Peds[k].LastOffsetDelay = 500
												end
											end
										end
									else
										Peds[k].LastOffsetDelay = Peds[k].LastOffsetDelay - 1
									end
									if Peds[k].SameDistanceTick > 50 then
									 	if Peds[k].LastYOffset == 2 then
											Peds[k].LastYOffset = 3
										else
											if Peds[k].LastYOffset == 3 then
												Peds[k].LastYOffset = 4
											else
												if Peds[k].LastYOffset == 4 then
													Peds[k].LastYOffset = 0
												end
											end
										end
										Peds[k].TaskState = 1
										--Peds[k].ActualPath = 1
										Peds[k].SearchCalled = true
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
										end
										Peds[k].SearchLowLevel = 1
										--Peds[k].SameDistanceTick = 0
									end
									if Peds[k].SameDistanceTick > 200 then
										--Print("Called")
										--local Vel = ENTITY.GET_ENTITY_VELOCITY(Peds[k].VehHandle)
										--ENTITY.SET_ENTITY_VELOCITY(Peds[k].VehHandle, Vel.x - FVect.x * 35.0, Vel.y - FVect.y * 35.0, Vel.z)
										Peds[k].SameDistanceTick = 0
										Peds[k].TaskState = 1
										Peds[k].ActualPath = 1
										Peds[k].SearchCalled = true
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
										end
										Peds[k].SearchLowLevel = 1
									end
									if Peds[k].SearchCalled then
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
											Peds[k].SearchCalled = false
											--Peds[k].SameDistanceTick = 0
											--Print("Called")
										end
									end
									--if DidHit then
									--	local Vel = ENTITY.GET_ENTITY_VELOCITY(Peds[k].VehHandle)
									--	ENTITY.SET_ENTITY_VELOCITY(Peds[k].VehHandle, Vel.x - FVect.x * 5.0, Vel.y - FVect.y * 5.0, Vel.z)
									--end
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 5.5, 5.5, 5.5, false, false, 0) then
										Peds[k].TaskState = 1
										Peds[k].ActualPath = Peds[k].ActualPath + 1
										Peds[k].DrivingStyle = 1
										Peds[k].SameDistanceTick = 0
										if Peds[k].ActualPath > #Peds[k].Paths then
											if Peds[k].SearchState == 2 then
												Peds[k].SearchState = 0
											end
											Peds[k].ActualPath = 1
											Peds[k].SearchLowLevel = 1
										end
									end
								end
							end
						end
					else
						--if RequestControlOfEntity(Peds[k].Handle) then
							--set_entity_as_no_longer_needed(Peds[k].Handle)
							--HandlesT[Peds[k].Handle] = nil
							--table.remove(Peds, k)
						--end
					end
				end
			end
			Wait()
		end
	end
end)

local CargobobRiders = false
local BobHandle = 0
menu.toggle(GameModesMenu, "Cargobob Riders", {}, "", function(Toggle)
	CargobobRiders = Toggle
	if not CargobobRiders then
		entities.delete_by_handle(BobHandle)
	end
	if CargobobRiders then
		local IsATest = false
		local Vehs = {}
		local HandlesT = {}
		local AddrNum = 22942+834+81
		local RotSpd = 0.0115
		local HSpeed = 5.0
		local Speed = 20.0
		local Max = 2
		if IsATest then
			if not STREAMING.HAS_MODEL_LOADED(joaat("cargobob2")) then
				STREAMING.REQUEST_MODEL(joaat("cargobob2"))
			end
			while not STREAMING.HAS_MODEL_LOADED(joaat("cargobob2")) do
				Wait()
			end
			local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			BobHandle = VEHICLE.CREATE_VEHICLE(joaat("cargobob2"), PlayerPos.x, PlayerPos.y, PlayerPos.z, 0.0, true, true, false)
			STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat("cargobob2"))
			Vehs[#Vehs+1] = {}
			Vehs[#Vehs].Handle = BobHandle
			Vehs[#Vehs].Paths = nil
			Vehs[#Vehs].TaskState = 0
			Vehs[#Vehs].SearchState = 0
			Vehs[#Vehs].ActualPath = 1
			Vehs[#Vehs].Radius = 4.0
			Vehs[#Vehs].Tick = 0
			Vehs[#Vehs].Acceleration = 0.0
			Vehs[#Vehs].AccelerationH = 0.0
			PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), BobHandle, -1)
			VEHICLE.SET_VEHICLE_DOOR_OPEN(BobHandle, 2, false, true)
			Wait(10000)
		end
		while CargobobRiders do
			if #Vehs < Max then
				if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_mission_controller")) > 0 then
					for i = 1, Max do
						local NetID = memory.read_int(memory.script_local("fm_mission_controller", AddrNum+i))
						if NetID ~= 0 then
							local VehHandle = 0
							util.spoof_script("fm_mission_controller", function()
								VehHandle = NETWORK.NET_TO_PED(NetID)
							end)
							if VehHandle ~= 0 then
								if HandlesT[VehHandle] == nil then
									Vehs[#Vehs+1] = {}
									Vehs[#Vehs].Handle = VehHandle
									Vehs[#Vehs].Paths = nil
									Vehs[#Vehs].TaskState = 0
									Vehs[#Vehs].SearchState = 0
									Vehs[#Vehs].ActualPath = 1
									Vehs[#Vehs].Radius = 4.0
									Vehs[#Vehs].Tick = 0
									Vehs[#Vehs].Acceleration = 0.0
									Vehs[#Vehs].AccelerationH = 0.0
									Vehs[#Vehs].SpeedState = 0
									HandlesT[VehHandle] = 0
								end
							end
						end
					end
				else
					for k = 1, #Vehs do
						HandlesT[Vehs[#Vehs].Handle] = nil
						table.remove(Vehs, #Vehs)
					end
				end
			end
			local IsControlOn = PLAYER.IS_PLAYER_CONTROL_ON(PLAYER.PLAYER_ID())
			if IsControlOn then
				for i = 1, #Vehs do
					if Vehs[i] ~= nil then
						if ENTITY.DOES_ENTITY_EXIST(Vehs[i].Handle) then
							if RequestControlOfEntity(Vehs[i].Handle) then
								entities.set_can_migrate(Vehs[i].Handle, false)
								VEHICLE.SET_DOOR_ALLOWED_TO_BE_BROKEN_OFF(Vehs[i].Handle, 2, false)
								VEHICLE.SET_VEHICLE_DOOR_CONTROL(Vehs[i].Handle, 2, 360.0, 180.0)
							end
							if Vehs[i].TaskState == 0 then
								if Vehs[i].SearchState == 2 then
									Vehs[i].SearchState = 0
								end
							end
							if Vehs[i].SearchState == 0 then
								local Pos = ENTITY.GET_ENTITY_COORDS(Vehs[i].Handle)
								local TargetPos = ENTITY.GET_ENTITY_COORDS(Vehs[1].Handle)
								Vehs[i].SearchState = 1
								util.create_thread(function()
									local NewPaths = nil
									if i == 1 then
										NewPaths = AStarPathFind(Pos, TargetPos, 1, true, nil, math.random(#Polys1))
									end
									if i == 2 then
										NewPaths = AStarPathFind(Pos, TargetPos, 1, true, nil, nil)
									end
									if NewPaths ~= nil then
										if Vehs[i] ~= nil then
											Vehs[i].Paths = NewPaths
											Vehs[i].ActualPath = 1
											Vehs[i].TaskState = 1
										end
									end
									Wait(1000)
									if Vehs[i] ~= nil then
										Vehs[i].SearchState = 2
									end
								end)
							end
							if Vehs[i].TaskState == 1 then
								local Pos = ENTITY.GET_ENTITY_COORDS(Vehs[i].Handle)
								local VRot = ENTITY.GET_ENTITY_ROTATION(Vehs[i].Handle, 5)
								local TaskCoords = Vehs[i].Paths[Vehs[i].ActualPath]
								local Sub = {
									x = TaskCoords.x - Pos.x,
									y = TaskCoords.y - Pos.y,
									z = TaskCoords.z - Pos.z
								}
								local NewV3 = v3.new(Sub.x, Sub.y, Sub.z)
								NewV3:normalise()
								local NewV3_1 = v3.new(TaskCoords.x, TaskCoords.y, TaskCoords.z)
								local Rot = v3.lookAt(Pos, NewV3_1)
								local Dir = v3.new(Rot)
								local Normal = Dir:normalise()
								local AdjustedX = 0.0 - VRot.x
								AdjustedX = (AdjustedX + 180) % 360 - 180
								local AdjustedY = 0.0 - VRot.y
								AdjustedY = (AdjustedY + 180) % 360 - 180
								local AdjustedZ = Rot.z - VRot.z
								AdjustedZ = (AdjustedZ + 180) % 360 - 180
								if i == 2 then
									AdjustedX = 0.0 - VRot.x
									AdjustedX = (AdjustedX + 180) % 360 - 180
									AdjustedY = 0.0 - VRot.y
									AdjustedY = (AdjustedY + 180) % 360 - 180
									AdjustedZ = (Rot.z + 180) - VRot.z
									AdjustedZ = (AdjustedZ + 180) % 360 - 180
								end
								if Vehs[i].SpeedState == 1 then
									if Vehs[i].Acceleration > 1.0 then
										Vehs[i].Acceleration = Vehs[i].Acceleration - 0.1
									else
										Vehs[i].SpeedState = 0
									end
									if Vehs[i].AccelerationH > 1.0 then
										Vehs[i].AccelerationH = Vehs[i].AccelerationH - 0.1
									end
								end
								if Vehs[i].SpeedState == 0 then
									if Vehs[i].Acceleration < Speed then
										Vehs[i].Acceleration = Vehs[i].Acceleration + 0.1
									end
									if Vehs[i].AccelerationH < HSpeed then
										Vehs[i].AccelerationH = Vehs[i].AccelerationH + 0.1
									end
								end
								ENTITY.SET_ENTITY_VELOCITY(Vehs[i].Handle, NewV3.x * Vehs[i].Acceleration, NewV3.y * Vehs[i].Acceleration, NewV3.z * Vehs[i].AccelerationH)
								--ENTITY.SET_ENTITY_VELOCITY(Vehs[i].Handle, NewV3.x * Speed, NewV3.y * Speed, NewV3.z * HSpeed)
								ENTITY.SET_ENTITY_ANGULAR_VELOCITY(Vehs[i].Handle, AdjustedX * RotSpd, AdjustedY * RotSpd, AdjustedZ * RotSpd)
								--ENTITY.SET_ENTITY_ANGULAR_VELOCITY(Vehs[i].Handle, Normal.x * RotSpd, Normal.y * RotSpd, Normal.z * RotSpd)
								--if ShapeTestNav(Vehs[i].Handle, Pos, TaskCoords, 2) then
								if MISC.IS_POSITION_OCCUPIED(Pos.x, Pos.y, Pos.z, Vehs[i].Radius, false, true, false, false, false, Vehs[i].Handle, false) then
									--local FVect, RVect, UpVect, Vect = v3.new(), v3.new(), v3.new(), v3.new()
									--local FVect = ENTITY.GET_ENTITY_FORWARD_VECTOR(Vehs[i].Handle)
									--ENTITY.GET_ENTITY_MATRIX(Vehs[i].Handle, FVect, RVect, UpVect, Vect)
									ENTITY.SET_ENTITY_VELOCITY(Vehs[i].Handle, -NewV3.x * Vehs[i].Acceleration, -NewV3.y * Vehs[i].Acceleration, NewV3.z * Vehs[i].AccelerationH)
									--ENTITY.SET_ENTITY_VELOCITY(Vehs[i].Handle, -FVect.x * Speed, -FVect.y * Speed, FVect.z * HSpeed)
									Vehs[i].Radius = 12.0
									Vehs[i].Tick = Vehs[i].Tick + 1
									if Vehs[i].Tick > 100 then
										Vehs[i].Tick = 0
										Vehs[i].Radius = 2.0
										if Vehs[i].ActualPath > 1 then
											Vehs[i].ActualPath = Vehs[i].ActualPath - 1
										end
									end
								else
									Vehs[i].Radius = 4.0
									--Vehs[i].Tick = 0
								end
								if ENTITY.IS_ENTITY_AT_COORD(Vehs[i].Handle, TaskCoords.x, TaskCoords.y, TaskCoords.z, 0.5, 0.5, 5.0, false, true, 0) then
									Vehs[i].ActualPath = Vehs[i].ActualPath + 1
									if Vehs[i].ActualPath > #Vehs[i].Paths then
										Vehs[i].TaskState = 0
										if Vehs[i].SearchState == 2 then
											Vehs[i].SearchState = 0
										end
									end
									Vehs[i].SpeedState = 1
									--Vehs[i].Acceleration = 0.0
									--Vehs[i].AccelerationH = 0.0
								end
							end
						else
							HandlesT[Vehs[i].Handle] = nil
							table.remove(Vehs, i)
						end
					end
				end
			end
			Wait()
		end
	end
end)

function SetPedCombatAbilities(ped)
	PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
	PED.SET_PED_COMBAT_ATTRIBUTES(ped, 1, true)
	PED.SET_PED_COMBAT_ATTRIBUTES(ped, 3, true)
	PED.SET_PED_COMBAT_ATTRIBUTES(ped, 13, true)
	PED.SET_PED_COMBAT_ATTRIBUTES(ped, 21, true)
	PED.SET_PED_COMBAT_ATTRIBUTES(ped, 38, true)
	PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
	PED.SET_PED_COMBAT_ATTRIBUTES(ped, 443, true)
	PED.SET_PED_COMBAT_MOVEMENT(ped, 2)
	PED.SET_PED_COMBAT_ABILITY(ped, 2) 
	PED.SET_PED_COMBAT_RANGE(ped, 2)
	PED.SET_PED_SEEING_RANGE(ped, 900.0)
	PED.SET_PED_TARGET_LOSS_RESPONSE(ped, 1)
	PED.SET_PED_HIGHLY_PERCEPTIVE(ped, true)
	PED.SET_PED_VISUAL_FIELD_PERIPHERAL_RANGE(ped, 400.0)
	PED.SET_COMBAT_FLOAT(ped, 10, 400.0)
end

function set_entity_as_no_longer_needed(entity)
	local pHandle = memory.alloc_int()
	memory.write_int(pHandle, entity)
	ENTITY.SET_ENTITY_AS_NO_LONGER_NEEDED(pHandle)
end

function CopyPolygonsData(PolygonsT)
	local NewData = {}
	for k = 1, #PolygonsT do
		NewData[k] = {}
		NewData[k].ID = PolygonsT[k].ID
		NewData[k].Parent = PolygonsT[k].Parent
		NewData[k].Closed = false
		NewData[k].Center = PolygonsT[k].Center
		NewData[k].Vertex1 = PolygonsT[k][1]
		NewData[k].Vertex2 = PolygonsT[k][2]
		NewData[k].Vertex3 = PolygonsT[k][3]
		NewData[k].Neighboors = {}
		for i = 1, #PolygonsT[k].Neighboors do
			NewData[k].Neighboors[#NewData[k].Neighboors+1] = PolygonsT[k].Neighboors[i]
		end
	end
	return NewData
end

function AStarPathFind(Start, Target, LowPriorityLevel, PolygonsOnly, CustomPolygons, CachedTargetIndex, IncludePoints, IncludeStartNode, IncludePoints2, Funnel, PreferCenter, Flags)
	local StartIndex = 0
	local TargetIndex = 0
	local FinalNode = true
	local Include = false
	local StartNode = true
	local IncludePointsNodes = false
	local CenterOnly = false
	local Bits = 0
	local PolysT = Polys1
	if CustomPolygons ~= nil then
		PolysT = CustomPolygons
	end
	if PreferCenter ~= nil then
		CenterOnly = PreferCenter
	end
	if IncludePoints ~= nil then
		Include = IncludePoints
	end
	if IncludeStartNode ~= nil then
		StartNode = IncludeStartNode
	end
	if PolygonsOnly ~= nil then
		FinalNode = PolygonsOnly
	end
	if IncludePoints2 ~= nil then
		IncludePointsNodes = IncludePoints2
	end
	if Flags ~= nil then
		Bits = Flags
	end
	if StartIndex == 0 then
		if GridStartType == 0 then
			StartIndex = consultarGridEstatico(Grid, Start.x, Start.y, GlobalCellSize)
		elseif GridStartType == 1 then
			StartIndex = buscarPoligonoPorCoordenada(Start.x, Start.y, Start.z, GridSizeIteration)
		end
		--consultarGridComOrigem(Grid, Start.x, Start.y, Start.z, Polys1Center.x, Polys1Center.y, Polys1Center.z, 5.0)
		--
		if StartIndex == nil then
			StartIndex = encontrarPoligonoDoPonto(Start, PolysT, 2.0)
			if StartIndex == nil then
				StartIndex = GetClosestPolygon(PolysT, Start, Include, LowPriorityLevel, Bits)
			end
		else
			local PolysIt = GetPolygonsFromGrid(StartIndex)
			StartIndex = encontrarPoligonoDoPonto(Start, PolysIt, 2.0)
			if StartIndex == nil then
				StartIndex = GetClosestPolygon(PolysIt, Start, Include, LowPriorityLevel, Bits)
				--Print("StartIndex Is Nil "..StartIndex)
			else
				--Print("StartIndex Is "..StartIndex)
			end
		end
	end
	if TargetIndex == 0 then
		if GridStartType == 0 then
			TargetIndex = consultarGridEstatico(Grid, Target.x, Target.y, GlobalCellSize)
		elseif GridStartType == 1 then
			TargetIndex = buscarPoligonoPorCoordenada(Target.x, Target.y, Target.z, GridSizeIteration)
		end
		--consultarGridComOrigem(Grid, Target.x, Target.y, Target.z, Polys1Center.x, Polys1Center.y, Polys1Center.z, 5.0)
		--
		if TargetIndex == nil then
			TargetIndex = encontrarPoligonoDoPonto(Target, PolysT, 1.0)
			if TargetIndex == nil then
				TargetIndex = GetClosestPolygon(PolysT, Target, Include, LowPriorityLevel, Bits)
			end
		else
			local PolysIt = GetPolygonsFromGrid(TargetIndex)
			TargetIndex = encontrarPoligonoDoPonto(Target, PolysIt, 1.0)
			if TargetIndex == nil then
				TargetIndex = GetClosestPolygon(PolysIt, Target, Include, LowPriorityLevel, Bits)
			end
		end
	end
	if StartIndex == 0 or TargetIndex == 0 then
		return nil
	end
	local InsideStartPolygon = InsidePolygon(PolysT[StartIndex], Start)
	local TargetInsideTargetPolygon = InsidePolygon(PolysT[TargetIndex], Target)
	if StartIndex == TargetIndex then
		if not FinalNode then
			return {{x = Target.x, y = Target.y, z = Target.z, NodeFlags = 0, PolyID = TargetIndex}}, StartIndex, TargetIndex, InsideStartPolygon, TargetInsideTargetPolygon
		else
			local CoordsT = {}
			for a = 1, #PolysT[TargetIndex] do
				CoordsT[#CoordsT+1] = PolysT[TargetIndex][a]
			end
			CoordsT[#CoordsT+1] = PolysT[TargetIndex].Center
			local ClosestPoint = closest_point_on_polygon(PolysT[TargetIndex], Target)
			CoordsT[#CoordsT+1] = ClosestPoint

			if IncludePointsNodes then
				for j = 1, #PolysT[TargetIndex].LocalPoints do
					CoordsT[#CoordsT+1] = PolysT[TargetIndex].LocalPoints[j]
				end
			end
			local Dist = 10000.0
			local SelectedVector = CoordsT[4]
			for j = 1, #CoordsT do
				local Distance = DistanceBetween(CoordsT[j].x, CoordsT[j].y, CoordsT[j].z, Target.x, Target.y, Target.z)
				if Distance < Dist then
					Dist = Distance
					SelectedVector = CoordsT[j]
				end
			end
			return {{x = SelectedVector.x, y = SelectedVector.y, z = SelectedVector.z, NodeFlags = 0, PolyID = TargetIndex}}, StartIndex, TargetIndex, InsideStartPolygon, TargetInsideTargetPolygon
		end
	end
	local Nodes = a_star(StartIndex, TargetIndex, PolysT)
	if Nodes == nil then
		return nil
	end
	local Nodes2 = {}
	local NodeIDs = {}
	local AddNodes = true
	for k = 1, #Nodes do
		--local ClosestPoint = closest_point_on_polygon(Polys1[Nodes[k]], Target)
		--Nodes2[#Nodes2+1] = ClosestPoint
		Nodes2[#Nodes2+1] = PolysT[Nodes[k]].Center
		if AddNodes then
			NodeIDs[Nodes[k]] = 0
			for i = 1, #Polys1[Nodes[k]].Neighboors do
				if NodeIDs[Polys1[Nodes[k]].Neighboors[i]] == nil then
					NodeIDs[Polys1[Nodes[k]].Neighboors[i]] = 0
					Nodes[#Nodes+1] = Polys1[Nodes[k]].Neighboors[i]
				end
			end
		end
	end
	if not FinalNode then
		table.remove(Nodes2, #Nodes2)
		Nodes2[#Nodes2+1] = Target
	end
	--table.remove(Nodes, 1)
	local NewPaths = smoothPath(Nodes2, PolysT, Nodes)
	return NewPaths, StartIndex, TargetIndex, InsideStartPolygon, TargetInsideTargetPolygon, Nodes
end

function InsidePolygon(polygon, point)
    local oddNodes = false
    local j = #polygon
    for i = 1, #polygon do
        if (polygon[i].y < point.y and polygon[j].y >= point.y or polygon[j].y < point.y and polygon[i].y >= point.y) then
            if (polygon[i].x + ( point.y - polygon[i].y ) / (polygon[j].y - polygon[i].y) * (polygon[j].x - polygon[i].x) < point.x) then
                oddNodes = not oddNodes
            end
        end
        j = i
    end
    return oddNodes
end

function InsidePolygon2(polygon, point, X, Y)
    local oddNodes = false
    local j = #polygon
    for i = 1, #polygon do
		--Print(polygon[i][X] + ( point[Y] - polygon[i][Y] ) / (polygon[j][Y] - polygon[i][Y]) * (polygon[j][X] - polygon[i][X]))
		--Print(polygon[i][X] + ( polygon[i][Y] - point[Y] ) / (polygon[j][Y] - polygon[i][Y]) * (polygon[j][X] - polygon[i][X]))
		--Print(polygon[j][X] - polygon[i][X])
        if (polygon[i][Y] < point[Y] and polygon[j][Y] >= point[Y] or polygon[j][Y] < point[Y] and polygon[i][Y] >= point[Y]) then
            if (polygon[i][X] + ( point[Y] - polygon[i][Y] ) / (polygon[j][Y] - polygon[i][Y]) * (polygon[j][X] - polygon[i][X]) < point[X]) then
                --if (polygon[i].z < point.z+1.0 and polygon[j].z >= point.z-1.0 and polygon[j].z < point.z+1.0 and polygon[i].z >= point.z-1.0) then
                    oddNodes = not oddNodes;
               	--end
            end
        end
        j = i;
    end
    return oddNodes
end

function Inside3DPolygon(polygon, point)
	local oddNodes = InsidePolygon(polygon, point)
	local Intersect1 =   math.findIntersect(polygon[1].z, polygon[1].x, polygon[2].z, polygon[2].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect2 =   math.findIntersect(polygon[2].z, polygon[2].x, polygon[3].z, polygon[3].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect3 =   math.findIntersect(polygon[1].z, polygon[1].x, polygon[3].z, polygon[3].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect4 =   math.findIntersect(polygon.Center.z, polygon.Center.x, polygon[1].z, polygon[1].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect5 =   math.findIntersect(polygon.Center.z, polygon.Center.x, polygon[2].z, polygon[2].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect6 =   math.findIntersect(polygon.Center.z, polygon.Center.x, polygon[3].z, polygon[3].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect7 =   math.findIntersect(polygon.Center.z, polygon.Center.x, polygon.Edge.z, polygon.Edge.x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect8 =   math.findIntersect(polygon.Center.z, polygon.Center.x, polygon.Edge2.z, polygon.Edge2.x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect9 =   math.findIntersect(polygon.Center.z, polygon.Center.x, polygon.Edge3.z, polygon.Edge3.x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect10 =  math.findIntersect(polygon.Edge.z, polygon.Edge.x, polygon[1].z, polygon[1].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect11 =  math.findIntersect(polygon.Edge.z, polygon.Edge.x, polygon[2].z, polygon[2].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect12 =  math.findIntersect(polygon.Edge.z, polygon.Edge.x, polygon[3].z, polygon[3].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect13 =  math.findIntersect(polygon.Edge2.z, polygon.Edge2.x, polygon[1].z, polygon[1].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect14 =  math.findIntersect(polygon.Edge2.z, polygon.Edge2.x, polygon[2].z, polygon[2].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect15 =  math.findIntersect(polygon.Edge2.z, polygon.Edge2.x, polygon[3].z, polygon[3].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect16 =  math.findIntersect(polygon.Edge3.z, polygon.Edge3.x, polygon[1].z, polygon[1].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect17 =  math.findIntersect(polygon.Edge3.z, polygon.Edge3.x, polygon[2].z, polygon[2].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect18 =  math.findIntersect(polygon.Edge3.z, polygon.Edge3.x, polygon[3].z, polygon[3].x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect19 =  math.findIntersect(polygon.Edge.z, polygon.Edge.x, polygon.Edge2.z, polygon.Edge2.x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect20 =  math.findIntersect(polygon.Edge.z, polygon.Edge.x, polygon.Edge3.z, polygon.Edge3.x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Intersect21 =  math.findIntersect(polygon.Edge2.z, polygon.Edge2.x, polygon.Edge3.z, polygon.Edge3.x, point.z + 0.5, point.x, point.z - 0.5, point.x, true, true)
	local Bool = Intersect1 or Intersect2 or Intersect3 or Intersect4 or Intersect5 or Intersect6 or Intersect7 or Intersect8 or Intersect9
	local Bool2 = Intersect10 or Intersect11 or Intersect12 or Intersect13 or Intersect14 or Intersect15 or Intersect16 or Intersect17
	or Intersect18 or Intersect19 or Intersect20 or Intersect21
	local Bool3 = Bool or Bool2
	return oddNodes and Bool3
end

function Inside3DPolygon2(polygon, point)
	local Inside = false
	local Bool = InsidePolygon(polygon, point)
	if Bool then
		local Min = math.min(polygon[1].z, polygon[2].z, polygon[3].z)
		local Max = math.max(polygon[1].z, polygon[2].z, polygon[3].z)
		if point.z > Min-1.0 and point.z < Max+1.0 then
			Inside = true
		end
	end
	return Inside
end

function GetClosestPolygon(PolygonsT, Point, IncludePoints, LowPriorityLevel, Flags)
	local Dist = 10000.0
	local Index = 1
	local Include = false
	if IncludePoints ~= nil then
		Include = IncludePoints
	end
	local Bits = 0
	if Flags ~= nil then
		Bits = Flags
	end
	local ItDelay = 0
	for k = 1, #PolygonsT do
		if Inside3DPolygon2(PolygonsT[k], Point) then
			return PolygonsT[k].ID, Dist
		end
		local CoordsT = {}
		CoordsT[#CoordsT+1] = {PolygonsT[k][1], PolygonsT[k].ID}
		CoordsT[#CoordsT+1] = {PolygonsT[k][2], PolygonsT[k].ID}
		CoordsT[#CoordsT+1] = {PolygonsT[k][3], PolygonsT[k].ID}
		CoordsT[#CoordsT+1] = {PolygonsT[k].Center, PolygonsT[k].ID}
		--CoordsT[#CoordsT+1] = {PolygonsT[k].Edge, PolygonsT[k].ID}
		--CoordsT[#CoordsT+1] = {PolygonsT[k].Edge2, PolygonsT[k].ID}
		--CoordsT[#CoordsT+1] = {PolygonsT[k].Edge3, PolygonsT[k].ID}
		CoordsT[#CoordsT+1] = {closest_point_on_polygon(PolygonsT[k], Point), PolygonsT[k].ID}
		if Include then
			for j = 1, #PolygonsT[k].LocalPoints do
				CoordsT[#CoordsT+1] = {PolygonsT[k].LocalPoints[j], PolygonsT[k].ID}
			end
		end
		for i = 1, #CoordsT do
			local CanPass = true
			if is_bit_set(Bits, 1) then
				if Point.z > CoordsT[i][1].z-10.0 and Point.z < CoordsT[i][1].z+10.0 then

				else
					CanPass = false
				end
			end
			if CanPass then
				local Distance = DistanceBetween(Point.x, Point.y, Point.z, CoordsT[i][1].x, CoordsT[i][1].y, CoordsT[i][1].z)
				if Distance < Dist then
					Dist = Distance
					Index = CoordsT[i][2]
				end
			end
		end
		if is_bit_set(LowPriorityLevel, 5) then
			ItDelay = ItDelay + 1
			if ItDelay > 1000 then
				Wait()
				ItDelay = 0
			end
		end
	end
	return Index, Dist
end

function DistanceBetween(x1, y1, z1, x2, y2, z2)
	local dx = x1 - x2
	local dy = y1 - y2
	local dz = z1 - z2
	return math.sqrt ( dx * dx + dy * dy + dz * dz)
end

function DistanceBetween2D(x1, y1, x2, y2)
	local dx = x1 - x2
	local dy = y1 - y2
	return math.sqrt ( dx * dx + dy * dy)
end

function GetNearPolygonNeighbors(StartIndex, Size)
	local Indexes = {}
	Indexes[#Indexes+1] = StartIndex
	local InsertedIndexes = {}
	InsertedIndexes[StartIndex] = 0
	for k = 1, #Polys1[StartIndex].Neighboors do
		local CanInsert = true
		for j = 1, #Indexes do
			if Polys1[StartIndex].Neighboors[k] == Indexes[j] then
				CanInsert = false
				break
			end
		end
		if CanInsert then
			Indexes[#Indexes+1] = Polys1[StartIndex].Neighboors[k]
		end
	end
	for r = 1, Size do
		for k = 1, #Indexes do
			if Polys1[Indexes[k]] ~= nil then
				for j = 1, #Polys1[Indexes[k]].Neighboors do
					local CanInsert = true
					--for a = 1, #Indexes do
					--	if Polys1[Indexes[k]].Neighboors[j] == Indexes[a] then
					--		CanInsert = false
					--		break
					--	end
					--end
					if InsertedIndexes[Polys1[Indexes[k]].Neighboors[j]] == nil then
						if CanInsert then
							Indexes[#Indexes+1] = Polys1[Indexes[k]].Neighboors[j]
							InsertedIndexes[Polys1[Indexes[k]].Neighboors[j]] = 0
						end
					end
				end
			end
		end
	end
	return Indexes
end

function TrackPolygonIndex(PolyIndexesT, StartIndex, Pos, Size)
	local FoundPoly = false
	local NewIndex = StartIndex
	local IsInsidePolygon = true
	if not InsidePolygon(Polys1[StartIndex], Pos) then
		IsInsidePolygon = false
		for k = 1, #PolyIndexesT do
			if InsidePolygon(Polys1[PolyIndexesT[k]], Pos) then
				NewIndex = PolyIndexesT[k]
				break
			end
		end
		if not FoundPoly then
			local Index = GetClosestPolygon(Polys1, Pos)
			PolyIndexesT = GetNearPolygonNeighbors(Index, Size)
			NewIndex = Index
		end
	end
	return NewIndex, IsInsidePolygon, FoundPoly
end

function TrackNewPolygonIndex(T, TargetIndex, Pos, PathsT)
	if not InsidePolygon(Polys1[TargetIndex], Pos) then
		if not T.HasSet then
			local NextPolygonID = 0
			for i = 1, #Polys1[TargetIndex].Neighboors do

			end
			if PathsT ~= nil then
				local CoordsT2 = {}
				CoordsT2[#CoordsT2+1] = Polys1[TargetIndex][1]
				CoordsT2[#CoordsT2+1] = Polys1[TargetIndex][2]
				CoordsT2[#CoordsT2+1] = Polys1[TargetIndex][3]
				CoordsT2[#CoordsT2+1] = Polys1[TargetIndex].Center
				CoordsT2[#CoordsT2+1] = Polys1[TargetIndex].Edge
				CoordsT2[#CoordsT2+1] = Polys1[TargetIndex].Edge2
				CoordsT2[#CoordsT2+1] = Polys1[TargetIndex].Edge3
				local Dist2 = 10000.0
				local SelectedVector2 = CoordsT2[4]
				for j = 1, #CoordsT2 do
					local Distance = DistanceBetween(CoordsT2[j].x, CoordsT2[j].y, CoordsT2[j].z, Pos.x, Pos.y, Pos.z)
					if Distance < Dist2 then
						Dist2 = Distance
						SelectedVector2 = CoordsT2[j]
					end
				end
				PathsT[#PathsT+1] = {
					x = SelectedVector2.x,
					y = SelectedVector2.y,
					z = SelectedVector2.z,
					Heading = 0.0,
					ID = Polys1[TargetIndex].ID,
					Parent = TargetIndex,
					NodeFlags = Polys1[TargetIndex].Flags,
					PolyID = Polys1[TargetIndex].ID
				}
			end
		end
	end
end


-- Checks if two lines intersect (or line segments if seg is true)
-- Lines are given as four numbers (two coordinates)
function math.findIntersect(l1p1x,l1p1y, l1p2x,l1p2y, l2p1x,l2p1y, l2p2x,l2p2y, seg1, seg2)
	local a1,b1,a2,b2 = l1p2y-l1p1y, l1p1x-l1p2x, l2p2y-l2p1y, l2p1x-l2p2x
	local c1,c2 = a1*l1p1x+b1*l1p1y, a2*l2p1x+b2*l2p1y
	local det,x,y = a1*b2 - a2*b1
	if det==0 then return false, 0.0, 0.0 end --"The lines are parallel."
	x,y = (b2*c1-b1*c2)/det, (a1*c2-a2*c1)/det
	if seg1 or seg2 then
	  local min,max = math.min, math.max
	  if seg1 and not (min(l1p1x,l1p2x) <= x and x <= max(l1p1x,l1p2x) and min(l1p1y,l1p2y) <= y and y <= max(l1p1y,l1p2y)) or
		 seg2 and not (min(l2p1x,l2p2x) <= x and x <= max(l2p1x,l2p2x) and min(l2p1y,l2p2y) <= y and y <= max(l2p1y,l2p2y)) then
		return false, 0.0, 0.0 -- "The lines don't intersect."
	  	end
	end
	return true, x, y
end

function SaveJSONFile(FileName, JSONContents)
    local File = io.open(FileName, "w+")
    if File then
        local Contents = json.encode(JSONContents)
        File:write(Contents)
        io.close(File)
    end
end

function is_bit_set(value, bit)
    bit = bit - 1
    return (value & (1 << bit)) ~= 0
end

function clear_bit(value, bit)
    bit = bit - 1;
    return value & ~(1 << bit)
end

function set_bit(value, bit)
    bit = bit - 1;
    return value | 1 << bit
end

function ShapeTestNav(Entity, PPos, AdjustedVect, Flags)
	local FlagBits = -1
	if Flags ~= nil then
		FlagBits = Flags
	end
	local HitCoords = v3.new()
	local DidHit = memory.alloc(1)
	local EndCoords = v3.new()
	local Normal = v3.new()
	local HitEntity = memory.alloc_int()
	local HitEntityHandle = 0

	local Handle = SHAPETEST.START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE(
		PPos.x, PPos.y, PPos.z,
		AdjustedVect.x, AdjustedVect.y, AdjustedVect.z,
		FlagBits,
		Entity, 7
	)
	SHAPETEST.GET_SHAPE_TEST_RESULT(Handle, DidHit, EndCoords, Normal, HitEntity)
	if memory.read_byte(DidHit) ~= 0 then
		HitCoords.x = EndCoords.x
		HitCoords.y = EndCoords.y
		HitCoords.z = EndCoords.z
	else
		HitCoords.x = AdjustedVect.x
		HitCoords.y = AdjustedVect.y
		HitCoords.z = AdjustedVect.z
	end
	if memory.read_byte(DidHit) ~= 0 then
		if memory.read_int(HitEntity) ~= 0 then
			HitEntityHandle = memory.read_int(HitEntity)
		end
	end
	return memory.read_byte(DidHit) ~= 0, HitCoords, HitEntityHandle, Normal
end

function RequestControlOfEntity(Entity)
	if NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(Entity) then
		return true
	else
		return NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(Entity)
	end
end

function CanIntersectEntity(Pos, TargetPos, Paths, CurrentIndex)
	local CanIntersect = true
	if Paths ~= nil then
		local Polygons = {}
		for k = 1, #Paths do
			Polygons[#Polygons+1] = Polys1[Paths[k].PolyID]
		end
		CanIntersect = is_path_clear(Pos, TargetPos, Polygons)
	end
	return CanIntersect 
end

function GetPositionCircle(Center, Radius, Angle)
	local NewPoint = {
		x = Center.x + Radius * math.cos(math.rad(Angle)),
		y = Center.y + Radius * math.sin(math.rad(Angle)),
		z = Center.z
	}
	return NewPoint
end

function ROTATION_TO_DIRECTION(rotation) 
	local adjusted_rotation = { 
		x = (math.pi / 180) * rotation.x, 
		y = (math.pi / 180) * rotation.y, 
		z = (math.pi / 180) * rotation.z 
	}
	local direction = {
		x = - math.sin(adjusted_rotation.z) * math.abs(math.cos(adjusted_rotation.x)), 
		y =   math.cos(adjusted_rotation.z) * math.abs(math.cos(adjusted_rotation.x)), 
		z =   math.sin(adjusted_rotation.x)
	}
	return direction
end

function GetEntityMatrix(element)
    local rot = ENTITY.GET_ENTITY_ROTATION(element, 2) -- ZXY
    local rx, ry, rz = rot.x, rot.y, rot.z
    rx, ry, rz = math.rad(rx), math.rad(ry), math.rad(rz)
    local matrix = {}
    matrix[1] = {}
    matrix[1][1] = math.cos(rz)*math.cos(ry) - math.sin(rz)*math.sin(rx)*math.sin(ry)
    matrix[1][2] = math.cos(ry)*math.sin(rz) + math.cos(rz)*math.sin(rx)*math.sin(ry)
    matrix[1][3] = -math.cos(rx)*math.sin(ry)
    matrix[1][4] = 1
    
    matrix[2] = {}
    matrix[2][1] = -math.cos(rx)*math.sin(rz)
    matrix[2][2] = math.cos(rz)*math.cos(rx)
    matrix[2][3] = math.sin(rx)
    matrix[2][4] = 1
	
    matrix[3] = {}
    matrix[3][1] = math.cos(rz)*math.sin(ry) + math.cos(ry)*math.sin(rz)*math.sin(rx)
    matrix[3][2] = math.sin(rz)*math.sin(ry) - math.cos(rz)*math.cos(ry)*math.sin(rx)
    matrix[3][3] = math.cos(rx)*math.cos(ry)
    matrix[3][4] = 1
	
    matrix[4] = {}
    local Pos = ENTITY.GET_ENTITY_COORDS(element)
    matrix[4][1], matrix[4][2], matrix[4][3] = Pos.x, Pos.y, Pos.z - 1.0
    matrix[4][4] = 1
	
    return matrix
end

function GetOffsetFromEntityInWorldCoords(entity, offX, offY, offZ)
    local m = GetEntityMatrix(entity)
    local x = offX * m[1][1] + offY * m[2][1] + offZ * m[3][1] + m[4][1]
    local y = offX * m[1][2] + offY * m[2][2] + offZ * m[3][2] + m[4][2]
    local z = offX * m[1][3] + offY * m[2][3] + offZ * m[3][3] + m[4][3]
    return {x = x, y = y, z = z}
end

function GetRotationMatrix(rot)
    local rx, ry, rz = rot.x, rot.y, rot.z
    rx, ry, rz = math.rad(rx), math.rad(ry), math.rad(rz)
    local matrix = {}
    matrix[1] = {}
    matrix[1][1] = math.cos(rz)*math.cos(ry) - math.sin(rz)*math.sin(rx)*math.sin(ry)
    matrix[1][2] = math.cos(ry)*math.sin(rz) + math.cos(rz)*math.sin(rx)*math.sin(ry)
    matrix[1][3] = -math.cos(rx)*math.sin(ry)
    matrix[1][4] = 1
    
    matrix[2] = {}
    matrix[2][1] = -math.cos(rx)*math.sin(rz)
    matrix[2][2] = math.cos(rz)*math.cos(rx)
    matrix[2][3] = math.sin(rx)
    matrix[2][4] = 1
	
    matrix[3] = {}
    matrix[3][1] = math.cos(rz)*math.sin(ry) + math.cos(ry)*math.sin(rz)*math.sin(rx)
    matrix[3][2] = math.sin(rz)*math.sin(ry) - math.cos(rz)*math.cos(ry)*math.sin(rx)
    matrix[3][3] = math.cos(rx)*math.cos(ry)
    matrix[3][4] = 1
	
    return matrix
end

function GetOffsetFromRotationInWorldCoords(rot, Pos, offX, offY, offZ)
    local m = GetRotationMatrix(rot)
    local x = offX * m[1][1] + offY * m[2][1] + offZ * m[3][1] + Pos.x
    local y = offX * m[1][2] + offY * m[2][2] + offZ * m[3][2] + Pos.y
    local z = offX * m[1][3] + offY * m[2][3] + offZ * m[3][3] + (Pos.z - 1.0)
    return {x = x, y = y, z = z}
end

local PolyIDs = {}

function SetPolyIDs()
	--[[
	for i = 1, #Polys1 do
		local XID = math.floor(Polys1[i].Edge.x)
		local YID = math.floor(Polys1[i].Edge.y)
		local ZID = math.floor(Polys1[i].Edge.z)
		local XID2 = math.floor(Polys1[i].Edge2.x)
		local YID2 = math.floor(Polys1[i].Edge2.y)
		local ZID2 = math.floor(Polys1[i].Edge2.z)
		local XID3 = math.floor(Polys1[i].Edge3.x)
		local YID3 = math.floor(Polys1[i].Edge3.y)
		local ZID3 = math.floor(Polys1[i].Edge3.z)
		if PolyIDs[XID] == nil then
			PolyIDs[XID] = {}
		end
		if PolyIDs[XID][YID] == nil then
			PolyIDs[XID][YID] = {}
		end
		PolyIDs[XID][YID][ZID] = Polys1[i].ID
		if PolyIDs[XID2] == nil then
			PolyIDs[XID2] = {}
		end
		if PolyIDs[XID2][YID2] == nil then
			PolyIDs[XID2][YID2] = {}
		end
		PolyIDs[XID2][YID2][ZID2] = Polys1[i].ID
		if PolyIDs[XID3] == nil then
			PolyIDs[XID3] = {}
		end
		if PolyIDs[XID3][YID3] == nil then
			PolyIDs[XID3][YID3] = {}
		end
		PolyIDs[XID3][YID3][ZID3] = Polys1[i].ID
		for k = 1, #Polys1[i].LocalPoints do
			local Vector3 = Polys1[i].LocalPoints[k]
			local XID4 = math.floor(Vector3.x)
			local YID4 = math.floor(Vector3.y)
			local ZID4 = math.floor(Vector3.z)
			if PolyIDs[XID4] == nil then
				PolyIDs[XID4] = {}
			end
			if PolyIDs[XID4][YID4] == nil then
				PolyIDs[XID4][YID4] = {}
			end
			PolyIDs[XID4][YID4][ZID4] = Polys1[i].ID
		end
		local XID4 = math.floor(Polys1[i][1].x)
		local YID4 = math.floor(Polys1[i][1].y)
		local ZID4 = math.floor(Polys1[i][1].z)
		local XID5 = math.floor(Polys1[i][2].x)
		local YID5 = math.floor(Polys1[i][2].y)
		local ZID5 = math.floor(Polys1[i][2].z)
		local XID6 = math.floor(Polys1[i][3].x)
		local YID6 = math.floor(Polys1[i][3].y)
		local ZID6 = math.floor(Polys1[i][3].z)
		if PolyIDs[XID4] == nil then
			PolyIDs[XID4] = {}
		end
		if PolyIDs[XID4][YID4] == nil then
			PolyIDs[XID4][YID4] = {}
		end
		PolyIDs[XID4][YID4][ZID4] = Polys1[i].ID
		if PolyIDs[XID5] == nil then
			PolyIDs[XID5] = {}
		end
		if PolyIDs[XID5][YID5] == nil then
			PolyIDs[XID5][YID5] = {}
		end
		PolyIDs[XID5][YID5][ZID5] = Polys1[i].ID
		if PolyIDs[XID6] == nil then
			PolyIDs[XID6] = {}
		end
		if PolyIDs[XID6][YID6] == nil then
			PolyIDs[XID6][YID6] = {}
		end
		PolyIDs[XID6][YID6][ZID6] = Polys1[i].ID
		local XID7 = math.floor(Polys1[i].Center.x)
		local YID7 = math.floor(Polys1[i].Center.y)
		local ZID7 = math.floor(Polys1[i].Center.z)
		if PolyIDs[XID7] == nil then
			PolyIDs[XID7] = {}
		end
		if PolyIDs[XID7][YID7] == nil then
			PolyIDs[XID7][YID7] = {}
		end
		PolyIDs[XID7][YID7][ZID7] = Polys1[i].ID
	end
	]]
end
SetPolyIDs()

menu.action(TestMenu, "Get Poly Index", {}, "", function(Toggle)
	local PlayerPed = PLAYER.PLAYER_PED_ID()
	local Pos = ENTITY.GET_ENTITY_COORDS(PlayerPed)
	local XID = math.floor(Pos.x)
	local YID = math.floor(Pos.y)
	local ZID = math.floor(Pos.z)
	local Index = 1
	if PolyIDs[XID] ~= nil then
		if PolyIDs[XID][YID] ~= nil then
			if PolyIDs[XID][YID][ZID] ~= nil then
				Index = PolyIDs[XID][YID][ZID]
			end
		end
	end
	ENTITY.SET_ENTITY_COORDS(PlayerPed, Polys1[Index].Center.x, Polys1[Index].Center.y, Polys1[Index].Center.z - 1.0)
	local XID2 = math.floor(Polys1[Index].Center.x)
	local YID2 = math.floor(Polys1[Index].Center.y)
	local ZID2 = math.floor(Polys1[Index].Center.z)
	for i = 1, 200 do
		directx.draw_text(0.7, 0.7, "x: "..XID.." y: "..YID.." z: "..ZID , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		directx.draw_text(0.7, 0.75, "x: "..XID2.." y: "..YID2.." z: "..ZID2 , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		Wait()
	end
end)

menu.action(TestMenu, "Straight Line Test", {}, "", function(Toggle)
	local PlayerPed = PLAYER.PLAYER_PED_ID()
	local Pos = ENTITY.GET_ENTITY_COORDS(PlayerPed)
	local FoundPolys = {}
	local FoundIDs = {}
	local StartPoly = GetClosestPolygon(Polys1, Pos, false, 0)
	local TargetPoly = GetClosestPolygon(Polys1, StartPath, false, 0)
	local CurrentPos = {x = Polys1[StartPoly].Center.x, y = Polys1[StartPoly].Center.y, z = Polys1[StartPoly].Center.z}
	local TargetPos = {x = Polys1[TargetPoly].Center.x, y = Polys1[TargetPoly].Center.y, z = Polys1[TargetPoly].Center.z}
	local HasReachedTargetIndex = false
	FoundIDs[StartPoly] = 0
	FoundPolys[#FoundPolys+1] = Polys1[StartPoly]
	for i = 1, 100 do
		if not HasReachedTargetIndex then
			for k = 1, #FoundPolys do
				for j = 1, #Polys1[FoundPolys[k].ID].Neighboors do
					if FoundIDs[Polys1[FoundPolys[k].ID].Neighboors[j]] == nil then
						FoundIDs[Polys1[FoundPolys[k].ID].Neighboors[j]] = 0
						FoundPolys[#FoundPolys+1] = Polys1[Polys1[FoundPolys[k].ID].Neighboors[j]]
						if Polys1[FoundPolys[k].ID].Neighboors[j] == TargetPoly then
							HasReachedTargetIndex = true
						end
					end
				end
			end
		else
			break
		end
	end
	local CanStraight = true
	for i = 1, 1000 do
		GRAPHICS.DRAW_MARKER(28, CurrentPos.x,
		CurrentPos.y, CurrentPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 150, 0, 0, 100, 0, false, 2, false, 0, 0, false)
		local Count = 0
		if CanStraight then
			local NewV3 = v3.new(TargetPos.x - CurrentPos.x, TargetPos.y - CurrentPos.y, TargetPos.z - CurrentPos.z)
			local Norm = NewV3:normalise()
			CurrentPos.x = CurrentPos.x + (Norm.x * 0.1)
			CurrentPos.y = CurrentPos.y + (Norm.y * 0.1)
			CurrentPos.z = CurrentPos.z + (Norm.z * 0.1)
			for k = 1, #FoundPolys do
				if Inside3DPolygon2(FoundPolys[k], CurrentPos) then
					Count = Count + 1
				end
			end
			if Count == 0 then
				CanStraight = false
			end
		end
		Print(CanStraight)
		Wait()
	end
end)

function GetPolygonDirectIndex(Pos)
	local XID = math.floor(Pos.x)
	local YID = math.floor(Pos.y)
	local ZID = math.floor(Pos.z)
	local Index = 0
	if PolyIDs[XID] ~= nil then
		if PolyIDs[XID][YID] ~= nil then
			if PolyIDs[XID][YID][ZID] ~= nil then
				Index = PolyIDs[XID][YID][ZID]
			end
		end
	end
	return Index
end

local AiHateRel = "rgFM_AiHate"
local AiLikeRel = "rgFM_AiLike"
local AiLikeHateAiHateRel = "rgFM_AiLike_HateAiHate"
local AiHateAiHateRel = "rgFM_HateAiHate"
local AiHateEveryone = "rgFM_HateEveryOne"

local DMTest = false
menu.toggle(TestMenu, "Multiple Peds For Navs", {}, "", function(Toggle)
	DMTest = Toggle
	if not DMTest then
		for index, peds in pairs(entities.get_all_peds_as_handles()) do
			if DECORATOR.DECOR_EXIST_ON(peds, "Casino_Game_Info_Decorator") then
				RequestControlOfEntity(peds)
				local NetID = NETWORK.PED_TO_NET(peds)
				if NetID ~= 0 then
					NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(NetID, PLAYER.PLAYER_ID(), false)
				end
				entities.delete_by_handle(peds)
			end
		end
	end
	if DMTest then
		local AiTeam1Hash = joaat("rgFM_AiPed20000")
		local Peds = {}
		local HandlesT = {}
		local PedModel = joaat("mp_m_bogdangoon")
		local StartPos = {x = StartPath.x, y = StartPath.y, z = StartPath.z}
		while DMTest do
			if #Peds < 10 then
				STREAMING.REQUEST_MODEL(PedModel)
				if STREAMING.HAS_MODEL_LOADED(PedModel) then
					local PedHandle = PED.CREATE_PED(28, joaat("mp_m_bogdangoon"), StartPos.x, StartPos.y, StartPos.z, 0.0, true, true)
					if PedHandle ~= 0 then
						ENTITY.SET_ENTITY_AS_MISSION_ENTITY(PedHandle, false, true)
						local NetID = NETWORK.PED_TO_NET(PedHandle)
						if NetID ~= 0 then
							NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(NetID, PLAYER.PLAYER_ID(), true)
							NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(NetID, true)
							NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NetID, false)
						end
						PED.SET_PED_RELATIONSHIP_GROUP_HASH(PedHandle, joaat(AiHateRel))
						WEAPON.GIVE_WEAPON_TO_PED(PedHandle, joaat("weapon_knife"), 99999, false, true)
						DECORATOR.DECOR_SET_INT(PedHandle, "Casino_Game_Info_Decorator", 1)
						if HandlesT[PedHandle] == nil then
							Peds[#Peds+1] = {}
							Peds[#Peds].Handle = PedHandle
							Peds[#Peds].TaskState = 0
							Peds[#Peds].Target = 0
							Peds[#Peds].TaskCoords = {x = 0.0, y = 0.0, z = 0.0}
							Peds[#Peds].TaskCoords2 = {x = 0.0, y = 0.0, z = 0.0}
							Peds[#Peds].Paths = nil
							Peds[#Peds].ActualPath = 1
							Peds[#Peds].SearchState = 0
							Peds[#Peds].SearchCalled = false
							Peds[#Peds].Start = nil
							Peds[#Peds].TargetPoly = nil
							Peds[#Peds].InsideStartPolygon = false
							Peds[#Peds].TargetInsideTargetPolygon = false
							Peds[#Peds].HasSetRel = false
							Peds[#Peds].TimeOut = 0
							Peds[#Peds].SearchLowLevel = 1
							Peds[#Peds].IsInVeh = false
							Peds[#Peds].VehHandle = 0
							Peds[#Peds].LastDistance = 0.0
							Peds[#Peds].SameDistanceTick = 0
							Peds[#Peds].StartPolysT = {}
							Peds[#Peds].TargetPolysT = {}
							Peds[#Peds].DrivingStyle = 0
							Peds[#Peds].NetID = NetID
							Peds[#Peds].IsZombie = false
							Peds[#Peds].JumpDelay = 0
							Peds[#Peds].StartIndexArg = nil
							Peds[#Peds].TargetIndexArg = nil
							Peds[#Peds].AddMode = false
							Peds[#Peds].HasChecked = false
							Peds[#Peds].LastPolyID = 0
							Peds[#Peds].LastTargetPos = {x = 0.0, y = 0.0, z = 0.0}
							PED.SET_PED_TARGET_LOSS_RESPONSE(PedHandle, 1)
							PED.SET_COMBAT_FLOAT(PedHandle, 2, 4000.0)
							PED.SET_PED_COMBAT_RANGE(PedHandle, 3)
							PED.SET_PED_FIRING_PATTERN(PedHandle, joaat("FIRING_PATTERN_FULL_AUTO"))
							PED.SET_PED_COMBAT_ATTRIBUTES(PedHandle, 5, true)
							PED.SET_PED_COMBAT_ATTRIBUTES(PedHandle, 46, true)
							HandlesT[PedHandle] = 0
						end
					end
				end
			else
				STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(PedModel)
			end
			for k = 1, #Peds do
				if Peds[k] ~= nil then
					if not ENTITY.IS_ENTITY_DEAD(Peds[k].Handle) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Handle) then
						if RequestControlOfEntity(Peds[k].Handle) then
							entities.set_can_migrate(Peds[k].Handle, false)
						end
						if WEAPON.IS_PED_ARMED(Peds[k].Handle, 1) then
							Peds[k].IsZombie = true
							PED.SET_COMBAT_FLOAT(Peds[k].Handle, 7, 3.0)
							PED.SET_PED_RESET_FLAG(Peds[k].Handle, 306, true)
							PED.SET_PED_CONFIG_FLAG(Peds[k].Handle, 435, true)
						end
						if Peds[k].IsZombie then
							--PED.SET_PED_MOVE_RATE_OVERRIDE(Peds[k].Handle, 1.5)
							PED.SET_AI_MELEE_WEAPON_DAMAGE_MODIFIER(100.0)
							PED.SET_PED_USING_ACTION_MODE(Peds[k].Handle, false, -1, 0)
							PED.SET_PED_MIN_MOVE_BLEND_RATIO(Peds[k].Handle, 3.0)
							PED.SET_PED_MAX_MOVE_BLEND_RATIO(Peds[k].Handle, 3.0)
						end
						local LastEnt = ENTITY._GET_LAST_ENTITY_HIT_BY_ENTITY(Peds[k].Handle)
						if LastEnt ~= 0 then
							if ENTITY.IS_ENTITY_A_PED(LastEnt) then
								if PED.GET_PED_RELATIONSHIP_GROUP_HASH(LastEnt) == PED.GET_PED_RELATIONSHIP_GROUP_HASH(Peds[k].Handle) then
									ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Peds[k].Handle, LastEnt, false)
								end
							end
						end
						--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Peds[k].Handle, LastHandle, false)
						local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
						if not Peds[k].HasSetRel then
							if PED.DOES_RELATIONSHIP_GROUP_EXIST(joaat(AiHateRel)) then
								if RequestControlOfEntity(Peds[k].Handle) then
									--PED.SET_PED_RELATIONSHIP_GROUP_HASH(Peds[k].Handle, AiTeam1Hash)
									Peds[k].HasSetRel = true
								end
							end
						end
						if Peds[k].TaskState == 6 then
							--TASK.TASK_COMBAT_HATED_TARGETS_AROUND_PED(Peds[k].Handle, 1000.0, 16)
							local Target = PED.GET_PED_TARGET_FROM_COMBAT_PED(Peds[k].Handle, 0)
							if Target ~= 0 then
								Peds[k].Target = Target
								Peds[k].TaskState = 1
							end
						end
						if Peds[k].TaskState == 0 then
							--TASK.TASK_COMBAT_HATED_TARGETS_AROUND_PED(Peds[k].Handle, 1000.0, 16)
							local Target = PED.GET_PED_TARGET_FROM_COMBAT_PED(Peds[k].Handle, 0)
							if Target ~= 0 then
								Peds[k].Target = Target
								Peds[k].TaskState = 1
							end
						end
						if Peds[k].SearchState == 0 then
							if Peds[k].Target ~= 0 then
								local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
								local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
								Peds[k].SearchState = 1
								util.create_thread(function()
									local NewPaths = nil
									NewPaths, Peds[k].Start, Peds[k].TargetPoly, Peds[k].InsideStartPolygon, Peds[k].TargetInsideTargetPolygon = AStarPathFind(Pos, TargetPos, Peds[k].SearchLowLevel, false, Peds[k].StartIndexArg, Peds[k].TargetIndexArg, false, false, nil, false)
									if NewPaths ~= nil then
										if Peds[k] ~= nil then
											if not Peds[k].AddMode then
												Peds[k].Paths = NewPaths
											else
												for i = 1, #NewPaths do
													table.insert(Peds[k].Paths, NewPaths[i])
												end
											end
											--Peds[k].SearchLowLevel = 1
											--Print("Found path")
											Peds[k].LastTargetPos.x = TargetPos.x
											Peds[k].LastTargetPos.y = TargetPos.y
											Peds[k].LastTargetPos.z = TargetPos.z
											Peds[k].ActualPath = 1
											Peds[k].TaskState = 1
											Peds[k].StartIndexArg = nil
											Peds[k].TargetIndexArg = nil
											Peds[k].AddMode = false
										end
										--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
									end
									
									Wait(1000)
									if Peds[k] ~= nil then
										Peds[k].SearchState = 2
										--Print("Reset")
									end
								end)
							end
						end
						if Peds[k].Target ~= 0 then
							if Peds[k].Paths ~= nil then
								local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
								local DistanceFinal = DistanceBetween(TargetPos.x, TargetPos.y, TargetPos.z, Peds[k].Paths[#Peds[k].Paths].x, Peds[k].Paths[#Peds[k].Paths].y, Peds[k].Paths[#Peds[k].Paths].z)
								local DistanceLast = DistanceBetween(TargetPos.x, TargetPos.y, TargetPos.z, Peds[k].LastTargetPos.x, Peds[k].LastTargetPos.y, Peds[k].LastTargetPos.z)
								if DistanceFinal > 30.0 or DistanceLast > 2.0 then
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 7
									end
								end
								
							end
						end
						if Peds[k].TaskState == 1 then
							if Peds[k].Paths ~= nil then
								--if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_CLIMB")) == 7 then
								if not Peds[k].IsZombie then
									if RequestControlOfEntity(Peds[k].Handle) then
										--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										if Peds[k].ActualPath > #Peds[k].Paths then
											Peds[k].ActualPath = 1
											if Peds[k].SearchState == 2 then
												Peds[k].SearchState = 0
												Peds[k].SearchLowLevel = 1
											end
										end
										if Peds[k].Paths[Peds[k].ActualPath] ~= nil then
											Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
											Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
											Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
											TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, Peds[k].Target, 2.0, true, 0.1, 0.1, false, 0, true, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
											PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
											if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY")) ~= 7 then
												Peds[k].TaskState = 2
											end
										end
									end
								else
									if not ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 5.5, 5.5, 2.5, false, true, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
											if Peds[k].ActualPath > #Peds[k].Paths then
												Peds[k].ActualPath = 1
												if Peds[k].SearchState == 2 then
													Peds[k].SearchState = 0
													Peds[k].SearchLowLevel = 1
												end
											end
											if Peds[k].Paths[Peds[k].ActualPath] ~= nil then
												local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
												if Peds[k].Paths[Peds[k].ActualPath].Action ~= nil then
													if InsidePolygon(Polys1[Peds[k].Paths[Peds[k].ActualPath].PolyID], Pos) then
														Peds[k].ActualPath = Peds[k].ActualPath + 1
													end
												end
												local NewV3 = v3.new(Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
												local Sub = v3.sub(NewV3, Pos)
												local Rot = Sub:toRot()
												--ENTITY.SET_ENTITY_HEADING(Peds[k].Handle, Rot.z, 2)
												Dir = Rot:toDir()
												Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
												Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
												Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
												Peds[k].TaskCoords2.x = Peds[k].Paths[Peds[k].ActualPath].x + Dir.x * 2.0
												Peds[k].TaskCoords2.y = Peds[k].Paths[Peds[k].ActualPath].y + Dir.y * 2.0
												Peds[k].TaskCoords2.z = Peds[k].Paths[Peds[k].ActualPath].z + Dir.z * 2.0
												Peds[k].LastDistance = DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
												--TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, Peds[k].Target, 2.0, true, 0.1, 0.1, false, 0, true, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
												--TASK.TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if Peds[k].Paths[Peds[k].ActualPath].Action == nil then
													TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, 3.0, -1, 40000.0, 0.1)
												else
													TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 2.0, -1, 40000.0, 0.1)
												end
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) ~= 7 then
													Peds[k].TaskState = 3
													--Print("Straight")
												end
											end
										end
									else
										local HasSetTask = false
										local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
										local Distance3 = DistanceBetween(Pos.x, Pos.y, Pos.z, TargetPos.x, TargetPos.y, TargetPos.z)
										if Distance3 < 1.5 then
											if RequestControlOfEntity(Peds[k].Handle) then
												TASK.TASK_COMBAT_PED(Peds[k].Handle, Peds[k].Target, 201326592, 16)
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_COMBAT")) ~= 7 then
													--Print("Combat")
													Peds[k].TaskState = 4
												end
												HasSetTask = true
											end
										end
										if not HasSetTask then
											--if Distance3 < 5.5 then
												--if ENTITY.HAS_ENTITY_CLEAR_LOS_TO_ENTITY(Peds[k].Handle, Peds[k].Target, 17) then
												
												if RequestControlOfEntity(Peds[k].Handle) then
													if Peds[k].ActualPath > #Peds[k].Paths then
														Peds[k].ActualPath = 1
														if Peds[k].SearchState == 2 then
															Peds[k].SearchState = 0
															Peds[k].SearchLowLevel = 1
														end
													end
													if Peds[k].Paths[Peds[k].ActualPath] ~= nil then
														local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
														if Peds[k].Paths[Peds[k].ActualPath].Action ~= nil then
															if InsidePolygon(Polys1[Peds[k].Paths[Peds[k].ActualPath].PolyID], Pos) then
																Peds[k].ActualPath = Peds[k].ActualPath + 1
															end
														end
														local NewV3 = v3.new(Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
														local Sub = v3.sub(NewV3, Pos)
														local Rot = Sub:toRot()
														Dir = Rot:toDir()
														Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
														Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
														Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
														Peds[k].TaskCoords2.x = Peds[k].Paths[Peds[k].ActualPath].x + Dir.x * 1.0
														Peds[k].TaskCoords2.y = Peds[k].Paths[Peds[k].ActualPath].y + Dir.y * 1.0
														Peds[k].TaskCoords2.z = Peds[k].Paths[Peds[k].ActualPath].z + Dir.z * 1.0
														Peds[k].LastDistance = DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
														--TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, Peds[k].Target, 2.0, true, 0.1, 0.1, false, 0, true, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
														--TASK.TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
														if Peds[k].Paths[Peds[k].ActualPath].Action == nil then
															TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, 3.0, -1, 40000.0, 0.1)
														else
															TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 2.0, -1, 40000.0, 0.1)
														end
														PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
														if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) ~= 7 then
															Peds[k].TaskState = 3
															--Print("Straight")
														end
													end
												end
											--end
										end
									end
								end
							--end
							else
								if Peds[k].SearchState == 2 then
									Peds[k].SearchState = 0
									Peds[k].SearchLowLevel = 1
								end
							end
						end
						if Peds[k].TaskState == 2 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if Peds[k].Paths ~= nil then
									if Peds[k].SearchState == 2 then
										if Peds[k].TargetPoly ~= nil then
											local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
											if Peds[k].TargetInsideTargetPolygon then
												if not InsidePolygon(Polys1[Peds[k].TargetPoly], TargetPos) then
													--Peds[k].TaskState = 1
													if Peds[k].SearchState == 2 then
														Peds[k].SearchState = 0
													end
												end
											else
												if InsidePolygon(Polys1[Peds[k].TargetPoly], TargetPos) then
													--Peds[k].TaskState = 1
													if Peds[k].SearchState == 2 then
														Peds[k].SearchState = 0
													end
												end
											end
										else
											if Peds[k].SearchState == 2 then
												Peds[k].SearchState = 0
											end
										end
									end
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.15, 0.15, 100.0, false, false, 0) then
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
										end
									end
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.5, 0.5, 1.0, false, false, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											Peds[k].ActualPath = Peds[k].ActualPath + 1
											if Peds[k].ActualPath > #Peds[k].Paths then
												Peds[k].ActualPath = 1
												if Peds[k].SearchState == 2 then
													Peds[k].SearchState = 0
												end
												Peds[k].SearchLowLevel = 1
											end
											Peds[k].TaskState = 1
										end
									else
										Peds[k].TimeOut = Peds[k].TimeOut + 1
										if Peds[k].TimeOut > 1000 then
											if Peds[k].SearchState == 2 then
												if RequestControlOfEntity(Peds[k].Handle) then
													PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
													TASK.CLEAR_PED_TASKS(Peds[k].Handle)
													Peds[k].SearchState = 0
													Peds[k].TaskState = 1
												end
											end
										end
									end
									if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY")) == 7 then
										Peds[k].TaskState = 1
										--Print("No action")
									end
								else
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 1
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
									Peds[k].ActualPath = 1
									Peds[k].SearchLowLevel = 1
								end
							end
						end
						GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z,
						Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 255, 255, 255, 255)
						if Peds[k].Paths ~= nil then
							for i = Peds[k].ActualPath, #Peds[k].Paths-1 do
								GRAPHICS.DRAW_LINE(Peds[k].Paths[i].x, Peds[k].Paths[i].y, Peds[k].Paths[i].z,
								Peds[k].Paths[i+1].x, Peds[k].Paths[i+1].y, Peds[k].Paths[i+1].z, 255, 255, 255, 255)
							end
						end
						if Peds[k].TaskState == 3 then
							if Peds[k].Paths[Peds[k].ActualPath].Action ~= nil then
								if InsidePolygon(Polys1[Peds[k].Paths[Peds[k].ActualPath].PolyID], Pos) then
									Peds[k].ActualPath = Peds[k].ActualPath + 1
									Peds[k].TaskState = 1
								end
							end
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								local Distance2 = DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
								Peds[k].SameDistanceTick = Peds[k].SameDistanceTick + 1
								local HasSet = false
								if Distance2 < Peds[k].LastDistance then
									Peds[k].LastDistance = Distance2
									Peds[k].SameDistanceTick = 0
								end
								--Distance2 > Peds[k].LastDistance then
								if Peds[k].SameDistanceTick > 50 or math.floor(Distance2) > math.floor(Peds[k].LastDistance) then
									--Peds[k].TaskState = 1
									--Peds[k].ActualPath = Peds[k].ActualPath + 1
									--if Peds[k].ActualPath > #Peds[k].Paths then
									--	Peds[k].ActualPath = 1
									--	if Peds[k].SearchState == 2 then
									--		Peds[k].SearchState = 0
									--	end
									--end
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 1
									end
								end
								if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) == 7 then
									if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_CLIMB")) == 7 then
										if RequestControlOfEntity(Peds[k].Handle) then
											Peds[k].TaskState = 1
											TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, 3.0, -1, 40000.0, 0.1)
										end
									end
								end
								if not HasSet then
									if ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 5.0, 5.0, 2.5, false, true, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											Peds[k].TaskState = 1
											--HasSet = true
											Peds[k].SameDistanceTick = 0
										end
									end
								end
								local R = 2.0
								if Peds[k].Paths[Peds[k].ActualPath].Action ~= nil then
									R = 1.0
								end
								if not HasSet then
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, R, R, 1.0, false, false, 0) or
									ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, R, R, 1.0, false, false, 0) then
										if Peds[k].Paths[Peds[k].ActualPath].Action ~= nil then
											if is_bit_set(Peds[k].Paths[Peds[k].ActualPath].Action, FlagBitNames.Jump) then
												--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
												--TASK.CLEAR_PED_TASKS_IMMEDIATELY(Peds[k].Handle)
												ENTITY.SET_ENTITY_HEADING(Peds[k].Handle, Peds[k].Paths[Peds[k].ActualPath].Heading)
												--TASK.TASK_JUMP(Peds[k].Handle, false, false, false)
												TASK.TASK_CLIMB(Peds[k].Handle, false)
												--if PED.IS_PED_CLIMBING(Peds[k].Handle) or PED.IS_PED_JUMPING(Peds[k].Handle) then
												--if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_CLIMB")) ~= 7 then
													Peds[k].JumpDelay = 10
													Peds[k].TaskState = 5
												--end
												
											end
										else
											Peds[k].ActualPath = Peds[k].ActualPath + 1
											if Peds[k].ActualPath > #Peds[k].Paths then
												Peds[k].ActualPath = 1
												if Peds[k].SearchState == 2 then
													Peds[k].SearchState = 0
													Peds[k].SearchLowLevel = 1
												end
											end
											Peds[k].TaskState = 1
											Peds[k].SameDistanceTick = 0
										end
										
									end
								end
							else
								Peds[k].TaskState = 0
								Peds[k].Target = 0
							end
						end
						if Peds[k].TaskState == 4 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if not ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 2.5, 2.5, 2.5, false, true, 0) then
									if RequestControlOfEntity(Peds[k].Handle) then
										PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										Peds[k].TaskState = 1
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
											Peds[k].SearchLowLevel = 1
										end
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
								end
							end
						end
						if Peds[k].TaskState == 5 then
							if not PED.IS_PED_CLIMBING(Peds[k].Handle) and not PED.IS_PED_JUMPING(Peds[k].Handle) then
								Peds[k].JumpDelay = Peds[k].JumpDelay - 1
								if Peds[k].JumpDelay <= 0 then
								--if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_CLIMB")) == 7 then
									Peds[k].ActualPath = Peds[k].ActualPath + 1
									if Peds[k].ActualPath > #Peds[k].Paths then
										Peds[k].ActualPath = 1
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
											Peds[k].SearchLowLevel = 1
										end
									end
									Peds[k].TaskState = 1
									Peds[k].SameDistanceTick = 0
								end
							end
						end
						if Peds[k].TaskState == 6 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 1.0, 1.0, 2.5, false, true, 0) or not CanIntersectEntity(Pos, ENTITY.GET_ENTITY_COORDS(Peds[k].Target, Peds[k].Paths, Peds[k].ActualPath)) then
									if RequestControlOfEntity(Peds[k].Handle) then
										PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										Peds[k].TaskState = 1
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
											Peds[k].SearchLowLevel = 1
										end
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
								end
							end
						end
					else
						if ENTITY.DOES_ENTITY_EXIST(Peds[k].Handle) then
							if ENTITY.IS_ENTITY_DEAD(Peds[k].Handle) then
								if RequestControlOfEntity(Peds[k].Handle) then
									set_entity_as_no_longer_needed(Peds[k].Handle)
									HandlesT[Peds[k].Handle] = nil
									table.remove(Peds, k)
								end
							end
						else
							HandlesT[Peds[k].Handle] = nil
							table.remove(Peds, k)
						end
					end
				end
			end
			Wait()
		end
	end
end)

function RaycastFromCamera(PlayerPed, Distance, Flags)
	local FlagBits = -1
	if Flags ~= nil then
		FlagBits = Flags
	end
	local HitCoords = v3.new()
	local CamRot = CAM.GET_GAMEPLAY_CAM_ROT(2)
	local FVect = CamRot:toDir()
	local PPos = CAM.GET_GAMEPLAY_CAM_COORD()
	local AdjustedX = PPos.x + FVect.x * Distance
	local AdjustedY = PPos.y + FVect.y * Distance
	local AdjustedZ = PPos.z + FVect.z * Distance
	local DidHit = memory.alloc(1)
	local EndCoords = v3.new()
	local Normal = v3.new()
	local HitEntity = memory.alloc_int()
	
	local Handle = SHAPETEST.START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE(
		PPos.x, PPos.y, PPos.z,
		AdjustedX, AdjustedY, AdjustedZ,
		FlagBits,
		PlayerPed, 7
	)
	SHAPETEST.GET_SHAPE_TEST_RESULT(Handle, DidHit, EndCoords, Normal, HitEntity)
	if memory.read_byte(DidHit) ~= 0 then
		HitCoords.x = EndCoords.x
		HitCoords.y = EndCoords.y
		HitCoords.z = EndCoords.z
	else
		HitCoords.x = AdjustedX
		HitCoords.y = AdjustedY
		HitCoords.z = AdjustedZ
	end
	return HitCoords, memory.read_byte(DidHit) ~= 0, memory.read_int(HitEntity)
end

function RaycastFromCamHandle(Cam, PlayerPed, Distance, Flags)
	local FlagBits = -1
	if Flags ~= nil then
		FlagBits = Flags
	end
	local HitCoords = v3.new()
	local CamRot = CAM.GET_CAM_ROT(Cam, 2)
	local FVect = CamRot:toDir()
	local PPos = CAM.GET_CAM_COORD(Cam)
	local AdjustedX = PPos.x + FVect.x * Distance
	local AdjustedY = PPos.y + FVect.y * Distance
	local AdjustedZ = PPos.z + FVect.z * Distance
	local DidHit = memory.alloc(1)
	local EndCoords = v3.new()
	local Normal = v3.new()
	local HitEntity = memory.alloc_int()
	
	local Handle = SHAPETEST.START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE(
		PPos.x, PPos.y, PPos.z,
		AdjustedX, AdjustedY, AdjustedZ,
		FlagBits,
		PlayerPed, 7
	)
	SHAPETEST.GET_SHAPE_TEST_RESULT(Handle, DidHit, EndCoords, Normal, HitEntity)
	if memory.read_byte(DidHit) ~= 0 then
		HitCoords.x = EndCoords.x
		HitCoords.y = EndCoords.y
		HitCoords.z = EndCoords.z
	else
		HitCoords.x = AdjustedX
		HitCoords.y = AdjustedY
		HitCoords.z = AdjustedZ
	end
	return HitCoords, memory.read_byte(DidHit) ~= 0, memory.read_int(HitEntity)
end

function InitClosestPolygonsTable(ArgsT)
	ArgsT.CurrentTableIndex = 1
	ArgsT.PolygonsT = {}
	ArgsT.PolygonIDs = {}
	ArgsT.PolygonsT2 = {}
	ArgsT.Pos = {x = 0.0, y = 0.0, z = 0.0}
	ArgsT.CurrentPolysIndex = 1
end

function GetClosestPolygons(ArgsT, Amount, MinDistance)
	local Pos = ArgsT.Pos
	for i = 1, 30 do
		if ArgsT.CurrentTableIndex <= #ArgsT.PolygonsT2 then
			local ID = ArgsT.CurrentTableIndex
			local Removed = false
			if DistanceBetween(Pos.x, Pos.y, Pos.z, ArgsT.PolygonsT2[ID].Pos.x, ArgsT.PolygonsT2[ID].Pos.y, ArgsT.PolygonsT2[ID].Pos.z) > MinDistance then
				ArgsT.PolygonIDs[ArgsT.PolygonsT2[ID].ID] = nil
				table.remove(ArgsT.PolygonsT, ID)
				table.remove(ArgsT.PolygonsT2, ID)
				ArgsT.CurrentTableIndex = ArgsT.CurrentTableIndex - 1
				if ArgsT.CurrentTableIndex < 1 then
					ArgsT.CurrentTableIndex = 1
				end
				Removed = true
			end
			if not Removed then
				ArgsT.CurrentTableIndex = ArgsT.CurrentTableIndex + 1
			end
		else
			ArgsT.CurrentTableIndex = 1
		end
	end
	for i = 1, 100 do
		if #ArgsT.PolygonsT < Amount then
			if ArgsT.CurrentPolysIndex <= #Polys1 then
				local ID = ArgsT.CurrentPolysIndex
				if DistanceBetween(Pos.x, Pos.y, Pos.z, Polys1[ID].Center.x, Polys1[ID].Center.y, Polys1[ID].Center.z) <= MinDistance then
					if ArgsT.PolygonIDs[Polys1[ID].ID] == nil then
						ArgsT.PolygonIDs[Polys1[ID].ID] = Polys1[ID].ID
						ArgsT.PolygonsT[#ArgsT.PolygonsT+1] = Polys1[ID]
						ArgsT.PolygonsT2[#ArgsT.PolygonsT2+1] = {Pos = {x = Polys1[ID].Center.x, y = Polys1[ID].Center.y, z = Polys1[ID].Center.z}, ID = Polys1[ID].ID}
						
					end
				end
				ArgsT.CurrentPolysIndex = ArgsT.CurrentPolysIndex + 1
			else
				ArgsT.CurrentPolysIndex = 1
			end
		end
	end
end
-- Representar um ponto como uma tabela
function vec3(x, y, z)
    return {x = x, y = y, z = z}
end

-- Funções de operações vetoriais
function dot(v1, v2)
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
end

function sub(v1, v2)
    return vec3(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
end

function add(v1, v2)
    return vec3(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
end

function mul(v, scalar)
    return vec3(v.x * scalar, v.y * scalar, v.z * scalar)
end

function length(v)
    return math.sqrt(dot(v, v))
end

function project_point_on_line(p, a, b)
    local ab = sub(b, a)
    local ap = sub(p, a)
    local t = dot(ap, ab) / dot(ab, ab)
    t = math.max(0, math.min(1, t))  -- Clamping t to the [0, 1] range
    return add(a, mul(ab, t))
end

-- Função para encontrar o ponto mais próximo no triângulo
function closest_point_on_triangle(p, a, b, c)
    local closest = project_point_on_line(p, a, b)
    local min_dist = length(sub(p, closest))

    local q = project_point_on_line(p, b, c)
    local dist = length(sub(p, q))
    if dist < min_dist then
        closest = q
        min_dist = dist
    end

    q = project_point_on_line(p, c, a)
    dist = length(sub(p, q))
    if dist < min_dist then
        closest = q
    end

    return closest
end

-- Função para verificar se duas linhas se intersectam
function linesIntersect(p1, p2, q1, q2)
    local function ccw(A, B, C)
        return (C.y - A.y) * (B.x - A.x) > (B.y - A.y) * (C.x - A.x)
    end
    return ccw(p1, q1, q2) ~= ccw(p2, q1, q2) and ccw(p1, p2, q1) ~= ccw(p1, p2, q2)
end

function is_path_clear(start_poly, end_poly, polys)
    -- Função para verificar se dois segmentos de linha se intersectam
    local function do_lines_intersect(p1, p2, p3, p4)
        local function ccw(A, B, C)
            return (C.y - A.y) * (B.x - A.x) > (B.y - A.y) * (C.x - A.x)
        end
        return ccw(p1, p3, p4) ~= ccw(p2, p3, p4) and ccw(p1, p2, p3) ~= ccw(p1, p2, p4)
    end

    -- Verifica cada polígono
    for i, poly in ipairs(polys) do
        -- Verifica cada aresta do polígono
		local Count = 0
        for j = 1, #poly do
            local next_j = (j % #poly) + 1
            local p1 = poly[j]
            local p2 = poly[next_j]
            if do_lines_intersect(start_poly, end_poly, p1, p2) then
                Count = Count + 1
            end
        end
		if Count <= 0 then
			return false
		end
    end
    return true
end

-- Função para calcular a distância entre dois pontos no espaço 3D
local function distance(p1, p2)
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Função para calcular a projeção de um ponto p em uma linha definida por v1 e v2 no espaço 3D
local function project_point_on_line(v1, v2, p)
    local vx = v2.x - v1.x
    local vy = v2.y - v1.y
    local vz = v2.z - v1.z
    local ux = p.x - v1.x
    local uy = p.y - v1.y
    local uz = p.z - v1.z

    local dot_product = ux * vx + uy * vy + uz * vz
    local length_sq = vx * vx + vy * vy + vz * vz
    local param = dot_product / length_sq

    if param < 0 then
        param = 0
    elseif param > 1 then
        param = 1
    end

    return { x = v1.x + param * vx, y = v1.y + param * vy, z = v1.z + param * vz }
end

-- Função principal para encontrar o ponto mais próximo no espaço 3D
function closest_point_on_polygon(polygon, point)
    local closest_point = nil
    local min_distance = nil

    for i = 1, #polygon do
        local v1 = polygon[i]
        local v2 = polygon[(i % #polygon) + 1]

        local proj = project_point_on_line(v1, v2, point)
        local dist = distance(proj, point)

        if not min_distance or dist < min_distance then
            min_distance = dist
            closest_point = proj
        end
    end

    return closest_point
end


function ShowLinesEdit()
	if not ShowLinesStarted then
		ShowLinesStarted = true
		util.create_thread(function()
			while #Vertexes_1 > 0 do
				if #Vertexes_1 > 1 then
					for k = 1, #Vertexes_1 do
						if k == #Vertexes_1 then
							GRAPHICS.DRAW_LINE(Vertexes_1[k].x, Vertexes_1[k].y, Vertexes_1[k].z,
							Vertexes_1[1].x, Vertexes_1[1].y, Vertexes_1[1].z, 255, 255, 255, 150)
						else
							GRAPHICS.DRAW_LINE(Vertexes_1[k].x, Vertexes_1[k].y, Vertexes_1[k].z,
							Vertexes_1[k+1].x, Vertexes_1[k+1].y, Vertexes_1[k+1].z, 255, 255, 255, 150)
						end
					end
				end
				Wait()
			end
			ShowLinesStarted = false
		end)
	end
end

-- Função para mover a linha em pequenos passos e verificar se a ponta está sempre dentro do polígono
function LineTravelToPoint(pontoInicial, pontoAlvo, poligono, passos)
	local deltaX = (pontoAlvo.x - pontoInicial.x) / passos
	local deltaY = (pontoAlvo.y - pontoInicial.y) / passos
	local pontoAtual = {x = pontoInicial.x, y = pontoInicial.y}
	
	for i = 1, passos do
		pontoAtual.x = pontoAtual.x + deltaX
		pontoAtual.y = pontoAtual.y + deltaY
		if not InsidePolygon(poligono, pontoAtual) then
			return false
		end
	end
	return true
end

function HitClimbableObject(Entity)
	local Distance = 1.0
	if ENTITY.GET_ENTITY_SPEED_VECTOR(Entity, true).y < 0.05 then
		local FVect, RVect, UpVect, Pos = v3.new(), v3.new(), v3.new(), v3.new()
		ENTITY.GET_ENTITY_MATRIX(Entity, FVect, RVect, UpVect, Pos)
		local Vect1 = {
			x = Pos.x + ((FVect.x * Distance)),
			y = Pos.y + ((FVect.y * Distance)),
			z = Pos.z + ((FVect.z * Distance)) + 0.5
		}
		--local Vect2 = {
		--	x = Pos.x + ((FVect.x * Distance) + (RVect.x * -1.0)),
		--	y = Pos.y + ((FVect.y * Distance) + (RVect.y * -1.0)),
		--	z = Pos.z + ((FVect.z * Distance) + (RVect.z * -1.0)) + 0.5
		--}
		--local Vect3 = {
		--	x = Pos.x + ((FVect.x * Distance) + (RVect.x * 1.0)),
		--	y = Pos.y + ((FVect.y * Distance) + (RVect.y * 1.0)),
		--	z = Pos.z + ((FVect.z * Distance) + (RVect.z * 1.0)) + 0.5
		--}
		Pos.z = Pos.z - 0.5
		local DidHit, HitCoords, HitEntity = ShapeTestNav(Entity, Pos, Vect1, -1)
		--local DidHit2, HitCoords2, HitEntity2 = ShapeTestNav(Entity, Pos, Vect2, -1)
		--local DidHit3, HitCoords3, HitEntity3 = ShapeTestNav(Entity, Pos, Vect3, -1)
		if DidHit then
			if HitEntity ~= 0 then
				if ENTITY.IS_ENTITY_AN_OBJECT(HitEntity) then
					return true
				end
			end
		end
		--if DidHit2 then
		--	if HitEntity2 ~= 0 then
		--		if ENTITY.IS_ENTITY_AN_OBJECT(HitEntity2) then
		--			return true
		--		end
		--	end
		--end
		--if DidHit3 then
		--	if HitEntity3 ~= 0 then
		--		if ENTITY.IS_ENTITY_AN_OBJECT(HitEntity3) then
		--			return true
		--		end
		--	end
		--end
	end
	return false
end

function JumpPassThroughHole(Entity)
	local Distance = 1.0
	local FVect, RVect, UpVect, Pos = v3.new(), v3.new(), v3.new(), v3.new()
	ENTITY.GET_ENTITY_MATRIX(Entity, FVect, RVect, UpVect, Pos)
	local Vect1 = {
		x = Pos.x + ((FVect.x * Distance)),
		y = Pos.y + ((FVect.y * Distance)),
		z = Pos.z + ((FVect.z * Distance))
	}
	local Vect2 = {
		x = Pos.x + ((FVect.x * Distance)),
		y = Pos.y + ((FVect.y * Distance)),
		z = Pos.z + ((FVect.z * Distance)) - 3.3
	}
	--GRAPHICS.DRAW_LINE(Vect1.x, Vect1.y, Vect1.z, Vect2.x, Vect2.y, Vect2.z, 255, 0, 0, 255)
	local DidHit = ShapeTestNav(Entity, Vect1, Vect2, -1)
	if not DidHit then
		return true
	end
	return false
end

menu.toggle_loop(TestMenu, "Poly Point Test", {}, "", function(Toggle)
	local Point = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	local PolyID = GetClosestPolygon(Polys1, Point, false, 1, 0)
	local ClosestPoint = closest_point_on_polygon(Polys1[PolyID], Point)
	GRAPHICS.DRAW_MARKER(28, ClosestPoint.x,
	ClosestPoint.y, ClosestPoint.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 150, 0, 0, 100, 0, false, 2, false, 0, 0, false)
end)

-- Função para desenhar o polígono (exemplo)
function DrawPolygon(vertices)
    for i = 1, #vertices - 1 do
        GRAPHICS.DRAW_POLY(vertices[i].x, vertices[i].y, vertices[i].z, vertices[i+1].x, vertices[i+1].y, vertices[i+1].z, vertices[1].x, vertices[1].y, vertices[1].z, 255, 255, 255, 150)
    end
    -- Fecha o polígono
    --GRAPHICS.DRAW_POLY(vertices[#vertices].x, vertices[#vertices].y, vertices[#vertices].z, vertices[1].x, vertices[1].y, vertices[1].z, vertices[2].x, vertices[2].y, vertices[2].z, 255, 255, 255, 150)
end

-- Função para desenhar linhas de conexão entre vértices próximos
function DrawConnections(verticesList, threshold)
    for i = 1, #verticesList do
        for j = i + 1, #verticesList do
            local vertices1 = verticesList[i]
            local vertices2 = verticesList[j]
            for _, v1 in ipairs(vertices1) do
                for _, v2 in ipairs(vertices2) do
                    if DistanceBetween(v1.x, v1.y, v1.z, v2.x, v2.y, v2.z) < threshold then
                        GRAPHICS.DRAW_LINE(v1.x, v1.y, v1.z, v2.x, v2.y, v2.z, 255, 255, 255, 255)
						--DrawCurve(v1, v2, 5)
                    end
                end
            end
        end
    end
end

function DrawCurve(v1, v2, segments)
    for i = 0, segments do
        local t = i / segments
        local x = (1 - t) * v1.x + t * v2.x
        local y = (1 - t) * v1.y + t * v2.y
        local z = (1 - t) * v1.z + t * v2.z
        local nx = (1 - (t + 1/segments)) * v1.x + (t + 1/segments) * v2.x
        local ny = (1 - (t + 1/segments)) * v1.y + (t + 1/segments) * v2.y
        local nz = (1 - (t + 1/segments)) * v1.z + (t + 1/segments) * v2.z
        GRAPHICS.DRAW_LINE(x, y, z, nx, ny, nz, 255, 255, 255, 255)
    end
end

-- Função para dividir as arestas de um objeto
function DivideEdges(vertices, divisions)
    local dividedVertices = {}
    
    for i = 1, #vertices do
        local j = (i % #vertices) + 1
        local v1 = vertices[i]
        local v2 = vertices[j]

        -- Adicionar o vértice inicial
        table.insert(dividedVertices, v1)

        -- Calcular e adicionar os vértices divididos
        for k = 1, divisions do
            local t = k / (divisions + 1)
            local dividedVertex = {
                x = (1 - t) * v1.x + t * v2.x,
                y = (1 - t) * v1.y + t * v2.y,
                z = (1 - t) * v1.z + t * v2.z
			}
            table.insert(dividedVertices, dividedVertex)
        end
    end
    
    return dividedVertices
end

-- Função para obter os vértices da superfície superior de um objeto
function GetObjectVertices(object)
	local Model = ENTITY.GET_ENTITY_MODEL(object)
    local min, max = v3.new(), v3.new()
	MISC.GET_MODEL_DIMENSIONS(Model, min, max)
    local rotation = ENTITY.GET_ENTITY_ROTATION(object, 2)
    min.x = min.x * 0.990
    min.y = min.y * 0.990
    max.x = max.x * 0.990
    max.y = max.y * 0.990
	local vertices = {}
	Print("x= "..rotation.x .. " y= "..rotation.y)
    -- Ajustar os vértices com base na rotação
    if math.abs(rotation.x) < 45 and math.abs(rotation.y) < 45 then
        -- Superfície superior está virada para cima
        vertices = {
            {x = min.x, y = min.y, z = max.z},
            {x = max.x, y = min.y, z = max.z},
            {x = max.x, y = max.y, z = max.z},
            {x = min.x, y = max.y, z = max.z}
        }
    elseif math.abs(rotation.x) > 135 or math.abs(rotation.y) > 135 then
        -- Superfície inferior está virada para cima
        vertices = {
            {x = min.x, y = min.y, z = min.z},
            {x = max.x, y = min.y, z = min.z},
            {x = max.x, y = max.y, z = min.z},
            {x = min.x, y = max.y, z = min.z}
        }
    elseif math.abs(rotation.x) > 45 and math.abs(rotation.x) < 135 then
        if rotation.x > 0 then
            -- Lado lateral está virado para cima
            vertices = {
                {x = min.x, y = min.z, z = max.y},
                {x = max.x, y = min.z, z = max.y},
                {x = max.x, y = max.z, z = max.y},
                {x = min.x, y = max.z, z = max.y}
            }
        else
            -- Outro lado lateral está virado para cima
            vertices = {
                {x = min.x, y = min.z, z = min.y},
                {x = max.x, y = min.z, z = min.y},
                {x = max.x, y = max.z, z = min.y},
                {x = min.x, y = max.z, z = min.y}
            }
        end
    elseif math.abs(rotation.y) > 45 and math.abs(rotation.y) < 135 then
        if rotation.y > 0 then
            -- Lado frontal está virado para cima
            vertices = {
                {x = min.x, y = max.z, z = min.y},
                {x = max.x, y = max.z, z = min.y},
                {x = max.x, y = max.z, z = max.y},
                {x = min.x, y = max.z, z = max.y}
            }
        else
            -- Lado traseiro está virado para cima
            vertices = {
                {x = min.x, y = min.z, z = min.y},
                {x = max.x, y = min.z, z = min.y},
                {x = max.x, y = min.z, z = max.y},
                {x = min.x, y = min.z, z = max.y}
            }
        end
    end
	-- Dividir as arestas
    local dividedEdges = DivideEdges(vertices, 0)

    return dividedEdges
end

-- Função para desenhar polígonos de conexão entre vértices próximos
function DrawConnectionPolygons(verticesList, threshold)
    for i = 1, #verticesList do
        for j = i + 1, #verticesList do
            local vertices1 = verticesList[i]
            local vertices2 = verticesList[j]
            
            -- Variáveis para armazenar vértices mais próximos
            local closestPairs = {}

            -- Encontre os vértices mais próximos
            for _, v1 in ipairs(vertices1) do
                for _, v2 in ipairs(vertices2) do
                    local dist = DistanceBetween(v1.x, v1.y, v1.z, v2.x, v2.y, v2.z)
                    if dist < threshold then
                        table.insert(closestPairs, {v1 = v1, v2 = v2})
                    end
                end
            end

            -- Desenhar polígonos de conexão se encontrarmos ao menos dois pares de vértices próximos
            if #closestPairs >= 2 then
                local v1_1 = closestPairs[1].v1
                local v2_1 = closestPairs[1].v2
                local v1_2 = closestPairs[2].v1
                local v2_2 = closestPairs[2].v2
                

                --GRAPHICS.DRAW_POLY(v1_1.x, v1_1.y, v1_1.z, v2_1.x, v2_1.y, v2_1.z, v1_2.x, v1_2.y, v1_2.z, 255, 255, 255, 150)
                --GRAPHICS.DRAW_POLY(v1_2.x, v1_2.y, v1_2.z, v2_1.x, v2_1.y, v2_1.z, v2_2.x, v2_2.y, v2_2.z, 255, 255, 255, 150)
				return v1_1, v2_1, v1_2, v2_2
            end
        end
    end
	return nil
end

function vector_add(v1, v2)
    return { x = v1.x + v2.x, y = v1.y + v2.y, z = v1.z + v2.z }
end

function vector_sub(v1, v2)
    return { x = v1.x - v2.x, y = v1.y - v2.y, z = v1.z - v2.z }
end

function vector_mul(v, scalar)
    return { x = v.x * scalar, y = v.y * scalar, z = v.z * scalar }
end

function vector_dot(v1, v2)
    return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
end

function vector_length(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

function GetClosestPointOnEdge(v1, v2, target)
    local edge = vector_sub(v2, v1)
    local target_vec = vector_sub(target, v1)
    local t = vector_dot(target_vec, edge) / vector_dot(edge, edge)
    t = math.max(0, math.min(1, t))
    return vector_add(v1, vector_mul(edge, t))
end

-- Função para adicionar vértices necessários para conectar os objetos
function AddNecessaryVertices(verticesList)
    local newVertices = {}

    for i = 1, #verticesList do
        for j = i + 1, #verticesList do
            local vertices1 = verticesList[i]
            local vertices2 = verticesList[j]

            for _, v1 in ipairs(vertices1) do
                for k = 1, #vertices2 do
                    local v2_1 = vertices2[k]
                    local v2_2 = vertices2[(k % #vertices2) + 1]

                    local closestPoint = GetClosestPointOnEdge(v2_1, v2_2, v1)
					if vector_length(vector_sub(closestPoint, v2_2)) > 2.0 and vector_length(vector_sub(closestPoint, v2_1)) > 2.0 then
						if vector_length(vector_sub(closestPoint, v1)) < 2.0 then
							table.insert(newVertices, closestPoint)
							table.insert(vertices2, k + 1, closestPoint) -- Inserir no local correto
							break
						end
					end
                end
            end
        end
    end

    for _, newVertex in ipairs(newVertices) do
        table.insert(verticesList, newVertex)
    end
end

function CreateBridgePolygons(verticesList, threshold)
    local bridgePolygons = {}

    for i = 1, #verticesList do
        for j = i + 1, #verticesList do
            local vertices1 = verticesList[i]
            local vertices2 = verticesList[j]

            local closestPairs = {}

            -- Encontrar os pares de vértices mais próximos
            for _, v1 in ipairs(vertices1) do
                for _, v2 in ipairs(vertices2) do
                    if vector_length(vector_sub(v1, v2)) < threshold then
                        table.insert(closestPairs, { v1, v2 })
                    end
                end
            end

            -- Criar polígonos de conexão para todos os pares de vértices próximos
            for p = 1, #closestPairs - 1 do
                local pair1 = closestPairs[p]
                local pair2 = closestPairs[p + 1]

                local newPolygon = {
                    pair1[1],
                    pair1[2],
                    pair2[2],
                    pair2[1]
                }

                table.insert(bridgePolygons, newPolygon)
            end
        end
    end

    return bridgePolygons
end

-- Função para aplicar rotação a um vetor
function ApplyRotation(vertex, rotation)
    local x, y, z = vertex.x, vertex.y, vertex.z

    -- Aplicar rotação em X
    local cosX, sinX = math.cos(math.rad(rotation.x)), math.sin(math.rad(rotation.x))
    y, z = y * cosX - z * sinX, y * sinX + z * cosX

    -- Aplicar rotação em Y
    local cosY, sinY = math.cos(math.rad(rotation.y)), math.sin(math.rad(rotation.y))
    x, z = x * cosY + z * sinY, -x * sinY + z * cosY

    -- Aplicar rotação em Z
    local cosZ, sinZ = math.cos(math.rad(rotation.z)), math.sin(math.rad(rotation.z))
    x, y = x * cosZ - y * sinZ, x * sinZ + y * cosZ

    return { x = x, y = y, z = z }
end

-- Função para obter os vértices da superfície do objeto
function GetSurfaceVertices(object)
	local Model = ENTITY.GET_ENTITY_MODEL(object)
    local min, max = v3.new(), v3.new()
	MISC.GET_MODEL_DIMENSIONS(Model, min, max)
    local rotation = ENTITY.GET_ENTITY_ROTATION(object, 2)

    local vertices = {
        { x = min.x, y = min.y, z = max.z },
        { x = max.x, y = min.y, z = max.z },
        { x = max.x, y = max.y, z = max.z },
        { x = min.x, y = max.y, z = max.z }
    }

    -- Aplicar rotação aos vértices
    for i, vertex in ipairs(vertices) do
        vertices[i] = ApplyRotation(vertex, rotation)
    end

    -- Ajustar vértices com base na posição do objeto
	local Pos = ENTITY.GET_ENTITY_COORDS(object)
    for i, vertex in ipairs(vertices) do
        vertices[i] = vector_add(vertex, {x = Pos.x, y = Pos.y, z = Pos.z})
    end

    return vertices
end


function AddPolysFromObjects(Objs)
	local Vertexes = {}
	for k = 1, #Objs do
		local Vertexes_ = GetObjectVertices(Objs[k])
		local Offsets = {}
		for j = 1, #Vertexes_ do
			local Offset = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Objs[k], Vertexes_[j].x, Vertexes_[j].y, Vertexes_[j].z)
			Offsets[#Offsets+1] = {x = Offset.x, y = Offset.y, z = Offset.z}
		end
		Vertexes[#Vertexes+1] = {Handle = Objs[k], Vertexes = Offsets}
	end
	local NewVertexes = {}
	for k = 1, #Vertexes do
		for i = 1, #Vertexes do
			if k ~= i then
				local VertexList = {Vertexes[k].Vertexes, Vertexes[i].Vertexes}
				AddNecessaryVertices(VertexList)
				--local V1, V2, V3, V4 = DrawConnectionPolygons(VertexList, 2.0)
				--if V1 ~= nil then
				--	NewVertexes[#NewVertexes+1] = {V1, V2, V4, V3}
				--end
			end
		end
	end
	local Vertexes2 = {}
	for k = 1, #Vertexes do
		Vertexes2[#Vertexes2+1] = Vertexes[k].Vertexes
	end
	local Bridges = CreateBridgePolygons(Vertexes2, 2.0)
	for k = 1, #Vertexes do
		Polys1[#Polys1+1] = {}
		for j = 1, #Vertexes[k].Vertexes do
			Polys1[#Polys1][#Polys1[#Polys1]+1] = Vertexes[k].Vertexes[j]
		end
	end
	--for rounds = 1, 100 do
	--	local BreakLoop = false
	--	for k = 1, #NewVertexes do
	--		if NewVertexes[k] ~= nil then
	--			for j = 1, #NewVertexes[k] do
	--				for i = 1, #NewVertexes do
	--					if NewVertexes[i] ~= nil then
	--						for a = 1, #NewVertexes[i] do
	--							if NewVertexes[i] ~= nil then
	--								if k ~= i then
	--									if NewVertexes[k][j].x == NewVertexes[i][a].x and NewVertexes[k][j].y == NewVertexes[i][a].y
	--									and NewVertexes[k][j].z == NewVertexes[i][a].z then
	--										--table.remove(NewVertexes, k)
	--										Print(i)
	--										BreakLoop = true
	--									end
	--								end
	--							end
	--						end
	--					end
	--				end
	--			end
	--		end
	--	end
	--	if not BreakLoop then
	--		--Print(rounds)
	--		--break
	--	end
	--end

	for k = 1, #Bridges do
		Polys1[#Polys1+1] = {}
		for j = 1, #Bridges[k] do
			Polys1[#Polys1][#Polys1[#Polys1]+1] = Bridges[k][j]
		end
	end
	SetAllPolysNeighboors()
end

menu.action(TestMenu, "All Objects Poly Add", {}, "", function(Toggle)
	local Objs = {}
	util.spoof_script("fm_mission_controller", function()
		for i = 1, 200 do
			local Handle = memory.read_int(memory.script_local("fm_mission_controller", 7368+i))
			if Handle ~= 0 then
				Objs[#Objs+1] = Handle
			end
		end
	end)
	AddPolysFromObjects(Objs)
end)

-- Função para escanear uma célula
function scanCell(center, cellSize, numRays)
    local vertices = {}
    local attempts = 0

    while #vertices < 3 and attempts < 5 do
        vertices = {}
        local angleIncrement = 2 * math.pi / numRays
        for i = 0, numRays - 1 do
            local angle = i * angleIncrement
            local x = center.x + cellSize * math.cos(angle)
            local y = center.y + cellSize * math.sin(angle)
            local endPoint = v3.new(x, y, center.z)

            --local rayHandle = StartShapeTestRay(center.x, center.y, center.z, endPoint.x, endPoint.y, endPoint.z, -1, -1, 7)
            local hit, hitPos, _, _ = ShapeTestNav(0, center, endPoint, -1)

            if hit then
                table.insert(vertices, hitPos)
            end
        end
        numRays = numRays + 4 -- Incrementar o número de raycasts para tentar obter mais vértices
        attempts = attempts + 1
    end

    return vertices
end

-- Função para escanear a área completa
function scanArea(center, areaSize, cellSize, numRays)
    local polygons = {}
    local halfSize = areaSize / 2

    for x = -halfSize, halfSize, cellSize do
        for y = -halfSize, halfSize, cellSize do
            local cellCenter = v3.new(center.x + x, center.y + y, center.z)
            local vertices = scanCell(cellCenter, cellSize, numRays)

            if #vertices >= 3 then
				local polygon = {}
				for k = 1, #vertices do
					polygon[#polygon+1] = {x = vertices[k].x, y = vertices[k].y, z = vertices[k].z}
				end
                table.insert(polygons, polygon)
            end
        end
    end

    return polygons
end

-- Função para verificar se uma célula está vazia
function isCellEmpty(center, cellSize, numRays)
    local vertices = scanCell(center, cellSize, numRays)
    return #vertices < 3
end

-- Função para preencher lacunas
function fillGaps(polygons, center, areaSize, cellSize, numRays)
    local halfSize = areaSize / 2

    for x = -halfSize, halfSize, cellSize do
        for y = -halfSize, halfSize, cellSize do
            local cellCenter = v3.new(center.x + x, center.y + y, center.z)
            if isCellEmpty(cellCenter, cellSize, numRays) then
                local vertices = scanCell(cellCenter, cellSize, numRays)
                if #vertices >= 3 then
                    local polygon = {}
					for k = 1, #vertices do
						polygon[#polygon+1] = {x = vertices[k].x, y = vertices[k].y, z = vertices[k].z}
					end
                    table.insert(polygons, polygon)
                end
            end
        end
    end
end

-- Função principal para gerar a malha de navegação
function generateNavigationMesh(center, areaSize, cellSize, numRays)
    local polygons = scanArea(center, areaSize, cellSize, numRays)
    fillGaps(polygons, center, areaSize, cellSize, numRays)
    return polygons
end

-- Função para determinar se dois polígonos são vizinhos
function arePolygonsNeighbors(poly1, poly2, cellSize)
    for _, v1 in ipairs(poly1) do
        for _, v2 in ipairs(poly2) do
            local distance = SYSTEM.VDIST2(v1.x, v1.y, v1.z, v2.x, v2.y, v2.z)
            if distance < cellSize then
                return true
            end
        end
    end
    return false
end

-- Função para verificar se dois vértices são próximos
function areVerticesClose(v1, v2, threshold)
    return SYSTEM.VDIST2(v1.x, v1.y, v1.z, v2.x, v2.y, v2.z) < threshold^2
end

-- Função para verificar colisão entre dois vértices usando raycast
function isLineOfSightClear(v1, v2)
    local hit, _, _, _ = ShapeTestNav(0, v1, v2, -1)
    return not hit
end

-- Função para preencher lacunas entre polígonos próximos com polígonos de até 3 vértices
function fillGapsWithTriangles(polygons, threshold)
    local newPolygons = {}
    
    for i, poly1 in ipairs(polygons) do
        for j, poly2 in ipairs(polygons) do
            if i ~= j and not arePolygonsNeighbors(poly1, poly2, 10.0) then
                for _, v1 in ipairs(poly1) do
                    for _, v2 in ipairs(poly2) do
                        if areVerticesClose(v1, v2, threshold) and isLineOfSightClear(v1, v2) then
                            for _, v3 in ipairs(poly1) do
                                if v3 ~= v1 and areVerticesClose(v3, v2, threshold) and isLineOfSightClear(v2, v3) then
                                    local newPolygon = {
                                        v1, v2, v3
                                    }
                                    table.insert(newPolygons, newPolygon)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for _, poly in ipairs(newPolygons) do
        table.insert(polygons, poly)
    end
end

-- Função principal para gerar a malha de navegação e preencher lacunas
function generateNavigationMeshWithGapFilling(center, areaSize, cellSize, numRays, threshold)
    local polygons = scanArea(center, areaSize, cellSize, numRays)
    fillGaps(polygons, center, areaSize, cellSize, numRays)
    --fillGapsWithTriangles(polygons, threshold) -- Preencher lacunas entre polígonos próximos com triângulos
    return polygons
end

menu.action(TestMenu, "Scan Area", {}, "", function(Toggle)
	local Center = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	Polys1 = generateNavigationMeshWithGapFilling(Center, 100.0, 10.0, 10, 10.0)--scanArea(Center, 100.0, 10.0, 8)
	SetAllPolysNeighboors()
end)

function generateAutoNavMesh(center, areaSize, gridResolution)
    local points = {}

    -- Gera a grade de pontos dentro da área
    for x = -areaSize/2, areaSize/2, gridResolution do
        for y = -areaSize/2, areaSize/2, gridResolution do
            local startPos = v3.new(center.x + x, center.y + y, center.z + areaSize/2)
            local endPos = v3.new(center.x + x, center.y + y, center.z - areaSize/2)
            
			local HitCoords = v3.new()
			local DidHit = memory.alloc(1)
			local EndCoords = v3.new()
			local Normal = v3.new()
			local HitEntity = memory.alloc_int()
			local HitEntityHandle = 0
            -- Executa Raycast vertical para encontrar a superfície
            local ray = SHAPETEST.START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE(startPos.x, startPos.y, startPos.z, endPos.x, endPos.y, endPos.z, -1, PLAYER.PLAYER_PED_ID(), 7)
            SHAPETEST.GET_SHAPE_TEST_RESULT(ray, DidHit, EndCoords, Normal, HitEntity)

            if memory.read_byte(DidHit) ~= 0 then
                -- Armazena o ponto de colisão
                table.insert(points, EndCoords)
            end
        end
    end

    -- Gera polígonos a partir dos pontos coletados
    local polygons = triangulate(points)

    return polygons
end

function triangulate(points)
    -- Implementação básica de triangulação
    local triangles = {}

    -- Supondo uma grade regular, cada quadrado é dividido em dois triângulos
    for i = 1, #points - 1 do
        if (i % math.sqrt(#points) ~= 0) and (i + math.sqrt(#points) <= #points) then
            local p1 = points[i]
            local p2 = points[i + 1]
            local p3 = points[i + math.sqrt(#points)]
            local p4 = points[i + math.sqrt(#points) + 1]

            -- Triângulo 1
            table.insert(triangles, {p1, p2, p3})
            -- Triângulo 2
            table.insert(triangles, {p2, p4, p3})
        end
    end

    return triangles
end


local NewScanArea = false
menu.toggle(TestMenu, "New Scan Area", {}, "", function(Toggle)
	NewScanArea = Toggle
	if NewScanArea then
		local Center = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
		local navMeshPolygons = generateAutoNavMesh(Center, 100.0, 10.0)
		while NewScanArea do
			for _, triangle in ipairs(navMeshPolygons) do
				if triangle[1] ~= nil and triangle[2] ~= nil then
					GRAPHICS.DRAW_LINE(triangle[1].x, triangle[1].y, triangle[1].z, triangle[2].x, triangle[2].y, triangle[2].z, 255, 0, 0, 255)
				end
				if triangle[2] ~= nil and triangle[3] ~= nil then
					GRAPHICS.DRAW_LINE(triangle[2].x, triangle[2].y, triangle[2].z, triangle[3].x, triangle[3].y, triangle[3].z, 0, 255, 0, 255)
				end
				if triangle[3] ~= nil and triangle[1] ~= nil then
					GRAPHICS.DRAW_LINE(triangle[3].x, triangle[3].y, triangle[3].z, triangle[1].x, triangle[1].y, triangle[1].z, 0, 0, 255, 255)
				end
			end
			Wait()
		end
	end
end)

menu.action(TestMenu, "Apply New Scan Area", {}, "", function(Toggle)
	local Center = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	local navMeshPolygons = generateAutoNavMesh(Center, 10.0, 10.0)
	for i = 1, #navMeshPolygons do
		if navMeshPolygons[i][1] ~= nil and navMeshPolygons[i][2] ~= nil and navMeshPolygons[i][3] ~= nil then
			Polys1[#Polys1+1] = {}
			Polys1[#Polys1][#Polys1[#Polys1]+1] = navMeshPolygons[i][1]
			Polys1[#Polys1][#Polys1[#Polys1]+1] = navMeshPolygons[i][2]
			Polys1[#Polys1][#Polys1[#Polys1]+1] = navMeshPolygons[i][3]
		end
	end
	SetAllPolysNeighboors()
end)

-- Função para calcular o centro de massa de um polígono (média dos vértices)
function calculate_centroid(polygon)
    local sum_x, sum_y, sum_z = 0, 0, 0
    for i = 1, 3 do
        sum_x = sum_x + polygon[i].x
        sum_y = sum_y + polygon[i].y
        sum_z = sum_z + polygon[i].z
    end
    return {
        x = sum_x / 3,
        y = sum_y / 3,
        z = sum_z / 3
    }
end

-- Função para calcular a distância euclidiana entre dois pontos 3D
function euclidean_distance(pointA, pointB)
    local dx = pointA.x - pointB.x
    local dy = pointA.y - pointB.y
    local dz = pointA.z - pointB.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Função principal do algoritmo A*
function a_star(start_index, goal_index, polygons)
    -- Inicializa as tabelas abertas (open set) e fechadas (closed set)
    local open_set = {[start_index] = true}
    local came_from = {}
    local g_score = {[start_index] = 0}
    
    -- Heurística inicial (do polígono inicial ao objetivo)
    local start_centroid = calculate_centroid(polygons[start_index])
    local goal_centroid = calculate_centroid(polygons[goal_index])
    local f_score = {[start_index] = euclidean_distance(start_centroid, goal_centroid)}
	local LoopCount = 0
    while next(open_set) do
        -- Seleciona o nó no open_set com o menor f_score
        local current_index = nil
        local lowest_f_score = math.huge
        for index in pairs(open_set) do
            if f_score[index] and f_score[index] < lowest_f_score then
                lowest_f_score = f_score[index]
                current_index = index
            end
        end

        -- Se o nó atual é o nó de destino, reconstruímos o caminho
        if current_index == goal_index then
            return reconstruct_path(came_from, current_index)
        end

        -- Remove o nó atual do open_set
        open_set[current_index] = nil

        -- Para cada vizinho do nó atual
        local neighbors = polygons[current_index].Neighboors
        for _, neighbor_index in ipairs(neighbors) do
            local tentative_g_score = g_score[current_index] + euclidean_distance(
                calculate_centroid(polygons[current_index]),
                calculate_centroid(polygons[neighbor_index])
            )

            -- Se o novo caminho para o vizinho é mais curto ou o vizinho não foi avaliado
            if not g_score[neighbor_index] or tentative_g_score < g_score[neighbor_index] then
                came_from[neighbor_index] = current_index
                g_score[neighbor_index] = tentative_g_score
                f_score[neighbor_index] = g_score[neighbor_index] + euclidean_distance(
                    calculate_centroid(polygons[neighbor_index]),
                    goal_centroid
                )
                open_set[neighbor_index] = true
            end
        end
		LoopCount = LoopCount + 1
		if LoopCount > 10 then
			LoopCount = 0
			Wait()
		end
    end

    -- Se o open_set estiver vazio, significa que não há caminho
    return nil, "Caminho não encontrado"
end

-- Função para reconstruir o caminho percorrendo de volta o "came_from"
function reconstruct_path(came_from, current_index)
    local total_path = {current_index}
    while came_from[current_index] do
        current_index = came_from[current_index]
        table.insert(total_path, 1, current_index)
    end
    return total_path
end

-- Função para calcular o produto vetorial em 3D
function cross_product(v1, v2)
    return {
        x = v1.y * v2.z - v1.z * v2.y,
        y = v1.z * v2.x - v1.x * v2.z,
        z = v1.x * v2.y - v1.y * v2.x
    }
end

-- Função para calcular o comprimento (magnitude) de um vetor
function vector_magnitude(v)
    return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

-- Função para normalizar um vetor (direção com magnitude 1)
function normalize_vector(v)
    local magnitude = vector_magnitude(v)
    return {x = v.x / magnitude, y = v.y / magnitude, z = v.z / magnitude}
end

local NewDrawAStar = false
menu.toggle(TestMenu, "New Optimize Path", {}, "", function(Toggle)
	NewDrawAStar = Toggle
	if NewDrawAStar then
		local path, err = a_star(GetClosestPolygon(Polys1, StartPath, false, 1), GetClosestPolygon(Polys1, ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID()), false, 1), Polys1)
		--Print(type(path))
		local NewPath = {}
		if path then
			local LinesPath = {}
			for k = 1, #path-1 do
				LinesPath[#LinesPath+1] = Polys1[path[k]].Center
			end
			LinesPath[#LinesPath+1] = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			NewPath = smoothPath(LinesPath, Polys1, path)
		end
		local Center = calcularCentroNavmesh(Polys1)
		while NewDrawAStar do
			if path then
				for i = 1, #NewPath-1 do
					GRAPHICS.DRAW_LINE(NewPath[i].x, NewPath[i].y, NewPath[i].z,
					NewPath[i+1].x, NewPath[i+1].y, NewPath[i+1].z, 255, 0, 0, 255)
				end
				--local Pos = calcularCentroidePoligono3D(Polys1[776])
				--GRAPHICS.DRAW_MARKER(28, Pos.x,
				--Pos.y, Pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 150, 0, 0, 100, 0, false, 2, false, 0, 0, false)
				for k = 1, #path do
					GRAPHICS.DRAW_POLY(Polys1[path[k]][1].x, Polys1[path[k]][1].y, Polys1[path[k]][1].z,
					Polys1[path[k]][2].x, Polys1[path[k]][2].y, Polys1[path[k]][2].z,
					Polys1[path[k]][3].x, Polys1[path[k]][3].y, Polys1[path[k]][3].z,
					100, 100, 100, 100)
					GRAPHICS.DRAW_LINE(Polys1[path[k]][1].x, Polys1[path[k]][1].y, Polys1[path[k]][1].z,
					Polys1[path[k]][2].x, Polys1[path[k]][2].y, Polys1[path[k]][2].z, 255, 255, 255, 150)
					GRAPHICS.DRAW_LINE(Polys1[path[k]][1].x, Polys1[path[k]][1].y, Polys1[path[k]][1].z,
					Polys1[path[k]][3].x, Polys1[path[k]][3].y, Polys1[path[k]][3].z, 255, 255, 255, 150)
				end
				GRAPHICS.DRAW_MARKER(28, Center.x,
				Center.y, Center.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 150, 0, 0, 100, 0, false, 2, false, 0, 0, false)
			end
			Wait()
		end
	end
end)

-- Função para calcular o centroide de um polígono 3D
function calcularCentroidePoligono3D(polygon)
    local cx, cy, cz = 0, 0, 0
    local numVertices = #polygon

    for i = 1, numVertices do
        cx = cx + polygon[i].x
        cy = cy + polygon[i].y
        cz = cz + polygon[i].z
    end

    -- Dividir pela quantidade de vértices para encontrar a média
    cx = cx / numVertices
    cy = cy / numVertices
    cz = cz / numVertices

    return {x = cx, y = cy, z = cz}
end

-- Função para verificar se um ponto está dentro de um polígono (utilizando o algoritmo de Ponto no Polígono)
function isPointInPolygon(point, polygon)
    local oddNodes = false
    local j = #polygon
    for i = 1, #polygon do
        local vi = polygon[i]
        local vj = polygon[j]
        if (vi.y < point.y and vj.y >= point.y or vj.y < point.y and vi.y >= point.y) then
            if (vi.x + (point.y - vi.y) / (vj.y - vi.y) * (vj.x - vi.x) < point.x) then
                oddNodes = not oddNodes
            end
        end
        j = i
    end
    return oddNodes
end

-- Função para verificar se a linha entre dois pontos passa por dentro de algum polígono e retorna a última coordenada válida
function canConnectDirectly(p1, p2, polygons, indexes)
    -- Vamos dividir a linha entre p1 e p2 em pequenos segmentos
    local numSegments = math.floor(DistanceBetween(polygons[indexes[1]].Center.x, polygons[indexes[1]].Center.y, polygons[indexes[1]].Center.z,
	polygons[indexes[#indexes]].Center.x, polygons[indexes[#indexes]].Center.y, polygons[indexes[#indexes]].Center.z)) * 1--50
    local lastValidPoint = nil

    for i = 0, numSegments do
        -- Interpolação linear entre p1 e p2 para criar um ponto intermediário
        local t = i / numSegments
        local intermediatePoint = {
            x = p1.x * (1 - t) + p2.x * t,
            y = p1.y * (1 - t) + p2.y * t
        }

        -- Verificar se esse ponto intermediário está dentro de algum polígono
        local insideAnyPolygon = false
        for k = 1, #indexes do
        --for _, polygon in ipairs(polygons) do
            local polygon = polygons[indexes[k]]
            if isPointInPolygon(intermediatePoint, polygon) then
                insideAnyPolygon = true
                lastValidPoint = intermediatePoint -- Atualiza o último ponto válido
                break
            end
        end

        -- Se algum ponto intermediário não estiver dentro de nenhum polígono, há uma obstrução
        if not insideAnyPolygon then
            return false, lastValidPoint
        end
    end

    -- Se todos os pontos intermediários estiverem dentro de polígonos, retorna o último ponto
    return true, p2
end


-- Função para suavizar a rota gerada pelo A*
function smoothPath(path, polygons, indexes)
    local smoothedPath = {}
    local i = 1

    -- Adiciona o primeiro ponto no caminho suavizado
    table.insert(smoothedPath, path[i])

    -- Variável para armazenar a última coordenada válida retornada pela canConnectDirectly
    local lastValidPoint = path[i]

    -- Itera sobre os pontos do caminho
    while i < #path do
        local j = i + 1
        local found = false
        local newPoint = nil

        -- Encontra o ponto mais distante que pode ser conectado diretamente
        while j <= #path do
            local canConnect, lastPoint = canConnectDirectly(lastValidPoint, path[j], polygons, indexes)
            if canConnect then
                found = true
                newPoint = lastPoint -- Atualiza o novo ponto de partida para a próxima iteração
                j = j + 1
            else
                break
            end
        end

        -- Se `j-1` puder ser conectado diretamente, adicionamos o ponto ao caminho suavizado
        if found and newPoint then
            table.insert(smoothedPath, newPoint)
        else
            -- Caso contrário, mova para o próximo ponto imediatamente
            j = i + 1
            table.insert(smoothedPath, path[j])
        end

        -- Atualiza a última coordenada válida
        lastValidPoint = smoothedPath[#smoothedPath]

        -- Certifique-se de avançar o índice `i`
        i = j
    end

    return smoothedPath
end


function SplitGlobals(GlobalString)
	local String = GlobalString
	local Value = String:gsub("%[(.-)]", "+1")
	local NewValue = Value:gsub("%a", "")
	local NewValue2 = NewValue:gsub("._", "+")
	local NewValue3 = NewValue2:gsub("_", "")
	local _Text, SymbolCount = NewValue3:gsub("+", "")
	local PatternCount = "(%d+)"
	for i = 1, SymbolCount do
		PatternCount = PatternCount .. "+(%d+)"
	end
	local Global, Global2, Global3, Global4, Global5, Global6, Global7 = NewValue3:match(PatternCount)
	local GlobalNumber = 0
	if Global ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global)
	end
	if Global2 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global2)
	end
	if Global3 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global3)
	end
	if Global4 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global4)
	end
	if Global5 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global5)
	end
	if Global6 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global6)
	end
	if Global7 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global7)
	end
	return GlobalNumber
end

--[[
local ImprovedDM = false
menu.toggle(GameModesMenu, "Improved Deathmatch", {}, "", function(Toggle)
	ImprovedDM = Toggle

end)
]]

-- Função que calcula o centro da navmesh
function calcularCentroNavmesh(poligonos)
    local somaX, somaY, somaZ = 0, 0, 0
    local totalVertices = 0
    
    -- Percorre todos os polígonos
    for _, poligono in ipairs(poligonos) do
        -- Percorre todos os vértices de cada polígono
        for _, vertice in ipairs(poligono) do
            somaX = somaX + vertice.x
            somaY = somaY + vertice.y
            somaZ = somaZ + vertice.z
            totalVertices = totalVertices + 1
        end
    end
    
    -- Calcula a média das coordenadas
    local centroX = somaX / totalVertices
    local centroY = somaY / totalVertices
    local centroZ = somaZ / totalVertices
    
    -- Retorna as coordenadas do centroide
    return {x = centroX, y = centroY, z = centroZ}
end

-- Função que calcula o offset relativo entre o centro e os vértices de cada polígono
function calcularOffsetPoligonos(poligonos, centro)
    local poligonosComOffset = {}
    
    -- Percorre todos os polígonos
    for i, poligono in ipairs(poligonos) do
        local poligonoOffset = {}
        
        -- Percorre todos os vértices de cada polígono
        for j, vertice in ipairs(poligono) do
            -- Calcula o offset relativo
            local offsetX = vertice.x - centro.x
            local offsetY = vertice.y - centro.y
            local offsetZ = vertice.z - centro.z
            
            -- Salva o vértice com o offset
            table.insert(poligonoOffset, {x = offsetX, y = offsetY, z = offsetZ})
        end
        
        -- Adiciona o polígono com os vértices offsetados à nova lista
        table.insert(poligonosComOffset, poligonoOffset)
    end
    
    return poligonosComOffset
end

-- Função para rotacionar um ponto em torno do eixo X
local function rotacionarX(vertice, anguloX)
	local cosAngulo = math.cos(anguloX)
	local sinAngulo = math.sin(anguloX)
	local y = vertice.y * cosAngulo - vertice.z * sinAngulo
	local z = vertice.y * sinAngulo + vertice.z * cosAngulo
	return {x = vertice.x, y = y, z = z}
end

-- Função para rotacionar um ponto em torno do eixo Y
local function rotacionarY(vertice, anguloY)
	local cosAngulo = math.cos(anguloY)
	local sinAngulo = math.sin(anguloY)
	local x = vertice.x * cosAngulo + vertice.z * sinAngulo
	local z = -vertice.x * sinAngulo + vertice.z * cosAngulo
	return {x = x, y = vertice.y, z = z}
end

-- Função para rotacionar um ponto em torno do eixo Z
local function rotacionarZ(vertice, anguloZ)
	local cosAngulo = math.cos(anguloZ)
	local sinAngulo = math.sin(anguloZ)
	local x = vertice.x * cosAngulo - vertice.y * sinAngulo
	local y = vertice.x * sinAngulo + vertice.y * cosAngulo
	return {x = x, y = y, z = vertice.z}
end

-- Função para rotacionar todos os polígonos com base nos ângulos de rotação do avião
function rotacionarPoligonos(poligonos, anguloX, anguloY, anguloZ)
	local poligonosRotacionados = {}

	-- Percorre todos os polígonos
	for i, poligono in ipairs(poligonos) do
		local poligonoRotacionado = {}
		
		-- Percorre todos os vértices de cada polígono
		for j, vertice in ipairs(poligono) do
			-- Aplica as rotações
			local verticeRotacionado = vertice
			verticeRotacionado = rotacionarX(verticeRotacionado, anguloX)
			verticeRotacionado = rotacionarY(verticeRotacionado, anguloY)
			verticeRotacionado = rotacionarZ(verticeRotacionado, anguloZ)
			
			-- Adiciona o vértice rotacionado ao polígono rotacionado
			table.insert(poligonoRotacionado, verticeRotacionado)
		end
		
		-- Adiciona o polígono rotacionado à nova lista
		table.insert(poligonosRotacionados, poligonoRotacionado)
	end
	
	return poligonosRotacionados
end
	
-- Função que move os polígonos para uma posição alvo
function moverPoligonosParaDestino(poligonosComOffset, destino)
    local poligonosMovidos = {}
    
    -- Percorre todos os polígonos
    for i, poligono in ipairs(poligonosComOffset) do
        local poligonoMovido = {}
        
        -- Percorre todos os vértices de cada polígono
        for j, vertice in ipairs(poligono) do
            -- Calcula a nova posição somando o offset à posição alvo (destino)
            local novoX = vertice.x + destino.x
            local novoY = vertice.y + destino.y
            local novoZ = vertice.z + destino.z
            
            -- Adiciona o vértice movido ao novo polígono
            table.insert(poligonoMovido, {x = novoX, y = novoY, z = novoZ})
        end
        
        -- Adiciona o polígono movido à nova lista
        table.insert(poligonosMovidos, poligonoMovido)
    end
    
    return poligonosMovidos
end

-- Função para calcular o offset relativo entre o centro e os vértices de polígonos específicos com base nos índices fornecidos
function calcularOffsetPoligonosComIndices(poligonos, indices, centro)
    -- Tabela para armazenar os polígonos com offset calculado
    local poligonosComOffset = {}

    -- Percorre apenas os polígonos cujos índices foram fornecidos
    for _, indice in ipairs(indices) do
        local poligono = poligonos[indice]
        local poligonoOffset = {}

        -- Percorre todos os vértices do polígono
        for _, vertice in ipairs(poligono) do
            -- Calcula o offset relativo entre o vértice e o centro
            local offsetX = vertice.x - centro.x
            local offsetY = vertice.y - centro.y
            local offsetZ = vertice.z - centro.z

            -- Armazena o vértice com o offset calculado
            table.insert(poligonoOffset, {x = offsetX, y = offsetY, z = offsetZ})
        end
        
        -- Adiciona o polígono com offset à tabela final
        poligonosComOffset[indice] = poligonoOffset
    end

    return poligonosComOffset
end


-- Armazenar a tabela original dos polígonos (cópia dos offsets)
-- Função para armazenar os offsets originais dos vértices
function armazenarOffsetsOriginais(poligonosComOffset, tableTarget)
    -- Faz uma cópia da tabela de polígonos original
    for i, poligono in ipairs(poligonosComOffset) do
        local poligonoCopia = {}
        for j, vertice in ipairs(poligono) do
            table.insert(poligonoCopia, {x = vertice.x, y = vertice.y, z = vertice.z})
        end
        table.insert(tableTarget, poligonoCopia)
    end
end

-- Função para armazenar os offsets originais de polígonos específicos, baseados nos índices fornecidos
function armazenarOffsetsOriginaisComIndices(poligonos, indices)
    local poligonosOriginais = {}

    -- Percorre apenas os polígonos cujos índices foram fornecidos
    for _, indice in ipairs(indices) do
        local poligono = poligonos[indice]
        local poligonoCopia = {}

        -- Armazena cada vértice do polígono como uma cópia
        for _, vertice in ipairs(poligono) do
            table.insert(poligonoCopia, {x = vertice.x, y = vertice.y, z = vertice.z})
        end
        
        -- Armazena a cópia do polígono original na nova tabela
        poligonosOriginais[indice] = poligonoCopia
    end

    return poligonosOriginais  -- Retorna a tabela de offsets originais para os índices especificados
end


-- Função para mover e rotacionar os polígonos a cada tick sem acumulação de rotação
function atualizarPoligonosParaDestinoERotacaoSemAcumulo(poligonosAtuais, poligonosOriginais, destino, rotacao)
    -- Percorre todos os polígonos originais
    for i, poligonoOriginal in ipairs(poligonosOriginais) do
        -- Percorre todos os vértices de cada polígono original
        for j, verticeOriginal in ipairs(poligonoOriginal) do
            -- Usa o vértice original (offset) para recalcular a rotação a cada tick
            local vertice = {x = verticeOriginal.x, y = verticeOriginal.y, z = verticeOriginal.z}
            
            -- Aplica a rotação nos eixos X, Y, e Z
            vertice = rotacionarX(vertice, rotacao.x)
            vertice = rotacionarY(vertice, rotacao.y)
            vertice = rotacionarZ(vertice, rotacao.z)
            
            -- Depois, move o vértice rotacionado para a posição do avião (destino)
            vertice.x = vertice.x + destino.x
            vertice.y = vertice.y + destino.y
            vertice.z = vertice.z + destino.z
            
            -- Atualiza o vértice atual na tabela de polígonos
            poligonosAtuais[i][j] = vertice
        end
		poligonosAtuais[i].Center = GetPolygonCenter(poligonosAtuais[i])
    end
end

-- Função para descobrir quais polígonos são bordas e retornar seus índices
function descobrirPoligonosDeBorda(poligonos)
    local bordas = {}

    -- Função auxiliar para encontrar arestas de um polígono
    local function obterArestas(poligono)
        local arestas = {}
        local numVertices = #poligono

        -- Conecta cada vértice ao próximo (e o último ao primeiro)
        for i = 1, numVertices do
            local v1 = poligono[i]
            local v2 = poligono[(i % numVertices) + 1]
            table.insert(arestas, {{x = v1.x, y = v1.y, z = v1.z}, {x = v2.x, y = v2.y, z = v2.z}})
        end

        return arestas
    end

    -- Função auxiliar para comparar duas arestas (se são iguais, independentemente da ordem dos vértices)
    local function arestasIguais(aresta1, aresta2)
        return (aresta1[1].x == aresta2[1].x and aresta1[1].y == aresta2[1].y and aresta1[1].z == aresta2[1].z and
                aresta1[2].x == aresta2[2].x and aresta1[2].y == aresta2[2].y and aresta1[2].z == aresta2[2].z) or
               (aresta1[1].x == aresta2[2].x and aresta1[1].y == aresta2[2].y and aresta1[1].z == aresta2[2].z and
                aresta1[2].x == aresta2[1].x and aresta1[2].y == aresta2[1].y and aresta1[2].z == aresta2[1].z)
    end

    -- Percorrer todos os polígonos para encontrar as arestas
    local todasArestas = {}
    for i, poligono in ipairs(poligonos) do
        todasArestas[i] = obterArestas(poligono)
    end

    -- Verificar quais polígonos têm arestas de borda
    for i, arestasPoligono in ipairs(todasArestas) do
        local isBorda = false

        for _, aresta in ipairs(arestasPoligono) do
            local compartilhada = false

            -- Verificar se a aresta é compartilhada com outro polígono
            for j, outrasArestasPoligono in ipairs(todasArestas) do
                if i ~= j then  -- Não comparar com o próprio polígono
                    for _, outraAresta in ipairs(outrasArestasPoligono) do
                        if arestasIguais(aresta, outraAresta) then
                            compartilhada = true
                            break
                        end
                    end
                end
                if compartilhada then break end
            end

            -- Se a aresta não foi compartilhada, o polígono é uma borda
            if not compartilhada then
                isBorda = true
                break
            end
        end

        -- Se pelo menos uma aresta não é compartilhada, o polígono é de borda
        if isBorda then
            table.insert(bordas, i)  -- Armazenar o índice do polígono de borda
        end
    end

    return bordas  -- Retorna os índices dos polígonos de borda
end

menu.action(TestMenu, "Set Veh Rot 0", {}, "", function(Toggle)
	local Veh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
	if Veh ~= 0 then
		ENTITY.SET_ENTITY_ROTATION(Veh, 0.0, 0.0, 0.0, 2)
	end
end)

local TestPlanePolys = false
menu.toggle(TestMenu, "Test Plane Polys", {}, "", function(Toggle)
	TestPlanePolys = Toggle
	if TestPlanePolys then
		local NewPolys = {}
		local IDs = {}
		for k = 1, #Polys1 do
			IDs[#IDs+1] = Polys1[k].ID
		end
		local Center = calcularCentroNavmeshComIndices(Polys1, IDs)
		local Offsets = calcularOffsetPoligonosComIndices(Polys1, IDs, Center)
		local New = armazenarOffsetsOriginaisComIndices(Offsets, IDs)
		local BorderIDs = descobrirPoligonosDeBordaComIndices(Polys1, PlatformIDs)
		--encontrarVizinhos(poligonosBorda, poligonosDinamicos, tolerancia)
		while TestPlanePolys do
			local Veh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
			if Veh ~= 0 then
				local Rot = ENTITY.GET_ENTITY_ROTATION(Veh, 0)
				Rot.x = math.rad(Rot.x)
				Rot.y = math.rad(Rot.y)
				Rot.z = math.rad(Rot.z)
				--local Pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Veh, -3.8, -4.8, 3.0)
				local Pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Veh, 0.2, -11.0, 3.0)
				atualizarPoligonosParaDestinoERotacaoSemAcumuloComIndices(New, Polys1, IDs, Pos, Rot)
				--atualizarTodosVizinhosComIndices(Polys1, BorderIDs, IDs, 10.0)
			end
			for k = 1, #BorderIDs do
				local CPos = Polys1[BorderIDs[k]].Center
				for i = 1, #Polys1[BorderIDs[k]].Neighboors do
					local CPos2 = Polys1[Polys1[BorderIDs[k]].Neighboors[i]].Center
					GRAPHICS.DRAW_LINE(CPos.x, CPos.y, CPos.z,
					CPos2.x, CPos2.y, CPos2.z, 255, 255, 255, 150)
				
				end
			end
			Wait()
		end
		local Rot = {}
		Rot.x = math.rad(0)
		Rot.y = math.rad(0)
		Rot.z = math.rad(0)
		atualizarPoligonosParaDestinoERotacaoSemAcumuloComIndices(New, Polys1, IDs, Center, Rot)
	end
end)

-- Função para calcular a bounding box de um polígono
function calcularBoundingBoxPoligono(poligono)
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

    -- Percorre todos os vértices do polígono
    for _, vertice in ipairs(poligono) do
        if vertice.x < minX then minX = vertice.x end
        if vertice.y < minY then minY = vertice.y end
        if vertice.z < minZ then minZ = vertice.z end

        if vertice.x > maxX then maxX = vertice.x end
        if vertice.y > maxY then maxY = vertice.y end
        if vertice.z > maxZ then maxZ = vertice.z end
    end

    return {min = {x = minX, y = minY, z = minZ}, max = {x = maxX, y = maxY, z = maxZ}}
end


-- Função para verificar se um ponto está dentro de uma bounding box
function pontoDentroDaBoundingBox(ponto, boundingBox)
    return ponto.x >= boundingBox.min.x and ponto.x <= boundingBox.max.x and
           ponto.y >= boundingBox.min.y and ponto.y <= boundingBox.max.y and
           ponto.z >= boundingBox.min.z and ponto.z <= boundingBox.max.z
end


-- Função para verificar se um ponto 2D (XY) está dentro de um polígono
function pontoDentroDoPoligono(ponto, poligono)
    local dentro = false
    local j = #poligono

    for i = 1, #poligono do
        local vi = poligono[i]
        local vj = poligono[j]

        -- Verifica se a linha que conecta os vértices cruza o eixo horizontal ao nível do ponto
        if ((vi.y > ponto.y) ~= (vj.y > ponto.y)) and
           (ponto.x < (vj.x - vi.x) * (ponto.y - vi.y) / (vj.y - vi.y) + vi.x) then
            dentro = not dentro
        end
        j = i
    end

    return dentro
end
-- Função para verificar se um ponto está dentro de uma bounding box com tolerância no eixo Z
function pontoDentroDaBoundingBoxComTolerancia(ponto, boundingBox, toleranciaZ)
    return ponto.x >= boundingBox.min.x and ponto.x <= boundingBox.max.x and
           ponto.y >= boundingBox.min.y and ponto.y <= boundingBox.max.y and
           ponto.z >= boundingBox.min.z - toleranciaZ and ponto.z <= boundingBox.max.z + toleranciaZ
end

-- Função para verificar se um ponto está dentro de um polígono com tolerância no eixo Z
function pontoDentroDoPoligonoComTolerancia(ponto, poligono, toleranciaZ)
    -- Primeiro, verificamos a altura (tolerância no eixo Z)
    local zPoligono = poligono[1].z  -- Assume que todos os vértices têm a mesma coordenada Z (plano horizontal)
    if ponto.z < zPoligono - toleranciaZ or ponto.z > zPoligono + toleranciaZ then
        return false  -- Se o ponto estiver fora da tolerância no Z, retorna falso
    end

    -- Em seguida, verifica se o ponto está dentro do polígono no plano XY
    local dentro = false
    local j = #poligono

    for i = 1, #poligono do
        local vi = poligono[i]
        local vj = poligono[j]

        -- Verifica se a linha que conecta os vértices cruza o eixo horizontal ao nível do ponto
        if ((vi.y > ponto.y) ~= (vj.y > ponto.y)) and
           (ponto.x < (vj.x - vi.x) * (ponto.y - vi.y) / (vj.y - vi.y) + vi.x) then
            dentro = not dentro
        end
        j = i
    end

    return dentro
end



-- Função para encontrar o índice do polígono em que um ponto está
function encontrarPoligonoDoPonto(ponto, poligonos, toleranciaZ)
	for i, poligono in ipairs(poligonos) do
		-- Calcula a bounding box do polígono
		if poligono.BoundingBox == nil then
			poligono.BoundingBox = calcularBoundingBoxPoligono(poligono)
		end
		local boundingBox = poligono.BoundingBox--calcularBoundingBoxPoligono(poligono)

		-- Primeiro, verifica se o ponto está dentro da bounding box
		if pontoDentroDaBoundingBoxComTolerancia(ponto, boundingBox, toleranciaZ) then
			-- Depois, faz a verificação detalhada se o ponto está dentro do polígono
			if pontoDentroDoPoligonoComTolerancia(ponto, poligono, toleranciaZ) then
				return poligono.ID  -- Retorna o índice do polígono
			end
		end
	end

	return nil  -- Retorna nil se o ponto não estiver em nenhum polígono
end

-- Função para calcular a distância entre dois pontos 3D
function calcularDistancia(p1, p2)
    local dx = p1.x - p2.x
    local dy = p1.y - p2.y
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Função para verificar se dois polígonos são vizinhos com base em uma tolerância
function saoVizinhos(poliBorda, poliDinamico, tolerancia)
    -- Verifica a distância entre cada vértice do polígono de borda e cada vértice do polígono dinâmico
    for _, verticeBorda in ipairs(poliBorda) do
        for _, verticeDinamico in ipairs(poliDinamico) do
            if calcularDistancia(verticeBorda, verticeDinamico) <= tolerancia then
                return true  -- Se a distância entre um par de vértices for menor que a tolerância, são vizinhos
            end
        end
    end
    return false  -- Se nenhuma distância for menor que a tolerância, não são vizinhos
end

-- Função para encontrar todos os vizinhos entre os polígonos de borda e os dinâmicos
function encontrarVizinhos(poligonosBorda, poligonosDinamicos, tolerancia)
    local vizinhos = {}

    -- Percorre cada polígono de borda
    for i, poliBorda in ipairs(poligonosBorda) do
        -- Percorre cada polígono dinâmico
        for j, poliDinamico in ipairs(poligonosDinamicos) do
            -- Verifica se eles são vizinhos
            if saoVizinhos(poliBorda, poliDinamico, tolerancia) then
                table.insert(vizinhos, {borda = i, dinamico = j})  -- Armazena o índice de polígonos vizinhos
            end
        end
    end

    return vizinhos  -- Retorna a lista de pares de polígonos que são vizinhos
end

-- Função para adicionar um vizinho ao polígono, se ainda não estiver presente
function adicionarVizinho(poligonos, indicePoligono, indiceVizinho)
    local vizinhos = poligonos[indicePoligono].Neighboors
    -- Verifica se o índice já está na lista de vizinhos
    for _, vizinho in ipairs(vizinhos) do
        if vizinho == indiceVizinho then
            return  -- O vizinho já está na lista, não faz nada
        end
    end
    -- Adiciona o índice do vizinho
    table.insert(vizinhos, indiceVizinho)
end

-- Função para remover um vizinho da lista de vizinhos do polígono
function removerVizinho(poligonos, indicePoligono, indiceVizinho)
    local vizinhos = poligonos[indicePoligono].Neighboors
    for i, vizinho in ipairs(vizinhos) do
        if vizinho == indiceVizinho then
            table.remove(vizinhos, i)  -- Remove o vizinho da lista
            return
        end
    end
end

-- Função para gerenciar a lista de vizinhos com base na distância, usando índices
function atualizarVizinhosComIndices(poligonos, indiceBorda, indiceDinamico, tolerancia)
    local poliBorda = poligonos[indiceBorda]
    local poliDinamico = poligonos[indiceDinamico]

    -- Verifica se são vizinhos (dentro da tolerância)
    if saoVizinhos(poliBorda, poliDinamico, tolerancia) then
        -- Adiciona o polígono dinâmico como vizinho do polígono de borda
        adicionarVizinho(poligonos, indiceBorda, indiceDinamico)
        -- Adiciona o polígono de borda como vizinho do polígono dinâmico
        adicionarVizinho(poligonos, indiceDinamico, indiceBorda)
    else
        -- Se estiverem distantes, remover da lista de vizinhos
        removerVizinho(poligonos, indiceBorda, indiceDinamico)
        removerVizinho(poligonos, indiceDinamico, indiceBorda)
    end
end

-- Função para atualizar os vizinhos entre polígonos de borda e dinâmicos, usando índices
function atualizarTodosVizinhosComIndices(poligonos, indicesBorda, indicesDinamicos, tolerancia)
    -- Percorre cada índice de polígono de borda
    for _, indiceBorda in ipairs(indicesBorda) do
        -- Percorre cada índice de polígono dinâmico
        for _, indiceDinamico in ipairs(indicesDinamicos) do
            -- Atualiza a relação de vizinhança entre o polígono de borda e o dinâmico
            atualizarVizinhosComIndices(poligonos, indiceBorda, indiceDinamico, tolerancia)
        end
    end
end

-- Função que calcula o centro da navmesh com base em uma lista de índices de polígonos
function calcularCentroNavmeshComIndices(poligonos, indices)
    local somaX, somaY, somaZ = 0, 0, 0
    local totalVertices = 0
    
    -- Percorre apenas os polígonos cujos índices foram fornecidos
    for _, indice in ipairs(indices) do
        local poligono = poligonos[indice]
        
        -- Percorre todos os vértices de cada polígono
        for _, vertice in ipairs(poligono) do
            somaX = somaX + vertice.x
            somaY = somaY + vertice.y
            somaZ = somaZ + vertice.z
            totalVertices = totalVertices + 1
        end
    end
    
    -- Calcula a média das coordenadas (centroide)
    if totalVertices == 0 then
        return nil  -- Caso não haja vértices
    end

    local centroX = somaX / totalVertices
    local centroY = somaY / totalVertices
    local centroZ = somaZ / totalVertices
    
    -- Retorna as coordenadas do centroide
    return {x = centroX, y = centroY, z = centroZ}
end

-- Função para mover e rotacionar os polígonos a cada tick usando índices, sem acumulação de rotação
function atualizarPoligonosParaDestinoERotacaoSemAcumuloComIndices(poligonosOriginais, poligonosAtuais, indices, destino, rotacao)
    -- Percorre os polígonos pelos índices fornecidos
    for _, indice in ipairs(indices) do
        local poligonoOriginal = poligonosOriginais[indice]
        local poligonoAtual = poligonosAtuais[indice]
        
        -- Percorre todos os vértices de cada polígono original
        for j, verticeOriginal in ipairs(poligonoOriginal) do
            -- Usa o vértice original (offset) para recalcular a rotação a cada tick
            local vertice = {x = verticeOriginal.x, y = verticeOriginal.y, z = verticeOriginal.z}
            
            -- Aplica a rotação nos eixos X, Y e Z
            vertice = rotacionarX(vertice, rotacao.x)
            vertice = rotacionarY(vertice, rotacao.y)
            vertice = rotacionarZ(vertice, rotacao.z)
            
            -- Depois, move o vértice rotacionado para a posição do destino (avião ou plataforma)
            vertice.x = vertice.x + destino.x
            vertice.y = vertice.y + destino.y
            vertice.z = vertice.z + destino.z
            
            -- Atualiza o vértice atual na tabela de polígonos atual
            poligonoAtual[j] = vertice
        end
		poligonoAtual.Center = GetPolygonCenter(poligonoAtual)
    end
end

-- Função para descobrir quais polígonos são bordas, com base em uma lista de índices
function descobrirPoligonosDeBordaComIndices(poligonos, indices)
    local bordas = {}

    -- Função auxiliar para encontrar arestas de um polígono
    local function obterArestas(poligono)
        local arestas = {}
        local numVertices = #poligono

        -- Conecta cada vértice ao próximo (e o último ao primeiro)
        for i = 1, numVertices do
            local v1 = poligono[i]
            local v2 = poligono[(i % numVertices) + 1]
            table.insert(arestas, {{x = v1.x, y = v1.y, z = v1.z}, {x = v2.x, y = v2.y, z = v2.z}})
        end

        return arestas
    end

    -- Função auxiliar para comparar duas arestas (se são iguais, independentemente da ordem dos vértices)
    local function arestasIguais(aresta1, aresta2)
        return (aresta1[1].x == aresta2[1].x and aresta1[1].y == aresta2[1].y and aresta1[1].z == aresta2[1].z and
                aresta1[2].x == aresta2[2].x and aresta1[2].y == aresta2[2].y and aresta1[2].z == aresta2[2].z) or
               (aresta1[1].x == aresta2[2].x and aresta1[1].y == aresta2[2].y and aresta1[1].z == aresta2[2].z and
                aresta1[2].x == aresta2[1].x and aresta1[2].y == aresta2[1].y and aresta1[2].z == aresta2[1].z)
    end

    -- Percorrer apenas os polígonos cujos índices foram fornecidos
    local todasArestas = {}
    for _, indice in ipairs(indices) do
        todasArestas[indice] = obterArestas(poligonos[indice])
    end

    -- Verificar quais polígonos têm arestas de borda
    for _, indice in ipairs(indices) do
        local arestasPoligono = todasArestas[indice]
        local isBorda = false

        for _, aresta in ipairs(arestasPoligono) do
            local compartilhada = false

            -- Verificar se a aresta é compartilhada com outro polígono nos índices fornecidos
            for _, outroIndice in ipairs(indices) do
                if indice ~= outroIndice then
                    local outrasArestasPoligono = todasArestas[outroIndice]
                    for _, outraAresta in ipairs(outrasArestasPoligono) do
                        if arestasIguais(aresta, outraAresta) then
                            compartilhada = true
                            break
                        end
                    end
                end
                if compartilhada then break end
            end

            -- Se a aresta não foi compartilhada, o polígono é uma borda
            if not compartilhada then
                isBorda = true
                break
            end
        end

        -- Se pelo menos uma aresta não é compartilhada, o polígono é de borda
        if isBorda then
            table.insert(bordas, indice)  -- Armazenar o índice do polígono de borda
        end
    end

    return bordas  -- Retorna os índices dos polígonos de borda
end

-- Função para converter ângulos de Euler para matriz de rotação (ordem XYZ)
function EulerToRotationMatrix(pitch, yaw, roll)
    local cx = math.cos(pitch)
    local sx = math.sin(pitch)
    local cy = math.cos(yaw)
    local sy = math.sin(yaw)
    local cz = math.cos(roll)
    local sz = math.sin(roll)

    return {
        {cy * cz, -cy * sz, sy},
        {sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy},
        {-cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy}
    }
end

-- Função para multiplicar duas matrizes 3x3
function MatrixMultiply(m1, m2)
    local result = {}
    for i = 1, 3 do
        result[i] = {}
        for j = 1, 3 do
            result[i][j] = m1[i][1] * m2[1][j] + m1[i][2] * m2[2][j] + m1[i][3] * m2[3][j]
        end
    end
    return result
end

-- Função para calcular a matriz de rotação inversa
function MatrixInverse(m)
    local determinant = m[1][1] * (m[2][2] * m[3][3] - m[2][3] * m[3][2]) -
                        m[1][2] * (m[2][1] * m[3][3] - m[2][3] * m[3][1]) +
                        m[1][3] * (m[2][1] * m[3][2] - m[2][2] * m[3][1])
    local invDet = 1 / determinant

    return {
        {
            invDet * (m[2][2] * m[3][3] - m[2][3] * m[3][2]),
            invDet * (m[1][3] * m[3][2] - m[1][2] * m[3][3]),
            invDet * (m[1][2] * m[2][3] - m[1][3] * m[2][2])
        },
        {
            invDet * (m[2][3] * m[3][1] - m[2][1] * m[3][3]),
            invDet * (m[1][1] * m[3][3] - m[1][3] * m[3][1]),
            invDet * (m[1][3] * m[2][1] - m[1][1] * m[2][3])
        },
        {
            invDet * (m[2][1] * m[3][2] - m[2][2] * m[3][1]),
            invDet * (m[1][2] * m[3][1] - m[1][1] * m[3][2]),
            invDet * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
        }
    }
end

-- Função para obter a matriz de rotação da entidade
function GetEntityRotationMatrix(entity)
    local rot = ENTITY.GET_ENTITY_ROTATION(entity, 5)
    return EulerToRotationMatrix(math.rad(rot.x), math.rad(rot.y), math.rad(rot.z))
end

-- Função para converter uma matriz de rotação para quaternion
function RotationMatrixToQuaternion(m)
    local w = math.sqrt(1 + m[1][1] + m[2][2] + m[3][3]) / 2
    local x = (m[3][2] - m[2][3]) / (4 * w)
    local y = (m[1][3] - m[3][1]) / (4 * w)
    local z = (m[2][1] - m[1][2]) / (4 * w)
    return {w = w, x = x, y = y, z = z}
end

-- Função para calcular a velocidade angular a partir da diferença de quaternions
function QuaternionToAngularVelocity(q)
    local theta = 2 * math.acos(q.w)
    local sinTheta = math.sqrt(1 - q.w * q.w)
    if sinTheta < 0.001 then
        return {x = q.x * theta, y = q.y * theta, z = q.z * theta}
    else
        return {x = q.x / sinTheta * theta, y = q.y / sinTheta * theta, z = q.z / sinTheta * theta}
    end
end

-- Função principal para girar a entidade até a rotação desejada usando matrizes de rotação
function RotateEntityToTargetRotation(entity, targetRotation, interpolationFactor, normalise)
    interpolationFactor = interpolationFactor or 0.1 -- Fator de interpolação para suavizar a rotação

    -- Obtenha a matriz de rotação atual da entidade
    local currentRotationMatrix = GetEntityRotationMatrix(entity)

    -- Calcule a matriz de rotação alvo a partir dos ângulos de Euler desejados
    local targetRotationMatrix = EulerToRotationMatrix(math.rad(targetRotation.x), math.rad(targetRotation.y), math.rad(targetRotation.z))

    -- Calcule a matriz de rotação delta
    local deltaRotationMatrix = MatrixMultiply(targetRotationMatrix, MatrixInverse(currentRotationMatrix))
    -- Converta a matriz de rotação delta para quaternion
    local deltaQuaternion = RotationMatrixToQuaternion(deltaRotationMatrix)

    -- Converta a diferença de quaternion em velocidade angular
    local angularVelocity = QuaternionToAngularVelocity(deltaQuaternion)

    -- Interpole a velocidade angular para suavizar a rotação
    angularVelocity.x = angularVelocity.x * interpolationFactor
    angularVelocity.y = angularVelocity.y * interpolationFactor
    angularVelocity.z = angularVelocity.z * interpolationFactor

	if normalise then
		angularVelocity = v3.new(angularVelocity.x, angularVelocity.y, angularVelocity.z)
		angularVelocity:normalise()
		angularVelocity:mul(interpolationFactor)
	end

    ENTITY.SET_ENTITY_ANGULAR_VELOCITY(entity, angularVelocity.x, angularVelocity.y, angularVelocity.z)
end

-- Função para calcular a nova rotação X e Y baseada na rotação Z e inclinação desejada
function calculateTiltRotationFromUserInput(rotX, rotY, rotZ, tiltDegrees)
    -- Converter a rotação Z para radianos
    local radZ = math.rad(rotZ)

    -- Calcular a inclinação (tilt) desejada
    local tiltX = tiltDegrees * math.cos(radZ)
    local tiltY = tiltDegrees * math.sin(radZ)

    -- Calcular a nova rotação X e Y
    local newRotX = rotX + tiltX
    local newRotY = rotY + tiltY

    -- Retornar a nova rotação X, Y e Z
    return {x = newRotX, y = newRotY, z = rotZ}
end

function angleDifference(target, current)
    local diff = target - current
    if diff > 180 then
        diff = diff - 360
    elseif diff < -180 then
        diff = diff + 360
    end
    return diff
end

-- Função para converter graus para radianos
local function deg2rad(deg)
    return deg * math.pi / 180.0
end

-- Função para converter radianos para graus
local function rad2deg(rad)
    return rad * 180.0 / math.pi
end

-- Função para limitar o ângulo no intervalo de -180 a 180 graus
local function wrap180(deg)
    while deg <= -180.0 do deg = deg + 360.0 end
    while deg > 180.0 do deg = deg - 360.0 end
    return deg
end

-- Função para converter rotação XYZ para ZYX
function convertRotationXYZtoZYX(rotX, rotY, rotZ)
    -- Converter para radianos
    local x = deg2rad(rotX)
    local y = deg2rad(rotY)
    local z = deg2rad(rotZ)

    -- Matriz de rotação para XYZ
    local cosX = math.cos(x)
    local sinX = math.sin(x)
    local cosY = math.cos(y)
    local sinY = math.sin(y)
    local cosZ = math.cos(z)
    local sinZ = math.sin(z)

    local Rxyz = {
        {cosY * cosZ, -cosY * sinZ, sinY},
        {sinX * sinY * cosZ + cosX * sinZ, -sinX * sinY * sinZ + cosX * cosZ, -sinX * cosY},
        {-cosX * sinY * cosZ + sinX * sinZ, cosX * sinY * sinZ + sinX * cosZ, cosX * cosY}
    }

    -- Extrair ângulos ZYX da matriz de rotação
    local rotZ2 = math.atan2(Rxyz[2][1], Rxyz[1][1])
    local rotY2 = math.asin(-Rxyz[3][1])
    local rotX2 = math.atan2(Rxyz[3][2], Rxyz[3][3])

    -- Converter de volta para graus
    rotX2 = rad2deg(rotX2)
    rotY2 = rad2deg(rotY2)
    rotZ2 = rad2deg(rotZ2)

    -- Ajustar ângulos para o intervalo de -180 a 180 graus
    rotX2 = wrap180(rotX2)
    rotY2 = wrap180(rotY2)
    rotZ2 = wrap180(rotZ2)

    return {x = rotX2, y = -rotY2, z = rotZ2}
end

-- Função para adicionar duas rotações e retornar a rotação normalizada
function addRotation(rot1, rot2)
    local result = rot1 + rot2
    return wrap180(result)
end

-- Função para subtrair duas rotações e retornar a rotação normalizada
function subtractRotation(rot1, rot2)
    local result = rot1 - rot2
    return wrap180(result)
end

function SetEntitySpeedToCoord(Entity, CoordTarget, Mul, IgnoreX, IgnoreY, IgnoreZ, AddX, AddY, AddZ, Normalise, Relative, Vel)
    local OPos = ENTITY.GET_ENTITY_COORDS(Entity)
	local NewV3 = {
        x = (CoordTarget.x - OPos.x) * Mul,
        y = (CoordTarget.y - OPos.y) * Mul,
        z = (CoordTarget.z - OPos.z) * Mul
    }
    if IgnoreX then
        NewV3.x = 0.0
    end
    if IgnoreY then
        NewV3.y = 0.0
    end
    if IgnoreZ then
        NewV3.z = 0.0
    end
    if Normalise then
        NewV3 = v3.new(NewV3.x, NewV3.y, NewV3.z)
        if math.abs(NewV3.x) > Mul or math.abs(NewV3.y) > Mul or math.abs(NewV3.z) > Mul then
            NewV3 = v3.normalise(NewV3)
            NewV3:mul(Mul)
        end
    end
    local MoreX, MoreY, MoreZ = AddX, AddY, AddZ
    if Relative then
        local FVect, RVect, UpVect, Vect = v3.new(), v3.new(), v3.new(), v3.new()
        ENTITY.GET_ENTITY_MATRIX(Entity, FVect, RVect, UpVect, Vect)
        MoreX = (FVect.x * AddY) + (RVect.x * AddX) + (UpVect.x + AddZ)
        MoreY = (FVect.y * AddY) + (RVect.y * AddX) + (UpVect.y + AddZ)
        MoreZ = (FVect.z * AddY) + (RVect.z * AddX) + (UpVect.z + AddZ)
    end
	if Vel then
		if Vel.x ~= nil then
			NewV3.x = Vel.x
			--MoreX = 0.0
		end
		if Vel.y ~= nil then
			NewV3.y = Vel.y
			--MoreY = 0.0
		end
		if Vel.z ~= nil then
			--NewV3.z = Vel.z
			--MoreZ = 0.0
			MoreZ = Vel.z
		end
	end
    ENTITY.SET_ENTITY_VELOCITY(Entity, (NewV3.x) + MoreX, (NewV3.y) + MoreY, (NewV3.z) + MoreZ)
end

-- Função para ajustar a velocidade da entidade até um valor máximo
function ApplyVelocityToTarget(entity, targetVelocity, maxSpeed)
    -- Pega a velocidade atual da entidade
    local currentVelocity = ENTITY.GET_ENTITY_VELOCITY(entity)
    
    -- Calcula a magnitude (velocidade total) da entidade
    local currentSpeed = math.sqrt(currentVelocity.x^2 + currentVelocity.y^2 + currentVelocity.z^2)

    -- Se a velocidade atual for menor que a velocidade máxima, continue aplicando velocidade
    if currentSpeed < maxSpeed then
        -- Calcula o quanto falta para atingir a velocidade máxima
        local speedDifference = maxSpeed - currentSpeed

        -- Normaliza o vetor da velocidade alvo (direção)
        local magnitude = math.sqrt(targetVelocity.x^2 + targetVelocity.y^2 + targetVelocity.z^2)
        local normalizedVelocity = {
            x = targetVelocity.x / magnitude,
            y = targetVelocity.y / magnitude,
            z = targetVelocity.z / magnitude
        }

        -- Calcula o vetor de velocidade ajustado
        local newVelocity = {
            x = normalizedVelocity.x * speedDifference,
            y = normalizedVelocity.y * speedDifference,
            z = normalizedVelocity.z * speedDifference
        }

        -- Adiciona a nova velocidade à velocidade atual
        local finalVelocity = {
            x = currentVelocity.x + newVelocity.x,
            y = currentVelocity.y + newVelocity.y,
            z = currentVelocity.z + newVelocity.z
        }

        -- Aplica a nova velocidade à entidade
        ENTITY.SET_ENTITY_VELOCITY(entity, finalVelocity.x, finalVelocity.y, finalVelocity.z)
    end
end

-- Função para manter a rotação nos limites de -180 a 180 graus
function NormalizeRotation(angle)
    -- Mantém o ângulo dentro do intervalo de 0 a 360
    angle = angle % 360

    -- Se o ângulo for maior que 180, subtraímos 360 para trazê-lo para o intervalo de -180 a 180
    if angle > 180 then
        angle = angle - 360
    end

    return angle
end


-- Função para calcular o multiplicador de velocidade com base na direção da entidade em relação ao alvo
function CalculateDirectionMultiplier(entity, targetCoords)
    -- Pega a posição da entidade e a rotação atual
    local entityCoords = ENTITY.GET_ENTITY_COORDS(entity)
    local entityRotation = ENTITY.GET_ENTITY_ROTATION(entity, 2) -- Pegando a rotação como um vetor (X, Y, Z)

	entityRotation.z = NormalizeRotation(entityRotation.z + 90.0)
       -- Calcula o vetor direção da entidade (usando a rotação Z para simplificar, que seria o ângulo yaw)
	local entityDirX = math.cos(math.rad(entityRotation.z))
	local entityDirY = math.sin(math.rad(entityRotation.z))
   
	-- Calcula o vetor direção em direção ao alvo
	local targetDirX = targetCoords.x - entityCoords.x
	local targetDirY = targetCoords.y - entityCoords.y
   
	-- Normaliza o vetor direção do alvo
	local magnitude = math.sqrt(targetDirX^2 + targetDirY^2)
	targetDirX = targetDirX / magnitude
	targetDirY = targetDirY / magnitude
   
	-- Produto escalar entre o vetor direção da entidade e o vetor direção ao alvo
	local dotProduct = (entityDirX * targetDirX) + (entityDirY * targetDirY)
   
	-- Ajuste para garantir que o multiplicador seja 1 quando virado para o alvo e 0 quando de costas
	local speedMultiplier = math.max(0, dotProduct) -- Limita o valor entre 0 e 1
   
	return speedMultiplier
   
end

-- Função para adicionar uma rotação de uma ordem para outra mantendo a ordem final da rotação acumulada
function AddEulerRotation(baseEuler, baseOrder, addEuler, addOrder, resultOrder)
    -- Passo 1: Converter ambas as rotações para matrizes
    local baseMatrix = EulerToMatrix(baseEuler, baseOrder)
    local addMatrix = EulerToMatrix(addEuler, addOrder)

    -- Passo 2: Multiplicar as matrizes para compor as rotações
    local combinedMatrix = MultiplyMatrices(baseMatrix, addMatrix)

    -- Passo 3: Converter a matriz combinada de volta para a ordem desejada
    local resultEuler = MatrixToEuler(combinedMatrix, resultOrder)

    return resultEuler
end

-- Função para converter ângulos de Euler de uma ordem para outra
function ConvertEulerRotation(fromEuler, fromOrder, toOrder)
    -- Passo 1: Converter os ângulos de Euler para uma matriz de rotação (baseado na ordem original)
    local rotationMatrix = EulerToMatrix(fromEuler, fromOrder)
    
    -- Passo 2: Converter a matriz de rotação de volta para ângulos de Euler na nova ordem
    local toEuler = MatrixToEuler(rotationMatrix, toOrder)
    
    return toEuler
end

-- Função para converter ângulos de Euler para uma matriz de rotação
function EulerToMatrix(euler, order)
    local xRot, yRot, zRot = math.rad(euler.x), math.rad(euler.y), math.rad(euler.z)

    -- Matrizes de rotação para os três eixos
    local Rx = {
        {1, 0, 0},
        {0, math.cos(xRot), -math.sin(xRot)},
        {0, math.sin(xRot), math.cos(xRot)}
    }

    local Ry = {
        {math.cos(yRot), 0, math.sin(yRot)},
        {0, 1, 0},
        {-math.sin(yRot), 0, math.cos(yRot)}
    }

    local Rz = {
        {math.cos(zRot), -math.sin(zRot), 0},
        {math.sin(zRot), math.cos(zRot), 0},
        {0, 0, 1}
    }

    -- Multiplicando as matrizes na ordem especificada
    if order == "XYZ" then
        return MultiplyMatrices(MultiplyMatrices(Rx, Ry), Rz)
    elseif order == "XZY" then
        return MultiplyMatrices(MultiplyMatrices(Rx, Rz), Ry)
    elseif order == "YXZ" then
        return MultiplyMatrices(MultiplyMatrices(Ry, Rx), Rz)
    elseif order == "YZX" then
        return MultiplyMatrices(MultiplyMatrices(Ry, Rz), Rx)
    elseif order == "ZXY" then
        return MultiplyMatrices(MultiplyMatrices(Rz, Rx), Ry)
    elseif order == "ZYX" then
        return MultiplyMatrices(MultiplyMatrices(Rz, Ry), Rx)
    end
end

-- Função para converter uma matriz de rotação de volta para ângulos de Euler
function MatrixToEuler(matrix, order)
    local xRot, yRot, zRot

    if order == "XYZ" then
        yRot = math.asin(-matrix[1][3])
        xRot = math.atan2(matrix[2][3], matrix[3][3])
        zRot = math.atan2(matrix[1][2], matrix[1][1])
    elseif order == "XZY" then
        zRot = math.asin(matrix[1][2])
        xRot = math.atan2(-matrix[3][2], matrix[2][2])
        yRot = math.atan2(-matrix[1][3], matrix[1][1])
    elseif order == "YXZ" then
        xRot = math.asin(-matrix[2][3])
        yRot = math.atan2(matrix[1][3], matrix[3][3])
        zRot = math.atan2(matrix[2][1], matrix[2][2])
    elseif order == "YZX" then
        zRot = math.asin(-matrix[2][1])
        yRot = math.atan2(matrix[3][1], matrix[1][1])
        xRot = math.atan2(matrix[2][3], matrix[2][2])
    elseif order == "ZXY" then
        xRot = math.asin(matrix[3][2])
        zRot = math.atan2(-matrix[3][1], matrix[3][3])
        yRot = math.atan2(-matrix[1][2], matrix[2][2])
    elseif order == "ZYX" then
        xRot = math.asin(-matrix[3][1])
        zRot = math.atan2(matrix[2][1], matrix[1][1])
        yRot = math.atan2(matrix[3][2], matrix[3][3])
    end

    return {
        x = math.deg(xRot),
        y = math.deg(yRot),
        z = math.deg(zRot)
    }
end

-- Função para multiplicar duas matrizes 3x3
function MultiplyMatrices(A, B)
    local result = {}
    for i = 1, 3 do
        result[i] = {}
        for j = 1, 3 do
            result[i][j] = A[i][1] * B[1][j] + A[i][2] * B[2][j] + A[i][3] * B[3][j]
        end
    end
    return result
end


local PlaneTransfer = false
menu.toggle(GameModesMenu, "Plane Transfer", {}, "", function(Toggle)
	PlaneTransfer = Toggle
	if PlaneTransfer then
		local NewPolys = {}
		--local Nav1 = LoadNavmesh("PlaneNav.json")
		--local Nav2 = LoadNavmesh("PlaneNav.json")
		--local Center = calcularCentroNavmeshComIndices(Polys1, Nav1)
		--local Center2 = calcularCentroNavmeshComIndices(Polys1, Nav2)
		--local Offsets = calcularOffsetPoligonosComIndices(Polys1, Nav1, Center)
		--local Offsets2 = calcularOffsetPoligonosComIndices(Polys1, Nav2, Center2)
		--local New = armazenarOffsetsOriginaisComIndices(Offsets, Nav1)
		--local New2 = armazenarOffsetsOriginaisComIndices(Offsets2, Nav2)
		--local BorderIDs = descobrirPoligonosDeBordaComIndices(Polys1, PlatformIDs)
		local Vehs = {}
		local AddrLocal = SplitGlobals("Local_22960.f_834.f_81")
		local AddrLocalPeds = SplitGlobals("Local_22960.f_834")
		local Peds = {}
		local Count = 0
		while PlaneTransfer do
			if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_mission_controller")) > 0 then
				local GameTimer = MISC.GET_GAME_TIMER()
				for i = 1, 4 do
					if Vehs[i] == nil then
						local NetID = memory.read_int(memory.script_local("fm_mission_controller", AddrLocal + i))
						if NetID ~= 0 then
							local Handle = 0
							util.spoof_script("fm_mission_controller", function()
								Handle = NETWORK.NET_TO_VEH(NetID)
							end)
							if Handle ~= 0 then
								Vehs[i] = {Handle = Handle, NavMap = nil, NavMap2 = nil, OffsetsMap = nil}
								ENTITY.SET_ENTITY_VELOCITY(Handle, 0.0, 0.0, -1.0)
							end
						end
					end
					if Vehs[i] ~= nil then
						if i == 1 or i == 2 then
							local Veh = Vehs[i].Handle
							if Vehs[i].NavMap == nil then
								Vehs[i].NavMap = LoadNavmesh("PlaneNav.json")
								local Center = calcularCentroNavmeshComIndices(Polys1, Vehs[i].NavMap)
								local Offsets = calcularOffsetPoligonosComIndices(Polys1, Vehs[i].NavMap, Center)
								Vehs[i].OffsetsMap = armazenarOffsetsOriginaisComIndices(Offsets, Vehs[i].NavMap)
							end
							if Vehs[i].NavMap2 == nil then
								if i == 1 then
									if Vehs[2] ~= nil then
										if Vehs[2].NavMap ~= nil then
											Vehs[i].NavMap2 = Vehs[2].NavMap
										end
									end
								end
								if i == 2 then
									if Vehs[1] ~= nil then
										if Vehs[1].NavMap ~= nil then
											Vehs[i].NavMap2 = Vehs[1].NavMap
										end
									end
								end
							end
							if i == 2 then
								local FVect = ENTITY.GET_ENTITY_FORWARD_VECTOR(Veh)
								FVect:mul(30.0)
								ENTITY.SET_ENTITY_VELOCITY(Veh, FVect.x, FVect.y, FVect.z)
								RotateEntityToTargetRotation(Veh, {x = 0.0, y = 0.0, z = 0.0}, 1.0, false)
							end
							if ENTITY.DOES_ENTITY_EXIST(Veh) then
								
								local Rot = ENTITY.GET_ENTITY_ROTATION(Veh, 0)
								Rot.x = math.rad(Rot.x)
								Rot.y = math.rad(Rot.y)
								Rot.z = math.rad(Rot.z)
								local Pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Veh, 0.2, -11.0, 3.0)
								atualizarPoligonosParaDestinoERotacaoSemAcumuloComIndices(Vehs[i].OffsetsMap, Polys1, Vehs[i].NavMap, Pos, Rot)
								if Vehs[i].NavMap2 ~= nil then
									atualizarTodosVizinhosComIndices(Polys1, Vehs[i].NavMap2, Vehs[i].NavMap, 10.0)
								end
							end
						end
					end
				end
				for i = 1, 1 do
					if Peds[i] == nil then
						local NetID = memory.read_int(memory.script_local("fm_mission_controller", AddrLocalPeds + i))
						if NetID ~= 0 then
							local Handle = 0
							util.spoof_script("fm_mission_controller", function()
								Handle = NETWORK.NET_TO_PED(NetID)
							end)
							if Handle ~= 0 then
								Peds[i] = {Handle = Handle, Bits = 0, Paths = {}, CurPath = 1, Timer = 0, Veh = 0, OffsetPaths = {}, OldPaths = {}}
							end
						end
					end
					if Peds[i] ~= nil then
						local Ped = Peds[i].Handle
						if ENTITY.DOES_ENTITY_EXIST(Ped) then
							if not ENTITY.IS_ENTITY_DEAD(Ped) then
								if not is_bit_set(Peds[i].Bits, 1) then
									if Vehs[2] ~= nil then
										if ENTITY.DOES_ENTITY_EXIST(Vehs[2].Handle) then
											Peds[i].Bits = set_bit(Peds[i].Bits, 1)
											local Pos = ENTITY.GET_ENTITY_COORDS(Ped)
											local Target = ENTITY.GET_ENTITY_COORDS(Vehs[2].Handle)
											util.create_thread(function()
												local Paths = AStarPathFind(Pos, Target, 3, false)
												if Peds[i] ~= nil then
													if Paths ~= nil then
														Peds[i].CurPath = 1
														Peds[i].Paths = Paths
														if not is_bit_set(Peds[i].Bits, 2) then
															Peds[i].Bits = set_bit(Peds[i].Bits, 2)
														end
														if is_bit_set(Peds[i].Bits, 3) then
															Peds[i].Bits = clear_bit(Peds[i].Bits, 3)
														end
														Peds[i].OldPaths = {}
														for k = 1, #Paths do
															Peds[i].OldPaths[#Peds[i].OldPaths+1] = Paths[k]
														end
													else
														Peds[i].Bits = clear_bit(Peds[i].Bits, 1)
														if is_bit_set(Peds[i].Bits, 2) then
															Peds[i].Bits = clear_bit(Peds[i].Bits, 2)
														end
														if is_bit_set(Peds[i].Bits, 3) then
															Peds[i].Bits = clear_bit(Peds[i].Bits, 3)
														end
													end
													Peds[i].Timer = GameTimer
												end
											end)
										end
									end
								else
									if GameTimer > Peds[i].Timer+3000 then
										Peds[i].Bits = clear_bit(Peds[i].Bits, 1)
										Print("Called")
									end
								end
								if is_bit_set(Peds[i].Bits, 2) then
									if not is_bit_set(Peds[i].Bits, 3) then
										if Peds[i].Paths[Peds[i].CurPath] ~= nil then
											Peds[i].Bits = set_bit(Peds[i].Bits, 3)
											local Veh = PED.GET_VEHICLE_PED_IS_IN(Ped, true)
											if Veh ~= 0 then
												Peds[i].Veh = Veh
											end
										else
											if is_bit_set(Peds[i].Bits, 1) then
												Peds[i].Bits = clear_bit(Peds[i].Bits, 1)
											end
											Peds[i].Bits = clear_bit(Peds[i].Bits, 2)
										end
									end
									if is_bit_set(Peds[i].Bits, 3) then
										local TaskCoords = Peds[i].Paths[Peds[i].CurPath]
										if not is_bit_set(Peds[i].Bits, 4) then
											if Vehs[2] ~= nil then
												if ENTITY.DOES_ENTITY_EXIST(Vehs[2].Handle) then
													Peds[i].Bits = set_bit(Peds[i].Bits, 4)
													for k = 1, #Peds[i].OldPaths do
														local Offset = ENTITY.GET_OFFSET_FROM_ENTITY_GIVEN_WORLD_COORDS(Vehs[1].Handle, Peds[i].OldPaths[k].x, Peds[i].OldPaths[k].y, Peds[i].OldPaths[k].z)
														Peds[i].OffsetPaths[#Peds[i].OffsetPaths+1] = Offset
													end
												end
											end
										end
										if is_bit_set(Peds[i].Bits, 4) then
											if Vehs[2] ~= nil then
												if ENTITY.DOES_ENTITY_EXIST(Vehs[2].Handle) then
													local Offset = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Vehs[1].Handle, Peds[i].OffsetPaths[Peds[i].CurPath].x, Peds[i].OffsetPaths[Peds[i].CurPath].y, Peds[i].OffsetPaths[Peds[i].CurPath].z)
													TaskCoords = Offset
													Peds[i].Paths[Peds[i].CurPath] = Offset
												end
											end
										end
										if Peds[i].Veh ~= 0 then
											if ENTITY.DOES_ENTITY_EXIST(Peds[i].Veh) then
												if PED.IS_PED_IN_VEHICLE(Ped, Peds[i].Veh, false) then
													PED.SET_PED_CAN_BE_KNOCKED_OFF_VEHICLE(Ped, 1)
													local DirMul = CalculateDirectionMultiplier(Peds[i].Veh, TaskCoords)
													local Spd = 20.00
													directx.draw_text(0.5, 0.5, ""..DirMul, 0, 1.0, {r = 1.0, g = 1.0, b = 1.0, a = 1.0})
													--local FVect, RVect, UpVect, Vect = v3.new(), v3.new(), v3.new(), v3.new()
													--ENTITY.GET_ENTITY_MATRIX(Peds[i].Veh, FVect, RVect, UpVect, Vect)
													--FVect:mul(0.5)
													--ApplyVelocityToTarget(Peds[i].Veh, FVect, Spd)
													--SetEntitySpeedToCoord(Peds[i].Veh, TaskCoords, Spd * DirMul, true, true, true, 0.0, Spd * DirMul, 0.0, true, true, {z = ENTITY.GET_ENTITY_VELOCITY(Peds[i].Veh).z})
													--VEHICLE.SET_VEHICLE_FORWARD_SPEED(Peds[i].Veh, 10.0 * DirMul)
													local LookAt = v3.lookAt(ENTITY.GET_ENTITY_COORDS(Peds[i].Veh), v3.new(TaskCoords.x, TaskCoords.y, TaskCoords.z))
													local CurRot = ENTITY.GET_ENTITY_ROTATION(Peds[i].Veh, 2)
													CurRot.z = LookAt.z
													local NewRot = ConvertEulerRotation(CurRot, "XYZ", "ZYX")
													if not ENTITY.IS_ENTITY_IN_AIR(Peds[i].Veh) then
														ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(Peds[i].Veh, 1, 0.0, DirMul * 0.3, 0.0, 0, true, true, false)
													end
													RotateEntityToTargetRotation(Peds[i].Veh, ConvertEulerRotation(LookAt, "XYZ", "ZYX"), 10.0, true)
												end
											else
												Peds[i].Veh = 0
											end
										else
											Peds[i].Veh = PED.GET_VEHICLE_PED_IS_IN(Ped, true)
										end
										if ENTITY.IS_ENTITY_AT_COORD(Ped, TaskCoords.x, TaskCoords.y, TaskCoords.z, 2.5, 2.5, 100.0, false, false, 0) then
											Peds[i].Bits = clear_bit(Peds[i].Bits, 3)
											Peds[i].CurPath = Peds[i].CurPath + 1
											Print("Called")
										end
									end
								end
							end
							if Peds[i].Paths[1] ~= nil then
								local TaskCoords3 = Peds[i].Paths[1]
								local Pos = ENTITY.GET_ENTITY_COORDS(Ped)
								GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z,
								TaskCoords3.x, TaskCoords3.y, TaskCoords3.z, 255, 0, 0, 150)
								for k = 1, #Peds[i].Paths-1 do
									local TaskCoords = Peds[i].Paths[k]
									local TaskCoords2 = Peds[i].Paths[k+1]
									GRAPHICS.DRAW_LINE(TaskCoords.x, TaskCoords.y, TaskCoords.z,
									TaskCoords2.x, TaskCoords2.y, TaskCoords2.z, 255, 0, 0, 150)
								end
							end
						end
					end
				end
				if Vehs[1] ~= nil then
					if Vehs[1].NavMap ~= nil then
						local Nav1 = Vehs[1].NavMap
						for k = 1, #Nav1 do
							local CPos = Polys1[Nav1[k]].Center
							for i = 1, #Polys1[Nav1[k]].Neighboors do
								local CPos2 = Polys1[Polys1[Nav1[k]].Neighboors[i]].Center
								GRAPHICS.DRAW_LINE(CPos.x, CPos.y, CPos.z,
								CPos2.x, CPos2.y, CPos2.z, 255, 255, 255, 150)
							
							end
						end
					end
				end
			else
				Vehs = {}
				Peds = {}
			end
			Wait()
		end
		for k = 1, #Polys1 do
			table.remove(Polys1, #Polys1)
		end
	end
end)

-- Função para escanear a área e encontrar os pontos válidos para a navmesh
function escanearAreaParaNavmesh(centro, raio, passo)
    local pontosValidos = {}

    -- Percorre a área em um Grid
    for x = -raio, raio, passo do
        for y = -raio, raio, passo do
            local coordX = centro.x + x
            local coordY = centro.y + y
            local coordZ = centro.z

            -- Tenta encontrar o chão para a coordenada atual
			local groundZ = memory.alloc(8)
            local found, hitcoord = 
			ShapeTestNav(0, {x = coordX, y = coordY, z = coordZ}, {x = coordX, y = coordY, z = coordZ - 100.0}, GlobalRaycastFlags)
			--MISC.GET_GROUND_Z_FOR_3D_COORD(coordX, coordY, coordZ, groundZ, 0)

            -- Se encontrar um chão, adiciona o ponto à lista de pontos válidos
            if found then
                table.insert(pontosValidos, {x = coordX, y = coordY, z = hitcoord.z})
				--table.insert(pontosValidos, {x = coordX, y = coordY, z = memory.read_float(groundZ)})
            end
        end
    end

    return pontosValidos  -- Retorna os pontos válidos para gerar a navmesh
end

-- Função para gerar polígonos (quadrados) a partir dos pontos válidos
function gerarPoligonosAPartirDosPontos(pontos, passo)
    local poligonos = {}
    local LoopCount = 0
    -- Organizar os pontos em uma matriz bidimensional para garantir que formem uma grade
    local Grid2 = {}
	local i = 1
	while i <= #pontos do
		local ponto = pontos[i]
        local gridX = math.floor(ponto.x / passo)
        local gridY = math.floor(ponto.y / passo)
        Grid2[gridX] = Grid2[gridX] or {}
        Grid2[gridX][gridY] = ponto
		LoopCount = LoopCount + 1
		directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
		i = i + 1
    end
    
    -- Percorre a grade para formar polígonos (quadrados) com quatro pontos adjacentes
    for x, coluna in pairs(Grid2) do
        for y, p1 in pairs(coluna) do
            local p2 = Grid2[x + 1] and Grid2[x + 1][y]
            local p3 = Grid2[x] and Grid2[x][y + 1]
            local p4 = Grid2[x + 1] and Grid2[x + 1][y + 1]

            -- Se todos os quatro pontos existirem, formamos um quadrado
            if p1 and p2 and p3 and p4 then
                table.insert(poligonos, {p1, p2, p4, p3})  -- Forma o quadrado no sentido anti-horário
				--table.insert(poligonos, p1)
				--table.insert(poligonos, p2)
				--table.insert(poligonos, p3)
				--table.insert(poligonos, p4)
            end
			LoopCount = LoopCount + 1
			directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
        end
		LoopCount = LoopCount + 1
		directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
    end

    return poligonos  -- Retorna a lista de polígonos gerados
end

-- Função para gerar polígonos a partir de pontos rotacionados, considerando uma tolerância de alinhamento
function gerarPoligonosAPartirDosPontosComRotacao(pontos, passo, tolerancia)
    local poligonos = {}

    -- Organizar os pontos em uma matriz bidimensional (grid) para garantir que formem uma grade
    local grid = {}
    for _, ponto in ipairs(pontos) do
        -- Usar uma tolerância para ajustar o ponto ao grid
        local gridX = math.floor((ponto.x + tolerancia) / passo)
        local gridY = math.floor((ponto.y + tolerancia) / passo)

        grid[gridX] = grid[gridX] or {}
        grid[gridX][gridY] = ponto
    end

    -- Percorrer a grade para formar polígonos (quadrados) com quatro pontos adjacentes
    for x, coluna in pairs(grid) do
        for y, p1 in pairs(coluna) do
            local p2 = grid[x + 1] and grid[x + 1][y]
            local p3 = grid[x] and grid[x][y + 1]
            local p4 = grid[x + 1] and grid[x + 1][y + 1]

            -- Se todos os quatro pontos existirem, formar um quadrado
            if p1 and p2 and p3 and p4 then
                table.insert(poligonos, {p1, p2, p4, p3})  -- Forma o quadrado no sentido anti-horário
            end
        end
    end

    return poligonos  -- Retorna a lista de polígonos gerados
end

-- Função para conectar polígonos adjacentes
function conectarPoligonos(poligonos)
	local LoopCount = 0
    for i, poligono1 in ipairs(poligonos) do
		if poligono1.Neighboors == nil then
        	poligono1.Neighboors = {}
		end

        for j, poligono2 in ipairs(poligonos) do
            if i ~= j then
                -- Verifica se os polígonos compartilham um lado (dois vértices coincidem)
                if verificarCompartilhamentoDeLado(poligono1, poligono2) then
                    table.insert(poligono1.Neighboors, j)
                end
            end
			LoopCount = LoopCount + 1
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
        end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
    end
end

-- Função auxiliar para verificar se dois polígonos compartilham um lado
function verificarCompartilhamentoDeLado(poli1, poli2)
    local verticesEmComum = 0
    for _, vertice1 in ipairs(poli1) do
        for _, vertice2 in ipairs(poli2) do
            if vertice1.x == vertice2.x and vertice1.y == vertice2.y then
                verticesEmComum = verticesEmComum + 1
            end
        end
		--Wait()
    end
    return verticesEmComum >= 2
end

-- Função principal para gerar a navmesh
function gerarNavmesh(centro, raio, passo)
    -- 1. Escanear a área para encontrar pontos válidos
    local pontosValidos = escanearAreaParaNavmesh(centro, raio, passo)
    -- Verificar se encontramos pontos válidos
    if #pontosValidos == 0 then
        print("Nenhum ponto válido encontrado na área.")
        return
    end

    -- 2. Gerar polígonos a partir dos pontos escaneados
    local poligonos = gerarPoligonosAPartirDosPontos(pontosValidos, passo)
    -- 3. Conectar os polígonos para formar uma navmesh
    --conectarPoligonos(poligonos)

    -- 4. Exibir o resultado para fins de depuração
    --print("Navmesh gerada com sucesso. Número de polígonos: " .. #poligonos)
    --for i, poligono in ipairs(poligonos) do
    --    print("Polígono " .. i .. " tem vizinhos: " .. table.concat(poligono.Neighboors, ", "))
    --end

    -- Retorna os polígonos da navmesh gerada
    return poligonos
end

-- Função para calcular o vetor normal de um polígono (considerando polígonos de 3 ou 4 vértices)
function calcularVetorNormal(p1, p2, p3)
    -- Vetores de duas arestas do polígono
    local v1 = {x = p2.x - p1.x, y = p2.y - p1.y, z = p2.z - p1.z}
    local v2 = {x = p3.x - p1.x, y = p3.y - p1.y, z = p3.z - p1.z}

    -- Produto vetorial para obter o vetor normal
    local normal = {
        x = v1.y * v2.z - v1.z * v2.y,
        y = v1.z * v2.x - v1.x * v2.z,
        z = v1.x * v2.y - v1.y * v2.x
    }

    return normal
end

-- Função para calcular o ângulo entre o vetor normal e o eixo Z
function calcularAnguloComEixoZ(normal)
    -- Normalizar o vetor normal (módulo do vetor)
    local modulo = math.sqrt(normal.x^2 + normal.y^2 + normal.z^2)
    local normalizadoZ = normal.z / modulo  -- Componente Z do vetor normal normalizado

    -- O ângulo entre o vetor normal e o eixo Z é dado pelo arco cosseno da componente Z normalizada
    return math.deg(math.acos(normalizadoZ))  -- Converte para graus
end

-- Função para filtrar polígonos com muita inclinação
function filtrarPoligonosPorInclinacao(poligonos, anguloMaximo)
    local poligonosValidos = {}

	local LoopCount = 0
	local i = 1
	while i <= #poligonos do
		local poligono = poligonos[i]
        -- Considera os três primeiros vértices do polígono para calcular o vetor normal
        local p1, p2, p3 = poligono[1], poligono[2], poligono[3]

        -- Calcula o vetor normal do polígono
        local normal = calcularVetorNormal(p1, p2, p3)

        -- Calcula o ângulo do vetor normal com o eixo Z
        local angulo = calcularAnguloComEixoZ(normal)

        -- Se o ângulo for menor ou igual ao limite permitido, consideramos o polígono válido
        if angulo <= anguloMaximo then
            table.insert(poligonosValidos, poligono)
        end
		LoopCount = LoopCount + 1
		directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
		i = i + 1
    end

    return poligonosValidos  -- Retorna os polígonos que passaram no filtro de inclinação
end

function PoligonoInclinado(Poligono, AnguloMaximo)
	local p1, p2, p3 = Poligono[1], Poligono[2], Poligono[3]

	-- Calcula o vetor normal do polígono
	local normal = calcularVetorNormal(p1, p2, p3)

	-- Calcula o ângulo do vetor normal com o eixo Z
	local angulo = calcularAnguloComEixoZ(normal)
	return angulo <= AnguloMaximo
end

-- Função para calcular a variação de altura dos vértices de um polígono
function verificarVariacaoAltura(p1, p2, p3, p4)
    local maxZ = math.max(p1.z, p2.z, p3.z, p4.z)
    local minZ = math.min(p1.z, p2.z, p3.z, p4.z)
    return maxZ - minZ  -- Diferença entre a altura máxima e mínima
end

-- Função para filtrar polígonos com base na variação de altura
function filtrarPoligonosPorAltura(poligonos, alturaMaxima)
    local poligonosValidos = {}
	local LoopCount = 0
	local i = 1
	while i <= #poligonos do
		local poligono = poligonos[i]
        local p1, p2, p3, p4 = poligono[1], poligono[2], poligono[3], poligono[4]

        -- Verifica a variação de altura dos vértices
        local variacaoAltura = verificarVariacaoAltura(p1, p2, p3, p4)

        -- Se a variação for menor ou igual à altura máxima permitida, o polígono é válido
        if variacaoAltura <= alturaMaxima then
            table.insert(poligonosValidos, poligono)
        end
		LoopCount = LoopCount + 1
		directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
		i = i + 1
    end

    return poligonosValidos  -- Retorna os polígonos que passaram no filtro de altura
end

function filtrarPoligonosComTeto(poligonos)
    local poligonosValidos = {}
	local LoopCount = 0
	local i = 1
	while i <= #poligonos do
		local poligono = poligonos[i]

		local IsValid = true
		for k = 1, #poligono do
			local Hit = ShapeTestNav(0, {x = poligono[k].x, y = poligono[k].y, z = poligono[k].z}, {x = poligono[k].x, y = poligono[k].y, z = poligono[k].z + 1.0}, GlobalRaycastFlags)
			if Hit then
				IsValid = false
				break
			end
		end

		if IsValid then
			table.insert(poligonosValidos, poligono)
		end
		LoopCount = LoopCount + 1
		directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
		i = i + 1
    end

    return poligonosValidos  -- Retorna os polígonos que passaram no filtro de altura
end

function PoligonoColidindoComTeto(Poligono)
	local IsValid = true
	for k = 1, #Poligono do
		local Hit = ShapeTestNav(0, {x = Poligono[k].x, y = Poligono[k].y, z = Poligono[k].z}, {x = Poligono[k].x, y = Poligono[k].y, z = Poligono[k].z + 1.0}, GlobalRaycastFlags)
		if Hit then
			IsValid = false
			break
		end
	end
	return IsValid
end

-- Função principal para gerar a navmesh com inclinação filtrada
function gerarNavmeshComFiltroDeInclinacao(centro, raio, passo, anguloMaximo)
    -- 1. Escanear a área para encontrar pontos válidos
    local pontosValidos = escanearAreaParaNavmesh(centro, raio, passo)

    -- Verificar se encontramos pontos válidos
    if #pontosValidos == 0 then
        print("Nenhum ponto válido encontrado na área.")
        return
    end

    -- 2. Gerar polígonos a partir dos pontos escaneados
    local poligonos = gerarPoligonosAPartirDosPontos(pontosValidos, passo)

    -- 3. Filtrar os polígonos com muita inclinação
    local poligonosValidos = filtrarPoligonosPorInclinacao(poligonos, anguloMaximo)

    -- 4. Conectar os polígonos para formar uma navmesh
    --conectarPoligonos(poligonosValidos)
--
    ---- 5. Exibir o resultado para fins de depuração
    --for i, poligono in ipairs(poligonosValidos) do
    --    print("Polígono " .. i .. " tem vizinhos: " .. table.concat(poligono.vizinhos, ", "))
    --end

    -- Retorna os polígonos válidos da navmesh gerada
    return poligonosValidos
end

-- Função para ajustar os vértices de um polígono para a altura média
function ajustarAlturaVerticesParaMedia(poligono)
    local somaZ = 0
    local numVertices = #poligono

    -- Somar as alturas dos vértices
    for _, vertice in ipairs(poligono) do
        somaZ = somaZ + vertice.z
    end

    -- Calcular a altura média
    local alturaMedia = somaZ / numVertices

    -- Ajustar todos os vértices para a altura média
    for _, vertice in ipairs(poligono) do
        vertice.z = alturaMedia
    end
end

-- Função para ajustar todos os polígonos com base na altura média dos vértices
function ajustarPoligonosParaAlturaMedia(poligonos)
    for _, poligono in ipairs(poligonos) do
        ajustarAlturaVerticesParaMedia(poligono)
    end
end

-- Função para suavizar a altura dos vértices usando interpolação
function suavizarAlturaVertices(poligonos, fatorSuavizacao)
    for _, poligono in ipairs(poligonos) do
        local somaZ = 0
        local numVertices = #poligono

        -- Calcular a média das alturas dos vértices
        for _, vertice in ipairs(poligono) do
            somaZ = somaZ + vertice.z
        end
        local alturaMedia = somaZ / numVertices

        -- Suavizar os vértices, interpolando com a altura média
        for _, vertice in ipairs(poligono) do
            vertice.z = vertice.z * (1 - fatorSuavizacao) + alturaMedia * fatorSuavizacao
        end
    end
end

	-- Função principal para gerar a navmesh com ajuste de altura
function gerarNavmeshComAjusteDeAltura(centro, raio, passo, anguloMaximo)
	-- 1. Escanear a área para encontrar pontos válidos
	local pontosValidos = escanearAreaParaNavmesh(centro, raio, passo)

	-- Verificar se encontramos pontos válidos
	if #pontosValidos == 0 then
		print("Nenhum ponto válido encontrado na área.")
		return
	end

	-- 2. Gerar polígonos a partir dos pontos escaneados
	local poligonos = gerarPoligonosAPartirDosPontos(pontosValidos, passo)

	-- 3. Filtrar os polígonos com muita inclinação
	local poligonosValidos = filtrarPoligonosPorInclinacao(poligonos, anguloMaximo)

	-- 4. Ajustar os polígonos para que tenham altura média
	ajustarPoligonosParaAlturaMedia(poligonosValidos)
	
	-- Alternativa: Suavizar os vértices em vez de ajustar diretamente para a média
	-- suavizarAlturaVertices(poligonosValidos, fatorSuavizacao)

	-- 5. Conectar os polígonos para formar uma navmesh
	--conectarPoligonos(poligonosValidos)
--
	---- 6. Exibir o resultado para fins de depuração
	--for i, poligono in ipairs(poligonosValidos) do
	--	print("Polígono " .. i .. " tem vizinhos: " .. table.concat(poligono.vizinhos, ", "))
	--end

	-- Retorna os polígonos válidos da navmesh gerada
	return poligonosValidos
end
	

-- Função para verificar se um polígono tem vértices desalinhados (uma vértice muito abaixo dos outros)
function filtrarPoligonosComVerticesDesalinhados(poligonos, limiteDesalinhamento)
    local poligonosValidos = {}
	local LoopCount = 0
	local i = 1
	while i <= #poligonos do
		local poligono = poligonos[i]
        local somaZ = 0
        local numVertices = #poligono

        -- Somar as alturas dos vértices
        for _, vertice in ipairs(poligono) do
            somaZ = somaZ + vertice.z
        end

        -- Calcular a altura média dos vértices
        local alturaMedia = somaZ / numVertices

        -- Verificar se algum vértice está muito abaixo da média
        local desalinhado = false
        for _, vertice in ipairs(poligono) do
            if (alturaMedia - vertice.z) > limiteDesalinhamento then
                desalinhado = true
                break
            end
        end

        -- Se não houver vértices desalinhados, o polígono é válido
        if not desalinhado then
            table.insert(poligonosValidos, poligono)
        end
	
		LoopCount = LoopCount + 1
		directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
		i = i + 1
    end

    return poligonosValidos  -- Retorna os polígonos que passaram no filtro
end


function PoligonoDesalinhado(Poligono, LimiteDesalinhamento)
	local numVertices = #Poligono
	local somaZ = 0.0
	-- Somar as alturas dos vértices
	for _, vertice in ipairs(Poligono) do
		somaZ = somaZ + vertice.z
	end

	-- Calcular a altura média dos vértices
	local alturaMedia = somaZ / numVertices

	-- Verificar se algum vértice está muito abaixo da média
	local desalinhado = false
	for _, vertice in ipairs(Poligono) do
		if (alturaMedia - vertice.z) > LimiteDesalinhamento then
			desalinhado = true
			break
		end
	end
	return desalinhado
end

	-- Função principal para gerar a navmesh com filtro de desalinhamento de vértices
function gerarNavmeshComFiltroDeDesalinhamento(centro, raio, passo, anguloMaximo, limiteDesalinhamento)
	-- 1. Escanear a área para encontrar pontos válidos
	local pontosValidos = escanearAreaParaNavmesh(centro, raio, passo)

	-- Verificar se encontramos pontos válidos
	if #pontosValidos == 0 then
		print("Nenhum ponto válido encontrado na área.")
		return
	end

	-- 2. Gerar polígonos a partir dos pontos escaneados
	local poligonos = gerarPoligonosAPartirDosPontos(pontosValidos, passo)

	-- 3. Filtrar os polígonos com muita inclinação
	local poligonosValidos = filtrarPoligonosPorInclinacao(poligonos, anguloMaximo)

	-- 4. Filtrar polígonos com vértices desalinhados
	poligonosValidos = filtrarPoligonosComVerticesDesalinhados(poligonosValidos, limiteDesalinhamento)

	-- 5. Conectar os polígonos para formar uma navmesh
	--conectarPoligonos(poligonosValidos)
--
	---- 6. Exibir o resultado para fins de depuração
	--for i, poligono in ipairs(poligonosValidos) do
	--	print("Polígono " .. i .. " tem vizinhos: " .. table.concat(poligono.vizinhos, ", "))
	--end

	-- Retorna os polígonos válidos da navmesh gerada
	return poligonosValidos
end

-- Função principal para gerar a navmesh em múltiplas alturas
function gerarNavmeshMultiplasAlturas(centro, raio, passo, alturas)
	-- 1. Escanear e gerar as navmeshes para diferentes alturas
	local navmeshesPorAltura = escanearMultiplasAlturas(centro, raio, passo, alturas)

	-- 2. Conectar polígonos em cada navmesh individualmente
	--for _, poligonos in ipairs(navmeshesPorAltura) do
	--	conectarPoligonos(poligonos)
	--end
--
	---- 3. Exibir o resultado para fins de depuração
	--for altura, poligonos in ipairs(navmeshesPorAltura) do
	--	print("Altura: " .. alturas[altura] .. " - Polígonos: " .. #poligonos)
	--end

	return navmeshesPorAltura
end

-- Função para escanear em múltiplas camadas de altura e retornar uma única tabela de polígonos
function escanearMultiplasAlturas(centro, raio, passo, alturas, anguloMaximo, limiteDesalinhamento)
    local poligonosFinal = {}

    for _, altura in ipairs(alturas) do
        --print("Escaneando na altura: " .. altura)

        -- Ajustar a altura do ponto central para cada sessão de escaneamento
        local centroAltura = v3.new(centro.x, centro.y, altura)

        -- Escanear a área e gerar a navmesh para a altura atual
        local pontosValidos = escanearAreaParaNavmesh(centroAltura, raio, passo)

        -- Se encontrar pontos válidos, gerar polígonos
        if #pontosValidos > 0 then
            local poligonos = gerarPoligonosAPartirDosPontos(pontosValidos, passo)

            -- Filtrar polígonos por inclinação
            poligonos = filtrarPoligonosPorInclinacao(poligonos, anguloMaximo)

            -- Filtrar polígonos com vértices desalinhados
            poligonos = filtrarPoligonosComVerticesDesalinhados(poligonos, limiteDesalinhamento)

            -- Adicionar os polígonos filtrados à tabela final
            for _, poligono in ipairs(poligonos) do
                table.insert(poligonosFinal, poligono)
            end
        end
    end

    return poligonosFinal  -- Retorna a tabela final com todos os polígonos filtrados
end

-- Função para conectar rampas entre diferentes camadas de altura
function conectarRampasEntreAlturas(poligonos, limiteDeConexao)
    -- Conectar polígonos que estão próximos em diferentes alturas
	local LoopCount = 0
    for i, poligono1 in ipairs(poligonos) do
        for j, poligono2 in ipairs(poligonos) do
			if poligono1.Neighboors == nil then
				poligono1.Neighboors = {}
			end
			if poligono2.Neighboors == nil then
				poligono2.Neighboors = {}
			end
			if poligono1.ID == nil then
				poligono1.ID = i
			end
			if poligono2.ID == nil then
				poligono2.ID = j
			end
			if poligono1.Center == nil then
				poligono1.Center = GetPolygonCenter(poligono1)
			end
			if poligono2.Center == nil then
				poligono2.Center = GetPolygonCenter(poligono2)
			end
            if i ~= j then
                -- Verifica se a distância entre os polígonos está dentro do limite para conectar
                if verificarProximidadePoligonos(poligono1, poligono2, limiteDeConexao) then
                    -- Conectar os polígonos de rampas
					
                    table.insert(poligono1.Neighboors, j)
                    table.insert(poligono2.Neighboors, i)
                end
            end
			LoopCount = LoopCount + 1
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
        end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
    end
end

-- Função auxiliar para verificar a proximidade entre dois polígonos
function verificarProximidadePoligonos(poli1, poli2, limite)
    for _, vertice1 in ipairs(poli1) do
        for _, vertice2 in ipairs(poli2) do
            local distancia = math.sqrt((vertice1.x - vertice2.x)^2 + (vertice1.y - vertice2.y)^2 + (vertice1.z - vertice2.z)^2)
            if distancia <= limite then
                return true
            end
        end
    end
    return false
end

-- Função principal para gerar a navmesh com filtros e múltiplas alturas
function gerarNavmeshMultiplasAlturasComFiltros(centro, raio, passo, alturas, anguloMaximo, limiteDesalinhamento, limiteDeConexao)
    -- 1. Escanear e gerar os polígonos para diferentes alturas, já filtrando os polígonos inválidos
    local poligonosFinal = escanearMultiplasAlturas(centro, raio, passo, alturas, anguloMaximo, limiteDesalinhamento)

    -- 2. Conectar polígonos que representam rampas entre diferentes alturas
    conectarRampasEntreAlturas(poligonosFinal, limiteDeConexao)

    -- 3. Conectar os polígonos dentro da mesma altura
    conectarPoligonos(poligonosFinal)

    -- 4. Exibir o resultado para fins de depuração
    --print("Número total de polígonos válidos: " .. #poligonosFinal)
    --for i, poligono in ipairs(poligonosFinal) do
    --    print("Polígono " .. i .. " tem vizinhos: " .. table.concat(poligono.vizinhos, ", "))
    --end

    return poligonosFinal  -- Retorna a tabela final de polígonos conectados e filtrados
end

-- Função para verificar se dois vértices estão próximos o suficiente (com uma tolerância)
function verticesIguais(v1, v2, tolerancia)
    return math.abs(v1.x - v2.x) <= tolerancia and math.abs(v1.y - v2.y) <= tolerancia and math.abs(v1.z - v2.z) <= tolerancia
end

-- Função para verificar se dois polígonos têm as mesmas posições de vértices (com tolerância)
function poligonosIguais(poli1, poli2, tolerancia)
    for i, vertice1 in ipairs(poli1) do
        local vertice2 = poli2[i]
        if not verticesIguais(vertice1, vertice2, tolerancia) then
            return false
        end
    end
    return true
end

-- Função para filtrar e remover polígonos duplicados
function filtrarPoligonosDuplicados(poligonos, tolerancia)
    local poligonosFiltrados = {}
	local LoopCount = 0
	local i = 1
	while i <= #poligonos do
		local poligonoAtual = poligonos[i]
        local duplicado = false

		directx.draw_text(0.7, 0.30, "Filtering duped polygons. Stage "..i , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		local y = 1
		while y <= #poligonosFiltrados do
			directx.draw_text(0.7, 0.35, "Filtering duped polygons. Stage "..y , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
        -- Verifica se o polígono atual já foi registrado como duplicado
			local poligonoFiltrado = poligonosFiltrados[y]
            if poligonosIguais(poligonoAtual, poligonoFiltrado, tolerancia) then
                duplicado = true
                break
            end
			LoopCount = LoopCount + 1
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
			y = y + 1
        end

        -- Se o polígono não for duplicado, adiciona à lista filtrada
        if not duplicado then
            table.insert(poligonosFiltrados, poligonoAtual)
        end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
		i = i + 1
    end

    return poligonosFiltrados  -- Retorna a lista de polígonos filtrados (sem duplicatas)
end

-- Parâmetros para o cenário
local toleranciaDuplicatas = 0.01 -- Tolerância para considerar polígonos duplicados

-- Função principal para gerar a navmesh com filtros e sem polígonos duplicados
function gerarNavmeshMultiplasAlturasComFiltrosEFiltragemDeDuplicatas(centro, raio, passo, alturas, anguloMaximo, limiteDesalinhamento, limiteDeConexao)
    -- 1. Escanear e gerar os polígonos para diferentes alturas, já filtrando os polígonos inválidos
    local poligonosFinal = escanearMultiplasAlturas(centro, raio, passo, alturas, anguloMaximo, limiteDesalinhamento)

    -- 2. Filtrar polígonos duplicados
    poligonosFinal = filtrarPoligonosDuplicados(poligonosFinal, toleranciaDuplicatas)

    -- 3. Conectar polígonos que representam rampas entre diferentes alturas
    conectarRampasEntreAlturas(poligonosFinal, limiteDeConexao)

    -- 4. Conectar os polígonos dentro da mesma altura
    conectarPoligonos(poligonosFinal)

    -- 5. Exibir o resultado para fins de depuração
    --print("Número total de polígonos válidos após filtragem de duplicatas: " .. #poligonosFinal)
    --for i, poligono in ipairs(poligonosFinal) do
    --    print("Polígono " .. i .. " tem vizinhos: " .. table.concat(poligono.vizinhos, ", "))
    --end

    return poligonosFinal  -- Retorna a tabela final de polígonos conectados e filtrados
end

-- Função para fazer um Raycast e verificar se há colisão válida
function verificarColisaoRaycast(origem, direcao, distancia)
	local hit, hitPos = ShapeTestNav(0, {x = origem.x, y = origem.y, z = origem.z},
	{x = origem.x + direcao.x * distancia, y = origem.y + direcao.y * distancia, z = origem.z + direcao.z * distancia}, GlobalRaycastFlags)
    -- Retorna se houve colisão e a posição do impacto
    return hit, hitPos
end


-- Função para escanear a área e usar Raycast para verificar a acessibilidade dos pontos
function escanearAreaParaNavmeshComRaycast(centro, raio, passo, alturaRaycast, distanciaRaycast, RegPoints)
    local pontosValidos = {}
	local LoopCount = 0
	local x = -raio
	local LastZ = 0.0
	local Height = 0.5
    -- Percorre a área em um Grid
	while x <= raio do
		local y = -raio
		while y <= raio do
			for j = 0, 0 do
				local coordX = centro.x + x
				local coordY = centro.y + y
				local coordZ = centro.z
				if j == 1 then
					coordZ = coordZ + LastZ
				end
				
				directx.draw_text(0.7, 0.30, "Area X: "..x.." Area Y: "..y , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
				local found, hitcoord = ShapeTestNav(0, {x = coordX, y = coordY, z = coordZ}, {x = coordX, y = coordY, z = coordZ - 2.5}, GlobalRaycastFlags)
				-- Se encontrar o chão, faz um Raycast para verificar a acessibilidade
				if found then
					local origem = v3.new(coordX, coordY, coordZ + alturaRaycast)
					local direcao = v3.new(0, 0, -1.0)  -- Raycast direcionado para baixo
					local colisaoValida, hitPos = verificarColisaoRaycast(origem, direcao, distanciaRaycast)

					-- Apenas adiciona o ponto se o Raycast encontrar uma colisão válida
					if colisaoValida then
						local chave = math.floor(hitPos.x) .. "," .. math.floor(hitPos.y) .. "," .. math.floor(hitPos.z)
						if j == 1 then
							LastZ = (hitPos.z) - centro.z
						end
						if RegPoints[chave] == nil then
							RegPoints[chave] = {}
							RegPoints[chave][#RegPoints[chave]+1] = {x = hitPos.x, y = hitPos.y, z = hitPos.z + 0.5}
							table.insert(pontosValidos, {x = hitPos.x, y = hitPos.y, z = hitPos.z + 0.5})
						else
							local Bool = true
							for k = 1, #RegPoints[chave] do
								--if (hitPos.x) > RegPoints[chave][k].x+Height or (hitPos.x) < RegPoints[chave][k].x-Height and
								--(hitPos.y) > RegPoints[chave][k].y+Height or (hitPos.y) < RegPoints[chave][k].y-Height and
								--(hitPos.z + 0.5) > RegPoints[chave][k].z+Height*1 or (hitPos.z + 0.5) < RegPoints[chave][k].z-Height*1
								--then
								--Print(DistanceBetween2D(RegPoints[chave][k].x, RegPoints[chave][k].y, hitPos.x, hitPos.y))
								--if DistanceBetween2D(RegPoints[chave][k].x, RegPoints[chave][k].y, hitPos.x, hitPos.y) >= 0.00000000000001 then
								--	Bool = true
								--	break
								--end
							end
							if Bool then
								--RegPoints[chave][#RegPoints[chave]+1] = {x = hitPos.x, y = hitPos.y, z = hitPos.z + 0.5}
								table.insert(pontosValidos, {x = hitPos.x, y = hitPos.y, z = hitPos.z + 0.5})
							end
						end
					end
				end
			end
			LoopCount = LoopCount + 1
			directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
			y = y + passo
        end
		LoopCount = LoopCount + 1
		directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
		x = x + passo
    end

    return pontosValidos  -- Retorna os pontos válidos após verificar com Raycast
end

-- Função adaptada para escanear uma área angular com Raycast
function escanearAreaParaNavmeshComRaycastComRotacao(centro, raio, passo, alturaRaycast, distanciaRaycast, angulo)
    local pontosValidos = {}
	local LoopCount = 0
    -- Percorre a área em um grid rotacionado
    for x = -raio, raio, passo do
        for y = -raio, raio, passo do
            -- Definir o ponto original (antes da rotação)
            local pontoOriginal = {x = centro.x + x, y = centro.y + y, z = centro.z}

            -- Aplicar a rotação ao ponto
            local pontoRotacionado = rotacionarPonto2(pontoOriginal, centro, angulo)

            -- Tenta encontrar o chão para a coordenada rotacionada
           -- local _, groundZ = GetGroundZFor_3dCoord(pontoRotacionado.x, pontoRotacionado.y, pontoRotacionado.z, 0)
			local hit, endCoord = ShapeTestNav(0, {x = pontoRotacionado.x, y = pontoRotacionado.y, z = pontoRotacionado.z}, {x = pontoRotacionado.x, y = pontoRotacionado.y, z = pontoRotacionado.z - 100.0}, GlobalRaycastFlags)
			
            -- Se encontrar o chão, faz um Raycast para verificar a acessibilidade
            if hit then
                local origem = v3.new(pontoRotacionado.x, pontoRotacionado.y, endCoord.z + alturaRaycast)  -- Aumentar a altura de início do Raycast
                local direcao = v3.new(0, 0, -1)  -- Raycast para baixo
                local colisaoValida, hitPos = verificarColisaoRaycast(origem, direcao, distanciaRaycast)

                -- Apenas adiciona o ponto se o Raycast encontrar uma colisão válida
                if colisaoValida then
                    table.insert(pontosValidos, {x = hitPos.x, y = hitPos.y, z = hitPos.z + 0.5})
					util.create_thread(function()
						for k = 1, 1000 do
							GRAPHICS.DRAW_MARKER(28, hitPos.x,
							hitPos.y, hitPos.z + 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 150, 0, 0, 100, 0, false, 2, false, 0, 0, false)
							Wait()
						end
					end)
                end
            end
			LoopCount = LoopCount + 1
			directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
        end
		LoopCount = LoopCount + 1
		directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
    end

    return pontosValidos  -- Retorna os pontos válidos após verificar com Raycast
end


-- Função principal para gerar a navmesh com Raycast de colisão para melhorar a acessibilidade
function gerarNavmeshMultiplasAlturasComRaycast(centro, raio, passo, alturas, anguloMaximo, limiteDesalinhamento, limiteDeConexao, alturaRaycast, distanciaRaycast)
    local poligonosFinal = {}

    for _, altura in ipairs(alturas) do
        --print("Escaneando na altura: " .. altura)

        -- Ajustar a altura do ponto central para cada sessão de escaneamento
        local centroAltura = v3.new(centro.x, centro.y, altura)

        -- Escanear a área com Raycast e gerar os polígonos
        local pontosValidos = escanearAreaParaNavmeshComRaycast(centroAltura, raio, passo, alturaRaycast, distanciaRaycast)

        -- Se encontrar pontos válidos, gerar polígonos
        if #pontosValidos > 0 then
            local poligonos = gerarPoligonosAPartirDosPontos(pontosValidos, passo)

            -- Filtrar polígonos por inclinação
            poligonos = filtrarPoligonosPorInclinacao(poligonos, anguloMaximo)

            -- Filtrar polígonos com vértices desalinhados
            poligonos = filtrarPoligonosComVerticesDesalinhados(poligonos, limiteDesalinhamento)

            -- Adicionar os polígonos filtrados à tabela final
            for _, poligono in ipairs(poligonos) do
                table.insert(poligonosFinal, poligono)
            end
        end
    end
	
	poligonosFinal = filtrarPoligonosDuplicados(poligonosFinal, toleranciaDuplicatas)
    -- Conectar rampas e polígonos entre diferentes alturas
    conectarRampasEntreAlturas(poligonosFinal, limiteDeConexao)

    return poligonosFinal  -- Retorna a tabela final com todos os polígonos filtrados e conectados
end


-- Função para converter uma coordenada (X, Y, Z) em um índice de Grid
function coordenadaParaIndiceGrid2(x, y, z, tamanhoCelula)
    local gridX = math.floor(x / tamanhoCelula)
    local gridY = math.floor(y / tamanhoCelula)
    local gridZ = math.floor(z / tamanhoCelula)

    return gridX, gridY, gridZ  -- Retorna os índices do Grid correspondentes às coordenadas
end

-- Função para converter uma coordenada (X, Y, Z) em um índice de grid, considerando uma origem
function coordenadaParaIndiceGrid(x, y, z, origemX, origemY, origemZ, tamanhoCelula)
    local gridX = math.floor((x - origemX) / tamanhoCelula)
    local gridY = math.floor((y - origemY) / tamanhoCelula)
    local gridZ = math.floor((z - origemZ) / tamanhoCelula)

    return gridX, gridY, gridZ  -- Retorna os índices do grid correspondentes às coordenadas
end


-- Função para armazenar polígonos no Grid
function armazenarPoligonosNoGrid(poligonos, tamanhoCelula)
    for indice, poligono in ipairs(poligonos) do
        for _, vertice in ipairs(poligono) do
            -- Converter a coordenada do vértice para o índice do Grid
            local gridX, gridY, gridZ = coordenadaParaIndiceGrid2(vertice.x, vertice.y, vertice.z, tamanhoCelula)

            -- Se a célula ainda não existir, cria a lista
            Grid[gridX] = Grid[gridX] or {}
            Grid[gridX][gridY] = Grid[gridX][gridY] or {}
            Grid[gridX][gridY][gridZ] = Grid[gridX][gridY][gridZ] or {}

            -- Armazena o índice do polígono na célula correspondente
            table.insert(Grid[gridX][gridY][gridZ], indice)
        end
    end
end

-- Função para buscar o índice de um polígono mais próximo pela coordenada
function buscarPoligonoPorCoordenada(x, y, z, tamanhoCelula)
    -- Converter a coordenada para o índice do Grid
    local gridX, gridY, gridZ = coordenadaParaIndiceGrid2(x, y, z, tamanhoCelula)

    -- Verifica se a célula correspondente existe no Grid
    if Grid[gridX] and Grid[gridX][gridY] and Grid[gridX][gridY][gridZ] then
        -- Retorna a lista de polígonos na célula (pode haver mais de um polígono)
        return Grid[gridX][gridY][gridZ]
    else
        return nil  -- Nenhum polígono encontrado na célula
    end
end

function GetPolygonsFromGrid(Indexes)
	local Polygons = {}
	for _, indice in ipairs(Indexes) do
		Polygons[#Polygons+1] = Polys1[indice]
	end
	return Polygons
end

-- Função para verificar se o polígono atravessa uma parede usando Raycast
function verificarPoligonoAtravessandoParedes(poligono, distanciaRaycast)
    for i = 1, #poligono do
        local verticeAtual = poligono[i]
        local proximoVertice = poligono[(i % #poligono) + 1]

        -- Faz Raycast do vértice atual até o próximo vértice
        --local handle = StartShapeTestRay(verticeAtual.x, verticeAtual.y, verticeAtual.z, proximoVertice.x, proximoVertice.y, proximoVertice.z, -1, 0, 7)
        --local _, hit, _, _, _ = GetShapeTestResult(handle)
		local curVertV3 = v3.new(verticeAtual.x, verticeAtual.y, verticeAtual.z)
		local nextVertV3 = v3.new(proximoVertice.x, proximoVertice.y, proximoVertice.z)
		local hit, _, _, _ = ShapeTestNav(0, curVertV3, nextVertV3, GlobalRaycastFlags)
        -- Se o Raycast detectar uma colisão, significa que o polígono está atravessando uma parede
        if hit then
            return true  -- Polígono está atravessando uma parede
        end
    end

    return false  -- Polígono não está atravessando paredes
end

-- Função para filtrar polígonos que estão atravessando paredes
function filtrarPoligonosAtravessandoParedes(poligonos, distanciaRaycast)
    local poligonosValidos = {}

	local LoopCount = 0
	local i = 1
	while i <= #poligonos do
		local poligono = poligonos[i]
        -- Verifica se o polígono está atravessando uma parede
        local atravessando = verificarPoligonoAtravessandoParedes(poligono, distanciaRaycast)

        -- Se o polígono não estiver atravessando uma parede, ele é considerado válido
        if not atravessando then
            table.insert(poligonosValidos, poligono)
        end
		LoopCount = LoopCount + 1
		directx.draw_text(0.7, 0.35, "Loop Count "..LoopCount , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
		i = i + 1
    end

    return poligonosValidos  -- Retorna os polígonos que não atravessam paredes
end

-- Função principal para gerar a navmesh com filtro de polígonos atravessando paredes
function gerarNavmeshMultiplasAlturasComRaycastEFiltragem(centro, raio, passo, alturas, anguloMaximo, limiteDesalinhamento, limiteDeConexao, alturaRaycast, distanciaRaycast)
    local poligonosFinal = {}

    for _, altura in ipairs(alturas) do
        --print("Escaneando na altura: " .. altura)

        -- Ajustar a altura do ponto central para cada sessão de escaneamento
        local centroAltura = v3.new(centro.x, centro.y, altura)

        -- Escanear a área com Raycast e gerar os polígonos
        local pontosValidos = escanearAreaParaNavmeshComRaycast(centroAltura, raio, passo, alturaRaycast, distanciaRaycast)

        -- Se encontrar pontos válidos, gerar polígonos
        if #pontosValidos > 0 then
            local poligonos = gerarPoligonosAPartirDosPontos(pontosValidos, passo)

            -- Filtrar polígonos por inclinação
            poligonos = filtrarPoligonosPorInclinacao(poligonos, anguloMaximo)

            -- Filtrar polígonos com vértices desalinhados
            poligonos = filtrarPoligonosComVerticesDesalinhados(poligonos, limiteDesalinhamento)

            -- Filtrar polígonos que atravessam paredes
            poligonos = filtrarPoligonosAtravessandoParedes(poligonos, distanciaRaycast)

            -- Adicionar os polígonos filtrados à tabela final
            for _, poligono in ipairs(poligonos) do
                table.insert(poligonosFinal, poligono)
            end
        end
    end
	poligonosFinal = filtrarPoligonosDuplicados(poligonosFinal, toleranciaDuplicatas)
    -- Conectar rampas e polígonos entre diferentes alturas
    conectarRampasEntreAlturas(poligonosFinal, limiteDeConexao)

    return poligonosFinal  -- Retorna a tabela final com todos os polígonos filtrados e conectados
end

-- Função para verificar se dois polígonos podem ser vizinhos, verificando colisões com Raycast
function verificarVizinhosComRaycast(poli1, poli2)
    for i = 1, #poli1 do
        local vertice1 = poli1[i]
        for j = 1, #poli2 do
            local vertice2 = poli2[j]

            -- Faz um Raycast entre os dois vértices
            --local handle = StartShapeTestRay(vertice1.x, vertice1.y, vertice1.z, vertice2.x, vertice2.y, vertice2.z, -1, 0, 7)
            --local _, hit, _, _, _ = GetShapeTestResult(handle)
			local vertice1V3 = v3.new(vertice1.x, vertice1.y, vertice1.z)
			local vertice2V3 = v3.new(vertice2.x, vertice2.y, vertice2.z)
			local hit = ShapeTestNav(0, vertice1V3, vertice2V3, GlobalRaycastFlags)
            -- Se o Raycast detectar uma colisão, os polígonos não podem ser vizinhos
            if hit then
                return false  -- Há uma colisão, não são vizinhos
            end
        end
    end

    return true  -- Não houve colisão, são vizinhos
end

-- Função para conectar polígonos como vizinhos, verificando com Raycast antes de conectar
function conectarVizinhosComRaycast(poligonos, limiteDeConexao)
	local LoopCount = 0
	local i = 1
	while i <= #poligonos do
		local poligono1 = poligonos[i]
		local j = 1
		directx.draw_text(0.7, 0.45, "Starting to connect polygon neighbors, total is "..#poligonos , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		directx.draw_text(0.7, 0.50, "Starting to connect polygon neighbors, stage "..i , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
		while j <= #poligonos do
			directx.draw_text(0.7, 0.45, "Starting to connect polygon neighbors, total is "..#poligonos , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			directx.draw_text(0.7, 0.55, "Starting to connect polygon neighbors, stage "..j , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			local poligono2 = poligonos[j]
			if poligono1.Neighboors == nil then
				poligono1.Neighboors = {}
			end
			if poligono2.Neighboors == nil then
				poligono2.Neighboors = {}
			end
			if poligono1.ID == nil then
				poligono1.ID = i
			end
			if poligono2.ID == nil then
				poligono2.ID = j
			end
			if poligono1.Center == nil then
				poligono1.Center = GetPolygonCenter(poligono1)
			end
			if poligono2.Center == nil then
				poligono2.Center = GetPolygonCenter(poligono2)
			end
            if i ~= j then
                -- Verifica se os dois polígonos podem ser vizinhos usando Raycast
                if verificarVizinhosComRaycast(poligono1, poligono2) and verificarProximidadePoligonos(poligono1, poligono2, limiteDeConexao) or verificarCompartilhamentoDeLado(poligono1, poligono2) then
                    -- Conecta os polígonos como vizinhos se não houver colisão
                    table.insert(poligono1.Neighboors, j)
                end
            end
			LoopCount = LoopCount + 1
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
			j = j + 1
        end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
		i = i + 1
    end
end

-- Função para rotacionar um polígono em torno do centro (eixo Z)
function rotacionarPoligono(poligono, centro, angulo)
	local s = math.sin(angulo)
	local c = math.cos(angulo)

	local novoPoligono = {}

	for _, vertice in ipairs(poligono) do
		-- Translação do vértice em relação ao centro
		local px = vertice.x - centro.x
		local py = vertice.y - centro.y

		-- Aplicar a rotação
		local novoX = px * c - py * s
		local novoY = px * s + py * c

		-- Adicionar o vértice rotacionado ao novo polígono
		table.insert(novoPoligono, {x = novoX + centro.x, y = novoY + centro.y, z = vertice.z})
	end

	return novoPoligono
end
	
	-- Função para gerar polígonos a partir de pontos sem rotação e aplicar a rotação ao polígono completo
function gerarPoligonosComRotacaoFinal(pontos, passo, centro, angulo)
    local poligonos = {}

    -- Organizar os pontos em uma matriz bidimensional (grid) sem rotação
    local grid = {}
    for _, ponto in ipairs(pontos) do
        local gridX = math.floor(ponto.x / passo)
        local gridY = math.floor(ponto.y / passo)

        grid[gridX] = grid[gridX] or {}
        grid[gridX][gridY] = ponto
    end

    -- Percorre a grade para formar polígonos (quadrados) com quatro pontos adjacentes
    for x, coluna in pairs(grid) do
        for y, p1 in pairs(coluna) do
            local p2 = grid[x + 1] and grid[x + 1][y]
            local p3 = grid[x] and grid[x][y + 1]
            local p4 = grid[x + 1] and grid[x + 1][y + 1]

            -- Se todos os quatro pontos existirem, formamos um quadrado
            if p1 and p2 and p3 and p4 then
                -- Criar o polígono antes de rotacionar
                local poligono = {p1, p2, p4, p3}

                -- Aplicar a rotação ao polígono inteiro
                local poligonoRotacionado = rotacionarPoligono(poligono, centro, angulo)

                -- Inserir o polígono rotacionado na lista
                table.insert(poligonos, poligonoRotacionado)
            end
        end
    end

    return poligonos  -- Retorna a lista de polígonos gerados e rotacionados
end


-- Função principal para gerar a navmesh com filtro de vizinhos usando Raycast
function gerarNavmeshComVizinhosFiltradosPorRaycast(centro, raio, passo, alturas, anguloMaximo, limiteDesalinhamento, limiteDeConexao, alturaRaycast, distanciaRaycast, distanciaParedeRaycast, alturaMaxima, calculateNeighbors)
    local poligonosFinal = {}
	local i = #alturas
	local RegPoints = {}
	while i >= 1 do
		local altura = alturas[i]
        --print("Escaneando na altura: " .. altura)

        -- Ajustar a altura do ponto central para cada sessão de escaneamento
		directx.draw_text(0.7, 0.25, "Iterating height "..i , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
        local centroAltura = v3.new(centro.x, centro.y, altura)
		local pontosValidos = {}
		pontosValidos = escanearAreaParaNavmeshComRaycast(centroAltura, raio, passo, alturaRaycast, distanciaRaycast, RegPoints)
        -- Escanear a área com Raycast e gerar os polígonos
        -- Se encontrar pontos válidos, gerar polígonos
        if #pontosValidos > 0 then
			Print("Valid Points Size Is "..#pontosValidos)
			local poligonos = {}
			directx.draw_text(0.7, 0.40, "Generating Height Polygons "..i , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			--if angle then
			--	poligonos = gerarEajustarPoligonos(pontosValidos, passo, centro, angle, alturaRaycast)
			--else
			--local NewGrid = organizarPontosPorProximidade(pontosValidos, passo)
			--poligonos = formarPoligonosPorProximidade(NewGrid)
			--poligonos = formarPoligonosAngulares(pontosValidos, 1.5, 0.1)
			Print("Polygons size is "..#poligonos)
			poligonos = gerarPoligonosAPartirDosPontos(pontosValidos, passo)
			directx.draw_text(0.7, 0.45, "Polygons From Points Generated, Total is "..#poligonos , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			--end

            -- Filtrar polígonos por inclinação
            poligonos = filtrarPoligonosPorInclinacao(poligonos, anguloMaximo)
			directx.draw_text(0.7, 0.50, "Filtered Polygons From Rotation X, Total is "..#poligonos , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)

            -- Filtrar polígonos com vértices desalinhados
            poligonos = filtrarPoligonosComVerticesDesalinhados(poligonos, limiteDesalinhamento)
			directx.draw_text(0.7, 0.55, "Filtered Polygons From Wrong Rot, Total is "..#poligonos , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)

			poligonos = filtrarPoligonosAtravessandoParedes(poligonos, distanciaParedeRaycast)
			directx.draw_text(0.7, 0.60, "Filtered Polygons Passing Through Walls, Total is "..#poligonos , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			
			poligonos = filtrarPoligonosPorAltura(poligonos, alturaMaxima)
			directx.draw_text(0.7, 0.65, "Filtered Polygons With Much Height, Total is "..#poligonos , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
            -- Adicionar os polígonos filtrados à tabela final
			
			poligonos = filtrarPoligonosComTeto(poligonos)
            for _, poligono in ipairs(poligonos) do
                table.insert(poligonosFinal, poligono)
                table.insert(Polys1, poligono)
            end
			--poligonosFinal = filtrarPoligonosDuplicados(poligonosFinal, toleranciaDuplicatas)
			poligonosFinal = filtrarPoligonosDuplicados2(poligonosFinal, toleranciaDuplicatas)
			poligonosFinal = filtrarPoligonosDuplicadosComTolerancia(poligonosFinal, 0.5)
			Polys1 = poligonosFinal
			Print("New Polygons Size is "..#poligonos)
        end
		i = i - 1
    end
	directx.draw_text(0.7, 0.40, "Starting to filter duped polygons, total is "..#poligonosFinal , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
	local grid = inicializarGridEspacial(poligonosFinal, passo * 5)
	poligonosFinal = filtrarPoligonosDuplicadosComGrid(grid, passo * 5, 0.1)
	--poligonosFinal = filtrarPoligonosDuplicadosComTolerancia(poligonosFinal, 0.1)
	--filtrarPoligonosDuplicados2(poligonosFinal, toleranciaDuplicatas)
	--poligonosFinal = filtrarECombinarPoligonos(poligonosFinal)
    -- Conectar polígonos como vizinhos, verificando com Raycast antes de conectar
	if calculateNeighbors then
		directx.draw_text(0.7, 0.45, "Starting to connect polygon neighbors, total is "..#poligonosFinal , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
    	conectarVizinhosComRaycast(poligonosFinal, limiteDeConexao)
		directx.draw_text(0.7, 0.50, "Done connecting polygons neighbors" , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
	end
    return poligonosFinal  -- Retorna a tabela final com todos os polígonos filtrados e conectados
end

-- Função para inicializar um grid vazio baseado em uma área e uma origem específica
function inicializarGrid(origemX, origemY, tamanhoCelula, areaX, areaY)
    local grid = {}

    -- Criar o grid em torno da origem
    for x = origemX - areaX, origemX + areaX, tamanhoCelula do
        for y = origemY - areaY, origemY + areaY, tamanhoCelula do
            local gridX = math.floor((x - origemX) / tamanhoCelula)
            local gridY = math.floor((y - origemY) / tamanhoCelula)
            
            -- Inicializa a célula do grid
            grid[gridX] = grid[gridX] or {}
            grid[gridX][gridY] = {}
        end
    end

    return grid
end


-- Função para armazenar polígonos no grid usando uma origem específica e seus offsets
function armazenarPoligonosNoGridComOrigem(grid, poligonos, tamanhoCelula, origemX, origemY, origemZ, raioDeInfluencia)
    for indice, poligono in ipairs(poligonos) do
        for _, vertice in ipairs(poligono) do
            -- Encontrar a célula correspondente ao vértice considerando a origem do grid
            local gridX, gridY, gridZ = coordenadaParaIndiceGrid(vertice.x, vertice.y, vertice.z, origemX, origemY, origemZ, tamanhoCelula)

            -- Inserir o polígono na célula do grid correspondente
            grid[gridX] = grid[gridX] or {}
            grid[gridX][gridY] = grid[gridX][gridY] or {}
            table.insert(grid[gridX][gridY], indice)

            -- Expandir o polígono para células ao redor com base no raio de influência
            for dx = -raioDeInfluencia, raioDeInfluencia, tamanhoCelula do
                for dy = -raioDeInfluencia, raioDeInfluencia, tamanhoCelula do
                    local vizinhoX = gridX + dx / tamanhoCelula
                    local vizinhoY = gridY + dy / tamanhoCelula

                    -- Verifica se a célula vizinha existe e, se não, cria
                    grid[vizinhoX] = grid[vizinhoX] or {}
                    grid[vizinhoX][vizinhoY] = grid[vizinhoX][vizinhoY] or {}

                    -- Insere o índice do polígono na célula vizinha
                    table.insert(grid[vizinhoX][vizinhoY], indice)
                end
            end
        end
    end
end

-- Função para consultar o grid com base em uma coordenada transformada e uma origem
function consultarGridComOrigem(grid, x, y, z, origemX, origemY, origemZ, tamanhoCelula)
    -- Converter a coordenada para o sistema de grid, considerando a origem
    local gridX, gridY, gridZ = coordenadaParaIndiceGrid(x, y, z, origemX, origemY, origemZ, tamanhoCelula)

    -- Verifica se a célula correspondente existe no grid
    if grid[gridX] and grid[gridX][gridY] and grid[gridX][gridY][gridZ] then
        return grid[gridX][gridY][gridZ]  -- Retorna os polígonos armazenados nessa célula
    else
        return nil  -- Nenhum polígono encontrado
    end
end

-- Função para encontrar o polígono mais próximo de uma célula vazia
function buscarPoligonoMaisProximo(grid, x, y, tamanhoCelula, maxDistancia)
    local gridX, gridY = coordenadaParaIndiceGrid(x, y, tamanhoCelula)

    -- Se houver polígonos na célula atual, retorna-os
    if grid[gridX] and grid[gridX][gridY] and #grid[gridX][gridY] > 0 then
        return grid[gridX][gridY]
    end

    -- Caso contrário, procura nas células ao redor, dentro de um raio de maxDistancia
    for dist = 1, maxDistancia, tamanhoCelula do
        for dx = -dist, dist, tamanhoCelula do
            for dy = -dist, dist, tamanhoCelula do
                local vizinhoX = gridX + dx / tamanhoCelula
                local vizinhoY = gridY + dy / tamanhoCelula

                if grid[vizinhoX] and grid[vizinhoX][vizinhoY] and #grid[vizinhoX][vizinhoY] > 0 then
                    return grid[vizinhoX][vizinhoY]  -- Retorna o polígono mais próximo encontrado
                end
            end
        end
    end

    return nil  -- Nenhum polígono encontrado nas proximidades
end

-- Função para inicializar um grid estático baseado em uma área
function inicializarGridEstatico(areaX, areaY, tamanhoCelula)
    local grid = {}
	local LoopCount = 0
    -- Criar o grid com base em uma área fixa
    for x = -areaX, areaX, tamanhoCelula do
        for y = -areaY, areaY, tamanhoCelula do
            local gridX = math.floor(x / tamanhoCelula)
            local gridY = math.floor(y / tamanhoCelula)
            
            -- Inicializa a célula do grid
            grid[gridX] = grid[gridX] or {}
            grid[gridX][gridY] = {}
			LoopCount = LoopCount + 1
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
        end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
    end

    return grid
end

-- Função para converter uma coordenada (X, Y) em um índice de grid
function coordenadaParaIndiceGridEstatico(x, y, tamanhoCelula)
    local gridX = math.floor(x / tamanhoCelula)
    local gridY = math.floor(y / tamanhoCelula)

    return gridX, gridY  -- Retorna os índices do grid correspondentes às coordenadas
end

-- Função para armazenar polígonos no grid em um cenário estático
function armazenarPoligonosNoGridEstatico(grid, poligonos, tamanhoCelula, raioDeInfluencia)
	local LoopCount = 0
    for indice, poligono in ipairs(poligonos) do
        for _, vertice in ipairs(poligono) do
            -- Encontrar a célula correspondente ao vértice
            local gridX, gridY = coordenadaParaIndiceGridEstatico(vertice.x, vertice.y, tamanhoCelula)

            -- Inserir o polígono na célula do grid correspondente
            grid[gridX] = grid[gridX] or {}
            grid[gridX][gridY] = grid[gridX][gridY] or {}
            table.insert(grid[gridX][gridY], indice)

            -- Expandir o polígono para células ao redor com base no raio de influência
            for dx = -raioDeInfluencia, raioDeInfluencia, tamanhoCelula do
                for dy = -raioDeInfluencia, raioDeInfluencia, tamanhoCelula do
                    local vizinhoX = gridX + dx / tamanhoCelula
                    local vizinhoY = gridY + dy / tamanhoCelula

                    -- Verifica se a célula vizinha existe e, se não, cria
                    grid[vizinhoX] = grid[vizinhoX] or {}
                    grid[vizinhoX][vizinhoY] = grid[vizinhoX][vizinhoY] or {}

                    -- Insere o índice do polígono na célula vizinha
                    table.insert(grid[vizinhoX][vizinhoY], indice)
                end
				LoopCount = LoopCount + 1
				if LoopCount > MaxLoopCount then
					LoopCount = 0
					Wait()
				end
            end
			LoopCount = LoopCount + 1
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
        end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
    end
end

-- Função para consultar o grid em um cenário estático
function consultarGridEstatico(grid, x, y, tamanhoCelula)
    -- Converter a coordenada para o sistema de grid
    local gridX, gridY = coordenadaParaIndiceGridEstatico(x, y, tamanhoCelula)

    -- Verifica se a célula correspondente existe no grid
    if grid[gridX] and grid[gridX][gridY] then
		--Print(#grid[gridX][gridY])
        return grid[gridX][gridY]  -- Retorna os polígonos armazenados nessa célula
    else
        return nil  -- Nenhum polígono encontrado
    end
end

local NavmeshGeneratorMenu = menu.list(NavmeshingMenu, "Navmesh Generator", {}, "")

local GenerationSizeRadius = 50.0
menu.slider_float(NavmeshGeneratorMenu, "Generation Size Radius", {"generationsizeradius"}, "", 50, 20000, math.floor(GenerationSizeRadius) * 100, 100, function(on_change)
	GenerationSizeRadius = on_change / 100
end)
local CellSize = 1.0
menu.slider_float(NavmeshGeneratorMenu, "Cell Size", {"cellsize"}, "", 50, 2000, math.floor(CellSize) * 100, 50, function(on_change)
	CellSize = on_change / 100
end)
local MaxAngle = 50.0
menu.slider_float(NavmeshGeneratorMenu, "Max Angle", {"maxangle"}, "", 0, 20000, math.floor(MaxAngle) * 100, 50, function(on_change)
	MaxAngle = on_change / 100
end)
local MaxAlign = 5.5
menu.slider_float(NavmeshGeneratorMenu, "Max Align", {"maxalign"}, "", 50, 20000, math.floor(MaxAlign) * 100, 50, function(on_change)
	MaxAlign = on_change / 100
end)
local NeighborRadius = 0.10
menu.slider_float(NavmeshGeneratorMenu, "Neighbor Radius", {"neighborradius"}, "", 10, 20000, math.floor(NeighborRadius) * 100, 10, function(on_change)
	NeighborRadius = on_change / 100
end)
local ValidCollisionCheck = 2.0
menu.slider_float(NavmeshGeneratorMenu, "Valid Collision Check", {"validcollisioncheck"}, "", 50, 20000, math.floor(ValidCollisionCheck) * 100, 50, function(on_change)
	ValidCollisionCheck = on_change / 100
end)
local ValidCollisionCheck2 = 10.0
menu.slider_float(NavmeshGeneratorMenu, "Valid Collision Check 2", {"validcollisioncheck2"}, "", 50, 20000, math.floor(ValidCollisionCheck2) * 100, 50, function(on_change)
	ValidCollisionCheck2 = on_change / 100
end)
local WallCollisionCheck = 1.0
menu.slider_float(NavmeshGeneratorMenu, "Wall Collision Check", {"wallcollisioncheck"}, "", 0, 20000, math.floor(WallCollisionCheck) * 100, 10, function(on_change)
	WallCollisionCheck = on_change / 100
end)
local MaxHeight = 5.0
menu.slider_float(NavmeshGeneratorMenu, "Max Height", {"maxheight"}, "", 0, 20000, math.floor(MaxHeight) * 100, 10, function(on_change)
	MaxHeight = on_change / 100
end)
local NumFloors = 1
menu.slider(NavmeshGeneratorMenu, "Num Floors", {"numfloors"}, "", 1, 20, NumFloors, 1, function(on_change)
	NumFloors = on_change
end)

menu.action(NavmeshGeneratorMenu, "Generate Navmesh", {}, "", function(Toggle)
	local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	--Pos.z = Pos.z - 1.0
	local Floors = {}
	for k = 0, NumFloors-1 do
		Floors[#Floors+1] = Pos.z + 2.0 * k
	end
	local Rot = ENTITY.GET_ENTITY_HEADING(PLAYER.PLAYER_PED_ID())
	local Scan = gerarNavmeshComVizinhosFiltradosPorRaycast(Pos, GenerationSizeRadius, CellSize, Floors, MaxAngle, MaxAlign, NeighborRadius, ValidCollisionCheck, ValidCollisionCheck2, WallCollisionCheck, MaxHeight, false)
	--gerarNavmeshComVizinhosFiltradosPorRaycastAngled(Pos, GenerationSizeRadius, CellSize, {Pos.z}, MaxAngle, MaxAlign, NeighborRadius, ValidCollisionCheck, ValidCollisionCheck2, Rot)
	--gerarNavmeshComVizinhosFiltradosPorRaycast(Pos, GenerationSizeRadius, CellSize, {Pos.z}, MaxAngle, MaxAlign, NeighborRadius, ValidCollisionCheck, ValidCollisionCheck2, ENTITY.GET_ENTITY_FORWARD_VECTOR(PLAYER.PLAYER_PED_ID()))
	--gerarNavmeshMultiplasAlturasComRaycastEFiltragem(Pos, 30.0, 0.5, {Pos.z, Pos.z + 3.0, Pos.z + 6.0, Pos.z + 9.0}, 30.0, 0.50, 1.0, 1.0 * 1, 5.0 * 1)
	--gerarNavmeshMultiplasAlturasComRaycast(Pos, 30.0, 1.5, {Pos.z, Pos.z + 10.0, Pos.z + 20.0, Pos.z + 30.0}, 30.0, 1.0, 3.0, 2.0 * 1, 5.0 * 1)
	--gerarNavmeshMultiplasAlturasComFiltrosEFiltragemDeDuplicatas(Pos, 20.0, 2.5, {Pos.z, Pos.z + 10.0, Pos.z + 20.0}, 50.0, 5.0, 0.0)
	--gerarNavmeshMultiplasAlturas(Pos, 50.0, 2.5, {Pos.z, Pos.z + 10.0})
	--gerarNavmeshComFiltroDeDesalinhamento(Pos, 50.0, 2.5, 30.0, 1.0)--gerarNavmesh(Pos, 50.0, 2.0)
	if Scan and #Scan > 0 then
		Polys1 = Scan
		Print("Calculating neighbors")
		--Grid = {}
		----armazenarPoligonosNoGrid(Polys1, GridSizeIteration)
		--armazenarPoligonosNoGridComOrigem(Grid, Polys1, 5.0, Center.x, Center.y, Center.z, 10.0)
		--conectarVizinhosComRaycast(Polys1, NeighborRadius)
		Grid = {}
		local IDs = {}
		for k = 1, #Polys1 do
			IDs[#IDs+1] = k
			Polys1[k].ID = k
			Polys1[k].Center = GetPolygonCenter(Polys1[k])
		end
		Polys1Center = calcularCentroNavmeshComIndices(Polys1, IDs)
		Grid = inicializarGridEstatico(Polys1Center.x, Polys1Center.y, GlobalCellSize)
		armazenarPoligonosNoGridEstatico(Grid, Polys1, GlobalCellSize, GlobalInfluenceRadius * GlobalCellSize)
		local NeighborGrid = inicializarGrid3D(Polys1, CellSize)
		local LoopCount = 0
		for k = 1, #Polys1 do
			Polys1[k].Neighboors = buscarVizinhosNoGrid(k, Polys1, NeighborGrid, CellSize)
			LoopCount = LoopCount + 1
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
		end
		Print(#Scan)
	end
end)

menu.action(NavmeshGeneratorMenu, "Generate Navmesh V2", {}, "", function(Toggle)
	local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
	local Heading = ENTITY.GET_ENTITY_HEADING(PLAYER.PLAYER_PED_ID())
	local NavAreaSize = GenerationSizeRadius
	local StepSize = CellSize
	local sqrt2_div_2 = 0.70710678118  -- Raiz de 2 dividida por 2
	local StepSizeDiagonal = StepSize * sqrt2_div_2
	local Floors = {}
	for k = 0, NumFloors-1 do
		Floors[#Floors+1] = Pos.z + 2.0 * k
	end
	local Points = {}
	local NeighborsToCalc = {}
	local DeepScan = 10.0
	Polys1 = {}
	local IDsAdded = {}
	local NumOfNumber = 2
	local PointsScanned = {}
	local i = 1
	while i <= #Floors do
		local x = -NavAreaSize
		while x <= NavAreaSize do
			local y = -NavAreaSize
			while y <= NavAreaSize do
				local StartPointOriginal = {x = Pos.x + x, y = Pos.y + y, z = Floors[i]}
				local RotatedPoint = rotacionarPonto2(StartPointOriginal, Pos, math.rad(Heading))
				local StartRayPos = {
					x = RotatedPoint.x,
					y = RotatedPoint.y,
					z = RotatedPoint.z
				}
				local RayPos = {
					x = RotatedPoint.x,
					y = RotatedPoint.y,
					z = RotatedPoint.z - DeepScan
				}
				local Hit_, StartRayPos2 = ShapeTestNav(PLAYER.PLAYER_PED_ID(), StartRayPos, RayPos, GlobalRaycastFlags)
				StartRayPos2.z = StartRayPos2.z + 1.0
				local PointKey = string.format("%." ..NumOfNumber.."f", StartRayPos2.x) .. " "..string.format("%." ..NumOfNumber.."f", StartRayPos2.y) .. " "..string.format("%." ..NumOfNumber.."f", StartRayPos2.z)
				if PointsScanned[PointKey] == nil then
					PointsScanned[PointKey] = 0
					local Pos1 = GetPositionCircle(StartRayPos2, StepSizeDiagonal, addRotation(Heading, 45.0))
					local Pos2 = GetPositionCircle(StartRayPos2, StepSizeDiagonal, addRotation(Heading, 135.0))
					local Pos3 = GetPositionCircle(StartRayPos2, StepSizeDiagonal, addRotation(Heading, 225.0))
					local Pos4 = GetPositionCircle(StartRayPos2, StepSizeDiagonal, addRotation(Heading, 315.0))
					
					local Hit, OutCoord = ShapeTestNav(PLAYER.PLAYER_PED_ID(), StartRayPos2, Pos1, GlobalRaycastFlags)
					local Hit2, OutCoord2 = ShapeTestNav(PLAYER.PLAYER_PED_ID(), StartRayPos2, Pos2, GlobalRaycastFlags)
					local Hit3, OutCoord3 = ShapeTestNav(PLAYER.PLAYER_PED_ID(), StartRayPos2, Pos3, GlobalRaycastFlags)
					local Hit4, OutCoord4 = ShapeTestNav(PLAYER.PLAYER_PED_ID(), StartRayPos2, Pos4, GlobalRaycastFlags)
					OutCoord.z = OutCoord.z + 1.0
					OutCoord2.z = OutCoord2.z + 1.0
					OutCoord3.z = OutCoord3.z + 1.0
					OutCoord4.z = OutCoord4.z + 1.0
					local RayPos1 = {x = OutCoord.x, y = OutCoord.y, z = OutCoord.z - DeepScan}
					local RayPos2 = {x = OutCoord2.x, y = OutCoord2.y, z = OutCoord2.z - DeepScan}
					local RayPos3 = {x = OutCoord3.x, y = OutCoord3.y, z = OutCoord3.z - DeepScan}
					local RayPos4 = {x = OutCoord4.x, y = OutCoord4.y, z = OutCoord4.z - DeepScan}
					local Hit, _OutCoord = ShapeTestNav(PLAYER.PLAYER_PED_ID(), OutCoord, RayPos1, GlobalRaycastFlags)
					local Hit2, _OutCoord2 = ShapeTestNav(PLAYER.PLAYER_PED_ID(), OutCoord2, RayPos2, GlobalRaycastFlags)
					local Hit3, _OutCoord3 = ShapeTestNav(PLAYER.PLAYER_PED_ID(), OutCoord3, RayPos3, GlobalRaycastFlags)
					local Hit4, _OutCoord4 = ShapeTestNav(PLAYER.PLAYER_PED_ID(), OutCoord4, RayPos4, GlobalRaycastFlags)

					_OutCoord.z = _OutCoord.z + 1.0
					_OutCoord2.z = _OutCoord2.z + 1.0
					_OutCoord3.z = _OutCoord3.z + 1.0
					_OutCoord4.z = _OutCoord4.z + 1.0
					local IsValid = true
					local NewPoly = {_OutCoord, _OutCoord2, _OutCoord3, _OutCoord4}
					for k = 1, #NewPoly do
						for j = 1, #NewPoly do
							if k ~= j then
								if ShapeTestNav(PLAYER.PLAYER_PED_ID(), NewPoly[k], NewPoly[i], GlobalRaycastFlags) then
									IsValid = false
									break
								end
							end
						end
					end
					if IsValid then
						local PassingThrougWalls = not verificarPoligonoAtravessandoParedes(NewPoly, WallCollisionCheck)
						and verificarVariacaoAltura(NewPoly[1], NewPoly[2], NewPoly[3], NewPoly[4]) <= MaxHeight
						and PoligonoColidindoComTeto(NewPoly) and not PoligonoInclinado(NewPoly, MaxAngle)
						and not PoligonoDesalinhado(NewPoly, MaxAlign)
						if not PassingThrougWalls then
							Polys1[#Polys1+1] = {_OutCoord, _OutCoord2, _OutCoord3, _OutCoord4, ID = #Polys1+1, Neighboors = {}}
							Polys1[#Polys1].Center = GetPolygonCenter(Polys1[#Polys1])
							local Key = string.format("%." ..NumOfNumber.."f", _OutCoord.x) .. " "..string.format("%." ..NumOfNumber.."f", _OutCoord.y) .. " "..string.format("%." ..NumOfNumber.."f", _OutCoord.z)
							local Key2 = string.format("%." ..NumOfNumber.."f", _OutCoord2.x) .. " "..string.format("%." ..NumOfNumber.."f", _OutCoord2.y) .. " "..string.format("%." ..NumOfNumber.."f", _OutCoord2.z)
							local Key3 = string.format("%." ..NumOfNumber.."f", _OutCoord3.x) .. " "..string.format("%." ..NumOfNumber.."f", _OutCoord3.y) .. " "..string.format("%." ..NumOfNumber.."f", _OutCoord3.z)
							local Key4 = string.format("%." ..NumOfNumber.."f", _OutCoord4.x) .. " "..string.format("%." ..NumOfNumber.."f", _OutCoord4.y) .. " "..string.format("%." ..NumOfNumber.."f", _OutCoord4.z)
							
							NeighborsToCalc[Key] = NeighborsToCalc[Key] or {}
							NeighborsToCalc[Key2] = NeighborsToCalc[Key2] or {}
							NeighborsToCalc[Key3] = NeighborsToCalc[Key3] or {}
							NeighborsToCalc[Key4] = NeighborsToCalc[Key4] or {}
							NeighborsToCalc[Key][#NeighborsToCalc[Key]+1] = Polys1[#Polys1].ID
							NeighborsToCalc[Key2][#NeighborsToCalc[Key2]+1] = Polys1[#Polys1].ID
							NeighborsToCalc[Key3][#NeighborsToCalc[Key3]+1] = Polys1[#Polys1].ID
							NeighborsToCalc[Key4][#NeighborsToCalc[Key4]+1] = Polys1[#Polys1].ID
							
							for k = 1, #NeighborsToCalc[Key] do
								IDsAdded[NeighborsToCalc[Key][k]] = IDsAdded[NeighborsToCalc[Key][k]] or {}
								for i = 1, #NeighborsToCalc[Key] do
									if NeighborsToCalc[Key][k] ~= NeighborsToCalc[Key][i] then
										if IDsAdded[NeighborsToCalc[Key][k]][NeighborsToCalc[Key][i]] == nil then
											Polys1[NeighborsToCalc[Key][k]].Neighboors[#Polys1[NeighborsToCalc[Key][k]].Neighboors+1] = NeighborsToCalc[Key][i]
											IDsAdded[NeighborsToCalc[Key][k]][NeighborsToCalc[Key][i]] = 0
										end
									end
								end
							end
							for k = 1, #NeighborsToCalc[Key2] do
								IDsAdded[NeighborsToCalc[Key2][k]] = IDsAdded[NeighborsToCalc[Key2][k]] or {}
								for i = 1, #NeighborsToCalc[Key2] do
									if NeighborsToCalc[Key2][k] ~= NeighborsToCalc[Key2][i] then
										if IDsAdded[NeighborsToCalc[Key2][k]][NeighborsToCalc[Key2][i]] == nil then
											Polys1[NeighborsToCalc[Key2][k]].Neighboors[#Polys1[NeighborsToCalc[Key2][k]].Neighboors+1] = NeighborsToCalc[Key2][i]
											IDsAdded[NeighborsToCalc[Key2][k]][NeighborsToCalc[Key2][i]] = 0
										end
									end
								end
							end
							for k = 1, #NeighborsToCalc[Key3] do
								IDsAdded[NeighborsToCalc[Key3][k]] = IDsAdded[NeighborsToCalc[Key3][k]] or {}
								for i = 1, #NeighborsToCalc[Key3] do
									if NeighborsToCalc[Key3][k] ~= NeighborsToCalc[Key3][i] then
										if IDsAdded[NeighborsToCalc[Key3][k]][NeighborsToCalc[Key3][i]] == nil then
											Polys1[NeighborsToCalc[Key3][k]].Neighboors[#Polys1[NeighborsToCalc[Key3][k]].Neighboors+1] = NeighborsToCalc[Key3][i]
											IDsAdded[NeighborsToCalc[Key3][k]][NeighborsToCalc[Key3][i]] = 0
										end
									end
								end
							end
							for k = 1, #NeighborsToCalc[Key4] do
								IDsAdded[NeighborsToCalc[Key4][k]] = IDsAdded[NeighborsToCalc[Key4][k]] or {}
								for i = 1, #NeighborsToCalc[Key4] do
									if NeighborsToCalc[Key4][k] ~= NeighborsToCalc[Key4][i] then
										if IDsAdded[NeighborsToCalc[Key4][k]][NeighborsToCalc[Key4][i]] == nil then
											Polys1[NeighborsToCalc[Key4][k]].Neighboors[#Polys1[NeighborsToCalc[Key4][k]].Neighboors+1] = NeighborsToCalc[Key4][i]
											IDsAdded[NeighborsToCalc[Key4][k]][NeighborsToCalc[Key4][i]] = 0
										end
									end
								end
							end
						end
					end
				end
				y = y + StepSize
				--Wait()
			end
			x = x + StepSize
			Wait()
		end
		i = i + 1
		Wait()
	end
	Grid = {}
	local IDs = {}
	for k = 1, #Polys1 do
		IDs[#IDs+1] = k
		Polys1[k].ID = k
		Polys1[k].Center = GetPolygonCenter(Polys1[k])
	end
	Polys1Center = calcularCentroNavmeshComIndices(Polys1, IDs)
	Grid = inicializarGridEstatico(Polys1Center.x, Polys1Center.y, GlobalCellSize)
	armazenarPoligonosNoGridEstatico(Grid, Polys1, GlobalCellSize, GlobalInfluenceRadius * GlobalCellSize)
	Print("Generated "..#Polys1.." Polygons")
end)

--armazenarPoligonosNoGrid(Polys1, GridSizeIteration)
--local IDs = {}
--for k = 1, #Polys1 do
--	IDs[#IDs+1] = Polys1[k].ID
--end
--local Center = calcularCentroNavmeshComIndices(Polys1, IDs)
--Grid = inicializarGrid(Center.x, Center.y, 5.0, 1000.0, 1000.0)
--
--armazenarPoligonosNoGridComOrigem(Grid, Polys1, 5.0, Center.x, Center.y, Center.z, 10.0)

function AdjustTraveledPaths(Indexes, PolysT, Pos)
	local Index = 2
	for k = 1, #Indexes do
		if InsidePolygon(PolysT[Indexes[k]], Pos) then
			return Index
		else
			Index = Index + 1
		end
	end
	return Index
end

-- Função para criar um novo nó na kd-tree
function novoKdNode(ponto, esquerda, direita)
    return {ponto = ponto, esquerda = esquerda, direita = direita}
end

-- Função recursiva para construir a kd-tree
function construirKdTree(pontos, profundidade)
    if #pontos == 0 then
        return nil
    end

    profundidade = profundidade or 0

    -- Alterna entre as dimensões (x, y, z) com base na profundidade
    local eixo = profundidade % 3 + 1

    -- Ordena os pontos com base na dimensão atual
    table.sort(pontos, function(a, b)
        return a[eixo] < b[eixo]
    end)

    -- Achar o ponto do meio para dividir a árvore
    local meio = math.floor(#pontos / 2) + 1

    -- Criar o nó da kd-tree
    return novoKdNode(
        pontos[meio],  -- Ponto do meio
        construirKdTree({table.unpack(pontos, 1, meio - 1)}, profundidade + 1),  -- Subárvore esquerda
        construirKdTree({table.unpack(pontos, meio + 1, #pontos)}, profundidade + 1)  -- Subárvore direita
    )
end

-- Função para calcular a distância euclidiana entre dois pontos
function calcularDistancia2(ponto1, ponto2)
    return math.sqrt((ponto1[1] - ponto2[1])^2 + (ponto1[2] - ponto2[2])^2 + (ponto1[3] - ponto2[3])^2)
end

-- Função para encontrar o polígono mais próximo em uma kd-tree
function buscarVizinhoMaisProximo(kdNode, ponto, profundidade, melhorNo, melhorDistancia)
    if kdNode == nil then
        return melhorNo, melhorDistancia
    end

    profundidade = profundidade or 0
    melhorNo = melhorNo or kdNode.ponto
    melhorDistancia = melhorDistancia or calcularDistancia2(ponto, kdNode.ponto)

    -- Alterna entre as dimensões (x, y, z) com base na profundidade
    local eixo = profundidade % 3 + 1

    -- Verificar a distância para o nó atual
    local distanciaAtual = calcularDistancia2(ponto, kdNode.ponto)
    if distanciaAtual < melhorDistancia then
        melhorNo = kdNode.ponto
        melhorDistancia = distanciaAtual
    end

    -- Determina qual ramo da kd-tree deve ser verificado
    local proximoRamo, outroRamo
    if ponto[eixo] < kdNode.ponto[eixo] then
        proximoRamo = kdNode.esquerda
        outroRamo = kdNode.direita
    else
        proximoRamo = kdNode.direita
        outroRamo = kdNode.esquerda
    end

    -- Explorar o ramo mais próximo primeiro
    melhorNo, melhorDistancia = buscarVizinhoMaisProximo(proximoRamo, ponto, profundidade + 1, melhorNo, melhorDistancia)

    -- Explorar o outro ramo se for possível encontrar algo mais próximo
    if math.abs(ponto[eixo] - kdNode.ponto[eixo]) < melhorDistancia then
        melhorNo, melhorDistancia = buscarVizinhoMaisProximo(outroRamo, ponto, profundidade + 1, melhorNo, melhorDistancia)
    end

    return melhorNo, melhorDistancia
end

-- Função recursiva para encontrar os k vizinhos mais próximos em uma kd-tree
function buscarVizinhosMaisProximos(kdNode, ponto, k, profundidade, melhorNos)
    if kdNode == nil then
        return melhorNos
    end

    profundidade = profundidade or 0
    melhorNos = melhorNos or {}  -- Inicializar melhorNos como uma tabela vazia na primeira chamada

    -- Alterna entre as dimensões (x, y, z) com base na profundidade
    local eixo = profundidade % 3 + 1

    -- Verificar a distância para o nó atual
    local distanciaAtual = calcularDistancia2(ponto, kdNode.ponto)
    
    -- Inserir o nó atual na lista de melhores vizinhos
    if #melhorNos < k then
        table.insert(melhorNos, {ponto = kdNode.ponto, distancia = distanciaAtual})
    else
        -- Substituir o vizinho mais distante se o atual for mais próximo
        table.sort(melhorNos, function(a, b) return a.distancia < b.distancia end)
        if distanciaAtual < melhorNos[#melhorNos].distancia then
            melhorNos[#melhorNos] = {ponto = kdNode.ponto, distancia = distanciaAtual}
        end
    end

    -- Determina qual ramo da kd-tree deve ser verificado
    local proximoRamo, outroRamo
    if ponto[eixo] < kdNode.ponto[eixo] then
        proximoRamo = kdNode.esquerda
        outroRamo = kdNode.direita
    else
        proximoRamo = kdNode.direita
        outroRamo = kdNode.esquerda
    end

    -- Explorar o ramo mais próximo primeiro
    melhorNos = buscarVizinhosMaisProximos(proximoRamo, ponto, k, profundidade + 1, melhorNos)

    -- Explorar o outro ramo se for possível encontrar algo mais próximo
    if math.abs(ponto[eixo] - kdNode.ponto[eixo]) < melhorNos[#melhorNos].distancia then
        melhorNos = buscarVizinhosMaisProximos(outroRamo, ponto, k, profundidade + 1, melhorNos)
    end

    return melhorNos
end



-- Função para calcular e armazenar os vizinhos mais próximos de cada polígono usando kd-tree
function calcularVizinhosParaTodosOsPoligonos(poligonos, kdTree, k)
    local vizinhosPorPoligono = {}

    for i, poligono in ipairs(poligonos) do
        -- Encontra os k vizinhos mais próximos para o polígono atual
        local pontoCentro = poligono  -- Considerando que `poligono` é representado pelo ponto central
        local vizinhos = buscarVizinhosMaisProximos(kdTree, pontoCentro, k)

        -- Armazena os índices dos vizinhos encontrados
        vizinhosPorPoligono[i] = {}
        for _, vizinho in ipairs(vizinhos) do
            -- Acha o índice do vizinho com base no ponto encontrado
            for j, p in ipairs(poligonos) do
                if p == vizinho.ponto then
                    table.insert(vizinhosPorPoligono[i], j)
                    break
                end
            end
        end
    end

    return vizinhosPorPoligono  -- Retorna uma tabela com os vizinhos para cada polígono
end

function verificarVizinhosComProximidadeERaycast(ponto1, ponto2, distanciaMaxima)
    -- Calcular a distância entre os dois pontos (centros dos polígonos)
    local distancia = calcularDistancia2(ponto1, ponto2)
    
    -- Se a distância for maior que a máxima permitida, não são vizinhos
    if distancia > distanciaMaxima then
        return false
    end

    -- Usar Raycast para verificar se há um obstáculo entre os dois pontos
    --local handle = StartShapeTestRay(ponto1[1], ponto1[2], ponto1[3], ponto2[1], ponto2[2], ponto2[3], -1, 0, 7)
    --local _, hit, _, _, _ = GetShapeTestResult(handle)
	local hit = ShapeTestNav(0, {x = ponto1[1], y = ponto1[2], z = ponto1[3]}, {x = ponto2[1], y = ponto2[2], z = ponto2[3]}, GlobalRaycastFlags)
    -- Se o Raycast detectar uma colisão (hit == 1), então há uma obstrução, logo não são vizinhos
    if hit then
        return false
    end

    return true  -- Se a distância for válida e não houver obstrução, são vizinhos
end

-- Função para comparar dois vértices com uma tolerância para evitar problemas de precisão
function verticesSaoIguais(vertice1, vertice2, tolerancia)
    tolerancia = tolerancia or 0.001  -- Defina a tolerância para evitar problemas de precisão
    return math.abs(vertice1.x - vertice2.x) <= tolerancia and
           math.abs(vertice1.y - vertice2.y) <= tolerancia and
           math.abs(vertice1.z - vertice2.z) <= tolerancia
end

-- Função para verificar se dois polígonos compartilham vértices com uma tolerância
function verificarVizinhosPorVertices(poligono1, poligono2, tolerancia)
    for _, vertice1 in ipairs(poligono1) do
        for _, vertice2 in ipairs(poligono2) do
            if verticesSaoIguais(vertice1, vertice2, tolerancia) then
                return true  -- São vizinhos, compartilham pelo menos um vértice
            end
        end
    end
    return false  -- Não compartilham vértices, não são vizinhos
end



-- Função para verificar se dois polígonos são vizinhos com uma tolerância para vértices e sem Raycast
function verificarVizinhosSemRaycast(poligono1, poligono2, distanciaMaxima, tolerancia)
    local ponto1 = {poligono1.Center.x, poligono1.Center.y, poligono1.Center.z}
    local ponto2 = {poligono2.Center.x, poligono2.Center.y, poligono2.Center.z}
    
    -- Verificar se a distância é menor que a distância máxima
    if calcularDistancia2(ponto1, ponto2) <= distanciaMaxima then
        -- Verificar se compartilham vértices
        if verificarVizinhosPorVertices(poligono1, poligono2, tolerancia) then
            return true
        end
    end
    return false
end

-- Função principal para calcular vizinhos
function calcularVizinhosParaPoligonosComVerticesSemRaycast(poligonos, kdTree, k, distanciaMaxima, tolerancia)
    local vizinhosPorPoligono = {}
	local LoopCount = 0
    for i, poligono in ipairs(poligonos) do
        local pontoCentro = {poligono.Center.x, poligono.Center.y, poligono.Center.z}
        local vizinhos = buscarVizinhosMaisProximos(kdTree, pontoCentro, k)
        vizinhosPorPoligono[i] = {}

        for _, vizinho in ipairs(vizinhos) do
            local vizinhoIndex = nil
            for j, poligonoVizinho in ipairs(poligonos) do
                local pontoVizinho = {poligonoVizinho.Center.x, poligonoVizinho.Center.y, poligonoVizinho.Center.z}
                if pontoVizinho[1] == vizinho.ponto[1] and pontoVizinho[2] == vizinho.ponto[2] and pontoVizinho[3] == vizinho.ponto[3] then
                    vizinhoIndex = poligonoVizinho.ID--j
                    break
                end
            end

            -- Evitar que o polígono considere a si mesmo como vizinho
            if vizinhoIndex and vizinhoIndex ~= i then
                -- Verificar se são vizinhos com base em vértices e proximidade (sem Raycast)
                if verificarVizinhosSemRaycast(poligono, poligonos[vizinhoIndex], distanciaMaxima, tolerancia) then
                    table.insert(vizinhosPorPoligono[i], vizinhoIndex)
                end
            end
			LoopCount = LoopCount + 1
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
        end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
    end

    return vizinhosPorPoligono
end

-- Função para calcular vizinhos com limite de distância
function verificarVizinhosComDistanciaMaxima(ponto1, ponto2, distanciaMaxima)
    local distancia = calcularDistancia2(ponto1, ponto2)
    return distancia <= distanciaMaxima
end

-- Função principal para calcular vizinhos considerando a distância máxima
function calcularVizinhosParaPoligonosComDistanciaMaxima(poligonos, kdTree, k, distanciaMaxima, tolerancia)
    local vizinhosPorPoligono = {}
	local LoopCount = 0
    for i, poligono in ipairs(poligonos) do
        local pontoCentro = {poligono.Center.x, poligono.Center.y, poligono.Center.z}
        local vizinhos = buscarVizinhosMaisProximos(kdTree, pontoCentro, k)
        vizinhosPorPoligono[i] = {}

        for _, vizinho in ipairs(vizinhos) do
            local vizinhoIndex = nil
            for j, poligonoVizinho in ipairs(poligonos) do
                local pontoVizinho = {poligonoVizinho.Center.x, poligonoVizinho.Center.y, poligonoVizinho.Center.z}
                if pontoVizinho[1] == vizinho.ponto[1] and pontoVizinho[2] == vizinho.ponto[2] and pontoVizinho[3] == vizinho.ponto[3] then
                    vizinhoIndex = j
                    break
                end
            end

            -- Evitar que o polígono considere a si mesmo como vizinho
            if vizinhoIndex and vizinhoIndex ~= i then
                -- Verificar se a distância entre os polígonos é menor que a distância máxima
                if verificarVizinhosComDistanciaMaxima(pontoCentro, vizinho.ponto, distanciaMaxima) then
                    table.insert(vizinhosPorPoligono[i], vizinhoIndex)
                end
            end
			LoopCount = LoopCount + 1
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
        end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
    end

    return vizinhosPorPoligono
end

-- Função para rotacionar um ponto em torno do centro (eixo Z)
function rotacionarPonto2(ponto, centro, angulo)
	local s = math.sin(angulo)
	local c = math.cos(angulo)

	-- Translação do ponto em relação ao centro
	local px = ponto.x - centro.x
	local py = ponto.y - centro.y

	-- Aplicar a rotação
	local novoX = px * c - py * s
	local novoY = px * s + py * c

	-- Retornar o ponto rotacionado com a translação de volta
	return {x = novoX + centro.x, y = novoY + centro.y, z = ponto.z}
end

-- Função para verificar se um polígono está colidindo com o ambiente (usando Raycast)
function verificarColisaoPoligono(poligono, alturaRaycast)
    for _, vertice in ipairs(poligono) do
        local origem = v3.new(vertice.x, vertice.y, vertice.z + alturaRaycast)
        local direcao = v3.new(0, 0, -1)  -- Raycast para baixo
        local colisaoValida, _ = verificarColisaoRaycast(origem, direcao, alturaRaycast)

        -- Se houver colisão, o polígono está sobre algo
        if colisaoValida then
            return true
        end
    end
    return false
end

-- Função para rotacionar um polígono e ajustar com base em colisões
function rotacionarEajustarPoligono(poligono, centro, anguloInicial, alturaRaycast)
    local angulo = anguloInicial
    local poligonoAjustado = rotacionarPoligono(poligono, centro, angulo)

    -- Verificar colisão e ajustar rotação se necessário
    while verificarColisaoPoligono(poligonoAjustado, alturaRaycast) do
        -- Ajusta o ângulo para evitar colisão (por exemplo, rotacionando em pequenos incrementos)
        angulo = angulo + math.rad(5)
        poligonoAjustado = rotacionarPoligono(poligono, centro, angulo)

        -- Limite para evitar loop infinito
        if angulo >= anguloInicial + math.rad(180) then
            print("Não foi possível ajustar a rotação para evitar colisões.")
            break
        end
		Wait()
    end

    return poligonoAjustado, angulo  -- Retorna o polígono ajustado e a rotação final
end

-- Função para gerar polígonos, aplicar rotação e ajustar com base em colisões
function gerarEajustarPoligonos(pontos, passo, centro, anguloInicial, alturaRaycast)
    local poligonos = {}

    -- Organizar os pontos em uma matriz bidimensional (grid) sem rotação
    local grid = {}
    for _, ponto in ipairs(pontos) do
        local gridX = math.floor(ponto.x / passo)
        local gridY = math.floor(ponto.y / passo)

        grid[gridX] = grid[gridX] or {}
        grid[gridX][gridY] = ponto
    end

    -- Percorre o grid para formar polígonos (quadrados) com quatro pontos adjacentes
    for x, coluna in pairs(grid) do
        for y, p1 in pairs(coluna) do
            local p2 = grid[x + 1] and grid[x + 1][y]
            local p3 = grid[x] and grid[x][y + 1]
            local p4 = grid[x + 1] and grid[x + 1][y + 1]

            -- Se todos os quatro pontos existirem, formamos um quadrado
            if p1 and p2 and p3 and p4 then
                -- Criar o polígono
                local poligono = {p1, p2, p4, p3}

                -- Aplicar rotação inicial e ajustar com base em colisões
                local poligonoAjustado, rotacaoFinal = rotacionarEajustarPoligono(poligono, centro, anguloInicial, alturaRaycast)

                -- Inserir o polígono ajustado na lista
                table.insert(poligonos, poligonoAjustado)
            end
        end
    end

    return poligonos  -- Retorna os polígonos ajustados e suas rotações finais
end

local NavNetID2 = 0
local NavHandle2 = 0
local PedNavSequence = false
menu.toggle(TestMenu, "Create Ped For Nav 2", {}, "", function(Toggle)
	PedNavSequence = Toggle
	if not PedNavSequence then
		if NavNetID2 ~= 0 then
			NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(NavNetID2, PLAYER.PLAYER_ID(), false)
		end
		entities.delete_by_handle(NavHandle2)
	end
	if PedNavSequence then
		local StartPos = {x = StartPath.x, y = StartPath.y, z = StartPath.z}
		local GoToCoords = {x = -955.48394775391, y = 166.00401306152, z = 373.17413330078}
		STREAMING.REQUEST_MODEL(joaat("mp_m_bogdangoon"))
		while not STREAMING.HAS_MODEL_LOADED(joaat("mp_m_bogdangoon")) do
			Wait()
		end
		--local Pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
		NavHandle2 = PED.CREATE_PED(28, joaat("mp_m_bogdangoon"), StartPos.x, StartPos.y, StartPos.z, 0.0, true, true)
		WEAPON.GIVE_WEAPON_TO_PED(NavHandle2, joaat("weapon_pistol"), 99999, false, true)
		ENTITY.SET_ENTITY_AS_MISSION_ENTITY(NavHandle2, false, true)
		NavNetID2 = NETWORK.PED_TO_NET(NavHandle2)
		if NavNetID2 ~= 0 then
			--NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(NavNetID, PLAYER.PLAYER_ID(), true)
			--NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(NavNetID, true)
			NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NavNetID2, false)
		end
		local FoundIndex = 0
		local TaskStatus = 0
		local TaskCoords = {x = 0.0, y = 0.0, z = 0.0}
		local FoundPaths = nil
		local PathIndex = 1
		local InPolyIndex = 1
		local TargetPolyIndex = 1
		local InsideStartPolygon = false
		local TargetInsideTargetPolygon = false
		local LastTargetPos = {x = 0.0, y = 0.0, z = 0.0}
		local JumpDelay = 0
		local Distance = 0.5
		while PedNavSequence do
			local Pos = ENTITY.GET_ENTITY_COORDS(NavHandle2)
			local PlayerPos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			--PED.SET_PED_MIN_MOVE_BLEND_RATIO(NavHandle, 3.0)
			--PED.SET_PED_MAX_MOVE_BLEND_RATIO(NavHandle, 3.0)
			local FVect = ENTITY.GET_ENTITY_FORWARD_VECTOR(NavHandle2)
			local AdjustedX = Pos.x + FVect.x * Distance
			local AdjustedY = Pos.y + FVect.y * Distance
			local AdjustedZ = (Pos.z + 0.5) + FVect.z * Distance
			GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z - 0.5,
			AdjustedX, AdjustedY, AdjustedZ, 255, 0, 255, 255)
			if JumpDelay <= 0 then
				if HitClimbableObject(NavHandle2) then
					TASK.TASK_CLIMB(NavHandle2, false)
					JumpDelay = 30
				end
			else
				JumpDelay = JumpDelay - 1
			end
			if FoundIndex == 0 then
				FoundPaths, InPolyIndex, TargetPolyIndex, InsideStartPolygon, TargetInsideTargetPolygon = AStarPathFind(Pos, PlayerPos, 3, false, nil, nil, nil, nil, nil, nil)
				if FoundPaths ~= nil then
					FoundIndex = 1
					LastTargetPos = PlayerPos
					--Print(#FoundPaths)
				end
			else
				if FoundPaths ~= nil then
					local SequenceAddr = memory.alloc(8)
					TASK.OPEN_SEQUENCE_TASK(SequenceAddr)
					for i = 1, #FoundPaths do
						TASK.TASK_GO_STRAIGHT_TO_COORD(0, FoundPaths[i].x, FoundPaths[i].y, FoundPaths[i].z, 3.0, -1, 40000.0, -1.0)
					end
					TASK.CLOSE_SEQUENCE_TASK(memory.read_int(SequenceAddr))
					TASK.TASK_PERFORM_SEQUENCE(NavHandle2, memory.read_int(SequenceAddr))
					break
				end
			end
			Wait()
		end
	end
end)

--50 Offset to address 2 of go to task coords
--1898 Offset from CPed to task go to coords
--E40 Offset from task go to coords to get task go to coords correct address
--C0 Offset from address task go to coords to task go to coords correct address

local MoreSensivityPressed = 0.0
local CamHandle = 0
local CreatorMode = false
menu.toggle(AddPolysMenu, "Grid Placement Mode", {}, "", function(Toggle)
	CreatorMode = Toggle
	if CreatorMode then
		CamHandle = CAM.CREATE_CAM("DEFAULT_SCRIPTED_CAMERA", true)
		local CamPos = CAM.GET_GAMEPLAY_CAM_COORD()
		local CamRot = CAM.GET_GAMEPLAY_CAM_ROT(2)
		CAM.SET_CAM_COORD(CamHandle, CamPos.x, CamPos.y, CamPos.z)
		CAM.SET_CAM_ROT(CamHandle, CamRot.x, CamRot.y, CamRot.z, 2)
		CAM.RENDER_SCRIPT_CAMS(true, false, 0, true, false, 0)
		local CurDistance = 10.0
		local PlacementMode = 0
		local PolyID = 0
		local PlacementModeText = {
			[0] = "Create Mode",
			[1] = "Snap Create Mode",
			[2] = "Delete Mode"
		}
		local CreateGridSize = 1.0
		while CreatorMode do
			local PlayerPed = PLAYER.PLAYER_PED_ID()
			local LRNormal = PAD.GET_CONTROL_NORMAL(0, 30)
			local UDNormal = -PAD.GET_CONTROL_NORMAL(0, 31)
			local LookLRNormal = -PAD.GET_CONTROL_NORMAL(0, 1) + -PAD.GET_DISABLED_CONTROL_NORMAL(0, 1)
			local LookUDNormal = -PAD.GET_CONTROL_NORMAL(0, 2) + -PAD.GET_DISABLED_CONTROL_NORMAL(0, 2)
			local FlyDownNormal = -PAD.GET_CONTROL_NORMAL(0, 10) + -PAD.GET_CONTROL_NORMAL(0, 224)
			local FlyUpNormal = PAD.GET_CONTROL_NORMAL(0, 11) + PAD.GET_CONTROL_NORMAL(0, 21)
			local CurCamRot = CAM.GET_CAM_ROT(CamHandle, 2)
			local NewRot = v3.new(0.0, 0.0, CurCamRot.z)
			local Matrix = GetRotationMatrix(NewRot)
			local CurPos = CAM.GET_CAM_COORD(CamHandle)
			local Adjusted = {
				x = CurPos.x + ((Matrix[2][1] * UDNormal * (1.0 + MoreSensivityPressed)) + (Matrix[1][1] * LRNormal * (1.0 + MoreSensivityPressed))),
				y = CurPos.y + ((Matrix[2][2] * UDNormal * (1.0 + MoreSensivityPressed)) + (Matrix[1][2] * LRNormal * (1.0 + MoreSensivityPressed))),
				z = CurPos.z + ((Matrix[2][3] * UDNormal * (1.0 + MoreSensivityPressed)) + (Matrix[1][3] * LRNormal * (1.0 + MoreSensivityPressed)) + FlyUpNormal + FlyDownNormal)
			}
			local AdjustedLook = {
				x = CurCamRot.x + LookUDNormal * 15.0,
				y = 0.0,
				z = CurCamRot.z + LookLRNormal * 15.0
			}
			CAM.SET_CAM_COORD(CamHandle, Adjusted.x, Adjusted.y, Adjusted.z)
			CAM.SET_CAM_ROT(CamHandle, AdjustedLook.x, AdjustedLook.y, AdjustedLook.z, 2)
			NETWORK.SET_ENTITY_LOCALLY_INVISIBLE(PlayerPed)
			ENTITY.SET_ENTITY_COORDS(PlayerPed, Adjusted.x, Adjusted.y, Adjusted.z, false, true)
			ENTITY.SET_ENTITY_HEADING(PlayerPed, AdjustedLook.z)
			HUD.LOCK_MINIMAP_ANGLE(math.ceil(Rotation180To360(AdjustedLook.z)))
			local FlyCursorDownNormal = -PAD.GET_CONTROL_NORMAL(0, 251)
			local FlyCursorUpNormal = PAD.GET_CONTROL_NORMAL(0, 250)
			CurDistance = CurDistance + FlyCursorDownNormal + FlyCursorUpNormal
			if CurDistance > 500.0 then
				CurDistance = 2.0
			end
			if CurDistance < 2.0 then
				CurDistance = 500.0
			end
			CursorPos, DidHit, OutEnt = RaycastFromCamHandle(CamHandle, PlayerPed, CurDistance, 511)
			CursorPos.z = CursorPos.z + 1.0
			GRAPHICS.DRAW_MARKER(28, CursorPos.x,
			CursorPos.y, CursorPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35, 0, 150, 0, 100, 0, false, 2, false, 0, 0, false)
			MoreSensivityPressed = PAD.GET_CONTROL_NORMAL(0, 22) * 2.0
			local ReleasedMove = PAD.IS_CONTROL_JUST_RELEASED(0, 25)
			local ReleasedPlace = PAD.IS_CONTROL_JUST_RELEASED(0, 24)
			local ChangeMode = PAD.IS_CONTROL_JUST_RELEASED(0, 189)
			directx.draw_text(0.7, 0.7, PlacementModeText[PlacementMode] , ALIGN_CENTRE, 1.0, {r = 1.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			if PlacementMode == 0 then
				local Pos1 = GetPositionCircle(CursorPos, CreateGridSize, addRotation(AdjustedLook.z, 45.0))
				local Pos2 = GetPositionCircle(CursorPos, CreateGridSize, addRotation(AdjustedLook.z, 135.0))
				local Pos3 = GetPositionCircle(CursorPos, CreateGridSize, addRotation(AdjustedLook.z, 225.0))
				local Pos4 = GetPositionCircle(CursorPos, CreateGridSize, addRotation(AdjustedLook.z, 315.0))
				GRAPHICS.DRAW_LINE(Pos1.x, Pos1.y, Pos1.z,
				Pos2.x, Pos2.y, Pos2.z, 255, 255, 255, 150)
				GRAPHICS.DRAW_LINE(Pos2.x, Pos2.y, Pos2.z,
				Pos3.x, Pos3.y, Pos3.z, 255, 255, 255, 150)
				GRAPHICS.DRAW_LINE(Pos3.x, Pos3.y, Pos3.z,
				Pos4.x, Pos4.y, Pos4.z, 255, 255, 255, 150)
				GRAPHICS.DRAW_LINE(Pos4.x, Pos4.y, Pos4.z,
				Pos1.x, Pos1.y, Pos1.z, 255, 255, 255, 150)
				if ReleasedPlace then
					AddNewPolygonGrid(Pos1, Pos2, Pos3, Pos4)
				end
			elseif PlacementMode == 1 then
				PolyID = GetClosestPolygon(Polys1, CursorPos, false, 0, 0)
				if PolyID ~= 0 then
					local ClosestVertex1 = 0
					local ClosestVertex2 = 0
					local VertexCopy = {}
					for k = 1, #Polys1[PolyID] do
						VertexCopy[#VertexCopy+1] = {x = Polys1[PolyID][k].x, y = Polys1[PolyID][k].y, z = Polys1[PolyID][k].z}
					end
					local Distance = 1000.0
					for k = 1, #VertexCopy do
						local Dist = DistanceBetween(VertexCopy[k].x, VertexCopy[k].y, VertexCopy[k].z, CursorPos.x, CursorPos.y, CursorPos.z)
						if Dist < Distance then
							Distance = Dist
							ClosestVertex1 = k
						end
					end
					Distance = 1000.0
					for k = 1, #VertexCopy do
						if k ~= ClosestVertex1 then
							local Dist = DistanceBetween(VertexCopy[k].x, VertexCopy[k].y, VertexCopy[k].z, CursorPos.x, CursorPos.y, CursorPos.z)
							if Dist < Distance then
								Distance = Dist
								ClosestVertex2 = k
							end
						end
					end
					if ClosestVertex1 ~= 0 and ClosestVertex2 ~= 0 then
						local Pos1 = VertexCopy[ClosestVertex1]
						local Pos2 = VertexCopy[ClosestVertex2]
						local Pos3 = GetPositionCircle(CursorPos, CreateGridSize, addRotation(AdjustedLook.z, 225.0))
						local Pos4 = GetPositionCircle(CursorPos, CreateGridSize, addRotation(AdjustedLook.z, 315.0))
						GRAPHICS.DRAW_LINE(Pos1.x, Pos1.y, Pos1.z,
						Pos2.x, Pos2.y, Pos2.z, 255, 255, 255, 150)
						GRAPHICS.DRAW_LINE(Pos2.x, Pos2.y, Pos2.z,
						Pos3.x, Pos3.y, Pos3.z, 255, 255, 255, 150)
						GRAPHICS.DRAW_LINE(Pos3.x, Pos3.y, Pos3.z,
						Pos4.x, Pos4.y, Pos4.z, 255, 255, 255, 150)
						GRAPHICS.DRAW_LINE(Pos4.x, Pos4.y, Pos4.z,
						Pos1.x, Pos1.y, Pos1.z, 255, 255, 255, 150)
						if ReleasedPlace then
							AddNewPolygonGrid(Pos1, Pos2, Pos3, Pos4)
						end
					end
				end
			end
			if ChangeMode then
				PlacementMode = PlacementMode + 1
				if PlacementMode > 2 then
					PlacementMode = 0
				end
			end
			Wait()
		end
	else
		HUD.UNLOCK_MINIMAP_ANGLE()
		if CamHandle ~= 0 then
			CAM.RENDER_SCRIPT_CAMS(false, false, 0, true, false, 0)
			CAM.DESTROY_CAM(CamHandle, false)
			CamHandle = 0
		end
	end
end)

function Rotation180To360(Angle)
    if Angle < 0.0 then
        return 360.0 + Angle
    else
        return Angle
    end
end

function AddNewPolygonGrid(Pos1, Pos2, Pos3, Pos4)
	Polys1[#Polys1+1] = {}
	Polys1[#Polys1][#Polys1[#Polys1]+1] = Pos1
	Polys1[#Polys1][#Polys1[#Polys1]+1] = Pos2
	Polys1[#Polys1][#Polys1[#Polys1]+1] = Pos3
	Polys1[#Polys1][#Polys1[#Polys1]+1] = Pos4
	SetAllPolysNeighboors(#Polys1)
end

-- Função para inicializar o grid espacial
function inicializarGrid3D(poligonos, tamanhoCelula)
    local grid = {}

    -- Iterar sobre todos os polígonos e colocá-los na célula correta do grid
    for i, poligono in ipairs(poligonos) do
        local centro = poligono.Center  -- Usar o centro do polígono para posicioná-lo no grid

        -- Calcular a célula do grid com base nas coordenadas do centro
        local gridX = math.floor(centro.x / tamanhoCelula)
        local gridY = math.floor(centro.y / tamanhoCelula)
        local gridZ = math.floor(centro.z / tamanhoCelula)

        -- Atribuir o polígono à célula correspondente no grid
        grid[gridX] = grid[gridX] or {}
        grid[gridX][gridY] = grid[gridX][gridY] or {}
        grid[gridX][gridY][gridZ] = grid[gridX][gridY][gridZ] or {}
        table.insert(grid[gridX][gridY][gridZ], i)  -- Armazena o índice do polígono
    end

    return grid
end

-- Função para buscar vizinhos em torno de uma célula do grid
function buscarVizinhosNoGrid(poligonoIndice, poligonos, grid, tamanhoCelula)
	local centro = poligonos[poligonoIndice].Center
	local vizinhos = {}

	local LoopCount = 0

	-- Calcular em qual célula o centro do polígono está localizado
	local gridX = math.floor(centro.x / tamanhoCelula)
	local gridY = math.floor(centro.y / tamanhoCelula)
	local gridZ = math.floor(centro.z / tamanhoCelula)

	-- Verificar a célula atual e as células adjacentes no grid
	for x = gridX - 1, gridX + 1 do
		for y = gridY - 1, gridY + 1 do
			for z = gridZ - 1, gridZ + 1 do
				if grid[x] and grid[x][y] and grid[x][y][z] then
					for _, indice in ipairs(grid[x][y][z]) do
						if indice ~= poligonoIndice then
							table.insert(vizinhos, indice)  -- Adicionar polígono como vizinho
						end
						LoopCount = LoopCount + 1
						if LoopCount > MaxLoopCount then
							LoopCount = 0
							Wait()
						end
					end
				end
				LoopCount = LoopCount + 1
				if LoopCount > MaxLoopCount then
					LoopCount = 0
					Wait()
				end
			end
			LoopCount = LoopCount + 1
			if LoopCount > MaxLoopCount then
				LoopCount = 0
				Wait()
			end
		end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
	end

	return vizinhos
end

-- Função para gerar uma chave única a partir dos vértices do polígono
function gerarChavePoligono(pontos)
	local PointsCopy = {}
	for k = 1, #pontos do
		PointsCopy[#PointsCopy+1] = {x = pontos[k].x, y = pontos[k].y, z = pontos[k].z}
	end
	-- Ordenar os vértices para garantir que a chave seja única, independentemente da ordem
	table.sort(PointsCopy, function(a, b)
		if a.x == b.x then
			if a.y == b.y then
				return a.z < b.z
			else
				return a.y < b.y
			end
		else
			return a.x < b.x
		end
	end)

	-- Concatenar as coordenadas dos vértices para gerar uma chave única
	local chave = ""
	for _, ponto in ipairs(PointsCopy) do
		chave = chave .. string.format("%f,%f,%f;", ponto.x, ponto.y, ponto.z)
	end

	return chave
end

-- Função para filtrar polígonos duplicados
function filtrarPoligonosDuplicados2(poligonos)
	local tabelaPoligonosUnicos = {}
	local poligonosFiltrados = {}
	local LoopCount = 0
	-- Iterar sobre todos os polígonos
	for _, poligono in ipairs(poligonos) do
		-- Gerar uma chave única para o polígono
		local chave = gerarChavePoligono(poligono)

		-- Verificar se o polígono já foi registrado
		if not tabelaPoligonosUnicos[chave] then
			-- Se não for duplicado, registrar o polígono e a chave
			tabelaPoligonosUnicos[chave] = true
			table.insert(poligonosFiltrados, poligono)
		end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
	end

	return poligonosFiltrados
end
	

-- Função para verificar se dois vértices são praticamente iguais com uma tolerância
function verticesIguaisComTolerancia(ponto1, ponto2, tolerancia)
    return math.abs(ponto1.x - ponto2.x) <= tolerancia and
           math.abs(ponto1.y - ponto2.y) <= tolerancia and
           math.abs(ponto1.z - ponto2.z) <= tolerancia
end

-- Função para gerar uma chave com tolerância
function gerarChavePoligonoComTolerancia(pontos, tolerancia)
	local PointsCopy = {}
	for k = 1, #pontos do
		PointsCopy[#PointsCopy+1] = {x = pontos[k].x, y = pontos[k].y, z = pontos[k].z}
	end
    -- Ordenar os vértices por proximidade com base na tolerância
    table.sort(PointsCopy, function(a, b)
        if math.abs(a.x - b.x) <= tolerancia then
            if math.abs(a.y - b.y) <= tolerancia then
                return a.z < b.z
            else
                return a.y < b.y
            end
        else
            return a.x < b.x
        end
    end)

    -- Gerar a chave com base nos vértices com tolerância
    local chave = ""
    for _, ponto in ipairs(PointsCopy) do
        chave = chave .. string.format("%f,%f,%f;", ponto.x, ponto.y, ponto.z)
    end

    return chave
end

-- Filtrar polígonos com tolerância
function filtrarPoligonosDuplicadosComTolerancia(poligonos, tolerancia)
    local tabelaPoligonosUnicos = {}
    local poligonosFiltrados = {}
	local LoopCount = 0
    for _, poligono in ipairs(poligonos) do
        local chave = gerarChavePoligonoComTolerancia(poligono, tolerancia)
        if not tabelaPoligonosUnicos[chave] then
            tabelaPoligonosUnicos[chave] = true
            table.insert(poligonosFiltrados, poligono)
        end
		LoopCount = LoopCount + 1
		if LoopCount > MaxLoopCount then
			LoopCount = 0
			Wait()
		end
    end

    return poligonosFiltrados
end

-- Função para inicializar o grid espacial
function inicializarGridEspacial(poligonos, tamanhoCelula)
    local grid = {}

    -- Iterar sobre todos os polígonos e colocá-los na célula correta do grid
    for i, poligono in ipairs(poligonos) do
        local centro = calcularCentroPoligono(poligono)  -- Calcular o centro do polígono

        -- Calcular a célula do grid com base nas coordenadas do centro
        local gridX = math.floor(centro.x / tamanhoCelula)
        local gridY = math.floor(centro.y / tamanhoCelula)
        local gridZ = math.floor(centro.z / tamanhoCelula)

        -- Criar uma entrada no grid se não existir
        grid[gridX] = grid[gridX] or {}
        grid[gridX][gridY] = grid[gridX][gridY] or {}
        grid[gridX][gridY][gridZ] = grid[gridX][gridY][gridZ] or {}

        -- Inserir o polígono na célula correta
        table.insert(grid[gridX][gridY][gridZ], poligono)
    end

    return grid
end

-- Função para calcular o centro de um polígono (média dos vértices)
function calcularCentroPoligono(poligono)
    local somaX, somaY, somaZ = 0, 0, 0
    for _, vertice in ipairs(poligono) do
        somaX = somaX + vertice.x
        somaY = somaY + vertice.y
        somaZ = somaZ + vertice.z
    end
    local numVertices = #poligono
    return {x = somaX / numVertices, y = somaY / numVertices, z = somaZ / numVertices}
end

-- Função para filtrar polígonos duplicados no grid espacial
function filtrarPoligonosDuplicadosComGrid(grid, tamanhoCelula, tolerancia)
    local poligonosFiltrados = {}
    local tabelaPoligonosUnicos = {}

    -- Iterar sobre todas as células do grid
    for gridX, coluna in pairs(grid) do
        for gridY, linha in pairs(coluna) do
            for gridZ, celula in pairs(linha) do
                -- Iterar sobre todos os polígonos na célula
                for _, poligono in ipairs(celula) do
                    -- Gerar uma chave para o polígono com base nos vértices
                    local chave = gerarChavePoligonoComTolerancia(poligono, tolerancia)

                    -- Verificar se o polígono já foi registrado
                    if not tabelaPoligonosUnicos[chave] then
                        -- Se não for duplicado, registrar o polígono e a chave
                        tabelaPoligonosUnicos[chave] = true
                        table.insert(poligonosFiltrados, poligono)
                    end
                end
            end
        end
    end

    return poligonosFiltrados
end

local RiotWeapons = {
	"weapon_smg",
	"weapon_assaultsmg",
	"weapon_assaultshotgun",
	"weapon_heavyshotgun",
	"weapon_pumpshotgun_mk2",
	"weapon_assaultrifle_mk2",
	"weapon_carbinerifle",
	"weapon_specialcarbine",
	"weapon_militaryrifle",
	"weapon_combatmg",
	"weapon_gusenberg",
	"weapon_tacticalrifle",
	"weapon_specialcarbine_mk2"
}

local DeathmatchNoMissionPeds = false
menu.toggle(GameModesMenu, "Deathmatch No Mission Peds", {}, "", function(Toggle)
	DeathmatchNoMissionPeds = Toggle
	if not DeathmatchNoMissionPeds then
		for index, peds in pairs(entities.get_all_peds_as_handles()) do
			if DECORATOR.DECOR_EXIST_ON(peds, "Casino_Game_Info_Decorator") then
				RequestControlOfEntity(peds)
				local NetID = NETWORK.PED_TO_NET(peds)
				if NetID ~= 0 then
					NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(NetID, PLAYER.PLAYER_ID(), false)
				end
				entities.delete_by_handle(peds)
			end
		end
	end
	if DeathmatchNoMissionPeds then
		local AiTeam1Hash = joaat("rgFM_AiPed20000")
		local Peds = {}
		local HandlesT = {}
		local Team1RelName = "Team1"
		local Team2RelName = "Team2"
		AddRelationshipGroup(Team1RelName)
		AddRelationshipGroup(Team2RelName)
		PED.SET_RELATIONSHIP_BETWEEN_GROUPS(1, joaat(Team1RelName), joaat(Team1RelName))
		PED.SET_RELATIONSHIP_BETWEEN_GROUPS(1, joaat(Team2RelName), joaat(Team2RelName))
		PED.SET_RELATIONSHIP_BETWEEN_GROUPS(5, joaat(Team1RelName), joaat(Team2RelName))
		PED.SET_RELATIONSHIP_BETWEEN_GROUPS(5, joaat(Team2RelName), joaat(Team1RelName))
		local TeamModels = { 
			joaat("mp_m_bogdangoon"),
			joaat("mp_m_avongoon")
		}
		local TeamsRels = {
			joaat(Team1RelName),
			joaat(Team2RelName)
		}
		local TeamToCreatePed = 0
		while DeathmatchNoMissionPeds do
			if #Peds < 20 then
				if TeamToCreatePed == 0 then
					TeamToCreatePed = math.random(1, 2)
				end
				if RequestModelFunc(TeamModels[TeamToCreatePed]) then
					local RandomPoly = Polys1[math.random(#Polys1)].Center
					local PedHandle = PED.CREATE_PED(28, TeamModels[TeamToCreatePed], RandomPoly.x, RandomPoly.y, RandomPoly.z, math.random(-180, 180), true, true)
					if PedHandle ~= 0 then
						if HandlesT[PedHandle] == nil then
							Peds[#Peds+1] = {}
							Peds[#Peds].Handle = PedHandle
							Peds[#Peds].TaskState = 0
							Peds[#Peds].Target = 0
							Peds[#Peds].TaskCoords = {x = 0.0, y = 0.0, z = 0.0}
							Peds[#Peds].TaskCoords2 = {x = 0.0, y = 0.0, z = 0.0}
							Peds[#Peds].Paths = nil
							Peds[#Peds].ActualPath = 1
							Peds[#Peds].SearchState = 0
							Peds[#Peds].SearchCalled = false
							Peds[#Peds].Start = nil
							Peds[#Peds].TargetPoly = nil
							Peds[#Peds].InsideStartPolygon = false
							Peds[#Peds].TargetInsideTargetPolygon = false
							Peds[#Peds].HasSetRel = false
							Peds[#Peds].TimeOut = 0
							Peds[#Peds].SearchLowLevel = 3+16
							Peds[#Peds].IsInVeh = false
							Peds[#Peds].VehHandle = 0
							Peds[#Peds].LastDistance = 0.0
							Peds[#Peds].SameDistanceTick = 0
							Peds[#Peds].StartPolysT = {}
							Peds[#Peds].TargetPolysT = {}
							Peds[#Peds].DrivingStyle = 0
							Peds[#Peds].NetID = NetID
							Peds[#Peds].IsZombie = false
							Peds[#Peds].JumpDelay = 0
							Peds[#Peds].StartIndexArg = nil
							Peds[#Peds].TargetIndexArg = nil
							Peds[#Peds].AddMode = false
							Peds[#Peds].HasChecked = false
							Peds[#Peds].LastPolyID = 0
							Peds[#Peds].OldPaths = {}
							PED.SET_PED_TARGET_LOSS_RESPONSE(PedHandle, 1)
							PED.SET_COMBAT_FLOAT(PedHandle, 2, 4000.0)
							PED.SET_PED_COMBAT_RANGE(PedHandle, 3)
							PED.SET_PED_FIRING_PATTERN(PedHandle, joaat("FIRING_PATTERN_FULL_AUTO"))
							PED.SET_PED_RELATIONSHIP_GROUP_HASH(PedHandle, TeamsRels[TeamToCreatePed])
							WEAPON.GIVE_WEAPON_TO_PED(PedHandle, joaat(RiotWeapons[math.random(#RiotWeapons)]), 99999, false, true)
							ENTITY.SET_ENTITY_AS_MISSION_ENTITY(PedHandle, false, true)
							entities.set_can_migrate(PedHandle, false)
							local Addr = entities.handle_to_pointer(PedHandle) + 0xD8
							if Addr ~= 0 then
								memory.write_int(Addr, 1)
							end
						end
					end
					STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(TeamModels[TeamToCreatePed])
					TeamToCreatePed = 0
				end
			end
			for k = 1, #Peds do
				if Peds[k] ~= nil then
					if not ENTITY.IS_ENTITY_DEAD(Peds[k].Handle) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Handle) then
						if RequestControlOfEntity(Peds[k].Handle) then
							entities.set_can_migrate(Peds[k].Handle, false)
						end
						if Peds[k].JumpDelay <= 0 then
							if HitClimbableObject(Peds[k].Handle) then
								TASK.TASK_CLIMB(Peds[k].Handle, false)
								Peds[k].JumpDelay = 1000
							end
							if JumpPassThroughHole(Peds[k].Handle) then
								TASK.TASK_CLIMB(Peds[k].Handle, true)
								Peds[k].JumpDelay = 1000
							end
						else
							Peds[k].JumpDelay = Peds[k].JumpDelay - 1
						end
						if WEAPON.IS_PED_ARMED(Peds[k].Handle, 1) then
							Peds[k].IsZombie = true
							PED.SET_COMBAT_FLOAT(Peds[k].Handle, 7, 3.0)
							PED.SET_PED_RESET_FLAG(Peds[k].Handle, 306, true)
							PED.SET_PED_CONFIG_FLAG(Peds[k].Handle, 435, true)
						end
						if Peds[k].IsZombie then
							--PED.SET_PED_MOVE_RATE_OVERRIDE(Peds[k].Handle, 1.5)
							--PED.SET_AI_MELEE_WEAPON_DAMAGE_MODIFIER(100.0)
							PED.SET_PED_USING_ACTION_MODE(Peds[k].Handle, false, -1, 0)
							--PED.SET_PED_MIN_MOVE_BLEND_RATIO(Peds[k].Handle, 3.0)
							--PED.SET_PED_MAX_MOVE_BLEND_RATIO(Peds[k].Handle, 3.0)
						end
						local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
						if not Peds[k].HasSetRel then
							if PED.DOES_RELATIONSHIP_GROUP_EXIST(AiTeam1Hash) then
								if RequestControlOfEntity(Peds[k].Handle) then
									--PED.SET_PED_RELATIONSHIP_GROUP_HASH(Peds[k].Handle, AiTeam1Hash)
									Peds[k].HasSetRel = true
								end
							end
						end
						if Peds[k].TaskState == 6 then
							--TASK.TASK_COMBAT_HATED_TARGETS_AROUND_PED(Peds[k].Handle, 1000.0, 16)
							local Target = PED.GET_PED_TARGET_FROM_COMBAT_PED(Peds[k].Handle, 0)
							if Target ~= 0 then
								Peds[k].Target = Target
								Peds[k].TaskState = 1
							end
						end
						if Peds[k].TaskState == 0 then
							--TASK.TASK_COMBAT_HATED_TARGETS_AROUND_PED(Peds[k].Handle, 1000.0, 16)
							local Target = PED.GET_PED_TARGET_FROM_COMBAT_PED(Peds[k].Handle, 0)
							if Target ~= 0 then
								Peds[k].Target = Target
								Peds[k].TaskState = 1
							end
						end
						if Peds[k].SearchState == 0 then
							if Peds[k].Target ~= 0 then
								local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
								local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
								Peds[k].SearchState = 1
								util.create_thread(function()
									local NewPaths = nil
									NewPaths, Peds[k].Start, Peds[k].TargetPoly, Peds[k].InsideStartPolygon, Peds[k].TargetInsideTargetPolygon, Nodes = AStarPathFind(Pos, TargetPos, Peds[k].SearchLowLevel, false, Peds[k].StartIndexArg, Peds[k].TargetIndexArg, false, false, nil, false, false)
									if NewPaths ~= nil then
										if Peds[k] ~= nil then
											if not Peds[k].AddMode then
												Peds[k].Paths = NewPaths
											else
												for i = 1, #NewPaths do
													table.insert(Peds[k].Paths, NewPaths[i])
												end
											end
											--Peds[k].SearchLowLevel = 1
											--Print("Found path")
											Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
											if Nodes ~= nil then
												Peds[k].ActualPath = AdjustTraveledPaths(Nodes, Polys1, Pos)--1
											else
												Peds[k].ActualPath = 1
											end
											--Print(Peds[k].ActualPath)
											Peds[k].TaskState = 1
											Peds[k].StartIndexArg = nil
											Peds[k].TargetIndexArg = nil
											Peds[k].AddMode = false
										end
										--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
									end
									
									Wait(1000)
									if Peds[k] ~= nil then
										Peds[k].SearchState = 2
										--Print("Reset")
									end
								end)
							end
						end
						local Polygons = {}
						if Peds[k].Target ~= 0 then
							if Peds[k].Paths ~= nil then
								local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
								local DistanceFinal = DistanceBetween(TargetPos.x, TargetPos.y, TargetPos.z, Peds[k].Paths[#Peds[k].Paths].x, Peds[k].Paths[#Peds[k].Paths].y, Peds[k].Paths[#Peds[k].Paths].z)
								if DistanceFinal > 30.0 then
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 4+16
									end
								end
							end
						end
						if Peds[k].TaskState == 1 then
							if Peds[k].Paths ~= nil then
								--if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_CLIMB")) == 7 then
								if not Peds[k].IsZombie then
									if RequestControlOfEntity(Peds[k].Handle) then
										--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										if Peds[k].ActualPath > #Peds[k].Paths then
											Peds[k].ActualPath = 1
											if Peds[k].SearchState == 2 then
												Peds[k].SearchState = 0
												Peds[k].SearchLowLevel = 3+16
											end
										end
										if Peds[k].Paths[Peds[k].ActualPath] ~= nil then
											local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
											local NewV3 = v3.new(Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
											local Sub = v3.sub(NewV3, Pos)
											local Rot = Sub:toRot()
											--ENTITY.SET_ENTITY_HEADING(Peds[k].Handle, Rot.z, 2)
											Dir = Rot:toDir()
											Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
											Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
											Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
											Peds[k].TaskCoords2.x = Peds[k].Paths[Peds[k].ActualPath].x + Dir.x * 2.0
											Peds[k].TaskCoords2.y = Peds[k].Paths[Peds[k].ActualPath].y + Dir.y * 2.0
											Peds[k].TaskCoords2.z = Peds[k].Paths[Peds[k].ActualPath].z + Dir.z * 2.0
											
											if ENTITY.HAS_ENTITY_CLEAR_LOS_TO_ENTITY(Peds[k].Handle, Peds[k].Target, 17) then
												TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, Peds[k].Target, 2.0, true, 0.1, 0.1, false, 0, true, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY")) ~= 7 then
													Peds[k].TaskState = 2
												end
											else
												TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 3.0, -1, 40000.0, 0.1)
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) ~= 7 then
													Peds[k].TaskState = 7
													--Print("Straight")
												end
											end
										end
									end
								else
									if not ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 5.5, 5.5, 2.5, false, true, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
											if Peds[k].ActualPath > #Peds[k].Paths then
												Peds[k].ActualPath = 1
												if Peds[k].SearchState == 2 then
													Peds[k].SearchState = 0
													Peds[k].SearchLowLevel = 3+16
												end
											end
											if Peds[k].Paths[Peds[k].ActualPath] ~= nil then
												local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
												local NewV3 = v3.new(Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
												local Sub = v3.sub(NewV3, Pos)
												local Rot = Sub:toRot()
												--ENTITY.SET_ENTITY_HEADING(Peds[k].Handle, Rot.z, 2)
												Dir = Rot:toDir()
												Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
												Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
												Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
												Peds[k].TaskCoords2.x = Peds[k].Paths[Peds[k].ActualPath].x + Dir.x * 2.0
												Peds[k].TaskCoords2.y = Peds[k].Paths[Peds[k].ActualPath].y + Dir.y * 2.0
												Peds[k].TaskCoords2.z = Peds[k].Paths[Peds[k].ActualPath].z + Dir.z * 2.0
												Peds[k].LastDistance = DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
												--TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, Peds[k].Target, 2.0, true, 0.1, 0.1, false, 0, true, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
												--TASK.TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, 3.0, -1, 40000.0, 0.1)
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) ~= 7 then
													Peds[k].TaskState = 3
													--Print("Straight")
												end
											end
										end
									else
										local HasSetTask = false
										local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
										local Distance3 = DistanceBetween(Pos.x, Pos.y, Pos.z, TargetPos.x, TargetPos.y, TargetPos.z)
										if Distance3 < 1.5 then
											if RequestControlOfEntity(Peds[k].Handle) then
												TASK.TASK_COMBAT_PED(Peds[k].Handle, Peds[k].Target, 201326592, 16)
												PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
												if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_COMBAT")) ~= 7 then
													--Print("Combat")
													Peds[k].TaskState = 4
												end
												HasSetTask = true
											end
										end
										if not HasSetTask then
											--if Distance3 < 1.5 then
												if ENTITY.HAS_ENTITY_CLEAR_LOS_TO_ENTITY(Peds[k].Handle, Peds[k].Target, 17) then
													if RequestControlOfEntity(Peds[k].Handle) then
														TASK.TASK_GO_STRAIGHT_TO_COORD_RELATIVE_TO_ENTITY(Peds[k].Handle, Peds[k].Target, 0.0, 0.0, 2.0, 3.0, -1)
														PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
														if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD_RELATIVE_TO_ENTITY")) ~= 7 then
															--Print("Combat")
															Peds[k].TaskState = 6
														end
													end
												else
													if RequestControlOfEntity(Peds[k].Handle) then
														if Peds[k].ActualPath > #Peds[k].Paths then
															Peds[k].ActualPath = 1
															if Peds[k].SearchState == 2 then
																Peds[k].SearchState = 0
																Peds[k].SearchLowLevel = 3+16
															end
														end
														if Peds[k].Paths[Peds[k].ActualPath] ~= nil then
															local Pos = ENTITY.GET_ENTITY_COORDS(Peds[k].Handle)
															local NewV3 = v3.new(Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
															local Sub = v3.sub(NewV3, Pos)
															local Rot = Sub:toRot()
															Dir = Rot:toDir()
															Peds[k].TaskCoords.x = Peds[k].Paths[Peds[k].ActualPath].x
															Peds[k].TaskCoords.y = Peds[k].Paths[Peds[k].ActualPath].y
															Peds[k].TaskCoords.z = Peds[k].Paths[Peds[k].ActualPath].z
															Peds[k].TaskCoords2.x = Peds[k].Paths[Peds[k].ActualPath].x + Dir.x * 1.0
															Peds[k].TaskCoords2.y = Peds[k].Paths[Peds[k].ActualPath].y + Dir.y * 1.0
															Peds[k].TaskCoords2.z = Peds[k].Paths[Peds[k].ActualPath].z + Dir.z * 1.0
															Peds[k].LastDistance = DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
															--TASK.TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, Peds[k].Target, 2.0, true, 0.1, 0.1, false, 0, true, joaat("FIRING_PATTERN_FULL_AUTO"), -1)
															--TASK.TASK_SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
															TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, 3.0, -1, 40000.0, 0.1)
															
															PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, true)
															if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) ~= 7 then
																Peds[k].TaskState = 3
																--Print("Straight")
															end
														end
													end
												end
											--end
										end
									end
								end
							--end
							else
								if Peds[k].SearchState == 2 then
									Peds[k].SearchState = 0
									Peds[k].SearchLowLevel = 3+16
								end
							end
						end
						if Peds[k].TaskState == 2 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if Peds[k].Paths ~= nil then
									if Peds[k].SearchState == 2 then
										if Peds[k].TargetPoly ~= nil then
											local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
											if Peds[k].TargetInsideTargetPolygon then
												if not InsidePolygon(Polys1[Peds[k].TargetPoly], TargetPos) then
													--Peds[k].TaskState = 1
													if Peds[k].SearchState == 2 then
														Peds[k].SearchState = 0
														
													end
												end
											end
										else
											--Peds[k].SearchState = 0
										end
									end
									--if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.15, 0.15, 100.0, false, false, 0) then
									--	if Peds[k].SearchState == 2 then
									--		Peds[k].SearchState = 0
									--	end
									--end
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.5, 0.5, 1.0, false, false, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											Peds[k].ActualPath = Peds[k].ActualPath + 1
											if Peds[k].ActualPath > #Peds[k].Paths then
												Peds[k].ActualPath = 1
												if Peds[k].SearchState == 2 then
													Peds[k].SearchState = 0
													Peds[k].SearchLowLevel = 3+16
												end
											end
											Peds[k].TaskState = 1
										end
									else
										Peds[k].TimeOut = Peds[k].TimeOut + 1
										if Peds[k].TimeOut > 10000 then
											if Peds[k].SearchState == 2 then
												if RequestControlOfEntity(Peds[k].Handle) then
													PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
													TASK.CLEAR_PED_TASKS(Peds[k].Handle)
													Peds[k].SearchState = 0
													Peds[k].TaskState = 1
												end
											end
										end
									end
									if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_TO_COORD_WHILE_AIMING_AT_ENTITY")) == 7 then
										Peds[k].TaskState = 1
										--Print("No action")
									end
								else
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 3+16
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
									Peds[k].ActualPath = 1
									Peds[k].SearchLowLevel = 3+16
								end
							end
						end
						GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z,
						Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 255, 255, 255, 255)
						if Peds[k].Paths ~= nil then
							for i = Peds[k].ActualPath, #Peds[k].Paths-1 do
								GRAPHICS.DRAW_LINE(Peds[k].Paths[i].x, Peds[k].Paths[i].y, Peds[k].Paths[i].z,
								Peds[k].Paths[i+1].x, Peds[k].Paths[i+1].y, Peds[k].Paths[i+1].z, 255, 255, 255, 255)
							end
						end
						if Peds[k].TaskState == 3 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								local Distance2 = DistanceBetween(Pos.x, Pos.y, Pos.z, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z)
								Peds[k].SameDistanceTick = Peds[k].SameDistanceTick + 1
								local HasSet = false
								if Distance2 < Peds[k].LastDistance then
									Peds[k].LastDistance = Distance2
									Peds[k].SameDistanceTick = 0
								else
									if Peds[k].ActualPath < #Peds[k].Paths then
										if Peds[k].ActualPath == 1 then
											Peds[k].ActualPath = Peds[k].ActualPath + 1
											Peds[k].TaskState = 1
										end
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
										end
									end
								end
								--Distance2 > Peds[k].LastDistance then
								if Peds[k].SameDistanceTick > 50 or math.floor(Distance2) > math.floor(Peds[k].LastDistance) then
									--Peds[k].TaskState = 1
									--Peds[k].ActualPath = Peds[k].ActualPath + 1
									--if Peds[k].ActualPath > #Peds[k].Paths then
									--	Peds[k].ActualPath = 1
									--	if Peds[k].SearchState == 2 then
									--		Peds[k].SearchState = 0
									--	end
									--end
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 3+16
									end
								end
								if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) == 7 then
									if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_CLIMB")) == 7 then
										if RequestControlOfEntity(Peds[k].Handle) then
											Peds[k].TaskState = 1
											TASK.TASK_GO_STRAIGHT_TO_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, 3.0, -1, 40000.0, 0.1)
										end
									end
								end
								if not HasSet then
									if ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 5.0, 5.0, 2.5, false, true, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											--PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											Peds[k].TaskState = 1
											--HasSet = true
											Peds[k].SameDistanceTick = 0
										end
									end
								end
								local R = 1.0
								local CurSpd = ENTITY.GET_ENTITY_SPEED(Peds[k].Handle)
								--R = R + CurSpd / 2
								--Print(R)
								if not HasSet then
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, R, R, 2.0, false, false, 0) or
									ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords2.x, Peds[k].TaskCoords2.y, Peds[k].TaskCoords2.z, R, R, 2.0, false, false, 0) then
										Peds[k].ActualPath = Peds[k].ActualPath + 1
										if Peds[k].ActualPath > #Peds[k].Paths then
											Peds[k].ActualPath = 1
											if Peds[k].SearchState == 2 then
												Peds[k].SearchState = 0
												Peds[k].SearchLowLevel = 3+16
											end
										end
										Peds[k].TaskState = 1
										Peds[k].SameDistanceTick = 0
									end
								end
							else
								Peds[k].TaskState = 0
								Peds[k].Target = 0
							end
						end
						if Peds[k].TaskState == 4 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if not ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 2.5, 2.5, 2.5, false, true, 0) then
									if RequestControlOfEntity(Peds[k].Handle) then
										PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										Peds[k].TaskState = 1
										
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
								end
							end
						end
						if Peds[k].TaskState == 5 then
							if not PED.IS_PED_CLIMBING(Peds[k].Handle) and not PED.IS_PED_JUMPING(Peds[k].Handle) then
								Peds[k].JumpDelay = Peds[k].JumpDelay - 1
								if Peds[k].JumpDelay <= 0 then
								--if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_CLIMB")) == 7 then
									Peds[k].ActualPath = Peds[k].ActualPath + 1
									if Peds[k].ActualPath > #Peds[k].Paths then
										Peds[k].ActualPath = 1
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
											Peds[k].SearchLowLevel = 3+16
										end
									end
									Peds[k].TaskState = 1
									Peds[k].SameDistanceTick = 0
								end
							end
						end
						if Peds[k].TaskState == 6 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if ENTITY.IS_ENTITY_AT_ENTITY(Peds[k].Handle, Peds[k].Target, 1.0, 1.0, 2.5, false, true, 0) then--or not CanIntersectEntity(Pos, ENTITY.GET_ENTITY_COORDS(Peds[k].Target, Peds[k].Paths, Peds[k].ActualPath)) then
									if RequestControlOfEntity(Peds[k].Handle) then
										PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
										TASK.CLEAR_PED_TASKS(Peds[k].Handle)
										Peds[k].TaskState = 1
										if Peds[k].SearchState == 2 then
											Peds[k].SearchState = 0
											Peds[k].SearchLowLevel = 3+16
										end
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
								end
							end
						end
						if Peds[k].TaskState == 7 then
							if not ENTITY.IS_ENTITY_DEAD(Peds[k].Target) and ENTITY.DOES_ENTITY_EXIST(Peds[k].Target) then
								if Peds[k].Paths ~= nil then
									if Peds[k].SearchState == 2 then
										if Peds[k].TargetPoly ~= nil then
											local TargetPos = ENTITY.GET_ENTITY_COORDS(Peds[k].Target)
											if Peds[k].TargetInsideTargetPolygon then
												if not InsidePolygon(Polys1[Peds[k].TargetPoly], TargetPos) then
													--Peds[k].TaskState = 1
													if Peds[k].SearchState == 2 then
														Peds[k].SearchState = 0
													end
												end
											end
										else
											Peds[k].SearchState = 0
										end
									end
									--if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.15, 0.15, 100.0, false, false, 0) then
									--	if Peds[k].SearchState == 2 then
									--		Peds[k].SearchState = 0
									--	end
									--end
									if ENTITY.HAS_ENTITY_CLEAR_LOS_TO_ENTITY(Peds[k].Handle, Peds[k].Target, 17) then
										Peds[k].TaskState = 1
									end
									if ENTITY.IS_ENTITY_AT_COORD(Peds[k].Handle, Peds[k].TaskCoords.x, Peds[k].TaskCoords.y, Peds[k].TaskCoords.z, 0.5, 0.5, 1.0, false, false, 0) then
										if RequestControlOfEntity(Peds[k].Handle) then
											PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
											--TASK.CLEAR_PED_TASKS(Peds[k].Handle)
											Peds[k].ActualPath = Peds[k].ActualPath + 1
											if Peds[k].ActualPath > #Peds[k].Paths then
												Peds[k].ActualPath = 1
												Peds[k].SearchState = 0
												Peds[k].SearchLowLevel = 3+16
											end
											Peds[k].TaskState = 1
										end
									else
										Peds[k].TimeOut = Peds[k].TimeOut + 1
										if Peds[k].TimeOut > 10000 then
											if Peds[k].SearchState == 2 then
												if RequestControlOfEntity(Peds[k].Handle) then
													PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
													TASK.CLEAR_PED_TASKS(Peds[k].Handle)
													Peds[k].SearchState = 0
													Peds[k].TaskState = 1
												end
											end
										end
									end
									if TASK.GET_SCRIPT_TASK_STATUS(Peds[k].Handle, joaat("SCRIPT_TASK_GO_STRAIGHT_TO_COORD")) == 7 then
										Peds[k].TaskState = 1
										--Print("No action")
									end
								else
									if Peds[k].SearchState == 2 then
										Peds[k].SearchState = 0
										Peds[k].SearchLowLevel = 3+16
									end
								end
							else
								if RequestControlOfEntity(Peds[k].Handle) then
									PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(Peds[k].Handle, false)
									TASK.CLEAR_PED_TASKS(Peds[k].Handle)
									Peds[k].TaskState = 0
									Peds[k].Target = 0
									Peds[k].ActualPath = 1
									Peds[k].SearchLowLevel = 3+16
								end
							end
						end
					else
						if ENTITY.DOES_ENTITY_EXIST(Peds[k].Handle) then
							if RequestControlOfEntity(Peds[k].Handle) then
								local Addr = entities.handle_to_pointer(Peds[k].Handle) + 0xD8
								if Addr ~= 0 then
									memory.write_int(Addr, 329858)
								end
								--set_entity_as_no_longer_needed(Peds[k].Handle)
								HandlesT[Peds[k].Handle] = nil
								table.remove(Peds, k)
							end
						else
							HandlesT[Peds[k].Handle] = nil
							table.remove(Peds, k)
						end
					end
				end
			end
			Wait()
		end
		for i = 1, #Peds do
			if ENTITY.DOES_ENTITY_EXIST(Peds[i].Handle) then
				entities.delete_by_handle(Peds[i].Handle)
			end
		end
	end
end)

function AddRelationshipGroup(RelName)
	if not PED.DOES_RELATIONSHIP_GROUP_EXIST(joaat(RelName)) then
		local ptr = memory.alloc(32)
		PED.ADD_RELATIONSHIP_GROUP(RelName, ptr)
	end
end

function RequestModelFunc(Model)
	STREAMING.REQUEST_MODEL(Model)
	return STREAMING.HAS_MODEL_LOADED(Model)
end