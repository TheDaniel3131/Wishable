import plotly.graph_objects as go
import random
import copy

# Tolerance for floating point comparisons to prevent microscopic misfits
# Increased to 1.0mm to handle real-world data imperfections/rounding errors
EPSILON = 1.0

class Item:
    def __init__(self, name, length, width, height, weight, color=None):
        self.name = name
        self.l = float(length)
        self.w = float(width)
        self.h = float(height)
        self.weight = float(weight)
        self.vol = self.l * self.w * self.h
        self.base_area = self.l * self.w
        
        # Consistent color based on name WITHOUT affecting global random state
        # We use a local instance of Random to ensure global shuffle remains random
        rd = random.Random(hash(name))
        r = rd.randint(50, 255)
        g = rd.randint(50, 255)
        b = rd.randint(50, 255)
        self.color = f'rgb({r}, {g}, {b})'
        
        self.x = 0
        self.y = 0
        self.z = 0
        self.rotation = 0 # 0: original, 1: rotated 90 deg on floor

    def get_dimension(self):
        if self.rotation == 1:
            return self.w, self.l, self.h
        return self.l, self.w, self.h

class Container:
    def __init__(self, length, width, height, max_weight=20000):
        self.L = length
        self.W = width
        self.H = height
        self.max_weight = max_weight
        self.current_weight = 0.0
        self.items = []
        self.unpacked_items = []
        
    def get_all_valid_anchors(self, item, start_x_limit=0, end_x_limit=None, axis_priority='x'):
        """
        Returns a list of ALL valid anchor points for an item, sorted by priority.
        """
        if end_x_limit is None:
            end_x_limit = self.L

        item_l, item_w, item_h = item.get_dimension()
        
        # 1. Generate potential anchor points
        unique_x = {0, self.L, start_x_limit} 
        unique_y = {0, self.W}
        unique_z = {0} # Strict no stacking
        
        for placed in self.items:
            p_l, p_w, p_h = placed.get_dimension()
            unique_x.add(placed.x)
            unique_x.add(placed.x + p_l)
            unique_y.add(placed.y)
            unique_y.add(placed.y + p_w)

        anchor_points = set()
        for x in unique_x:
            if x < start_x_limit - EPSILON or x > (end_x_limit - item_l) + EPSILON: continue
            
            for y in unique_y:
                for z in unique_z:
                    if (x + item_l <= end_x_limit + EPSILON and 
                        y + item_w <= self.W + EPSILON and 
                        z + item_h <= self.H + EPSILON):
                         anchor_points.add((x, y, z))

        valid_anchors = []
        for x, y, z in anchor_points:
            # Collision Check
            collision = False
            for other in self.items:
                o_l, o_w, o_h = other.get_dimension()
                if (x < other.x + o_l - EPSILON and x + item_l > other.x + EPSILON and
                    y < other.y + o_w - EPSILON and y + item_w > other.y + EPSILON and
                    z < other.z + o_h - EPSILON and z + item_h > other.z + EPSILON):
                    collision = True
                    break
            if collision: continue
            
            # Fit Metric: Calculate how tight this fit is to the boundaries
            gap_metric = (end_x_limit - (x + item_l)) + (self.W - (y + item_w))
            
            # Sort Key: (Z, X, Y, Gap) or (Z, Y, X, Gap)
            if axis_priority == 'x':
                sort_key = (z, x, y, gap_metric)
            else:
                sort_key = (z, y, x, gap_metric)
                
            valid_anchors.append((sort_key, (x, y, z), gap_metric))
            
        # Sort best first
        valid_anchors.sort(key=lambda item: item[0])
        return valid_anchors # Returns full tuple list

    def find_best_fit(self, item, start_x_limit=0, end_x_limit=None, axis_priority='x'):
        anchors = self.get_all_valid_anchors(item, start_x_limit, end_x_limit, axis_priority)
        if anchors:
            # Return (x,y,z) and the gap_metric
            return anchors[0][1], anchors[0][2]
        return None, float('inf')

def calculate_balance_score(container):
    if container.current_weight == 0: return 50.0
    mid_point = container.L / 2
    weight_nose = 0.0
    for item in container.items:
        item_mid = item.x + (item.get_dimension()[0] / 2)
        if item_mid < mid_point:
            weight_nose += item.weight
        elif item_mid == mid_point:
            weight_nose += item.weight * 0.5
    balance_ratio = (weight_nose / container.current_weight) * 100
    return abs(50.0 - balance_ratio), balance_ratio

