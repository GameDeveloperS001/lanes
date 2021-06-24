local lanes = require("lanes").configure{ with_timers = false}
local l = lanes.linda "my linda"

-- we will transfer userdata created by this module, so we need to make Lanes aware of it
local dt = lanes.require "deep_test"

local test_deep = true
local test_clonable = false
local test_uvtype = "string"

local makeUserValue = function( obj_)
	if test_uvtype == "string" then
		return "some uservalue"
	elseif test_uvtype == "function" then
		-- a function that pull the userdata as upvalue
		local f = function()
			print( obj_)
		end
		return f
	end
end

local performTest = function( obj_)
	-- setup the userdata with some value and a uservalue
	obj_:set( 666)
	-- lua 5.1->5.2 support a single table uservalue
	-- lua 5.3 supports an arbitrary type uservalue
	obj_:setuv( 1, makeUserValue( obj_))
	-- lua 5.4 supports multiple uservalues of arbitrary types
	-- obj_:setuv( 2, "ENDUV")

	-- read back the contents of the object
	print( "immediate:", obj_, obj_:getuv( 1))

	-- send the object in a linda, get it back out, read the contents
	l:set( "key", obj_)
	-- when obj_ is a deep userdata, out is the same userdata as obj_ (not another one pointing on the same deep memory block) because of an internal cache table [deep*] -> proxy)
	-- when obj_ is a clonable userdata, we get a different clone everytime we cross a linda or lane barrier
	local out = l:get( "key")
	print( "out of linda:", out, out:getuv( 1))

	-- send the object in a lane through parameter passing, the lane body returns it as return value, read the contents
	local g = lanes.gen(
		"package"
		, {
			required = { "deep_test"} -- we will transfer userdata created by this module, so we need to make this lane aware of it
		}
		, function( param_)
			-- read contents inside lane
			print( "in lane:", param_, param_:getuv( 1))
			return param_
		end
	)
	h = g( obj_)
	-- when obj_ is a deep userdata, from_lane is the same userdata as obj_ (not another one pointing on the same deep memory block) because of an internal cache table [deep*] -> proxy)
	-- when obj_ is a clonable userdata, we get a different clone everytime we cross a linda or lane barrier
	local from_lane = h[1]
	print( "from lane:", from_lane, from_lane:getuv( 1))
end

if test_deep then
	performTest( dt.new_deep())
end

if test_clonable then
	performTest( dt.new_clonable())
end
