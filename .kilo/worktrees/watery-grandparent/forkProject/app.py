import streamlit as st
import dataset
import calculation as calc
import optimizer
import pandas as pd
import random
import plotly.graph_objects as go

# 1. Page Config
st.set_page_config(page_title="koi", layout="wide")

def local_css(file_name):
    # Create style.css if it doesn't exist to prevent errors
    try:
        with open(file_name) as f:
            st.markdown(f'<style>{f.read()}</style>', unsafe_allow_html=True)
    except FileNotFoundError:
        st.markdown("""
        <style>
            .main-title { font-size: 2.5rem; font-weight: 800; margin-bottom: 0; text-align: center; }
            .sub-title { font-size: 1rem; margin-bottom: 1rem; text-align: center; opacity: 0.7; }
        </style>
        """, unsafe_allow_html=True)

local_css("style.css")

# 2. Session State Initialization
if 'database' not in st.session_state:
    # IMPROVED LOADING LOGIC
    if hasattr(dataset, 'get_data'):
        # Case A: Dataset has a function to fetch data
        st.session_state['database'] = dataset.get_data()
    elif hasattr(dataset, 'STATIC_DATABASE'):
        # Case B: Dataset is a simple list variable
        st.session_state['database'] = dataset.STATIC_DATABASE
    else:
        # Fallback: No data found
        st.session_state['database'] = []

if 'saved_items' not in st.session_state:
    st.session_state['saved_items'] = []

# Container State
if 'container_items' not in st.session_state:
    st.session_state['container_items'] = []

if 'container_plan' not in st.session_state:
    st.session_state['container_plan'] = None

# Focus Management State
if 'should_focus_desc' not in st.session_state:
    st.session_state['should_focus_desc'] = False

# Ensure existing items have the Delete key
for item in st.session_state['saved_items']:
    if "Delete" not in item:
        item["Delete"] = False

# Initialize Calculation Defaults
defaults = {'calc_w': "", 'calc_l': "", 'calc_h': "", 'calc_code': "", 'calc_plates': 3}
for key, default in defaults.items():
    if key not in st.session_state:
        st.session_state[key] = default

# 3. Custom CSS
st.markdown("""
<style>
    /* Clean Header Styling */
    .main-title { font-size: 2.5rem; font-weight: 800; margin-bottom: 0; text-align: center; }
    .sub-title { font-size: 1rem; margin-bottom: 1rem; text-align: center; opacity: 0.7; }
    
    /* Input Field Styling */
    .stTextInput > label, .stNumberInput > label { font-size: 0.85rem; font-weight: 600; margin-bottom: 0.2rem; }
    
    /* Metric Styling */
    div[data-testid="stMetricValue"] { font-size: 1.5rem; }
    div[data-testid="stMetricLabel"] { font-size: 0.8rem; opacity: 0.7; }

    /* Compact Layout Overrides */
    div[data-testid="stVerticalBlock"] { gap: 0.5rem !important; }
    hr { margin-top: 0.5rem !important; margin-bottom: 0.5rem !important; }
    
    /* Editor Styling */
    .stDataFrame { font-size: 0.8rem; }
    
    /* Tabs Styling Adjustment */
    .stTabs [data-baseweb="tab-list"] {
        gap: 10px;
    }
</style>
""", unsafe_allow_html=True)

# 4. Header
st.markdown('<div class="main-title">Koi<span style="color:#3b82f6">Koi</span> PRO</div>', unsafe_allow_html=True)
st.markdown('<div class="sub-title">404</div>', unsafe_allow_html=True)

# ==============================================================================
# LOGIC & CALLBACKS
# ==============================================================================
def update_inputs_from_search():
    query = st.session_state.calc_search_query.strip().upper()
    found = next((item for item in st.session_state['database'] if item["code"] == query), None)
    
    if found:
        st.session_state.calc_w = str(found['width'])
        st.session_state.calc_l = str(found['length'])
        st.session_state.calc_h = str(found['height'])
        st.session_state.calc_code = found['code']
        st.session_state.calc_plates = calc.auto_detect_plates(found['code'])
        st.session_state.calc_sc = 5.0
        st.session_state.calc_mt = 5.0
        st.toast(f"Data loaded for {query}", icon="✅")
    elif query:
        st.toast("Code not found. Please enter dimensions manually.", icon="ℹ️")