def _apply_swaps(items, percentage):
    # Helper to clean up random swaps
    n_swaps = int(len(items) * percentage)
    for _ in range(n_swaps):
        i1, i2 = random.randint(0, len(items)-1), random.randint(0, len(items)-1)
        items[i1], items[i2] = items[i2], items[i1]

def solve_packing(container_l, container_w, container_h, items_data, max_weight_kg=20000, balance_weight=False, n_simulations=10000): 
    # Pre-parse base items
    base_items_raw = []
    for d in items_data:
        for _ in range(int(d['qty'])):
            base_items_raw.append(Item(d['name'], d['l'], d['w'], d['h'], d['weight']))

    # Strategy Definition
    # Combined Power: Try Scarcity (Constraints), Spot Centric (Geometry), AND Monte Carlo (Random)
    strategies = ["Global_Scarcity_Fit", "Spot_Centric_Fit", "Super_Compute_Monte_Carlo"]
    
    best_container = None
    best_item_count = -1
    best_utilization = -1.0
    best_balance_diff = 100.0 
    
    for strat in strategies:
        iterations = 1
        if strat == "Super_Compute_Monte_Carlo":
             iterations = n_simulations
        
        # Run X-axis priority (Front-to-Back) and Y-axis priority (Left-to-Right)
        sub_strategies = ['x', 'y']

        for i in range(iterations):
            for axis_p in sub_strategies:
                
                trial_container = Container(container_l, container_w, container_h, max_weight=max_weight_kg)
                
                if strat == "Global_Scarcity_Fit":
                    # --- SCARCITY LOGIC (Fail-First Heuristic) ---
                    # Identifies items that have the FEWEST placement options and places them first.
                    items_pool = [Item(i.name, i.l, i.w, i.h, i.weight) for i in base_items_raw]
                    
                    while len(items_pool) > 0:
                        scarcity_scores = []
                        for idx, item in enumerate(items_pool):
                            if trial_container.current_weight + item.weight > trial_container.max_weight: continue
                            
                            best_move_for_this_item = None
                            total_valid_spots = 0
                            
                            for rot in [0, 1]:
                                item.rotation = rot
                                anchors = trial_container.get_all_valid_anchors(item, axis_priority=axis_p)
                                count = len(anchors)
                                total_valid_spots += count
                                if count > 0:
                                    best_anchor = anchors[0]
                                    if best_move_for_this_item is None:
                                        best_move_for_this_item = (rot, best_anchor[1]) # store (rot, (x,y,z))
                                    else:
                                        # Tie break by coordinate priority
                                        if best_anchor[1] < best_move_for_this_item[1]:
                                            best_move_for_this_item = (rot, best_anchor[1])

                            if total_valid_spots > 0 and best_move_for_this_item:
                                r, (x,y,z) = best_move_for_this_item
                                # Score: (ValidSpots, -Area, idx, ...)
                                scarcity_scores.append((total_valid_spots, -item.base_area, idx, r, x, y, z))
                        
                        if not scarcity_scores:
                            trial_container.unpacked_items.extend(items_pool)
                            break
                        
                        # Sort by Scarcity (Lowest Count First), then Largest Area
                        scarcity_scores.sort(key=lambda x: (x[0], x[1]))
                        winner_info = scarcity_scores[0]
                        w_idx, w_rot, wx, wy, wz = winner_info[2], winner_info[3], winner_info[4], winner_info[5], winner_info[6]
                        winner = items_pool.pop(w_idx)
                        winner.rotation = w_rot
                        winner.x, winner.y, winner.z = wx, wy, wz
                        trial_container.items.append(winner)
                        trial_container.current_weight += winner.weight

                elif strat == "Spot_Centric_Fit":
                    # --- SPOT CENTRIC LOGIC V2 ---
                    # Finds the best available "Hole" and plugs it with the item that fits best.
                    items_pool = [Item(i.name, i.l, i.w, i.h, i.weight) for i in base_items_raw]
                    
                    # Try two sub-modes for Spot Centric: 
                    # 1. Prioritize Tight Gap (Snugness)
                    # 2. Prioritize Large Area (Fill Volume)
                    # We toggle this based on iteration count or run both if possible. 
                    # For simplicity, we stick to the robust hybrid metric.
                    
                    while len(items_pool) > 0:
                        global_best_move = None
                        # Metric: (Z, X, Y, Gap, -ItemArea)
                        global_best_metric = (float('inf'), float('inf'), float('inf'), float('inf'), float('inf'))
                        valid_move_found = False
                        
                        for idx, item in enumerate(items_pool):
                            if trial_container.current_weight + item.weight > trial_container.max_weight: continue
                            
                            for rot in [0, 1]:
                                item.rotation = rot
                                anchor, gap = trial_container.find_best_fit(item, axis_priority=axis_p)
                                
                                if anchor:
                                    x, y, z = anchor
                                    if axis_p == 'x': pos_score = (z, x, y)
                                    else: pos_score = (z, y, x)
                                    
                                    # Metric: Position -> Gap -> Size
                                    current_metric = (pos_score[0], pos_score[1], pos_score[2], gap, -item.base_area)
                                    if current_metric < global_best_metric:
                                        global_best_metric = current_metric
                                        global_best_move = (idx, rot, x, y, z)
                                        valid_move_found = True
                        
                        if valid_move_found and global_best_move:
                            idx, rot, x, y, z = global_best_move
                            winner = items_pool.pop(idx)
                            winner.rotation = rot
                            winner.x, winner.y, winner.z = x, y, z
                            trial_container.items.append(winner)
                            trial_container.current_weight += winner.weight
                        else:
                            trial_container.unpacked_items.extend(items_pool)
                            break
                            
                else:
                    # --- SUPER COMPUTE MONTE CARLO ---
                    # High volume random sampling
                    items_to_pack = [Item(i.name, i.l, i.w, i.h, i.weight) for i in base_items_raw]
                    
                    mode = i % 6
                    if mode == 0: random.shuffle(items_to_pack)
                    elif mode == 1: 
                        items_to_pack.sort(key=lambda x: x.base_area, reverse=True)
                        _apply_swaps(items_to_pack, 0.2)
                    elif mode == 2:
                        items_to_pack.sort(key=lambda x: x.l, reverse=True)
                        _apply_swaps(items_to_pack, 0.2)
                    elif mode == 3:
                        items_to_pack.sort(key=lambda x: x.w, reverse=True)
                        _apply_swaps(items_to_pack, 0.2)
                    elif mode == 4:
                        # Big First, then Shuffle rest
                        items_to_pack.sort(key=lambda x: x.base_area, reverse=True)
                        split = len(items_to_pack) // 3
                        rest = items_to_pack[split:]
                        random.shuffle(rest)
                        items_to_pack = items_to_pack[:split] + rest
                    elif mode == 5:
                        # Smallest First (Reverse Area) - Sometimes works for tight spaces
                        items_to_pack.sort(key=lambda x: x.base_area, reverse=False)
                        _apply_swaps(items_to_pack, 0.1)

                    for item in items_to_pack:
                        if trial_container.current_weight + item.weight > trial_container.max_weight:
                            trial_container.unpacked_items.append(item)
                            continue
                        
                        best_fit_trial = None
                        for rot in [0, 1]:
                            item.rotation = rot
                            anchor, gap = trial_container.find_best_fit(item, axis_priority=axis_p)
                            if anchor:
                                x, y, z = anchor
                                is_better = False
                                if best_fit_trial is None: is_better = True
                                else:
                                    bx, by, bz, _, bgap = best_fit_trial
                                    if z < bz: is_better = True
                                    elif z == bz:
                                        if axis_p == 'x':
                                            if x < bx: is_better = True
                                            elif x == bx and y < by: is_better = True
                                        else:
                                            if y < by: is_better = True
                                            elif y == by and x < bx: is_better = True
                                if is_better: best_fit_trial = (x, y, z, rot, gap)
                        
                        if best_fit_trial:
                            x, y, z, rot, _ = best_fit_trial
                            item.rotation, item.x, item.y, item.z = rot, x, y, z
                            trial_container.items.append(item)
                            trial_container.current_weight += item.weight
                        else:
                            trial_container.unpacked_items.append(item)

                # --- SCORING ---
                packed_count = len(trial_container.items)
                packed_vol = sum(it.vol for it in trial_container.items)
                balance_diff, _ = calculate_balance_score(trial_container)
                
                # Bonus for Smart Strategies
                strat_bonus = 0.5 if strat != "Super_Compute_Monte_Carlo" else 0
                
                if best_container is None:
                    best_container = trial_container
                    best_item_count = packed_count
                    best_utilization = packed_vol
                    best_balance_diff = balance_diff - strat_bonus
                else:
                    if packed_count > best_item_count:
                        best_container = trial_container
                        best_item_count = packed_count
                        best_utilization = packed_vol
                        best_balance_diff = balance_diff - strat_bonus
                    elif packed_count == best_item_count:
                        if packed_vol > best_utilization + 1e-5:
                            best_container = trial_container
                            best_utilization = packed_vol
                            best_balance_diff = balance_diff - strat_bonus
                        elif abs(packed_vol - best_utilization) < 1e-5:
                            current_score = balance_diff - strat_bonus
                            if current_score < best_balance_diff:
                                best_container = trial_container
                                best_balance_diff = current_score

    return best_container

