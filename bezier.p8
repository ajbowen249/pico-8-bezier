pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
-- globals
selected_program = 1
point_pin = 0
point_mirror = 1

-->8
-- library functions

function map(array, func)
  local out = {}
  for i, v in ipairs(array) do
    out[i] = func(v)
  end

  return out
end

function count_ex(array, func)
  local c = 0
  for _, v in ipairs(array) do
    if func(v) then
      c = c + 1
    end
  end
  return c
end

function some(array, func)
  for _, v in ipairs(array) do
    if func(v) then
      return true
    end
  end

  return false
end

-->8
-- math functions
function lerp(v0, v1, t)
  return (1 - t) * v0 + t * v1
end

function point(x, y)
  return { x = x, y = y }
end

function points_equal(p1, p2)
  return p1.x == p2.x and p1.y == p2.y
end

function contains_point(array, p)
  return some(array, function(v)
    return points_equal(p, v)
  end)
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

-- ew, should rework bezier curve into point array...
function get_bez_point(curve, index)
  if index == 1 then
    return curve.p0
  elseif index == 2 then
    return curve.p1
  elseif index == 3 then
    return curve.p2
  else
    return curve.p3
  end
end

function cub_bezier_calc_state(curve)
  return {
    curve = curve,
    t = 0,
    points = {},
  }
end

function calc_cub_bezier_with_state(state, incr, to_t)
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
end

function calc_cub_bezier(curve, incr, to_t)
  local state = cub_bezier_calc_state(curve)
  calc_cub_bezier_with_state(state, incr, to_t)
  return state
end

function bezier_spline(...)
  return {
    curves = { ... },
  }
end

