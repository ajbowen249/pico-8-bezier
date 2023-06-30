pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- globals
selected_program = 1

-->8
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
-- cubic bezier curve program logic
cbds = {} -- cubic bezier demo state

function init_cubic_bezier_demo()
  cbds = {
    bez = cub_bezier(
      point(25, 75),
      point(25, 25),
      point(75, 25),
      point(75, 75)
    ),
    set_increment_value = 0.001,
    selected_control_point = 0,
    t_adjust_incr = 0.01,
    set_t_value = 1,
    mode = 0,
  }
end

function cbds_draw_t_panel(t_val, active)
  local col = active and 3 or 6
  print("t: " .. t_val, 0, 120, col)
end

function cbds_draw_help(cur_mode)
  if cur_mode == 0 then
    print("⬅️➡️⬆️⬇️ move point", 52, 108, 6)
    print("🅾️ change point", 52, 114, 6)
    print("❎ adjust t", 52, 120, 6)
  elseif cur_mode == 1 then
    print("⬅️➡️ -/+" .. cbds.set_increment_value, 62, 102, 6)
    print("⬇️⬆️ -/+" .. cbds.set_increment_value * 5, 62, 108, 6)
    print("❎ adjust points", 62, 114, 6)
    print("🅾️ main menu", 62, 120, 6)
  end
end

function draw_cubic_bezier_demo()
  rectfill(0, 0, 127, 127, 1)
  local curve = calc_cub_bezier(cbds.bez, cbds.set_increment_value, cbds.set_t_value)

  cbds_draw_t_panel(cbds.set_t_value, cbds.mode == 1)

  cbds_draw_help(cbds.mode)

  draw_points(curve.points, 12)
  draw_control_points(cbds.bez, cbds.mode == 0 and cbds.selected_control_point or 5)
end

function update_cubic_bezier_demo()
  if btnp(5) then
    cbds.mode = (cbds.mode + 1) % 2
  end

  if cbds.mode == 0 then
      if btnp(4) then
        cbds.selected_control_point = (cbds.selected_control_point + 1) % 4
      end

      local mincr = 0.5

      local points = {
        cbds.bez.p0,
        cbds.bez.p1,
        cbds.bez.p2,
        cbds.bez.p3,
      }

      local point = points[cbds.selected_control_point + 1]

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
    elseif cbds.mode == 1 then
        if btn(0) then
          cbds.set_t_value -= cbds.t_adjust_incr
        end

        if btn(1) then
          cbds.set_t_value += cbds.t_adjust_incr
        end

        if btn(3) then
          cbds.set_t_value -= cbds.t_adjust_incr * 5
        end

        if btn(2) then
          cbds.set_t_value += cbds.t_adjust_incr * 5
        end

        if btn(4) then
          selected_program = 1
        end

        if cbds.set_t_value < 0 then
          cbds.set_t_value = 0
        elseif cbds.set_t_value > 1 then
          cbds.set_t_value = 1
        end
  end
end

-->8
-- b-spline demo
bsds = {} -- b-spline demo state

function init_b_spline_demo()
  bsds = {
    bez = cub_bezier(
      point(25, 75),
      point(25, 25),
      point(75, 25),
      point(75, 75)
    ),
    set_increment_value = 0.001,
    selected_control_point = 0,
    t_adjust_incr = 0.01,
    set_t_value = 1,
    mode = 0,
  }
end

function bsds_draw_t_panel(t_val, active)
  local col = active and 3 or 6
  print("t: " .. t_val, 0, 120, col)
end

function bsds_draw_help(cur_mode)
  if cur_mode == 0 then
    print("⬅️➡️⬆️⬇️ move point", 52, 108, 5)
    print("🅾️ change point", 52, 114, 5)
    print("❎ adjust t", 52, 120, 5)
  elseif cur_mode == 1 then
    print("⬅️➡️ -/+" .. bsds.set_increment_value, 62, 102, 5)
    print("⬇️⬆️ -/+" .. bsds.set_increment_value * 5, 62, 108, 5)
    print("❎ adjust points", 62, 114, 5)
    print("🅾️ main menu", 62, 120, 5)
  end
end

function draw_b_spline_demo()
  rectfill(0, 0, 127, 127, 1)
  local curve = calc_cub_bezier(bsds.bez, bsds.set_increment_value, bsds.set_t_value)

  bsds_draw_t_panel(bsds.set_t_value, bsds.mode == 1)

  bsds_draw_help(bsds.mode)

  draw_points(curve.points, 10)
  draw_control_points(bsds.bez, bsds.mode == 0 and bsds.selected_control_point or 5)
end

function update_b_spline_demo()
  if btnp(5) then
    bsds.mode = (bsds.mode + 1) % 2
  end

  if bsds.mode == 0 then
      if btnp(4) then
        bsds.selected_control_point = (bsds.selected_control_point + 1) % 4
      end

      local mincr = 0.5

      local points = {
        bsds.bez.p0,
        bsds.bez.p1,
        bsds.bez.p2,
        bsds.bez.p3,
      }

      local point = points[bsds.selected_control_point + 1]

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
    elseif bsds.mode == 1 then
        if btn(0) then
          bsds.set_t_value -= bsds.t_adjust_incr
        end

        if btn(1) then
          bsds.set_t_value += bsds.t_adjust_incr
        end

        if btn(3) then
          bsds.set_t_value -= bsds.t_adjust_incr * 5
        end

        if btn(2) then
          bsds.set_t_value += bsds.t_adjust_incr * 5
        end

        if btn(4) then
          selected_program = 1
        end

        if bsds.set_t_value < 0 then
          bsds.set_t_value = 0
        elseif bsds.set_t_value > 1 then
          bsds.set_t_value = 1
        end
  end
end

-->8
-- main menu

mms = {} -- main menu state
mms_last_program = 2

function init_main_menu()
  mms = {
    selected_program = mms_last_program,
    options = {
      "menu",
      "cubic bezier curve",
      "b-spline (stub!)",
    },
  }
end

function draw_main_menu()
  rectfill(0, 0, 127, 127, 1)
  for i, option in ipairs(mms.options) do
    print(option, 0, i * 7, 7 and i == mms.selected_program or 6)
  end
end

function update_main_menu()
  if btnp(2) then
    mms.selected_program -= 1

    if mms.selected_program < 1 then
      mms.selected_program = #mms.options
    end
  end

  if btnp(3) then
    mms.selected_program += 1
    if mms.selected_program > #mms.options then
      mms.selected_program = 1
    end
  end

  if btnp(4) or btnp(5) then
    selected_program = mms.selected_program
    mms_last_program = mms.selected_program
  end
end

-->8
-- main program logic
last_update_program = -1

init_funcs = {
  init_main_menu,
  init_cubic_bezier_demo,
  init_b_spline_demo,
}

draw_funcs = {
  draw_main_menu,
  draw_cubic_bezier_demo,
  draw_b_spline_demo,
}

update_funcs = {
  update_main_menu,
  update_cubic_bezier_demo,
  update_b_spline_demo,
}

function _draw()
  if last_update_program != selected_program then
    return
  end

  draw_funcs[selected_program]()
end

function _update()
  if last_update_program != selected_program then
    init_funcs[selected_program]()
    last_update_program = selected_program
  end

  update_funcs[selected_program]()
end

__gfx__
00000000660606603303033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000600000603000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000600600603003003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700600000603000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000660606603303033000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