def visualize_container(container):
    fig = go.Figure()
    L, W, H = container.L, container.W, container.H
    
    # 1. Container Wireframe
    cage_lines = [
        ([0, L], [0, 0], [0, 0]), ([0, L], [W, W], [0, 0]), ([0, L], [0, 0], [H, H]), ([0, L], [W, W], [H, H]),
        ([0, 0], [0, W], [0, 0]), ([L, L], [0, W], [0, 0]), ([0, 0], [0, W], [H, H]), ([L, L], [0, W], [H, H]),
        ([0, 0], [0, 0], [0, H]), ([L, L], [0, 0], [0, H]), ([0, 0], [W, W], [0, H]), ([L, L], [W, W], [0, H])
    ]
    for lx, ly, lz in cage_lines:
        fig.add_trace(go.Scatter3d(x=lx, y=ly, z=lz, mode='lines', line=dict(color='white', width=4), showlegend=False, hoverinfo='skip'))

    # 2. Add Center Lines (Reference Axes) and Marker
    # Red X at geometric center
    fig.add_trace(go.Scatter3d(
        x=[L/2], y=[W/2], z=[H/2],
        mode='markers',
        marker=dict(size=8, color='red', symbol='x'),
        name='Geometric Center',
        hoverinfo='text',
        text=f"Geometric Center<br>L:{L/2:.0f} W:{W/2:.0f} H:{H/2:.0f}"
    ))

    # Center Length Line (Longitudinal) - RED
    fig.add_trace(go.Scatter3d(
        x=[0, L], y=[W/2, W/2], z=[H/2, H/2],
        mode='lines',
        line=dict(color='red', width=5, dash='dash'),
        name='Center Length (Balance Axis)',
        hoverinfo='skip'
    ))
    
    # Center Width Line (Horizontal) - BLUE
    fig.add_trace(go.Scatter3d(
        x=[L/2, L/2], y=[0, W], z=[H/2, H/2],
        mode='lines',
        line=dict(color='blue', width=5, dash='dash'),
        name='Center Width (Side Axis)',
        hoverinfo='skip'
    ))

    # Center Height Line (Vertical) - GREEN
    fig.add_trace(go.Scatter3d(
        x=[L/2, L/2], y=[W/2, W/2], z=[0, H],
        mode='lines',
        line=dict(color='green', width=5, dash='dash'),
        name='Center Height (Vertical Axis)',
        hoverinfo='skip'
    ))

    # 3. Add Items with Solid Mesh and Lighting
    for item in container.items:
        x, y, z = item.x, item.y, item.z
        l, w, h = item.get_dimension()
        
        vx = [x, x+l, x+l, x, x, x+l, x+l, x]
        vy = [y, y, y+w, y+w, y, y, y+w, y+w]
        vz = [z, z, z, z, z+h, z+h, z+h, z+h]
        
        # Vertex indices for 12 triangles forming a solid cube
        i_idx = [0, 0, 4, 4, 0, 0, 1, 1, 2, 2, 3, 3]
        j_idx = [1, 2, 5, 6, 1, 5, 2, 6, 3, 7, 0, 4]
        k_idx = [2, 3, 6, 7, 5, 4, 6, 5, 7, 6, 4, 7]
        
        fig.add_trace(go.Mesh3d(
            x=vx, y=vy, z=vz,
            i=i_idx, j=j_idx, k=k_idx,
            color=item.color,
            opacity=1.0, # Shapes are now fully opaque
            flatshading=True,
            lighting=dict(ambient=0.6, diffuse=0.8, fresnel=0.2, specular=0.4, roughness=0.4),
            name=item.name,
            hoverinfo='text',
            text=f"{item.name}<br>Pos: {x:.0f},{y:.0f},{z:.0f}<br>Size: {l:.0f}x{w:.0f}x{h:.0f}"
        ))

        # 4. Add Black Outlines (Wireframe) for clear shape definition
        edges = [
            ([x, x+l], [y, y], [z, z]), ([x, x+l], [y+w, y+w], [z, z]), 
            ([x, x+l], [y, y], [z+h, z+h]), ([x, x+l], [y+w, y+w], [z+h, z+h]),
            ([x, x], [y, y+w], [z, z]), ([x+l, x+l], [y, y+w], [z, z]),
            ([x, x], [y, y+w], [z+h, z+h]), ([x+l, x+l], [y, y+w], [z+h, z+h]),
            ([x, x], [y, y], [z, z+h]), ([x+l, x+l], [y, y], [z, z+h]),
            ([x, x], [y+w, y+w], [z, z+h]), ([x+l, x+l], [y+w, y+w], [z, z+h])
        ]
        for ex, ey, ez in edges:
            fig.add_trace(go.Scatter3d(x=ex, y=ey, z=ez, mode='lines', line=dict(color='black', width=2), showlegend=False, hoverinfo='skip'))

    fig.update_layout(
        scene=dict(
            xaxis=dict(range=[0, L], title="Length (mm)", backgroundcolor="#0f172a"),
            yaxis=dict(range=[0, W], title="Width (mm)", backgroundcolor="#0f172a"),
            zaxis=dict(range=[0, H], title="Height (mm)", backgroundcolor="#0f172a"),
            aspectmode='data'
        ),
        paper_bgcolor="rgba(0,0,0,0)",
        margin=dict(l=0, r=0, b=0, t=0)
    )
    return fig