def clear_search():
    if st.session_state.calc_search_query:
        st.session_state.calc_search_query = ""

def on_code_change():
    clear_search()
    st.session_state.calc_sc = 1.0
    st.session_state.calc_mt = 1.0

def add_to_list(data, code, w, l, h, qty):
    new_item = {
        "Delete": False,
        "Description": f"{w}x{l}x{h} ({code})",
        "Qty": int(qty),
        "Unit Wt": float(round(data['unit_wt'], 3)),
        "Total Wt": float(round(data['grand_total'], 2)),
        # Hidden fields for transfer to Container Tab
        "_dim_w": float(w),
        "_dim_l": float(l),
        "_dim_h": float(h)
    }
    st.session_state['saved_items'].append(new_item)
    st.toast("Item added to list!", icon="📋")

def clear_list():
    st.session_state['saved_items'] = []

def display_results(width, length, height, code, quantity, side_cover, metal_thk, plate_count):
    if not (width and length and height and code):
        st.info("👋 Enter dimensions or search code.")
        return

    try:
        data = calc.calculate_specs(width, length, height, code, quantity, side_cover, metal_thk, plate_count)
    except Exception as e:
        st.warning(f"Waiting for valid inputs... ({e})")
        return

    is_solid = data.get('is_solid', False)
    shape = "ROUND" if data.get('is_round') else "RECTANGULAR"
    
    with st.container(border=True):
        r1_col1, r1_col2 = st.columns([3, 1])
        r1_col1.caption(f"RESULTS: {shape} {'(SOLID)' if is_solid else ''}")
        
        c1, c2, c3 = st.columns(3)
        c1.metric("Unit Weight", f"{data['unit_wt']:.3f} kg")
        c2.metric("Total Vol", f"{data['total_vol']:,.0f} cc")
        c3.metric("Rubber Vol", f"{data['rubber_vol']:,.0f} cc")
        
        st.divider()
        st.markdown("**Configuration**")
        d1, d2 = st.columns(2)
        if is_solid:
            d1.info("Solid Rubber (N)")
            d2.caption(f"SG: 1.4")
        else:
            d1.caption(f"Metals: {data['metal_w']:.0f}x{data['metal_l']:.0f}mm")
            d1.caption(f"Plates: {plate_count} pcs ({metal_thk}mm)")
            d2.caption(f"Metal Wt: {data['metal_wt']:.3f} kg")
            d2.caption(f"Comp Wt: {data['compound_wt']:.3f} kg")

        st.divider()
        t1, t2 = st.columns([1.5, 1])
        t1.subheader(f"Total: {data['grand_total']:,.2f} kg")
        
        if t2.button("Add to List ➕", use_container_width=True, type="primary"):
            add_to_list(data, code, width, length, height, quantity)


# ==============================================================================
# MAIN LAYOUT (TABS)
# ==============================================================================

tab1, tab2 = st.tabs(["Calculator", "3d cont"])

