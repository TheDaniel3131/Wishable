import plotly.graph_objects as go
import random

# --- 1. OPTIMIZER LOGIC (Classes & Functions) ---

class Item:
    def __init__(self, name, length, width, height, weight, color=None):
        self.name = name
        self.l = float(length)
        self.w = float(width)
        self.h = float(height)
        self.weight = float(weight)
        self.vol = self.l * self.w * self.h
        self.base_area = self.l * self.w
        
        # Color generation
        random.seed(hash(name)) 
        r = random.randint(50, 255)
        g = random.randint(50, 255)
        b = random.randint(50, 255)
        self.color = f'rgb({r}, {g}, {b})'
        
        self.x = 0
        self.y = 0
        self.z = 0
        self.rotation = 0 

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
        
    def find_best_fit(self, item, start_x_limit=0, end_x_limit=None):
        if end_x_limit is None: end_x_limit = self.L
        item_l, item_w, item_h = item.get_dimension()
        
        # Potential anchors
        unique_x = {0, self.L, start_x_limit} 
        unique_y = {0, self.W}
        unique_z = {0}
        
        for placed in self.items:
            p_l, p_w, p_h = placed.get_dimension()
            unique_x.add(placed.x); unique_x.add(placed.x + p_l)
            unique_y.add(placed.y); unique_y.add(placed.y + p_w)
            unique_z.add(placed.z + p_h)

        anchor_points = []
        for x in unique_x:
            if x < start_x_limit or x > end_x_limit: continue
            for y in unique_y:
                for z in unique_z:
                    if x + item_l <= end_x_limit and y + item_w <= self.W and z + item_h <= self.H:
                         anchor_points.append((x, y, z))

        decorated_anchors = []
        for x, y, z in anchor_points:
            # Collision
            if any(x < o.x + o.get_dimension()[0] and x + item_l > o.x and
                   y < o.y + o.get_dimension()[1] and y + item_w > o.y and
                   z < o.z + o.get_dimension()[2] and z + item_h > o.z for o in self.items):
                continue
            
            # Stability (Z>0)
            if z > 0:
                corners = [(x, y), (x+item_l, y), (x, y+item_w), (x+item_l, y+item_w)]
                supporters = [s for s in self.items if abs((s.z + s.get_dimension()[2]) - z) < 0.01]
                valid_corners = sum(1 for cx, cy in corners if any(s.x <= cx <= s.x + s.get_dimension()[0] and s.y <= cy <= s.y + s.get_dimension()[1] for s in supporters))
                if valid_corners < 3: continue 

            gap_metric = (end_x_limit - (x + item_l)) + (self.W - (y + item_w))
            dist_to_wall = min(y, self.W - (y + item_w))
            decorated_anchors.append((z, dist_to_wall, gap_metric, x, (x, y, z)))

        if not decorated_anchors: return None
        decorated_anchors.sort(key=lambda k: (k[0], k[1], k[2], k[3]))
        return decorated_anchors[0][0], decorated_anchors[0][4][0], decorated_anchors[0][4][1], decorated_anchors[0][4][2]


