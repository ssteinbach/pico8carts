pico-8 cartridge // http://www.pico-8.com
version 14
__lua__
-- dead mans slope
-- @stephan_gfx / @stevelavieties
--
-- v0.6
beta = 0.0001
mincutoff = 0.0001
function make_one_euro_filt(beta, mincutoff)
return {
first_time = true,
dx = 0,
rate = 0.0333, 
mincutoff = mincutoff, 
beta = beta, 
d_cutoff = 0, 
xfilt = make_low_pass_filter(),
dxfilt = make_low_pass_filter(),
filter=function(t, x)
t.dx = t.first_time and 0 or (x - t.xfilt.hatxprev) * t.rate
local edx = t.dxfilt:filter(t.dx, t:alpha(t.rate, t.d_cutoff))
local cutoff = mincutoff + beta * abs(edx)
return t.xfilt:filter(x, t:alpha(t.rate, cutoff))
end,
alpha = function(t, rate, cutoff)
local tau = 1.0 / (2 * 3.14159 * cutoff)
local te = 1.0 / rate
return (1.0 / (1.0 + tau/te))
end
}
end
function make_low_pass_filter()
return {
first_time = true,
hat_x_prev = nil,
hat_x = nil,
filter = function(t, x, alpha)
if t.first_time then
t.first_time = false
t.hat_x_prev = x
end
t.hat_x = alpha * x + (1 - alpha) * t.hat_x_prev
t.hat_x_prev = t.hat_x
return t.hat_x
end
}
end
function add_particle(x, y, dx, dy, life, color, ddy, pass)
particle_array_length += 1
if (#particle_array < particle_array_length) add(particle_array, 0)
particle_array[particle_array_length] = {x = x, y = y, dx = dx, dy = dy, life = life or 8, color = color or 6, ddy = ddy or 0.0625, pass = pass or 0}
end
function process_particles(at_scope, pass)
local p = 1
local off = {0,0}
if at_scope == sp_world and g_cam != nil then
off = {-g_cam.x + 64, -g_cam.y + 64}
end
pass = pass or 0
while p <= particle_array_length do
local particle = particle_array[p]
if particle.pass == pass then
if bor(band(0x8000, particle.life), band(bor(off[1]+particle.x, off[2]+particle.y), 0xff80)) != 0 then
particle_array[p], particle_array[particle_array_length] = particle_array[particle_array_length], nil
particle_array_length -= 1
else
local addr = bor(0x6000, bor(shr(off[1]+particle.x, 1), shl(band(off[2]+particle.y, 0xffff), 6)))
local pixel_pair = peek(addr)
if band(off[1]+particle.x, 1) == 1 then
pixel_pair = bor(band(pixel_pair, 0x0f), shl(particle.color, 4))
else
pixel_pair = bor(band(pixel_pair, 0xf0), particle.color)
end
poke(addr, pixel_pair)
particle.dy += particle.ddy
particle.x += particle.dx
particle.y += particle.dy
particle.life -= 1
if g_state == ge_state_menu then
for _, c in pairs(collision_objects) do
local collision_result = c:collides(particle)
if collision_result != nil then
particle.x += collision_result[1]
particle.y += collision_result[2]
particle.dy = 0
particle.dx = 0
end
end
end
p += 1
end 
else
p +=1
end 
end 
end
collision_objects = {}
g_mogulneer_accel = 0.45
function make_snow_particles()
return {
update=function()
if g_state == ge_state_menu then
add_particle(rnd(128), 0, rnd_centered(0.5), 0.5+rnd(0.3), 270, 7, 0)
end
end,
draw=function()
process_particles()
end
}
end
function spray_particles()
return {
start_spray=0,
add_trail_spray=function()
local velmag = vecmag(g_p1.vel)
if velmag < 2 then
return
end
local amount = clamp(remap(velmag, 3, 5, 0, 1))
local n_trail_pts = #g_p1.trail_points
for i=0,25 do
if rnd() < amount or amount > 0.95 then
local ind = ceil(rnd(min(6, n_trail_pts)))
local pt = g_p1.trail_points[n_trail_pts - ind] or g_p1
pos = vecadd(
vecadd(vecscale(g_p1.ski_vec, rnd_centered(6)), pt),
vecfromangle(pt.perpendicular, rnd_centered(5))
)
add_particle(
pos.x, pos.y,
rnd_centered(0.5), 0.5+rnd(0.3),
270,
12, 
0 
)
end
end
end,
add_brake_spray=function()
if not g_p1.sliding then
return
end
local mag = -min(abs(g_p1.vel_against/1.5), 1)
for i=0,25 do
local ski_vec = vecfromangle(g_p1.perpendicular+rnd_centered(0.2),mag)
local off=vecadd(
vecscale(g_p1.ski_vec_perp, -3),
vecscale(g_p1.ski_vec, rnd_centered(6))
)
off = vecadd(off, vecrand(4, true))
local life = 30+rnd(5)
local num_parts = rnd() < 0.25 and 1 or 0
for i_x=0,num_parts do
for i_y=0,num_parts do
add_particle(
g_p1.x+off.x+i_x,
g_p1.y+off.y+i_y,
ski_vec.x,
max(ski_vec.y, -0.5),
life, 
6, 
-0.01, 
1
)
end
end
end
end,
update=function(t)
if not g_p1.jumping then
t:add_trail_spray()
t:add_brake_spray()
end
end,
draw=function()
process_particles(sp_world)
end
}
end
function make_title()
return {
y=-64,
duration=40,
start_frame=g_tick-15,
start=vecmake(-264, -264),
target=vecmake(8, 20),
update=function(t)
local frame = elapsed(t.start_frame)
if frame < t.duration then
vecset(t, veclerp(t.start, t.target, smootherstep(frame/t.duration)))
for j=4,16*8,8 do
for i=0,15,2 do
local off=vecadd(t, vecrand(12, true))
add_particle(
j+off.x,
off.y,
rnd_centered(6),
1,
30+rnd(100),
7,
0.5
)
end
end
end
end,
draw=function(t)
spr(216, 44, 0, 3, 1)
spr(232, 42, 10, 4, 1)
spr(248, 42, 20, 4, 1)
palt(3, true)
palt(0, false)
spr(230, 48, 30, 2, 2)
if elapsed(t.start_frame) > t.duration then
print("by: @stephan_gfx   ", 19, 46, 12)
print("    @stevelavieties", 19, 54, 12)
local ic_s = "controls are " .. (ge_inverted_controls and "inverted" or "not inverted")
print(ic_s, 8, 100, 7)
end
palt()
end,
}
end
function _init()
music(-1)
reset_shake()
g_flash_end = nil
g_flash_color =nil
particle_array, particle_array_length = {}, 0
stdinit()
add_gobjs(make_snow_trans(_title_stuff, 6))
end
function _title_stuff()
music(-1)
music(0)
g_state = ge_state_menu
stdinit()
add_gobjs(make_bg(6))
add_gobjs(make_title())
add_gobjs(make_snow_particles())
add_gobjs(
make_timer(
10,
function()
add(
collision_objects,
{
x=30,
y=80,
width=67,
height=24,
collides=function(t, part)
if (
part.x > t.x
and part.x - t.x < t.width
and part.y > t.y and
part.y - t.y < t.height
) then
return {0, -1}
end
end
}
)
add_gobjs(
make_menu(
track_names,
function (t, i, s)
if i < #tracks then
function done_func()
slalom_start(i+1)
end
add_gobjs(make_snow_trans(done_func, 7))
else
ge_inverted_controls = not ge_inverted_controls
end
end
)
)
end
)
)
end
function make_timer(time_to_wait, callback)
return {
start=g_tick,
time_to_wait=time_to_wait,
callback=callback,
update=function(t)
if elapsed(t.start) > t.time_to_wait then
del(t, g_objs)
t.callback()
t.update = nil
end
end
}
end
function _update()
stdupdate()
end
function _draw()
stddraw()
end
sp_world = 0
sp_local = 1
sp_screen_native = 2
sp_screen_center = 3
function add_gobjs(thing)
return add(g_objs, thing)
end
function ef_out_quart(amount)
local t = clamp(amount) - 1
return -1 * (t*t*t*t- 1)
end
function smootherstep(x)
return x*x*x*(x*(x*6 - 15) + 10);
end
function lerp(input, min_out, max_out)
return input * (max_out - min_out) + min_out
end
function remap(
val,
i_min,
i_max,
o_min,
o_max
)
return lerp((val-i_min)/(i_max-i_min), o_min, o_max)
end
function vecdraw(v, c, scale, o)
o = o or null_v
local end_point = vecadd(o, vecscale(v, scale or 30))
line(o.x, o.y, end_point.x, end_point.y, c)
return
end
function rnd_centered(max_val)
return rnd(max_val)-(max_val/2)
end
function vecrand(scale, center, yscale)
local result = vecmake(rnd(scale), rnd(yscale or scale))
if center then
result = vecsub(result, vecmake(scale/2, (yscale or scale)/2))
end
return result
end
function vecmake(xf, yf)
xf = xf or 0
return {x=xf, y=(yf or xf)}
end
function veccopy(tgt)
return vecmake(tgt.x, tgt.y)
end
null_v = vecmake()
function vecscale(v, m)
return {x=v.x*m, y=v.y*m}
end
function vecmagsq(v)
return v.x*v.x+v.y*v.y
end
function vecmag(v, sf)
if sf then
v = vecscale(v, sf)
end
local result=sqrt(vecmagsq(v))
if sf then
result=result/sf
end
return result
end
function vecdot(a, b)
return (a.x*b.x+a.y*b.y)
end
function vecadd(a, b)
return {x=a.x+b.x, y=a.y+b.y}
end
function vecsub(a, b)
return {x=a.x-b.x, y=a.y-b.y}
end
function vecflr(a)
return vecmake(flr(a.x), flr(a.y))
end
function vecset(target, source)
target.x = source.x
target.y = source.y
end
function vecfromangle(angle, mag)
mag = mag or 1.0
return vecmake(mag*cos(angle), mag*sin(angle))
end
function veclerp(v1, v2, amount, clamp)
local result = vecadd(vecscale(vecsub(v2,v1),amount),v1)
if clamp and vecmag((vecsub(result,v2))) < clamp then
result = v2
end
return result
end
function clamp(v, min_v, max_v)
return min(max(v, min_v or 0), max_v or 1)
end
function vecclamp(v, min_v, max_v)
return vecmake(
clamp(v.x, min_v.x, max_v.x),
clamp(v.y, min_v.y, max_v.y)
)
end
function make_player(p)
return {
x=0.1, 
y=-3,
p=p,
space=sp_world,
vel=null_v,
vel_along=0,
vel_against=0,
bound_min=vecmake(-3, -4),
bound_max=vecmake(2,0),
angle=-0.25, 
perpendicular=0.5,
turn_start = nil,
drag_scale = 1,
ski_vec=null_v,
ski_vec_perp=null_v,
skier_state=ge_skier_start,
trail_points={},
crashed=false,
made_timer = false,
last_push=g_tick,
c_drag_along=0.02,
c_drag_against=0.05,
sliding=false,
is_on_ice=nil,
drag_along_multiplier=5,
drag_against_multiplier=5,
jumping = nil,
jump_velocity = 0,
jump_height= 0,
mogul_off = 0,
g=null_v,
total_accel=null_v,
drag_along=null_v,
drag_against=null_v,
update=function(t)
if t.crashed then
t.vel = vecscale(t.vel, 0.9)
vecset(t, vecadd(t, t.vel))
g_cam.drift = true
g_cam.last_target_point = veccopy(t)
t.sliding = true
if not t.made_timer and vecmagsq(t.vel) < 0.1 then
t.made_timer = true
add_gobjs(
make_timer(
30,
function()
t.made_timer = false
t.vel = null_v
vecset(t, t.respawn_location)
t.crashed = false
t.sliding = false
t.skier_state = ge_skier_start
t.angle = -0.25
g_cam.drift = false
flash_screen(4, 8)
end
)
)
end
return
end
if t.skier_state != ge_skier_start then
t.skier_state = ge_skier_normal
end
local tgt_dir = nil
if btn(0, t.p) then
tgt_dir = ge_inverted_controls and 0 or -0.5
end
if btn(1, t.p) then
if tgt_dir != nil then
t.skier_state = ge_skier_wedge
else
tgt_dir = ge_inverted_controls and -0.5 or 0
end
end
if btn(3, t.p) then
if not tgt_dir then
tgt_dir = -0.25
else
tgt_dir = (tgt_dir -0.25)/2
end
end
if btn(2, t.p) then
t.skier_state = ge_skier_wedge
end
if btn(5, t.p) and t.skier_state != ge_skier_wedge then
t.skier_state = ge_skier_tuck
if (
(t.angle <= -0.45 or t.angle >= -0.05)
and elapsed(t.last_push) > 25
and vecmag(t.vel) < 1
)
then
t.vel = vecadd(t.vel, vecfromangle(t.angle, 2.5))
t.last_push = g_tick
end
end
if t.skier_state == ge_skier_start and not tgt_dir and not jmp then
return
elseif t.skier_state == ge_skier_start then
t.skier_state = ge_skier_normal
end
local jmp = btn(4, t.p)
if jmp then
t.jumping = t.jumping or g_tick
elseif t.jumping then
if t.jump_velocity < 0 then
t.jump_velocity = 0
elseif t.jump_height == 0 then
t.jumping = nil
end
end
if t.jumping == g_tick then
t.jump_velocity = -3.375
t.jump_height = 0
end
if t.jumping and t.jump_height <= 0 then
t.jump_velocity += g_mogulneer_accel
t.jump_height += t.jump_velocity
if t.jump_height > 0 then
t.turn_start = g_tick - 20
t.jump_height = 0
t.jump_velocity = 0
end
end
local turn_amount = (
(t.jumping and 0.021)
or ((t.skier_state == ge_skier_tuck) and 0.011)
or 0.015
)
if tgt_dir then
if t.turn_start == nil then
t.turn_start = g_tick
end
if tgt_dir > t.angle then
t.angle = min(t.angle + turn_amount, 0)
elseif tgt_dir < t.angle then
t.angle = max(t.angle - turn_amount, -0.5)
end
t.angle = clamp_to(t.angle, tgt_dir)
else
t.turn_start = nil
end
t.total_accel = t.jumping and null_v or t:acceleration()
t.vel = vecadd(t.vel, t.total_accel)
vecset(t, vecadd(t, t.vel))
for i=#t.trail_points,1,-1 do
if (t.y - t.trail_points[i].y > 100) then
del(t.trail_points, t.trail_points[i])
end
end
t.mogul_off = 0
for i=1,#g_mountain.p_objs do
local o = g_mountain.p_objs[i]
if overlaps_bounds(o, t) and o.overlaps then
o:overlaps(t)
end
end
t:add_new_trail_point(t)
end,
acceleration=function(t)
local ski_vec = vecfromangle(t.angle)
t.ski_vec = ski_vec
local perpendicular = t.angle - 0.25
if t.angle > -0.25 then
perpendicular = t.angle + 0.25
end
local ski_vec_perp = vecfromangle(perpendicular)
t.ski_vec_perp = ski_vec_perp
t.perpendicular = perpendicular
local drag_along_multiplier = 1
local drag_against_multiplier = 5
if t.skier_state == ge_skier_normal then
drag_along_multiplier = 5
elseif t.skier_state == ge_skier_wedge then
drag_along_multiplier = 25
drag_against_multiplier = 15
end
if t.is_on_ice and t.is_on_ice + 1 == g_tick then
drag_along_multiplier *= 0.5
drag_against_multiplier *= 0.4
end
if t.mogul_off > 0 then
drag_along_multiplier *= 5
drag_against_multiplier /= 3
end
t.drag_along_multiplier = lerp(0.3, t.drag_along_multiplier, drag_along_multiplier)
t.drag_against_multiplier = lerp(0.3, t.drag_against_multiplier, drag_against_multiplier)
local mod_ang = (0.25 - abs(0.25 + t.angle))*4
local ang_fact = ef_out_quart(mod_ang)
local g_accel = ang_fact * g_mogulneer_accel
local g = vecscale(ski_vec, g_accel)
t.ang_fact = ang_fact
t.g = g
local vel_along  = vecdot(ski_vec, t.vel)
t.vel_along = vel_along
local vel_against = vecdot(ski_vec_perp, t.vel)
t.vel_against = vel_against
t.drag_along = vecscale(
ski_vec,
-1 * t.c_drag_along * t.drag_along_multiplier * vel_along*abs(vel_along)
)
local drag_scale = 1
if t.turn_start and elapsed(t.turn_start) < 30 then
drag_scale = cos(elapsed(t.turn_start)/(2*30))
drag_scale *= drag_scale
end
t.drag_scale = drag_scale
t.drag_against = vecscale(
ski_vec_perp,
-drag_scale * t.c_drag_against * t.drag_against_multiplier * vel_against
)
t.sliding = abs(vel_against) > abs(vel_along)
return vecadd(g, vecadd(t.drag_along, t.drag_against))
end,
draw=function(t, _, layername)
local pose = flr((t.angle + 0.25)*16)
if layername == "backmost" then
for i=2,#t.trail_points do
local real_p1 = t.trail_points[i-1]
local real_p2 = t.trail_points[i]
if not real_p1.gap and not real_p2.gap then
local p1 = vecflr(vecsub(real_p1, t)) 
local p2 = vecflr(vecsub(real_p2, t))
for off_mult=-1,1,2 do
local off_perp = vecfromangle(real_p2.perpendicular, off_mult)
local p1_off = vecadd(p1, off_perp)
local p2_off = vecadd(p2, off_perp)
line(
p1_off.x, p1_off.y,
p2_off.x, p2_off.y,
6
)
end
end
end
return
end
if not t.crashed then
for x_off=-1,1,2 do
local ang = t.angle
local offset = 1
if t.jumping or t.skier_state == ge_skier_wedge then
ang = t.angle-0.06*x_off
if t.jumping then
ang += 0.08*x_off
end
offset = 2
end
local jump_off = vecmake(0, t.jump_height)
local turn_off = vecscale(vecmake(cos(ang+0.25*x_off), sin(ang+0.25*x_off)), offset)
turn_off = vecadd(turn_off, jump_off)
local first_p = vecscale(vecmake(cos(ang), sin(ang)),4)
local last_p  = vecscale(first_p, -1)
first_p = vecadd(first_p, turn_off)
last_p = vecadd(last_p, turn_off)
pushc(0, t.mogul_off)
line(first_p.x, first_p.y, last_p.x, last_p.y, 4)
circfill(first_p.x, first_p.y, 1, 8)
popc()
end
end
if t.jumping then
local shadow_size = lerp(smootherstep(-t.jump_height/18), 3, 1)
circfill(0, 0, shadow_size, 5)
end
local offset = 0
palt(0, false)
palt(3, true)
if t.skier_state == ge_skier_tuck then
palt(14, true)
palt(13, true)
offset = 2
else
palt(14, false)
pal(14, 11)
pal(13, 11)
end
local sprn = 17+abs(pose)*2
if t.crashed then
sprn = 29
elseif sprn == 25 and elapsed(t.last_push) < 5 or vecmag(t.vel) < 0.1 then
if t.skier_state != ge_skier_start then
sprn = 27
else
sprn = 100
local frame = flr(g_tick / 41) % 2
local y_offst = frame == 0 and 0 or 1
if not t.blink or t.blink == g_tick then
pal(7, 0)
t.blink = g_tick + 45+ flr(rnd(120))
end
for x_off=-3,3,6 do
line(x_off, -4+y_offst, x_off, 1+y_offst, 1)
line(x_off, -3+y_offst, x_off, -3+y_offst, 11)
end
end
end
pushc(0, t.mogul_off)
spr(sprn, -8, -11 + offset + t.jump_height, 2, 2, pose < 0)
popc()
palt()
pal()
g_cursor_y=12
jump_height_max = max(abs(t.jump_height), jump_height_max)
end,
add_new_trail_point=function(t, p)
p = vecadd(vecflr(p), vecmake(1))
p.gap = t.jumping or t.crashed
p.perpendicular = t.perpendicular
local last_point = t.trail_points[#t.trail_points]
if (
last_point == nil
or last_point.x != p.x
or last_point.y != p.y
) then
add(t.trail_points, p)
end
end
}
end
function clamp_to(val_to_clamp, val_to_clamp_to)
return abs(val_to_clamp - val_to_clamp_to) < 0.015 and val_to_clamp_to or val_to_clamp
end
function make_camera(x,y)
return {
x=x or 30,
y=y or 60,
low_pass=make_one_euro_filt(beta, mincutoff),
delta_offset = 0,
drift = false,
last_target_point = nil,
drift_start = nil,
update=function(t)
if g_state == ge_state_menu_trans then
return
end
local target_point = null_v
if g_p1 then
local offset = 20
if g_p1.vel then
offset += g_p1.vel.y*10
end
local new_offset = t.low_pass:filter(offset)
t.delta_offset = new_offset - offset
target_point = vecadd(g_p1, vecmake(0, new_offset))
if not t.drift then
t.last_target_point = target_point
t.last_vel = g_p1.vel
else
t.drift_start = t.drift_start or g_tick
target_point = t.last_target_point
if elapsed(t.drift_start) < 20 then
vecset(
t.last_target_point,
vecadd(
t.last_target_point,
veclerp(t.last_vel, null_v, elapsed(t.drift_start)/10)
)
)
end
end
end
vecset(t,veclerp(t,target_point,0.2,0.7))
if g_shake_end and g_tick < g_shake_end then
if (
not g_shake_frequency
or ((g_shake_end - g_tick) % g_shake_frequency) == 0
) then
vecset(t, vecadd(t, vecrand(g_shake_mag, true)))
end
end
vecset(t, vecflr(t))
end,
}
end
ge_inverted_controls = false
ge_trackitem_start = 0
ge_trackitem_end = 1
ge_trackitem_left = 2
ge_trackitem_right = 3
ge_trackitem_mogul = 10
ge_trackitem_text = 20
ge_trackitem_hole = 21
ge_trackitem_ice = 22
ge_state_menu = 0
ge_state_menu_trans = 1
ge_state_playing = 2
ge_skier_normal = 0
ge_skier_tuck = 1
ge_skier_wedge = 2
ge_skier_start = 3
gate_height = 10
gate_stem_color = 5
gate_flag_height = 4
gate_flag_width = 4
gate_flag_height_offset = 6
tracks = {
{
name = "first tracks",
course = {
{vecmake(), ge_trackitem_start, 32},
{vecmake(-48, 8), ge_trackitem_text, "   press any key\nto start"},
{vecmake(-16, 64), ge_trackitem_text, "  hold  \nfor brakes"},
{vecmake(-48, 70), ge_trackitem_right},
{vecmake(32, 100)},
{vecmake(-48, 32), ge_trackitem_text, "  hold  \n to dash "},
{vecmake(-96, 140)},
{vecmake(0, 80)},
{vecmake(-20, 90)},
{vecmake(-45, 60), ge_trackitem_text, "     press  \nto jump over the hole!"},
{vecmake(-45, 80), ge_trackitem_hole, 12, 1},
{vecmake(-20, 200), ge_trackitem_text, "finish line!"},
{vecmake(0,   220), ge_trackitem_end, 16},
}
},
{
name = "powder days",
course = {
{vecmake(), ge_trackitem_start, 32},
{vecmake(-50, 90), ge_trackitem_right},
{vecmake(50, 90)}, 
{vecmake(200, 80)},
{vecmake(90, 90)}, 
{vecmake(-60, 90)},
{vecmake(-0, 90)}, 
{vecmake(0, 90), ge_trackitem_right},
{vecmake(0, 60)},
{vecmake(0, 60)},
{vecmake(-30, 40), ge_trackitem_hole, 12, 1},
{vecmake(-60, 120), ge_trackitem_hole, 12, 4},
{vecmake(0, 180)},
{vecmake(-30, 40), ge_trackitem_hole, 12, 1},
{vecmake(-60, 120), ge_trackitem_hole, 12, 4},
{vecmake(0,   220), ge_trackitem_end, 16},
}
},
{
name = "sunnyside",
course = {
{vecmake(), ge_trackitem_start, 32},
{vecmake(-50, 90), ge_trackitem_right},
{vecmake(50, 90)}, 
{vecmake(-10, 40), ge_trackitem_ice, 12, 1},
{vecmake(-50, 90)}, 
{vecmake(200, 80)},
{vecmake(90, 90)}, 
{vecmake(-60, 90)},
{vecmake(-0, 90)}, 
{vecmake(0, 90), ge_trackitem_right},
{vecmake(0, 60)},
{vecmake(0, 60)},
{vecmake(-30, 40), ge_trackitem_hole, 12, 1},
{vecmake(-60, 120), ge_trackitem_hole, 12, 4},
{vecmake(0, 180)},
{vecmake(-30, 40), ge_trackitem_hole, 12, 1},
{vecmake(-60, 120), ge_trackitem_hole, 12, 4},
{vecmake(0,   220), ge_trackitem_end, 16},
}
}
}
track_names = {}
foreach(tracks, function(t) add(track_names, t.name) end)
add(track_names, "invert controls")
ge_timerstate_stopped = 0
ge_timerstate_running = 1
function make_clock()
return {
x=64,
y=2,
c=0,
m=0,
s=0,
misses=0,
state=ge_timerstate_stopped,
start=function(t)
t.state = ge_timerstate_running
end,
stop=function(t)
t.state = ge_timerstate_stopped
end,
draw=function(t)
rectfill(-16,-1,16,5,6)
local mp,sp,cp = '','',''
if t.m<10 then
mp=0
end
if t.s<10 then
sp=0
end
if t.c < 10 then
cp=0
end
print(mp..t.m..':'..sp..t.s.."."..cp..t.c, -15,0,0)
local ndigits=6
if t.misses > 9 then
ndigits +=1
end
if t.misses > 99 then
ndigits += 1
end
local half_len = ndigits/2
rectfill(-half_len*4, 7, half_len*4, 13, 6)
print("miss:"..t.misses, -half_len*4+1, 8, 0)
end,
increment=function(t, amount)
for i=1,amount do
t.c+=1
if t.c>=30 then
t.c=0
t.s+=1
if t.s>=60 then
t.s=0
t.m+=1
end
end
end
end,
update=function(t)
if t.state == ge_timerstate_stopped then
return
end
t:increment(1)
end,
inc_missed_gate = function(t)
t.misses += 1
shake_screen(min(15*(vecmag(g_p1.vel)/4), 5), 15, 3)
flash_screen(4, 8)
end
}
end
function make_score_display(base_timer, score_mode, track_ind)
local total_misses = base_timer.misses
return {
y=-192,
start=vecmake(0, -192),
target=vecmake(0, -4),
frame=15,
made=g_tick,
duration=25,
space=sp_world,
update=function(t)
if t.frame < t.duration then
vecset(t, veclerp(t.start, t.target, smootherstep(t.frame/t.duration)))
end
t.frame += 1
if t.frame < t.duration then
for j=-32,32,8 do
for i=0,30 do
local off=vecrand(6, true)
add_particle(
j+t.x + off.x+rnd_centered(6),
t.y + off.y+rnd_centered(6),
0 + rnd_centered(6),
3+rnd(1),
8,
6,
0.5
)
end
end
elseif (
base_timer.misses
and base_timer.misses > 0
and t.made and (elapsed(t.made) % 15) == 0
) then
base_timer.misses -= 1
g_timer:increment(50)
shake_screen(8, 5)
flash_screen(4, 8)
end
if (
t.made
and elapsed(t.made) > 45
and (score_mode or base_timer.misses == 0)
) then
t.made = nil
local menu_items = {'try track again'}
local n_tracks = #tracks
if track_ind != n_tracks then
add(menu_items, 'next track')
end
add(menu_items, 'main menu')
add_gobjs(
make_menu(
menu_items,
function (t, i, s)
local function done_func()
if i==0 then
slalom_start(track_ind)
elseif i==2 or track_ind == n_tracks then
_title_stuff()
else
slalom_start(track_ind+1)
end
end
add_gobjs(make_snow_trans(done_func, 7))
end
)
)
end
end,
timer_score=function()
local m_t = 0
if base_timer.m > 10 then
m_t = min(9, flr(base_timer.m/10))
end
local m_o = base_timer.m - 10*flr(base_timer.m/10)
local s_t = 0
if base_timer.s > 10 then
s_t = min(9, flr(base_timer.s/10))
end
local s_o = base_timer.s - 10*flr(base_timer.s/10)
local c_t = 0
if base_timer.c > 10 then
c_t = min(9, flr(base_timer.c/10))
end
local c_o = base_timer.c - 10*flr(base_timer.c/10)
return {m_t, m_o, 10, s_t, s_o, 10, c_t, c_o}
end,
draw=function(t)
local gratz_str = "congratulations!"
local msg_str = score_mode and "your final score was:" or "your final time was:"
g_cursor_y = -12
if score_mode or base_timer.misses == 0 then
print_cent(gratz_str, 14)
print_cent(msg_str, 14)
end
g_cursor_y = 9
if not score_mode then
print_cent("misses: "..(total_misses - base_timer.misses), 14)
end
local char_array = {}
char_array = t:timer_score()
local x_off = -#char_array*4
palt(3, true)
palt(0, false)
pal(7, 2)
pal(6, 14)
for i in all(char_array) do
spr(196+i, x_off, 0, 1, 1, false, false)
x_off += 8
end
pal()
palt()
process_particles(sp_world)
if total_misses == 0 and t.frame >= t.duration+30 then
spr(228, 20, 7+3*sin(g_tick/30), 2, 1)
end
end
}
end
function make_score_screen(timer, backcountry_mode, track_ind)
g_objs = {
make_bg(7),
make_score_display(timer, backcountry_mode, track_ind),
}
g_p1 = nil
g_cam = add_gobjs(make_camera(0,0))
g_state = ge_state_menu
end
function make_gate(gate_data, accum_y, starter_objects, track_ind)
local gate_kind = gate_data[2]
if gate_kind == nil then
gate_kind = (
ge_trackitem_right
- starter_objects[#starter_objects].gate_kind
+ ge_trackitem_left
)
end
local gate_border_offset = 0
if gate_kind == ge_trackitem_right then
gate_border_offset = 30
elseif gate_kind == ge_trackitem_left then
gate_border_offset = -30
end
return {
x=gate_data[1].x,
y=accum_y,
gate_border_offset = gate_data[1].x + gate_border_offset,
radius=gate_data[3],
gate_kind=gate_kind,
space=sp_world,
overlaps = false,
missed=nil,
passed=nil,
spr_ind=68,
celebrate = false,
update=function(t)
if t.passed or t.missed then
return
end
local flash = false
if abs(g_p1.y - t.y) < 0.5 then
t.overlaps = true
elseif t.overlaps or (g_p1.y < t.y and g_p1.y + g_p1.vel.y > t.y) then
if t.gate_kind == ge_trackitem_start then
g_timer:start()
elseif t.gate_kind == ge_trackitem_end then
g_timer:stop()
g_cam.drift = true
g_cam.last_target_point = veccopy(t)
function done_func()
make_score_screen(g_timer, false, track_ind)
end
add_gobjs(make_snow_trans(done_func, 7, 45))
t.celebrate = g_tick
elseif t.gate_kind == ge_trackitem_left then
if g_p1.x > t.x  then
flash = true
elseif t.passed == nil then
t.passed = g_tick
end
elseif t.gate_kind == ge_trackitem_right then
if g_p1.x < t.x then
flash = true
elseif t.passed == nil then
t.passed = g_tick
end
end
t.overlaps = false
end
if flash and not t.missed then
g_timer:inc_missed_gate()
t.missed = g_tick
end
end,
draw=function(t)
if abs(t.y - g_cam.y) > 70 then
return
end
if t.gate_kind == ge_trackitem_start or t.gate_kind == ge_trackitem_end then
for xdir=-1,1,2 do
line(xdir * t.radius, 0, xdir*t.radius, -gate_height, gate_stem_color)
for i=1,gate_flag_height do
for j=1,2 do
if t.celebrate then
add_particle(
t.x + xdir * t.radius,
t.y,
rnd_centered(4),
-rnd(3)-1,
10,
rnd(14)+2,
0.5
)
end
line(
xdir*t.radius, -gate_flag_height_offset - i,
xdir*t.radius + xdir*gate_flag_width, -gate_flag_height_offset - i,
8
)
end
end
end
if t.gate_kind == ge_trackitem_start then
g_cursor_y = -27
print_cent(""..track_ind..": "..tracks[track_ind].name, 15)
g_cursor_y = -28
print_cent(""..track_ind..": "..tracks[track_ind].name, 14)
end
else
local offset=0
local flip = false
if t.gate_kind == ge_trackitem_left then
flip = true
offset = -15
pal(12, 8)
pal(1, 2)
end
if t.missed then
spr(225, -6, -8, 2, 2)
if elapsed(t.missed) <= 30 then
local radius = lerp(elapsed(t.missed)/5, 2, 10)
circ(0,0,radius, 8)
circ(0,0,radius+0.5, 8)
end
end
if t.passed != nil and not t.missed then
if elapsed(t.passed) % 2 == 1 then
t.spr_ind += 2
end
if t.spr_ind == 76 then
t.passed = nil
end
end
spr(t.spr_ind, offset, -16, 2, 2, flip)
if flip then
pal()
end
end
end
}
end
function make_starting_gate()
return {
start_frame=nil,
space=sp_world,
update=function(t)
if not t.start_frame and g_p1.skier_state != ge_skier_start then
t.start_frame = g_tick
end
end,
draw=function(t)
line(-11, -18, -11, 0, 1)
line(11, -18, 11, 0, 1)
rectfill(-11, -18, 11, -10, 12)
rectfill(-10, -17, 10, -11, 1)
print("start", -9, -16, 12)
line(-5, -4, -5, 0, 1)
line(5, -4, 5, 0, 1)
local angle = 0.5
if t.start_frame then
angle = lerp(ef_out_quart(elapsed(t.start_frame)/20), 0.5, 0.25)
end
local start = vecmake(-5, -4)
local endp = vecadd(start, vecfromangle(angle, -10))
line(start.x, start.y, endp.x, endp.y, 12)
end,
}
end
function slalom_start(track_ind)
g_state = ge_state_playing
g_objs = {
make_bg(7),
}
g_mountain = add_gobjs(make_mountain("slalom", track_ind))
g_partm    = add_gobjs(spray_particles())
g_cam      = add_gobjs(make_camera())
g_p1       = add_gobjs(make_player(0))
add_gobjs(make_starting_gate())
g_timer    = add_gobjs(make_clock())
in_front_of_player       = add_gobjs(
{
draw=function()
process_particles(sp_world, 1)
g_mountain:draw_in_front_of_player()
end
}
)
music(10)
end
ramp = {1, 13, 12, 6, 3, 11, 10}
function make_bg(col)
col = col or 7
return {
draw=function()
stdclscol(col)
end
}
end
function make_line(before, g1, g2, after)
local m0 = vecmake(0, 1)
local m1 = vecmake(0, -1)
if before then
m0 = vecsub(g1, before)
end
if after then
m1 = vecsub(after, g2)
end
local p0 = vecmake(g1.gate_border_offset, g1.y)
local p1 = vecmake(g2.gate_border_offset, g2.y)
local pts = {p0}
local curve_points = 10
local last_point = p0
for z_prime=1,curve_points,1 do
local z = z_prime/curve_points
local p0_t = vecscale(p0, (2*z*z*z - 3*z*z + 1))
local m0_t = vecscale(m0, (z*z*z - 2*z*z + z))
local p1_t = vecscale(p1, (-2*z*z*z + 3*z*z))
local m1_t = vecscale(m1, (z*z*z - z*z))
last_point = add(pts, vecadd(vecadd(p0_t, m0_t), vecadd(p1_t, m1_t)))
end
return {
space=sp_world,
g1=g1,
g2=g2,
x_coordinte=function(t, y_coordinate)
local tgt_ind = #pts
for i=2,#pts do
if pts[i].y > y_coordinate then
tgt_ind = i
break
end
end
local pt1 = pts[tgt_ind-1]
local pt2 = pts[tgt_ind]
return (y_coordinate - pt1.y) * (pt2.x - pt1.x) / (pt2.y - pt1.y) + pt1.x
end,
draw=function(t)
if abs(t.g2.y - g_cam.y) > 130 and abs(t.g1.y - g_cam.y) > 130 then
return
end
local last_point = p0
local colors = {10,9,4,9,10}
local npts = #pts
for p_ind = 2,npts,1 do
local last_point = pts[p_ind-1]
local p_t = pts[p_ind]
for offset=-1,1,2 do
for l_ind=1,5 do
local i=49+l_ind
local c = colors[l_ind]
line(last_point.x+offset*i, last_point.y, p_t.x+offset*i, p_t.y, c)
end
end
last_point = p_t
end
end
}
end
function trackitem_factory(gate_data, accum_x, accum_y)
local fn = trackitem_map[gate_data[2]]
if fn then
return fn(gate_data, accum_x, accum_y)
end
end
function make_ice_trackitem(gate_data, accum_x, accum_y)
local size = { gate_data[3],gate_data[4] }
return {
x=accum_x+gate_data[1].x,
y=accum_y+gate_data[1].y,
space=sp_world,
size = size,
bound_min = vecmake(),
bound_max = vecmake(size[1]*8-1, size[2]*8-1),
overlaps=function(t, o)
o.is_on_ice = g_tick
end,
draw=function(t)
palt(0, false)
rectfill(0,0,t.bound_max.x, t.bound_max.y, 12)
palt()
end,
}
end
function make_hole_trackitem(gate_data, accum_x, accum_y)
local size = { gate_data[3],gate_data[4] }
local sprites = {}
for j=1,size[2] do
local row = add(sprites, {})
for i=1,size[1] do
local sprnum = -1
if i==1 or i==size[1] or j==1 or j==size[2] then
sprnum = flr(rnd(4))
end
add(row, sprnum)
end
end
return {
x=accum_x+gate_data[1].x,
y=accum_y+gate_data[1].y,
space=sp_world,
size = size,
bound_min = vecmake(),
bound_max = vecmake(size[1]*8-1, size[2]*8-1),
overlaps=function(t)
if not g_p1.jumping and not g_p1.crashed then
g_p1.sliding = false
g_p1.crashed = true
shake_screen(min(15*(vecmag(g_p1.vel)/4), 5), 15, 3)
flash_screen(10, 8)
g_p1.respawn_location = vecmake(g_p1.x,  t.y + (t.size[2]+1)*8 + 4)
end
end,
draw=function(t)
palt(0, false)
pal(3, 0)
rectfill(0,0,t.bound_max.x, t.bound_max.y, 0)
palt(0, true)
for j=1,size[2] do
local y_off = 8*(j-1)
for i=1,size[1] do
local x_off = 8*(i-1)
local sprnum = sprites[j][i]
if sprnum >= 0 then
local sprites_to_draw = {}
if i==1 then
add(sprites_to_draw, {52, false, false})
end
if i==size[1] then
add(sprites_to_draw, {52, true, false})
end
if j==1 then
add(sprites_to_draw, {48, false, false})
end
if j==size[2] then
add(sprites_to_draw, {48, false, true})
end
if #sprites_to_draw > 1 then
for c_spec_x in all({1, size[1]}) do
for c_spec_y in all({1, size[2]}) do
if i == c_spec_x and j == c_spec_y then
add(sprites_to_draw, {56, i!=1, j!=1})
end
end
end
end
for spr_str in all(sprites_to_draw) do
local base_spr = spr_str[1]
local flip_x = spr_str[2]
local flip_y = spr_str[3]
if flip_y then
pal(6, 0)
pal(5, 0)
end
spr(base_spr + sprnum, x_off, y_off, 1, 1, flip_x, flip_y)
if flip_x or flip_y then
pal(6, 6)
pal(5, 5)
end
end
end
end
end
palt()
pal()
end,
}
end
function make_trackitem_text(gate_data, accum_x, accum_y)
return {
x=accum_x+gate_data[1].x,
y=accum_y+gate_data[1].y,
space=sp_world,
text=gate_data[3],
draw=function(t)
print(t.text, 0, 1, 15)
print(t.text, 0, 0, 8)
end
}
end
trackitem_map = {}
trackitem_map[ge_trackitem_mogul] = make_trackitem_mogul
trackitem_map[ge_trackitem_text] = make_trackitem_text
trackitem_map[ge_trackitem_hole] = make_hole_trackitem
trackitem_map[ge_trackitem_ice] = make_ice_trackitem
function is_gate(gate_data)
return not gate_data[2] or gate_data[2] < 10
end
function make_mountain(kind, track_ind)
local trees = {}
local starter_objects = {}
local lines = {}
if kind == "slalom" then
local gates = {}
starter_objects = {}
local accum_y = 0
for gate in all(tracks[track_ind]["course"]) do
if is_gate(gate) then
accum_y += gate[1].y
add(gates, make_gate(gate, accum_y, gates, track_ind))
else
if gate[2] == ge_trackitem_mogul then
local n_x = gate[3] or 1
local n_y = gate[4] or 1
for i=1,n_x do
for j=1,n_y do
local accum_x = gate[1].x + 16*(i-1)
add(trees, trackitem_factory(gate, accum_x, accum_y + 16*(j-1)))
end
end
else
add(trees, trackitem_factory(gate, 0, accum_y))
end
end
end
for i=2,#gates do
add(lines, make_line(gates[i-2], gates[i-1], gates[i], gates[i+1]))
end
for l_obj in all(lines) do
add(starter_objects, l_obj)
end
for g_obj in all(gates) do
add(starter_objects, g_obj)
end
local current_line = 1
for i=0,16 do
local y_c = i*10-80
local l = lines[current_line]
if y_c > l.g2.y then
current_line += 1
l = lines[current_line]
end
for off=-1,1,2 do
for j=1,4 do
local off_x = off*90
local rndloc = vecmake(
rnd_centered(40) + off_x + l:x_coordinte(y_c),
rnd_centered(12) + y_c
)
add(trees, make_tree(rndloc))
end
end
end
end
return {
sp=sp_world,
c_objs=starter_objects,
p_objs=trees,
lines=lines,
line_for_height=function(t, y)
for i=1,#lines do
if t.lines[i].g2.y > y then
return t.lines[i]
end
end
return t.lines[#lines]
end,
update=function(t)
updateobjs(t.p_objs)
updateobjs(t.c_objs)
end,
draw=function(t)
drawobjs({g_p1}, "backmost")
drawobjs(t.p_objs, "behind_player")
drawobjs(t.c_objs)
end,
draw_in_front_of_player=function(t)
drawobjs(t.p_objs, "in_front_player")
end
}
end
function flash_screen(duration, c)
g_flash_end = g_tick + duration + 1
g_flash_color = c
end
function shake_screen(duration, magnitude, frequency)
g_shake_end = g_tick + duration + 1
g_shake_mag = magnitude
g_shake_frequency = frequency
end
function reset_shake()
g_shake_end = nil
g_shake_mag = nil
g_shake_frequency = nil
end
function respawn_object(t, anywhere)
if g_cam.y - t.y > 80 then
t.y += 160
local flip = rnd(1) > 0.5 and 1 or -1
local rnd_off = 110 + rnd_centered(60)
t.x = flip*rnd_off
t.x += g_mountain:line_for_height(t.y):x_coordinte(t.y)
del(g_mountain.p_objs, t)
add(g_mountain.p_objs, t)
end
end
function make_tree(loc, anywhere)
return {
x=loc.x,
y=loc.y,
space=sp_world,
bound_min=vecmake(-2,9),
bound_max=vecmake(1,12),
flip=rnd(1) > 0.5,
height=flr(rnd(24)),
overlaps=function(t, o)
if not g_p1.jumping and not g_p1.crashed then
g_p1.sliding = false
g_p1.crashed = true
shake_screen(9, 20, 3)
g_p1.respawn_location = vecmake(
g_mountain:line_for_height(t.y):x_coordinte(t.y),
t.y
)
end
end,
update=function(t)
respawn_object(t, anywhere)
end,
draw=function(t)
sspr(
0, 32, 8, 16,
-4 - t.height/8, -4 - t.height,
8+t.height/4, 16 + t.height,
t.flip
)
end
}
end
function overlaps_bounds(fst, snd)
if not fst.bound_min or not snd.bound_min or
not fst.bound_max or not snd.bound_max then
return false
end
for dim in all({'x','y'}) do
fst_dim = {
fst.bound_min[dim] + fst[dim],
fst.bound_max[dim] + fst[dim]
}
snd_dim = {
snd.bound_min[dim] + snd[dim],
snd.bound_max[dim] + snd[dim]
}
if (
(fst_dim[2] < snd_dim[1])
or
(fst_dim[1] > snd_dim[2])
) then
return false
end
end
return true
end
function print_cent(str, col)
str = tostr(str)
print(str, -(#str)*2, g_cursor_y, col or 8)
g_cursor_y += 6
end
function stdinit()
g_tick=0    
g_ct=0      
g_ctl=0     
g_cs = {}   
g_objs = {} 
end
function stdupdate()
g_tick = max(0,g_tick+1)
g_ctl = g_ct
g_ct = btn()
updateobjs(g_objs)
end
function updateobjs(objs)
foreach(objs, function(t)
if t.update then
t:update(objs)
end
end)
end
function stdclscol(col)
rectfill(127,127,0,0,col)
end
function stddraw()
drawobjs(g_objs)
if g_flash_end and g_tick < g_flash_end then
for i=1,128 do
for j=1,128 do
if pget(i, j) != 7 then
pset(i, j, g_flash_color)
end
end
end
else
g_flash_end = nil
end
end
function drawobjs(objs, mode)
foreach(
objs,
function(t)
if
(mode == "behind_player" and t.y > g_p1.y - 2)
or (mode == "in_front_player" and t.y < g_p1.y - 2)
then
return
end
if t.draw then
local cam_stack = 0
local t_t = vecflr(t)
if t.space == sp_screen_center then
pushc(-64, -64)
cam_stack += 1
elseif t.space == sp_world and g_cam  then
pushc(flr(g_cam.x) - 64, flr(g_cam.y) - 64)
pushc(-t_t.x, -t_t.y)
cam_stack += 2
elseif not t.space or t.space == sp_local then
pushc(-t_t.x, -t_t.y)
cam_stack += 1
end
t:draw(objs, mode)
for i=1,cam_stack do
popc()
end
end
end
)
end
function btns(i,p)
i=shl(1,i)
if p==1 then
i=shl(i,8)
end
local c,cng =
band(i,g_ct),
band(i,g_ctl)
return c>0,c~=cng
end
function btnn(i,p)
if p==-1 then 
return btnn(i,0) or btnn(i,1)
end
local pr,chg=btns(i,p)
return pr and chg
end
function pushc(x, y)
local l=g_cs[#g_cs] or {0,0}
local n={l[1]+x,l[2]+y}
add(g_cs, n)
camera(n[1], n[2])
end
function popc()
local len = #g_cs
g_cs[len] = nil
len -= 1
if len > 0 then
local xy=g_cs[len]
camera(xy[1],xy[2])
else
camera()
end
end
function make_menu(
lbs, 
fnc, 
x,y, 
omb, 
p,   
cfnc 
)
local m={
i=0, 
s=g_tick,
e=5,
x=x or 64,
y=y or 80,
h=10*#lbs+4,
tw=0,
p=p or -1,
draw=function(t)
local e=elapsed(t.s)
local w=t.tw*4+10
local x=min(1,e/t.e)*(w+9)/2
if not omb then
rectfill(-x,0,x,t.h,0)
rect(-x,0,x,t.h,1)
end
if e<t.e then
return
end
x=w/2+1
for i,l in pairs(lbs) do
if not t.off or i==t.i+1 then
local y=4+(i-1)*10
print(l,-x+9,y+1,0)
print(l,-x+9,y,7)
end
end
spr(0,-x,2+10*t.i)
end,
update=function(t,s)
if t.off then
return
end
if elapsed(t.s)<t.e*2 then
return
end
if btnn(5,t.p) then
if fnc then
fnc(t,t.i,s)
end
end
if btnn(4,t.p) then
if cfnc then
cfnc(t,s)
end
end
if btnn(2,t.p) and
t.i>0 then
t.i-=1
end
if btnn(3,t.p) and
t.i<(#lbs-1) then
t.i+=1
end
end
}
for l in all(lbs) do
m.tw=max(m.tw,#l)
end
return m
end
function elapsed(t)
if g_tick>=t then
return g_tick - t
end
return 32767-t+g_tick
end
function make_snow_chunk(src, tgt, col, size, nframes, delay)
local start = g_tick+delay
return {
x=src.x,
y=src.y,
update=function(t)
vecset(t, veclerp(t, tgt, elapsed(start)/nframes))
end,
draw=function()
circfill(0, 0, size, col)
end
}
end
function make_snow_trans(done_func, final_color, delay)
if g_trans then
return
end
delay = delay or 0
reset_shake()
local snow = {}
local topsize =  17
for i=1,128,topsize do
for j=1,128,topsize do
local tgt = vecmake(i,j)
local src = vecsub(
tgt,
vecsub(vecmake(256), vecflr(vecscale(vecrand(16), 8)))
)
local size = topsize+rnd(topsize/4)
local col = flr(rnd(2))+6
add(snow, make_snow_chunk(src, tgt, col, size, 30 + rnd(15), delay))
if col != final_color then
add(
snow,
make_snow_chunk(
vecsub(src, vecmake(128)),
tgt,
final_color,
size,
60 + rnd(15),
delay
)
)
end
end
end
local start=g_tick
g_trans = {
space=sp_screen_native,
update=function(t)
if elapsed(start) > delay then
g_state = ge_state_menu_trans
if elapsed(start) - delay > 28 then
del(g_objs, t)
g_trans = nil
done_func()
end
updateobjs(snow)
end
end,
draw=function()
if elapsed(start) > delay then
drawobjs(snow)
end
end
}
return g_trans
end
__gfx__
0060000010122101000000003300033000666000000600000000000098899000998899000bb0000011357bdf0c00000c76666777766667770000000000000000
0066000000088000000c0000300000300633360000636000000000009988990059988990088b0000fffeeddc0000c0c076556667765566670000000000006000
0066600010033001000c00000000000063333360063336000000000049988990599889900888b000cbbaa998c0c00c0076555566765555560000000000066000
00666600283083820cc8cc0000030000336663300066600000666000549988905599889908000000877665540c0000c066500556765000560000000000033000
0066650028380382000c00000000000006333600063336000055560055499899559988990800000043322111000c000066550567765000560000000000033000
0066500010033001000c00003000003000333000633433600055550055588888559988992820000011111111c0c000c076650567765000560000000000633600
00650000000880000000000033000330000400000004000000000000000000005588888828200000111111110c00c00077650567765000560000000000363300
005000001012210100000000000000000004000000040000000000000000000000000000222000001111111100c00c0c77777667765000560000000000333300
33888883333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333306333360
0387978333333333a33333333333333a33333333333333a333333333333333333333333333333333333333333333333333333333333333333333333303336330
30899980333333338333333333333338333333333333333833333333333a33333333333333333333333333333333333333333333333333333333333303333330
3b88888b333333338333333333333338833333333333333883333333333388333333333333333333333333333333333333333333333333333344333363333336
30222220333330388830333333303338880333333333333888333333333388883333333333333333333333333333333333333333333343333443333333363333
43b23b233333308888803333333303888883333333033388888333333333388888833333333388888883333333338888888333333333433344a3333300333300
44bb4bb3333330879780333333330387978033333330338879733333330333887973333333a888888973333333a888888973333333334034b383333300044000
3444344333333089998033333333308999803333333303889980333333300388998b0333333333888993333333333388899333333333490b3883333300044000
0000000033333b88888b333333333b88888b333333333b88888b333333330b088883333333333000b08333333333338888833333333349908883333300000000
000000003333302222203333333330222220333333333302222303333333332222233333333333222223333333333322b223333333334d22b888333300000000
0000000033333322322333333333332232233333333333223223333333333322322333333333333222233333333333320223333333334d228088333300000000
00000000333333dd3dd33333333333dd3dd33333333333dd3dd33333333333dd3dd333333333333dd33333333333333d03333333333393228998333300000000
00000000333333ee3ee33333333333ee3ee33333333333ee3ee33333333333ee3ee333333333333ee33333333333333e03333333333399228978333300000000
00000000333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333300000000
00000000333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333300000000
00000000333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333300000000
77766777767777776666777776566677765000007650000076500000765000007650000077700000776000007660000000000000000000000000000000000000
66655666657777766555566665055566765000007765000076500000765000006500000077600000765000006550000000000000000000000000000000000000
55500555505666655550005550000055765333337765333376033333650333335003333376533333650333335003333300000000000000000000000000000000
00300300003055500030030000300300650000007765000075000000650000000030000000300000003000000030000000000000000000000000000000000000
00300300003003000030030000300300650000007760000065000000650000000030000000300000003000000030000000000000000000000000000000000000
00300300003003000030030000300300765333337753333365533333500333330030000000300000003000000030000000000000000000000000000000000000
00300300003003000030030000300300765000006500000065500000650000000030000000300000003000000030000000000000000000000000000000000000
00300300003003000030030000300300765000007650000066500000765000000030000000300000003000000030000000000000000000000000000000000000
000000000000000000000000000000005c0000000000000000000005c00000000000000000000000000000000000000000000000000000000000000000000000
000060000000000000000000000060005cc000000000000000000055c00000000000000000000000000000000000000000000000000000000000000000000000
0006600000006600000000600006600051cc00000000000000000051cc0000000000000000000000000000000000000000000000000000000000000000000000
00033000000336000000066000033000511cc00000000000000005511c0000000000000000000000000000000000000000000000000000000001111111111000
000330000003300000063300000330005c11cc0000000000000005cc1c0000000000000000050000000000000000000000000000000000000011111111111100
00633600006330000003630000633600511cc00000000000000055111cc000000000000000550000000000000000000000000000000000000112222222222110
0036330000363600000333000036330051cc0000000000000000511cccc0000000000000055c0000000000000000000000000000000000001122334444332211
003333000033330000333600003333005cc000000000000000055ccc0000000000000000551c0000000000000000000000000000000000001223445665443221
063333600633330000336300063333605c000000000000000005cc0000000000000000055c1c0000000000000000000000000000000000001122344554432211
033363300333636006333300033363305000000000000000000500000000000000000055111c0000000000000000000000000000000000000112344554432111
03333330633333303333336003333330500000000000000000550000000000000000055ccccc0000000000000000000000000000000000000112344554432110
63333336333333300336333063333336500000000000000000500000000000000000550000000000000000000000000000000000000000000012334444332100
33363333033633360333303033363333500000000000000005500000000000000005500000000000000005555555555500000000000000000002223333222000
003333000033330300333006003333005000000000000000050000000000000000550000000000000005550cc11c11cc00000000000000000000011111110000
0004400000044000000440000004400050000000000000005500000000000000055000000000000005550000cc111cc000000555555555550000000000000000
00044000000440000004400000044000500000000000000050000000000000005500000000000000550000000cc1cc005555550cc11c11cc0000000000000000
0000000000000000000000000000000033333333333333333333333333333333333333333333333333333333333333333333333333333333cccccccccccccccc
00000000000000000000000000000000333333333333333333333333333333333333333333333333333333333333333333333333333333331111111111111111
0000000000000000000000000000000033333333333333333333332333233333333333333323333333333333333333333333333333333333ccccccccc1cc1ccc
0006600006666000006660000066600033333333333333333333332333233333333333333223333333366666666663333336666666666333c111c1c1c1c1c1c1
666556600555566006555600005556663333333888333333333333223223333333333333222333333366777ffffaf6333366777fffff6633ccc1c1ccc1cc11c1
55556556655655500566556006555555333333888883333333333311111333333333333311133333366777777777af6336677777777ff66311c1c1c1c1c1c1c1
66555555555665566555555665556655333333879783333333333317d7133333333333311d7333336677777777777af666777777777aff66ccc1c1c1c1c1c1c1
5555555555555555555555555555555633333389998333333333d31ddd13d333333333111dd3333367777777777777af65d677777777aff61111111111111111
00000000000000000000000000000000333333888883333333333d17071d33333333331d117333336d7777777777777f65d6677777777affcccccccccccccccc
000000000000000000000000000000003333332222233333333333272723333333333322d2733333357777777777777f35dd67777777777f0000000000000000
0000000000000000000000000000000033333322322333333333332737233333333333322273333335577777777777f3355d6677777777730000000000000000
00000000000000000000000000000000333333dd3dd33333333333dd3dd333333333333dd3333333335d777777777f333355d667777777330000000000000000
00000000000000000000000000000000333333ee3ee33333333333ee3ee333333333333ee333333333355d677777733333355ddd777773330000000000000000
000000000000000000000000000000003333333333333333333333333333333333333333333333333333555d6777333333333555577733330000000000000000
00000000000000000000000000000000333333333333333333333333333333333333333333333333333333333333333333333333333333330000000000000000
00000000000000000000000000000000333333333333333333333333333333333333333333333333333333333333333333333333333333330000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000
00000000000000070000000007000000000000000000000000000000070000700000000000000000000777000000000000000000000000000000000000000000
07777000000000777007000077700700000077770000000000000000770007770070000007777000000777700000000000000000000000000777700000000000
77777770000007777077700777707770000777777700000000000007770077770777000077777000000777770000000000000000000000777777777000000000
17711170000011111177100111111111100177111700000111110111110011111111110017711170000111111111110000000000000000111771117000000000
1c7cc11000001cccccc71011ccccc7cc1101c7cc11000001ccc111ccc1011ccccc7cc1101c7cc1170001ccc11cccc10000000000000000c11c7cc11000000000
1ccccc1100001ccccccc101cccccccccc101ccccc1100001cccc1cccc101cccccccccc101ccccc110001ccc11cccc10000000000000000cc1ccccc1100000000
1cccccc110001ccccccc101cccccccccc101cccccc110001ccccccccc101cccccccccc101cccccc10001ccc1111cc10000000000000000cc1cccccc110000000
1ccccccc11001ccc1111101ccc1111ccc101ccccccc11001ccccccccc101ccc1111ccc101ccc1cc10001ccc1011cc11111111100000000cc1ccccccc11000000
1ccc1cccc1101ccc1000001ccc1000ccc101ccc1cccc1101ccccccccc101ccc1000ccc101ccc1cc17001ccc1011111ccccccc100000000cc1ccc1cccc1100000
1ccc11cccc101ccc1777001ccc1777ccc101ccc11cccc101ccc1c1ccc101ccc1777ccc101ccc1cc11701ccc101ccccccccccc100000000cc1ccc11cccc100000
1ccc101ccc101ccc1111101ccc1111ccc101ccc101ccc101ccc111ccc101ccc1111ccc101ccc1ccc1101ccc101ccccccccccc100000000cc1ccc101ccc100000
1ccc1001cc101ccccccc101cccccccccc101ccc1001cc101ccc101ccc101cccccccccc101ccc11ccc101ccc101ccc111111111000000000c1ccc1001cc100000
1ccc1001cc101ccccccc101cccccccccc101ccc1001cc101ccc101ccc101cccccccccc101ccc101cc101ccc101ccc100000000000000000c1ccc1001cc100000
1ccc1001cc101ccccccc101cccccccccc101ccc1001cc101ccc101ccc101cccccccccc101ccc101cc101ccc101ccc111111111000000000c1ccc1001cc100000
1ccc1001cc101ccc1111101ccc1111ccc101ccc1001cc101ccc101ccc101ccc1111ccc101ccc101cc171ccc101ccccccccccc1000000000c1ccc1001cc100000
1ccc1001cc101ccc1000001ccc1001ccc101ccc1001cc101ccc101ccc101ccc1001ccc101ccc101cc111ccc101ccccccccccc1000000000c1ccc1001cc100000
1ccc101ccc101ccc1000001ccc1001ccc101ccc101ccc101ccc101ccc101ccc1001ccc101ccc1011cc11ccc101ccccccccccc1000000000c1ccc101ccc100000
1ccc11cccc101ccc1707001ccc1001ccc101ccc11cccc101ccc101ccc101ccc1001ccc101ccc10011cc1ccc10111111111ccc1000000000c1ccc11cccc100000
1ccc1cccc1101ccc1777001ccc1001ccc101ccc1cccc1101ccc101ccc101ccc1001ccc101ccc10001cc1ccc10000000001ccc1000000001c1ccc1cccc1100000
1ccccccc11001ccc1111101ccc1001ccc101ccccccc11001ccc101ccc101ccc1001ccc101ccc10001cc1ccc10111111111ccc1000000001c1ccccccc11000000
1cccccc110001ccccccc101ccc1001ccc101cccccc110001ccc101ccc101ccc1001ccc101ccc10001cccccc701ccccccccccc1000000001c1cccccc110000000
1ccc7c1100071ccccccc101ccc1001ccc101ccc7c1100071ccc101ccc101ccc1001ccc101ccc700011cccc7701ccccccccccc1000000007c1ccc7c1100070000
1cc7771000777ccccccc107ccc1001ccc101cc7771000771ccc101ccc107ccc1001ccc101cc77700011cc77701ccccccccccc100000007771cc7771000770000
11777770177771111117707111111711110117777701777111110711110711111171111000000077711111177111111111111100000077771177777017770000
77777777777777777777707777777770000777777777777000000777770777777777000000000077777777777000000000000000007777777777777777770000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000377777733377773337777773377777733777777337777773377777733777777337777773377777733333333300000000
00000000022222222000000000000000376666733376673337666673376666733767767337666673376666733766667337666673376666733337773300000000
07000000028822882000000000000000376776733377673337777673377776733767767337677773376777733777767337677673376776733337673300000000
07700000028882882000000000000000376776733307673337666673307666733766667337666673376666733000767337666673376666733337773300000000
77771000022888882000000000000000376776733337673337677773377776733777767337777673376776733333767337677673377776733337673300000000
177c1000002288882000000000000000376666733337673337666673376666733000767337666673376666733333767337666673300076733337773300000000
1c7c1000000228882200000000000000377777733337773337777773377777733333777337777773377777733333777337777773333377733330003300000000
1ccc1000000022888220000000000000300000033330003330000003300000033333000330000003300000033333000330000003333300033333333300000000
1ccc1000000002888822000000000000377777733777777300000000000000001111001111011111011110000000000000000000000000000000000000000000
1ccc1000000002888882200000000000376666733766667300000000000000001cc1101cc101ccc101cc11000000000000000000000000000000000000000000
1ccc1000000002882888220000000000376776733767767300000000000000001c1c101c1101c1c101c1c1000000000000000000000000000000000000000000
1ccc1000000002882288822000000000376666733766667300000000000000001c1c101cc101ccc101c1c1000000000000000000000000000000000000000000
1ccc1000000002882228882200000000376776733777767300000000000000001c1c101c1101c1c101c1c1000000000000000000000000000000000000000000
1ccc1000000002882022888200000000376666733000767300000000000000001c1c101c1101c1c101c1c1000000000000000000000000000000000000000000
1ccc1000000002882002288200000000377777733333777300000000000000001ccc101cc101c1c101ccc1000000000000000000000000000000000000000000
1ccc1000000002222000222200000000300000033333000300000000000000001111101111011111011111000000000000000000000000000000000000000000
1ccc1000000000000000000000000000111111111111111133330000003333331111101111101111001110111100000000000000000000000000000000000000
1ccc10000222222220000000000000001c11c1c1cc1cc1c133300555500333331ccc101ccc101cc1111c111cc100000000000000000000000000000000000000
111110000288228820000000000000001cc1c1c1c11c11c133005777750033331ccc101c1c101c1c11c111c11100000000000000000000000000000000000000
000700000288828820000000000000001c1cc1c1c11cc1c130057777775003331c1c101ccc101c1c111101ccc100000000000000000000000000000000000000
077770000228888820000000000000001c11c1c1c11c111100577777777500331c1c101c1c101c1c10000111c100000000000000000000000000000000000000
711170000022888820000000000000001c11c1c1cc1cc1c105775577557750331c1c101c1c101c1c10000111c100000000000000000000000000000000000000
1ccc1000000228882200000000000000111111111111111105770577057750331c1c101c1c101c1c100001cc1100000000000000000000000000000000000000
1c7c1000000022888220000000000000555555555555555505770577057750331111101111101111100001111000000000000000000000000000000000000000
17771000000002888822000000000000000000000000000000577755777500330111101110001110011110011110000000000000000000000000000000000000
777777000000028888822000000000000000000000000000300577057750033311cc101c10011c1101cc1101cc10000000000000000000000000000000000000
00000000000002882888220000000000000000000000000033005777750033331c11101c1001c1c101c1c101c110000000000000000000000000000000000000
00000000000002882288822000000000000000000000000033305767650333331ccc101c1001c1c101ccc101cc10000000000000000000000000000000000000
0000000000000288222888220000000000000000000000003330576765033333111c101c1001c1c101c11101c110000000000000000000000000000000000000
0000000000000288202288820000000000000000000000003330055550033333111c101c1101c1c101c10001c110000000000000000000000000000000000000
00000000000002882002288200000000000000000000000033330000003333331cc1101cc1011c1101c10001cc10000000000000000000000000000000000000
00000000000002222000222200000000000000000000000033333333333333331111001111001110011100011110000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
001000000356000000035500000003540000000356003540035400000003540000000354000000035400000007550075400000000000075400754000000000000756007550075400754000000000000000000000
011000000356000000035600000003540000000356003540035400000003540000000354000000035400000007540075400000000000075400754000000000000555005550055500555000000000000000000000
001000000356500000035650000003565035650350003565035000356503565035000b5600b5600b5600b5500b5300b5100b50500000075000750000000000000550005500055000550000000000000000000000
0010000000045000452b6250000000045000002b6250000000045000002b6250000000045000002b6250000000045000452b6250000000045000002b6250000000045000002b6250000000045000002b6252b625
0010000000045000452b6250000000045000002b6250000000045000002b6250000000045000002b625000002b625000052b6252b625000052b6552b625000002b625000052b6252b655000052b6252b6452b655
001000001455214552145521455213552135521355213552135521355213552135521355213532135321151200000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001455214552145521455213550135521355213552125501255212552125521355213552135521355213552135521355213542135421354213532135120000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c00000955500000095500000009555000000955000000055550000005555000000555500000055550000004555000000455500000045550000004555000000455500000045500000004555000000455000000
000c000000045000002b715000002b625000002a71500000000450000028715000002b62500000287150000000045000002b715000002b625000002b7150000000045000002a715000002b625000002b62500000
010c00001c1221b1221c1221b1221c1221b1221c1221b1221c1221c1221c1221c122000000000000000000001a122181221a122181221a122181221a122181221a1221a1221a1221a12200000000000000000000
010c000017122171221712217122171221712217122171221c1211c1221c1221c1221c1221c1221c1221c1221b1211b1221b1221b1221b1221b1221b1221b1220000000000000000000000000000000000000000
010c00001c1221b1221c1221b1221c1221b1221c1221b1221c1221c1221c1221c1220000000000000001c122101210000010122000001012210122000001a1221012100000101220000010122101221c1211c122
010c00001712200000000000000000000000000000000000101220000000000000000000000000000000000017122000000000000000000000000000000000001312213122000000000010102100001010210122
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 00034544
00 01034344
00 00030544
00 01030644
00 00034544
02 02040544
00 41424344
00 41424344
00 41424344
00 41424344
01 10111544
00 10111244
00 10111344
00 10111444
02 10111444
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