# --- TAB 1: CALCULATOR ---
with tab1:
    calc_col, list_col = st.columns([1.5, 1], gap="medium")

    with calc_col:
        with st.container(border=True):
            st.markdown("**Calculator**")
            col_search, col_qty = st.columns([2.5, 1])
            with col_search:
                st.text_input("Search", placeholder="Code...", key="calc_search_query", on_change=update_inputs_from_search, label_visibility="collapsed")
            with col_qty:
                calc_qty = st.number_input("Qty", value=1, min_value=1, key='calc_qty', label_visibility="collapsed")
            
            st.divider()
            c1, c2, c3, c4 = st.columns(4)
            c1.text_input("W", key="calc_w", on_change=clear_search)
            c2.text_input("L", key="calc_l", on_change=clear_search)
            c3.text_input("H", key="calc_h", on_change=clear_search)
            c4.text_input("Code", key="calc_code", on_change=on_code_change)

            current_code = st.session_state.calc_code.upper() if st.session_state.calc_code else ""
            is_solid_calc = 'N' in current_code

            if is_solid_calc:
                st.caption("Solid (N) - No internal settings.")
                calc_side_cover, calc_metal_thk, calc_plates = 0.0, 0.0, 0
            else:
                s1, s2, s3 = st.columns(3)
                calc_side_cover = s1.number_input("S.Cover", value=5.0, step=0.5, key='calc_sc')
                calc_metal_thk = s2.number_input("M.Thk", value=5.0, step=0.5, key='calc_mt')
                calc_plates = s3.number_input("Plates", 0, key='calc_plates')

        st.write("") 
        display_results(
            width=st.session_state.calc_w,
            length=st.session_state.calc_l,
            height=st.session_state.calc_h,
            code=st.session_state.calc_code,
            quantity=calc_qty,
            side_cover=calc_side_cover,
            metal_thk=calc_metal_thk,
            plate_count=calc_plates
        )

    with list_col:
        st.markdown("**Project List**")
        st.caption("Edit 'Qty' to update. Select '❌' to remove.")
        
        if len(st.session_state['saved_items']) > 0:
            df = pd.DataFrame(st.session_state['saved_items'])
            
            edited_df = st.data_editor(
                df,
                column_config={
                    "Delete": st.column_config.CheckboxColumn("❌", width="small"),
                    "Description": st.column_config.TextColumn("Item", width="medium", disabled=True),
                    "Qty": st.column_config.NumberColumn("Qty", min_value=1, step=1, width="small"),
                    "Unit Wt": st.column_config.NumberColumn("Unit (kg)", format="%.3f", disabled=True),
                    "Total Wt": st.column_config.NumberColumn("Total (kg)", format="%.2f", disabled=True),
                    "_dim_w": None, "_dim_l": None, "_dim_h": None # Hide internal columns
                },
                hide_index=True,
                use_container_width=True,
                key="list_editor",
                column_order=("Delete", "Description", "Qty", "Total Wt") 
            )
            
            changes_detected = False
            if edited_df['Delete'].any():
                edited_df = edited_df[~edited_df['Delete']]
                edited_df['Delete'] = False
                changes_detected = True
            
            new_totals = edited_df['Qty'] * edited_df['Unit Wt']
            if not edited_df['Total Wt'].equals(new_totals):
                edited_df['Total Wt'] = new_totals
                changes_detected = True
            
            if changes_detected:
                st.session_state['saved_items'] = edited_df.to_dict('records')
                st.rerun()

            total_project_weight = edited_df['Total Wt'].sum()
            st.divider()
            st.metric("Project Total Weight", f"{total_project_weight:,.2f} kg")
            
            if st.button("Clear All Items", type="secondary", use_container_width=True):
                clear_list()
                st.rerun()
            
        else:
            st.info("List is empty.")