def solve_packing(container_l, container_w, container_h, items_data, max_weight_kg=20000, balance_weight=False): 
    # Strategies including SHUFFLE to ungroup
    strategies = [
        ("Area", lambda x: (x.base_area, x.weight, x.h)),
        ("Ungrouped", lambda x: (x.vol, x.base_area, x.h)),
        ("Shuffle_A", lambda x: random.random()),
        ("Shuffle_B", lambda x: random.random()),
        ("Shuffle_C", lambda x: random.random()),
    ]
    
    start_ratios = [i / 19.0 for i in range(20)] 
    best_container, best_utilization = None, -1.0
    
    base_items = []
    for d in items_data:
        for _ in range(int(d['qty'])):
            base_items.append(d)

    for strat_name, sort_func in strategies:
        temp_items = [Item(d['name'], d['l'], d['w'], d['h'], d['weight']) for d in base_items]
        temp_items.sort(key=sort_func, reverse=True)
        
        for start_ratio in start_ratios:
            trial = Container(container_l, container_w, container_h, max_weight=max_weight_kg)
            for i, item in enumerate(temp_items):
                if trial.current_weight + item.weight > trial.max_weight:
                    trial.unpacked_items.append(item); continue 
                
                best_fit = None 
                for rot in [0, 1]:
                    item.rotation = rot
                    start_x = 0
                    if i == 0: start_x = max(0, ((container_l - item.get_dimension()[0]) / 2) * start_ratio)
                    
                    res = trial.find_best_fit(item, start_x_limit=start_x)
                    if not res and start_x > 0: res = trial.find_best_fit(item, start_x_limit=0)
                    
                    if res:
                        metric, x, y, z = res
                        if best_fit is None or (z < best_fit[3]) or (z == best_fit[3] and metric < best_fit[0]):
                            best_fit = (metric, x, y, z, rot)
                
                if best_fit:
                    _, item.x, item.y, item.z, item.rotation = best_fit
                    trial.items.append(item)
                    trial.current_weight += item.weight
                else:
                    trial.unpacked_items.append(item)

            vol = sum(i.vol for i in trial.items)
            if vol > best_utilization:
                best_utilization = vol
                best_container = trial

    return best_container

def get_container_stats(container):
    total_vol = container.L * container.W * container.H
    used_vol = sum(i.vol for i in container.items)
    total_weight = sum(i.weight for i in container.items)
    mid = container.L / 2
    w_nose = sum(i.weight for i in container.items if (i.x + i.get_dimension()[0]/2) < mid)
    
    return {
        "packed": len(container.items),
        "total": len(container.items) + len(container.unpacked_items),
        "weight": total_weight,
        "nose_pct": (w_nose / total_weight * 100) if total_weight > 0 else 0,
        "vol_pct": (used_vol / total_vol) * 100
    }

# --- 2. EXECUTION BLOCK (Run this to see results) ---
if __name__ == "__main__":
    
    # Standard 20ft Container
    CONT_L, CONT_W, CONT_H = 5900, 2350, 2390
    
    items = [
        {'name': 'Pink (1140)', 'l': 1140, 'w': 1140, 'h': 640, 'weight': 1274.5, 'qty': 13},
        {'name': 'Yellow (1830)', 'l': 1830, 'w': 1830, 'h': 640, 'weight': 1046.5, 'qty': 2}
    ]
    
    print(f"--- PHYSICAL CHECK: Can they separate? ---")
    print(f"Container Width: {CONT_W}mm")
    
    w_pink = 1140
    w_yellow = 1830
    
    # Check Pink + Pink
    pair_pink = w_pink + w_pink
    print(f"1. Pink + Pink Width:   {pair_pink}mm -> {'FITS ✅' if pair_pink <= CONT_W else 'TOO WIDE ❌'}")

    # Check Pink + Yellow
    pair_mixed = w_pink + w_yellow
    print(f"2. Pink + Yellow Width: {pair_mixed}mm -> {'FITS ✅' if pair_mixed <= CONT_W else 'TOO WIDE ❌'}")
    
    if pair_mixed > CONT_W:
        print("\n[!] CONCLUSION: It is PHYSICALLY IMPOSSIBLE to place a Pink box next to a Yellow box.")
        print("    They MUST be in separate rows. The algorithm isn't grouping them by choice;")
        print("    it's the only way they fit!")
    else:
        print("\n[!] Conclusion: They CAN mix.")
    print("------------------------------------------\n")

    cont = solve_packing(CONT_L, CONT_W, CONT_H, items)
    stats = get_container_stats(cont)
    
    print(f"Packed: {stats['packed']}/{stats['total']}")
    print(f"Weight: {stats['weight']:.2f} kg")
    print(f"Balance: {stats['nose_pct']:.1f}% (Front) / {100-stats['nose_pct']:.1f}% (Back)")
    
    print("\nLayout Sequence (X-Axis):")
    # Sort items by their position to show order
    sorted_items = sorted(cont.items, key=lambda x: x.x)
    for i in sorted_items:
        if i.z == 0: # Print floor layer
            print(f"[{i.name}] at X={i.x:.0f}, Y={i.y:.0f}")