def get_container_stats(container):
    total_vol = container.L * container.W * container.H
    used_vol = sum(i.vol for i in container.items)
    total_weight = sum(i.weight for i in container.items)
    
    # Accurate Weight Balance Calculation (Proportional)
    # We analyze balance across all three axes: Length, Width, Height
    
    mid_L = container.L / 2
    mid_W = container.W / 2
    mid_H = container.H / 2
    
    w_nose, w_door = 0.0, 0.0   # Length (X-axis)
    w_left, w_right = 0.0, 0.0  # Width (Y-axis)
    w_bottom, w_top = 0.0, 0.0  # Height (Z-axis)
    
    for item in container.items:
        # Get dimensions based on current rotation
        dim = item.get_dimension() # returns (l, w, h)
        item_weight = item.weight
        
        # --- LENGTH BALANCE (Nose vs Door) ---
        start_x, end_x = item.x, item.x + dim[0]
        # Calculate portion of item in the Front half (0 to mid_L)
        overlap_nose = max(0, min(mid_L, end_x) - max(0, start_x))
        ratio_nose = overlap_nose / dim[0] if dim[0] > 0 else (1 if item.x < mid_L else 0)
        
        w_nose += item_weight * ratio_nose
        w_door += item_weight * (1 - ratio_nose)
        
        # --- WIDTH BALANCE (Left vs Right) ---
        start_y, end_y = item.y, item.y + dim[1]
        # Calculate portion of item in the Left half (0 to mid_W)
        overlap_left = max(0, min(mid_W, end_y) - max(0, start_y))
        ratio_left = overlap_left / dim[1] if dim[1] > 0 else (1 if item.y < mid_W else 0)
        
        w_left += item_weight * ratio_left
        w_right += item_weight * (1 - ratio_left)
        
        # --- VERTICAL BALANCE (Bottom vs Top) ---
        start_z, end_z = item.z, item.z + dim[2]
        # Calculate portion of item in the Bottom half (0 to mid_H)
        overlap_bottom = max(0, min(mid_H, end_z) - max(0, start_z))
        ratio_bottom = overlap_bottom / dim[2] if dim[2] > 0 else (1 if item.z < mid_H else 0)
        
        w_bottom += item_weight * ratio_bottom
        w_top += item_weight * (1 - ratio_bottom)

    # Ratios (Percentages)
    balance_ratio_len = (w_nose / total_weight * 100) if total_weight > 0 else 50.0
    balance_ratio_width = (w_left / total_weight * 100) if total_weight > 0 else 50.0
    balance_ratio_height = (w_bottom / total_weight * 100) if total_weight > 0 else 50.0
    
    return {
        "packed_count": len(container.items),
        "unpacked_count": len(container.unpacked_items),
        "weight_total": total_weight,
        "weight_limit": container.max_weight,
        "weight_utilization": (total_weight / container.max_weight * 100) if container.max_weight > 0 else 0,
        "volume_utilization": (used_vol / total_vol) * 100,
        
        # Detailed Weight Distribution
        "weight_nose": w_nose,
        "weight_door": w_door,
        "weight_left": w_left,
        "weight_right": w_right,
        "weight_bottom": w_bottom,
        "weight_top": w_top,
        
        # Ratios
        "balance_ratio": balance_ratio_len,         # Existing key for compatibility
        "balance_ratio_len": balance_ratio_len,     # Front/Back (50% is perfect)
        "balance_ratio_width": balance_ratio_width, # Left/Right (50% is perfect)
        "balance_ratio_height": balance_ratio_height # Bottom/Top (Higher is usually safer/more stable)
    }