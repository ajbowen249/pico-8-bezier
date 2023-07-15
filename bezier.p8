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

function all_t(array, func)
  for _, v in ipairs(array) do
    if not func(v) then
      return false
    end
  end

  return true
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
    return tonum(deli(tokens, 1))
  end

  local num_segments = next_token()
  local curves = {}

  if #tokens != num_segments * 8 then
    stop("expected " .. num_segments * 8 .. " more numbers. got " .. #tokens)
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
  -- i <3 bud
  -- 31,10.90087890625,56.035560607910156,23.286338806152344,39.530113220214844,26.507761001586914,21.407630920410156,29.131032943725586,13.993316650390625,29.131032943725586,13.993316650390625,31.273908615112305,7.936775207519531,28.569534301757812,4.669342041015625,25.37701416015625,11.987564086914062,25.37701416015625,11.987564086914062,22.83916473388672,17.805084228515625,16.18082046508789,35.97648620605469,16.933856964111328,47.48133850097656,16.933856964111328,47.48133850097656,17.353464126586914,53.892066955566406,29.828094482421875,52.645957946777344,35.63619613647461,48.13185119628906,35.63619613647461,48.13185119628906,38.17247009277344,46.16063690185547,52.777122497558594,38.33820343017578,59.00237274169922,24.280868530273438,59.00237274169922,24.280868530273438,65.22761535644531,10.223548889160156,69.96063232421875,6.499755859375,79.10907745361328,20.118019104003906,79.10907745361328,20.118019104003906,80.205078125,21.74951171875,80.01776123046875,21.004074096679688,82.73186492919922,19.33770751953125,82.73186492919922,19.33770751953125,107.14754486083984,4.347320556640625,108.54048156738281,21.711402893066406,107.340087890625,30.908172607421875,107.340087890625,30.908172607421875,104.07442474365234,55.92793273925781,82.62052154541016,68.84694290161133,74.46236419677734,73.25897598266602,74.46236419677734,73.25897598266602,72.72010803222656,74.20121002197266,68.46893310546875,65.28809356689453,68.03599548339844,63.091941833496094,68.03599548339844,63.091941833496094,67.5686264038086,60.72112274169922,62.015533447265625,47.036224365234375,62.840919494628906,32.50508117675781,62.840919494628906,32.50508117675781,63.35017395019531,23.539527893066406,40.72063064575195,2.2081451416015625,26.384904861450195,4.722618103027344,26.384904861450195,4.722618103027344,12.596360206604004,7.14111328125,-1.5333292484283447,11.453231811523438,2.4648783206939697,30.743270874023438,2.4648783206939697,30.743270874023438,4.999994277954102,42.97437286376953,6.1237874031066895,60.44523620605469,12.764719009399414,79.19318389892578,12.764719009399414,79.19318389892578,16.935400009155273,90.96739196777344,13.353537559509277,96.50584030151367,13.510101318359375,116.39458656311035,13.510101318359375,116.39458656311035,13.615056037902832,129.72731971740723,20.169124603271484,122.26079320907593,31.749404907226562,120.00856637954712,31.749404907226562,120.00856637954712,41.85457992553711,118.0432300567627,38.20857620239258,106.16820907592773,26.44137191772461,105.32677459716797,26.44137191772461,105.32677459716797,15.54029655456543,104.54727363586426,12.63333797454834,106.38956642150879,13.848913192749023,104.70562171936035,13.848913192749023,104.70562171936035,14.59256649017334,103.67543411254883,31.09323501586914,101.76928520202637,32.37055969238281,100.13167953491211,32.37055969238281,100.13167953491211,38.591651916503906,92.1558723449707,26.033470153808594,87.33821868896484,23.956764221191406,87.31334686279297,23.956764221191406,87.31334686279297,8.663381576538086,87.13018417358398,16.24650764465332,86.24856567382812,14.300662994384766,86.97453689575195,14.300662994384766,86.97453689575195,12.672639846801758,87.5819320678711,8.453863143920898,120.18609142303467,14.074789047241211,126.16362690925598,14.074789047241211,126.16362690925598,15.265145301818848,127.42950320243835,33.61701202392578,125.36765098571777,41.06669616699219,121.92849493026733,41.06669616699219,121.92849493026733,44.6851921081543,120.25801181793213,43.01362228393555,99.578369140625,43.32543182373047,91.37907409667969,43.32543182373047,91.37907409667969,43.61228942871094,83.83587265014648,42.69994354248047,121.20360851287842,50.8922004699707,120.74265766143799,50.8922004699707,120.74265766143799,61.51278305053711,120.14507293701172,63.64973068237305,111.82984924316406,65.51752471923828,93.58134460449219,65.51752471923828,93.58134460449219,66.60063934326172,82.99922561645508,74.66703796386719,85.77753067016602,77.95865631103516,94.63843536376953,77.95865631103516,94.63843536376953,81.66287231445312,104.61004257202148,80.30499267578125,114.63867664337158,80.72335052490234,123.91167640686035,80.72335052490234,123.91167640686035,80.83930206298828,126.48178100585938,98.61905670166016,124.79820919036865,100.32015991210938,124.31824922561646,100.32015991210938,124.31824922561646,109.73452758789062,121.66202020645142,115.38595581054688,94.6048355102539,106.09349060058594,92.76820373535156,106.09349060058594,92.76820373535156,94.7444076538086,90.52508544921875,85.82269287109375,90.79464340209961,76.49498748779297,92.44294738769531
  -- spline = bez_spline_from_string("2, 5,20, 20,20, 20,35, 40,35,    40,35, 60,35, 60,20, 80,20")
  spline = bez_spline_from_string(" 8,58.810550689697266,17.6689453125,95.50778198242188,21.41315460205078,98.17866516113281,47.947669982910156,104.61775970458984,54.59931945800781,104.61775970458984,54.59931945800781,130.27444458007812,81.10293579101562,124.57888793945312,103.01200866699219,115.45970153808594,104.60778045654297,115.45970153808594,104.60778045654297,13.181465148925781,122.50550842285156,110.1832275390625,113.67817306518555,16.933547973632812,108.13141250610352,16.933547973632812,108.13141250610352,-4.483125686645508,106.85748672485352,38.76192855834961,66.71900939941406,43.631832122802734,61.578819274902344,43.631832122802734,61.578819274902344,58.38747787475586,46.00421142578125,42.614967346191406,40.86088562011719,35.22932815551758,47.755340576171875,35.22932815551758,47.755340576171875,24.90984344482422,57.388526916503906,17.778091430664062,53.00233459472656,8.395520210266113,42.13108825683594,8.395520210266113,42.13108825683594,0.05032920837402344,32.461814880371094,-4.328205585479736,13.757522583007812,7.311325550079346,6.149383544921875,7.311325550079346,6.149383544921875,15.362564086914062,0.88671875,28.40860366821289,7.374824523925781,29.40860366821289,7.374824523925781")
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
  "recursive fill to sprites",
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
  dp1s.rec_to_sprite_ready = false
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

function new_fill_tree_node(depth, end_depth)
  if depth > end_depth then
    return nil
  end

  if depth == end_depth then
    return {
      is_resolved = false,
      is_filled = false,
      is_empty = false,
      is_leaf = true,
      tl = nil,
      tr = nil,
      bl = nil,
      br = nil,
    }
  end

  return {
    is_resolved = false,
    is_filled = false,
    is_empty = false,
    is_leaf = false,
    tl = new_fill_tree_node(depth + 1, end_depth),
    tr = new_fill_tree_node(depth + 1, end_depth),
    bl = new_fill_tree_node(depth + 1, end_depth),
    br = new_fill_tree_node(depth + 1, end_depth),
  }
end

function new_fill_tree(terminal_resolution)
  -- we don't have a log2 function to use here :(
  local depth = 1
  local resolution = 128
  while resolution > terminal_resolution do
    depth = depth + 1
    resolution = resolution / 2
  end

  return new_fill_tree_node(1, depth)
end

function visit_fill_tree(node, depth, p, visitor)
  if not node.is_leaf then
    local tl_p = point(p.x, p.y)
    local loc_size = 128 / (2 ^ depth)
    local tr_p = point(p.x + loc_size, p.y)
    local bl_p = point(p.x, p.y + loc_size)
    local br_p = point(p.x + loc_size, p.y + loc_size)

    visit_fill_tree(node.tl, depth + 1, tl_p, visitor)
    visit_fill_tree(node.tr, depth + 1, tr_p, visitor)
    visit_fill_tree(node.bl, depth + 1, bl_p, visitor)
    visit_fill_tree(node.br, depth + 1, br_p, visitor)
  end

  visitor(node, p, depth)
end

function screen_space_to_fill_tree(transparent_color, sprite_size)
  local fill_tree = new_fill_tree(sprite_size)

  visit_fill_tree(fill_tree, 1, point(0, 0), function(node, p)
    if node.is_leaf then
      -- leaf nodes check pixels

      local found_transparent = false
      local found_non_transparent = false

      for x = p.x, p.x + sprite_size, 1 do
        for y = p.y, p.y + sprite_size, 1 do
          local color = pget(x, y)
          if color == transparent_color then
            found_transparent = true
          else
            found_non_transparent = true
          end
        end
      end

      if found_non_transparent and not found_transparent then
        node.is_filled = true
      elseif found_transparent and not found_non_transparent then
        node.is_empty = true
      end
    else
      -- nodes higher up just want to know who is filled
      node.is_filled = all_t({ node.tl, node.tr, node.bl, node.br }, function(child)
        return child.is_filled
      end)

      node.is_empty = all_t({ node.tl, node.tr, node.bl, node.br }, function(child)
        return child.is_empty
      end)
    end

    node.is_resolved = true
  end)

  return fill_tree
end

function get_sprite_offset(index, row, sprite_size, sheet_start)
  local spr_row = flr(index / (128 / sprite_size))
  local spr_col = index % (128 / sprite_size)
  local screen_row = (spr_row * sprite_size * 64) + (row * 64)
  return (screen_row + (spr_col * (sprite_size / 2))) + sheet_start
end

function get_point_offset(p)
  return (p.y * 64) + (p.x / 2)
end

function extract_fill_tree_to_sprites(fill_tree, from, to, sprite_size)
  local sprite_index = 0

  visit_fill_tree(fill_tree, 1, point(0, 0), function(node, p, depth)
    if not node.is_leaf or node.is_empty or node.is_filled then
      return
    end

    for row = 0, sprite_size - 1, 1 do
      local source_offset = get_point_offset(point(p.x, p.y + row))
      local dest_offset = get_sprite_offset(sprite_index, row, sprite_size, to)

      memcpy(dest_offset, source_offset, sprite_size / 2) -- / 2 because 1 byte is 2px
    end

    node.sprite_index = sprite_index
    sprite_index = sprite_index + 1
  end)
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
    if dp1s.mode == 3 then
      print("(rendering)", dp1s.c_x, dp1s.c_y + 6, 11)
    else
      print("(drawing)", dp1s.c_x, dp1s.c_y + 6, 11)
    end
    dp1s.transitioned = true
    return
  end

  if dp1s.mode == 1 or dp1s.mode == 4 then
    draw_vector_line(spline.curves, 10)
  end

  local start_point = spline.curves[1].points[1]
  local last_curve = spline.curves[#spline.curves]
  local end_point = last_curve.points[#last_curve.points]

  if dp1s.mode == 2 then
    draw_underfill(spline.curves, screen_bounds, 10)
    return
  end

  if dp1s.mode == 4 then
    line(start_point.x, start_point.y, end_point.x, end_point.y, 10)
    flood_fill(point(20, 20), 10, { screen_bounds })
    return
  end

  if dp1s.mode == 3 then
    if not dp1s.rec_to_sprite_ready then
      -- First, render the spline to the spritesheet
      poke(0x5f55, 0x00) -- switch draw commands to use spritesheet
      cls()
      draw_vector_line(spline.curves, 10)
      line(start_point.x, start_point.y, end_point.x, end_point.y, 10)
      flood_fill(point(20, 20), 10, {
        {
          min_x = 0,
          min_y = 0,
          max_x = 127,
          max_y = 127,
        }
      })

      -- extract partially-filled cells to sprites in aux memory
      dp1s.fill_tree = screen_space_to_fill_tree(0, 8)
      extract_fill_tree_to_sprites(dp1s.fill_tree, 0x0000, 0x8000, 8)

      -- since we drew the shape into sprite memory, we used extended ram to store the generated sprites
      -- now we have to copy those sprites back into the actual sprite sheet
      cls()
      memcpy(0x0000, 0x8000, 8192)

      -- just testing; copy sprite sheet to extended ram and back
      -- memcpy(0x8000, 0x0000, 8192)
      -- cls()
      -- memcpy(0x0000, 0x8000, 8192)


      poke(0x5f55, 0x60) -- switch back to screen space

      dp1s.rec_to_sprite_ready = true
    end

    -- draw the rendered sprites to the screen

    visit_fill_tree(dp1s.fill_tree, 1, point(0, 0), function(node, p)
      if node.is_leaf then
        if node.sprite_index != nil then
          spr(node.sprite_index, p.x, p.y)
          -- circfill(p.x + 4, p.y + 4, 4, 10)
        end
      end
    end)

    return
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

  local changed_mode = false

  if btnp(0, 1) then
    dp1s.mode = dp1s.mode - 1
    changed_mode = true
  end

  if btnp(1, 1) then
    dp1s.mode = dp1s.mode + 1
    changed_mode = true
  end

  if changed_mode then
    dp1s.transitioned = false

    if dp1s.mode < 1 then
      dp1s.mode = 1
    elseif dp1s.mode > #dp1s_mode_names then
      dp1s.mode = #dp1s_mode_names
    end

    if dp1s.mode == 4 then
      dp1s.rec_to_sprite_ready = false
    end
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
