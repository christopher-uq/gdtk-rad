-- gridarray.lua
-- A module for constructing arrays of structured grids.
--
-- PJ, 2021-10-04
--

module(..., package.seeall)


-- Class for GridArray objects.
GridArray = {
   myType = "GridArray"
}

function GridArray:new(o)
   -- Construct a GridArray object which contains both the overall structured grid and
   -- an array of structured grids.  We may be given either for starters.
   --
   -- If we are given an initial overall grid, then we also expect to be given
   -- the number of subgrids to be formed in each index direction.
   --
   -- If we are given an array of grids initially, the overall grid will be constructed
   -- by joining the subgrids.
   --
   local flag = type(self)=='table' and self.myType=='GridArray'
   if not flag then
      error("Make sure that you are using GridArray:new{} and not GridArray.new{}", 2)
   end
   o = o or {}
   if o.myType and o.myType == 'GridArray' then
      print("This is already a GridArray object, just returning it.")
      return o
   end
   local flag = checkAllowedNames(o, {"grid", "gridArray", "nib", "njb", "nkb"})
   if not flag then
      error("Invalid name for item supplied to GridArray constructor.", 2)
   end
   setmetatable(o, self)
   self.__index = self
   -- We will embed the GridArray identity in the individual grids
   -- and we would like that identity to start from 0 for the D code.
   o.id = #(gridArraysList)
   if o.grid then
      -- We will take a single grid and divide it into an array of subgrids.
      o.grids = {} -- will be a multi-dimensional array, indexed as [ib][jb][kb],
                   -- with 1<=ib<=nib, 1<=jb<=njb, 1<=kb<=nkb
      if (not o.grid.get_type) or o.grid:get_type() ~= "structured_grid" then
         error("You need to supply a structured_grid to GridArray constructor.", 2)
      end
      -- Numbers of subblocks in each coordinate direction
      o.nib = o.nib or 1
      o.njb = o.njb or 1
      o.nkb = o.nkb or 1
      if config.dimensions == 2 then
         o.nkb = 1
      end
      -- Extract some information from the StructuredGrid
      o.niv = o.grid:get_niv()
      o.njv = o.grid:get_njv()
      o.nkv = o.grid:get_nkv()
      -- Subdivide the single grid based on numbers of cells.
      -- Note 0-based indexing for vertices and cells in the D-domain.
      local nic_total = o.niv - 1
      local dnic = math.floor(nic_total/o.nib)
      local njc_total = o.njv - 1
      local dnjc = math.floor(njc_total/o.njb)
      local nkc_total = o.nkv - 1
      local dnkc = math.floor(nkc_total/o.nkb)
      if config.dimensions == 2 then
         nkc_total = 1
         dnkc = 1
      end
      -- Work along each index direction and work out numbers of cells in subgrid.
      o.nics = {} -- numbers of cells in each subgrid
      local nic_remaining = nic_total
      for ib = 1, o.nib do
         local nic = math.floor(nic_remaining/(o.nib-ib+1))
         if (ib == o.nib) then
            -- On last subgrid, just use what's left
            nic = nic_remaining
         end
         o.nics[#o.nics+1] = nic
         nic_remaining = nic_remaining - nic
      end
      o.njcs = {}
      local njc_remaining = njc_total
      for jb = 1, o.njb do
         local njc = math.floor(njc_remaining/(o.njb-jb+1))
         if (jb == o.njb) then
            njc = njc_remaining
         end
         o.njcs[#o.njcs+1] = njc
         njc_remaining = njc_remaining - njc
      end
      o.nkcs = {}
      if config.dimensions == 2 then
         o.nkcs[1] = 1
      else
         local nkc_remaining = nkc_total
         for kb = 1, o.nkb do
            local nkc = math.floor(nkc_remaining/(o.nkb-kb+1))
            if (kb == o.nkb) then
               nkc = nkc_remaining
            end
            o.nkcs[#o.nkcs+1] = nkc
            nkc_remaining = nkc_remaining - nkc
         end
      end
      -- Now, generate the actual subgrids.
      local i0 = 0
      for ib = 1, o.nib do
         o.grids[ib] = {}
         local nic = o.nics[ib]
         local j0 = 0
         for jb = 1, o.njb do
            local njc = o.njcs[jb]
            if config.dimensions == 2 then
               -- 2D flow
               if false then
                  -- May activate print statements for debug.
                  print("ib=", ib, "jb= ", jb)
                  print("i0= ", i0, " nic= ", nic, " j0= ", j0, " njc= ", njc)
               end
               if nic < 1 then
                  error(string.format("Invalid nic=%d while making subgrid ib=%d, jb=%d", nic, ib, jb), 2)
               end
               if njc < 1 then
                  error(string.format("Invalid njc=%d while making subgrid ib=%d, jb=%d", njc, ib, jb), 2)
               end
               o.grids[ib][jb] = o.grid:subgrid(i0,nic+1,j0,njc+1)
            else
               -- 3D flow, need one more level in the array
               o.grids[ib][jb] = {}
               local k0 = 0
               for kb = 1, o.nkb do
                  local nkc = o.nkcs[kb]
                  if nic < 1 then
                     error(string.format("Invalid nic=%d while making subgrid ib=%d, jb=%d, kb=%d", nic, ib, jb, kb), 2)
                  end
                  if njc < 1 then
                     error(string.format("Invalid njc=%d while making subgrid ib=%d, jb=%d, kb=%d", njc, ib, jb, kb), 2)
                  end
                  if nkc < 1 then
                     error(string.format("Invalid nkc=%d while making subgrid ib=%d, jb=%d, kb=%d", nkc, ib, jb, kb), 2)
                  end
                  o.grids[ib][jb][kb] = o.grid:subgrid(i0,nic+1,j0,njc+1,k0,nkc+1)
                  -- Prepare k0 at end of loop, ready for next iteration
                  k0 = k0 + nkc
               end -- kb loop
            end -- dimensions
            -- Prepare j0 at end of loop, ready for next iteration
            j0 = j0 + njc
         end -- jb loop
         -- Prepare i0 at end of loop, ready for next iteration
         i0 = i0 + nic
      end -- ib loop
      -- Finished generating subgrids
   else
      -- We were not given a single grid,
      -- so we assume that we were given the array of subgrids.
      -- Join these into a single overall grid.
      if not (type(o.gridArray) == "table") then
         error("gridArray should be an array of grid objects.", 2)
      end
      o.nib = #(o.gridArray)
      if o.nib < 1 then
         error("gridArray should have at least one row of grids.", 2)
      end
      if not (type(o.gridArray[1]) == "table") then
         error("gridArray[1] should be and array of grids.", 2)
      end
      o.njb = #(o.gridArray[1])
      if o.njb < 1 then
         error("gridArray[1] should contain at least one grid object.", 2)
      end
      o.grids = {}
      if config.dimensions == 2 then
         -- Check that the numbers of vertices are compatible for all subgrids
         -- and make a copy of the grid references, as well.
         for ib = 1, o.nib do
            o.grids[ib] = { o.gridArray[ib][1], }
            local niv_expected = o.gridArray[ib][1]:get_niv()
            for jb = 2, o.njb do
               local subgrid = o.gridArray[ib][jb]
               o.grids[ib][jb] = subgrid
               if (subgrid:get_niv() ~= niv_expected) then
                  error(string.format("Mismatch in niv for subgrid[%d][%d]: got %d, expected %d",
                                      ib, jb, subgrid:get_niv(), niv_expected), 2)
               end
               local p10 = o.gridArray[ib][jb]:get_corner_vtx("10")
               local p11 = o.gridArray[ib][jb-1]:get_corner_vtx("11")
               local p00 = o.gridArray[ib][jb]:get_corner_vtx("00")
               local p01 = o.gridArray[ib][jb-1]:get_corner_vtx("01")
               if not closeEnough(p01, p00, 1.0e-5) then
                  error(string.format("Mismatch for joining subgrid[%d][%d]: p01=%s p00=%s",
                                      ib, jb, tostring(p01), tostring(p00)), 2)
               end
               if not closeEnough(p11, p11, 1.0e-5) then
                  error(string.format("Mismatch for joining subgrid[%d][%d]: p11=%s p10=%s",
                                      ib, jb, tostring(p11), tostring(p10)), 2)
               end
            end
         end
         for jb = 1, o.njb do
            local njv_expected = o.gridArray[1][jb]:get_njv()
            for ib = 2, o.nib do
               local subgrid = o.gridArray[ib][jb]
               if (subgrid:get_njv() ~= njv_expected) then
                  error(string.format("Mismatch in njv for subgrid[%d][%d]: got %d, expected %d",
                                      ib, jb, subgrid:get_njv(), njv_expected), 2)
               end
               local p10 = o.gridArray[ib-1][jb]:get_corner_vtx("10")
               local p11 = o.gridArray[ib-1][jb]:get_corner_vtx("11")
               local p00 = o.gridArray[ib][jb]:get_corner_vtx("00")
               local p01 = o.gridArray[ib][jb]:get_corner_vtx("01")
               if not closeEnough(p10, p00, 1.0e-5) then
                  error(string.format("Mismatch for joining subgrid[%d][%d]: p10=%s p00=%s",
                                      ib, jb, tostring(p10), tostring(p00)), 2)
               end
               if not closeEnough(p11, p01, 1.0e-5) then
                  error(string.format("Mismatch for joining subgrid[%d][%d]: p11=%s p01=%s",
                                      ib, jb, tostring(p11), tostring(p01)), 2)
               end
            end
         end
         -- Make stacks of the original subgrids in the j-direction,
         -- then join those stacks into the overall 2D grid.
         o.nkb = 1
         local jstack = {}
         for ib = 1, o.nib do
            jstack[ib] = o.gridArray[ib][1]:copy() -- need to retain the original subgrid
            for jb = 2, o.njb do
               jstack[ib]:joinGrid(o.gridArray[ib][jb], "north")
            end
         end
         o.grid = jstack[1]
         for ib = 2, o.nib do
            o.grid:joinGrid(jstack[ib], "east")
         end
      else
         -- For 3D
         o.nkb = #(o.gridArray[1][1])
         -- Make a copy of the grid references.
         for ib = 1, o.nib do
            o.grids[ib] = {}
            for jb = 1, o.njb do
               o.grids[ib][jb] = {}
               for kb = 1, o.nkb do
                  o.grids[ib][jb][kb] = o.gridArray[ib][jb][kb]
               end
            end
         end
         -- Make stacks of the original subgrids, starting in the k-index direction,
         -- then building slabs spanning the jk directions from those stacks and,
         -- finally, joining the slabs in the i-direction.
         -- [TODO] 2021-09-01 PJ Put in checks on the numbers of vertices for adjacent subgrids.
         local kstack = {}
         for ib = 1, o.nib do
            kstack[ib] = {}
            for jb = 1, o.njb do
               kstack[ib][jb] = o.gridArray[ib][jb][1]:copy() -- retain original subgrid
               for kb = 2, o.nkb do
                  kstack[ib][jb]:joinGrid(o.gridArray[ib][jb][kb], "top")
               end
            end
         end
         local jkslab = {}
         for ib = 1, o.nib do
            jkslab[ib] = kstack[ib][1]
            for jb = 2, o.njb do
               jkslab[ib]:joinGrid(kstack[ib][jb], "north")
            end
         end
         o.grid = jkslab[1]
         for ib = 2, o.nib do
            o.grid:joinGrid(jkslab[ib], "east")
         end
      end
      -- Numbers of cells in each of the subgrids.
      -- Needed by FBArray when setting up shock-fitting weights, etc.
      o.nics = {}
      for ib =1, o.nib do
         if config.dimensions == 2 then
            o.nics[#o.nics+1] = o.gridArray[ib][1]:get_niv() - 1
         else
            o.nics[#o.nics+1] = o.gridArray[ib][1][1]:get_niv() - 1
         end
      end
      o.njcs = {}
      for jb =1, o.njb do
         if config.dimensions == 2 then
            o.njcs[#o.njcs+1] = o.gridArray[1][jb]:get_njv() - 1
         else
            o.njcs[#o.njcs+1] = o.gridArray[1][jb][1]:get_njv() - 1
         end
      end
      o.nkcs = {}
      if config.dimensions == 2 then
         o.nkcs[1] = 1
      else
         for kb = 1, o.nkb do
            o.nkcs[#o.nkcs+1] = o.gridArray[1][1][kb]:get_nkv() - 1
         end
      end
      -- Extract some information from the assembled grid, for later use.
      o.niv = o.grid:get_niv()
      o.njv = o.grid:get_njv()
      o.nkv = o.grid:get_nkv()
   end
   --
   return o
end -- GridArray:new

function GridArray:tojson(o)
   local str = string.format('"grid_array_%d": {\n', self.id)
   str = str .. string.format('    "nib": %d,\n', self.nib)
   str = str .. string.format('    "njb": %d,\n', self.njb)
   str = str .. string.format('    "nkb": %d,\n', self.nkb)
   str = str .. string.format('    "niv": %d,\n', self.niv)
   str = str .. string.format('    "njv": %d,\n', self.njv)
   str = str .. string.format('    "nkv": %d,\n', self.nkv)
   --
   str = str .. string.format('    "nics": [ ')
   for i=1,#(self.nics)-1 do
      str = str .. string.format('%d, ', self.nics[i])
   end
   str = str .. string.format('%d ],\n', self.nics[#self.nics])
   --
   str = str .. string.format('    "njcs": [ ')
   for i=1,#(self.njcs)-1 do
      str = str .. string.format('%d, ', self.njcs[i])
   end
   str = str .. string.format('%d ],\n', self.njcs[#self.njcs])
   --
   str = str .. string.format('    "nkcs": [ ')
   for i=1,#(self.nkcs)-1 do
      str = str .. string.format('%d, ', self.nkcs[i])
   end
   str = str .. string.format('%d ]\n', self.nkcs[#self.nkcs])
   --
   str = str .. '}'
   return str
end -- GridArray:tojson()