function add_bez_spline_segment(spline, curve)
  spline.curves[#spline.curves + 1] = curve
end

function calc_bez_spline_state(spline)
  return {
    spline = spline,
    curves = map(spline.curves, cub_bezier_calc_state),
    t = 0,
    curve = 0,
  }
end

function calc_bez_spline(spline, incr, to_t)
  local state = calc_bez_spline_state(spline)
  local t_ex = to_t * #spline.curves
  local full_curves = flr(t_ex)
  local inner_t = t_ex - full_curves
  for i = 1, full_curves, 1 do
    calc_cub_bezier_with_state(state.curves[i], incr, 1)
  end

  if full_curves < #state.curves then
    calc_cub_bezier_with_state(state.curves[full_curves + 1], incr, inner_t)
  end

  return state
end

-->8
-- serlialization functions
function bez_spline_to_string(spline)
  local str = ""

  str = str .. #spline.curves .. ","

  for curve_i,curve in ipairs(spline.curves) do
    for i = 1, 4, 1 do
      local p = get_bez_point(curve, i)
      str = str .. p.x .. "," .. p.y
      if i < 4 then
        str = str .. ","
      end
    end

    if curve_i < #spline.curves then
      str = str .. ","
    end
  end

  return str
end

function bez_spline_from_string(str)
  local tokens = split(str)
  function next_token()
    return deli(tokens, 1)
  end

  local num_segments = next_token()
  local curves = {}

  if #tokens != num_segments * 8 then
    stop("expected " .. num_segments * 8 .. " more numbers")
  end

  for i = 1, num_segments, 1 do
    curves[i] = cub_bezier(
      point(next_token(), next_token()),
      point(next_token(), next_token()),
      point(next_token(), next_token()),
      point(next_token(), next_token())
    )
  end

  return bezier_spline(unpack(curves))
end

-->8
-- general draw functions
function draw_points(points, col)
  for _, p in ipairs(points) do
    pset(p.x, p.y, col)
  end
end

function draw_multi_points(points_groups, col)
  for _, group in ipairs(points_groups) do
    draw_points(group.points, col)
  end
end

function draw_vector_line(points_groups, col)
  for _, group in ipairs(points_groups) do
    for i, p in ipairs(group.points) do
      if i < #group.points then
        local next = group.points[i + 1]
        line(p.x, p.y, next.x, next.y, col)
      end
    end
  end
end

function draw_control_point(p, selected)
  spr(
    selected and 2 or 1,
    p.x - 3,
    p.y - 3
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

      local p = points[cbds.selected_control_point + 1]

      if btn(0) then
        p.x -= mincr
      end

      if btn(1) then
        p.x += mincr
      end

      if btn(2) then
        p.y -= mincr
      end

      if btn(3) then
        p.y += mincr
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
-- bezier spline demo
bsds = { -- bezier spline demo state
  -- testing shapes
  -- lumpy circle
  -- 4,11.5,56.5,7.5,49,5,6.5,40,6.5,40,6.5,75,6.5,112,22,100,52.5,100,52.5,88,83,73.5,98.25,48.5,92,48.5,92,23.5,85.75,13,78.625,9.5,63.5
  -- weird star
  -- 4,11.5,56.5,7.5,49,28.5,-37.5,40,6.5,40,6.5,51.5,50.5,158,47.5,100,52.5,100,52.5,42,57.5,70,82.25,45,76,45,76,20,69.75,13,78.625,9.5,63.5
  -- slope for underfill
  -- 3,5,20,20,20,12,5.5,40,10,40,10,68,14.5,54.5,19.5,85.5,25.5,85.5,25.5,116.5,31.5,92,45.5,122.5,45
  -- streteched version of previous
  -- 3,-132.5,20,-101,3,-44.5,-16,5,10,5,10,54.5,36,50,-5.5,81,6,81,6,112,17.5,191,45.5,374,45
  -- bsds.spline = bez_spline_from_string("2, 5,20, 20,20, 20,35, 40,35,    40,35, 60,35, 60,20, 80,20")
  spline = bez_spline_from_string("4,11.5,56.5,7.5,49,5,6.5,40,6.5,40,6.5,75,6.5,112,22,100,52.5,100,52.5,88,83,73.5,98.25,48.5,92,48.5,92,23.5,85.75,13,78.625,9.5,63.5")
}

function init_bez_spline_demo()
  camera(0, 0)
  bsds.set_increment_value = 0.05
  bsds.selected_control_point = 1
  bsds.selected_curve = 1
  bsds.t_adjust_incr = 0.01
  bsds.set_t_value = 1
  bsds.mode = 0
end

function bsds_draw_t_panel(t_val, active)
  local col = active and 3 or 6
  print("t: " .. t_val, 0, 120, col)
end

function bsds_draw_help(cur_mode)
  if cur_mode == 0 then
    print("⬅️➡️⬆️⬇️ move point", 52, 102, 5)
    print("p2⬅️➡️ change point", 52, 108, 5)
    print("❎ adjust t", 52, 114, 5)
    print("p2❎ add segment", 52, 120, 5)
  elseif cur_mode == 1 then
    print("⬅️➡️ -/+" .. bsds.set_increment_value, 62, 96, 5)
    print("⬇️⬆️ -/+" .. bsds.set_increment_value * 5, 62, 102, 5)
    print("❎ adjust points", 62, 108, 5)
    print("🅾️ main menu", 62, 114, 5)
    print("p2🅾️/❎ p2 copy/paste", 42, 120, 5)
  end
end

function draw_bez_spline_demo()
  rectfill(0, 0, 127, 127, 1)
  local spline = calc_bez_spline(bsds.spline, bsds.set_increment_value, bsds.set_t_value)

  bsds_draw_t_panel(bsds.set_t_value, bsds.mode == 1)

  bsds_draw_help(bsds.mode)

  draw_vector_line(spline.curves, 10)
  if bsds.mode == 0 then
    local curve = bsds.spline.curves[bsds.selected_curve]
    draw_control_points(curve, bsds.selected_control_point - 1)
    line(curve.p0.x, curve.p0.y, curve.p1.x, curve.p1.y, 6)
    line(curve.p2.x, curve.p2.y, curve.p3.x, curve.p3.y, 6)
  end
end

function update_bez_spline_demo()
  if btnp(5) then
    bsds.mode = (bsds.mode + 1) % 2
  end

  if bsds.mode == 0 then
      if btnp(1, 1) then
        bsds.selected_control_point = bsds.selected_control_point + 1
        if bsds.selected_control_point > 4 then
          bsds.selected_control_point = 1
          bsds.selected_curve = bsds.selected_curve + 1
        end

        if bsds.selected_curve > #bsds.spline.curves then
          bsds.selected_curve = 1
        end
      elseif btnp(0, 1) then
        bsds.selected_control_point = bsds.selected_control_point - 1
        if bsds.selected_control_point < 0 then
          bsds.selected_control_point = 1
          bsds.selected_curve = bsds.selected_curve - 1
        end

        if bsds.selected_curve < 1 then
          bsds.selected_curve = #bsds.spline.curves
        end
      end

      local mincr = 0.5
      local curve_idx = bsds.selected_curve
      local point_idx = bsds.selected_control_point

      local editing_point = get_bez_point(bsds.spline.curves[bsds.selected_curve], point_idx)
      local impact_type = nil
      local impacted_points = {}
      if point_idx == 1 then
        impact_type = point_pin
        impacted_points = {
          get_bez_point(bsds.spline.curves[curve_idx], 2),
        }

        if curve_idx > 1 then
          impacted_points[#impacted_points + 1] = get_bez_point(bsds.spline.curves[curve_idx - 1], 4)
          impacted_points[#impacted_points + 1] = get_bez_point(bsds.spline.curves[curve_idx - 1], 3)
        end
      elseif point_idx == 4 then
        impact_type = point_pin
        impacted_points = {
          get_bez_point(bsds.spline.curves[curve_idx], 3),
        }

        if curve_idx < #bsds.spline.curves then
          impacted_points[#impacted_points + 1] = get_bez_point(bsds.spline.curves[curve_idx + 1], 1)
          impacted_points[#impacted_points + 1] = get_bez_point(bsds.spline.curves[curve_idx + 1], 2)
        end
      elseif point_idx == 2 and curve_idx > 1 then
        impact_type = point_mirror
        impacted_points = {
          get_bez_point(bsds.spline.curves[curve_idx - 1], 3),
        }
      elseif point_idx == 3 and curve_idx < #bsds.spline.curves then
        impact_type = point_mirror
        impacted_points = {
          get_bez_point(bsds.spline.curves[curve_idx + 1], 2),
        }
      end

      if btn(0) then
        editing_point.x -= mincr

        map(impacted_points, function(impacted_point)
          if impact_type == point_pin then
            impacted_point.x -= mincr
          elseif impact_type == point_mirror then
            impacted_point.x += mincr
          end
        end)
      end

      if btn(1) then
        editing_point.x += mincr

        map(impacted_points, function(impacted_point)
          if impact_type == point_pin then
            impacted_point.x += mincr
          elseif impact_type == point_mirror then
            impacted_point.x -= mincr
          end
        end)
      end

      if btn(2) then
        editing_point.y -= mincr

        map(impacted_points, function(impacted_point)
          if impact_type == point_pin then
            impacted_point.y -= mincr
          elseif impact_type == point_mirror then
            impacted_point.y += mincr
          end
        end)
      end

      if btn(3) then
        editing_point.y += mincr

        map(impacted_points, function(impacted_point)
          if impact_type == point_pin then
            impacted_point.y += mincr
          elseif impact_type == point_mirror then
            impacted_point.y -= mincr
          end
        end)
      end

      if btnp(5, 1) then
        local end_point = get_bez_point(bsds.spline.curves[#bsds.spline.curves], 4)
        local end_control = get_bez_point(bsds.spline.curves[#bsds.spline.curves], 3)
        local rise = end_point.y - end_control.y
        local run = end_point.x - end_control.x
        local next_control = point(end_point.x + run, end_point.y + rise)
        add_bez_spline_segment(bsds.spline, cub_bezier(
          point(end_point.x, end_point.y),
          point(next_control.x, next_control.y),
          point(next_control.x + (run / 2), next_control.y + (rise / 2)),
          point(next_control.x + run, next_control.y + rise)
        ))

        bsds.selected_curve = #bsds.spline.curves
        bsds.selected_control_point = 1
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

        if btnp(4) then
          selected_program = 1
        end

        if bsds.set_t_value < 0 then
          bsds.set_t_value = 0
        elseif bsds.set_t_value > 1 then
          bsds.set_t_value = 1
        end

        if btnp(4, 1) then
          printh(bez_spline_to_string(bsds.spline), "@clip")
        end

        if btnp(5, 1) then
          bsds.spline = bez_spline_from_string(stat(4))
        end
  end
end

-->8
-- drawing playground 1
dp1s = {} -- drawing playground 1 state

dp1s_mode_names = {
  "line",
  "under fill",
  "recursive fill",
}

function init_draw_playground_1()
  if bsds.spline == nil then
    init_bez_spline_demo()
  end

  dp1s.spline = bsds.spline
  dp1s.incr = 0.1
  dp1s.c_x = 0
  dp1s.c_y = 0
  dp1s.mode = 1
  dp1s.transitioned = false
end

function is_in_bounds(p, bounds)
  return p.x >= bounds.min_x and p.x <= bounds.max_x and p.y >= bounds.min_y and p.y <= bounds.max_y
end

function flood_fill(from_point, color, bounds_list)
  local point_queue = { from_point }

  while #point_queue > 0 do
    local current_point = deli(point_queue, 1)

    pset(current_point.x, current_point.y, color)
    local neighbors = {
      point(current_point.x - 1, current_point.y),
      point(current_point.x + 1, current_point.y),
      point(current_point.x, current_point.y - 1),
      point(current_point.x, current_point.y + 1),
    }

    for _, neighbor in ipairs(neighbors) do
      if some(bounds_list, function(bounds) return is_in_bounds(neighbor, bounds) end) and pget(neighbor.x, neighbor.y) != color and (contains_point(point_queue, neighbor) == false) then
        add(point_queue, neighbor)
      end
    end
  end
end

function sample_sectors(points_groups, sector_size)
  local sectors = {}
  for _, group in ipairs(points_groups) do
    for i, p in ipairs(group.points) do
      if i < #group.points then
        -- this might need work:
        -- find the midpoing to the next point. if that is out of bounds, find the midpoint to the end of bounds
        -- from the midpoint, point 90 degree clockwise (i.e. right-hand rule) and project a little ways out for the fill origin

        local next = group.points[i + 1]

        -- 0 offset
        local unit_point = point(
          next.x - p.x,
          next.y - p.y
        )

        -- normalize and scale out to some px
        local magnitude = sqrt((unit_point.x * unit_point.x) + (unit_point.y * unit_point.y))
        unit_point.x = (unit_point.x / magnitude) * 2
        unit_point.y = (unit_point.y / magnitude) * 2

        -- rotate 90 degrees
        local fill_point = point(
          unit_point.y * -1,
          unit_point.x
        )

        -- translate into place
        local midpoint = lerp_2d(p, next, 0.5)

        fill_point.x = fill_point.x + midpoint.x
        fill_point.y = fill_point.y + midpoint.y

        local sector = {
          p = point(
            flr(p.x / sector_size),
            flr(p.y / sector_size)
          ),
          fill_point = fill_point,
        }

        if not some(sectors, function(s) return points_equal(s.p, sector.p) end) then
          add(sectors, sector)
        end
      end
    end
  end

  return sectors
end

function fill_sectors(points_groups, sector_size, color)
  local sectors = sample_sectors(points_groups, sector_size)
  -- cls()
  -- stop("#: " .. #sectors, 0, 0, color)
  local bounds_list = map(sectors, function(sector) return {
    min_x = (sector.p.x * sector_size),
    max_x = (sector.p.x * sector_size) + sector_size,
    min_y = (sector.p.y * sector_size),
    max_y = (sector.p.y * sector_size) + sector_size,
  } end)

  for _, sector in ipairs(sectors) do
    flood_fill(sector.fill_point, color, bounds_list)
  end
end

function draw_underfill(points_groups, bounds, col)
  for _, group in ipairs(points_groups) do
    for i, p in ipairs(group.points) do
      if i < #group.points then
        local next = group.points[i + 1]

        -- this may lead to back-draw, but that's fine. this is what it is and the curves need to deal
        -- some playing around suggests having a color generator could even make that a feature...
        local rise = next.y - p.y
        local run = next.x - p.x
        local slope = rise / run

        local drawing_point = point(p.x, p.y)
        while drawing_point.x <= next.x do
          rect(drawing_point.x, drawing_point.y, drawing_point.x, bounds.max_y, col)
          drawing_point.x += 1
          drawing_point.y += slope
        end
      end
    end
  end
end

function draw_draw_playground_1()
  local screen_bounds = {
    min_x = dp1s.c_x,
    max_x = dp1s.c_x + 127,
    min_y = dp1s.c_y,
    max_y = dp1s.c_y + 127,
  }

  rectfill(screen_bounds.min_x, screen_bounds.min_y, screen_bounds.max_x, screen_bounds.max_y, 1)
  camera(dp1s.c_x, dp1s.c_y)
  local spline = calc_bez_spline(dp1s.spline, dp1s.incr, 1)

  print(stat(7), dp1s.c_x, dp1s.c_y, 11)
  print(dp1s_mode_names[dp1s.mode], dp1s.c_x + 10, dp1s.c_y, 11)

  if not dp1s.transitioned then
    print("(drawing)", dp1s.c_x, dp1s.c_y + 6, 11)
    dp1s.transitioned = true
    return
  end

  if dp1s.mode == 1 or dp1s.mode == 3 then
    draw_vector_line(spline.curves, 10)
  end

  local start_point = spline.curves[1].points[1]
  local last_curve = spline.curves[#spline.curves]
  local end_point = last_curve.points[#last_curve.points]

  if dp1s.mode == 2 then
    draw_underfill(spline.curves, screen_bounds, 10)
  elseif dp1s.mode == 3 then
    line(start_point.x, start_point.y, end_point.x, end_point.y, 10)
    flood_fill(point(20, 20), 10, { screen_bounds })
  end
end

function update_draw_playground_1()
  local camera_move = 1

  if btn(0) then
    dp1s.c_x -= camera_move
  end

  if btn(1) then
    dp1s.c_x += camera_move
  end

  if btn(2) then
    dp1s.c_y -= camera_move
  end

  if btn(3) then
    dp1s.c_y += camera_move
  end

  if btnp(0, 1) then
    dp1s.mode = dp1s.mode - 1
    dp1s.transitioned = false
  end

  if btnp(1, 1) then
    dp1s.mode = dp1s.mode + 1
    dp1s.transitioned = false
  end

  if dp1s.mode < 1 then
    dp1s.mode = 1
  elseif dp1s.mode > #dp1s_mode_names then
    dp1s.mode = #dp1s_mode_names
  end

  if btnp(4) then
    selected_program = 1
  end
end

-->8
-- main menu

mms = {} -- main menu state
mms_last_program = 3

function init_main_menu()
  mms = {
    selected_program = mms_last_program,
    options = {
      "menu",
      "cubic bezier curve",
      "bezier spline",
      "draw playground",
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
  init_bez_spline_demo,
  init_draw_playground_1,
}

draw_funcs = {
  draw_main_menu,
  draw_cubic_bezier_demo,
  draw_bez_spline_demo,
  draw_draw_playground_1,
}

update_funcs = {
  update_main_menu,
  update_cubic_bezier_demo,
  update_bez_spline_demo,
  update_draw_playground_1,
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
