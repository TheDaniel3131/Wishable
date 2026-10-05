import math

# Constants for Standard (Reinforced)
SG_RUBBER = 1.15
SG_METAL = 7.85
COMPOUND_MULTIPLIER = 1.03
PI_VAL = 3.142

# Constants for Solid Bearing (No Metal)
SG_SOLID = 1.4
SOLID_MULTIPLIER = 1.03

def calculate_specs(width, length, height, code, quantity, side_cover, metal_thk, plate_count):
    """
    Performs engineering calculations.
    Supports both Standard (Metal+Rubber) and Solid (N) bearings.
    """
    
    # Ensure inputs are floats
    W = float(width)
    L = float(length)
    H = float(height)
    
    # 1. Detect Type: If 'N' is in code, it is Solid Bearing (No Metal)
    is_solid = 'N' in code.strip().upper()
    
    # 2. Detect Shape: Ends with 'C' is Round, otherwise Rectangular
    is_round = code.strip().upper().endswith('C')
    
    # 3. Calculate Volume based on Shape
    total_vol = 0.0
    if is_round:
        # Round: (W * L) / 4 * H * PI (Using W/L as diameter)
        total_vol = (W * L) / 4 * H * PI_VAL
    else:
        # Rectangle: W * L * H
        total_vol = W * L * H
        
    # 4. Calculate Internals (Metal vs Solid)
    if is_solid:
        # --- SOLID BEARING (N) ---
        # Plates = 0, Metal = 0
        metal_w = 0.0
        metal_l = 0.0
        metal_vol = 0.0
        plate_count = 0 # Force plate count to 0
        
        # Rubber is entire volume
        rubber_vol = total_vol
        
        # Use SG 1.4 and Solid Multiplier
        # Formula: total volume * 1.4 / 1000000 * 1.03
        compound_wt = (rubber_vol * SG_SOLID / 1000000) * SOLID_MULTIPLIER
        metal_wt = 0.0
        
    else:
        # --- STANDARD BEARING ---
        # Metal Dimensions
        metal_w = W - (side_cover * 2)
        metal_l = L - (side_cover * 2)
        
        # Metal Volume
        if is_round:
            metal_vol = (metal_w * metal_l) / 4 * metal_thk * plate_count * PI_VAL
        else:
            metal_vol = metal_w * metal_l * metal_thk * plate_count

        rubber_vol = total_vol - metal_vol
        
        # Weights (SG 1.15)
        compound_wt = (rubber_vol * SG_RUBBER / 1000000) * COMPOUND_MULTIPLIER
        metal_wt = (metal_vol * SG_METAL / 1000000)
    
    # 5. Final Totals
    unit_wt = compound_wt + metal_wt
    grand_total = unit_wt * quantity
    
    return {
        "is_round": is_round,
        "is_solid": is_solid, # Added flag to help UI
        "metal_w": metal_w,
        "metal_l": metal_l,
        "total_vol": total_vol,
        "metal_vol": metal_vol,
        "rubber_vol": rubber_vol,
        "compound_wt": compound_wt,
        "metal_wt": metal_wt,
        "unit_wt": unit_wt,
        "grand_total": grand_total
    }

def auto_detect_plates(code):
    """
    Extracts digits before the last character (R or C).
    Formula: Digit + 1
    If Code contains 'N', returns 0 (Solid Bearing).
    """
    if not code:
        return 0

    # Check for Solid Bearing (N)
    if 'N' in code.strip().upper():
        return 0

    import re
    match = re.search(r'(\d+)[RC]$', code, re.IGNORECASE)
    
    if match:
        num_str = match.group(1)[-2:] 
        try:
            val = int(num_str)
            return val + 1 
        except ValueError:
            return 0
    return 0