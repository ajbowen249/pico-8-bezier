pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- math functions
function lerp(v0, v1, t)
  return (1 - t) * v0 + t * v1
end

function point(x, y)
  return { x = x, y = y }
end

function lerp_2d(p0, p1, t)
  return point(
    lerp(p0.x, p1.x, t),
    lerp(p0.y, p1.y, t)
  )
end

-->8
-- bezier functions
function cub_bezier(p0, p1, p2, p3)
  return {
    p0 = p0,
    p1 = p1,
    p2 = p2,
    p3 = p3,
  };
end

function cub_bezier_state(curve)
  return {
    curve = curve,
    t = 0,
    points = {},
  }
end

function calc_cub_bezier(curve, incr, to_t)
  local state = cub_bezier_state(curve)
  while (state.t < to_t) do
    local q0 = lerp_2d(
      state.curve.p0,
      state.curve.p1,
      state.t
    )

    local q1 = lerp_2d(
      state.curve.p1,
      state.curve.p2,
      state.t
    )

    local q2 = lerp_2d(
      state.curve.p2,
      state.curve.p3,
      state.t
    )

    local r0 = lerp_2d(q0, q1, state.t)
    local r1 = lerp_2d(q1, q2, state.t)

    local b = lerp_2d(r0, r1, state.t)

    state.points[#state.points + 1] = b

    state.t = state.t + incr
  end

  return state
end

-->8
-- general draw functions
function draw_points(points, col)
  for _, point in ipairs(points) do
    pset(point.x, point.y, col)
  end
end

function draw_control_point(point, selected)
  spr(
    selected and 2 or 1,
    point.x - 3,
    point.y - 3
  )
end

function draw_control_points(curve, selected_index)
  draw_control_point(curve.p0, selected_index == 0)
  draw_control_point(curve.p1, selected_index == 1)
  draw_control_point(curve.p2, selected_index == 2)
  draw_control_point(curve.p3, selected_index == 3)
end

-->8
-- ui draw functions

function draw_t_panel(t_val, active)
  local col = active and 3 or 6
  print("t: " .. t_val, 0, 120, col)
end

function draw_help(cur_mode)
  if cur_mode == 0 then
    print("⬅️➡️⬆️⬇️ move point", 52, 108, 6)
    print("🅾️ change point", 52, 114, 6)
    print("❎ adjust t", 52, 120, 6)
  elseif cur_mode == 1 then
    print("⬅️➡️ -/+" .. set_increment_value, 62, 108, 6)
    print("⬇️⬆️ -/+" .. set_increment_value * 5, 62, 114, 6)
    print("❎ adjust points", 62, 120, 6)
  end
end

-->8
-- program logic
bez = cub_bezier(
  point(25, 75),
  point(25, 25),
  point(75, 25),
  point(75, 75)
)

set_increment_value = 0.001
selected_control_point = 0
t_adjust_incr = 0.01
set_t_value = 1
mode = 0

function _draw()
  rectfill(0, 0, 127, 127, 1)
  local curve = calc_cub_bezier(bez, set_increment_value, set_t_value)

  draw_t_panel(set_t_value, mode == 1)

  draw_help(mode)

  draw_points(curve.points, 12)
  draw_control_points(bez, mode == 0 and selected_control_point or 5)
end

function _update()
  if btnp(5) then
    mode = (mode + 1) % 2
  end

  if mode == 0 then
      if btnp(4) then
        selected_control_point = (selected_control_point + 1) % 4
      end

      local mincr = 0.5

      local points = {
        bez.p0,
        bez.p1,
        bez.p2,
        bez.p3,
      }

      local point = points[selected_control_point + 1]

      if btn(0) then
        point.x -= mincr
      end

      if btn(1) then
        point.x += mincr
      end

      if btn(2) then
        point.y -= mincr
      end

      if btn(3) then
        point.y += mincr
      end
    elseif mode == 1 then
        if btn(0) then
          set_t_value -= t_adjust_incr
        end

        if btn(1) then
          set_t_value += t_adjust_incr
        end

        if btn(3) then
          set_t_value -= t_adjust_incr * 5
        end

        if btn(2) then
          set_t_value += t_adjust_incr * 5
        end

        if set_t_value < 0 then
          set_t_value = 0
        elseif set_t_value > 1 then
          set_t_value = 1
        end
  end
end


__gfx__
00000000660606603303033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000600000603000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000600600603003003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700600000603000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000660606603303033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