# --- TAB 2: CONTAINER LOADING ---
with tab2:
    st.markdown("### 3d  Cont")
    
    row1_col1, row1_col2 = st.columns([1, 2], gap="large")

    # --- LEFT: INPUTS ---
    with row1_col1:
        # 1. Container Selection
        with st.container(border=True):
            st.subheader("1. Container Settings")
            cont_type = st.radio("Type", ["40ft High Cube", "20ft Standard"], horizontal=True)
            
            c_dim1, c_dim2, c_dim3 = st.columns(3)
            if cont_type == "40ft High Cube":
                cont_l = c_dim1.number_input("L (mm)", value=12000)
                cont_w = c_dim2.number_input("W (mm)", value=2290)
                cont_h = c_dim3.number_input("H (mm)", value=2300)
            else:
                cont_l = c_dim1.number_input("L (mm)", value=5780)
                cont_w = c_dim2.number_input("W (mm)", value=2290)
                cont_h = c_dim3.number_input("H (mm)", value=2390)
                
            # ADDED: Balance Toggle to fix the crash
            balance_mode = st.toggle("Force 50/50 Weight Balance", value=True, help="AI will try to split heavy items evenly between front and back.")
            
        # 2. Packing List Editor
        st.subheader("2. Packing List")
        
        # Clear Button Only
        if st.button("🗑️ Clear List", type="secondary", use_container_width=True):
            st.session_state['container_items'] = []
            st.rerun()

        # --- Manual Input Form (Static Layout) ---
        # Initialize session state for manual inputs if they don't exist
        if 'input_desc' not in st.session_state: st.session_state['input_desc'] = ""
        if 'input_l' not in st.session_state: st.session_state['input_l'] = 0
        if 'input_w' not in st.session_state: st.session_state['input_w'] = 0
        if 'input_h' not in st.session_state: st.session_state['input_h'] = 0
        if 'input_wt' not in st.session_state: st.session_state['input_wt'] = 0.0
        if 'input_qty' not in st.session_state: st.session_state['input_qty'] = 1
        
        def add_item_callback():
            # Check validation directly from session state
            if (st.session_state.input_l > 0 and 
                st.session_state.input_w > 0 and 
                st.session_state.input_h > 0 and 
                st.session_state.input_wt > 0):
                
                new_item = {
                    "Delete": False,
                    "Description": st.session_state.input_desc if st.session_state.input_desc else "Item",
                    "Length (mm)": int(st.session_state.input_l),
                    "Width (mm)": int(st.session_state.input_w),
                    "Height (mm)": int(st.session_state.input_h),
                    "Weight (kg)": float(st.session_state.input_wt),
                    "Qty": int(st.session_state.input_qty)
                }
                st.session_state['container_items'].append(new_item)
                st.toast("Item added!", icon="✅")
                
                # Clear inputs after successful add
                st.session_state.input_desc = ""
                st.session_state.input_l = 0
                st.session_state.input_w = 0
                st.session_state.input_h = 0
                st.session_state.input_wt = 0.0
                st.session_state.input_qty = 1
                
                # Set flag to trigger refocus script
                st.session_state['should_focus_desc'] = True
            else:
                st.error("Please enter valid dimensions and weight.")

        with st.container(border=True):
            st.markdown("**:heavy_plus_sign: Add Item**")
            st.caption("💡 *Tip: Press **Enter** to jump to the next box.*")
            
            # 1. Description (Always Visible)
            st.text_input("Description", placeholder="Item Name...", key="input_desc")
            
            # 2. Dimensions Row (Always Visible)
            st.number_input("Length (mm)", min_value=0, step=10, key="input_l")
            st.number_input("Width (mm)", min_value=0, step=10, key="input_w")
            st.number_input("Height (mm)", min_value=0, step=10, key="input_h")

            # 3. Weight & Quantity Row (Always Visible)
            c_wt, c_qty = st.columns(2)
            with c_wt:
                st.number_input("Weight (kg)", min_value=0.0, step=0.1, key="input_wt")
            with c_qty:
                st.number_input("Qty", min_value=1, step=1, key="input_qty")
                
            st.button("Add to List", type="primary", use_container_width=True, on_click=add_item_callback)
            
            # --- JAVASCRIPT INJECTION FOR ENTER KEY & REFOCUS ---
            st.markdown(
                """
                <script>
                // 1. Enter Key Navigation
                function setupEnterKeyNavigation() {
                    try {
                        const doc = window.parent.document;
                        
                        // Select all input fields (including Streamlit's number inputs)
                        // We filter for standard text/number types and ensure they are visible
                        const inputs = Array.from(doc.querySelectorAll('input'))
                            .filter(el => {
                                // Must be visible
                                if (el.offsetParent === null) return false;
                                // Must be text-like (exclude checkboxes, radios, range, color)
                                const type = el.getAttribute('type');
                                return ['text', 'number', 'password', 'search', 'tel', 'url'].includes(type) || !type;
                            });

                        inputs.forEach((input, index) => {
                            // Cleanup
                            if (input._enterHandler) input.removeEventListener('keydown', input._enterHandler, true);
                            
                            input._enterHandler = function(e) {
                                if (e.key === 'Enter') {
                                    // PREVENT Streamlit from refreshing/submitting
                                    e.preventDefault();
                                    e.stopPropagation();
                                    
                                    const nextInput = inputs[index + 1];
                                    if (nextInput) {
                                        // Move to next input
                                        nextInput.focus();
                                        nextInput.select();
                                    } else {
                                        // If no next input (Last Field), try to click "Add to List"
                                        // Find buttons that are visible
                                        const buttons = Array.from(doc.querySelectorAll('button'))
                                            .filter(b => b.offsetParent !== null && b.innerText.includes("Add to List"));
                                        
                                        if (buttons.length > 0) {
                                            // Click the last found "Add to List" (likely the one in Tab 2)
                                            buttons[buttons.length - 1].click();
                                        }
                                    }
                                }
                            };
                            // Capture Phase (True) is CRITICAL to beat Streamlit's event listeners
                            input.addEventListener('keydown', input._enterHandler, true);
                        });
                    } catch (e) { console.log(e); }
                }

                // Run repeatedly to catch re-renders
                setInterval(setupEnterKeyNavigation, 1000);
                </script>
                """,
                unsafe_allow_html=True
            )
            
            # --- CONDITIONAL REFOCUS SCRIPT ---
            if st.session_state['should_focus_desc']:
                st.markdown(
                    """
                    <script>
                        setTimeout(function() {
                            var doc = window.parent.document;
                            // Selector for the Description input specifically
                            var input = doc.querySelector('input[aria-label="Description"]');
                            if (input) {
                                input.focus();
                            }
                        }, 100); 
                    </script>
                    """,
                    unsafe_allow_html=True
                )
                st.session_state['should_focus_desc'] = False

        # Display List
        if len(st.session_state['container_items']) > 0:
            df_container = pd.DataFrame(st.session_state['container_items'])
            
            # Ensure Delete column exists (for items added via import or old state)
            if "Delete" not in df_container.columns:
                df_container["Delete"] = False

            edited_container_df = st.data_editor(
                df_container,
                num_rows="fixed", # Disable adding rows via table
                use_container_width=True,
                column_config={
                    "Delete": st.column_config.CheckboxColumn("❌", width="small"),
                    "Description": st.column_config.TextColumn("Item"),
                    "Weight (kg)": st.column_config.NumberColumn("Wt", format="%.1f"),
                    "Length (mm)": st.column_config.NumberColumn("L", format="%d"),
                    "Width (mm)": st.column_config.NumberColumn("W", format="%d"),
                    "Height (mm)": st.column_config.NumberColumn("H", format="%d"),
                    "Qty": st.column_config.NumberColumn("Qty", step=1)
                },
                column_order=("Delete", "Description", "Weight (kg)", "Length (mm)", "Width (mm)", "Height (mm)", "Qty"), 
                hide_index=True,
                key="container_list_editor"
            )

            # Handle Deletions & Edits
            if edited_container_df['Delete'].any():
                edited_container_df = edited_container_df[~edited_container_df['Delete']]
                # Remove delete flag
                edited_container_df['Delete'] = False
                st.session_state['container_items'] = edited_container_df.to_dict('records')
                st.rerun()
            else:
                 st.session_state['container_items'] = edited_container_df.to_dict('records')

        else:
            st.info("Packing list is empty.")


        if st.button("🚀 Calculate Loading Plan", type="primary", use_container_width=True):
            with st.spinner("AI is optimizing placement and balancing weight..."):
                # Prepare data for optimizer
                items_data = []
                for item in st.session_state['container_items']:
                    # Validation: Ensure critical fields exist
                    if item.get("Length (mm)") and item.get("Weight (kg)"):
                        # Use Description as name
                        name_display = item.get("Description", "Item")
                        
                        items_data.append({
                            "name": name_display,
                            "l": item["Length (mm)"],
                            "w": item["Width (mm)"],
                            "h": item["Height (mm)"],
                            "weight": item["Weight (kg)"],
                            "qty": item["Qty"],
                            # Color removed, handled by optimizer
                        })
                
                # Run Optimization
                if items_data:
                    container = optimizer.solve_packing(
                        cont_l, cont_w, cont_h, items_data, balance_weight=balance_mode
                    )
                    st.session_state['container_plan'] = container
                else:
                    st.warning("⚠️ List is empty or missing dimensions.")
            st.rerun()

    # --- RIGHT: VISUALIZATION ---
    with row1_col2:
        container = st.session_state.get('container_plan')

        if container:
            stats = optimizer.get_container_stats(container)
            
            # --- KPI Cards ---
            kpi1, kpi2, kpi3, kpi4 = st.columns(4)
            kpi1.metric("Items Packed", f"{stats['packed_count']} / {stats['packed_count'] + stats['unpacked_count']}")
            kpi2.metric("Total Weight", f"{stats['weight_total']:,.0f} kg")
            kpi3.metric("Vol. Usage", f"{stats['volume_utilization']:.1f}%")
            
            # Legacy Balance Indicator (kept for top-level summary)
            bal = stats['balance_ratio']
            delta_color = "normal"
            if bal < 45 or bal > 55: delta_color = "inverse"
            kpi4.metric("Nose/Door Bal.", f"{bal:.0f}%", delta="Target 50%", delta_color=delta_color)

            # --- 3D Chart ---
            st.plotly_chart(optimizer.visualize_container(container), use_container_width=True, theme="streamlit")
            
            # --- DETAILED BALANCE METRICS (ADDED) ---
            st.subheader("⚖️ Weight Balance Analysis")
            b1, b2, b3 = st.columns(3)

            with b1:
                len_f = stats['balance_ratio_len']
                len_b = 100 - len_f
                st.metric(
                    label="Longitudinal Balance (Front / Back)", 
                    value=f"{len_f:.0f}% / {len_b:.0f}%", 
                    help=f"Front: {len_f:.1f}% | Back: {len_b:.1f}%"
                )
                st.progress(min(1.0, max(0.0, len_f / 100)))

            with b2:
                wid_l = stats['balance_ratio_width']
                wid_r = 100 - wid_l
                st.metric(
                    label="Horizontal Balance (Left / Right)", 
                    value=f"{wid_l:.0f}% / {wid_r:.0f}%", 
                    help=f"Left: {wid_l:.1f}% | Right: {wid_r:.1f}%"
                )
                st.progress(min(1.0, max(0.0, wid_l / 100)))

            with b3:
                hgt_b = stats['balance_ratio_height']
                hgt_t = 100 - hgt_b
                st.metric(
                    label="Vertical Balance (Bottom / Top)", 
                    value=f"{hgt_b:.0f}% / {hgt_t:.0f}%", 
                    help=f"Bottom: {hgt_b:.1f}% | Top: {hgt_t:.1f}%"
                )
                st.progress(min(1.0, max(0.0, hgt_b / 100)))

            # Detailed breakdown text
            st.caption(f"Detailed Vertical Load: Bottom {stats['weight_bottom']:.0f}kg | Top {stats['weight_top']:.0f}kg")

            # --- Warnings / Details ---
            if stats['unpacked_count'] > 0:
                st.error(f"⚠️ {stats['unpacked_count']} items could not fit! Check dimensions or upgrade container size.")
                with st.expander("See unpacked items"):
                    for item in container.unpacked_items:
                        st.write(f"- {item.name} ({item.l}x{item.w}x{item.h})")
            
            if bal < 40 or bal > 60:
                st.warning("⚠️ Longitudinal weight is unbalanced. Consider rearranging manually or checking item weights.")

        else:
            # Placeholder State
            st.markdown(
                """
                <div style="display:flex; justify-content:center; align-items:center; height:400px; border: 2px dashed #334155; border-radius: 10px; color: #64748b;">
                    <div style="text-align:center">
                        <h3>👈 Step 1: Input your Packing List on the left</h3>
                        <p>Step 2: Click <b>'Calculate Loading Plan'</b> to visualize</p>
                    </div>
                </div>
                """, 
                unsafe_allow_html=True
            )
